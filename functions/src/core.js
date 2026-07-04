const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");
const crypto = require("crypto");
const moment = require("moment-timezone");
const tzLookup = require("tz-lookup");
const { GoogleAuth } = require("google-auth-library");

// Environment / API Variables
const GOOGLE_PLACES_API_KEY = defineSecret("GOOGLE_PLACES_API_KEY");
const FUNCTION_REGION = "us-central1";
const AI_REQUEST_TIMEOUT_MS = 25000;
const PLACES_REQUEST_TIMEOUT_MS = 12000;

axios.defaults.timeout = AI_REQUEST_TIMEOUT_MS;

if (!admin.apps.length) {
  admin.initializeApp();
}

const GROQ_API_KEY = defineSecret("GROQ_API_KEY");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const GEMINI_FLASH_LITE_MODEL = "gemini-2.5-flash-lite";
const BHRIGU_TUNED_MODEL = "endpoints/6058371191452729344";
// Deprecated: Groq models removed in favour of Gemini 2.5 Flash Lite.
const GROQ_PARTNER_MATCH_MODEL = "llama-3.3-70b-versatile";
const GROQ_BHRIGU_CHAT_MODEL = "llama-3.3-70b-versatile";

const TAROT_READING_CONTENT_VERSION = "tarot_flash_lite_json_v2";
const GEOMANCY_READING_CONTENT_VERSION = "geomancy_gemini25_lite_v5";
const TAROT_MAX_OUTPUT_TOKENS = 1400;
const GEOMANCY_MAX_OUTPUT_TOKENS = 1200;
const MYSTIC_READING_TEMPERATURE = 0.9;
const TAROT_READING_TEMPERATURE = 0.7;
const GEOMANCY_READING_TEMPERATURE = 0.7;
// Enable at deploy time only after release/debug App Check tokens are verified.
const APP_CHECK_ENFORCEMENT_ENABLED =
  String(process.env.APP_CHECK_ENFORCEMENT_ENABLED || "true")
    .trim()
    .toLowerCase() === "true";
const KNOWLEDGE_CACHE_TTL_MS = 10 * 60 * 1000;
const BHRIGU_CHAT_KNOWLEDGE_LIMIT = 5;

const HORIZONS_API_URL = "https://ssd.jpl.nasa.gov/api/horizons.api";
const HORIZONS_TIMEOUT_MS = 18000;
const HORIZONS_MAX_ATTEMPTS = 4;
const HORIZONS_RETRY_DELAY_MS = 750;
const HORIZONS_INTER_BODY_DELAY_MS = 350;
const DAILY_TRANSIT_LOCK_TTL_MS = 4 * 60 * 1000;
const DAILY_TRANSIT_WAIT_TIMEOUT_MS = 90 * 1000;
const DAILY_TRANSIT_WAIT_POLL_MS = 1000;
const MILLISECONDS_PER_DAY = 86400000;
const DEG_TO_RAD = Math.PI / 180;
const RAD_TO_DEG = 180 / Math.PI;
const CHART_CALCULATION_VERSION = "nasa_jpl_horizons_v5_observer_ecliptic_nodes";
const HOME_HOROSCOPE_CONTENT_VERSION = "home_signal_v12_nasa_transit_brief";
const ENGLISH_AI_RESPONSE_LANGUAGE = "english";
const HINGLISH_AI_RESPONSE_LANGUAGE = "hinglish";

const ZODIAC_SIGNS = [
  "Aries",
  "Taurus",
  "Gemini",
  "Cancer",
  "Leo",
  "Virgo",
  "Libra",
  "Scorpio",
  "Sagittarius",
  "Capricorn",
  "Aquarius",
  "Pisces",
];

const NAKSHATRAS = [
  "Ashwini",
  "Bharani",
  "Krittika",
  "Rohini",
  "Mrigashira",
  "Ardra",
  "Punarvasu",
  "Pushya",
  "Ashlesha",
  "Magha",
  "Purva Phalguni",
  "Uttara Phalguni",
  "Hasta",
  "Chitra",
  "Swati",
  "Vishakha",
  "Anuradha",
  "Jyeshtha",
  "Mula",
  "Purva Ashadha",
  "Uttara Ashadha",
  "Shravana",
  "Dhanishta",
  "Shatabhisha",
  "Purva Bhadrapada",
  "Uttara Bhadrapada",
  "Revati",
];

const HORIZONS_BODIES = [
  { name: "Sun", symbol: "☉", command: "10" },
  { name: "Moon", symbol: "☽", command: "301" },
  { name: "Mercury", symbol: "☿", command: "199" },
  { name: "Venus", symbol: "♀", command: "299" },
  { name: "Mars", symbol: "♂", command: "499" },
  { name: "Jupiter", symbol: "♃", command: "599" },
  { name: "Saturn", symbol: "♄", command: "699" },
];

function shouldUsePremiumReadingModel(data = {}) {
  return (
    data.modelTier === "paid" ||
    data.paid === true ||
    data.premium === true ||
    data.usePremiumModel === true
  );
}

function messageListToPrompt(messages) {
  return messages
    .map((message) => {
      const role = String(message.role || "user").toUpperCase();
      return `${role}:\n${message.content || ""}`;
    })
    .join("\n\n");
}

function stableStringify(value) {
  if (Array.isArray(value)) {
    return `[${value.map((item) => stableStringify(item)).join(",")}]`;
  }

  if (value && typeof value === "object") {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`)
      .join(",")}}`;
  }

  return JSON.stringify(value);
}

function cacheKeyForReading(type, payload) {
  const hash = crypto
    .createHash("sha256")
    .update(stableStringify(payload))
    .digest("hex");

  return `${type}_${hash}`;
}

function normalizeAiResponseLanguage(value) {
  return value === HINGLISH_AI_RESPONSE_LANGUAGE
    ? HINGLISH_AI_RESPONSE_LANGUAGE
    : ENGLISH_AI_RESPONSE_LANGUAGE;
}

function languageInstruction(aiResponseLanguage) {
  if (normalizeAiResponseLanguage(aiResponseLanguage) !== HINGLISH_AI_RESPONSE_LANGUAGE) {
    return "";
  }

  return `
RESPONSE LANGUAGE:
This is mandatory: all user-facing prose must be in natural Indian Hinglish using Roman script.
Do not answer in full English when this instruction is present.
Mix simple Hindi and English naturally, like a thoughtful Indian astrology guide speaking to an Indian user.
Use examples of this tone: "Aapke chart ka signal yeh kehta hai..." and "abhi clarity force karne ki zarurat nahi hai."
Do not use Devanagari.
Do not translate required headings, JSON keys, labels, section names, card names, figure names, sign names, or formatting markers.
Keep astrology terms accurate: Lagna, graha, dasha, nakshatra, Rahu, Ketu, Shani, karma, transit.
Explain Sanskrit terms simply when useful.
Avoid filmy, exaggerated, childish, or preachy Hindi.
Preserve every existing safety rule, structure rule, and accuracy rule above this instruction.
`;
}

function looksLikeHinglish(text) {
  const source = String(text || "").toLowerCase();
  const markers = [
    "aap",
    "aapke",
    "aapka",
    "hai",
    "hain",
    "nahi",
    "nahin",
    "abhi",
    "yeh",
    "isse",
    "iska",
    "isliye",
    "lekin",
    "agar",
    "toh",
    "mat",
    "zarurat",
    "samjho",
    "dikhata",
    "dikhati",
    "karta",
    "karti",
    "mein",
    "ki",
    "ka",
    "ko",
    "se",
    "par",
  ];

  return markers.filter((marker) => {
    return new RegExp(`\\b${marker}\\b`).test(source);
  }).length >= 3;
}

async function ensureHinglishText({
  text,
  aiResponseLanguage,
  preserveFormatInstruction = "",
  enquiryContext = "",
  maxTokens = 1200,
}) {
  if (normalizeAiResponseLanguage(aiResponseLanguage) !== HINGLISH_AI_RESPONSE_LANGUAGE) {
    return text;
  }

  if (looksLikeHinglish(text)) {
    return text;
  }

  const contextInstruction = enquiryContext ? `\n${enquiryContext}\n` : "";

  try {
    return await generateGeminiReadingText({
      systemInstruction: `${languageInstruction(aiResponseLanguage)}
Rewrite the supplied text into natural Indian Hinglish using Roman script.
Preserve all headings, labels, section order, names, numbers, punctuation style, and line breaks.
Do not add new sections. Do not remove information. Do not use Devanagari.
Return only the rewritten text.
${preserveFormatInstruction}${contextInstruction}`,
      prompt: String(text || ""),
      maxTokens,
      temperature: 0.25,
      model: GEMINI_FLASH_LITE_MODEL,
    });
  } catch (error) {
    console.error(
      "Hinglish rewrite failed:",
      error.response?.data || error.message
    );
    return text;
  }
}

async function resolveAiResponseLanguage(uid, requestValue, userData = null) {
  if (userData && Object.prototype.hasOwnProperty.call(userData, "aiResponseLanguage")) {
    return normalizeAiResponseLanguage(userData.aiResponseLanguage);
  }

  try {
    const snap = await admin.firestore().collection("users").doc(uid).get();
    const data = snap.data() || {};

    if (Object.prototype.hasOwnProperty.call(data, "aiResponseLanguage")) {
      return normalizeAiResponseLanguage(data.aiResponseLanguage);
    }
  } catch (error) {
    console.error("AI response language lookup error:", error.message);
  }

  if (requestValue) {
    console.warn(
      "Ignoring client-only aiResponseLanguage because no stored user preference was found."
    );
  }
  return ENGLISH_AI_RESPONSE_LANGUAGE;
}

function userReadingCacheRef(uid, cacheKey) {
  return admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("aiReadingCache")
    .doc(cacheKey);
}

async function readCachedReading(
  uid,
  cacheKey,
  contentVersion,
  aiResponseLanguage = null
) {
  let snap;

  try {
    snap = await userReadingCacheRef(uid, cacheKey).get();
  } catch (error) {
    console.error("Reading cache read error:", error.message);
    return null;
  }

  if (!snap.exists) {
    return null;
  }

  const cached = snap.data() || {};

  if (cached.contentVersion !== contentVersion || !cached.text) {
    return null;
  }

  if (
    aiResponseLanguage &&
    normalizeAiResponseLanguage(cached.aiResponseLanguage) !==
      normalizeAiResponseLanguage(aiResponseLanguage)
  ) {
    return null;
  }

  return String(cached.text);
}

