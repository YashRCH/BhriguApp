const fs = require('fs');
const axios = require('axios');

const GEMINI_API_KEY = "***REMOVED-ROTATED-KEY***";

async function runTest() {
  const userMessage = "Why do I feel attached even when I know better?";
  
  try {
    const response = await axios.post(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=${GEMINI_API_KEY}`,
      {
        contents: [{ role: "user", parts: [{ text: userMessage }] }],
        systemInstruction: { parts: [{ text: "You are Bhrigu." }] },
        generationConfig: { temperature: 0.9, maxOutputTokens: 1024 }
      }
    );
    console.log(JSON.stringify(response.data, null, 2));
  } catch (e) {
    console.error(e.response ? JSON.stringify(e.response.data, null, 2) : e.message);
  }
}

runTest();
