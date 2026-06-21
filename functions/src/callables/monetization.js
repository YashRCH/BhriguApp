const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const {
  onCall,
  HttpsError,
  admin,
  axios,
  crypto,
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
const REVENUECAT_SECRET_API_KEY = defineSecret("REVENUECAT_SECRET_API_KEY");
const REVENUECAT_SUBSCRIBER_API_BASE =
  "https://api.revenuecat.com/v1/subscribers";
const IGNORED_WEBHOOK_EVENTS = new Set(["TEST"]);

function webhookAuthorizationMatches(req) {
  const auth = String(req.get("authorization") || "").trim();
  const secret = String(REVENUECAT_WEBHOOK_AUTH.value() || "").trim();

  if (!auth || !secret) {
    return false;
  }

  const bareAuth = auth.replace(/^bearer\s+/i, "").trim();
  const bareSecret = secret.replace(/^bearer\s+/i, "").trim();

  return timingSafeStringEqual(bareAuth, bareSecret);
}

function timingSafeStringEqual(left, right) {
  const leftBuffer = Buffer.from(String(left || ""), "utf8");
  const rightBuffer = Buffer.from(String(right || ""), "utf8");
  if (leftBuffer.length !== rightBuffer.length) return false;
  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function webhookRequestMeta(req) {
  const authorization = String(req.get("authorization") || "").trim();
  return {
    userAgent: String(req.get("user-agent") || "").slice(0, 160),
    hasAuthorization: authorization.length > 0,
    authorizationScheme: authorization.includes(" ")
      ? authorization.split(/\s+/)[0]
      : "raw",
  };
}

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
  const explicitId = String(event.id || event.event_id || "").trim();
  if (explicitId) return explicitId;

  const fallbackPayload = JSON.stringify({
    type: event.type || "",
    app_user_id: event.app_user_id || "",
    product_id: event.product_id || "",
    transaction_id: transactionIdForEvent(event),
    event_timestamp_ms: event.event_timestamp_ms || "",
    expiration_at_ms: event.expiration_at_ms || "",
    aliases: stringArray(event.aliases),
    transferred_from: stringArray(event.transferred_from),
    transferred_to: stringArray(event.transferred_to),
  });

  return crypto.createHash("sha256").update(fallbackPayload).digest("hex");
}

function isRevenueCatAnonymousId(value) {
  const id = String(value || "").trim();
  return (
    !id ||
    id.startsWith("$RCAnonymousID") ||
    id.toLowerCase().includes("anonymous")
  );
}

function isSafeFirestoreDocId(value) {
  const id = String(value || "").trim();
  return id.length > 0 && id.length < 512 && !id.includes("/");
}

function stringArray(value) {
  return Array.isArray(value)
    ? value.map((item) => String(item || "").trim()).filter(Boolean)
    : [];
}

function uniqueStrings(values) {
  return [...new Set(values.map((value) => String(value || "").trim()))]
    .filter(Boolean);
}

function userIdCandidatesFromEvent(event) {
  return uniqueStrings([
    event.app_user_id,
    event.original_app_user_id,
    ...stringArray(event.aliases),
    ...stringArray(event.transferred_to),
  ]).filter(isSafeFirestoreDocId);
}

async function uidFromEvent(event) {
  const candidates = userIdCandidatesFromEvent(event);
  const nonAnonymous = candidates.filter(
    (candidate) => !isRevenueCatAnonymousId(candidate)
  );
  const lookupCandidates = nonAnonymous.length ? nonAnonymous : candidates;

  for (const candidate of lookupCandidates) {
    const userDoc = await admin.firestore().collection("users").doc(candidate).get();
    if (userDoc.exists) return candidate;
  }

  return nonAnonymous[0] || "";
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

function normalizedPlanSignalText(values) {
  return values
    .map((value) => String(value || "").trim().toLowerCase())
    .filter(Boolean)
    .join(" ")
    .replace(/[^a-z0-9]+/g, " ");
}

function containsAnyPlanSignal(text, signals) {
  const normalized = normalizedPlanSignalText([text]);
  const tokens = new Set(normalized.split(" ").filter(Boolean));
  const compact = normalized.replace(/\s+/g, "");

  return signals.some((signal) => {
    const normalizedSignal = normalizedPlanSignalText([signal]);
    if (!normalizedSignal) return false;

    const signalCompact = normalizedSignal.replace(/\s+/g, "");
    const compactSignalCanBeEmbedded = /\d/.test(signalCompact);
    if (normalizedSignal.includes(" ")) {
      return normalized === normalizedSignal ||
        compact === signalCompact ||
        (compactSignalCanBeEmbedded && compact.includes(signalCompact));
    }

    return tokens.has(normalizedSignal) ||
      compact === signalCompact ||
      (compactSignalCanBeEmbedded && compact.includes(signalCompact));
  });
}

function planFromSignalText(text) {
  const normalized = normalizedPlanSignalText([text]);
  if (
    containsAnyPlanSignal(normalized, [
      "annual",
      "annually",
      "yearly",
      "year",
      "p1y",
      "p12m",
      "1y",
      "12m",
      "12month",
      "12 month",
      "12 months",
    ])
  ) {
    return "yearly";
  }

  if (
    containsAnyPlanSignal(normalized, [
      "monthly",
      "month",
      "p1m",
      "1m",
      "1 month",
    ])
  ) {
    return "monthly";
  }

  return "";
}

function planFromSubscriptionDuration(purchasedAt, expiresAt, { sandbox = false } = {}) {
  if (!purchasedAt || !expiresAt) return "";

  const subscriptionDays = (expiresAt - purchasedAt) / 86400000;
  if (sandbox) {
    if (subscriptionDays >= 20 / 1440) {
      return "yearly";
    }

    if (subscriptionDays > 0) {
      return "monthly";
    }

    return "";
  }

  if (subscriptionDays >= 300) {
    return "yearly";
  }

  if (subscriptionDays >= 20 && subscriptionDays <= 45) {
    return "monthly";
  }

  return "";
}

function normalizedStoredPlan(value) {
  const plan = String(value || "").trim().toLowerCase();
  return plan === "yearly" || plan === "annual"
    ? "yearly"
    : plan === "monthly"
      ? "monthly"
      : "";
}

function resolvePlusPlan(detectedPlan, existingPlan, { active = true } = {}) {
  const detected = normalizedStoredPlan(detectedPlan);
  if (detected) return detected;

  const existing = normalizedStoredPlan(existingPlan);
  if (existing) return existing;

  return active ? "monthly" : "free";
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
  const planFromText = planFromSignalText(
    normalizedPlanSignalText([
    event.period_type || "",
      event.period || "",
      event.billing_period || "",
    event.presented_offering_identifier || "",
    event.presented_offering_id || "",
      event.package_identifier || "",
      event.package_id || "",
    event.product_id || "",
    event.new_product_id || "",
    event.product_identifier || "",
    event.new_product_identifier || "",
    event.store_product_id || "",
      event.base_plan_id || "",
      event.base_plan_identifier || "",
      event.product_plan_identifier || "",
      event.subscription_plan_id || "",
    ])
  );
  if (planFromText) return planFromText;

  const purchasedAt = numberFromMillis(
    event.purchased_at_ms || event.event_timestamp_ms
  );
  const expiresAt = numberFromMillis(event.expiration_at_ms);
  const planFromDuration = planFromSubscriptionDuration(purchasedAt, expiresAt, {
    sandbox: String(event.environment || "").toLowerCase() === "sandbox",
  });
  if (planFromDuration) return planFromDuration;

  return "";
}

function millisFromRevenueCatDate(value) {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    return value;
  }

  if (typeof value === "string" && value.trim()) {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
  }

  return null;
}

function timestampFromRevenueCatDate(value) {
  const millis = millisFromRevenueCatDate(value);
  return millis ? admin.firestore.Timestamp.fromMillis(millis) : null;
}

function firestoreMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (typeof value.toDate === "function") return value.toDate().getTime();
  return numberFromMillis(value) || millisFromRevenueCatDate(value);
}