async function writeCachedReading(
  uid,
  cacheKey,
  contentVersion,
  text,
  aiResponseLanguage = ENGLISH_AI_RESPONSE_LANGUAGE
) {
  try {
    await userReadingCacheRef(uid, cacheKey).set(
      {
        contentVersion,
        text,
        aiResponseLanguage: normalizeAiResponseLanguage(aiResponseLanguage),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  } catch (error) {
    console.error("Reading cache write error:", error.message);
  }
}

const DEFAULT_CONCURRENCY = 80;
const DEFAULT_MAX_INSTANCES = 30;

function callableRuntimeOptions(options = {}) {
  const defaults = {
    concurrency: DEFAULT_CONCURRENCY,
    maxInstances: DEFAULT_MAX_INSTANCES,
  };
  const merged = { ...defaults, ...options };

  return APP_CHECK_ENFORCEMENT_ENABLED
    ? { ...merged, enforceAppCheck: true }
    : merged;
}

function requireCallableAuth(request) {
  const auth = request.auth;

  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "Please sign in again.");
  }

  return auth;
}

function jsonByteLength(value) {
  try {
    return Buffer.byteLength(JSON.stringify(value), "utf8");
  } catch (error) {
    throw new HttpsError("invalid-argument", "Request payload is invalid.");
  }
}

function assertJsonSize(value, field, maxBytes) {
  if (jsonByteLength(value) > maxBytes) {
    throw new HttpsError("invalid-argument", `${field} is too large.`);
  }
}

function requireRequestData(request, { maxBytes = 60000 } = {}) {
  const data = request.data || {};

  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", "Request payload must be an object.");
  }

  assertJsonSize(data, "Request payload", maxBytes);
  return data;
}

function boundedString(value, {
  field = "Value",
  max = 1000,
  required = false,
  fallback = "",
  trim = false,
} = {}) {
  if (value === null || value === undefined) {
    if (required) {
      throw new HttpsError("invalid-argument", `${field} is required.`);
    }
    return fallback;
  }

  if (typeof value !== "string") {
    if (required) {
      throw new HttpsError("invalid-argument", `${field} must be a string.`);
    }
    return fallback;
  }

  const text = trim ? value.trim() : value;
  if (text.length > max) {
    throw new HttpsError("invalid-argument", `${field} is too long.`);
  }

  if (required && !text) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }

  return text;
}

function boundedPlainObject(value, {
  field = "Object",
  maxBytes = 20000,
  fallback = {},
} = {}) {
  if (value === null || value === undefined) {
    return fallback;
  }

  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${field} must be an object.`);
  }

  assertJsonSize(value, field, maxBytes);
  return value;
}

function boundedArray(value, {
  field = "Array",
  maxItems = 20,
  maxBytes = 30000,
  fallback = [],
} = {}) {
  if (value === null || value === undefined) {
    return fallback;
  }

  if (!Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${field} must be an array.`);
  }

  if (value.length > maxItems) {
    throw new HttpsError("invalid-argument", `${field} has too many items.`);
  }

  assertJsonSize(value, field, maxBytes);
  return value;
}

function cleanMetricKey(value) {
  return String(value || "unknown")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 64) || "unknown";
}

async function recordUsageEvent(uid, {
  feature,
  provider,
  model,
  cached = false,
} = {}) {
  if (!uid) return;

  const dateKey = new Date().toISOString().slice(0, 10);
  const increment = admin.firestore.FieldValue.increment(1);
  const payload = {
    total: increment,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    features: {
      [cleanMetricKey(feature)]: increment,
    },
    cache: {
      [cached ? "hits" : "misses"]: increment,
    },
  };

  if (provider) {
    payload.providers = {
      [cleanMetricKey(provider)]: increment,
    };
  }

  if (model) {
    payload.models = {
      [cleanMetricKey(model)]: increment,
    };
  }

  try {
    await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection("usage")
      .doc(dateKey)
      .set(payload, { merge: true });
  } catch (error) {
    console.error("Usage counter write error:", error.message);
  }
}

function isTimeoutError(error) {
  return (
    error?.code === "ECONNABORTED" ||
    error?.code === "ETIMEDOUT" ||
    error?.name === "TimeoutError" ||
    error?.name === "AbortError" ||
    String(error?.message || "").toLowerCase().includes("timeout")
  );
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isRetryableHorizonsError(error) {
  const status = Number(error?.status || error?.response?.status || 0);
  const message = String(error?.message || "").toLowerCase();

  return (
    error?.retryable === true ||
    status === 429 ||
    status === 500 ||
    status === 502 ||
    status === 503 ||
    status === 504 ||
    isTimeoutError(error) ||
    message.includes("fetch failed") ||
    message.includes("socket") ||
    message.includes("network") ||
    message.includes("temporarily")
  );
}

function isRetryableAiError(error) {
  const status = Number(error?.response?.status || 0);
  const details = error?.response?.data || {};
  const code = String(details?.error?.code || details?.code || error?.code || "");
  const type = String(details?.error?.type || details?.type || "");
  const message = String(details?.error?.message || details?.message || error?.message || "");
  const combined = `${code} ${type} ${message}`.toLowerCase();

  return (
    status === 429 ||
    status === 500 ||
    status === 502 ||
    status === 503 ||
    status === 504 ||
    isTimeoutError(error) ||
    combined.includes("rate") ||
    combined.includes("quota") ||
    combined.includes("capacity") ||
    combined.includes("overload")
  );
}

let authClient = null;

async function getVertexAuth() {
  if (!authClient) {
    authClient = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-platform"],
    });
  }
  const client = await authClient.getClient();
  const tokenResponse = await client.getAccessToken();
  const projectId = await authClient.getProjectId();
  return { token: tokenResponse.token, projectId };
}

async function generateGeminiReadingText({
  prompt,
  systemInstruction,
  maxTokens,
  temperature,
  model = BHRIGU_TUNED_MODEL,
  timeoutMs = AI_REQUEST_TIMEOUT_MS,
  responseMimeType,
}) {
  const { token, projectId } = await getVertexAuth();
  const region = FUNCTION_REGION || "us-central1";

  // Tuned endpoints (endpoints/...) don't reliably support the
  // systemInstruction API field or responseMimeType in generationConfig.
  // For those, prepend the system instruction into the user message
  // (the approach that was proven working on origin/main).
  const isEndpoint = model.startsWith("endpoints/");

  const effectivePrompt = (isEndpoint && systemInstruction)
    ? `${systemInstruction}\n\n${prompt}`
    : prompt;

  const body = {
    contents: [
      {
        role: "user",
        parts: [
          {
            text: effectivePrompt,
          },
        ],
      },
    ],
    // Standard Gemini models: use proper systemInstruction API field
    ...(!isEndpoint && systemInstruction
      ? {
          systemInstruction: {
            parts: [
              {
                text: systemInstruction,
              },
            ],
          },
        }
      : {}),
    generationConfig: {
      maxOutputTokens: maxTokens,
      temperature,
      // responseMimeType (e.g. application/json) only for standard models
      ...(!isEndpoint && responseMimeType ? { responseMimeType } : {}),
    },
  };

  const modelPath = isEndpoint 
    ? model 
    : `publishers/google/models/${model}`;

  const response = await axios.post(
    `https://${region}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${region}/${modelPath}:generateContent`,
    body,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      timeout: timeoutMs,
    }
  );

  const candidates = response.data.candidates || [];
  const parts = candidates[0]?.content?.parts || [];
  const text = parts.map((part) => part.text || "").join("").trim();

  if (!text) {
    const error = new Error("Gemini returned an empty reading.");
    error.responseData = response.data;
    error.candidateCount = candidates.length;
    error.finishReasons = candidates.map((candidate) => {
      return candidate.finishReason || "unknown";
    });
    throw error;
  }

  return text;
}

async function generateGroqReadingText({
  messages,
  maxTokens,
  temperature,
  model = GROQ_PARTNER_MATCH_MODEL,
}) {
  const response = await axios.post(
    "https://api.groq.com/openai/v1/chat/completions",
    {
      model,
      messages,
      max_tokens: maxTokens,
      temperature,
    },
    {
      headers: {
        Authorization: `Bearer ${GROQ_API_KEY.value()}`,
        "Content-Type": "application/json",
      },
    }
  );

  return (response.data.choices[0].message.content || "").trim();
}

async function generateUserReadingText({
  requestData,
  prompt,
  messages,
  systemInstruction,
  maxTokens,
  temperature,
}) {
  return generateGeminiReadingText({
    prompt: prompt || messageListToPrompt(
      messages ||
      [
        ...(systemInstruction
          ? [{ role: "system", content: systemInstruction }]
          : []),
        { role: "user", content: prompt },
      ]
    ),
    systemInstruction,
    maxTokens,
    temperature,
  });
}

function normalizeDegrees(value) {
  return ((value % 360) + 360) % 360;
}

function roundTo(value, places = 6) {
  const factor = 10 ** places;
  return Math.round((value + Number.EPSILON) * factor) / factor;
}

function signFromLongitude(longitude) {
  const index = Math.min(11, Math.max(0, Math.floor(normalizeDegrees(longitude) / 30)));
  return ZODIAC_SIGNS[index];
}

function degreeWithinSign(longitude) {
  const normalized = normalizeDegrees(longitude);
  return normalized - (Math.floor(normalized / 30) * 30);
}

function nakshatraFromMoon(moonLongitude) {
  const index = Math.min(
    26,
    Math.max(0, Math.floor(normalizeDegrees(moonLongitude) / (360 / 27)))
  );
  return NAKSHATRAS[index];
}

function parseBirthMinutes(timeOfBirth) {
  const normalized = String(timeOfBirth || "").trim().toUpperCase();
  const match = normalized.match(/(\d{1,2})[:.](\d{2})/);

  if (!match) {
    return 12 * 60;
  }

  let hour = Number.parseInt(match[1], 10);
  const minute = Number.parseInt(match[2], 10);
  const isPm = normalized.includes("PM");
  const isAm = normalized.includes("AM");

  if (isPm && hour < 12) hour += 12;
  if (isAm && hour === 12) hour = 0;

  return ((Math.min(23, Math.max(0, hour)) * 60) + Math.min(59, Math.max(0, minute))) % 1440;
}

function parseBirthDateParts(birthDate) {
  const raw = String(birthDate || "").trim();
  const match = raw.match(/^(\d{4})-(\d{2})-(\d{2})/);

  if (!match) {
    throw new HttpsError("invalid-argument", "Birth date must be an ISO date string.");
  }

  const year = Number.parseInt(match[1], 10);
  const month = Number.parseInt(match[2], 10);
  const day = Number.parseInt(match[3], 10);

  if (!year || month < 1 || month > 12 || day < 1 || day > 31) {
    throw new HttpsError("invalid-argument", "Birth date is invalid.");
  }

  return { year, month, day };
}

function detectTimezoneOffsetHours(placeOfBirth, latitude, longitude) {
  const place = String(placeOfBirth || "").toLowerCase();

  if (
    place.includes("india") ||
    place.includes("bharat") ||
    (
      typeof latitude === "number" &&
      typeof longitude === "number" &&
      latitude >= 6 &&
      latitude <= 38 &&
      longitude >= 68 &&
      longitude <= 98
    )
  ) {
    return 5.5;
  }

  // Fallback only: real civil time zones depend on borders and daylight-saving
  // history. A timezone lookup database should replace this later for global
  // historical accuracy.
  if (typeof longitude === "number" && Number.isFinite(longitude)) {
    return longitude / 15;
  }

  return 0;
}

