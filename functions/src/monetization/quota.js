const { admin } = require("../core");
const {
  PLAN_LIMITS,
  monetizationMode,
} = require("./catalog");

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
  const plusActive =
    entitlement.active === true &&
    timestampIsFutureOrMissing(entitlement.expiresAt);
  const plan = plusActive
    ? String(entitlement.plan || "monthly")
    : "free";

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
      circleCompatibility: readInt(quota.circleCompatibility),
    },
    limits: PLAN_LIMITS[plan] || {},
  };
}

module.exports = {
  monthKey,
  getMonetizationStatusForUid,
};
