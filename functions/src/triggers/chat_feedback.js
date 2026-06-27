const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const {
  admin,
  FUNCTION_REGION,
  GEMINI_API_KEY,
  generateGeminiEmbedding,
} = require("../core");

const LIKED_ANSWER_COLLECTION = "liked_answer_knowledge";

// When a chat answer is up-voted, embed the question and store the Q->A pair as
// a per-user RAG exemplar. Any other state (down-vote, cleared, deleted)
// removes the exemplar so it stops influencing that user's future answers.
exports.onChatFeedbackWritten = onDocumentWritten(
  {
    document: "chatFeedback/{feedbackId}",
    region: FUNCTION_REGION,
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (event) => {
    const feedbackId = event.params.feedbackId;
    const likedRef = admin
      .firestore()
      .collection(LIKED_ANSWER_COLLECTION)
      .doc(feedbackId);

    const after = event.data?.after?.data() || null;
    const vote = String(after?.vote || "").trim().toLowerCase();

    if (!after || vote !== "up") {
      try {
        await likedRef.delete();
      } catch (error) {
        console.error("Liked answer cleanup failed:", error.message);
      }
      return;
    }

    const userId = String(after.userId || "").trim();
    const question = String(after.question || "").trim();
    const answer = String(after.answer || "").trim();

    if (!userId || !answer) {
      return;
    }

    let embedding = [];

    try {
      embedding = await generateGeminiEmbedding(question || answer);
    } catch (error) {
      console.error(
        "Liked answer embedding error:",
        error.response?.data || error.message
      );
      // Store without an embedding; retrieval falls back to recency.
    }

    try {
      await likedRef.set({
        userId,
        question,
        answer,
        embedding,
        aiResponseLanguage: String(after.aiResponseLanguage || "").trim(),
        sourceFeedbackId: feedbackId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error("Liked answer write failed:", error.message);
    }
  }
);
