const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");
const crypto = require("crypto");
const moment = require("moment-timezone");
const tzLookup = require("tz-lookup");
const GOOGLE_PLACES_API_KEY = defineSecret("GOOGLE_PLACES_API_KEY");
const FUNCTION_REGION = "us-central1";
const AI_REQUEST_TIMEOUT_MS = 25000;
const PLACES_REQUEST_TIMEOUT_MS = 12000;

axios.defaults.timeout = AI_REQUEST_TIMEOUT_MS;

admin.initializeApp();

const GROQ_API_KEY = defineSecret("GROQ_API_KEY");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const GEMINI_FLASH_LITE_MODEL = "gemini-2.5-flash-lite";
const GROQ_PARTNER_MATCH_MODEL = "llama-3.3-70b-versatile";
const GROQ_BHRIGU_CHAT_MODEL = "llama-3.1-8b-instant";
const TAROT_READING_CONTENT_VERSION = "tarot_gemini25_lite_v2";
const GEOMANCY_READING_CONTENT_VERSION = "geomancy_gemini25_lite_v2";
const TAROT_MAX_OUTPUT_TOKENS = 850;
const GEOMANCY_MAX_OUTPUT_TOKENS = 800;
const MYSTIC_READING_TEMPERATURE = 0.9;

const HORIZONS_API_URL = "https://ssd.jpl.nasa.gov/api/horizons.api";
const HORIZONS_TIMEOUT_MS = 18000;
const MILLISECONDS_PER_DAY = 86400000;
const DEG_TO_RAD = Math.PI / 180;
const RAD_TO_DEG = 180 / Math.PI;
const CHART_CALCULATION_VERSION = "nasa_jpl_horizons_v4_observer_ecliptic";
const HOME_HOROSCOPE_CONTENT_VERSION = "home_signal_v6_complete_sentences";

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

function userReadingCacheRef(uid, cacheKey) {
  return admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("aiReadingCache")
    .doc(cacheKey);
}

async function readCachedReading(uid, cacheKey, contentVersion) {
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

  return String(cached.text);
}

