const fs = require('fs');
const path = require('path');
const axios = require('axios');
const dotenv = require('dotenv');

// Load environment variables from functions directory
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

if (!GEMINI_API_KEY) {
  console.error("ERROR: GEMINI_API_KEY is not set in functions/.env");
  process.exit(1);
}

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
