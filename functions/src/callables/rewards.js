const {
  onCall,
  admin,
  FUNCTION_REGION,
  callableRuntimeOptions,
  requireCallableAuth,
} = require("../core");

const TAROT_REWARD_TYPE = "tarot";
const GEOMANCY_REWARD_TYPE = "geomancy";

function rewardRef(uid) {
  return admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("rewards")
    .doc("streak_calendar");
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function stateFromData(data = {}) {
  return {
    rewardCycleDay:
      typeof data.rewardCycleDay === "number" ? data.rewardCycleDay : 0,
    freeRewardAvailable: data.freeRewardAvailable === true,
    freeRewardType:
      typeof data.freeRewardType === "string" ? data.freeRewardType : null,
    lastClaimDate:
      typeof data.lastClaimDate === "string" ? data.lastClaimDate : null,
  };
}

exports.loadStreakReward = onCall(
  callableRuntimeOptions({
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const doc = await rewardRef(auth.uid).get();

    return stateFromData(doc.data() || {});
  }
);

exports.claimDailyStreakReward = onCall(
  callableRuntimeOptions({
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const ref = rewardRef(auth.uid);
    const today = todayKey();

    return admin.firestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(ref);
      const data = doc.data() || {};
      const oldStreakCount =
        typeof data.streakCount === "number" ? data.streakCount : 0;
      const oldCycleDay =
        typeof data.rewardCycleDay === "number" ? data.rewardCycleDay : 0;
      const oldLastClaimDate =
        typeof data.lastClaimDate === "string" ? data.lastClaimDate : null;
      const hasPendingReward = data.freeRewardAvailable === true;

      if (oldLastClaimDate === today) {
        return {
          state: stateFromData(data),
          unlockedReward: false,
          carriedPendingReward: hasPendingReward,
          alreadyClaimed: true,
        };
      }

      const newStreakCount = oldStreakCount + 1;
      const newCycleDay = hasPendingReward ? oldCycleDay : oldCycleDay + 1;
      const shouldUnlockReward = !hasPendingReward && newCycleDay >= 4;
      const rewardType = shouldUnlockReward
        ? newStreakCount % 8 === 0
          ? GEOMANCY_REWARD_TYPE
          : TAROT_REWARD_TYPE
        : typeof data.freeRewardType === "string"
          ? data.freeRewardType
          : null;
      const updatedCycleDay = shouldUnlockReward ? 0 : newCycleDay;
      const updatedDaysUntilReward =
        shouldUnlockReward || hasPendingReward ? 0 : 4 - updatedCycleDay;

      const update = {
        streakCount: newStreakCount,
        rewardCycleDay: updatedCycleDay,
        daysUntilReward: updatedDaysUntilReward,
        lastClaimDate: today,
        freeRewardAvailable: shouldUnlockReward || hasPendingReward,
        freeRewardType: rewardType,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (shouldUnlockReward) {
        update.unlockedAt = admin.firestore.FieldValue.serverTimestamp();
      }

      transaction.set(ref, update, { merge: true });

      return {
        state: {
          rewardCycleDay: updatedCycleDay,
          freeRewardAvailable: shouldUnlockReward || hasPendingReward,
          freeRewardType: rewardType,
          lastClaimDate: today,
        },
        unlockedReward: shouldUnlockReward,
        carriedPendingReward: hasPendingReward,
        alreadyClaimed: false,
      };
    });
  }
);

exports.consumeFreeReward = onCall(
  callableRuntimeOptions({
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const ref = rewardRef(auth.uid);

    await ref.set(
      {
        freeRewardAvailable: false,
        freeRewardType: null,
        rewardCycleDay: 0,
        daysUntilReward: 4,
        openedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return stateFromData({
      freeRewardAvailable: false,
      freeRewardType: null,
      rewardCycleDay: 0,
      daysUntilReward: 4,
    });
  }
);
