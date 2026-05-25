const {
  onCall,
  HttpsError,
  admin,
  FUNCTION_REGION,
  callableRuntimeOptions,
  requireCallableAuth,
} = require("../core");

const RECENT_LOGIN_WINDOW_SECONDS = 5 * 60;

exports.deleteAccount = onCall(
  callableRuntimeOptions({
    region: FUNCTION_REGION,
    timeoutSeconds: 540,
    memory: "1GiB",
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const uid = auth.uid;
    const authTime = Number(auth.token?.auth_time || 0);
    const nowSeconds = Math.floor(Date.now() / 1000);

    if (!authTime || nowSeconds - authTime > RECENT_LOGIN_WINDOW_SECONDS) {
      throw new HttpsError(
        "failed-precondition",
        "Please sign in again before deleting your account."
      );
    }

    const firestore = admin.firestore();
    const userRef = firestore.collection("users").doc(uid);

    try {
      await admin.auth().updateUser(uid, { disabled: true });
      await admin.auth().revokeRefreshTokens(uid);
      await firestore.recursiveDelete(userRef);
      await admin.auth().deleteUser(uid);

      return {
        deleted: true,
      };
    } catch (error) {
      try {
        await admin.auth().updateUser(uid, { disabled: false });
      } catch (restoreError) {
        console.error("Failed to re-enable user after deletion error:", restoreError);
      }

      console.error("Account deletion failed:", error);
      throw new HttpsError(
        "internal",
        "Account deletion failed. Please try again."
      );
    }
  }
);
