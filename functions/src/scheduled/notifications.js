const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const moment = require("moment-timezone");
const {
  GEMINI_API_KEY,
  HOME_HOROSCOPE_CONTENT_VERSION,
  getDailyTransits,
  normalizeAiResponseLanguage,
} = require("../core");
const {
  __dailyHoroscopeInternals: dailyHoroscopeInternals,
} = require("../callables/horoscope");

if (!admin.apps.length) {
  admin.initializeApp();
}

const notificationTimeZone = "Asia/Kolkata";
const playStoreUrl = "https://play.google.com/store/apps/details?id=com.bhr1gu.app";
const DAILY_HOROSCOPE_ENQUEUE_BATCH_SIZE = 400;
const DAILY_HOROSCOPE_WORKER_BATCH_SIZE = 12;
const DAILY_HOROSCOPE_WORKER_CONCURRENCY = 4;
const DAILY_HOROSCOPE_JOB_LOCK_TTL_MS = 10 * 60 * 1000;
const DAILY_HOROSCOPE_JOB_MAX_ATTEMPTS = 3;
const {
  buildDailyHoroscopePrompt,
  dailyHoroscopeRef,
  generateAndStoreDailyHoroscope,
  hasCompleteDailyHoroscope,
} = dailyHoroscopeInternals;

function isInvalidFcmTokenError(error) {
  const code = error?.code || "";
  return code === "messaging/invalid-registration-token" ||
    code === "messaging/registration-token-not-registered";
}

async function removeInvalidTokens(db, tokenOwners, invalidTokens) {
  const tokensByUid = new Map();

  invalidTokens.forEach((token) => {
    const owners = tokenOwners.get(token) || new Set();
    owners.forEach((uid) => {
      const tokens = tokensByUid.get(uid) || [];
      tokens.push(token);
      tokensByUid.set(uid, tokens);
    });
  });

  const entries = Array.from(tokensByUid.entries());
  for (let i = 0; i < entries.length; i += 400) {
    const batch = db.batch();
    entries.slice(i, i + 400).forEach(([uid, tokens]) => {
      batch.update(db.collection("users").doc(uid), {
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokens),
      });
    });
    await batch.commit();
  }
}

async function getFcmTokenTargets(db) {
  const usersSnapshot = await db.collection("users").get();

  const tokens = new Set();
  const tokenOwners = new Map();
  usersSnapshot.forEach((doc) => {
    const data = doc.data();
    if (data.fcmTokens && Array.isArray(data.fcmTokens) && data.fcmTokens.length > 0) {
      data.fcmTokens.forEach((token) => {
        const cleanToken = typeof token === "string" ? token.trim() : "";
        if (cleanToken) {
          tokens.add(cleanToken);
          const owners = tokenOwners.get(cleanToken) || new Set();
          owners.add(doc.id);
          tokenOwners.set(cleanToken, owners);
        }
      });
    }
  });

  return {
    tokenList: Array.from(tokens),
    tokenOwners,
  };
}

async function sendNotificationToTokens(db, tokenList, tokenOwners, message, logLabel) {
  const maxTokensPerBatch = 500;
  for (let i = 0; i < tokenList.length; i += maxTokensPerBatch) {
    const tokenBatch = tokenList.slice(i, i + maxTokensPerBatch);

    const response = await admin.messaging().sendEachForMulticast({
      ...message,
      tokens: tokenBatch,
    });
    console.log(`${response.successCount} ${logLabel} messages sent successfully in this batch.`);

    if (response.failureCount > 0) {
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.error("Failed to send to token:", tokenBatch[idx], resp.error);
          if (isInvalidFcmTokenError(resp.error)) {
            invalidTokens.push(tokenBatch[idx]);
          }
        }
      });
      if (invalidTokens.length > 0) {
        try {
          await removeInvalidTokens(db, tokenOwners, invalidTokens);
        } catch (cleanupError) {
          console.error("Failed to remove invalid FCM tokens:", cleanupError);
        }
      }
    }
  }
}

function getScheduledDateKey(event) {
  const scheduleTime = event?.scheduleTime || new Date().toISOString();
  return moment(scheduleTime).tz(notificationTimeZone).format("YYYY-MM-DD");
}

function hasFcmTokens(data = {}) {
  return Array.isArray(data.fcmTokens) &&
    data.fcmTokens.some((token) => String(token || "").trim());
}

