const { GoogleAuth } = require('google-auth-library');
const axios = require('axios');
const auth = new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-platform'] });

async function run() {
  const model = "6058371191452729344";
  const projectId = "astrology-guru-app";
  const client = await auth.getClient();
  const token = await client.getAccessToken();

  const body = {
    contents: [
      { role: "user", parts: [{ text: "Did she ever love me?" }] }
    ],
    generationConfig: { maxOutputTokens: 512, temperature: 0.8 },
  };

  try {
    const response = await axios.post(
      `https://us-central1-aiplatform.googleapis.com/v1/projects/${projectId}/locations/us-central1/endpoints/${model}:generateContent`,
      body,
      {
        headers: {
          "Authorization": `Bearer ${token.token}`,
          "Content-Type": "application/json"
        }
      }
    );
    console.log(JSON.stringify(response.data, null, 2));
  } catch (e) {
    console.error(e.response?.data || e.message);
  }
}

run();
