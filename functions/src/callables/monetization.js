const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const {
  onCall,
  HttpsError,
  admin,
  FUNCTION_REGION,
  callableRuntimeOptions,
  requireCallableAuth,
} = require("../core");
const {
  BHRIGU_PLUS_ENTITLEMENT,
  BHRIGU_PLUS_PRODUCT,
  DAKSHANA_PRODUCT,
  DAKSHANA_CREDITS,
  ACTIVE_SUBSCRIPTION_EVENTS,
  INACTIVE_SUBSCRIPTION_EVENTS,
  DAKSHANA_GRANT_EVENTS,
  DAKSHANA_REVOKE_EVENTS,
} = require("../monetization/catalog");
const {
  getMonetizationStatusForUid,
} = require("../monetization/quota");

const REVENUECAT_WEBHOOK_AUTH = defineSecret("REVENUECAT_WEBHOOK_AUTH");
const IGNORED_WEBHOOK_EVENTS = new Set(["TEST", "TRANSFER"]);

function parseRequestBody(req) {
  if (!req.body) return {};
  if (Buffer.isBuffer(req.body)) {
    return JSON.parse(req.body.toString("utf8"));
  }
  if (typeof req.body === "string") {
    return JSON.parse(req.body);
  }
  return req.body;
}

function eventFromPayload(payload) {
  if (payload?.event && typeof payload.event === "object") {
    return payload.event;
  }

  return payload && typeof payload === "object" ? payload : {};
}

function eventTypeFor(event) {
  return String(event.type || "").trim().toUpperCase();
}

function eventIdFor(event) {
  return String(
    event.id ||
      event.event_id ||
      [
        event.type,
        event.app_user_id,
        event.product_id,
        event.event_timestamp_ms,
      ].filter(Boolean).join("_")
  );
}

function uidFromEvent(event) {
  const uid = String(event.app_user_id || "").trim();
  if (uid) return uid;

  if (Array.isArray(event.transferred_to) && event.transferred_to.length > 0) {
    return String(event.transferred_to[0] || "").trim();
  }

  return "";
}

function timestampFromMillis(value) {
  const millis = Number(value);
  if (!Number.isFinite(millis) || millis <= 0) return null;
  return admin.firestore.Timestamp.fromMillis(millis);
}

function numberFromMillis(value) {
  const millis = Number(value);
  return Number.isFinite(millis) && millis > 0 ? millis : null;
}

function normalizedProductId(value) {
  const productId = String(value || "").trim();
  if (!productId) return "";
  return productId.split(":")[0];
}

function eventProductIds(event) {
  return [
    event.product_id,
    event.new_product_id,
    event.product_identifier,
    event.new_product_identifier,
    event.store_product_id,
    event.original_product_id,
  ]
    .map((value) => String(value || "").trim())
    .filter(Boolean);
}

function eventMatchesProduct(event, productId) {
  return eventProductIds(event).some((candidate) =>
    candidate === productId || normalizedProductId(candidate) === productId
  );
}

function primaryProductId(event, fallback) {
  return eventProductIds(event)[0] || fallback;
}

function transactionIdForEvent(event) {
  return String(
    event.transaction_id ||
      event.original_transaction_id ||
      event.purchase_token ||
      event.id ||
      event.event_id ||
      ""
  ).trim();
}

function planFromEvent(event) {
  const period = [
    event.period_type || "",
    event.presented_offering_identifier || "",
    event.presented_offering_id || "",
    event.product_id || "",
    event.new_product_id || "",
    event.product_identifier || "",
    event.new_product_identifier || "",
    event.store_product_id || "",
  ].join(" ").toLowerCase();

  if (period.includes("year") || period.includes("annual")) {
    return "yearly";
  }

  const purchasedAt = numberFromMillis(
    event.purchased_at_ms || event.event_timestamp_ms
  );
  const expiresAt = numberFromMillis(event.expiration_at_ms);
  if (purchasedAt && expiresAt) {
    const subscriptionDays = (expiresAt - purchasedAt) / 86400000;
    if (subscriptionDays >= 300) {
      return "yearly";
    }
  }

  return "monthly";
}

function isPlusEvent(event) {
  const entitlementIds = Array.isArray(event.entitlement_ids)
    ? event.entitlement_ids
    : [];

  return eventMatchesProduct(event, BHRIGU_PLUS_PRODUCT) ||
    entitlementIds.includes(BHRIGU_PLUS_ENTITLEMENT);
}

function isDakshanaEvent(event) {
  return eventMatchesProduct(event, DAKSHANA_PRODUCT);
}

function dakshanaWalletRef(uid) {
  return admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("wallet")
    .doc("dakshana");
}

function userPurchaseRef(uid, eventRef) {
  return admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("purchases")
    .doc(`revenuecat_${eventRef.id}`);
}

