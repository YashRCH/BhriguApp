const BHRIGU_PLUS_ENTITLEMENT = "bhrigu_plus";
const BHRIGU_PLUS_PRODUCT = "bhrigu_plus";
const DAKSHANA_PRODUCT = "dakshana_pack_1";

const DAKSHANA_CREDITS = {
  chat: 5,
  tarot: 1,
  geomancy: 1,
};

const PLAN_LIMITS = {
  free: {
    chat: 5,
    tarot: 5,
    geomancy: 5,
  },
  monthly: {
    chat: 50,
    tarot: 20,
    geomancy: 20,
    manualMatch: 15,
  },
  yearly: {
    chat: 1500,
    chatDaily: 100,
    tarot: 300,
    geomancy: 300,
  },
};

const METERED_FEATURES = {
  chat: {
    quotaField: "chat",
    dakshanaField: "chat",
    label: "BHR1GU chat",
    unlimitedPlans: ["yearly"],
  },
  tarot: {
    quotaField: "tarot",
    dakshanaField: "tarot",
    label: "Tarot reading",
    unlimitedPlans: ["yearly"],
  },
  geomancy: {
    quotaField: "geomancy",
    dakshanaField: "geomancy",
    label: "Geomancy reading",
    unlimitedPlans: ["yearly"],
  },
  manualMatch: {
    quotaField: "manualMatch",
    dakshanaField: null,
    label: "Manual match",
    includedPlans: ["monthly", "yearly"],
    unlimitedPlans: ["yearly"],
  },
};

const ACTIVE_SUBSCRIPTION_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "SUBSCRIPTION_EXTENDED",
  "TEMPORARY_ENTITLEMENT_GRANT",
  "UNCANCELLATION",
  "PRODUCT_CHANGE",
]);

const INACTIVE_SUBSCRIPTION_EVENTS = new Set([
  "EXPIRATION",
]);

const DAKSHANA_GRANT_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "NON_RENEWING_PURCHASE",
]);

const DAKSHANA_REVOKE_EVENTS = new Set([
  "CANCELLATION",
]);

function monetizationMode() {
  return String(process.env.MONETIZATION_ENFORCEMENT_MODE || "enforce")
    .trim()
    .toLowerCase() || "enforce";
}

module.exports = {
  BHRIGU_PLUS_ENTITLEMENT,
  BHRIGU_PLUS_PRODUCT,
  DAKSHANA_PRODUCT,
  DAKSHANA_CREDITS,
  PLAN_LIMITS,
  METERED_FEATURES,
  ACTIVE_SUBSCRIPTION_EVENTS,
  INACTIVE_SUBSCRIPTION_EVENTS,
  DAKSHANA_GRANT_EVENTS,
  DAKSHANA_REVOKE_EVENTS,
  monetizationMode,
};