function timezoneNameForBirthPlace(latitude, longitude) {
  if (
    typeof latitude !== "number" ||
    typeof longitude !== "number" ||
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude)
  ) {
    return null;
  }

  try {
    return tzLookup(latitude, longitude);
  } catch (error) {
    console.error("Timezone lookup failed:", error.message);
    return null;
  }
}

function parseBirthDateTimeToUtc({
  birthDate,
  timeOfBirth,
  placeOfBirth,
  latitude,
  longitude,
}) {
  const { year, month, day } = parseBirthDateParts(birthDate);
  const birthMinutes = parseBirthMinutes(timeOfBirth);
  const hour = Math.floor(birthMinutes / 60);
  const minute = birthMinutes % 60;
  const timezoneName = timezoneNameForBirthPlace(latitude, longitude);

  if (timezoneName) {
    const zonedBirth = moment.tz(
      {
        year,
        month: month - 1,
        date: day,
        hour,
        minute,
        second: 0,
        millisecond: 0,
      },
      timezoneName
    );

    if (zonedBirth.isValid()) {
      return {
        utcDate: zonedBirth.toDate(),
        timezoneName,
        timezoneOffsetMinutes: zonedBirth.utcOffset(),
        timezoneSource: "moment-timezone/tz-lookup",
      };
    }
  }

  const offsetHours = detectTimezoneOffsetHours(placeOfBirth, latitude, longitude);
  const localUtcShell = Date.UTC(
    year,
    month - 1,
    day,
    hour,
    minute,
    0,
    0
  );

  return {
    utcDate: new Date(localUtcShell - (offsetHours * 60 * 60 * 1000)),
    timezoneName: null,
    timezoneOffsetMinutes: Math.round(offsetHours * 60),
    timezoneSource: "longitude_fallback",
  };
}

function julianDateFromUtc(date) {
  return (date.getTime() / MILLISECONDS_PER_DAY) + 2440587.5;
}

function julianCenturiesSinceJ2000(utcDate) {
  return (julianDateFromUtc(utcDate) - 2451545.0) / 36525;
}

function daysSinceJ2000(utcDate) {
  const j2000 = Date.UTC(2000, 0, 1, 12, 0, 0, 0);
  return (utcDate.getTime() - j2000) / MILLISECONDS_PER_DAY;
}

function calculateLahiriAyanamsa(utcDate) {
  return 23.8531 + ((daysSinceJ2000(utcDate) / 36525) * 1.396);
}

function calculateMeanLunarNodeLongitude(utcDate) {
  const t = julianCenturiesSinceJ2000(utcDate);
  const t2 = t * t;
  const t3 = t2 * t;
  const t4 = t3 * t;

  return normalizeDegrees(
    125.04455501 -
    (1934.1361849 * t) +
    (0.0020762 * t2) +
    (t3 / 467410) -
    (t4 / 60616000)
  );
}

function siderealLunarNodeBodies(utcDate, ayanamsa) {
  const rahuLongitude = normalizeDegrees(calculateMeanLunarNodeLongitude(utcDate) - ayanamsa);

  return [
    {
      name: "Rahu",
      symbol: "☊",
      longitude: rahuLongitude,
      retrograde: true,
    },
    {
      name: "Ketu",
      symbol: "☋",
      longitude: normalizeDegrees(rahuLongitude + 180),
      retrograde: true,
    },
  ];
}

function meanObliquityDegrees(utcDate) {
  const t = julianCenturiesSinceJ2000(utcDate);
  const seconds = 21.448 - (t * (46.8150 + (t * (0.00059 - (t * 0.001813)))));
  return 23 + (26 / 60) + (seconds / 3600);
}

function greenwichMeanSiderealTimeDegrees(utcDate) {
  const jd = julianDateFromUtc(utcDate);
  const t = (jd - 2451545.0) / 36525;

  return normalizeDegrees(
    280.46061837 +
    (360.98564736629 * (jd - 2451545.0)) +
    (0.000387933 * t * t) -
    ((t * t * t) / 38710000)
  );
}

function localSiderealTimeDegrees(utcDate, longitude) {
  const safeLongitude =
    typeof longitude === "number" && Number.isFinite(longitude)
      ? longitude
      : 0;

  return normalizeDegrees(greenwichMeanSiderealTimeDegrees(utcDate) + safeLongitude);
}

function parseHorizonsVector(resultText, bodyName) {
  const result = String(resultText || "");
  const tableMatch = result.match(/\$\$SOE([\s\S]*?)\$\$EOE/);
  const table = tableMatch ? tableMatch[1] : result;
  const lines = table
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  for (const line of lines) {
    if (line.includes(",")) {
      const values = line
        .split(",")
        .map((part) => part.trim())
        .filter((part) => /^[-+]?\d+(?:\.\d*)?(?:[Ee][-+]?\d+)?$/.test(part))
        .map(Number);

      if (values.length >= 7 && values[0] > 2000000) {
        values.shift();
      }

      if (values.length >= 6) {
        return {
          x: values[0],
          y: values[1],
          z: values[2],
          vx: values[3],
          vy: values[4],
          vz: values[5],
        };
      }
    }
  }

  const labeled = {};
  const regex = /\b(X|Y|Z|VX|VY|VZ)\s*=\s*([-+]?\d+(?:\.\d*)?(?:[Ee][-+]?\d+)?)/g;
  let match;

  while ((match = regex.exec(result)) !== null) {
    labeled[match[1].toLowerCase()] = Number(match[2]);
  }

  if (
    typeof labeled.x === "number" &&
    typeof labeled.y === "number" &&
    typeof labeled.vx === "number" &&
    typeof labeled.vy === "number"
  ) {
    return {
      x: labeled.x,
      y: labeled.y,
      z: labeled.z || 0,
      vx: labeled.vx,
      vy: labeled.vy,
      vz: labeled.vz || 0,
    };
  }

  console.error(`Horizons parse failed for ${bodyName}. Snippet:`, result.slice(0, 800));
  throw new Error(`Could not parse Horizons vector for ${bodyName}.`);
}

function parseHorizonsObserverEcliptic(resultText, bodyName) {
  const result = String(resultText || "");
  const tableMatch = result.match(/\$\$SOE([\s\S]*?)\$\$EOE/);
  const table = tableMatch ? tableMatch[1] : result;
  const lines = table
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  for (const line of lines) {
    if (!line.includes(",")) continue;

    const values = line
      .split(",")
      .map((part) => part.trim())
      .filter((part) => /^[-+]?\d+(?:\.\d*)?(?:[Ee][-+]?\d+)?$/.test(part))
      .map(Number);

    if (values.length >= 2) {
      return {
        longitude: normalizeDegrees(values[values.length - 2]),
        latitude: values[values.length - 1],
      };
    }
  }

  console.error(`Horizons observer parse failed for ${bodyName}. Snippet:`, result.slice(0, 800));
  throw new Error(`Could not parse Horizons observer ecliptic longitude for ${bodyName}.`);
}

async function fetchHorizonsJson(body, params) {
  const url = `${HORIZONS_API_URL}?${params.toString()}`;
  let lastError = null;

  for (let attempt = 1; attempt <= HORIZONS_MAX_ATTEMPTS; attempt += 1) {
    try {
      const response = await fetch(url, {
        method: "GET",
        signal: AbortSignal.timeout(HORIZONS_TIMEOUT_MS),
      });

      const responseText = await response.text();

      if (!response.ok) {
        const error = new Error(`Horizons request failed for ${body.name}.`);
        error.status = response.status;
        console.error(
          "Horizons HTTP error:",
          body.name,
          response.status,
          responseText.slice(0, 500)
        );
        throw error;
      }

      let json;

      try {
        json = JSON.parse(responseText);
      } catch (error) {
        console.error("Horizons JSON parse error:", body.name, responseText.slice(0, 500));
        const parseError = new Error(`Horizons returned a non-JSON response for ${body.name}.`);
        parseError.retryable = true;
        throw parseError;
      }

      if (json.error) {
        console.error("Horizons API error:", body.name, json.error);
        throw new Error(`Horizons returned an error for ${body.name}.`);
      }

      return json;
    } catch (error) {
      lastError = error;

      if (
        attempt < HORIZONS_MAX_ATTEMPTS &&
        isRetryableHorizonsError(error)
      ) {
        const retryDelay =
          HORIZONS_RETRY_DELAY_MS * (2 ** (attempt - 1));
        console.warn(
          `Horizons request failed for ${body.name}; retrying attempt ${attempt + 1}/${HORIZONS_MAX_ATTEMPTS} after ${retryDelay}ms.`,
          error.status || error.code || error.name || error.message
        );
        await sleep(retryDelay);
        continue;
      }

      throw error;
    }
  }

  throw lastError || new Error(`Horizons request failed for ${body.name}.`);
}

async function fetchHorizonsObserverEcliptic(body, utcDate) {
  const params = new URLSearchParams({
    format: "json",
    COMMAND: `'${body.command}'`,
    OBJ_DATA: "NO",
    MAKE_EPHEM: "YES",
    EPHEM_TYPE: "OBSERVER",
    CENTER: "'500@399'",
    QUANTITIES: "'31'",
    CSV_FORMAT: "YES",
    TLIST: `'${julianDateFromUtc(utcDate).toFixed(8)}'`,
    TLIST_TYPE: "JD",
  });
  const json = await fetchHorizonsJson(body, params);

  return parseHorizonsObserverEcliptic(json.result, body.name);
}

function signedAngularDistance(a, b) {
  return ((normalizeDegrees(a - b) + 540) % 360) - 180;
}

async function fetchHorizonsLongitude(body, utcDate) {
  if (body.name === "Sun" || body.name === "Moon") {
    const ecliptic = await fetchHorizonsObserverEcliptic(body, utcDate);
    return {
      name: body.name,
      symbol: body.symbol,
      longitude: ecliptic.longitude,
      eclipticLatitude: ecliptic.latitude,
      retrograde: false,
    };
  }

  const ecliptic = await fetchHorizonsObserverEcliptic(body, utcDate);
  const nextDate = new Date(utcDate.getTime() + MILLISECONDS_PER_DAY);
  await sleep(HORIZONS_INTER_BODY_DELAY_MS);
  const nextEcliptic = await fetchHorizonsObserverEcliptic(body, nextDate);

  const retrograde = signedAngularDistance(nextEcliptic.longitude, ecliptic.longitude) < 0;

  return {
    name: body.name,
    symbol: body.symbol,
    longitude: ecliptic.longitude,
    eclipticLatitude: ecliptic.latitude,
    retrograde,
  };
}