function applyPlusEvent(transaction, uid, event, eventRef) {
  const type = eventTypeFor(event);
  const productId = primaryProductId(event, BHRIGU_PLUS_PRODUCT);
  const plan = planFromEvent(event);
  const entitlementRef = admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("entitlements")
    .doc(BHRIGU_PLUS_ENTITLEMENT);
  const purchaseRef = userPurchaseRef(uid, eventRef);
  const expiresAt = timestampFromMillis(event.expiration_at_ms);
  const activeByExpiration =
    !expiresAt || expiresAt.toMillis() > Date.now();
  const active = ACTIVE_SUBSCRIPTION_EVENTS.has(type)
    ? activeByExpiration
    : INACTIVE_SUBSCRIPTION_EVENTS.has(type)
      ? false
      : activeByExpiration;

  transaction.set(
    entitlementRef,
    {
      active,
      entitlementId: BHRIGU_PLUS_ENTITLEMENT,
      productId,
      plan,
      status: type || "unknown",
      store: String(event.store || "play_store"),
      environment: String(event.environment || "unknown"),
      expiresAt,
      lastRevenueCatEventId: eventRef.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  transaction.set(
    purchaseRef,
    {
      productId,
      productIds: eventProductIds(event),
      entitlementId: BHRIGU_PLUS_ENTITLEMENT,
      plan,
      active,
      status: type || "unknown",
      transactionId: transactionIdForEvent(event),
      expiresAt,
      revenueCatEventId: eventRef.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

function applyDakshanaEvent(transaction, uid, event, eventRef, walletDoc) {
  const type = eventTypeFor(event);
  const grantsCredits = DAKSHANA_GRANT_EVENTS.has(type);
  const revokesCredits = DAKSHANA_REVOKE_EVENTS.has(type);
  if (!grantsCredits && !revokesCredits) return;

  const walletRef = dakshanaWalletRef(uid);
  const purchaseRef = userPurchaseRef(uid, eventRef);
  const wallet = walletDoc?.data() || {};
  const transactionId = transactionIdForEvent(event);
  const existingCredits =
    Number(wallet.chat || 0) +
    Number(wallet.tarot || 0) +
    Number(wallet.geomancy || 0);

  if (revokesCredits) {
    transaction.set(
      walletRef,
      {
        active: false,
        chat: 0,
        tarot: 0,
        geomancy: 0,
        productId: DAKSHANA_PRODUCT,
        lastRevenueCatEventId: eventRef.id,
        revokedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    transaction.set(
      purchaseRef,
      {
        productId: DAKSHANA_PRODUCT,
        status: "revoked",
        transactionId,
        revenueCatEventId: eventRef.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return;
  }

  if (existingCredits > 0) {
    transaction.set(
      purchaseRef,
      {
        productId: DAKSHANA_PRODUCT,
        status: "blocked_duplicate_active_pack",
        transactionId,
        revenueCatEventId: eventRef.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return;
  }

  transaction.set(
    walletRef,
    {
      active: true,
      chat: DAKSHANA_CREDITS.chat,
      tarot: DAKSHANA_CREDITS.tarot,
      geomancy: DAKSHANA_CREDITS.geomancy,
      productId: DAKSHANA_PRODUCT,
      transactionId,
      lastRevenueCatEventId: eventRef.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  transaction.set(
    purchaseRef,
    {
      productId: DAKSHANA_PRODUCT,
      status: "granted",
      transactionId,
      revenueCatEventId: eventRef.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

exports.revenueCatWebhook = onRequest(
  {
    region: FUNCTION_REGION,
    secrets: [REVENUECAT_WEBHOOK_AUTH],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }

    const expectedAuth = `Bearer ${REVENUECAT_WEBHOOK_AUTH.value()}`;
    if (req.get("authorization") !== expectedAuth) {
      res.status(401).json({ error: "unauthorized" });
      return;
    }

    let payload;
    try {
      payload = parseRequestBody(req);
    } catch (error) {
      res.status(400).json({ error: "invalid_json" });
      return;
    }

    const event = eventFromPayload(payload);
    const type = eventTypeFor(event);
    const uid = uidFromEvent(event);
    const eventId = eventIdFor(event);

    if (!eventId) {
      res.status(400).json({ error: "missing_event_identity" });
      return;
    }

    const db = admin.firestore();
    const eventRef = db.collection("revenuecat_events").doc(eventId);

    try {
      const result = await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(eventRef);
        if (existing.exists) {
          return { duplicate: true };
        }

        const dakshanaEvent = uid ? isDakshanaEvent(event) : false;
        const dakshanaWalletDoc = dakshanaEvent
          ? await transaction.get(dakshanaWalletRef(uid))
          : null;

        const productIds = eventProductIds(event);

        const ignored = IGNORED_WEBHOOK_EVENTS.has(type) || !uid;

        transaction.set(eventRef, {
          uid: uid || null,
          type: type || "unknown",
          productId: productIds[0] || "",
          productIds,
          appUserId: String(event.app_user_id || ""),
          originalAppUserId: String(event.original_app_user_id || ""),
          transactionId: transactionIdForEvent(event),
          environment: String(event.environment || "unknown"),
          ignored,
          receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (ignored) {
          return { duplicate: false, ignored: true };
        }

        if (isPlusEvent(event)) {
          applyPlusEvent(transaction, uid, event, eventRef);
        }

        if (dakshanaEvent) {
          applyDakshanaEvent(
            transaction,
            uid,
            event,
            eventRef,
            dakshanaWalletDoc
          );
        }

        return { duplicate: false };
      });

      res.status(200).json({ ok: true, ...result });
    } catch (error) {
      console.error("RevenueCat webhook failed:", error);
      res.status(500).json({ error: "webhook_failed" });
    }
  }
);

exports.getMonetizationStatus = onCall(
  callableRuntimeOptions({
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);

    try {
      return await getMonetizationStatusForUid(auth.uid);
    } catch (error) {
      console.error("Monetization status failed:", error);
      throw new HttpsError(
        "internal",
        "Could not load monetization status."
      );
    }
  }
);