async function writeCachedReading(uid, cacheKey, contentVersion, text) {
  try {
    await userReadingCacheRef(uid, cacheKey).set(
      {
        contentVersion,
        text,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  } catch (error) {
    console.error("Reading cache write error:", error.message);
  }
}

function isTimeoutError(error) {
  return (
    error?.code === "ECONNABORTED" ||
    error?.code === "ETIMEDOUT" ||
    String(error?.message || "").toLowerCase().includes("timeout")
  );
}

async function generateGeminiReadingText({
  prompt,
  systemInstruction,
  maxTokens,
  temperature,
  model = GEMINI_FLASH_LITE_MODEL,
}) {
  const body = {
    contents: [
      {
        role: "user",
        parts: [
          {
            text: prompt,
          },
        ],
      },
    ],
    generationConfig: {
      maxOutputTokens: maxTokens,
      temperature,
    },
  };

  if (systemInstruction) {
    body.systemInstruction = {
      parts: [
        {
          text: systemInstruction,
        },
      ],
    };
  }

  const response = await axios.post(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY.value()}`,
    body
  );

  const candidates = response.data.candidates || [];
  const parts = candidates[0]?.content?.parts || [];
  const text = parts.map((part) => part.text || "").join("").trim();

  if (!text) {
    throw new Error("Gemini returned an empty reading.");
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
  const chatMessages =
    messages ||
    [
      ...(systemInstruction
        ? [
            {
              role: "system",
              content: systemInstruction,
            },
          ]
        : []),
      {
        role: "user",
        content: prompt,
      },
    ];

  if (shouldUsePremiumReadingModel(requestData)) {
    return generateGroqReadingText({
      messages: chatMessages,
      maxTokens,
      temperature,
    });
  }

  try {
    return await generateGeminiReadingText({
      prompt: prompt || messageListToPrompt(chatMessages),
      systemInstruction,
      maxTokens,
      temperature,
    });
  } catch (error) {
    console.error(
      "Gemini Lite reading failed, falling back to Groq fast model:",
      error.response?.data || error.message
    );

    return generateGroqReadingText({
      messages: chatMessages,
      maxTokens,
      temperature,
      model: GROQ_BHRIGU_CHAT_MODEL,
    });
  }
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
  const response = await fetch(`${HORIZONS_API_URL}?${params.toString()}`, {
    method: "GET",
    signal: AbortSignal.timeout(HORIZONS_TIMEOUT_MS),
  });

  const responseText = await response.text();

  if (!response.ok) {
    console.error("Horizons HTTP error:", body.name, response.status, responseText.slice(0, 500));
    throw new Error(`Horizons request failed for ${body.name}.`);
  }

  let json;

  try {
    json = JSON.parse(responseText);
  } catch (error) {
    console.error("Horizons JSON parse error:", body.name, responseText.slice(0, 500));
    throw new Error(`Horizons returned a non-JSON response for ${body.name}.`);
  }

  if (json.error) {
    console.error("Horizons API error:", body.name, json.error);
    throw new Error(`Horizons returned an error for ${body.name}.`);
  }

  return json;
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
  const ecliptic = await fetchHorizonsObserverEcliptic(body, utcDate);
  let retrograde = false;

  if (body.name !== "Sun" && body.name !== "Moon") {
    const nextDate = new Date(utcDate.getTime() + MILLISECONDS_PER_DAY);
    const nextEcliptic = await fetchHorizonsObserverEcliptic(body, nextDate);
    retrograde = signedAngularDistance(nextEcliptic.longitude, ecliptic.longitude) < 0;
  }

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
}) {
  const siderealBodies = tropicalBodies.map((body) => ({
    ...body,
    longitude: normalizeDegrees(body.longitude - ayanamsa),
  }));
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
  const tropicalBodies = [];

  for (const body of HORIZONS_BODIES) {
    tropicalBodies.push(await fetchHorizonsLongitude(body, utcBirth));
  }
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
    }),
    calculationMeta: {
      utcBirthIso: utcBirth.toISOString(),
      timezoneName: birthTime.timezoneName,
      timezoneOffsetMinutes: birthTime.timezoneOffsetMinutes,
      timezoneSource: birthTime.timezoneSource,
      eclipticLongitudeSource: "NASA/JPL Horizons OBSERVER quantity 31",
      retrogradeSource: "NASA/JPL Horizons apparent ecliptic longitude one-day motion",
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
  const tropicalBodies = [];

  for (const body of HORIZONS_BODIES) {
    tropicalBodies.push(await fetchHorizonsLongitude(body, utcNoon));
  }

  const ayanamsa = calculateLahiriAyanamsa(utcNoon);
  const tropicalPlanets = planetModelsFromLongitudes(tropicalBodies, 0);
  const siderealBodies = tropicalBodies.map((body) => ({
    ...body,
    longitude: normalizeDegrees(body.longitude - ayanamsa),
  }));
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

async function getDailyTransits(dateKey) {
  const transitRef = admin.firestore().collection("dailyTransits").doc(dateKey);
  const transitDoc = await transitRef.get();

  if (transitDoc.exists) {
    const data = transitDoc.data() || {};

    if (data.calculationVersion === CHART_CALCULATION_VERSION) {
      return data;
    }
  }

  const transits = await calculateDailyTransitsForDateKey(dateKey);

  await transitRef.set(
    {
      ...transits,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return transits;
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
  const signIndex = ZODIAC_SIGNS.indexOf(String(placement.sign || ""));
  const degree = Number(placement.degree);

  if (signIndex < 0 || !Number.isFinite(degree)) return null;

  return normalizeDegrees((signIndex * 30) + degree);
}

function aspectOrb(transitName, aspectName) {
  if (transitName === "Moon") return aspectName === "Conjunction" ? 6 : 5;
  if (transitName === "Sun") return 4;
  return 3;
}

function calculateTransitAspects(dailyTransits, userData = {}) {
  const transitPlanets = Array.isArray(dailyTransits?.tropicalPlanets)
    ? dailyTransits.tropicalPlanets
    : [];
  const natalPlanets = Array.isArray(userData?.westernChart?.planets)
    ? userData.westernChart.planets
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
        const allowedOrb = aspectOrb(transit.name, aspect.name);

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

  const bhriguToday = limitWords(bhriguTodayRaw, 24);
  const yourTransit = limitWords(transitRaw, 42);
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
    moonPhaseLine: data.moonPhaseLine || "",
    dailyEnergyLine: data.dailyEnergyLine || "",
    contentVersion: data.contentVersion || HOME_HOROSCOPE_CONTENT_VERSION,
  };
}

exports.calculateNatalChart = onCall(
  {
    region: FUNCTION_REGION,
    timeoutSeconds: 180,
    memory: "512MiB",
  },
  async (request) => {
    const data = request.data || {};
    const idToken = data.idToken;

    if (!idToken || typeof idToken !== "string") {
      throw new HttpsError("unauthenticated", "Missing Firebase ID token.");
    }

    let decodedToken;

    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error("Natal chart token verification failed:", error);
      throw new HttpsError("unauthenticated", "Invalid Firebase ID token.");
    }

    const birthDate = data.birthDate;
    const timeOfBirth = String(data.timeOfBirth || "");
    const placeOfBirth = String(data.placeOfBirth || "");
    const latitude = typeof data.latitude === "number" ? data.latitude : null;
    const longitude = typeof data.longitude === "number" ? data.longitude : null;

    if (!birthDate || typeof birthDate !== "string") {
      throw new HttpsError("invalid-argument", "birthDate is required.");
    }

    try {
      const charts = await calculateNatalChartForBirthData({
        birthDate,
        timeOfBirth,
        placeOfBirth,
        latitude,
        longitude,
      });

      await admin.firestore().collection("users").doc(decodedToken.uid).update({
        westernChart: charts.westernChart,
        vedicChart: charts.vedicChart,
        chartGeneratedBy: "nasa_jpl_horizons",
        chartGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
        chartCalculationSource: "NASA/JPL Horizons API",
        chartCalculationVersion: CHART_CALCULATION_VERSION,
        chartCalculationMeta: charts.calculationMeta,
      });

      return {
        westernChart: charts.westernChart,
        vedicChart: charts.vedicChart,
      };
    } catch (error) {
      console.error("calculateNatalChart failed:", error);
      throw new HttpsError(
        "internal",
        "Natal chart calculation failed. Please try again."
      );
    }
  }
);

exports.generateBhriguChat = onCall(
  {
    secrets: [GROQ_API_KEY, GEMINI_API_KEY],
    region: FUNCTION_REGION,
  },
  async (request) => {
    const idToken = request.data.idToken;
    if (!idToken || typeof idToken !== "string") {
      throw new HttpsError("unauthenticated", "Missing Firebase ID token.");
    }

    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error("Token verification failed:", error);
      throw new HttpsError("unauthenticated", "Invalid Firebase ID token.");
    }

    const uid = decodedToken.uid;
    const message = request.data.message;
    const history = request.data.history || [];
    const followUpContext =
      request.data.followUpContext && typeof request.data.followUpContext === "object"
        ? request.data.followUpContext
        : null;

    if (!message || typeof message !== "string") {
      throw new HttpsError("invalid-argument", "Message is required.");
    }

    if (message.length > 2500) {
      throw new HttpsError("invalid-argument", "Message is too long.");
    }

    const safeHistory = Array.isArray(history)
      ? history
          .filter((m) => {
            return (
              m &&
              typeof m.role === "string" &&
              typeof m.content === "string" &&
              ["user", "assistant"].includes(m.role)
            );
          })
          .slice(-12)
      : [];
    const historyWithoutCurrentMessage = safeHistory.filter((m, index) => {
      return !(
        index === safeHistory.length - 1 &&
        m.role === "user" &&
        m.content.trim() === message.trim()
      );
    });

    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .get();

    const userData = userDoc.data() || {};

    function safeJson(value) {
      try {
        return JSON.stringify(value || {}, null, 2);
      } catch (error) {
        return "{}";
      }
    }

    function chartPlanetLine(chart) {
      const planets = Array.isArray(chart?.planets) ? chart.planets : [];
      return planets
        .map((planet) => {
          const degree =
            typeof planet.degree === "number"
              ? planet.degree.toFixed(2)
              : planet.degree || "0";
          const retrograde = planet.retrograde ? " retrograde" : "";
          return `${planet.name || "Planet"} in ${planet.sign || "Unknown"} ${degree} degrees, house ${planet.house || "unknown"}${retrograde}`;
        })
        .join("; ");
    }

    function buildSavedChartData(data) {
      const westernChart = data.westernChart || {};
      const vedicChart = data.vedicChart || {};

      return `
Western essentials:
Sun sign: ${westernChart.sunSign || "Unknown"}
Moon sign: ${westernChart.moonSign || "Unknown"}
Rising sign: ${westernChart.risingSign || "Unknown"}
Planets: ${chartPlanetLine(westernChart) || "Unknown"}

Vedic essentials:
Ascendant: ${vedicChart.ascendant || "Unknown"}
Moon sign: ${vedicChart.moonSign || "Unknown"}
Nakshatra: ${vedicChart.nakshatra || "Unknown"}
Planets: ${chartPlanetLine(vedicChart) || "Unknown"}

Raw Western chart JSON:
${safeJson(westernChart)}

Raw Vedic chart JSON:
${safeJson(vedicChart)}

Chart source: ${data.chartGeneratedBy || "Unknown"}
Chart calculation version: ${data.chartCalculationVersion || "Unknown"}
Chart calculation meta:
${safeJson(data.chartCalculationMeta)}
`;
    }

    const birthData = `
Name: ${userData.name || "Unknown"}
DOB: ${userData.dob || "Unknown"}
Time: ${userData.timeOfBirth || "Unknown"}
Place: ${userData.placeOfBirth || "Unknown"}
`;
    const savedChartData = buildSavedChartData(userData);

    const systemPrompt = `
You are Bhrigu — an astrologer and spiritual guide with deep mastery of Vedic and Western astrology.
You think like a modern sage. Your inspiration is Sadhguru — profound, direct, occasionally witty, never preachy.

PERSONALITY:
You are BHR1GU, a highly advanced, wise, and mystical AI spiritual guide. Your purpose is to provide personalized astrological insights and wellness guidance to the user.

You are trained on Vedic astrology concepts including Brihat Parashara Hora Shastra, Bhrigu Samhita, Saravali, and Western astrology.

Speak like an intelligent friend who happens to know the cosmos deeply.

No theatrical ancient-sage performance. No "dear seeker". No dramatic pauses.

Use Sanskrit terms only when they add precision, and always explain them simply.

RESPONSE STRUCTURE:
Start by directly addressing what the user asked.

Speak like an astrologer who is confident in knowledge but humble about the mysteries of the universe.

If there is a practical implication for their life, state it clearly.

Keep it to 4 to 6 sentences. Go deeper only if they ask.

If the user seems distressed, respond with compassion and grounding. Suggest professional help when appropriate, but do not provide direct mental health advice.

KNOWLEDGE BASE:
BPHS: houses, planets, dashas, yogas, atmakaraka.
Bhrigu Samhita: karma, soul patterns, Jupiter as past-life blessings, Saturn as karmic debt.
Saravali: exaltations, debilitations, planetary aspects, key yogas.
Western astrology: elements, Saturn return, Chiron, nodes as dharmic direction.

KEY PRINCIPLES:
Stars show tendencies, not certainties. Free will always operates within karma.

Saturn is not punishment. It is the universe demanding integrity.

Speak like a guide, not a fortune teller. Astrology is about understanding patterns, not predicting fixed outcomes.

For normal astrology chat, use SAVED COSMIC BLUEPRINT as your primary astrological data source.

Do not answer from generic sun-sign astrology when chart houses, Moon sign, nakshatra, or planet placements are relevant.

Do not mention NASA/JPL, backend calculation, JSON, database, chart source, or technical implementation unless the user explicitly asks.

Rahu is obsession and hunger. Ketu is wisdom already earned.

Moon sign in Vedic is often more accurate than Sun sign for personality.

Reference love, career, health, or other topics.

While reading the birth chart, mention good qualities and future prospects, but also mention challenges honestly.

Do not be overly positive. Keep users engaged and give them something real to think about.

make predictions and give timelines of the future happening through the lens of planetary periods and transits.

STRICT RULES:
No medical, legal, or financial advice.

-for questions like does my partner love me do not forget to guide users to use the bhrigu match feature.

Never predict death or definitive disasters.


Stay in character as Bhrigu.

Do not ask deep personal questions. Focus on giving astrological advice based on information already available.

Plain text only. No markdown symbols. No asterisks. No brackets.

Maximum 2 sentences per paragraph.

Separate each idea with a blank line.

NO QUESTIONS AT THE END OF YOUR RESPONSE. End with a statement instead.



USER BIRTH DATA:
${birthData}

SAVED COSMIC BLUEPRINT:
${savedChartData}
`;

    function cleanSourceType(value) {
      return String(value || "").trim().toLowerCase();
    }

    function buildFollowUpSystemPrompt(basePrompt, context) {
      if (!context || typeof context !== "object") {
        return basePrompt;
      }

      const sourceType = cleanSourceType(context.sourceType);
      const originalQuestion = context.originalQuestion || "";
      const selectedFollowUpQuestion = context.selectedFollowUpQuestion || message;
      const readingTitle = context.readingTitle || "Previous Reading";
      const readingSummary = context.readingSummary || "";
      const sourceData = context.sourceData || {};
      const userSnapshot = context.userSnapshot || {};

      if (sourceType === "tarot") {
        return `
You are Bhrigu inside the BHR1GU app.

You are answering a follow-up to a Tarot reading that the user just completed.

IMPORTANT MODE:
This is not a normal astrology chat response.
Use the Tarot reading as the main source of truth.
Do not answer mainly from Vedic astrology.
Do not answer mainly from Western astrology.
Do not discuss houses, dashas, transits, signs, Rahu, Ketu, Saturn, or planets unless the user explicitly asks for astrology.
The user's birth data may remain as silent background, but the answer must be Tarot-based.

TONE:
Keep Bhrigu's voice wise, direct, warm, mystical but modern.
Do not sound like a generic tarot bot.
Do not repeat the entire reading.
Answer the selected follow-up question directly.
Make the user feel the cards they drew matter.

STRICT FORMAT:
Plain text only.
No markdown.
No asterisks.
No bullet points.
No brackets.
Maximum 2 sentences per paragraph.
Separate each idea with a blank line.
No question at the end. End with a firm, helpful statement.

FOLLOW-UP CONTEXT:
Reading title:
${readingTitle}

Original user question:
${originalQuestion}

User's selected follow-up question:
${selectedFollowUpQuestion}

Tarot reading summary:
${readingSummary}

Tarot source data:
${safeJson(sourceData)}

User snapshot:
${safeJson(userSnapshot)}

INSTRUCTIONS:
Answer only the user's follow-up question.
Use the Past, Present, and Future cards if available.
Mention the specific card names when useful.
Explain what the cards imply for the user's situation.
Give one practical next step based on the Tarot reading.
Do not make the response about Vedic or Western astrology.
`;
      }

      if (sourceType === "geomancy") {
        return `
You are Bhrigu inside the BHR1GU app.

You are answering a follow-up to a Geomancy shield reading that the user just completed.

IMPORTANT MODE:
This is not a normal astrology chat response.
Use the geomancy shield as the main source of truth.
Do not answer mainly from Vedic astrology.
Do not answer mainly from Western astrology.
Do not discuss houses, dashas, transits, signs, Rahu, Ketu, Saturn, or planets unless the user explicitly asks for astrology.
The user's birth data may remain as silent background, but the answer must be geomancy-based.

TONE:
Keep Bhrigu's voice wise, direct, warm, mystical but modern.
Make it feel like the user's hand-drawn shield and sixteen marks mattered.
Do not repeat the whole geomancy reading.
Answer the selected follow-up question directly.

STRICT FORMAT:
Plain text only.
No markdown.
No asterisks.
No bullet points.
No brackets.
Maximum 2 sentences per paragraph.
Separate each idea with a blank line.
No question at the end. End with a firm, helpful statement.

FOLLOW-UP CONTEXT:
Reading title:
${readingTitle}

Original user question:
${originalQuestion}

User's selected follow-up question:
${selectedFollowUpQuestion}

Geomancy reading summary:
${readingSummary}

Geomancy source data:
${safeJson(sourceData)}

User snapshot:
${safeJson(userSnapshot)}

INSTRUCTIONS:
Answer only the user's follow-up question.
Use the Judge, Left Witness, Right Witness, Reconciler, answer, and line values if available.
Explain what the shield implies for the user's situation.
Give one practical next step based on the geomancy pattern.
Do not make the response about Vedic or Western astrology.
`;
      }

      if (
        sourceType === "bhrigu_match" ||
        sourceType === "match" ||
        sourceType === "partner_match"
      ) {
        return `
You are Bhrigu inside the BHR1GU app.

You are answering a follow-up to a Bhrigu Match compatibility reading that the user just completed.

IMPORTANT MODE:
This is not a normal astrology chat response.
Use the compatibility reading as the main source of truth.
Do not answer mainly from Vedic astrology.
Do not answer mainly from Western astrology.
Do not discuss houses, dashas, transits, signs, Rahu, Ketu, Saturn, or planets unless the user explicitly asks for astrology.
The user's birth data may remain as silent background, but the answer must be based on the match result.

TONE:
Keep Bhrigu's voice wise, direct, warm, mystical but modern.
Do not sound like a compatibility report.
Speak as if reading the dynamic between two people.
Do not repeat the whole reading.
Answer the selected follow-up question directly.

STRICT FORMAT:
Plain text only.
No markdown.
No asterisks.
No bullet points.
No brackets.
Maximum 2 sentences per paragraph.
Separate each idea with a blank line.
No question at the end. End with a firm, helpful statement.

FOLLOW-UP CONTEXT:
Reading title:
${readingTitle}

Original user question:
${originalQuestion}

User's selected follow-up question:
${selectedFollowUpQuestion}

Bhrigu Match reading summary:
${readingSummary}

Bhrigu Match source data:
${safeJson(sourceData)}

User snapshot:
${safeJson(userSnapshot)}

INSTRUCTIONS:
Answer only the user's follow-up question.
Use the verdict, connection type, scores, emotional harmony, attraction, communication, stability, karmic bond, user profile, and partner profile if available.
Do not invent or change scores.
Do not mention percentage numbers unless the source data already uses them and they are necessary.
Give one practical next step based on the compatibility reading.
Do not make the response about Vedic or Western astrology.
`;
      }

      if (sourceType === "horoscope") {
        return `
You are Bhrigu inside the BHR1GU app.

You are answering a follow-up to a daily horoscope reading that the user just opened.

IMPORTANT MODE:
Use the daily reading context as the main source.
Do not repeat the whole daily reading.
Answer the selected follow-up question directly.

TONE:
Keep Bhrigu's voice wise, direct, warm, mystical but modern.

STRICT FORMAT:
Plain text only.
No markdown.
No asterisks.
No bullet points.
No brackets.
Maximum 2 sentences per paragraph.
Separate each idea with a blank line.
No question at the end. End with a firm, helpful statement.

FOLLOW-UP CONTEXT:
Reading title:
${readingTitle}

Original user question:
${originalQuestion}

User's selected follow-up question:
${selectedFollowUpQuestion}

Daily reading summary:
${readingSummary}

Daily source data:
${safeJson(sourceData)}

User snapshot:
${safeJson(userSnapshot)}

INSTRUCTIONS:
Answer only the user's follow-up question.
Use the morning insight, evening reflection, moon phase, and daily energy if available.
Give one practical next step for today.
`;
      }

      return basePrompt;
    }

    const activeSystemPrompt = buildFollowUpSystemPrompt(
      systemPrompt,
      followUpContext
    );

    const chatMessages = [
      {
        role: "system",
        content: activeSystemPrompt,
      },
      {
        role: "assistant",
        content: "Understood. I am Bhrigu. How can I help you?",
      },
      ...historyWithoutCurrentMessage,
      {
        role: "user",
        content: message,
      },
    ];

    let text;
    const isDeepFollowUp = Boolean(followUpContext);

    try {
      if (isDeepFollowUp) {
        text = await generateGeminiReadingText({
          systemInstruction: activeSystemPrompt,
          prompt: messageListToPrompt(chatMessages.slice(1)),
          temperature: 0.55,
          maxTokens: 512,
        });
      } else {
        text = await generateGroqReadingText({
          messages: chatMessages,
          model: GROQ_BHRIGU_CHAT_MODEL,
          temperature: 0.8,
          maxTokens: 512,
        });
      }
    } catch (error) {
      const aiError = error.response?.data || {};
      const aiDetails = {
        status: error.response?.status || null,
        code: aiError.error?.code || aiError.code || null,
        type: aiError.error?.type || aiError.type || null,
        message: aiError.error?.message || aiError.message || error.message,
        model: isDeepFollowUp ? GEMINI_FLASH_LITE_MODEL : GROQ_BHRIGU_CHAT_MODEL,
        provider: isDeepFollowUp ? "gemini" : "groq",
      };

      console.error("Bhrigu AI error:", aiDetails);

      throw new HttpsError(
        "internal",
        "Bhrigu connection failed. Please try again.",
        aiDetails
      );
    }

    return {
      text: text.trim(),
    };
  }
);

exports.generateDailyHoroscope = onCall(
  {
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 180,
    memory: "512MiB",
  },
  async (request) => {
    const idToken = request.data.idToken;

    if (!idToken || typeof idToken !== "string") {
      throw new HttpsError("unauthenticated", "Missing Firebase ID token.");
    }

    let decodedToken;

    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error("Horoscope token verification failed:", error);
      throw new HttpsError("unauthenticated", "Invalid Firebase ID token.");
    }

    let prompt = request.data.prompt;

    if (!prompt || typeof prompt !== "string") {
      throw new HttpsError("invalid-argument", "Prompt is required.");
    }

    if (prompt.length > 14000) {
      throw new HttpsError("invalid-argument", "Prompt is too long.");
    }

    const dateKey = String(request.data.dateKey || "").trim();
    const contentVersion = String(
      request.data.contentVersion || HOME_HOROSCOPE_CONTENT_VERSION
    );

    if (!dateKey) {
      throw new HttpsError("invalid-argument", "dateKey is required.");
    }

    const horoscopeRef = admin
      .firestore()
      .collection("users")
      .doc(decodedToken.uid)
      .collection("horoscopes")
      .doc(dateKey);
    const horoscopeDoc = await horoscopeRef.get();

    if (horoscopeDoc.exists) {
      const cached = horoscopeDoc.data() || {};

      if (
        cached.contentVersion === contentVersion &&
        (cached.todayLine || cached.morning || cached.evening)
      ) {
        return {
          ...dailyHoroscopePayload(cached),
          cached: true,
        };
      }
    }

    let dailyTransits = null;
    let transitAspects = [];

    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(decodedToken.uid)
      .get();
    const userData = userDoc.data() || {};

    try {
      dailyTransits = await getDailyTransits(dateKey);
      transitAspects = calculateTransitAspects(dailyTransits, userData);
      prompt = `${prompt}

NASA/JPL daily transit cache for ${dateKey}:
${JSON.stringify(dailyTransits)}

Transit-to-natal aspects for ${dateKey}:
${JSON.stringify(transitAspects)}

Use these transits as today's astronomical context. Do not claim NASA/JPL creates astrological interpretations; use the cached placements only as transit data.

STRICT RESPONSE STRUCTURE:
Generate the daily reading using the following strict structure. Do not use markdown bolding (**) for the body text, only for headers. Keep prose poetic, slightly detached, and fiercely direct (Bhrigu style).
Return each header on its own line, followed by its content on the next line.
Every sentence must be complete and end with a period.
Do not use ellipses.
Do not repeat any sentence or key phrase across sections.
MANTRA must not restate or summarize BHRIGU TODAY; it must be a separate command.
If you cannot use a real transit or aspect, say the lunar context plainly instead of inventing a placement.

[BHRIGU TODAY] (2 sentences max. Brutally honest psychological insight. Complete your sentences with a firm stop.)
[YOUR TRANSIT] (1 sentence detailing planetary mechanics, 1 sentence on how it feels.)
[DO] (One complete paragraph, 1-2 sentences. Make it actionable and specific. No bullet points.)
[AVOID] (One complete paragraph, 1-2 sentences. Make it psychologically sharp. No bullet points.)
[RELATIONSHIPS] (2 sentences on romantic or platonic dynamics.)
[WORK / MONEY] (1-2 sentences on material wealth or discipline.)
[INNER WEATHER] (1 sentence describing the internal emotional climate.)
[MANTRA] (1 short, powerful, imperative sentence. Complete your sentence with a firm stop.)
`;
    } catch (transitError) {
      console.error("Daily transit cache error:", transitError);
    }

    try {
      const text = await generateGeminiReadingText({
        prompt,
        maxTokens: 520,
        temperature: 0.7,
      });
      const horoscopeMeta = request.data.horoscopeMeta || {};
      const parsed = parseDailyHoroscopeText(text, {
        moonPhaseLine: request.data.moonPhaseLine,
        dailyEnergyLine: request.data.dailyEnergyLine,
      });
      const storedHoroscope = {
        dateKey,
        contentVersion,
        ...parsed,
        moonPhase: horoscopeMeta.moonPhase || null,
        moonAge:
          typeof horoscopeMeta.moonAge === "number"
            ? horoscopeMeta.moonAge
            : null,
        moonIllumination:
          typeof horoscopeMeta.moonIllumination === "number"
            ? horoscopeMeta.moonIllumination
            : null,
        dailyPlanet: horoscopeMeta.dailyPlanet || null,
        dailyTransits,
        transitAspects,
        rawText: text,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await horoscopeRef.set(storedHoroscope, { merge: true });

      return {
        ...dailyHoroscopePayload({
          ...storedHoroscope,
          generatedAt: undefined,
        }),
        cached: false,
      };
    } catch (error) {
      console.error("Daily horoscope Gemini error:", error.response?.data || error.message);

      throw new HttpsError(
        "internal",
        "Daily horoscope generation failed."
      );
    }
  }
);
exports.generateTarotEmbedding = onCall(
  {
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  },
  async (request) => {
    const idToken = request.data.idToken;

    if (!idToken || typeof idToken !== "string") {
      throw new HttpsError("unauthenticated", "Missing Firebase ID token.");
    }

    try {
      await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error("Tarot embedding token verification failed:", error);
      throw new HttpsError("unauthenticated", "Invalid Firebase ID token.");
    }

    const text = request.data.text;

    if (!text || typeof text !== "string") {
      throw new HttpsError("invalid-argument", "Text is required.");
    }

    if (text.length > 4000) {
      throw new HttpsError("invalid-argument", "Text is too long.");
    }

    try {
      const response = await axios.post(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY.value()}`,
        {
          model: "models/gemini-embedding-001",
          content: {
            parts: [
              {
                text: text,
              },
            ],
          },
        }
      );

      const values = response.data.embedding.values || [];

      return {
        values: values,
      };
    } catch (error) {
      console.error(
        "Tarot Gemini embedding error:",
        error.response?.data || error.message
      );

      throw new HttpsError(
        "internal",
        "Tarot embedding generation failed."
      );
    }
  }
);

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

