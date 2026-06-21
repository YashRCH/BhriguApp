const { HttpsError, admin, axios, defineSecret } = require("../core");
const {
  BHRIGU_PLUS_ENTITLEMENT,
  BHRIGU_PLUS_PRODUCT,
  METERED_FEATURES,
  PLAN_LIMITS,
  monetizationMode,
} = require("./catalog");

const REVENUECAT_SECRET_API_KEY = defineSecret("REVENUECAT_SECRET_API_KEY");
const REVENUECAT_SUBSCRIBER_API_BASE =
  "https://api.revenuecat.com/v1/subscribers";
const REWARD_QUOTA_FIELDS = {
  chat: "rewardChat",
  tarot: "rewardTarot",
  geomancy: "rewardGeomancy",
};

function monthKey(date = new Date()) {
  return date.toISOString().slice(0, 7).replace("-", "");
}

function readInt(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }

  if (typeof value === "string") {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  return 0;
}

function timestampToIso(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return null;
}

function timestampIsFutureOrMissing(value, now = new Date()) {
  if (!value) return true;
  if (typeof value.toDate === "function") return value.toDate() > now;
  if (value instanceof Date) return value > now;
  return true;
}

function rewardCreditsFromQuota(quota = {}) {
  return {
    chat: readInt(quota.rewardChat),
    tarot: readInt(quota.rewardTarot),
    geomancy: readInt(quota.rewardGeomancy),
  };
}

function normalizedPlanForEntitlement(entitlement, plusActive) {
  if (!plusActive) return "free";

  const plan = String(entitlement.plan || "").trim().toLowerCase();
  if (PLAN_LIMITS[plan]) return plan;

  return "monthly";
}

function normalizedMonetizationMode() {
  const mode = monetizationMode();
  if (mode === "enforce" || mode === "enforced" || mode === "on") {
    return "enforce";
  }
  if (mode === "audit" || mode === "meter") {
    return "audit";
  }
  return "off";
}