function revenueCatEventTimestampMs(event) {
  return numberFromMillis(event.event_timestamp_ms) ||
    numberFromMillis(event.purchased_at_ms) ||
    numberFromMillis(event.purchase_at_ms) ||
    null;
}

function revenueCatProductIds(value) {
  return uniqueStrings([
    value?.product_identifier,
    value?.product_id,
    value?.store_product_identifier,
    value?.base_plan_id,
    value?.base_plan_identifier,
    value?.product_plan_identifier,
    value?.subscription_plan_id,
  ]);
}

function revenueCatSubscriptionForEntitlement(subscriber = {}, entitlement = {}) {
  const subscriptions = subscriber?.subscriptions || {};
  const productIds = revenueCatProductIds(entitlement);

  for (const productId of productIds) {
    if (subscriptions[productId]) {
      return {
        ...subscriptions[productId],
        product_identifier: productId,
      };
    }
  }

  const activeSubscriptions = Object.entries(subscriptions)
    .map(([productId, subscription]) => ({
      ...(subscription || {}),
      product_identifier: productId,
    }))
    .filter((subscription) => revenueCatEntitlementIsActive(subscription));

  return activeSubscriptions[0] || null;
}

function planFromRevenueCatPurchase(value = {}) {
  const planFromText = planFromSignalText(
    normalizedPlanSignalText([
      ...revenueCatProductIds(value),
      value.period,
      value.period_type,
      value.billing_period,
      value.package_identifier,
      value.package_id,
      value.presented_offering_identifier,
      value.presented_offering_id,
    ])
  );
  if (planFromText) return planFromText;

  const purchasedAt = millisFromRevenueCatDate(
    value.purchase_date || value.original_purchase_date
  );
  const expiresAt = millisFromRevenueCatDate(value.expires_date);
  const planFromDuration = planFromSubscriptionDuration(purchasedAt, expiresAt, {
    sandbox: value.is_sandbox === true ||
      String(value.environment || "").toLowerCase() === "sandbox",
  });
  if (planFromDuration) return planFromDuration;

  return "";
}

