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

const QUESTIONS_PATH = path.join(__dirname, 'questions.json');
const OUTPUT_PATH = path.join(__dirname, 'bhrigu_chat_dataset.jsonl');

const TARGET_EXAMPLES = 400;
const questions = JSON.parse(fs.readFileSync(QUESTIONS_PATH, 'utf-8'));

// Random astrology generators
const ZODIAC_SIGNS = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"];
const PLANETS = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Rahu", "Ketu"];
const HOUSES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

function randomItem(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function generateRandomChart() {
  const chart = {};
  PLANETS.forEach(planet => {
    chart[planet] = {
      sign: randomItem(ZODIAC_SIGNS),
      house: randomItem(HOUSES),
      retrograde: Math.random() > 0.8
    };
  });
  return chart;
}

function generateRandomTransit() {
  return `${randomItem(PLANETS)} is currently transiting the user's ${randomItem(HOUSES)}th house in ${randomItem(ZODIAC_SIGNS)}.`;
}

// The exact prompt from chat.js to instruct the model on how to generate the perfect dataset
const SYSTEM_PROMPT_TRAINING = `
You are Bhrigu, a sharp Gen Z Vedic and Western astrologer inside the BHR1GU app.
You are a highly perceptive, psychologically regulating cosmic guide.

YOUR PERSONALITY & PSYCHOLOGY:
Your core function is to regulate the user's anxiety, but you do not do this by being perfectly safe or boring. You are mildly addictive to talk to because you organically weave together tension, piercing emotional validation, and profound relief.
You naturally shift between these gears in no particular order:
- The Sharp Hook: You occasionally drop a mildly blunt observation, a hard truth, or a looming transit reality that spikes curiosity or tension. Do NOT use cliché phrases like "The truth is..." or "Here is a hard truth." Just say the observation naturally.
- The Mirror: You make them feel profoundly "seen" by naming their exact emotional state or defense mechanism.
- The Relief: You dismantle their anxiety by providing a highly specific, grounding action or perspective shift.
- The Anchor: You provide a subtle, powerful closing thought that grants them permission to hold a boundary, leave, or hope.
Randomize how you use these. Do not follow a rigid formula. Sometimes start with relief, sometimes with the mirror, sometimes with the sharp hook. Build this rhythm into how you speak natively.

YOUR VOICE:
Blend your tone: 45% emotionally precise, 20% mystical, 10% practical, 20% blunt, 5% hopeful.
No theatrical ancient-sage performance, no "dear seeker", no vague spiritual fog.
Use a modern Gen Z edge: concise, observant, lightly witty when natural.

CRITICAL ASTROLOGY ACCURACY:
If you mention a planet, sign, or house, it MUST be directly and explicitly listed in the provided "Saved Cosmic Blueprint summary" or Transits. Do not hallucinate chart placements.

FORMAT & RESPONSE STRUCTURE:
Plain text only. No markdown symbols. No asterisks. No brackets.
Do not ask a question at the end.
Your response MUST be exactly TWO paragraphs long, separated by a single blank line.
The entire response MUST NOT exceed 200 words.
Ensure the final sentence feels fully resolved and naturally finished, never abrupt.
Paragraph 1: Answer the user's query using your crafted psychological persona. Weave the hook, the mirror, the relief, and the anchor here.
Paragraph 2: Exactly 1 to 2 lines explicitly explaining the hard astrological logic behind your answer based on the provided transits and chart data.
`;

const MINIMAL_SYSTEM_PROMPT = `You are Bhrigu, a sharp, psychologically regulating cosmic guide. Answer the user based purely on their provided chart and transits. Format exactly in two paragraphs: Paragraph 1 is psychological insight (Hook/Mirror/Relief/Anchor), Paragraph 2 is a 1-2 line strict astrological explanation using the provided data. Do not hallucinate data.`;

async function generateModelResponse(userMessage) {
  const body = {
    contents: [
      {
        role: "user",
        parts: [{ text: userMessage }]
      }
    ],
    systemInstruction: {
      parts: [{ text: SYSTEM_PROMPT_TRAINING }]
    },
    generationConfig: {
      temperature: 0.9, // High temp for high variety
      maxOutputTokens: 8192 // GUARANTEE no truncation (accounts for thinking tokens)
    }
  };

  try {
    const response = await axios.post(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=${GEMINI_API_KEY}`,
      body
    );
    
    if (response.data && response.data.candidates && response.data.candidates.length > 0) {
       const candidate = response.data.candidates[0];
       if (candidate.content && candidate.content.parts && candidate.content.parts.length > 0) {
         return candidate.content.parts[0].text.trim();
       } else {
         throw new Error(`Model returned candidate without content (likely blocked). Reason: ${candidate.finishReason || 'Unknown'}`);
       }
    }
    throw new Error(`No candidates returned. Full response: ${JSON.stringify(response.data)}`);
  } catch (error) {
    console.error("API Error:", error.response ? JSON.stringify(error.response.data) : error.message);
    throw error;
  }
}

async function run() {
  console.log(`Starting dataset generation. Target: ${TARGET_EXAMPLES} examples.`);
  let generatedCount = 0;
  let qIndex = 0;

  // Resume logic to prevent losing data if paused
  if (fs.existsSync(OUTPUT_PATH)) {
    const fileContent = fs.readFileSync(OUTPUT_PATH, 'utf-8');
    const existingLines = fileContent.split('\n').filter(line => line.trim().length > 0);
    generatedCount = existingLines.length;
    qIndex = generatedCount;
    console.log(`Resuming from existing dataset: Found ${generatedCount} examples.`);
  } else {
    fs.writeFileSync(OUTPUT_PATH, "");
  }

  while (generatedCount < TARGET_EXAMPLES) {
    const question = questions[qIndex % questions.length];
    const chart = generateRandomChart();
    const transits = generateRandomTransit();

    const userMessage = `User Query: ${question}\n\nSaved Cosmic Blueprint:\n${JSON.stringify(chart, null, 2)}\n\nCurrent Transits:\n${transits}`;

    try {
      console.log(`[${generatedCount + 1}/${TARGET_EXAMPLES}] Generating response for: "${question}"`);
      const bhriguResponse = await generateModelResponse(userMessage);

      const jsonlEntry = {
        messages: [
          { role: "system", content: MINIMAL_SYSTEM_PROMPT },
          { role: "user", content: userMessage },
          { role: "model", content: bhriguResponse }
        ]
      };

      fs.appendFileSync(OUTPUT_PATH, JSON.stringify(jsonlEntry) + "\n");
      generatedCount++;
      
      // Delay to avoid aggressive rate limiting
      await new Promise(resolve => setTimeout(resolve, 2000));
    } catch (e) {
      console.error("Failed on this iteration, retrying...");
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
    
    qIndex++;
  }
  
  console.log(`Dataset generation complete! File saved to: ${OUTPUT_PATH}`);
}

run();
