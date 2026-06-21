const {
  onCall,
  admin,
  FUNCTION_REGION,
  callableRuntimeOptions,
  requireCallableAuth,
} = require("../core");
const { monthKey } = require("../monetization/quota");

const TAROT_REWARD_TYPE = "tarot";
const GEOMANCY_REWARD_TYPE = "geomancy";
const OWL_MOON_BOND_TARGET = 4;
const OWL_GIFT_CHAT_MESSAGES = 5;
const OWL_REWARD_TYPES = new Set([
  TAROT_REWARD_TYPE,
  GEOMANCY_REWARD_TYPE,
]);

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

function owlStateRef(uid) {
  return admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("owlCompanion")
    .doc("state");
}

function quotaRef(uid) {
  return admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("quota")
    .doc(monthKey());
}

function owlClaimRef(uid, claimDate, claimedCount) {
  return admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("owlCompanionClaims")
    .doc(`${claimDate}_${claimedCount}`);
}

function validOwlRewardType(value) {
  return OWL_REWARD_TYPES.has(value) ? value : null;
}

function nextOwlRewardType(rewardClaimedCount) {
  return rewardClaimedCount % 2 === 0
    ? TAROT_REWARD_TYPE
    : GEOMANCY_REWARD_TYPE;
}

function readingRewardLabel(rewardType) {
  return rewardType === GEOMANCY_REWARD_TYPE ? "geomancy" : "tarot";
}

function rewardQuotaFieldForType(rewardType) {
  return rewardType === GEOMANCY_REWARD_TYPE ? "rewardGeomancy" : "rewardTarot";
}

function owlStateFromData(data = {}) {
  const serverManaged = data.serverManaged === true;
  const rawProgress = readInt(data.petProgress);
  const petProgress = serverManaged
    ? Math.min(OWL_MOON_BOND_TARGET - 1, Math.max(0, rawProgress))
    : 0;

  return {
    owlName:
      typeof data.owlName === "string" && data.owlName.trim()
        ? data.owlName.trim().slice(0, 24)
        : "Bhrigu's Owl",
    petProgress,
    lastPetDate:
      serverManaged && typeof data.lastPetDate === "string"
        ? data.lastPetDate
        : null,
    rewardAvailable: serverManaged && data.rewardAvailable === true,
    rewardType: serverManaged ? validOwlRewardType(data.rewardType) : null,
    rewardReadingGranted:
      serverManaged && data.rewardReadingGranted === true,
    rewardClaimedCount: serverManaged
      ? Math.max(0, readInt(data.rewardClaimedCount))
      : 0,
    lastRewardClaimDate:
      serverManaged && typeof data.lastRewardClaimDate === "string"
        ? data.lastRewardClaimDate
        : null,
  };
}

