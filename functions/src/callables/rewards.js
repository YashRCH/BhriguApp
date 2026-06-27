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

function nextOwlRewardType(readingGrantCount) {
  return readingGrantCount % 2 === 0
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
  // The bond can sit at the target while a gift waits to be opened, so the
  // progress is clamped to [0, target] rather than [0, target - 1].
  const petProgress = serverManaged
    ? Math.min(OWL_MOON_BOND_TARGET, Math.max(0, rawProgress))
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
    readingGrantCount: serverManaged
      ? Math.max(0, readInt(data.readingGrantCount))
      : 0,
    lastReadingType: serverManaged
      ? validOwlRewardType(data.lastReadingType)
      : null,
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
    readingGrantCount: Math.max(0, readInt(state.readingGrantCount)),
    lastReadingType: validOwlRewardType(state.lastReadingType),
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

      // Spam petting is allowed, but a reading is granted at most once per UTC
      // day. Repeat pets on the same day are cosmetic only.
      if (state.lastPetDate === today) {
        const write = {
          ...owlStatePayload(state),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (!doc.exists) {
          write.createdAt = admin.firestore.FieldValue.serverTimestamp();
        }
        transaction.set(ref, write, { merge: true });

        return {
          state: owlStatePayload(state),
          success: true,
          progressed: false,
          unlockedReward: false,
          rewardType: null,
          readingCreditsGranted: 0,
          message: state.rewardAvailable
            ? "Your owl gift is ready. Open it for chat messages."
            : "You have already bonded with your owl today. Come back " +
              "tomorrow for another reading.",
        };
      }

      // First pet of the day: grant one reading and advance the Moon Bond.
      const rewardType = nextOwlRewardType(state.readingGrantCount);
      const readingGrantCount = state.readingGrantCount + 1;
      const petProgress = Math.min(
        OWL_MOON_BOND_TARGET,
        state.petProgress + 1
      );
      const rewardAvailable =
        state.rewardAvailable || petProgress >= OWL_MOON_BOND_TARGET;
      const unlockedReward = rewardAvailable && !state.rewardAvailable;

      const updatedState = {
        ...state,
        petProgress,
        lastPetDate: today,
        rewardAvailable,
        readingGrantCount,
        lastReadingType: rewardType,
      };
      const write = {
        ...owlStatePayload(updatedState),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (!doc.exists) {
        write.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }
      transaction.set(ref, write, { merge: true });

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

      const message = unlockedReward
        ? `+1 ${readingRewardLabel(rewardType)} reading added. Moon Bond ` +
          `filled — open the gift for +${OWL_GIFT_CHAT_MESSAGES} chat ` +
          "messages."
        : `+1 ${readingRewardLabel(rewardType)} reading added. Moon Bond ` +
          `${petProgress}/${OWL_MOON_BOND_TARGET}.`;

      return {
        state: owlStatePayload(updatedState),
        success: true,
        progressed: true,
        unlockedReward,
        rewardType,
        readingCreditsGranted: 1,
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

      // Readings are granted daily on pet; the gift only grants chat messages
      // and resets the Moon Bond so a new cycle can begin.
      const rewardClaimedCount = state.rewardClaimedCount + 1;
      const updatedState = {
        ...state,
        petProgress: 0,
        rewardAvailable: false,
        rewardClaimedCount,
        lastRewardClaimDate: today,
      };
      const serverTime = admin.firestore.FieldValue.serverTimestamp();

      transaction.set(
        userQuotaRef,
        {
          rewardChat: admin.firestore.FieldValue.increment(
            OWL_GIFT_CHAT_MESSAGES
          ),
          owlGiftChatGranted: admin.firestore.FieldValue.increment(
            OWL_GIFT_CHAT_MESSAGES
          ),
          updatedAt: serverTime,
        },
        { merge: true }
      );

      transaction.set(
        stateRef,
        {
          ...owlStatePayload(updatedState),
          lastRewardChatMessagesGranted: OWL_GIFT_CHAT_MESSAGES,
          updatedAt: serverTime,
        },
        { merge: true }
      );

      transaction.set(
        owlClaimRef(auth.uid, today, rewardClaimedCount),
        {
          chatMessagesGranted: OWL_GIFT_CHAT_MESSAGES,
          readingCreditsGranted: 0,
          claimedAt: serverTime,
        }
      );

      return {
        state: owlStatePayload(updatedState),
        claimed: true,
        rewardType: null,
        chatMessagesGranted: OWL_GIFT_CHAT_MESSAGES,
        readingCreditsGranted: 0,
        message: `Gift opened: +${OWL_GIFT_CHAT_MESSAGES} chat messages.`,
      };
    });
  }
);