function entitlementIsActive(entitlement, now = new Date()) {
  return entitlement.active === true &&
    timestampIsFutureOrMissing(entitlement.expiresAt, now);
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

function revenueCatProductIds(value) {
  return [
    value?.product_identifier,
    value?.product_id,
    value?.store_product_identifier,
    value?.base_plan_id,
    value?.base_plan_identifier,
    value?.product_plan_identifier,
    value?.subscription_plan_id,
  ]
    .map((item) => String(item || "").trim())
    .filter(Boolean);
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

function resolvePlusPlan(detectedPlan, existingPlan, { active = true } = {}) {
  const detected = normalizedStoredPlan(detectedPlan);
  if (detected) return detected;

  const existing = normalizedStoredPlan(existingPlan);
  if (existing) return existing;

  return active ? "monthly" : "free";
}

function normalizedStoredPlan(value) {
  const plan = String(value || "").trim().toLowerCase();
  return plan === "yearly" || plan === "annual"
    ? "yearly"
    : plan === "monthly"
      ? "monthly"
      : "";
}

function revenueCatEntitlementIsActive(value = {}, now = Date.now()) {
  const expiresAt = millisFromRevenueCatDate(value.expires_date);
  return !expiresAt || expiresAt > now;
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

  return Object.entries(subscriptions)
    .map(([productId, subscription]) => ({
      ...(subscription || {}),
      product_identifier: productId,
    }))
    .find((subscription) => revenueCatEntitlementIsActive(subscription)) ||
    null;
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

async function fetchRevenueCatSubscriber(uid) {
  const apiKey = String(REVENUECAT_SECRET_API_KEY.value() || "").trim();
  if (!apiKey) return null;

  try {
    const response = await axios.get(
      `${REVENUECAT_SUBSCRIBER_API_BASE}/${encodeURIComponent(uid)}`,
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          Accept: "application/json",
        },
        timeout: 10000,
        validateStatus: (status) => status < 500,
      }
    );

    if (response.status < 200 || response.status >= 300) return null;
    return response.data?.subscriber || null;
  } catch (error) {
    console.warn("RevenueCat quota preflight sync skipped:", {
      status: error.response?.status || null,
      message: error.message,
    });
    return null;
  }
}

async function syncActiveRevenueCatPlus(uid) {
  const subscriber = await fetchRevenueCatSubscriber(uid);
  const entitlement =
    subscriber?.entitlements?.[BHRIGU_PLUS_ENTITLEMENT] || null;

  if (!entitlement || !revenueCatEntitlementIsActive(entitlement)) {
    return false;
  }

  const subscription = revenueCatSubscriptionForEntitlement(
    subscriber,
    entitlement
  );
  const productIds = revenueCatProductIds(subscription || entitlement);
  const productId = productIds[0] || BHRIGU_PLUS_PRODUCT;
  const entitlementRef = admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("entitlements")
    .doc(BHRIGU_PLUS_ENTITLEMENT);
  const existingEntitlementDoc = await entitlementRef.get();
  const existingEntitlement = existingEntitlementDoc.data() || {};
  const detectedPlan = planFromRevenueCatPurchase(subscription || entitlement);
  const plan = resolvePlusPlan(detectedPlan, existingEntitlement.plan);

  await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("entitlements")
    .doc(BHRIGU_PLUS_ENTITLEMENT)
    .set(
      {
        active: true,
        entitlementId: BHRIGU_PLUS_ENTITLEMENT,
        productId,
        productIds,
        plan,
        planDetected: detectedPlan || null,
        status: "active",
        store: String(entitlement.store || subscription?.store || "play_store"),
        environment: "revenuecat_api_preflight",
        expiresAt: timestampFromRevenueCatDate(entitlement.expires_date),
        lastRevenueCatSyncAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  return true;
}

async function getMonetizationStatusForUid(uid) {
  const db = admin.firestore();
  const [entitlementDoc, walletDoc, quotaDoc] = await Promise.all([
    db
      .collection("users")
      .doc(uid)
      .collection("entitlements")
      .doc("bhrigu_plus")
      .get(),
    db.collection("users").doc(uid).collection("wallet").doc("dakshana").get(),
    db.collection("users").doc(uid).collection("quota").doc(monthKey()).get(),
  ]);

  const entitlement = entitlementDoc.data() || {};
  const wallet = walletDoc.data() || {};
  const quota = quotaDoc.data() || {};
  const plusActive = entitlementIsActive(entitlement);
  const plan = normalizedPlanForEntitlement(entitlement, plusActive);

  return {
    mode: monetizationMode(),
    plusActive,
    plan,
    plusExpiresAt: timestampToIso(entitlement.expiresAt),
    dakshana: {
      active: wallet.active === true,
      chat: readInt(wallet.chat),
      tarot: readInt(wallet.tarot),
      geomancy: readInt(wallet.geomancy),
    },
    usage: {
      chat: readInt(quota.chat),
      chatDaily: readInt(quota.chatDaily),
      tarot: readInt(quota.tarot),
      geomancy: readInt(quota.geomancy),
      manualMatch: readInt(quota.manualMatch),
    },
    rewards: rewardCreditsFromQuota(quota),
    limits: PLAN_LIMITS[plan] || {},
  };
}

async function requireMeteredFeature(uid, featureKey) {
  const feature = METERED_FEATURES[featureKey];
  if (!feature) {
    throw new HttpsError("internal", "Unknown monetized feature.");
  }

  const mode = normalizedMonetizationMode();
  if (mode === "off") {
    return { allowed: true, mode, charged: false, featureKey };
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const entitlementRef = userRef
    .collection("entitlements")
    .doc(BHRIGU_PLUS_ENTITLEMENT);
  const walletRef = userRef.collection("wallet").doc("dakshana");
  const quotaRef = userRef.collection("quota").doc(monthKey());

  const preflightEntitlementDoc = await entitlementRef.get();
  const preflightEntitlement = preflightEntitlementDoc.data() || {};
  if (!entitlementIsActive(preflightEntitlement)) {
    await syncActiveRevenueCatPlus(uid);
  }

  return db.runTransaction(async (transaction) => {
    const [entitlementDoc, walletDoc, quotaDoc] = await Promise.all([
      transaction.get(entitlementRef),
      transaction.get(walletRef),
      transaction.get(quotaRef),
    ]);

    const entitlement = entitlementDoc.data() || {};
    const wallet = walletDoc.data() || {};
    const quota = quotaDoc.data() || {};
    const plusActive = entitlementIsActive(entitlement);
    const plan = normalizedPlanForEntitlement(entitlement, plusActive);
    const limits = PLAN_LIMITS[plan] || {};
    const quotaField = feature.quotaField;
    const quotaLimit = readInt(limits[quotaField]);
    const currentUsage = readInt(quota[quotaField]);
    const increment = admin.firestore.FieldValue.increment(1);
    const dakshanaField = feature.dakshanaField;
    const walletCredits = dakshanaField ? readInt(wallet[dakshanaField]) : 0;
    const rewardQuotaField = REWARD_QUOTA_FIELDS[featureKey] || null;
    const rewardCredits = rewardQuotaField ? readInt(quota[rewardQuotaField]) : 0;
    const includedPlans = Array.isArray(feature.includedPlans)
      ? feature.includedPlans
      : null;
    const unlimitedPlans = Array.isArray(feature.unlimitedPlans)
      ? feature.unlimitedPlans
      : [];

    if (plusActive && includedPlans && !includedPlans.includes(plan)) {
      throw new HttpsError(
        "resource-exhausted",
        `${feature.label} is not included in your current BHR1GU Plus plan.`
      );
    }

    if (plusActive && unlimitedPlans.includes(plan)) {
      transaction.set(
        quotaRef,
        {
          [quotaField]: increment,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return { allowed: true, mode, charged: true, source: "plus", featureKey };
    }

    if (rewardQuotaField && rewardCredits > 0) {
      transaction.set(
        quotaRef,
        {
          [rewardQuotaField]: admin.firestore.FieldValue.increment(-1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return {
        allowed: true,
        mode,
        charged: true,
        source: "reward",
        featureKey,
      };
    }

    if (quotaLimit > 0 && currentUsage < quotaLimit) {
      transaction.set(
        quotaRef,
        {
          [quotaField]: increment,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return {
        allowed: true,
        mode,
        charged: true,
        source: plusActive ? "plus" : "free",
        featureKey,
      };
    }

    if (mode === "audit") {
      transaction.set(
        quotaRef,
        {
          [quotaField]: increment,
          auditOnly: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return { allowed: true, mode, charged: false, source: "audit", featureKey };
    }

    if (dakshanaField && wallet.active === true && walletCredits > 0) {
      transaction.set(
        walletRef,
        {
          [dakshanaField]: admin.firestore.FieldValue.increment(-1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return {
        allowed: true,
        mode,
        charged: true,
        source: "dakshana",
        featureKey,
      };
    }

    if (quotaLimit > 0 && currentUsage >= quotaLimit) {
      throw new HttpsError(
        "resource-exhausted",
        `${feature.label} monthly limit reached.`
      );
    }

    const requirement = feature.dakshanaField
      ? "BHR1GU Plus or an active Dakshana pack"
      : "BHR1GU Plus";

    throw new HttpsError(
      "resource-exhausted",
      `${feature.label} requires ${requirement}.`
    );
  });
}

async function refundMeteredFeatureCharge(uid, charge) {
  if (!charge?.charged || !charge.featureKey || !charge.source) {
    return false;
  }

  const feature = METERED_FEATURES[charge.featureKey];
  if (!feature) return false;

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);

  if (charge.source === "plus" || charge.source === "free") {
    const quotaField = feature.quotaField;
    if (!quotaField) return false;

    const quotaRef = userRef.collection("quota").doc(monthKey());
    await db.runTransaction(async (transaction) => {
      const quotaDoc = await transaction.get(quotaRef);
      const quota = quotaDoc.data() || {};
      const currentUsage = readInt(quota[quotaField]);

      transaction.set(
        quotaRef,
        {
          [quotaField]: Math.max(0, currentUsage - 1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
    return true;
  }

  if (charge.source === "dakshana") {
    const dakshanaField = feature.dakshanaField;
    if (!dakshanaField) return false;

    const walletRef = userRef.collection("wallet").doc("dakshana");
    await db.runTransaction(async (transaction) => {
      const walletDoc = await transaction.get(walletRef);
      const wallet = walletDoc.data() || {};
      const currentCredits = readInt(wallet[dakshanaField]);

      transaction.set(
        walletRef,
        {
          active: true,
          [dakshanaField]: currentCredits + 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
    return true;
  }

  if (charge.source === "reward") {
    const rewardQuotaField = REWARD_QUOTA_FIELDS[charge.featureKey] || null;
    if (!rewardQuotaField) return false;

    const quotaRef = userRef.collection("quota").doc(monthKey());
    await quotaRef.set(
      {
        [rewardQuotaField]: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return true;
  }

  return false;
}

module.exports = {
  monthKey,
  normalizedMonetizationMode,
  getMonetizationStatusForUid,
  requireMeteredFeature,
  refundMeteredFeatureCharge,
  REVENUECAT_SECRET_API_KEY,
};