function hasDailyHoroscopeProfile(data = {}) {
  return Boolean(
    data &&
      data.westernChart &&
      data.vedicChart &&
      String(data.timeOfBirth || "").trim() &&
      String(data.placeOfBirth || "").trim()
  );
}

function dailyHoroscopeJobsRef(db, dateKey) {
  return db.collection("dailyHoroscopeJobs").doc(dateKey).collection("jobs");
}

function dailyHoroscopeJobId(uid, aiResponseLanguage) {
  return `${uid}_${normalizeAiResponseLanguage(aiResponseLanguage)}`;
}

function timestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();

  const seconds = Number(value.seconds);
  if (Number.isFinite(seconds)) {
    const nanoseconds = Number(value.nanoseconds || 0);
    return seconds * 1000 + Math.floor(nanoseconds / 1000000);
  }

  const millis = Number(value);
  return Number.isFinite(millis) ? millis : 0;
}

async function enqueueDailyHoroscopeJobs(db, dateKey) {
  const usersSnapshot = await db.collection("users").get();
  let batch = db.batch();
  let pendingWrites = 0;
  let queued = 0;
  let skipped = 0;

  async function commitPendingBatch() {
    if (pendingWrites === 0) return;
    await batch.commit();
    batch = db.batch();
    pendingWrites = 0;
  }

  for (const doc of usersSnapshot.docs) {
    const userData = doc.data() || {};

    if (!hasFcmTokens(userData) || !hasDailyHoroscopeProfile(userData)) {
      skipped += 1;
      continue;
    }

    const aiResponseLanguage = normalizeAiResponseLanguage(
      userData.aiResponseLanguage
    );
    const jobRef = dailyHoroscopeJobsRef(db, dateKey).doc(
      dailyHoroscopeJobId(doc.id, aiResponseLanguage)
    );

    batch.set(
      jobRef,
      {
        uid: doc.id,
        dateKey,
        aiResponseLanguage,
        contentVersion: HOME_HOROSCOPE_CONTENT_VERSION,
        status: "queued",
        attempts: 0,
        generationLockOwner: null,
        generationLockExpiresAt: null,
        generationError: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    pendingWrites += 1;
    queued += 1;

    if (pendingWrites >= DAILY_HOROSCOPE_ENQUEUE_BATCH_SIZE) {
      await commitPendingBatch();
    }
  }

  await commitPendingBatch();
  return { queued, skipped };
}

async function claimDailyHoroscopeJob(jobRef) {
  const lockOwner = `worker_${Date.now()}_${Math.random().toString(36).slice(2)}`;
  const nowMs = Date.now();
  const lockExpiresAt = admin.firestore.Timestamp.fromMillis(
    nowMs + DAILY_HOROSCOPE_JOB_LOCK_TTL_MS
  );

  return admin.firestore().runTransaction(async (transaction) => {
    const snap = await transaction.get(jobRef);
    if (!snap.exists) return null;

    const data = snap.data() || {};
    const status = String(data.status || "");
    const activeLockExpiresAt = timestampMillis(data.generationLockExpiresAt);
    const lockIsActive =
      data.generationLockOwner && activeLockExpiresAt > nowMs;
    const canClaim =
      status === "queued" ||
      status === "retry" ||
      (status === "processing" && !lockIsActive);

    if (!canClaim) return null;

    const attempts = Number(data.attempts || 0);
    if (attempts >= DAILY_HOROSCOPE_JOB_MAX_ATTEMPTS) {
      transaction.set(
        jobRef,
        {
          status: "failed",
          generationLockOwner: null,
          generationLockExpiresAt: null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return null;
    }

    const nextAttempt = attempts + 1;
    transaction.set(
      jobRef,
      {
        status: "processing",
        attempts: nextAttempt,
        generationLockOwner: lockOwner,
        generationLockExpiresAt: lockExpiresAt,
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      ref: jobRef,
      data: {
        ...data,
        attempts: nextAttempt,
        generationLockOwner: lockOwner,
      },
    };
  });
}

async function updateClaimedDailyHoroscopeJob(jobRef, lockOwner, update) {
  await admin.firestore().runTransaction(async (transaction) => {
    const snap = await transaction.get(jobRef);
    const data = snap.data() || {};

    if (data.generationLockOwner !== lockOwner) return;

    transaction.set(
      jobRef,
      {
        ...update,
        generationLockOwner: null,
        generationLockExpiresAt: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

async function markDailyHoroscopeJobFailed(jobRef, jobData, error) {
  const attempts = Number(jobData.attempts || 0);
  const retryable = attempts < DAILY_HOROSCOPE_JOB_MAX_ATTEMPTS;
  const status = retryable ? "retry" : "failed";
  const lockOwner = jobData.generationLockOwner;

  await updateClaimedDailyHoroscopeJob(jobRef, lockOwner, {
    status,
    generationError: String(error?.message || error || "unknown error").slice(
      0,
      500
    ),
    failedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function markDailyHoroscopeJobComplete(jobRef, jobData, update = {}) {
  await updateClaimedDailyHoroscopeJob(jobRef, jobData.generationLockOwner, {
    status: "ready",
    generationError: null,
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...update,
  });
}

async function processDailyHoroscopeJob(jobRef, jobData) {
  const uid = String(jobData.uid || "").trim();
  const dateKey = String(jobData.dateKey || "").trim();

  if (!uid || !dateKey) {
    await markDailyHoroscopeJobComplete(jobRef, jobData, {
      status: "skipped",
      skipReason: "missing_uid_or_date",
    });
    return "skipped";
  }

  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  const userData = userDoc.data() || {};

  if (!hasFcmTokens(userData) || !hasDailyHoroscopeProfile(userData)) {
    await markDailyHoroscopeJobComplete(jobRef, jobData, {
      status: "skipped",
      skipReason: "ineligible_profile",
    });
    return "skipped";
  }

  const aiResponseLanguage = normalizeAiResponseLanguage(
    jobData.aiResponseLanguage || userData.aiResponseLanguage
  );
  const horoscopeRef = dailyHoroscopeRef(uid, dateKey, aiResponseLanguage);
  const cachedDoc = await horoscopeRef.get();

  if (
    cachedDoc.exists &&
    hasCompleteDailyHoroscope(
      cachedDoc.data() || {},
      HOME_HOROSCOPE_CONTENT_VERSION,
      aiResponseLanguage
    )
  ) {
    await markDailyHoroscopeJobComplete(jobRef, jobData, {
      skippedExistingCache: true,
    });
    return "cached";
  }

  const promptInput = buildDailyHoroscopePrompt({
    userData,
    dateKey,
  });

  await generateAndStoreDailyHoroscope({
    uid,
    dateKey,
    aiResponseLanguage,
    prompt: promptInput.prompt,
    horoscopeRef,
    userData,
    horoscopeMeta: promptInput.horoscopeMeta,
    moonPhaseLine: promptInput.moonPhaseLine,
    dailyEnergyLine: promptInput.dailyEnergyLine,
    recordUsage: false,
    maskAiErrors: false,
  });

  await markDailyHoroscopeJobComplete(jobRef, jobData);
  return "generated";
}

async function runWithConcurrency(items, limit, worker) {
  const results = [];
  let index = 0;

  async function runNext() {
    while (index < items.length) {
      const currentIndex = index;
      index += 1;
      results[currentIndex] = await worker(items[currentIndex]);
    }
  }

  const workerCount = Math.min(limit, items.length);
  await Promise.all(Array.from({ length: workerCount }, runNext));
  return results;
}

async function processDailyHoroscopeJobs(db, dateKey) {
  const jobsSnapshot = await dailyHoroscopeJobsRef(db, dateKey)
    .where("status", "in", ["queued", "retry", "processing"])
    .limit(DAILY_HOROSCOPE_WORKER_BATCH_SIZE)
    .get();
  const claimedJobs = [];

  for (const doc of jobsSnapshot.docs) {
    const claimed = await claimDailyHoroscopeJob(doc.ref);
    if (claimed) claimedJobs.push(claimed);
  }

  const results = {
    claimed: claimedJobs.length,
    generated: 0,
    cached: 0,
    skipped: 0,
    failed: 0,
  };

  await runWithConcurrency(
    claimedJobs,
    DAILY_HOROSCOPE_WORKER_CONCURRENCY,
    async (job) => {
      try {
        const result = await processDailyHoroscopeJob(job.ref, job.data);
        if (Object.prototype.hasOwnProperty.call(results, result)) {
          results[result] += 1;
        }
      } catch (error) {
        results.failed += 1;
        console.error(
          `Daily horoscope precompute job failed for ${job.data.uid}:`,
          error.response?.data || error.message
        );
        await markDailyHoroscopeJobFailed(job.ref, job.data, error);
      }
    }
  );

  return results;
}

exports.sendDailyHoroscopeNotifications = onSchedule(
  {
    schedule: "0 0 * * *", // 12:00 AM every day
    timeZone: "UTC",
    memory: "512MiB",
  },
  async (event) => {
    const db = admin.firestore();

    // Query users that have at least one FCM token.
    // Note: Firestore doesn't have a direct 'array is not empty' query.
    // We get all users and filter in code, or we can just fetch all users.
    // For a large userbase, consider keeping a separate collection for device tokens or a boolean flag.
    const { tokenList, tokenOwners } = await getFcmTokenTargets(db);

    if (tokenList.length === 0) {
      console.log("No FCM tokens found.");
      return;
    }

    console.log(`Sending daily horoscope notification to ${tokenList.length} devices.`);

    const message = {
      notification: {
        title: "Daily Horoscope",
        body: "Your daily horoscope has arrived!",
      },
      android: {
        notification: {
          channelId: "high_importance_channel",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    try {
      // sendEachForMulticast allows up to 500 tokens per call.
      await sendNotificationToTokens(db, tokenList, tokenOwners, message, "daily horoscope");
    } catch (error) {
      console.error("Error sending daily horoscope notifications:", error);
    }
  }
);

exports.precomputeDailyTransits = onSchedule(
  {
    schedule: "5 0 * * *",
    timeZone: notificationTimeZone,
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async (event) => {
    const dateKey = getScheduledDateKey(event);

    console.log(`Precomputing NASA/JPL daily transits for ${dateKey}.`);
    const transits = await getDailyTransits(dateKey);

    console.log(
      `Precomputed NASA/JPL daily transits for ${dateKey}: ${transits.tropicalPlanets?.length || 0} tropical planets.`
    );
  }
);

exports.enqueueDailyHoroscopePrecomputeJobs = onSchedule(
  {
    schedule: "10 0 * * *",
    timeZone: notificationTimeZone,
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async (event) => {
    const db = admin.firestore();
    const dateKey = getScheduledDateKey(event);

    console.log(`Enqueuing daily horoscope precompute jobs for ${dateKey}.`);
    const result = await enqueueDailyHoroscopeJobs(db, dateKey);

    console.log(
      `Enqueued ${result.queued} daily horoscope jobs for ${dateKey}; skipped ${result.skipped} users.`
    );
  }
);

exports.processDailyHoroscopePrecomputeJobs = onSchedule(
  {
    schedule: "* * * * *",
    timeZone: notificationTimeZone,
    memory: "1GiB",
    timeoutSeconds: 540,
    maxInstances: 1,
    concurrency: 1,
    secrets: [GEMINI_API_KEY],
  },
  async (event) => {
    const db = admin.firestore();
    const dateKey = getScheduledDateKey(event);
    const result = await processDailyHoroscopeJobs(db, dateKey);

    if (result.claimed > 0) {
      console.log(
        `Processed horoscope jobs for ${dateKey}: claimed=${result.claimed}, generated=${result.generated}, cached=${result.cached}, skipped=${result.skipped}, failed=${result.failed}.`
      );
    }
  }
);

exports.sendPlayStoreUpdateReminderToday = onSchedule(
  {
    schedule: "0 12 14 6 *", // 12:00 PM on June 14. Date guard below keeps this one-time.
    timeZone: notificationTimeZone,
    memory: "512MiB",
  },
  async (event) => {
    const targetDateKey = "2026-06-14";
    const scheduledDateKey = getScheduledDateKey(event);

    if (scheduledDateKey !== targetDateKey) {
      console.log(
        `Skipping Play Store update reminder for ${scheduledDateKey}; target date was ${targetDateKey}.`
      );
      return;
    }

    const db = admin.firestore();
    const { tokenList, tokenOwners } = await getFcmTokenTargets(db);

    if (tokenList.length === 0) {
      console.log("No FCM tokens found for Play Store update reminder.");
      return;
    }

    console.log(`Sending Play Store update reminder to ${tokenList.length} devices.`);

    const message = {
      notification: {
        title: "Update BHR1GU",
        body: "A new update is ready. Please update BHR1GU from the Play Store.",
      },
      data: {
        type: "play_store_update",
        url: playStoreUrl,
      },
      android: {
        notification: {
          channelId: "high_importance_channel",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    try {
      await sendNotificationToTokens(db, tokenList, tokenOwners, message, "Play Store update reminder");
    } catch (error) {
      console.error("Error sending Play Store update reminder:", error);
    }
  }
);
