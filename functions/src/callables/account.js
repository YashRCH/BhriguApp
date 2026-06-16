const {
  onCall,
  HttpsError,
  admin,
  FUNCTION_REGION,
  callableRuntimeOptions,
  requireCallableAuth,
} = require("../core");

const RECENT_LOGIN_WINDOW_SECONDS = 5 * 60;

function cleanUsername(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/^@+/, "");
}

async function deleteQueryDocs(query) {
  let snap = await query.limit(400).get();

  while (!snap.empty) {
    await Promise.all(
      snap.docs.map((doc) => admin.firestore().recursiveDelete(doc.ref))
    );
    snap = await query.limit(400).get();
  }
}

async function deleteUsernameReservations(firestore, uid, usernames) {
  const cleanNames = Array.from(
    new Set(usernames.map(cleanUsername).filter(Boolean))
  );

  await Promise.all([
    ...cleanNames.map(async (username) => {
      const ref = firestore.collection("usernames").doc(username);
      const snap = await ref.get();
      const data = snap.data() || {};

      if (data.uid === uid) {
        await ref.delete();
      }
    }),
    deleteQueryDocs(firestore.collection("usernames").where("uid", "==", uid)),
  ]);
}

async function deleteUserConnections(firestore, uid) {
  const snap = await firestore
    .collection("connections")
    .where("memberIds", "array-contains", uid)
    .get();

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const memberIds = Array.isArray(data.memberIds) ? data.memberIds : [];
    const otherMemberIds = Array.from(
      new Set(memberIds.filter((memberId) => memberId && memberId !== uid))
    );
    const batch = firestore.batch();

    otherMemberIds.forEach((memberId) => {
      batch.delete(
        firestore.collection("users").doc(memberId).collection("connections").doc(uid)
      );
      batch.delete(
        firestore.collection("users").doc(uid).collection("connections").doc(memberId)
      );
    });

    if (otherMemberIds.length > 0) {
      await batch.commit();
    }
    await firestore.recursiveDelete(doc.ref);
  }
}

exports.deleteAccount = onCall(
  callableRuntimeOptions({
    region: FUNCTION_REGION,
    timeoutSeconds: 180,
    memory: "1GiB",
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const uid = auth.uid;
    const authTime = Number(auth.token?.auth_time || 0);
    const nowSeconds = Math.floor(Date.now() / 1000);
    const confirmation = String(request.data?.confirmation || "")
      .trim()
      .toLowerCase();

    if (!authTime || nowSeconds - authTime > RECENT_LOGIN_WINDOW_SECONDS) {
      throw new HttpsError(
        "failed-precondition",
        "Please sign in again before deleting your account."
      );
    }

    if (confirmation !== "confirm") {
      throw new HttpsError(
        "failed-precondition",
        "Type confirm to delete your account."
      );
    }

    const firestore = admin.firestore();
    const userRef = firestore.collection("users").doc(uid);
    const publicProfileRef = firestore.collection("public_profiles").doc(uid);

    try {
      await admin.auth().updateUser(uid, { disabled: true });
      await admin.auth().revokeRefreshTokens(uid);

      const [userDoc, publicProfileDoc] = await Promise.all([
        userRef.get(),
        publicProfileRef.get(),
      ]);
      const userData = userDoc.data() || {};
      const publicProfileData = publicProfileDoc.data() || {};

      await Promise.all([
        deleteUsernameReservations(firestore, uid, [
          userData.username,
          userData.usernameLower,
          publicProfileData.username,
          publicProfileData.usernameLower,
        ]),
        deleteQueryDocs(
          firestore.collection("invites").where("inviterUid", "==", uid)
        ),
        deleteQueryDocs(
          firestore.collection("invites").where("acceptedByUid", "==", uid)
        ),
        deleteQueryDocs(
          firestore.collection("aiReports").where("userId", "==", uid)
        ),
        deleteUserConnections(firestore, uid),
        firestore.recursiveDelete(publicProfileRef),
      ]);

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