function owlStatePayload(state) {
  return {
    owlName: state.owlName,
    petProgress: state.petProgress,
    lastPetDate: state.lastPetDate || null,
    rewardAvailable: state.rewardAvailable === true,
    rewardType: validOwlRewardType(state.rewardType),
    rewardReadingGranted: state.rewardReadingGranted === true,
    rewardClaimedCount: Math.max(0, readInt(state.rewardClaimedCount)),
    lastRewardClaimDate: state.lastRewardClaimDate || null,
    serverManaged: true,
  };
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

exports.petOwlCompanion = onCall(
  callableRuntimeOptions({
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const ref = owlStateRef(auth.uid);
    const userQuotaRef = quotaRef(auth.uid);
    const today = todayKey();

    return admin.firestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(ref);
      const state = owlStateFromData(doc.data() || {});
      let petProgress = state.petProgress;
      let rewardAvailable = state.rewardAvailable;
      let rewardType = state.rewardType;
      let rewardReadingGranted = state.rewardReadingGranted;
      let readingCreditsGranted = 0;
      let progressed = false;
      let unlockedReward = false;
      let shouldGrantReading = false;
      let message = "Hoot.";

      if (state.rewardAvailable) {
        if (!state.rewardReadingGranted) {
          rewardType = state.rewardType ||
            nextOwlRewardType(state.rewardClaimedCount);
          rewardReadingGranted = true;
          readingCreditsGranted = 1;
          shouldGrantReading = true;
          message =
            `Your ${readingRewardLabel(rewardType)} reading has been added. ` +
            `Open the gift for +${OWL_GIFT_CHAT_MESSAGES} chat messages.`;
        } else {
          message = "Open your owl gift first.";
        }
      } else if (state.lastPetDate === today) {
        message = "Moon Bond is already filled for today.";
      } else {
        progressed = true;
        petProgress += 1;

        if (petProgress >= OWL_MOON_BOND_TARGET) {
          petProgress = 0;
          rewardAvailable = true;
          rewardType = nextOwlRewardType(state.rewardClaimedCount);
          rewardReadingGranted = true;
          readingCreditsGranted = 1;
          shouldGrantReading = true;
          unlockedReward = true;
          message =
            `Moon Bond filled. +1 ${readingRewardLabel(rewardType)} ` +
            `reading added. Open the gift for +${OWL_GIFT_CHAT_MESSAGES} ` +
            "chat messages.";
        } else {
          message = `Moon Bond ${petProgress}/${OWL_MOON_BOND_TARGET}.`;
        }
      }

      const updatedState = {
        ...state,
        petProgress,
        lastPetDate: today,
        rewardAvailable,
        rewardType,
        rewardReadingGranted,
      };
      const write = {
        ...owlStatePayload(updatedState),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (!doc.exists) {
        write.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }

      transaction.set(ref, write, { merge: true });

      if (shouldGrantReading) {
        transaction.set(
          userQuotaRef,
          {
            [rewardQuotaFieldForType(rewardType)]:
              admin.firestore.FieldValue.increment(1),
            owlBondReadingGranted: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      return {
        state: owlStatePayload(updatedState),
        success: true,
        progressed,
        unlockedReward,
        rewardType: shouldGrantReading ? rewardType : null,
        readingCreditsGranted,
        message,
      };
    });
  }
);

exports.claimOwlMoonReward = onCall(
  callableRuntimeOptions({
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const stateRef = owlStateRef(auth.uid);
    const userQuotaRef = quotaRef(auth.uid);
    const today = todayKey();

    return admin.firestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(stateRef);
      const state = owlStateFromData(doc.data() || {});

      if (!state.rewardAvailable) {
        return {
          state: owlStatePayload(state),
          claimed: false,
          rewardType: null,
          chatMessagesGranted: 0,
          readingCreditsGranted: 0,
          message: "No owl gift is ready yet.",
        };
      }

      const rewardType =
        state.rewardType || nextOwlRewardType(state.rewardClaimedCount);
      const shouldGrantMissingReading = state.rewardReadingGranted !== true;
      const rewardClaimedCount = state.rewardClaimedCount + 1;
      const updatedState = {
        ...state,
        rewardAvailable: false,
        rewardType: null,
        rewardReadingGranted: false,
        rewardClaimedCount,
        lastRewardClaimDate: today,
      };
      const serverTime = admin.firestore.FieldValue.serverTimestamp();
      const quotaUpdate = {
        rewardChat: admin.firestore.FieldValue.increment(
          OWL_GIFT_CHAT_MESSAGES
        ),
        owlGiftChatGranted: admin.firestore.FieldValue.increment(
          OWL_GIFT_CHAT_MESSAGES
        ),
        updatedAt: serverTime,
      };

      if (shouldGrantMissingReading) {
        quotaUpdate[rewardQuotaFieldForType(rewardType)] =
          admin.firestore.FieldValue.increment(1);
        quotaUpdate.owlBondReadingGranted =
          admin.firestore.FieldValue.increment(1);
      }

      transaction.set(
        userQuotaRef,
        quotaUpdate,
        { merge: true }
      );

      transaction.set(
        stateRef,
        {
          ...owlStatePayload(updatedState),
          lastRewardType: rewardType,
          lastRewardChatMessagesGranted: OWL_GIFT_CHAT_MESSAGES,
          lastRewardReadingCreditsGranted: shouldGrantMissingReading ? 1 : 0,
          updatedAt: serverTime,
        },
        { merge: true }
      );

      transaction.set(
        owlClaimRef(auth.uid, today, rewardClaimedCount),
        {
          rewardType,
          chatMessagesGranted: OWL_GIFT_CHAT_MESSAGES,
          readingCreditsGranted: shouldGrantMissingReading ? 1 : 0,
          claimedAt: serverTime,
        }
      );

      return {
        state: owlStatePayload(updatedState),
        claimed: true,
        rewardType,
        chatMessagesGranted: OWL_GIFT_CHAT_MESSAGES,
        readingCreditsGranted: shouldGrantMissingReading ? 1 : 0,
        message: shouldGrantMissingReading
          ? `Gift opened: +${OWL_GIFT_CHAT_MESSAGES} chat messages and ` +
            `+1 ${readingRewardLabel(rewardType)} reading.`
          : `Gift opened: +${OWL_GIFT_CHAT_MESSAGES} chat messages. ` +
            `Your ${readingRewardLabel(rewardType)} reading was already added.`,
      };
    });
  }
);
