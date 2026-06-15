const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const moment = require("moment-timezone");

if (!admin.apps.length) {
  admin.initializeApp();
}

const notificationTimeZone = "Asia/Kolkata";
const playStoreUrl = "https://play.google.com/store/apps/details?id=com.bhr1gu.app";

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
