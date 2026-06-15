const BHRIGU_PLUS_ENTITLEMENT = "bhrigu_plus";
const BHRIGU_PLUS_PRODUCT = "bhrigu_plus";
const DAKSHANA_PRODUCT = "dakshana_pack_1";

const DAKSHANA_CREDITS = {
  chat: 5,
  tarot: 1,
  geomancy: 1,
};

const PLAN_LIMITS = {
  free: {},
  monthly: {
    chat: 50,
    tarot: 20,
    geomancy: 20,
    circleCompatibility: 1,
  },
  yearly: {
    chat: 1500,
    chatDaily: 100,
    tarot: 300,
    geomancy: 300,
    circleCompatibility: 1,
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
  return String(process.env.MONETIZATION_ENFORCEMENT_MODE || "off")
    .trim()
    .toLowerCase() || "off";
}

module.exports = {
  BHRIGU_PLUS_ENTITLEMENT,
  BHRIGU_PLUS_PRODUCT,
  DAKSHANA_PRODUCT,
  DAKSHANA_CREDITS,
  PLAN_LIMITS,
  ACTIVE_SUBSCRIPTION_EVENTS,
  INACTIVE_SUBSCRIPTION_EVENTS,
  DAKSHANA_GRANT_EVENTS,
  DAKSHANA_REVOKE_EVENTS,
  monetizationMode,
};