async function fetchHorizonsVectorLongitude(body, utcDate) {
  const params = new URLSearchParams({
    format: "json",
    COMMAND: `'${body.command}'`,
    OBJ_DATA: "NO",
    MAKE_EPHEM: "YES",
    EPHEM_TYPE: "VECTORS",
    CENTER: "'500@399'",
    REF_PLANE: "ECLIPTIC",
    OUT_UNITS: "AU-D",
    VEC_TABLE: "2",
    VEC_CORR: "LT+S",
    CSV_FORMAT: "YES",
    TLIST: `'${julianDateFromUtc(utcDate).toFixed(8)}'`,
    TLIST_TYPE: "JD",
  });
  const json = await fetchHorizonsJson(body, params);

  const vector = parseHorizonsVector(json.result, body.name);
  const longitude = normalizeDegrees(Math.atan2(vector.y, vector.x) * 180 / Math.PI);
  const angularRate =
    ((vector.x * vector.vy) - (vector.y * vector.vx)) /
    ((vector.x * vector.x) + (vector.y * vector.y));

  return {
    name: body.name,
    symbol: body.symbol,
    longitude,
    retrograde: body.name === "Sun" || body.name === "Moon" ? false : angularRate < 0,
  };
}

async function fetchHorizonsLongitudesSequentially(utcDate) {
  const positions = [];

  for (let index = 0; index < HORIZONS_BODIES.length; index += 1) {
    const body = HORIZONS_BODIES[index];
    positions.push(await fetchHorizonsLongitude(body, utcDate));

    if (index < HORIZONS_BODIES.length - 1) {
      await sleep(HORIZONS_INTER_BODY_DELAY_MS);
    }
  }

  return positions;
}

function calculateAscendant({
  utcDate,
  latitude,
  longitude,
}) {
  const lst = localSiderealTimeDegrees(utcDate, longitude) * DEG_TO_RAD;
  const obliquity = meanObliquityDegrees(utcDate) * DEG_TO_RAD;
  const safeLatitude =
    typeof latitude === "number" && Number.isFinite(latitude)
      ? Math.min(66, Math.max(-66, latitude))
      : 0;
  const phi = safeLatitude * DEG_TO_RAD;
  const y = -Math.cos(lst);
  const x = (Math.sin(lst) * Math.cos(obliquity)) +
    (Math.tan(phi) * Math.sin(obliquity));

  return normalizeDegrees(Math.atan2(y, x) * RAD_TO_DEG);
}

function houseFromAscendant(longitude, ascendantLongitude) {
  const planetSign = Math.floor(normalizeDegrees(longitude) / 30);
  const ascendantSign = Math.floor(normalizeDegrees(ascendantLongitude) / 30);
  return ((planetSign - ascendantSign + 12) % 12) + 1;
}

function planetModelsFromLongitudes(bodyPositions, ascendantLongitude) {
  return bodyPositions.map((body) => ({
    name: body.name,
    symbol: body.symbol,
    sign: signFromLongitude(body.longitude),
    degree: roundTo(degreeWithinSign(body.longitude)),
    house: houseFromAscendant(body.longitude, ascendantLongitude),
    retrograde: body.retrograde,
  }));
}

function buildWesternChart({
  tropicalBodies,
  ascendantLongitude,
}) {
  const bodyMap = Object.fromEntries(
    tropicalBodies.map((body) => [body.name, body])
  );

  return {
    sunSign: signFromLongitude(bodyMap.Sun.longitude),
    moonSign: signFromLongitude(bodyMap.Moon.longitude),
    risingSign: signFromLongitude(ascendantLongitude),
    planets: planetModelsFromLongitudes(tropicalBodies, ascendantLongitude),
  };
}

function buildVedicChart({
  tropicalBodies,
  siderealAscendantLongitude,
  ayanamsa,
  utcDate,
}) {
  const siderealBodies = [
    ...tropicalBodies.map((body) => ({
      ...body,
      longitude: normalizeDegrees(body.longitude - ayanamsa),
    })),
    ...siderealLunarNodeBodies(utcDate, ayanamsa),
  ];
  const bodyMap = Object.fromEntries(
    siderealBodies.map((body) => [body.name, body])
  );

  return {
    ascendant: signFromLongitude(siderealAscendantLongitude),
    moonSign: signFromLongitude(bodyMap.Moon.longitude),
    nakshatra: nakshatraFromMoon(bodyMap.Moon.longitude),
    planets: planetModelsFromLongitudes(siderealBodies, siderealAscendantLongitude),
  };
}

async function calculateNatalChartForBirthData({
  birthDate,
  timeOfBirth,
  placeOfBirth,
  latitude,
  longitude,
}) {
  const birthTime = parseBirthDateTimeToUtc({
    birthDate,
    timeOfBirth,
    placeOfBirth,
    latitude,
    longitude,
  });
  const utcBirth = birthTime.utcDate;
  const tropicalBodies = await fetchHorizonsLongitudesSequentially(utcBirth);
  const ayanamsa = calculateLahiriAyanamsa(utcBirth);
  const tropicalAscendant = calculateAscendant({
    utcDate: utcBirth,
    latitude,
    longitude,
  });
  const siderealAscendant = normalizeDegrees(tropicalAscendant - ayanamsa);

  return {
    westernChart: buildWesternChart({
      tropicalBodies,
      ascendantLongitude: tropicalAscendant,
    }),
    vedicChart: buildVedicChart({
      tropicalBodies,
      siderealAscendantLongitude: siderealAscendant,
      ayanamsa,
      utcDate: utcBirth,
    }),
    calculationMeta: {
      utcBirthIso: utcBirth.toISOString(),
      timezoneName: birthTime.timezoneName,
      timezoneOffsetMinutes: birthTime.timezoneOffsetMinutes,
      timezoneSource: birthTime.timezoneSource,
      eclipticLongitudeSource: "NASA/JPL Horizons OBSERVER quantity 31",
      retrogradeSource: "NASA/JPL Horizons apparent ecliptic longitude one-day motion",
      lunarNodeSource: "Mean lunar ascending node with Lahiri ayanamsa; Ketu opposite Rahu",
      ayanamsa: roundTo(ayanamsa),
      tropicalAscendant: roundTo(tropicalAscendant),
      siderealAscendant: roundTo(siderealAscendant),
    },
  };
}

function parseDateKeyToUtcNoon(dateKey) {
  const raw = String(dateKey || "").trim();
  const match = raw.match(/^(\d{4})-(\d{2})-(\d{2})$/);

  if (!match) {
    throw new HttpsError("invalid-argument", "dateKey must use YYYY-MM-DD.");
  }

  return new Date(Date.UTC(
    Number.parseInt(match[1], 10),
    Number.parseInt(match[2], 10) - 1,
    Number.parseInt(match[3], 10),
    12,
    0,
    0,
    0
  ));
}

async function calculateDailyTransitsForDateKey(dateKey) {
  const utcNoon = parseDateKeyToUtcNoon(dateKey);
  const tropicalBodies = await fetchHorizonsLongitudesSequentially(utcNoon);

  const ayanamsa = calculateLahiriAyanamsa(utcNoon);
  const tropicalPlanets = planetModelsFromLongitudes(tropicalBodies, 0);
  const siderealBodies = [
    ...tropicalBodies.map((body) => ({
      ...body,
      longitude: normalizeDegrees(body.longitude - ayanamsa),
    })),
    ...siderealLunarNodeBodies(utcNoon, ayanamsa),
  ];
  const siderealPlanets = planetModelsFromLongitudes(siderealBodies, 0);
  const siderealMoon = siderealBodies.find((body) => body.name === "Moon");

  return {
    dateKey,
    calculatedForUtc: utcNoon.toISOString(),
    source: "NASA/JPL Horizons API",
    calculationVersion: CHART_CALCULATION_VERSION,
    eclipticLongitudeSource: "NASA/JPL Horizons OBSERVER quantity 31",
    ayanamsa: roundTo(ayanamsa),
    tropicalPlanets,
    siderealPlanets,
    siderealMoonSign: siderealMoon ? signFromLongitude(siderealMoon.longitude) : "Unknown",
    siderealMoonNakshatra: siderealMoon ? nakshatraFromMoon(siderealMoon.longitude) : "Unknown",
  };
}

function hasCompleteDailyTransitData(data = {}) {
  return (
    data.calculationVersion === CHART_CALCULATION_VERSION &&
    Array.isArray(data.tropicalPlanets) &&
    data.tropicalPlanets.length >= HORIZONS_BODIES.length &&
    Array.isArray(data.siderealPlanets) &&
    data.siderealPlanets.length >= HORIZONS_BODIES.length &&
    data.siderealMoonSign &&
    data.siderealMoonNakshatra
  );
}

function firestoreTimestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (typeof value === "number") return value;

  const parsed = Date.parse(String(value));
  return Number.isFinite(parsed) ? parsed : 0;
}

async function markDailyTransitGenerationFailed(transitRef, lockOwner, error) {
  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const snap = await transaction.get(transitRef);
      const data = snap.data() || {};

      if (data.generationLockOwner !== lockOwner) return;

      transaction.set(
        transitRef,
        {
          generationStatus: "failed",
          generationError: String(error?.message || error || "Unknown error").slice(0, 500),
          generationFailedAt: admin.firestore.FieldValue.serverTimestamp(),
          generationLockOwner: null,
          generationLockExpiresAt: null,
        },
        { merge: true }
      );
    });
  } catch (lockError) {
    console.error(
      "Daily transit failure lock cleanup error:",
      lockError.message || lockError
    );
  }
}