async function generateTarotQueryEmbedding(text) {
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

async function retrieveTarotKnowledge({
  cardName,
  keywords,
  fallback,
}) {
  const cleanCardName = String(cardName || "").trim();
  const cleanFallback = String(fallback || "").trim();
  const query = `${cleanCardName}: ${String(keywords || "").trim()}`;

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
    const snap = await admin.firestore().collection("tarot_knowledge").get();

    let exactText = "";
    let bestText = cleanFallback;
    let bestScore = -1;

    snap.forEach((doc) => {
      const data = doc.data() || {};
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

exports.generateTarotReading = onCall(
  {
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 120,
    memory: "1GiB",
  },
  async (request) => {
    const idToken = request.data.idToken;

    if (!idToken || typeof idToken !== "string") {
      throw new HttpsError("unauthenticated", "Missing Firebase ID token.");
    }

    let decodedToken;

    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error("Tarot reading token verification failed:", error);
      throw new HttpsError("unauthenticated", "Invalid Firebase ID token.");
    }

    const birthData = request.data.birthData || "Birth data not available.";
    const question = request.data.question || "";
    const pastName = request.data.pastName || "";
    const presentName = request.data.presentName || "";
    const futureName = request.data.futureName || "";
    const pastKnowledgeFallback = request.data.pastKnowledge || "";
    const presentKnowledgeFallback = request.data.presentKnowledge || "";
    const futureKnowledgeFallback = request.data.futureKnowledge || "";
    const pastKeywords = request.data.pastKeywords || "";
    const presentKeywords = request.data.presentKeywords || "";
    const futureKeywords = request.data.futureKeywords || "";
    const cacheKey = cacheKeyForReading("tarot", {
      version: TAROT_READING_CONTENT_VERSION,
      model: GEMINI_FLASH_LITE_MODEL,
      maxTokens: TAROT_MAX_OUTPUT_TOKENS,
      temperature: MYSTIC_READING_TEMPERATURE,
      birthData,
      question,
      pastName,
      presentName,
      futureName,
      pastKeywords,
      presentKeywords,
      futureKeywords,
    });

    const cachedText = await readCachedReading(
      decodedToken.uid,
      cacheKey,
      TAROT_READING_CONTENT_VERSION
    );

    if (cachedText) {
      return {
        text: cachedText,
        cached: true,
        deduped: true,
      };
    }

    const [pastKnowledge, presentKnowledge, futureKnowledge] =
      await Promise.all([
        retrieveTarotKnowledge({
          cardName: pastName,
          keywords: pastKeywords,
          fallback: pastKnowledgeFallback,
        }),
        retrieveTarotKnowledge({
          cardName: presentName,
          keywords: presentKeywords,
          fallback: presentKnowledgeFallback,
        }),
        retrieveTarotKnowledge({
          cardName: futureName,
          keywords: futureKeywords,
          fallback: futureKnowledgeFallback,
        }),
      ]);

    const prompt = `
You are Bhrigu — a Vedic sage and experienced tarot reader.

READING STYLE:
- Speak directly and warmly to the seeker by name
- Read each card separately with a clear label: PAST, PRESENT, FUTURE
- For each card give 2-3 sentences — one positive prospect and one honest challenge or caution
- Build a connecting narrative that flows from past to present to future based on user question.
- Weave in the seeker's birth chart naturally where relevant
- Be specific and personal — never generic
- End with one powerful closing statement — no question
- Plain text only, absolutely no asterisks, no markdown, no bullet points

RESPONSE FORMAT — follow this exactly:
PAST — [card name]
[2-3 sentences about the past card — positive and honest challenge balanced]

PRESENT — [card name]
[2-3 sentences about the present card — positive and honest challenge balanced]

FUTURE — [card name]
[2-3 sentences about the future card — positive and honest challenge balanced]

[One closing sentence tying all three together and speaking to the seeker's question]

SEEKER: ${birthData}
QUESTION: ${question}

PAST CARD — ${pastName}: ${pastKnowledge}
PRESENT CARD — ${presentName}: ${presentKnowledge}
FUTURE CARD — ${futureName}: ${futureKnowledge}
`;

    function cleanText(value) {
      return String(value || "")
        .replace(/\*\*/g, "")
        .replace(/\*/g, "")
        .replace(/__/g, "")
        .replace(/#{1,6}\s?/g, "")
        .replace(/^\s*[-•]\s+/gm, "")
        .replace(/\bConclusion\s*:/gi, "")
        .replace(/\bFinal Message\s*:/gi, "")
        .replace(/\bOverall Reading\s*:/gi, "")
        .replace(/\bClosing Insight\s*:/gi, "")
        .replace(/\s+/g, " ")
        .trim();
    }

    function removeEndingQuestion(text) {
      let cleaned = cleanText(text);
      const sentences = cleaned.match(/[^.!?]+[.!?]+/g);

      if (!sentences || sentences.length === 0) {
        return cleaned.endsWith("?") ? cleaned.slice(0, -1).trim() + "." : cleaned;
      }

      while (sentences.length > 0 && sentences[sentences.length - 1].trim().endsWith("?")) {
        sentences.pop();
      }

      return sentences.join(" ").trim() || cleaned.replace(/\?+$/g, ".").trim();
    }

    function buildFallbackText() {
      return `PAST — ${pastName}
${cleanText(pastKnowledge)}

PRESENT — ${presentName}
${cleanText(presentKnowledge)}

FUTURE — ${futureName}
${cleanText(futureKnowledge)}

These three cards show a movement from what shaped you, to what is testing you now, to what is slowly forming ahead.`;
    }

    function buildFinalText(parsed) {
      const past = removeEndingQuestion(parsed.past);
      const present = removeEndingQuestion(parsed.present);
      const future = removeEndingQuestion(parsed.future);
      const closing = removeEndingQuestion(parsed.closing);

      return `PAST — ${pastName}
${past}

PRESENT — ${presentName}
${present}

FUTURE — ${futureName}
${future}

${closing}`.trim();
    }

    try {
      const rawText = await generateGeminiReadingText({
        systemInstruction:
          "You are generating tarot reading content for an app. Return only valid JSON. Do not include markdown. Do not include headings. Do not include labels. Do not include conclusion headings. Do not ask a question at the end.",
        prompt: `${prompt}

Return only valid JSON in this exact structure:
{
  "past": "2 to 3 sentences for the past card. Include one positive prospect and one honest challenge.",
  "present": "2 to 3 sentences for the present card. Include one positive prospect and one honest challenge.",
  "future": "2 to 3 sentences for the future card. Include one positive prospect and one honest challenge.",
  "closing": "One powerful closing sentence tying all three cards to the user's question. No question."
}

Do not write PAST, PRESENT, FUTURE, Conclusion, Final Message, Overall Reading, or Closing Insight inside the JSON values. Only write the actual reading content.`,
        maxTokens: TAROT_MAX_OUTPUT_TOKENS,
        temperature: MYSTIC_READING_TEMPERATURE,
      });

      let parsed;

      try {
        const jsonStart = rawText.indexOf("{");
        const jsonEnd = rawText.lastIndexOf("}");

        if (jsonStart === -1 || jsonEnd === -1) {
          throw new Error("No JSON object found");
        }

        const jsonText = rawText.substring(jsonStart, jsonEnd + 1);
        parsed = JSON.parse(jsonText);
      } catch (parseError) {
        console.error("Tarot JSON parse error:", parseError);

        return {
          text: buildFallbackText(),
        };
      }

      const finalText = buildFinalText(parsed);
      await writeCachedReading(
        decodedToken.uid,
        cacheKey,
        TAROT_READING_CONTENT_VERSION,
        finalText
      );

      return {
        text: finalText,
        cached: false,
      };
    } catch (error) {
      console.error(
        "Tarot Gemini error:",
        error.response?.data || error.message
      );

      return {
        text: buildFallbackText(),
        fallback: true,
        timeout: isTimeoutError(error),
      };
    }
  }
);
exports.generateGeomancyReading = onCall(
  {
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (request) => {
    const idToken = request.data.idToken;

    if (!idToken || typeof idToken !== "string") {
      throw new HttpsError("unauthenticated", "Missing Firebase ID token.");
    }

    let decodedToken;

    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error("Geomancy token verification failed:", error);
      throw new HttpsError("unauthenticated", "Invalid Firebase ID token.");
    }

    const question = request.data.question || "";
    const birthData = request.data.birthData || "Birth data not available.";
    const answer = request.data.answer || "Mixed result";
    const chart = request.data.chart || {};

    const judge = chart.judge || {};
    const leftWitness = chart.leftWitness || {};
    const rightWitness = chart.rightWitness || {};
    const reconciler = chart.reconciler || {};
    const cacheKey = cacheKeyForReading("geomancy", {
      version: GEOMANCY_READING_CONTENT_VERSION,
      model: GEMINI_FLASH_LITE_MODEL,
      maxTokens: GEOMANCY_MAX_OUTPUT_TOKENS,
      temperature: MYSTIC_READING_TEMPERATURE,
      question,
      birthData,
      answer,
      chart,
    });

    const cachedText = await readCachedReading(
      decodedToken.uid,
      cacheKey,
      GEOMANCY_READING_CONTENT_VERSION
    );

    if (cachedText) {
      return {
        text: cachedText,
        cached: true,
        deduped: true,
      };
    }

    const geminiPrompt = `
Give one short symbolic context paragraph for this geomancy chart.

Judge: ${judge.name || ""}
Left Witness: ${leftWitness.name || ""}
Right Witness: ${rightWitness.name || ""}
Reconciler: ${reconciler.name || ""}

Keep it under 60 words. No markdown.
`;

    let geminiContext =
      "The figure pattern suggests a movement from visible circumstances toward a deeper hidden lesson.";

    try {
      const geminiResponse = await axios.post(
        `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_FLASH_LITE_MODEL}:generateContent?key=${GEMINI_API_KEY.value()}`,
        {
          contents: [
            {
              parts: [
                {
                  text: geminiPrompt,
                },
              ],
            },
          ],
        }
      );

      const candidates = geminiResponse.data.candidates || [];
      const content = candidates[0]?.content || {};
      const parts = content.parts || [];

      if (parts[0]?.text) {
        geminiContext = parts[0].text;
      }
    } catch (error) {
      console.error(
        "Geomancy Gemini error:",
        error.response?.data || error.message
      );
    }

    const q =
      question.trim().length === 0
        ? "The user did not type a question. Give a general reading from the pattern."
        : question.trim();

    const prompt = `
You are Bhrigu Geomancer inside the BHR1GU astrology app.
You are interpreting a geomancy shield chart created by the user's sixteen hand-drawn ritual marks.

Speak like Bhrigu: wise, direct, mystical but grounded in earth magic. 
Do not sound like a generic horoscope. Keep it premium, emotionally engaging, and specific to the geomantic figures.

User birth data:
${birthData}

User question:
${q}

Geomancy result:
Judge: ${judge.name || ""} - ${judge.latinName || ""}
Judge answer: ${answer}
Judge meaning: ${judge.meaning || ""}
Left Witness: ${leftWitness.name || ""} (meaning: ${leftWitness.meaning || ""})
Right Witness: ${rightWitness.name || ""} (meaning: ${rightWitness.meaning || ""})
Reconciler: ${reconciler.name || ""} (meaning: ${reconciler.meaning || ""})

Gemini contextual note:
${geminiContext}

STRICT RESPONSE STRUCTURE:
You MUST format your response exactly like this. Plain text only. No markdown (no ** or *). Separate each section with a double line break. 

THE JUDGEMENT
[1 to 2 sentences directly answering the user's question using the Judge figure. Be definitive.]

THE WITNESSES
[2 sentences explaining the underlying forces at play using the Left and Right Witnesses. What is pushing them forward, and what is holding them back?]

THE RECONCILER
[1 to 2 sentences explaining the hidden lesson or ultimate outcome using the Reconciler figure.]

EARTH'S COUNSEL
[1 short, powerful, imperative sentence giving them a strict action or mantra to follow.]

RULES:
- Do not add any conversational filler (e.g., "Here is your reading").
- Never ask a question at the end.
- Use the exact all-caps headings shown above.

`;

    try {
      const text = await generateGeminiReadingText({
        prompt,
        maxTokens: GEOMANCY_MAX_OUTPUT_TOKENS,
        temperature: MYSTIC_READING_TEMPERATURE,
      });
      await writeCachedReading(
        decodedToken.uid,
        cacheKey,
        GEOMANCY_READING_CONTENT_VERSION,
        text
      );

      return {
        text: text,
        cached: false,
      };
    } catch (error) {
      console.error(
        "Geomancy Gemini error:",
        error.response?.data || error.message
      );

      if (isTimeoutError(error)) {
        throw new HttpsError(
          "deadline-exceeded",
          "Geomancy reading timed out. Please try again."
        );
      }

      throw new HttpsError(
        "internal",
        "Geomancy reading generation failed."
      );
    }
  }
);

exports.generateCompatibilityEmbedding = onCall(
  {
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  },
  async (request) => {
    const idToken = request.data.idToken;

    if (!idToken || typeof idToken !== "string") {
      throw new HttpsError("unauthenticated", "Missing Firebase ID token.");
    }

    try {
      await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error("Compatibility embedding token verification failed:", error);
      throw new HttpsError("unauthenticated", "Invalid Firebase ID token.");
    }

    const text = request.data.text;

    if (!text || typeof text !== "string") {
      throw new HttpsError("invalid-argument", "Text is required.");
    }

    if (text.length > 4000) {
      throw new HttpsError("invalid-argument", "Text is too long.");
    }

    try {
      const response = await axios.post(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY.value()}`,
        {
          model: "models/gemini-embedding-001",
          content: {
            parts: [
              {
                text: text,
              },
            ],
          },
        }
      );

      const values = response.data.embedding.values || [];

      return {
        values: values,
      };
    } catch (error) {
      console.error(
        "Compatibility Gemini embedding error:",
        error.response?.data || error.message
      );

      throw new HttpsError(
        "internal",
        "Compatibility embedding generation failed."
      );
    }
  }
);

exports.generatePartnerMatchReading = onCall(
  {
    secrets: [GROQ_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 180,
    memory: "512MiB",
  },
  async (request) => {
    const idToken = request.data.idToken;

    if (!idToken || typeof idToken !== "string") {
      throw new HttpsError("unauthenticated", "Missing Firebase ID token.");
    }

    let decodedToken;

    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error("Partner match token verification failed:", error);
      throw new HttpsError("unauthenticated", "Invalid Firebase ID token.");
    }

    const user = request.data.user || {};
    const partner = request.data.partner || {};
    const scores = request.data.scores || {};
    const userSun = request.data.userSun || "";
    const partnerSun = request.data.partnerSun || "";
    const userMoon = request.data.userMoon || "";
    const partnerMoon = request.data.partnerMoon || "";
    const connectionType = request.data.connectionType || "";
    const verdict = request.data.verdict || "";
    const retrievedKnowledge =
      request.data.retrievedKnowledge || "No specific compatibility knowledge retrieved.";
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(decodedToken.uid)
      .get();
    const userData = userDoc.data() || {};
    const userNatalChart = {
      westernChart: userData.westernChart || null,
      vedicChart: userData.vedicChart || null,
      chartGeneratedBy: userData.chartGeneratedBy || "Unknown",
      chartCalculationVersion: userData.chartCalculationVersion || "Unknown",
    };
    let partnerNatalChart = null;

    try {
      if (partner.dob) {
        partnerNatalChart = await calculateNatalChartForBirthData({
          birthDate: partner.dob,
          timeOfBirth: String(partner.timeOfBirth || ""),
          placeOfBirth: String(partner.placeOfBirth || ""),
          latitude: typeof partner.latitude === "number" ? partner.latitude : null,
          longitude: typeof partner.longitude === "number" ? partner.longitude : null,
        });
      }
    } catch (chartError) {
      console.error("Partner chart calculation failed:", chartError);
    }

    const prompt = `
Write as Bhrigu, an ancient calm sage speaking with quiet certainty. The tone should feel wise, spiritual, poetic, and human, not like a report. Use simple but sacred language. Avoid robotic phrases like "pattern suggests", "compatibility judgement", "emotional rhythm", or "future potential" unless they sound natural. Speak as if reading two souls, not explaining data..

You are reading a partner compatibility match between two birth profiles.

IMPORTANT:
The app has already calculated the compatibility scores.
Do not change the scores.
Do not invent any percentage.
Do not write any percentage numbers in your response.
The exact percentage numbers are already shown separately on the app screen.
Your job is to interpret the meaning of the calculated pattern.
Use the structured natal chart placements below as supporting astrology logic.
Do not call them generic signs; these are saved user chart data and a freshly calculated partner chart using the same NASA/JPL helper.
Do not mention NASA/JPL, backend, helper, JSON, or database to the user.


User:
Name: ${user.name}
DOB: ${user.dob}
Time: ${user.timeOfBirth}
Place: ${user.placeOfBirth}
Sun Sign: ${userSun}
Moon Style: ${userMoon}

Partner:
Name: ${partner.name}
DOB: ${partner.dob}
Time: ${partner.timeOfBirth}
Place: ${partner.placeOfBirth}
Sun Sign: ${partnerSun}
Moon Style: ${partnerMoon}

User saved natal chart:
${JSON.stringify(userNatalChart)}

Partner calculated natal chart:
${JSON.stringify(partnerNatalChart)}

User's exact typed feeling about partner:
"${partner.emotionalPrompt}"

Calculated scores for your understanding only:
Overall Compatibility: ${scores.overall}
Emotional Harmony: ${scores.emotional}
Attraction Pull: ${scores.attraction}
Communication: ${scores.communication}
Long-Term Stability: ${scores.stability}
Karmic Bond: ${scores.karmic}

Connection Type:
${connectionType}

Verdict Label:
${verdict}

Retrieved Compatibility Knowledge:
${retrievedKnowledge}

Response format exactly:

Verdict:
Write 2 sentences giving the direct compatibility judgement using the verdict label and connection type. Do not mention any percentage.

Heart Signal:
First quote the user's exact typed feeling in quotation marks. Then explain what those exact words reveal emotionally. Do not say only "what you wrote"; interpret the actual words.

Emotional Bond:
Write 2 sentences explaining the emotional rhythm using the emotional harmony pattern and Moon styles. Do not mention any percentage.

Attraction:
Write 2 sentences explaining attraction and chemistry using the attraction pattern and the user's typed feeling if it mentions attraction, spark, beauty, confidence, voice, smile, or chemistry. Do not mention any percentage.

Long-Term Potential:
Write 2 sentences explaining communication, stability, and future potential. Do not mention any percentage.

Bhrigu Warning:
Write 1 honest warning or caution. Do not end with a question.

Rules:
Do not write any percentage numbers.
Do not mention database, RAG, retrieved knowledge, or AI.
Do not use markdown symbols.
Do not use bullet points.
Do not use asterisks.
Do not ask the user anything at the end.
Do not end with a question.
Do not be overly positive.
Keep the tone mystical, direct, and emotionally intelligent.
`;

    try {
      const text = await generateGroqReadingText({
        messages: [
          {
            role: "system",
            content:
              "Follow the compatibility reading format exactly. Do not use markdown. Do not use bullet points. Do not ask a question at the end. Do not write percentage numbers.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        model: GROQ_PARTNER_MATCH_MODEL,
        maxTokens: 620,
        temperature: 0.35,
      });

      return {
        text: text.trim(),
      };
    } catch (error) {
      console.error(
        "Partner match Groq error:",
        error.response?.data || error.message
      );

      throw new HttpsError(
        "internal",
        "Partner match reading generation failed."
      );
    }
  }
);
exports.generateCompatibilityInsight = onCall(
  {
    secrets: [GROQ_API_KEY, GEMINI_API_KEY],
    region: FUNCTION_REGION,
  },
  async (request) => {
    const idToken = request.data.idToken;

    if (!idToken || typeof idToken !== "string") {
      throw new HttpsError("unauthenticated", "Missing Firebase ID token.");
    }

    try {
      await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error("Chart AI token verification failed:", error);
      throw new HttpsError("unauthenticated", "Invalid Firebase ID token.");
    }

    const westernChart = request.data.westernChart;
    const vedicChart = request.data.vedicChart;

    const prompt = `
You are BHR1GU, a premium Vedic and Western astrology guide.

Create a short romantic compatibility insight from this user's chart.

Western chart:
${JSON.stringify(westernChart)}

Vedic chart:
${JSON.stringify(vedicChart)}

Rules:
- 45 to 70 words
- Sound mystical but grounded
- Mention attraction, emotional bonding, and long-term relationship pattern
- Include one honest caution
- No markdown
- Do not claim certainty
`;

    try {
      const text = await generateUserReadingText({
        requestData: request.data,
        prompt,
        temperature: 0.75,
        maxTokens: 160,
      });

      return {
        text: text.trim(),
      };
    } catch (error) {
      console.error(
        "Chart AI Groq error:",
        error.response?.data || error.message
      );

      throw new HttpsError(
        "internal",
        "Compatibility insight generation failed."
      );
    }
  }
);
exports.searchBirthPlaces = onCall(
  {
    region: FUNCTION_REGION,
    secrets: [GOOGLE_PLACES_API_KEY],
  },
  async (request) => {
    try {
      const data = request.data || {};
      const idToken = data.idToken;
      const query = String(data.query || "").trim();

      if (!idToken) {
        throw new HttpsError("unauthenticated", "Missing Firebase ID token.");
      }

      await admin.auth().verifyIdToken(idToken);

      if (query.length < 2) {
        return {
          places: [],
          placeDetails: [],
        };
      }

      if (query.length > 120) {
        throw new HttpsError("invalid-argument", "Search query is too long.");
      }

      const response = await fetch(
        "https://places.googleapis.com/v1/places:autocomplete",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY.value(),
            "X-Goog-FieldMask":
              "suggestions.placePrediction.placeId,suggestions.placePrediction.text.text,suggestions.placePrediction.structuredFormat.mainText.text,suggestions.placePrediction.structuredFormat.secondaryText.text",
          },
          body: JSON.stringify({
            input: query,
            includeQueryPredictions: false,
            languageCode: "en",
          }),
          signal: AbortSignal.timeout(PLACES_REQUEST_TIMEOUT_MS),
        }
      );

      const responseText = await response.text();

      if (!response.ok) {
        console.error(
          "Google Places error:",
          response.status,
          responseText
        );

        throw new HttpsError(
          "internal",
          `Google Places failed with status ${response.status}.`
        );
      }

      const json = JSON.parse(responseText);

      const suggestions = Array.isArray(json.suggestions)
        ? json.suggestions
        : [];

      const placePredictions = suggestions
        .map((suggestion) => {
          const prediction = suggestion.placePrediction || {};
          const structuredFormat = prediction.structuredFormat || {};
          const placeId = prediction.placeId || "";
          const mainText = structuredFormat.mainText?.text || "";
          const secondaryText = structuredFormat.secondaryText?.text || "";
          const fallbackText = prediction.text?.text || "";

          let description = "";

          if (mainText && secondaryText) {
            description = `${mainText}, ${secondaryText}`;
          } else if (fallbackText) {
            description = fallbackText;
          } else if (mainText) {
            description = mainText;
          }

          return {
            placeId,
            description,
          };
        })
        .filter((place) => place.description.trim().length > 0)
        .filter(
          (place, index, array) =>
            array.findIndex(
              (item) => item.description === place.description
            ) === index
        )
        .slice(0, 8);

      const placeDetails = await Promise.all(
        placePredictions.map(async (place) => {
          if (!place.placeId) {
            return {
              description: place.description,
              latitude: null,
              longitude: null,
            };
          }

          try {
            const detailResponse = await fetch(
              `https://places.googleapis.com/v1/places/${place.placeId}`,
              {
                method: "GET",
                headers: {
                  "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY.value(),
                  "X-Goog-FieldMask": "location",
                },
                signal: AbortSignal.timeout(PLACES_REQUEST_TIMEOUT_MS),
              }
            );

            if (!detailResponse.ok) {
              return {
                description: place.description,
                latitude: null,
                longitude: null,
              };
            }

            const detailJson = await detailResponse.json();
            const location = detailJson.location || {};

            return {
              description: place.description,
              latitude:
                typeof location.latitude === "number"
                  ? location.latitude
                  : null,
              longitude:
                typeof location.longitude === "number"
                  ? location.longitude
                  : null,
            };
          } catch (detailError) {
            console.error("Google Place detail error:", detailError);
            return {
              description: place.description,
              latitude: null,
              longitude: null,
            };
          }
        })
      );

      return {
        places: placeDetails.map((place) => place.description),
        placeDetails,
      };
    } catch (error) {
      console.error("searchBirthPlaces error:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "Could not search birth places right now."
      );
    }
  }
);
