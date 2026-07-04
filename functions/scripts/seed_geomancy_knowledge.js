// Seeds the geomancy_knowledge Firestore collection from
// geomancy_knowledge_data.js. Run from the functions directory:
//
//   node scripts/seed_geomancy_knowledge.js
//
// Credentials: uses Application Default Credentials. Either set
// GOOGLE_APPLICATION_CREDENTIALS to a service-account key file, or run
// `gcloud auth application-default login` first. Override the project with
// GOOGLE_CLOUD_PROJECT if needed.

const admin = require("firebase-admin");
const figures = require("./geomancy_knowledge_data");

admin.initializeApp({
  projectId:
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT ||
    "astrology-guru-app",
});

async function main() {
  const db = admin.firestore();
  const batch = db.batch();

  for (const figure of figures) {
    const docId = String(figure.figure)
      .trim()
      .toLowerCase()
      .replace(/\s+/g, "_");
    const ref = db.collection("geomancy_knowledge").doc(docId);

    batch.set(ref, {
      ...figure,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  console.log(`Seeded ${figures.length} geomancy figures into geomancy_knowledge.`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Geomancy knowledge seeding failed:", error);
    process.exit(1);
  });