async function getDailyTransits(dateKey) {
  const transitRef = admin.firestore().collection("dailyTransits").doc(dateKey);
  const lockOwner = crypto.randomUUID();
  const waitUntil = Date.now() + DAILY_TRANSIT_WAIT_TIMEOUT_MS;

  while (Date.now() < waitUntil) {
    const decision = await admin.firestore().runTransaction(async (transaction) => {
      const transitDoc = await transaction.get(transitRef);
      const data = transitDoc.data() || {};

      if (hasCompleteDailyTransitData(data)) {
        return {
          action: "cached",
          data,
        };
      }

      const lockExpiresAt = firestoreTimestampMillis(data.generationLockExpiresAt);
      const lockIsAvailable =
        !data.generationLockOwner || lockExpiresAt <= Date.now();

      if (lockIsAvailable) {
        transaction.set(
          transitRef,
          {
            dateKey,
            generationStatus: "generating",
            generationLockOwner: lockOwner,
            generationLockExpiresAt: admin.firestore.Timestamp.fromMillis(
              Date.now() + DAILY_TRANSIT_LOCK_TTL_MS
            ),
            generationStartedAt: admin.firestore.FieldValue.serverTimestamp(),
            generationError: null,
          },
          { merge: true }
        );

        return {
          action: "generate",
        };
      }

      return {
        action: "wait",
        lockOwner: data.generationLockOwner,
      };
    });

    if (decision.action === "cached") {
      return decision.data;
    }

    if (decision.action === "generate") {
      try {
        const transits = await calculateDailyTransitsForDateKey(dateKey);

        await transitRef.set(
          {
            ...transits,
            generationStatus: "ready",
            generationLockOwner: null,
            generationLockExpiresAt: null,
            generationError: null,
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        return transits;
      } catch (error) {
        await markDailyTransitGenerationFailed(transitRef, lockOwner, error);
        throw error;
      }
    }

    await sleep(DAILY_TRANSIT_WAIT_POLL_MS);
  }

  const finalDoc = await transitRef.get();
  const finalData = finalDoc.data() || {};

  if (hasCompleteDailyTransitData(finalData)) {
    return finalData;
  }

  throw new Error(`Timed out waiting for daily transit generation for ${dateKey}.`);
}

function currentSkyCacheKey(now = new Date()) {
  return now.toISOString().slice(0, 13).replace("T", "-");
}

function dateKeyFromUtcDate(date = new Date()) {
  return date.toISOString().slice(0, 10);
}

function planetSnapshotFromBodyPosition(body) {
  return {
    longitude: roundTo(body.longitude, 6),
    sign: signFromLongitude(body.longitude),
    degree: roundTo(degreeWithinSign(body.longitude), 2),
  };
}

function currentSkyFromDailyTransits(dailyTransits = {}, now = new Date()) {
  const planets = {};
  const tropicalPlanets = Array.isArray(dailyTransits.tropicalPlanets)
    ? dailyTransits.tropicalPlanets
    : [];

  for (const planet of tropicalPlanets) {
    const longitude = longitudeFromPlacement(planet);

    if (!planet?.name || longitude === null) continue;

    planets[planet.name] = {
      longitude: roundTo(longitude, 6),
      sign: planet.sign || signFromLongitude(longitude),
      degree: typeof planet.degree === "number"
        ? roundTo(planet.degree, 2)
        : roundTo(degreeWithinSign(longitude), 2),
    };
  }

  if (!hasCompleteCurrentSkyPlanets(planets)) {
    return null;
  }

  return {
    key: currentSkyCacheKey(now),
    source: dailyTransits.source || "NASA/JPL Horizons API",
    fallbackSource: "dailyTransits",
    dateKey: dailyTransits.dateKey || dateKeyFromUtcDate(now),
    isoTime: now.toISOString(),
    planets,
  };
}

async function calculateCurrentSkySnapshot(now = new Date()) {
  const planets = {};
  const missingPlanets = [];
  const results = await Promise.allSettled(
    HORIZONS_BODIES.map(async (body) => ({
      body,
      ecliptic: await fetchHorizonsObserverEcliptic(body, now),
    }))
  );

  results.forEach((result, index) => {
    const body = HORIZONS_BODIES[index];

    if (result.status === "fulfilled") {
      planets[body.name] = planetSnapshotFromBodyPosition({
        longitude: result.value.ecliptic.longitude,
      });
      return;
    }

    missingPlanets.push(body.name);
    console.error(
      "Current sky body calculation failed:",
      body.name,
      result.reason?.message || result.reason
    );
  });

  if (Object.keys(planets).length === 0) {
    throw new Error("Current sky calculation failed for every planet.");
  }

  return {
    key: currentSkyCacheKey(now),
    source: "NASA/JPL Horizons API",
    isoTime: now.toISOString(),
    planets,
    partial: missingPlanets.length > 0,
    missingPlanets,
  };
}

function hasCompleteCurrentSkyPlanets(planets = {}) {
  return HORIZONS_BODIES.every((body) => {
    const longitude = Number(planets[body.name]?.longitude);
    return Number.isFinite(longitude);
  });
}

function hasCurrentSkyPlanets(data = {}) {
  const planets = data.planets && typeof data.planets === "object"
    ? data.planets
    : {};

  return hasCompleteCurrentSkyPlanets(planets);
}

async function getCurrentSkySnapshot(now = new Date()) {
  const key = currentSkyCacheKey(now);
  const transitRef = admin.firestore().collection("astro_transits").doc(key);
  const transitDoc = await transitRef.get();

  if (transitDoc.exists) {
    const cached = transitDoc.data() || {};

    if (hasCurrentSkyPlanets(cached)) {
      return {
        key,
        ...cached,
      };
    }
  }

  let snapshot = null;

  try {
    snapshot = await calculateCurrentSkySnapshot(now);
  } catch (error) {
    console.error(
      "Hourly current sky calculation failed:",
      error.message || error
    );
  }

  if (!snapshot || snapshot.partial) {
    try {
      const dailyTransits = await getDailyTransits(dateKeyFromUtcDate(now));
      const fallbackSnapshot = currentSkyFromDailyTransits(dailyTransits, now);

      if (fallbackSnapshot) {
        snapshot = fallbackSnapshot;
      }
    } catch (error) {
      console.error(
        "Current sky daily transit fallback failed:",
        error.message || error
      );
    }
  }

  if (snapshot?.partial) {
    throw new Error("Current sky remained incomplete after daily fallback.");
  }

  if (!snapshot) {
    throw new Error("Current sky calculation failed.");
  }

  if (!snapshot.partial) {
    await transitRef.set(
      {
        ...snapshot,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  return snapshot;
}

function transitPlanetListFromCurrentSky(currentSky = {}) {
  const planets = currentSky.planets || {};

  return Object.entries(planets).map(([name, placement]) => ({
    name,
    ...(placement || {}),
  }));
}

function selectNatalChartForTransits(userData = {}) {
  // Current-sky snapshots are tropical, so transit aspects must use the
  // Western natal chart instead of mixing in sidereal Vedic placements.
  if (Array.isArray(userData?.westernChart?.planets)) {
    return userData.westernChart;
  }

  return null;
}

function maxOrbForTransitPlanet(transitName) {
  if (transitName === "Sun" || transitName === "Moon") return 6;
  if (["Mercury", "Venus", "Mars"].includes(transitName)) return 4;
  if (["Jupiter", "Saturn"].includes(transitName)) return 3;
  return 3;
}

function transitAspectTheme(transitPlanet, natalPlanet, aspectName) {
  const specificThemes = {
    "Saturn:Moon": "emotional pressure, maturity, delayed comfort, patience",
    "Venus:Sun": "self-worth, attraction, confidence, social warmth",
    "Mars:Mercury": "sharp speech, fast decisions, conflict risk",
    "Jupiter:Sun": "growth, opportunity, confidence, visibility",
    "Saturn:Sun": "discipline, responsibility, pressure, long-term growth",
    "Moon:Venus": "softness, affection, emotional needs",
    "Mars:Venus": "desire, attraction, impulsive romance",
    "Mercury:Moon": "thoughts, mood, communication, emotional processing",
  };
  const specificTheme = specificThemes[`${transitPlanet}:${natalPlanet}`];

  if (specificTheme) {
    return specificTheme;
  }

  const planetMeanings = {
    Sun: "identity, vitality, confidence",
    Moon: "mood, emotional needs, instinct",
    Mercury: "thoughts, speech, decisions",
    Venus: "love, pleasure, values",
    Mars: "drive, desire, conflict",
    Jupiter: "growth, faith, opportunity",
    Saturn: "discipline, limits, responsibility",
  };
  const aspectMeanings = {
    conjunction: "direct activation and emphasis",
    sextile: "supportive opportunity that still needs effort",
    square: "friction, pressure, and necessary adjustment",
    trine: "natural flow and easier expression",
    opposition: "mirroring, tension, and relationship awareness",
  };

  return `${planetMeanings[transitPlanet] || "current planetary pressure"} influencing natal ${planetMeanings[natalPlanet] || "chart patterns"} through ${aspectMeanings[aspectName] || "an active aspect"}`;
}

function calculateTransitAspectMatches({
  transitPlanets,
  natalPlanets,
  limit = 5,
}) {
  const aspectDefs = [
    { name: "conjunction", angle: 0 },
    { name: "sextile", angle: 60 },
    { name: "square", angle: 90 },
    { name: "trine", angle: 120 },
    { name: "opposition", angle: 180 },
  ];
  const aspects = [];

  for (const transit of transitPlanets) {
    const transitLongitude = longitudeFromPlacement(transit);
    if (transitLongitude === null) continue;

    for (const natal of natalPlanets) {
      const natalLongitude = longitudeFromPlacement(natal);
      if (natalLongitude === null) continue;

      const separation = Math.abs(signedAngularDistance(transitLongitude, natalLongitude));
      const maxOrb = maxOrbForTransitPlanet(transit.name);

      for (const aspect of aspectDefs) {
        const orb = Math.abs(separation - aspect.angle);

        if (orb <= maxOrb) {
          const strength = Math.min(
            100,
            Math.max(1, Math.round((1 - (orb / maxOrb)) * 100))
          );

          aspects.push({
            transitPlanet: transit.name,
            natalPlanet: natal.name,
            aspect: aspect.name,
            orb: roundTo(orb, 2),
            strength,
            theme: transitAspectTheme(transit.name, natal.name, aspect.name),
            transitSign: transit.sign || signFromLongitude(transitLongitude),
            natalSign: natal.sign || signFromLongitude(natalLongitude),
            description: `${transit.name} ${aspect.name} natal ${natal.name}`,
          });
        }
      }
    }
  }

  return aspects
    .sort((a, b) => b.strength - a.strength || a.orb - b.orb)
    .slice(0, limit);
}

function messageHasKeyword(text, keyword) {
  const escaped = String(keyword || "")
    .trim()
    .replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    .replace(/\s+/g, "\\s+");

  if (!escaped) return false;

  return new RegExp(`(^|[^a-z0-9])${escaped}([^a-z0-9]|$)`, "i").test(text);
}

function detectQuestionCategory(message) {
  const text = String(message || "").toLowerCase();
  const categories = [
    {
      name: "love_relationship",
      keywords: [
        "love", "relationship", "crush", "marriage", "partner", "ex",
        "boyfriend", "girlfriend", "connection", "feelings", "breakup",
        "trust", "soulmate", "twin flame", "dating", "proposal",
      ],
    },
    {
      name: "career_work",
      keywords: [
        "career", "job", "work", "business", "promotion", "boss", "office",
        "success", "startup", "project", "client", "company",
      ],
    },
    {
      name: "money",
      keywords: [
        "money", "finance", "income", "salary", "wealth", "debt",
        "investment", "payment", "savings", "loan",
      ],
    },
    {
      name: "family",
      keywords: [
        "family", "mother", "father", "parents", "home", "sibling",
        "brother", "sister",
      ],
    },
    {
      name: "health_wellbeing",
      keywords: [
        "health", "stress", "anxiety", "tired", "mental", "sleep",
        "energy", "depression", "overwhelmed",
      ],
    },
    {
      name: "education",
      keywords: [
        "study", "exam", "college", "marks", "course", "degree",
        "interview", "placement", "internship", "university",
      ],
    },
    {
      name: "spiritual_growth",
      keywords: [
        "purpose", "karma", "spiritual", "path", "lesson", "soul",
        "meaning", "destiny", "dharma",
      ],
    },
    {
      name: "timing_decision",
      keywords: [
        "when", "should i", "will i", "decision", "choose", "move",
        "leave", "start", "wait", "accept", "reject", "continue", "stop",
      ],
    },
  ];

  for (const category of categories) {
    if (category.keywords.some((keyword) => messageHasKeyword(text, keyword))) {
      return category.name;
    }
  }

  return "general";
}

function categoryFocus(category) {
  const focusByCategory = {
    love_relationship:
      "Prioritize Moon, Venus, Mars, 5th house, 7th house, emotional pattern, attraction, attachment, trust, and timing. Do not drift into career unless the user asks.",
    career_work:
      "Prioritize Sun, Saturn, Mars, Jupiter, 6th house, 10th house, discipline, recognition, delay, authority, skill, and practical next steps. Do not drift into romance unless the user asks.",
    money:
      "Prioritize Venus, Jupiter, Saturn, 2nd house, 8th house, 11th house, income, spending, risk, patience, and discipline.",
    family:
      "Prioritize Moon, 4th house, Saturn, emotional duty, home patterns, family karma, and boundaries.",
    health_wellbeing:
      "Prioritize Moon, Mercury, Saturn, 6th house, stress, routine, rest, emotional regulation, and grounding. Avoid diagnosis or medical claims.",
    education:
      "Prioritize Mercury, Jupiter, Saturn, 5th house, 9th house, discipline, memory, focus, learning, and exam timing.",
    timing_decision:
      "Prioritize current transits if available, current date context, Saturn/Jupiter/Mars symbolism, risk, delay, patience, and whether action or waiting is wiser. If live transit data is missing, do not pretend exact transit timing is known.",
    spiritual_growth:
      "Prioritize Moon, Jupiter, Saturn, Ketu-style detachment if available, dharma, karmic lessons, self-awareness, and inner discipline.",
    general:
      "Answer the exact user question first. Use only relevant chart factors. Do not give a full chart reading unless asked.",
  };

  return focusByCategory[category] || focusByCategory.general;
}

function knowledgeTextFromDoc(data = {}) {
  return String(
    data.text ||
    data.content ||
    data.knowledge ||
    data.chunk ||
    data.excerpt ||
    data.reading_style ||
    ""
  ).trim();
}

function searchableKnowledgeText(data = {}) {
  const tags = Array.isArray(data.tags) ? data.tags.join(" ") : "";

  return [
    data.title,
    data.category,
    tags,
    knowledgeTextFromDoc(data),
  ]
    .map((value) => String(value || "").toLowerCase())
    .join(" ");
}

function keywordKnowledgeScore(query, data = {}) {
  const haystack = searchableKnowledgeText(data);
  const terms = String(query || "")
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((term) => term.length > 2);
  let score = 0;

  for (const term of new Set(terms)) {
    if (haystack.includes(term)) {
      score += 1;
    }
  }

  return score;
}

function formatBhriguKnowledgeChunk(chunk = {}) {
  const tags = Array.isArray(chunk.tags) ? chunk.tags.join(", ") : "";
  const text = String(chunk.text || "").slice(0, 1200);

  return `Title: ${chunk.title || "Untitled"}
Category: ${chunk.category || "general"}
Tags: ${tags || "none"}
Knowledge: ${text}`;
}

let bhriguBookKnowledgeDocsCache = null;
let bhriguBookKnowledgeDocsCacheAt = 0;
let bhriguBookKnowledgeDocsPromise = null;

async function readBhriguBookKnowledgeDocs() {
  const now = Date.now();

  if (
    bhriguBookKnowledgeDocsCache &&
    now - bhriguBookKnowledgeDocsCacheAt < KNOWLEDGE_CACHE_TTL_MS
  ) {
    return bhriguBookKnowledgeDocsCache;
  }

  if (bhriguBookKnowledgeDocsPromise) {
    return bhriguBookKnowledgeDocsPromise;
  }

  bhriguBookKnowledgeDocsPromise = admin
    .firestore()
    .collection("book_knowledge")
    .get()
    .then((snap) => {
      const docs = [];
      snap.forEach((doc) => {
        docs.push({
          id: doc.id,
          ...(doc.data() || {}),
        });
      });
      bhriguBookKnowledgeDocsCache = docs;
      bhriguBookKnowledgeDocsCacheAt = Date.now();
      return docs;
    })
    .finally(() => {
      bhriguBookKnowledgeDocsPromise = null;
    });

  return bhriguBookKnowledgeDocsPromise;
}

async function retrieveBhriguChatKnowledge({
  message,
  category,
  limit = BHRIGU_CHAT_KNOWLEDGE_LIMIT,
}) {
  const query = `${category}: ${String(message || "").trim()}`;
  const docs = await readBhriguBookKnowledgeDocs();

  if (!docs.length) {
    return "";
  }

  let queryEmbedding = [];

  if (docs.some((data) => Array.isArray(data.embedding))) {
    try {
      queryEmbedding = await generateGeminiEmbedding(query);
    } catch (error) {
      console.error(
        "Bhrigu chat RAG embedding error:",
        error.response?.data || error.message
      );
    }
  }

  const scoredChunks = [];

  docs.forEach((data) => {
    const text = knowledgeTextFromDoc(data);
    if (!text) return;

    let score = keywordKnowledgeScore(query, data);

    if (queryEmbedding.length > 0 && Array.isArray(data.embedding)) {
      score += cosineSimilarity(queryEmbedding, data.embedding) * 10;
    }

    scoredChunks.push({
      title: String(data.title || data.book || data.source || ""),
      category: String(data.category || data.section || "general"),
      tags: Array.isArray(data.tags) ? data.tags.map((tag) => String(tag)) : [],
      text,
      score,
    });
  });

  scoredChunks.sort((a, b) => b.score - a.score);

  return scoredChunks
    .slice(0, limit)
    .map(formatBhriguKnowledgeChunk)
    .join("\n\n");
}

// Retrieves the asking user's OWN previously up-voted answers, scored by
// semantic similarity to the current message. Per-user only, so the examples
// are grounded in this same user's chart and safe to build on directly.
async function retrieveLikedAnswerExamples({ uid, message, limit = 3 }) {
  if (!uid) {
    return "";
  }

  let snap;

  try {
    snap = await admin
      .firestore()
      .collection("liked_answer_knowledge")
      .where("userId", "==", uid)
      .limit(50)
      .get();
  } catch (error) {
    console.error("Liked answer retrieval error:", error.message);
    return "";
  }

  if (snap.empty) {
    return "";
  }

  const docs = [];
  snap.forEach((doc) => {
    const data = doc.data() || {};
    if (data.question || data.answer) {
      docs.push(data);
    }
  });

  if (!docs.length) {
    return "";
  }

  let queryEmbedding = [];

  if (docs.some((data) => Array.isArray(data.embedding) && data.embedding.length)) {
    try {
      queryEmbedding = await generateGeminiEmbedding(String(message || "").trim());
    } catch (error) {
      console.error(
        "Liked answer RAG embedding error:",
        error.response?.data || error.message
      );
    }
  }

  const scored = docs.map((data) => {
    let score = 0;

    if (queryEmbedding.length > 0 && Array.isArray(data.embedding)) {
      score = cosineSimilarity(queryEmbedding, data.embedding);
    }

    return { data, score };
  });

  // When no embeddings are available all scores tie at 0; fall back to most
  // recently liked so the section is still useful.
  scored.sort((a, b) => {
    if (b.score !== a.score) {
      return b.score - a.score;
    }

    const aTime = a.data.createdAt?.toMillis ? a.data.createdAt.toMillis() : 0;
    const bTime = b.data.createdAt?.toMillis ? b.data.createdAt.toMillis() : 0;
    return bTime - aTime;
  });

  return scored
    .slice(0, limit)
    .map(({ data }, index) => {
      const question = String(data.question || "").trim() || "(not recorded)";
      const answer = String(data.answer || "").trim();
      return `Example ${index + 1}\nUser asked: ${question}\nAnswer the user loved: ${answer}`;
    })
    .filter((chunk) => chunk.includes("Answer the user loved:"))
    .join("\n\n");
}

function cleanGeneratedLine(value) {
  return String(value || "")
    .replace(/\*\*/g, "")
    .replace(/^\s*\[([^\]]+)\]\s*/g, "$1 ")
    .replace(/\s+/g, " ")
    .replace(/^[\-\*\u2022\s]+/g, "")
    .trim();
}

function firstSentence(value) {
  const cleaned = cleanGeneratedLine(value);
  const match = cleaned.match(/^(.+?[.!?])(?:\s|$)/);

  return match ? match[1].trim() : cleaned;
}

function terminalPunctuation(value) {
  const cleaned = cleanGeneratedLine(value).replace(/(?:\.{3,}|…)+$/g, "").trim();

  if (!cleaned) return "";
  if (/[.!?]$/.test(cleaned)) return cleaned;

  return `${cleaned}.`;
}

function normalizedReadingLine(value) {
  return cleanGeneratedLine(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function limitWords(value, maxWords) {
  const cleaned = cleanGeneratedLine(value).replace(/\.{3,}|…/g, "").trim();
  const words = cleaned.split(/\s+/).filter(Boolean);

  if (words.length <= maxWords) return terminalPunctuation(cleaned);

  const sentences = cleaned.match(/[^.!?]+[.!?]+/g) || [];
  const selected = [];

  for (const sentence of sentences) {
    const next = [...selected, sentence.trim()].join(" ");
    const nextWords = next.split(/\s+/).filter(Boolean);

    if (nextWords.length <= maxWords) {
      selected.push(sentence.trim());
    }
  }

  if (selected.length > 0) {
    return terminalPunctuation(selected.join(" "));
  }

  return terminalPunctuation(words.slice(0, maxWords).join(" "));
}

function splitGeneratedLines(value) {
  return String(value || "")
    .replace(/\r\n?/g, "\n")
    .split("\n")
    .flatMap((line) => line.split(/\s*;\s*/))
    .map((line) => cleanGeneratedLine(line.replace(/^\d+[\).\s-]+/, "")))
    .filter(Boolean);
}

function ensureActionLines(generated, fallback, maxWords) {
  const source = generated.length > 0 ? generated : fallback;

  return source.slice(0, 3).map((line) => limitWords(line, maxWords));
}

function longitudeFromPlacement(placement = {}) {
  const longitude = Number(placement.longitude);

  if (Number.isFinite(longitude)) {
    return normalizeDegrees(longitude);
  }

  const signIndex = ZODIAC_SIGNS.indexOf(String(placement.sign || ""));
  const degree = Number(placement.degree);

  if (signIndex < 0 || !Number.isFinite(degree)) return null;

  return normalizeDegrees((signIndex * 30) + degree);
}

function dailyTransitAspectOrb(transitName, aspectName) {
  if (transitName === "Moon") return aspectName === "Conjunction" ? 6 : 5;
  if (transitName === "Sun") return 4;
  return 3;
}

function calculateTransitAspects(firstInput, secondInput = {}) {
  const isCurrentSkyRequest =
    Array.isArray(firstInput?.planets) &&
    secondInput?.planets &&
    !Array.isArray(secondInput.planets);

  if (isCurrentSkyRequest) {
    return calculateTransitAspectMatches({
      transitPlanets: transitPlanetListFromCurrentSky(secondInput),
      natalPlanets: firstInput.planets,
      limit: 5,
    });
  }

  const transitPlanets = Array.isArray(firstInput?.tropicalPlanets)
    ? firstInput.tropicalPlanets
    : [];
  const natalPlanets = Array.isArray(secondInput?.westernChart?.planets)
    ? secondInput.westernChart.planets
    : [];
  const aspectDefs = [
    { name: "Conjunction", angle: 0 },
    { name: "Sextile", angle: 60 },
    { name: "Square", angle: 90 },
    { name: "Trine", angle: 120 },
    { name: "Opposition", angle: 180 },
  ];
  const aspects = [];

  for (const transit of transitPlanets) {
    const transitLongitude = longitudeFromPlacement(transit);
    if (transitLongitude === null) continue;

    for (const natal of natalPlanets) {
      const natalLongitude = longitudeFromPlacement(natal);
      if (natalLongitude === null) continue;

      const separation = Math.abs(signedAngularDistance(transitLongitude, natalLongitude));

      for (const aspect of aspectDefs) {
        const orb = Math.abs(separation - aspect.angle);
        const allowedOrb = dailyTransitAspectOrb(transit.name, aspect.name);

        if (orb <= allowedOrb) {
          aspects.push({
            transitPlanet: transit.name,
            natalPlanet: natal.name,
            aspect: aspect.name,
            orb: roundTo(orb, 2),
            transitSign: transit.sign,
            natalSign: natal.sign,
            description: `${transit.name} ${aspect.name.toLowerCase()} natal ${natal.name}`,
          });
        }
      }
    }
  }

  return aspects
    .sort((a, b) => a.orb - b.orb)
    .slice(0, 8);
}

function parseDailyHoroscopeText(text, fallback = {}) {
  const source = String(text || "").replace(/\*\*/g, "");
  const matchSection = (pattern) => {
    const match = source.match(pattern);
    return match ? match[1].trim() : "";
  };

  const bhriguTodayRaw = matchSection(
    /(?:\[?\s*BHRIGU[\s_]+TODAY\s*\]?):?\s*(.+?)(?=\[?\s*YOUR[\s_]+TRANSIT\s*\]?:?|\[?\s*DO\s*\]?:?|\[?\s*AVOID\s*\]?:?|\[?\s*RELATIONSHIPS\s*\]?:?|\[?\s*(?:WORK_MONEY|WORK\s*\/\s*MONEY)\s*\]?:?|\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?:?|\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)/s
  );
  const transitRaw = matchSection(
    /(?:\[?\s*YOUR[\s_]+TRANSIT\s*\]?):?\s*(.+?)(?=\[?\s*DO\s*\]?:?|\[?\s*AVOID\s*\]?:?|\[?\s*RELATIONSHIPS\s*\]?:?|\[?\s*(?:WORK_MONEY|WORK\s*\/\s*MONEY)\s*\]?:?|\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?:?|\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)/s
  );
  const doRaw = matchSection(
    /(?:\[?\s*DO\s*\]?):?\s*(.+?)(?=\[?\s*AVOID\s*\]?:?|\[?\s*RELATIONSHIPS\s*\]?:?|\[?\s*(?:WORK_MONEY|WORK\s*\/\s*MONEY)\s*\]?:?|\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?:?|\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)/s
  );
  const avoidRaw = matchSection(
    /(?:\[?\s*AVOID\s*\]?):?\s*(.+?)(?=\[?\s*RELATIONSHIPS\s*\]?:?|\[?\s*(?:WORK_MONEY|WORK\s*\/\s*MONEY)\s*\]?:?|\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?:?|\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)/s
  );
  const relationshipsRaw = matchSection(
    /(?:\[?\s*RELATIONSHIPS\s*\]?):?\s*(.+?)(?=\[?\s*(?:WORK_MONEY|WORK\s*\/\s*MONEY)\s*\]?:?|\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?:?|\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)/s
  );
  const workMoneyRaw = matchSection(
    /(?:\[?\s*(?:WORK_MONEY|WORK\s*\/\s*MONEY)\s*\]?):?\s*(.+?)(?=\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?:?|\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)/s
  );
  const innerWeatherRaw = matchSection(
    /(?:\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?):?\s*(.+?)(?=\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)/s
  );
  const mantraRaw = matchSection(
    /(?:\[?\s*MANTRA\s*\]?):?\s*(.+?)(?=MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)/s
  );
  const moonPhaseRaw = matchSection(
    /MOON_PHASE_LINE:\s*(.+?)(?=DAILY_ENERGY_LINE:|$)/s
  );
  const dailyEnergyRaw = matchSection(/DAILY_ENERGY_LINE:\s*(.+)/s);

  const bhriguToday = limitWords(bhriguTodayRaw, 45);
  const yourTransit = limitWords(transitRaw, 55);
  const relationships = limitWords(relationshipsRaw, 34);
  const workMoney = limitWords(workMoneyRaw, 28);
  const innerWeather = limitWords(innerWeatherRaw, 30);
  const mantraCandidate = limitWords(
    mantraRaw || "Choose peace before performance.",
    14
  );
  const mantra =
    normalizedReadingLine(mantraCandidate) === normalizedReadingLine(firstSentence(bhriguToday))
      ? "Choose peace before performance."
      : mantraCandidate;

  return {
    morning: bhriguToday,
    evening: yourTransit,
    bhriguToday,
    yourTransit,
    doText: limitWords(
      doRaw || "Choose one clean action and finish it before seeking signs.",
      34
    ),
    avoidText: limitWords(
      avoidRaw || "Avoid turning silence into evidence, drama, or prophecy.",
      34
    ),
    relationships,
    workMoney,
    innerWeather,
    mantra,
    moonPhaseLine: limitWords(moonPhaseRaw || fallback.moonPhaseLine || "", 12),
    dailyEnergyLine: limitWords(dailyEnergyRaw || fallback.dailyEnergyLine || "", 12),
  };
}

function dailyHoroscopePayload(data = {}) {
  return {
    text: data.rawText || data.text || "",
    dailyTransits: data.dailyTransits || null,
    transitAspects: Array.isArray(data.transitAspects) ? data.transitAspects : [],
    morning: data.morning || "",
    evening: data.evening || "",
    bhriguToday: data.bhriguToday || data.todayLine || "",
    yourTransit: data.yourTransit || data.whyLine || "",
    doText: data.doText ||
      (Array.isArray(data.doLines) ? data.doLines.join(" ") : ""),
    avoidText: data.avoidText ||
      (Array.isArray(data.avoidLines)
        ? data.avoidLines.join(" ")
        : Array.isArray(data.dontLines)
          ? data.dontLines.join(" ")
          : ""),
    relationships: data.relationships || "",
    workMoney: data.workMoney || "",
    innerWeather: data.innerWeather || "",
    mantra: data.mantra || data.focusLine || "",
    transitSummary: data.transitSummary || "",
    moonPhaseLine: data.moonPhaseLine || "",
    dailyEnergyLine: data.dailyEnergyLine || "",
    contentVersion: data.contentVersion || HOME_HOROSCOPE_CONTENT_VERSION,
  };
}

function cosineSimilarity(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b) || a.length === 0 || a.length !== b.length) {
    return 0;
  }

  let dot = 0;
  let normA = 0;
  let normB = 0;

  for (let i = 0; i < a.length; i++) {
    const av = Number(a[i]);
    const bv = Number(b[i]);

    if (!Number.isFinite(av) || !Number.isFinite(bv)) {
      return 0;
    }

    dot += av * bv;
    normA += av * av;
    normB += bv * bv;
  }

  const denom = Math.sqrt(normA) * Math.sqrt(normB);
  return denom === 0 ? 0 : dot / denom;
}

async function generateGeminiEmbedding(text) {
  const response = await axios.post(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY.value()}`,
    {
      model: "models/gemini-embedding-001",
      content: {
        parts: [
          {
            text,
          },
        ],
      },
    }
  );

  return response.data.embedding.values || [];
}

async function generateTarotQueryEmbedding(text) {
  return generateGeminiEmbedding(text);
}

let tarotKnowledgeDocsCache = null;
let tarotKnowledgeDocsCacheAt = 0;
let tarotKnowledgeDocsPromise = null;
const tarotKnowledgeByCardCache = new Map();
let compatibilityKnowledgeDocsCache = null;
let compatibilityKnowledgeDocsCacheAt = 0;
let compatibilityKnowledgeDocsPromise = null;
let geomancyKnowledgeDocsCache = null;
let geomancyKnowledgeDocsCacheAt = 0;
let geomancyKnowledgeDocsPromise = null;

async function readExactTarotKnowledge(cleanCardName) {
  const cacheKey = cleanCardName.toLowerCase();

  if (tarotKnowledgeByCardCache.has(cacheKey)) {
    return tarotKnowledgeByCardCache.get(cacheKey);
  }

  const snap = await admin
    .firestore()
    .collection("tarot_knowledge")
    .where("card", "==", cleanCardName)
    .limit(1)
    .get();

  const text = snap.empty
    ? ""
    : String(snap.docs[0].data()?.reading_style || "").trim();

  tarotKnowledgeByCardCache.set(cacheKey, text);
  return text;
}

async function readTarotKnowledgeDocs() {
  const now = Date.now();

  if (
    tarotKnowledgeDocsCache &&
    now - tarotKnowledgeDocsCacheAt < KNOWLEDGE_CACHE_TTL_MS
  ) {
    return tarotKnowledgeDocsCache;
  }

  if (tarotKnowledgeDocsPromise) {
    return tarotKnowledgeDocsPromise;
  }

  tarotKnowledgeDocsPromise = admin
    .firestore()
    .collection("tarot_knowledge")
    .get()
    .then((snap) => {
      const docs = [];
      snap.forEach((doc) => {
        docs.push(doc.data() || {});
      });
      tarotKnowledgeDocsCache = docs;
      tarotKnowledgeDocsCacheAt = Date.now();
      return docs;
    })
    .finally(() => {
      tarotKnowledgeDocsPromise = null;
    });

  return tarotKnowledgeDocsPromise;
}

async function readCompatibilityKnowledgeDocs() {
  const now = Date.now();

  if (
    compatibilityKnowledgeDocsCache &&
    now - compatibilityKnowledgeDocsCacheAt < KNOWLEDGE_CACHE_TTL_MS
  ) {
    return compatibilityKnowledgeDocsCache;
  }

  if (compatibilityKnowledgeDocsPromise) {
    return compatibilityKnowledgeDocsPromise;
  }

  compatibilityKnowledgeDocsPromise = admin
    .firestore()
    .collection("compatibility_knowledge")
    .get()
    .then((snap) => {
      const docs = [];
      snap.forEach((doc) => {
        docs.push(doc.data() || {});
      });
      compatibilityKnowledgeDocsCache = docs;
      compatibilityKnowledgeDocsCacheAt = Date.now();
      return docs;
    })
    .finally(() => {
      compatibilityKnowledgeDocsPromise = null;
    });

  return compatibilityKnowledgeDocsPromise;
}

async function readGeomancyKnowledgeDocs() {
  const now = Date.now();

  if (
    geomancyKnowledgeDocsCache &&
    now - geomancyKnowledgeDocsCacheAt < KNOWLEDGE_CACHE_TTL_MS
  ) {
    return geomancyKnowledgeDocsCache;
  }

  if (geomancyKnowledgeDocsPromise) {
    return geomancyKnowledgeDocsPromise;
  }

  geomancyKnowledgeDocsPromise = admin
    .firestore()
    .collection("geomancy_knowledge")
    .get()
    .then((snap) => {
      const docs = [];
      snap.forEach((doc) => {
        docs.push(doc.data() || {});
      });
      geomancyKnowledgeDocsCache = docs;
      geomancyKnowledgeDocsCacheAt = Date.now();
      return docs;
    })
    .finally(() => {
      geomancyKnowledgeDocsPromise = null;
    });

  return geomancyKnowledgeDocsPromise;
}

function formatGeomancyKnowledge(doc, role) {
  const domains = doc.domains || {};
  const roleText =
    role === "judge"
      ? doc.as_judge
      : role === "reconciler"
        ? doc.as_reconciler
        : doc.as_witness;

  return [
    `${doc.figure} (${doc.latin}) - ${doc.planet}, ${doc.zodiac}, ${doc.element}.`,
    String(doc.favorability || "").trim(),
    String(doc.core || "").trim(),
    String(roleText || "").trim(),
    `In love: ${String(domains.love || "").trim()}`,
    `In career: ${String(domains.career || "").trim()}`,
    `In money: ${String(domains.money || "").trim()}`,
    `In health: ${String(domains.health || "").trim()}`,
    `Timing: ${String(domains.timing || "").trim()}`,
  ]
    .filter((line) => line && !/^In \w+:\s*$/.test(line) && line !== "Timing:")
    .join("\n");
}

// Strict retrieval: the geomancy reading must be grounded in the seeded
// knowledge base, so a missing figure throws instead of degrading to a
// generic hardcoded meaning.
async function retrieveGeomancyKnowledge({ figureName, role }) {
  const cleanFigureName = String(figureName || "").trim().toLowerCase();

  if (!cleanFigureName) {
    throw new Error("Geomancy figure name missing for knowledge retrieval.");
  }

  const docs = await readGeomancyKnowledgeDocs();
  const match = docs.find(
    (doc) =>
      String(doc.figure || "").trim().toLowerCase() === cleanFigureName
  );

  if (!match) {
    throw new Error(
      `Geomancy knowledge missing for figure: ${figureName}. Seed the geomancy_knowledge collection.`
    );
  }

  return formatGeomancyKnowledge(match, role);
}

async function retrieveTarotKnowledge({
  cardName,
  keywords,
  fallback,
}) {
  const cleanCardName = String(cardName || "").trim();
  const cleanFallback = String(fallback || "").trim();
  const query = `${cleanCardName}: ${String(keywords || "").trim()}`;

  try {
    if (cleanCardName) {
      const exactKnowledge = await readExactTarotKnowledge(cleanCardName);

      if (exactKnowledge) {
        return exactKnowledge;
      }
    }
  } catch (error) {
    console.error("Tarot exact lookup error:", error.message);
  }

  let queryEmbedding = [];

  try {
    queryEmbedding = await generateTarotQueryEmbedding(query);
  } catch (error) {
    console.error(
      "Tarot RAG embedding error:",
      error.response?.data || error.message
    );
  }

  try {
    const docs = await readTarotKnowledgeDocs();

    let exactText = "";
    let bestText = cleanFallback;
    let bestScore = -1;

    docs.forEach((data) => {
      const docCardName = String(data.card || "").trim();
      const readingStyle = String(data.reading_style || "").trim();

      if (
        cleanCardName &&
        docCardName.toLowerCase() === cleanCardName.toLowerCase() &&
        readingStyle
      ) {
        exactText = readingStyle;
      }

      if (queryEmbedding.length > 0 && Array.isArray(data.embedding)) {
        const score = cosineSimilarity(queryEmbedding, data.embedding);

        if (score > bestScore && readingStyle) {
          bestScore = score;
          bestText = readingStyle;
        }
      }
    });

    return exactText || bestText || cleanFallback;
  } catch (error) {
    console.error("Tarot RAG Firestore error:", error.message);
    return cleanFallback;
  }
}


module.exports = {
  onCall,
  HttpsError,
  defineSecret,
  admin,
  axios,
  crypto,
  moment,
  tzLookup,
  GOOGLE_PLACES_API_KEY,
  FUNCTION_REGION,
  AI_REQUEST_TIMEOUT_MS,
  PLACES_REQUEST_TIMEOUT_MS,
  GROQ_API_KEY,
  GEMINI_API_KEY,
  GEMINI_FLASH_LITE_MODEL,
  BHRIGU_TUNED_MODEL,
  GROQ_PARTNER_MATCH_MODEL,
  GROQ_BHRIGU_CHAT_MODEL,
  TAROT_READING_CONTENT_VERSION,
  GEOMANCY_READING_CONTENT_VERSION,
  TAROT_MAX_OUTPUT_TOKENS,
  GEOMANCY_MAX_OUTPUT_TOKENS,
  MYSTIC_READING_TEMPERATURE,
  TAROT_READING_TEMPERATURE,
  GEOMANCY_READING_TEMPERATURE,
  APP_CHECK_ENFORCEMENT_ENABLED,
  KNOWLEDGE_CACHE_TTL_MS,
  BHRIGU_CHAT_KNOWLEDGE_LIMIT,
  HORIZONS_API_URL,
  HORIZONS_TIMEOUT_MS,
  MILLISECONDS_PER_DAY,
  DEG_TO_RAD,
  RAD_TO_DEG,
  CHART_CALCULATION_VERSION,
  HOME_HOROSCOPE_CONTENT_VERSION,
  ZODIAC_SIGNS,
  NAKSHATRAS,
  HORIZONS_BODIES,
  shouldUsePremiumReadingModel,
  messageListToPrompt,
  stableStringify,
  cacheKeyForReading,
  normalizeAiResponseLanguage,
  resolveAiResponseLanguage,
  languageInstruction,
  ensureHinglishText,
  userReadingCacheRef,
  readCachedReading,
  writeCachedReading,
  callableRuntimeOptions,
  requireCallableAuth,
  requireRequestData,
  boundedString,
  boundedPlainObject,
  boundedArray,
  cleanMetricKey,
  recordUsageEvent,
  isTimeoutError,
  isRetryableAiError,
  generateGeminiReadingText,
  generateGroqReadingText,
  generateUserReadingText,
  normalizeDegrees,
  roundTo,
  signFromLongitude,
  degreeWithinSign,
  nakshatraFromMoon,
  parseBirthMinutes,
  parseBirthDateParts,
  detectTimezoneOffsetHours,
  timezoneNameForBirthPlace,
  parseBirthDateTimeToUtc,
  julianDateFromUtc,
  julianCenturiesSinceJ2000,
  daysSinceJ2000,
  calculateLahiriAyanamsa,
  calculateMeanLunarNodeLongitude,
  siderealLunarNodeBodies,
  meanObliquityDegrees,
  greenwichMeanSiderealTimeDegrees,
  localSiderealTimeDegrees,
  parseHorizonsVector,
  parseHorizonsObserverEcliptic,
  fetchHorizonsJson,
  fetchHorizonsObserverEcliptic,
  signedAngularDistance,
  fetchHorizonsLongitude,
  fetchHorizonsVectorLongitude,
  calculateAscendant,
  houseFromAscendant,
  planetModelsFromLongitudes,
  buildWesternChart,
  buildVedicChart,
  calculateNatalChartForBirthData,
  parseDateKeyToUtcNoon,
  calculateDailyTransitsForDateKey,
  getDailyTransits,
  currentSkyCacheKey,
  dateKeyFromUtcDate,
  planetSnapshotFromBodyPosition,
  currentSkyFromDailyTransits,
  calculateCurrentSkySnapshot,
  hasCompleteCurrentSkyPlanets,
  hasCurrentSkyPlanets,
  getCurrentSkySnapshot,
  transitPlanetListFromCurrentSky,
  selectNatalChartForTransits,
  maxOrbForTransitPlanet,
  transitAspectTheme,
  calculateTransitAspectMatches,
  messageHasKeyword,
  detectQuestionCategory,
  categoryFocus,
  knowledgeTextFromDoc,
  searchableKnowledgeText,
  keywordKnowledgeScore,
  formatBhriguKnowledgeChunk,
  bhriguBookKnowledgeDocsCache,
  bhriguBookKnowledgeDocsCacheAt,
  bhriguBookKnowledgeDocsPromise,
  readBhriguBookKnowledgeDocs,
  retrieveBhriguChatKnowledge,
  retrieveLikedAnswerExamples,
  cleanGeneratedLine,
  firstSentence,
  terminalPunctuation,
  normalizedReadingLine,
  limitWords,
  splitGeneratedLines,
  ensureActionLines,
  longitudeFromPlacement,
  dailyTransitAspectOrb,
  calculateTransitAspects,
  parseDailyHoroscopeText,
  dailyHoroscopePayload,
  cosineSimilarity,
  generateGeminiEmbedding,
  generateTarotQueryEmbedding,
  tarotKnowledgeDocsCache,
  tarotKnowledgeDocsCacheAt,
  tarotKnowledgeDocsPromise,
  tarotKnowledgeByCardCache,
  compatibilityKnowledgeDocsCache,
  compatibilityKnowledgeDocsCacheAt,
  compatibilityKnowledgeDocsPromise,
  readExactTarotKnowledge,
  readTarotKnowledgeDocs,
  readCompatibilityKnowledgeDocs,
  retrieveTarotKnowledge,
  readGeomancyKnowledgeDocs,
  retrieveGeomancyKnowledge,
};