function planFromRevenueCatSubscriber(subscriber = {}, entitlement = {}) {
  const subscription = revenueCatSubscriptionForEntitlement(
    subscriber,
    entitlement
  );

  return planFromRevenueCatPurchase(subscription || entitlement);
}

function revenueCatEntitlementIsActive(value = {}, now = Date.now()) {
  const expiresAt = millisFromRevenueCatDate(value.expires_date);
  return !expiresAt || expiresAt > now;
}

function activePlusEntitlementFromSubscriber(subscriber = {}) {
  const entitlement =
    subscriber?.entitlements?.[BHRIGU_PLUS_ENTITLEMENT] || null;
  if (!entitlement || !revenueCatEntitlementIsActive(entitlement)) {
    return null;
  }

  return entitlement;
}

function allDakshanaPurchasesFromSubscriber(subscriber = {}) {
  const purchases = subscriber?.non_subscriptions?.[DAKSHANA_PRODUCT];
  if (!Array.isArray(purchases)) return [];

  return purchases
    .filter((purchase) => purchase && typeof purchase === "object")
    .map((purchase) => ({
      ...purchase,
      product_identifier: DAKSHANA_PRODUCT,
    }))
    .sort((a, b) => {
      return (
        (millisFromRevenueCatDate(b.purchase_date) || 0) -
        (millisFromRevenueCatDate(a.purchase_date) || 0)
      );
    });
}

function revenueCatPurchaseTransactionId(purchase = {}) {
  return String(
    purchase.store_transaction_id ||
      purchase.transaction_id ||
      purchase.id ||
      [
        purchase.product_identifier,
        purchase.purchase_date,
      ].filter(Boolean).join("_")
  ).trim();
}

function syncPurchaseDocId(prefix, transactionId) {
  const safeHash = crypto
    .createHash("sha256")
    .update(String(transactionId || ""))
    .digest("hex")
    .slice(0, 40);

  return `${prefix}_${safeHash}`;
}

function isPlusEvent(event) {
  const entitlementIds = [
    event.entitlement_id,
    ...(Array.isArray(event.entitlement_ids) ? event.entitlement_ids : []),
  ].filter(Boolean);

  return eventMatchesProduct(event, BHRIGU_PLUS_PRODUCT) ||
    entitlementIds.includes(BHRIGU_PLUS_ENTITLEMENT);
}

function isDakshanaEvent(event) {
  return eventMatchesProduct(event, DAKSHANA_PRODUCT);
}

function plusEntitlementRef(uid) {
  return admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("entitlements")
    .doc(BHRIGU_PLUS_ENTITLEMENT);
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

function shouldIgnoreStalePlusEvent(existingEntitlement, event, expiresAt) {
  const existingEventMs = numberFromMillis(
    existingEntitlement.lastRevenueCatEventTimestampMs
  );
  const incomingEventMs = revenueCatEventTimestampMs(event);

  if (existingEventMs && incomingEventMs && incomingEventMs < existingEventMs) {
    return true;
  }

  const existingExpiresMs = firestoreMillis(existingEntitlement.expiresAt);
  const incomingExpiresMs = firestoreMillis(expiresAt);
  return Boolean(
    existingEntitlement.active === true &&
      existingExpiresMs &&
      incomingExpiresMs &&
      incomingExpiresMs < existingExpiresMs
  );
}

function applyPlusEvent(transaction, uid, event, eventRef, entitlementDoc) {
  const type = eventTypeFor(event);
  const productId = primaryProductId(event, BHRIGU_PLUS_PRODUCT);
  const entitlementRef = plusEntitlementRef(uid);
  const purchaseRef = userPurchaseRef(uid, eventRef);
  const expiresAt = timestampFromMillis(event.expiration_at_ms);
  const incomingEventTimestampMs = revenueCatEventTimestampMs(event);
  const activeByExpiration =
    !expiresAt || expiresAt.toMillis() > Date.now();
  const active = ACTIVE_SUBSCRIPTION_EVENTS.has(type)
    ? activeByExpiration
    : INACTIVE_SUBSCRIPTION_EVENTS.has(type)
      ? false
      : activeByExpiration;
  const existingEntitlement = entitlementDoc?.data() || {};
  const detectedPlan = planFromEvent(event);
  const plan = resolvePlusPlan(detectedPlan, existingEntitlement.plan, {
    active,
  });
  const stale = shouldIgnoreStalePlusEvent(
    existingEntitlement,
    event,
    expiresAt
  );

  if (!stale) {
    transaction.set(
      entitlementRef,
      {
        active,
        entitlementId: BHRIGU_PLUS_ENTITLEMENT,
        productId,
        plan,
        planDetected: detectedPlan || null,
        status: type || "unknown",
        store: String(event.store || "play_store"),
        environment: String(event.environment || "unknown"),
        expiresAt,
        lastRevenueCatEventId: eventRef.id,
        lastRevenueCatEventTimestampMs: incomingEventTimestampMs,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  transaction.set(
    purchaseRef,
    {
      productId,
      productIds: eventProductIds(event),
      entitlementId: BHRIGU_PLUS_ENTITLEMENT,
      plan,
      planDetected: detectedPlan || null,
      active,
      status: stale ? "stale_ignored" : type || "unknown",
      stale,
      transactionId: transactionIdForEvent(event),
      expiresAt,
      revenueCatEventId: eventRef.id,
      revenueCatEventTimestampMs: incomingEventTimestampMs,
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
  const walletTransactionId = String(wallet.transactionId || "").trim();
  const existingCredits =
    Number(wallet.chat || 0) +
    Number(wallet.tarot || 0) +
    Number(wallet.geomancy || 0);

  if (revokesCredits) {
    const activeWalletMatchesEvent =
      existingCredits > 0 &&
      wallet.active === true &&
      transactionId &&
      walletTransactionId === transactionId;
    const shouldRevokeWallet =
      activeWalletMatchesEvent ||
      existingCredits <= 0 ||
      wallet.active !== true;

    if (shouldRevokeWallet) {
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
    }

    transaction.set(
      purchaseRef,
      {
        productId: DAKSHANA_PRODUCT,
        status: shouldRevokeWallet ? "revoked" : "revoked_stale_ignored",
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

async function readTransferState(transaction, event) {
  if (eventTypeFor(event) !== "TRANSFER") return null;

  const targetUid = stringArray(event.transferred_to)
    .filter((value) => !isRevenueCatAnonymousId(value))
    .filter(isSafeFirestoreDocId)[0];
  const sourceUids = stringArray(event.transferred_from)
    .filter(isSafeFirestoreDocId);

  if (!targetUid || sourceUids.length === 0) return null;

  const db = admin.firestore();
  const sourceRefs = sourceUids.map((sourceUid) => ({
    sourceUid,
    entitlementRef: db
      .collection("users")
      .doc(sourceUid)
      .collection("entitlements")
      .doc(BHRIGU_PLUS_ENTITLEMENT),
    walletRef: db
      .collection("users")
      .doc(sourceUid)
      .collection("wallet")
      .doc("dakshana"),
  }));

  const entitlementDocs = await Promise.all(
    sourceRefs.map((source) => transaction.get(source.entitlementRef))
  );
  const walletDocs = await Promise.all(
    sourceRefs.map((source) => transaction.get(source.walletRef))
  );
  const sourceStates = sourceRefs.map((source, index) => ({
    sourceUid: source.sourceUid,
    entitlementExists: entitlementDocs[index].exists,
    walletExists: walletDocs[index].exists,
  }));

  return {
    targetUid,
    sourceUids,
    sourceStates,
    entitlement: entitlementDocs
      .map((doc) => doc.data() || null)
      .find((data) => data?.active === true) || null,
    wallet: walletDocs
      .map((doc) => doc.data() || null)
      .find((data) =>
        Number(data?.chat || 0) +
          Number(data?.tarot || 0) +
          Number(data?.geomancy || 0) > 0
      ) || null,
  };
}

function applyTransferEvent(transaction, transferState, eventRef) {
  if (!transferState?.targetUid) return false;

  const db = admin.firestore();
  const targetUid = transferState.targetUid;
  const userRef = db.collection("users").doc(targetUid);
  const eventPayload = {
    transferSourceUids: transferState.sourceUids,
    lastRevenueCatEventId: eventRef.id,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  let applied = false;

  if (transferState.entitlement) {
    transaction.set(
      userRef.collection("entitlements").doc(BHRIGU_PLUS_ENTITLEMENT),
      {
        ...transferState.entitlement,
        ...eventPayload,
      },
      { merge: true }
    );
    applied = true;
  }

  if (transferState.wallet) {
    transaction.set(
      userRef.collection("wallet").doc("dakshana"),
      {
        ...transferState.wallet,
        ...eventPayload,
      },
      { merge: true }
    );
    applied = true;
  }

  for (const source of transferState.sourceStates || []) {
    const sourceUid = String(source.sourceUid || "").trim();
    if (!sourceUid || sourceUid === targetUid) continue;

    const sourceRef = db.collection("users").doc(sourceUid);
    const transferOutPayload = {
      transferredTo: targetUid,
      lastRevenueCatEventId: eventRef.id,
      transferredAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (source.entitlementExists) {
      transaction.set(
        sourceRef.collection("entitlements").doc(BHRIGU_PLUS_ENTITLEMENT),
        {
          active: false,
          status: "transferred_out",
          ...transferOutPayload,
        },
        { merge: true }
      );
      applied = true;
    }

    if (source.walletExists) {
      transaction.set(
        sourceRef.collection("wallet").doc("dakshana"),
        {
          active: false,
          chat: 0,
          tarot: 0,
          geomancy: 0,
          status: "transferred_out",
          ...transferOutPayload,
        },
        { merge: true }
      );
      applied = true;
    }
  }

  return applied;
}

async function fetchRevenueCatSubscriber(uid) {
  const apiKey = String(REVENUECAT_SECRET_API_KEY.value() || "").trim();
  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "RevenueCat server API key is not configured."
    );
  }

  try {
    const response = await axios.get(
      `${REVENUECAT_SUBSCRIBER_API_BASE}/${encodeURIComponent(uid)}`,
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          Accept: "application/json",
        },
        timeout: 12000,
        validateStatus: (status) => status < 500,
      }
    );

    if (response.status === 404) return null;

    if (response.status === 401 || response.status === 403) {
      throw new HttpsError(
        "failed-precondition",
        "RevenueCat server API key was rejected."
      );
    }

    if (response.status < 200 || response.status >= 300) {
      throw new HttpsError(
        "unavailable",
        "RevenueCat subscriber sync failed."
      );
    }

    return response.data?.subscriber || {};
  } catch (error) {
    if (error instanceof HttpsError) throw error;

    console.error("RevenueCat subscriber API failed:", {
      status: error.response?.status || null,
      message: error.message,
    });
    throw new HttpsError(
      "unavailable",
      "RevenueCat subscriber sync failed."
    );
  }
}

async function syncRevenueCatSubscriberToFirestore(uid, subscriber) {
  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const entitlementRef = userRef
    .collection("entitlements")
    .doc(BHRIGU_PLUS_ENTITLEMENT);
  const walletRef = userRef.collection("wallet").doc("dakshana");
  const rawPlusEntitlement =
    subscriber?.entitlements?.[BHRIGU_PLUS_ENTITLEMENT] || null;
  const activePlusEntitlement =
    activePlusEntitlementFromSubscriber(subscriber);
  const dakshanaPurchases =
    allDakshanaPurchasesFromSubscriber(subscriber).slice(0, 1);
  const latestDakshanaPurchase = dakshanaPurchases[0] || null;
  const latestDakshanaTransactionId = latestDakshanaPurchase
    ? revenueCatPurchaseTransactionId(latestDakshanaPurchase)
    : "";
  const latestDakshanaPurchaseRef = latestDakshanaTransactionId
    ? userRef
        .collection("purchases")
        .doc(syncPurchaseDocId("revenuecat_api", latestDakshanaTransactionId))
    : null;

  return db.runTransaction(async (transaction) => {
    const [entitlementDoc, walletDoc, latestDakshanaPurchaseDoc] = await Promise.all([
      transaction.get(entitlementRef),
      latestDakshanaPurchaseRef ? transaction.get(walletRef) : null,
      latestDakshanaPurchaseRef
        ? transaction.get(latestDakshanaPurchaseRef)
        : null,
    ]);

    const result = {
      plusActive: false,
      plan: "free",
      dakshanaGranted: false,
      dakshanaPurchaseAlreadySynced: false,
      dakshanaBlockedByActivePack: false,
      plusEntitlementMissing: false,
    };

    if (rawPlusEntitlement) {
      const productIds = revenueCatProductIds(rawPlusEntitlement);
      const productId = productIds[0] || BHRIGU_PLUS_PRODUCT;
      const expiresAt = timestampFromRevenueCatDate(
        rawPlusEntitlement.expires_date
      );
      const active = Boolean(activePlusEntitlement);
      const detectedPlan = planFromRevenueCatSubscriber(
        subscriber,
        rawPlusEntitlement
      );
      const existingEntitlement = entitlementDoc?.data() || {};
      const plan = resolvePlusPlan(detectedPlan, existingEntitlement.plan, {
        active,
      });

      transaction.set(
        entitlementRef,
        {
          active,
          entitlementId: BHRIGU_PLUS_ENTITLEMENT,
          productId,
          productIds,
          plan,
          planDetected: detectedPlan || null,
          status: active ? "active" : "expired",
          store: String(rawPlusEntitlement.store || "play_store"),
          environment: "revenuecat_api",
          expiresAt,
          lastRevenueCatSyncAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      result.plusActive = active;
      result.plan = active ? plan : "free";
    } else {
      result.plusEntitlementMissing = true;
      transaction.set(
        entitlementRef,
        {
          active: false,
          entitlementId: BHRIGU_PLUS_ENTITLEMENT,
          plan: "free",
          status: "missing",
          productId: BHRIGU_PLUS_PRODUCT,
          productIds: [],
          store: "play_store",
          environment: "revenuecat_api",
          expiresAt: null,
          lastRevenueCatSyncAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    if (!latestDakshanaPurchaseRef || !latestDakshanaPurchase) {
      return result;
    }

    if (latestDakshanaPurchaseDoc?.exists) {
      result.dakshanaPurchaseAlreadySynced = true;
      return result;
    }

    const wallet = walletDoc?.data() || {};
    const existingCredits =
      Number(wallet.chat || 0) +
      Number(wallet.tarot || 0) +
      Number(wallet.geomancy || 0);
    const purchaseRecord = {
      productId: DAKSHANA_PRODUCT,
      productIds: revenueCatProductIds(latestDakshanaPurchase),
      transactionId: latestDakshanaTransactionId,
      purchaseDate: latestDakshanaPurchase.purchase_date || null,
      store: String(latestDakshanaPurchase.store || "play_store"),
      source: "revenuecat_api",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (existingCredits > 0) {
      transaction.set(
        latestDakshanaPurchaseRef,
        {
          ...purchaseRecord,
          status: "blocked_duplicate_active_pack",
        },
        { merge: true }
      );
      result.dakshanaBlockedByActivePack = true;
      return result;
    }

    transaction.set(
      walletRef,
      {
        active: true,
        chat: DAKSHANA_CREDITS.chat,
        tarot: DAKSHANA_CREDITS.tarot,
        geomancy: DAKSHANA_CREDITS.geomancy,
        productId: DAKSHANA_PRODUCT,
        transactionId: latestDakshanaTransactionId,
        lastRevenueCatSyncAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    transaction.set(
      latestDakshanaPurchaseRef,
      {
        ...purchaseRecord,
        status: "granted",
      },
      { merge: true }
    );

    result.dakshanaGranted = true;
    return result;
  });
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

    if (!webhookAuthorizationMatches(req)) {
      console.warn("RevenueCat webhook unauthorized:", webhookRequestMeta(req));
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
    const uid = await uidFromEvent(event);
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

        const plusEvent = uid ? isPlusEvent(event) : false;
        const dakshanaEvent = uid ? isDakshanaEvent(event) : false;
        const plusEntitlementDoc = plusEvent
          ? await transaction.get(plusEntitlementRef(uid))
          : null;
        const dakshanaWalletDoc = dakshanaEvent
          ? await transaction.get(dakshanaWalletRef(uid))
          : null;
        const transferState = await readTransferState(transaction, event);

        const productIds = eventProductIds(event);

        const ignored = IGNORED_WEBHOOK_EVENTS.has(type) ||
          (!uid && !transferState?.targetUid);

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

        if (type === "TRANSFER") {
          const transferApplied = applyTransferEvent(
            transaction,
            transferState,
            eventRef
          );
          return { duplicate: false, transferApplied };
        }

        if (plusEvent) {
          applyPlusEvent(transaction, uid, event, eventRef, plusEntitlementDoc);
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

        return { duplicate: false, uid };
      });

      console.info("RevenueCat webhook processed:", {
        type,
        uid: uid || null,
        eventId,
        productIds: eventProductIds(event),
        result,
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

exports.syncRevenueCatPurchases = onCall(
  callableRuntimeOptions({
    region: FUNCTION_REGION,
    secrets: [REVENUECAT_SECRET_API_KEY],
  }),
  async (request) => {
    const auth = requireCallableAuth(request);

    try {
      const subscriber = await fetchRevenueCatSubscriber(auth.uid);
      const syncResult = subscriber
        ? await syncRevenueCatSubscriberToFirestore(auth.uid, subscriber)
        : { subscriberMissing: true };
      const status = await getMonetizationStatusForUid(auth.uid);

      return {
        synced: true,
        syncResult,
        status,
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error("RevenueCat purchase sync failed:", error);
      throw new HttpsError(
        "internal",
        "Could not sync RevenueCat purchases."
      );
    }
  }
);
