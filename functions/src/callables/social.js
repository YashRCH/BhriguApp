const {
  onCall,
  HttpsError,
  admin,
  crypto,
  GEMINI_API_KEY,
  FUNCTION_REGION,
  GEMINI_FLASH_LITE_MODEL,
  callableRuntimeOptions,
  requireCallableAuth,
  requireRequestData,
  boundedString,
  boundedPlainObject,
  normalizeAiResponseLanguage,
  resolveAiResponseLanguage,
  languageInstruction,
  generateGeminiReadingText,
  recordUsageEvent,
} = require("../core");

const SOCIAL_COMPATIBILITY_CONTENT_VERSION = "connection_compatibility_v4";
const CONNECTION_DAILY_ENERGY_CONTENT_VERSION = "connection_daily_energy_v9_base_gemini";
const FRIEND_SCORE_ALGORITHM_VERSION = "friend_blueprint_math_v1";
const PARTNER_SCORE_ALGORITHM_VERSION = "partner_blueprint_math_v1";
const CIRCLE_SAFETY_POLICY_VERSION = "circle_safety_v1";
const VALID_RELATIONSHIP_TYPES = new Set(["friend", "partner"]);

// ─── Helpers ────────────────────────────────────────────────────────────────

function cleanUsername(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/^@+/, "");
}

function assertUsername(username) {
  if (!/^[a-z0-9_]{3,24}$/.test(username)) {
    throw new HttpsError(
      "invalid-argument",
      "Username must be 3-24 characters using letters, numbers, or underscores."
    );
  }
}

function assertOnboardingString(value, fieldName, minLength, maxLength) {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${fieldName} is invalid.`);
  }

  const text = value.trim();
  if (text.length < minLength || text.length > maxLength) {
    throw new HttpsError("invalid-argument", `${fieldName} is invalid.`);
  }

  return text;
}

function normalizeOptionalCoordinate(value, fieldName, min, max) {
  if (value === null || typeof value === "undefined") return null;

  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < min ||
    value > max
  ) {
    throw new HttpsError("invalid-argument", `${fieldName} is invalid.`);
  }

  return value;
}

function normalizeOnboardingUserData(value, username) {
  if (value === null || typeof value === "undefined") return null;

  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "Onboarding profile is invalid.");
  }

  return {
    name: assertOnboardingString(value.name, "Name", 1, 120),
    username,
    usernameLower: username,
    dob: assertOnboardingString(value.dob, "Birth date", 10, 40),
    timeOfBirth: assertOnboardingString(value.timeOfBirth, "Birth time", 0, 20),
    placeOfBirth: assertOnboardingString(value.placeOfBirth, "Birth place", 1, 200),
    latitude: normalizeOptionalCoordinate(value.latitude, "Latitude", -90, 90),
    longitude: normalizeOptionalCoordinate(value.longitude, "Longitude", -180, 180),
    aiResponseLanguage: normalizeAiResponseLanguage(value.aiResponseLanguage),
    onboardingComplete: false,
    createdAt: assertOnboardingString(value.createdAt, "Created at", 0, 40),
  };
}

async function clearUnreservedIncompleteUsername(firestore, uid) {
  const userRef = firestore.collection("users").doc(uid);
  const userDoc = await userRef.get();

  if (!userDoc.exists) return;

  const userData = userDoc.data() || {};
  if (userData.onboardingComplete === true) return;

  const currentUsername = cleanUsername(userData.usernameLower || userData.username);
  if (!currentUsername) return;

  const usernameDoc = await firestore.collection("usernames").doc(currentUsername).get();
  if (usernameDoc.exists && usernameDoc.data()?.uid === uid) return;

  await userRef.update({
    username: admin.firestore.FieldValue.delete(),
    usernameLower: admin.firestore.FieldValue.delete(),
  });
}

function cleanRelationshipType(value) {
  const type = String(value || "friend").trim().toLowerCase();
  if (type === "spouse") return "partner";
  return VALID_RELATIONSHIP_TYPES.has(type) ? type : "friend";
}

function connectionIdFor(uidA, uidB) {
  return [uidA, uidB].sort().join("_");
}

function dateKeyFromDate(date) {
  return date.toISOString().slice(0, 10);
}

function dateValueToIso(value, fallback = "2000-01-01T00:00:00.000Z") {
  if (!value) return fallback;

  if (typeof value.toDate === "function") {
    const date = value.toDate();
    return Number.isNaN(date.getTime()) ? fallback : date.toISOString();
  }

  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? fallback : value.toISOString();
  }

  if (typeof value === "object" && typeof value.seconds === "number") {
    return new Date(
      (value.seconds * 1000) + Math.trunc((value.nanoseconds || 0) / 1000000)
    ).toISOString();
  }

  const date = new Date(String(value));
  return Number.isNaN(date.getTime()) ? fallback : date.toISOString();
}

function timestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  if (typeof value.seconds === "number") {
    return (value.seconds * 1000) + Math.trunc((value.nanoseconds || 0) / 1000000);
  }
  return 0;
}

function memberPairFromConnection(data) {
  const memberIds = Array.isArray(data.memberIds)
    ? data.memberIds.filter((uid) => typeof uid === "string" && uid.trim())
    : [];

  if (memberIds.length !== 2) {
    throw new HttpsError("failed-precondition", "Connection member data is incomplete.");
  }

  return memberIds;
}

function sunSignFromDob(dob) {
  const date = new Date(dateValueToIso(dob, ""));
  if (Number.isNaN(date.getTime())) return "";

  const month = date.getUTCMonth() + 1;
  const day = date.getUTCDate();

  if ((month === 3 && day >= 21) || (month === 4 && day <= 19)) return "Aries";
  if ((month === 4 && day >= 20) || (month === 5 && day <= 20)) return "Taurus";
  if ((month === 5 && day >= 21) || (month === 6 && day <= 20)) return "Gemini";
  if ((month === 6 && day >= 21) || (month === 7 && day <= 22)) return "Cancer";
  if ((month === 7 && day >= 23) || (month === 8 && day <= 22)) return "Leo";
  if ((month === 8 && day >= 23) || (month === 9 && day <= 22)) return "Virgo";
  if ((month === 9 && day >= 23) || (month === 10 && day <= 22)) return "Libra";
  if ((month === 10 && day >= 23) || (month === 11 && day <= 21)) return "Scorpio";
  if ((month === 11 && day >= 22) || (month === 12 && day <= 21)) return "Sagittarius";
  if ((month === 12 && day >= 22) || (month === 1 && day <= 19)) return "Capricorn";
  if ((month === 1 && day >= 20) || (month === 2 && day <= 18)) return "Aquarius";
  return "Pisces";
}

function signFromChart(chart, fallbackDob) {
  const placements = chart && typeof chart === "object" ? chart.placements : null;
  if (Array.isArray(placements)) {
    const sun = placements.find((item) => String(item.name || "").toLowerCase() === "sun");
    if (sun && sun.sign) return String(sun.sign);
  }

  if (chart && typeof chart === "object" && chart.sunSign) {
    return String(chart.sunSign);
  }

  return sunSignFromDob(fallbackDob);
}

function moonFromChart(chart) {
  const placements = chart && typeof chart === "object" ? chart.placements : null;
  if (Array.isArray(placements)) {
    const moon = placements.find((item) => String(item.name || "").toLowerCase() === "moon");
    if (moon && moon.sign) return String(moon.sign);
  }

  if (chart && typeof chart === "object" && chart.moonSign) {
    return String(chart.moonSign);
  }

  return "";
}

function risingFromChart(chart) {
  if (chart && typeof chart === "object" && chart.ascendantSign) {
    return String(chart.ascendantSign);
  }

  if (chart && typeof chart === "object" && chart.risingSign) {
    return String(chart.risingSign);
  }

  return "";
}

function publicProfileFromUser(uid, userData, username) {
  const westernChart = userData.westernChart || {};

  return {
    uid,
    username,
    usernameLower: cleanUsername(username),
    displayName: String(userData.name || "BHR1GU user").slice(0, 80),
    photoUrl: String(userData.photoUrl || ""),
    sunSign: signFromChart(westernChart, userData.dob),
    moonSign: moonFromChart(westernChart),
    risingSign: risingFromChart(westernChart),
    allowSearch: userData.allowSearch !== false,
  };
}

function clampNumber(value, min, max) {
  return Math.min(max, Math.max(min, Number(value) || 0));
}

function normalizedModulo(value, base) {
  return ((value % base) + base) % base;
}

function normalizeDegrees(value) {
  return normalizedModulo(value, 360);
}

function sinDeg(degrees) {
  return Math.sin((degrees * Math.PI) / 180);
}

function doubleOrNull(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function parseBirthMinutes(time) {
  const normalized = String(time || "").trim().toUpperCase();
  const match = normalized.match(/(\d{1,2})[:.](\d{2})/);
  if (!match) return 720;

  let hour = Number.parseInt(match[1], 10) || 12;
  const minute = Number.parseInt(match[2], 10) || 0;
  const isPm = normalized.includes("PM");
  const isAm = normalized.includes("AM");

  if (isPm && hour < 12) hour += 12;
  if (isAm && hour === 12) hour = 0;

  return ((clampNumber(hour, 0, 23) * 60) + clampNumber(minute, 0, 59)) % 1440;
}

function knownCoordinates(place) {
  const normalized = String(place || "").toLowerCase();
  const known = {
    "new delhi": { latitude: 28.6139, longitude: 77.2090 },
    delhi: { latitude: 28.6139, longitude: 77.2090 },
    mumbai: { latitude: 19.0760, longitude: 72.8777 },
    bengaluru: { latitude: 12.9716, longitude: 77.5946 },
    bangalore: { latitude: 12.9716, longitude: 77.5946 },
    kolkata: { latitude: 22.5726, longitude: 88.3639 },
    chennai: { latitude: 13.0827, longitude: 80.2707 },
    hyderabad: { latitude: 17.3850, longitude: 78.4867 },
    pune: { latitude: 18.5204, longitude: 73.8567 },
    ahmedabad: { latitude: 23.0225, longitude: 72.5714 },
    jaipur: { latitude: 26.9124, longitude: 75.7873 },
    lucknow: { latitude: 26.8467, longitude: 80.9462 },
    varanasi: { latitude: 25.3176, longitude: 82.9739 },
    london: { latitude: 51.5074, longitude: -0.1278 },
    "new york": { latitude: 40.7128, longitude: -74.0060 },
    "los angeles": { latitude: 34.0522, longitude: -118.2437 },
    chicago: { latitude: 41.8781, longitude: -87.6298 },
    toronto: { latitude: 43.6532, longitude: -79.3832 },
    sydney: { latitude: -33.8688, longitude: 151.2093 },
    melbourne: { latitude: -37.8136, longitude: 144.9631 },
    singapore: { latitude: 1.3521, longitude: 103.8198 },
    dubai: { latitude: 25.2048, longitude: 55.2708 },
  };

  const match = Object.entries(known).find(([key]) => normalized.includes(key));
  return match ? match[1] : null;
}

function coordinatesFor(profile) {
  const latitude = doubleOrNull(profile.latitude);
  const longitude = doubleOrNull(profile.longitude);
  if (latitude !== null && longitude !== null) return { latitude, longitude };
  return knownCoordinates(profile.placeOfBirth);
}

function estimatedUtcBirth(profile) {
  const dob = new Date(profile.dob || "");
  const safeDob = Number.isNaN(dob.getTime()) ? new Date(Date.UTC(2000, 0, 1)) : dob;
  const place = coordinatesFor(profile);
  const birthMinutes = parseBirthMinutes(profile.timeOfBirth);
  const longitudeOffsetMinutes = Math.round((place?.longitude || 0) * 4);
  const localDate = Date.UTC(
    safeDob.getUTCFullYear(),
    safeDob.getUTCMonth(),
    safeDob.getUTCDate()
  );
  return new Date(localDate + ((birthMinutes - longitudeOffsetMinutes) * 60000));
}

function daysSinceJ2000(utcBirth) {
  return (utcBirth.getTime() - Date.UTC(2000, 0, 1, 12)) / 86400000;
}

function lahiriAyanamsa(days) {
  return 23.8531 + ((days / 36525) * 1.396);
}

function siderealSunLongitude(days, ayanamsa) {
  const meanLongitude = normalizeDegrees(280.46646 + (0.98564736 * days));
  const meanAnomaly = normalizeDegrees(357.52911 + (0.98560028 * days));
  const center =
    (1.914602 * sinDeg(meanAnomaly)) +
    (0.019993 * sinDeg(2 * meanAnomaly)) +
    (0.000289 * sinDeg(3 * meanAnomaly));
  return normalizeDegrees(meanLongitude + center - ayanamsa);
}

function siderealMoonLongitude(days, ayanamsa) {
  const meanLongitude = normalizeDegrees(218.3164477 + (13.17639648 * days));
  const meanAnomaly = normalizeDegrees(134.9633964 + (13.06499295 * days));
  const elongation = normalizeDegrees(297.8501921 + (12.19074912 * days));
  const sunAnomaly = normalizeDegrees(357.5291092 + (0.98560028 * days));
  const longitude =
    meanLongitude +
    (6.289 * sinDeg(meanAnomaly)) +
    (1.274 * sinDeg((2 * elongation) - meanAnomaly)) +
    (0.658 * sinDeg(2 * elongation)) +
    (0.214 * sinDeg(2 * meanAnomaly)) -
    (0.186 * sinDeg(sunAnomaly));
  return normalizeDegrees(longitude - ayanamsa);
}

function signIndexFromLongitude(longitude) {
  return Math.trunc(clampNumber(Math.floor(normalizeDegrees(longitude) / 30), 0, 11));
}

function meanPlanetSign(epochLongitude, dailyMotion, days, ayanamsa) {
  return signIndexFromLongitude(normalizeDegrees(epochLongitude + (dailyMotion * days) - ayanamsa));
}

function localSolarMinutes(time, longitude) {
  const clockMinutes = parseBirthMinutes(time);
  const longitudeOffset = longitude == null ? 0 : Math.round(longitude * 4);
  return normalizedModulo(clockMinutes + longitudeOffset, 1440);
}

function ascendantSign(siderealSun, localMinutes, latitude) {
  const sunriseRelativeMinutes = normalizedModulo(localMinutes - 360, 1440);
  const signShift = Math.floor(sunriseRelativeMinutes / 120);
  const latitudeShift = latitude == null ? 0 : Math.floor(Math.abs(latitude) / 55);
  return normalizedModulo(signIndexFromLongitude(siderealSun) + signShift + latitudeShift, 12);
}

function vedicSignature(profile) {
  const utcBirth = estimatedUtcBirth(profile);
  const days = daysSinceJ2000(utcBirth);
  const ayanamsa = lahiriAyanamsa(days);
  const siderealSun = siderealSunLongitude(days, ayanamsa);
  const siderealMoon = siderealMoonLongitude(days, ayanamsa);
  const place = coordinatesFor(profile);
  const localMinutes = localSolarMinutes(profile.timeOfBirth, place?.longitude);

  return {
    siderealSunSign: signIndexFromLongitude(siderealSun),
    moonSign: signIndexFromLongitude(siderealMoon),
    ascendantSign: ascendantSign(siderealSun, localMinutes, place?.latitude),
    mercurySign: meanPlanetSign(252.25084, 4.09233445, days, ayanamsa),
    venusSign: meanPlanetSign(181.97973, 1.60213034, days, ayanamsa),
    marsSign: meanPlanetSign(355.433, 0.5240207766, days, ayanamsa),
    saturnSign: meanPlanetSign(50.077, 0.03345965, days, ayanamsa),
    rahuSign: meanPlanetSign(125.04452, -0.05295377, days, ayanamsa),
    nakshatra: Math.trunc(clampNumber(Math.floor(siderealMoon / (360 / 27)), 0, 26)),
  };
}

function signDistance(a, b) {
  const diff = Math.abs(a - b);
  return Math.min(diff, 12 - diff);
}

function elementForSign(sign) {
  if ([0, 4, 8].includes(sign)) return "fire";
  if ([1, 5, 9].includes(sign)) return "earth";
  if ([2, 6, 10].includes(sign)) return "air";
  return "water";
}

function relationshipScore(a, b, mode) {
  const d = signDistance(a, b);
  const tables = {
    emotional: { 0: 13, 2: 14, 4: 18, 6: 10, 3: 5, 1: 3, 5: 2 },
    attraction: { 0: 12, 2: 12, 4: 15, 6: 17, 3: 16, 1: 7, 5: 5 },
    communication: { 0: 13, 2: 14, 4: 16, 6: 8, 3: 5, 1: 4, 5: 3 },
    stability: { 0: 12, 2: 12, 4: 16, 6: 9, 3: 7, 1: 4, 5: 3 },
    karmic: { 0: 14, 6: 17, 3: 16, 5: 12, 4: 8, 2: 7, 1: 6 },
  };
  return tables[mode]?.[d] || 5;
}

function elementScore(a, b, mode) {
  const first = elementForSign(a);
  const second = elementForSign(b);

  if (first === second) return mode === "attraction" ? 7 : 10;

  const supportive =
    (first === "fire" && second === "air") ||
    (first === "air" && second === "fire") ||
    (first === "earth" && second === "water") ||
    (first === "water" && second === "earth");
  if (supportive) return mode === "stability" ? 10 : 8;

  const friction =
    (first === "fire" && second === "water") ||
    (first === "water" && second === "fire") ||
    (first === "air" && second === "earth") ||
    (first === "earth" && second === "air");
  if (friction) return mode === "karmic" ? 10 : 3;

  return 5;
}

function promptAdjustments(prompt) {
  const text = String(prompt || "").toLowerCase();
  const hasAny = (words) => words.some((word) => text.includes(word));
  const scores = { emotional: 0, attraction: 0, communication: 0, stability: 0, karmic: 0 };

  if (hasAny(["calm", "caring", "kind", "safe", "understands", "listen", "gentle", "loyal", "comfort", "peace"])) {
    scores.emotional += 6;
    scores.stability += 2;
  }
  if (hasAny(["confidence", "ambition", "ambitious", "driven", "successful", "mature", "responsible", "disciplined", "consistent"])) {
    scores.stability += 5;
    scores.attraction += 2;
  }
  if (hasAny(["attraction", "attractive", "chemistry", "spark", "beautiful", "handsome", "hot", "magnetic", "smile", "eyes"])) {
    scores.attraction += 6;
    scores.karmic += 2;
  }
  if (hasAny(["talk", "conversation", "communicate", "funny", "intelligent", "mindset", "ideas", "voice", "laugh"])) {
    scores.communication += 5;
  }
  if (hasAny(["confusion", "confusing", "mixed signal", "distant", "unavailable", "ego", "toxic", "obsession", "anxious", "overthink"])) {
    scores.karmic += 7;
    scores.stability -= 5;
    scores.emotional -= 3;
  }
  if (hasAny(["dont like", "don't like", "do not like", "hate", "annoying", "irritating", "rude", "angry"])) {
    scores.communication -= 3;
    scores.emotional -= 3;
    scores.stability -= 2;
    scores.karmic += 4;
  }

  return {
    emotional: Math.trunc(clampNumber(scores.emotional, -6, 6)),
    attraction: Math.trunc(clampNumber(scores.attraction, -6, 6)),
    communication: Math.trunc(clampNumber(scores.communication, -6, 6)),
    stability: Math.trunc(clampNumber(scores.stability, -6, 6)),
    karmic: Math.trunc(clampNumber(scores.karmic, -6, 8)),
  };
}

function calculatePartnerBaseScores(user, partner) {
  const userSignature = vedicSignature(user);
  const partnerSignature = vedicSignature(partner);
  let emotional = 48;
  let attraction = 48;
  let communication = 48;
  let stability = 48;
  let karmic = 48;

  emotional += relationshipScore(userSignature.moonSign, partnerSignature.moonSign, "emotional");
  emotional += elementScore(userSignature.moonSign, partnerSignature.moonSign, "emotional");

  attraction += relationshipScore(userSignature.venusSign, partnerSignature.marsSign, "attraction");
  attraction += relationshipScore(partnerSignature.venusSign, userSignature.marsSign, "attraction");
  attraction += relationshipScore(userSignature.siderealSunSign, partnerSignature.siderealSunSign, "attraction");

  communication += relationshipScore(userSignature.mercurySign, partnerSignature.mercurySign, "communication");
  communication += elementScore(userSignature.mercurySign, partnerSignature.mercurySign, "communication");

  stability += relationshipScore(userSignature.saturnSign, partnerSignature.saturnSign, "stability");
  stability += relationshipScore(userSignature.ascendantSign, partnerSignature.ascendantSign, "stability");
  stability += elementScore(userSignature.siderealSunSign, partnerSignature.siderealSunSign, "stability");

  karmic += relationshipScore(userSignature.rahuSign, partnerSignature.siderealSunSign, "karmic");
  karmic += relationshipScore(partnerSignature.rahuSign, userSignature.siderealSunSign, "karmic");
  karmic += relationshipScore(userSignature.moonSign, partnerSignature.moonSign, "karmic");

  const promptScores = promptAdjustments(partner.emotionalPrompt);
  emotional += promptScores.emotional;
  attraction += promptScores.attraction;
  communication += promptScores.communication;
  stability += promptScores.stability;
  karmic += promptScores.karmic;

  emotional = Math.trunc(clampNumber(emotional, 60, 96));
  attraction = Math.trunc(clampNumber(attraction, 60, 96));
  communication = Math.trunc(clampNumber(communication, 60, 96));
  stability = Math.trunc(clampNumber(stability, 60, 96));
  karmic = Math.trunc(clampNumber(karmic, 60, 96));

  const overall = Math.trunc(clampNumber(Math.round(
    (emotional * 0.25) +
    (attraction * 0.25) +
    (communication * 0.15) +
    (stability * 0.20) +
    (karmic * 0.15)
  ), 60, 96));

  return { overall, emotional, attraction, communication, stability, karmic };
}

function friendMetric(base, ...parts) {
  return Math.trunc(clampNumber(
    base + parts.reduce((total, part) => total + (Number(part) || 0), 0),
    60,
    96
  ));
}

function calculateFriendBaseScores(user, friend) {
  const userSignature = vedicSignature(user);
  const friendSignature = vedicSignature(friend);

  const emotionalSupport = friendMetric(
    48,
    relationshipScore(userSignature.moonSign, friendSignature.moonSign, "emotional"),
    elementScore(userSignature.moonSign, friendSignature.moonSign, "emotional")
  );
  const communication = friendMetric(
    48,
    relationshipScore(userSignature.mercurySign, friendSignature.mercurySign, "communication"),
    elementScore(userSignature.mercurySign, friendSignature.mercurySign, "communication")
  );
  const trust = friendMetric(
    47,
    relationshipScore(userSignature.moonSign, friendSignature.moonSign, "stability"),
    relationshipScore(userSignature.saturnSign, friendSignature.saturnSign, "stability"),
    elementScore(userSignature.moonSign, friendSignature.moonSign, "stability")
  );
  const loyalty = friendMetric(
    48,
    relationshipScore(userSignature.siderealSunSign, friendSignature.siderealSunSign, "stability"),
    relationshipScore(userSignature.saturnSign, friendSignature.moonSign, "stability"),
    relationshipScore(friendSignature.saturnSign, userSignature.moonSign, "stability")
  );
  const conflictRepair = friendMetric(
    47,
    relationshipScore(userSignature.mercurySign, friendSignature.marsSign, "communication"),
    relationshipScore(friendSignature.mercurySign, userSignature.marsSign, "communication"),
    elementScore(userSignature.marsSign, friendSignature.marsSign, "communication")
  );
  const sharedRhythm = friendMetric(
    48,
    relationshipScore(userSignature.ascendantSign, friendSignature.ascendantSign, "stability"),
    relationshipScore(userSignature.siderealSunSign, friendSignature.siderealSunSign, "emotional"),
    elementScore(userSignature.siderealSunSign, friendSignature.siderealSunSign, "stability")
  );
  const growthPotential = friendMetric(
    49,
    relationshipScore(userSignature.rahuSign, friendSignature.siderealSunSign, "karmic"),
    relationshipScore(friendSignature.rahuSign, userSignature.siderealSunSign, "karmic"),
    relationshipScore(userSignature.moonSign, friendSignature.moonSign, "communication")
  );
  const funEnergy = friendMetric(
    50,
    relationshipScore(userSignature.siderealSunSign, friendSignature.siderealSunSign, "emotional"),
    relationshipScore(userSignature.mercurySign, friendSignature.mercurySign, "communication"),
    elementScore(userSignature.siderealSunSign, friendSignature.siderealSunSign, "emotional")
  );
  const overall = Math.trunc(clampNumber(Math.round(
    (emotionalSupport * 0.18) +
    (communication * 0.16) +
    (trust * 0.16) +
    (loyalty * 0.14) +
    (conflictRepair * 0.13) +
    (sharedRhythm * 0.10) +
    (growthPotential * 0.08) +
    (funEnergy * 0.05)
  ), 60, 96));

  return {
    overall,
    emotional_support: emotionalSupport,
    communication,
    trust,
    loyalty,
    conflict_repair: conflictRepair,
    shared_rhythm: sharedRhythm,
    growth_potential: growthPotential,
    fun_energy: funEnergy,
  };
}

function hasPair(a, b, first, second) {
  return (a === first && b === second) || (a === second && b === first);
}

function varnaRank(moonSign) {
  const element = moonSign % 4;
  if (element === 0) return 2;
  if (element === 1) return 1;
  if (element === 2) return 0;
  return 3;
}

function vashyaGroup(moonSign) {
  if ([2, 5, 6, 10].includes(moonSign)) return 0;
  if ([0, 1, 4, 8].includes(moonSign)) return 1;
  if ([3, 9, 11].includes(moonSign)) return 2;
  return 3;
}

function isAuspiciousTara(fromNakshatra, toNakshatra) {
  const tara = (((toNakshatra - fromNakshatra + 27) % 27) + 1) % 9;
  return [0, 2, 4, 6, 8].includes(tara);
}

function yoniAnimal(nakshatra) {
  const animals = [0, 1, 2, 3, 3, 4, 5, 2, 5, 6, 6, 7, 8, 9, 8, 9, 10, 10, 4, 11, 12, 11, 13, 0, 13, 7, 1];
  return animals[Math.trunc(clampNumber(nakshatra, 0, 26))];
}

function enemyYoni(a, b) {
  return [[0, 8], [1, 13], [2, 11], [3, 12], [4, 10], [5, 6], [7, 9]]
    .some(([first, second]) => hasPair(a, b, first, second));
}

function sameYoniTemperament(a, b) {
  const soft = new Set([0, 1, 5, 7, 10]);
  const active = new Set([2, 4, 6, 8, 11]);
  const intense = new Set([3, 9, 12, 13]);
  return (soft.has(a) && soft.has(b)) ||
    (active.has(a) && active.has(b)) ||
    (intense.has(a) && intense.has(b));
}

function signLord(sign) {
  return [2, 5, 3, 1, 0, 3, 5, 2, 4, 6, 6, 4][Math.trunc(clampNumber(sign, 0, 11))];
}

function planetRelation(fromLord, toLord) {
  const friends = {
    0: new Set([1, 2, 4]),
    1: new Set([0, 3]),
    2: new Set([0, 1, 4]),
    3: new Set([0, 5]),
    4: new Set([0, 1, 2]),
    5: new Set([3, 6]),
    6: new Set([3, 5]),
  };
  const enemies = {
    0: new Set([5, 6]),
    1: new Set(),
    2: new Set([3]),
    3: new Set([1]),
    4: new Set([3, 5]),
    5: new Set([0, 1]),
    6: new Set([0, 1, 2]),
  };

  if (friends[fromLord]?.has(toLord)) return 2;
  if (enemies[fromLord]?.has(toLord)) return 0;
  return 1;
}

function gana(nakshatra) {
  const values = [0, 1, 2, 1, 0, 1, 0, 0, 2, 2, 1, 1, 1, 0, 0, 2, 0, 2, 2, 1, 1, 0, 2, 2, 1, 2, 0];
  return values[Math.trunc(clampNumber(nakshatra, 0, 26))];
}

function nadi(nakshatra) {
  const values = [0, 1, 2, 2, 1, 0, 0, 1, 2, 2, 1, 0, 0, 1, 2, 2, 1, 0, 0, 1, 2, 2, 1, 0, 0, 1, 2];
  return values[Math.trunc(clampNumber(nakshatra, 0, 26))];
}

function gunaItem(name, score, maxScore, meaning) {
  return { name, score, maxScore, meaning };
}

function calculateMarriageGunaMatch(user, partner) {
  const u = vedicSignature(user);
  const p = vedicSignature(partner);
  const userVarna = varnaRank(u.moonSign);
  const partnerVarna = varnaRank(p.moonSign);
  const userVashya = vashyaGroup(u.moonSign);
  const partnerVashya = vashyaGroup(p.moonSign);
  const userYoni = yoniAnimal(u.nakshatra);
  const partnerYoni = yoniAnimal(p.nakshatra);
  const userLord = signLord(u.moonSign);
  const partnerLord = signLord(p.moonSign);
  const userGana = gana(u.nakshatra);
  const partnerGana = gana(p.nakshatra);
  const forward = ((p.moonSign - u.moonSign + 12) % 12) + 1;
  const reverse = ((u.moonSign - p.moonSign + 12) % 12) + 1;
  const challengingBhakoot = hasPair(forward, reverse, 2, 12) ||
    hasPair(forward, reverse, 5, 9) ||
    hasPair(forward, reverse, 6, 8);
  const userNadi = nadi(u.nakshatra);
  const partnerNadi = nadi(p.nakshatra);

  let yoniScore = 2;
  if (userYoni === partnerYoni) yoniScore = 4;
  else if (enemyYoni(userYoni, partnerYoni)) yoniScore = 0;
  else if (sameYoniTemperament(userYoni, partnerYoni)) yoniScore = 3;

  const relationTotal = planetRelation(userLord, partnerLord) + planetRelation(partnerLord, userLord);
  const grahaMaitriScore = relationTotal === 4 ? 5 : relationTotal === 3 ? 4 : relationTotal === 2 ? 3 : relationTotal === 1 ? 2 : 0;

  let ganaScore = 1;
  if (userGana === partnerGana) ganaScore = 6;
  else if (hasPair(userGana, partnerGana, 0, 1)) ganaScore = 5;
  else if (hasPair(userGana, partnerGana, 1, 2)) ganaScore = 3;

  const items = [
    gunaItem("Varna", Math.abs(userVarna - partnerVarna) <= 1 ? 1 : 0, 1, "Moon-sign varna balance for dharma, ego, and values."),
    gunaItem("Vashya", userVashya === partnerVashya ? 2 : (hasPair(userVashya, partnerVashya, 0, 1) || hasPair(userVashya, partnerVashya, 2, 3) ? 1 : 0), 2, "Natural pull, influence, and ease of yielding."),
    gunaItem("Tara", isAuspiciousTara(u.nakshatra, p.nakshatra) && isAuspiciousTara(p.nakshatra, u.nakshatra) ? 3 : (isAuspiciousTara(u.nakshatra, p.nakshatra) || isAuspiciousTara(p.nakshatra, u.nakshatra) ? 1 : 0), 3, "Birth-star support for luck, protection, and timing."),
    gunaItem("Yoni", yoniScore, 4, "Instinctive chemistry, desire rhythm, and intimacy comfort."),
    gunaItem("Graha Maitri", grahaMaitriScore, 5, "Moon-lord friendship for mental acceptance and trust."),
    gunaItem("Gana", ganaScore, 6, "Temperament class: deva, manushya, or rakshasa nature."),
    gunaItem("Bhakoot", challengingBhakoot ? 0 : 7, 7, "Moon-sign placement for family harmony and shared prosperity."),
    gunaItem("Nadi", userNadi === partnerNadi ? 0 : 8, 8, "Pranic compatibility, health harmony, and lineage balance."),
  ];
  const totalScore = Math.trunc(clampNumber(items.reduce((total, item) => total + item.score, 0), 0, 36));
  const level = totalScore >= 29 ? "Excellent Marriage Match" :
    totalScore >= 22 ? "Good Marriage Match" :
      totalScore >= 18 ? "Average Marriage Match" :
        "Challenging Marriage Match";
  const summary = totalScore >= 29
    ? "The Vedic Guna pattern shows strong marriage harmony, emotional support, and long-term promise."
    : totalScore >= 22
      ? "The Vedic Guna pattern is supportive, with good potential if both partners communicate with maturity."
      : totalScore >= 18
        ? "The Vedic Guna pattern is moderate. The bond may work, but emotional patience and family alignment matter."
        : "The Vedic Guna pattern shows tension in long-term adjustment. This match needs careful thought, patience, and maturity.";

  return { totalScore, maxScore: 36, level, summary, items };
}

function applyMarriageScoreToOverall(baseScores, marriageGunaMatch) {
  const safeMax = marriageGunaMatch.maxScore <= 0 ? 36 : marriageGunaMatch.maxScore;
  const safeTotal = Math.trunc(clampNumber(marriageGunaMatch.totalScore, 0, safeMax));
  const gunaPercent = Math.trunc(clampNumber(Math.round((safeTotal / safeMax) * 100), 0, 100));
  const safeBaseOverall = Math.trunc(clampNumber(baseScores.overall, 42, 96));
  const blended = Math.trunc(clampNumber(Math.round((safeBaseOverall * 0.65) + (gunaPercent * 0.35)), 0, 100));
  const uniquenessSeed = `${marriageGunaMatch.totalScore}-${baseScores.emotional}-${baseScores.attraction}-${baseScores.communication}-${baseScores.stability}-${baseScores.karmic}`
    .split("")
    .reduce((total, char) => total + char.charCodeAt(0), 0);
  const uniqueShift = (uniquenessSeed % 5) - 2;
  let finalOverall = blended + uniqueShift;

  if (safeTotal <= 18 || finalOverall < 70) finalOverall = clampNumber(finalOverall, 60, 69);
  else if (safeTotal <= 27 || finalOverall < 80) finalOverall = clampNumber(finalOverall, 70, 79);
  else finalOverall = clampNumber(finalOverall, 80, 95);

  return { ...baseScores, overall: Math.trunc(clampNumber(finalOverall, 60, 95)) };
}

function moonStyle(profile) {
  const styles = [
    "Intuitive",
    "Protective",
    "Restless",
    "Deep-feeling",
    "Practical",
    "Romantic",
    "Private",
    "Fiery",
    "Grounded",
    "Detached",
    "Devotional",
    "Sensitive",
  ];
  return styles[vedicSignature(profile).moonSign % styles.length];
}

function connectionTypeForPartner(scores) {
  if (scores.attraction >= 84 && scores.stability <= 64) return "High Chemistry, Low Peace";
  if (scores.emotional >= 80 && scores.stability >= 76) return "Emotionally Safe Match";
  if (scores.karmic >= 84 && scores.emotional < 72) return "Karmic Lesson";
  if (scores.overall >= 86) return "Soulful Bond";
  if (scores.attraction >= 82) return "Magnetic Attraction";
  if (scores.stability >= 78) return "Stable Companion";
  return "Mixed but Meaningful";
}

function verdictForScore(score) {
  if (score >= 88) return "Rare cosmic alignment";
  if (score >= 80) return "Strong compatibility";
  if (score >= 70) return "Promising bond";
  return "Challenging karmic connection";
}

function scoreQuality(score) {
  if (score >= 82) return "strong";
  if (score >= 72) return "steady";
  if (score >= 64) return "workable";
  return "delicate";
}

function friendConnectionTypeFor(scores) {
  if (scores.trust >= 84 && scores.communication >= 78) return "Trusted Inner-Circle Friend";
  if (scores.fun_energy >= 84 && scores.conflict_repair < 70) return "High Fun, Low Repair";
  if (scores.emotional_support >= 82 && scores.loyalty >= 78) return "Emotionally Reliable Friendship";
  if (scores.growth_potential >= 84 && scores.shared_rhythm < 72) return "Growth Mirror";
  if (scores.communication >= 82) return "Clear-Minded Friendship";
  if (scores.conflict_repair >= 80) return "Repairable Friendship";
  return "Useful but Uneven Friendship";
}

function friendVerdictForScore(score) {
  if (score >= 88) return "Rare friendship alignment";
  if (score >= 80) return "Strong friendship compatibility";
  if (score >= 70) return "Promising friendship";
  return "Challenging friendship pattern";
}

function scoreExtreme(scores, highest) {
  const areas = {
    "emotional harmony": scores.emotional,
    "attraction pull": scores.attraction,
    communication: scores.communication,
    "long-term stability": scores.stability,
    "karmic bond": scores.karmic,
  };
  return Object.entries(areas).reduce((current, next) => {
    return highest
      ? next[1] > current[1] ? next : current
      : next[1] < current[1] ? next : current;
  })[0];
}

function friendScoreExtreme(scores, highest) {
  const areas = {
    "emotional support": scores.emotional_support,
    communication: scores.communication,
    trust: scores.trust,
    loyalty: scores.loyalty,
    "conflict repair": scores.conflict_repair,
    "shared rhythm": scores.shared_rhythm,
    "growth potential": scores.growth_potential,
    "fun energy": scores.fun_energy,
  };
  return Object.entries(areas).reduce((current, next) => {
    return highest
      ? next[1] > current[1] ? next : current
      : next[1] < current[1] ? next : current;
  })[0];
}

function fallbackFriendSections({ profileA, profileB, scores, connectionType, verdict }) {
  const nameA = String(profileA.displayName || "one friend");
  const nameB = String(profileB.displayName || "the other friend");
  const strongest = friendScoreExtreme(scores, true);
  const softest = friendScoreExtreme(scores, false);

  return {
    summary: `${nameA} and ${nameB} show ${verdict} through a ${connectionType} pattern. This friendship works best when it stays honest, simple, and pressure-free.`,
    strengths: `The strongest area is ${strongest}. That is where the friendship feels easiest without anyone performing.`,
    tensions: `The softest area is ${softest}. That is where assumptions, silence, or mismatched effort can start to show.`,
    advice: "Keep the friendship direct and low-drama. Say the real thing early instead of testing each other through distance.",
    dailyBondSignal: "This friendship needs clarity before assumption.",
  };
}

function partnerProfileFromUserData(userData, fallbackProfile, heartSignal) {
  return {
    name: String(userData.name || fallbackProfile.displayName || "BHR1GU user"),
    dob: dateValueToIso(userData.dob),
    timeOfBirth: String(userData.timeOfBirth || "Unknown"),
    placeOfBirth: String(userData.placeOfBirth || "Unknown"),
    latitude: doubleOrNull(userData.latitude),
    longitude: doubleOrNull(userData.longitude),
    emotionalPrompt: heartSignal || "",
  };
}

function fallbackPartnerReading({
  user,
  partner,
  scores,
  marriageGunaMatch,
  userSun,
  partnerSun,
  userMoon,
  partnerMoon,
  connectionType,
  verdict,
}) {
  const strongest = scoreExtreme(scores, true);
  const softest = scoreExtreme(scores, false);
  const heartSignal = partner.emotionalPrompt.trim()
    ? `"${partner.emotionalPrompt.trim()}"`
    : "No heart signal was provided.";

  return `Verdict:
${partner.name} and ${user.name} show ${verdict} through a ${connectionType} pattern. This bond has a clear emotional shape rather than being random.

Compatibility Snapshot:
The strongest area in this match is ${strongest}, while ${softest} needs the most care. This connection should be read with nuance, not as a simple yes or no.

Heart Signal:
${heartSignal}
These exact words show what your heart is reacting to before your mind fully explains the connection.

Emotional Bond:
${user.name} carries a ${userMoon} Moon style, while ${partner.name} carries a ${partnerMoon} Moon style. The emotional bond is ${scoreQuality(scores.emotional)}, but comfort grows only when both people can name their feelings without pressure.

Attraction & Chemistry:
The attraction pull is ${scoreQuality(scores.attraction)}, so chemistry or curiosity can rise naturally between them. Strong pull can create closeness, but it should not be mistaken for emotional safety by itself.

Communication Pattern:
Communication is ${scoreQuality(scores.communication)}, so repair after misunderstanding matters more than perfect conversation. If silence, mixed signals, or ego appear, this bond needs direct truth without performance.

Long-Term Stability:
Long-term stability is ${scoreQuality(scores.stability)}, so the future depends on consistency under real pressure. The ${userSun} and ${partnerSun} dynamic can mature when patience supports the attraction.

36 Guna Marriage Reading:
The 36 Guna reading shows ${marriageGunaMatch.totalScore}/${marriageGunaMatch.maxScore}, ${marriageGunaMatch.level}. ${marriageGunaMatch.summary}

Karmic Lesson:
The karmic bond is ${scoreQuality(scores.karmic)}, so this connection may mirror attachment, timing, or expectation patterns. Its lesson is to stay honest without forcing certainty too early.

Growth Edge:
The main growth edge is ${softest}, because that area can become the future friction point. This match needs repeated behavior, not only strong feeling.

Bhrigu Warning:
Do not confuse intensity with peace, because a bond can feel powerful and still require maturity before it becomes safe.

Bhrigu's Guidance:
Move slowly and observe whether their actions match the feeling they create in you.`;
}

async function buildPartnerConnectionReading({
  authUid,
  otherUid,
  userData,
  otherData,
  userProfile,
  otherProfile,
  heartSignal,
  aiResponseLanguage,
}) {
  const user = partnerProfileFromUserData(userData, userProfile, "");
  const partner = partnerProfileFromUserData(otherData, otherProfile, heartSignal);
  const baseScores = calculatePartnerBaseScores(user, partner);
  const marriageGunaMatch = calculateMarriageGunaMatch(user, partner);
  const scores = applyMarriageScoreToOverall(baseScores, marriageGunaMatch);
  const userSun = sunSignFromDob(user.dob);
  const partnerSun = sunSignFromDob(partner.dob);
  const userMoon = moonStyle(user);
  const partnerMoon = moonStyle(partner);
  const connectionType = connectionTypeForPartner(scores);
  const verdict = verdictForScore(scores.overall);
  const userNatalChart = {
    westernChart: userData.westernChart || null,
    vedicChart: userData.vedicChart || null,
    chartGeneratedBy: userData.chartGeneratedBy || "Unknown",
    chartCalculationVersion: userData.chartCalculationVersion || "Unknown",
  };
  const partnerNatalChart = {
    westernChart: otherData.westernChart || null,
    vedicChart: otherData.vedicChart || null,
    chartGeneratedBy: otherData.chartGeneratedBy || "Unknown",
    chartCalculationVersion: otherData.chartCalculationVersion || "Unknown",
  };
  const prompt = `
Write as Bhrigu, an ancient calm sage speaking with quiet certainty. The tone should feel wise, direct, spiritual, and human, not like a report.
You are reading a partner compatibility match between two connected BHR1GU users.

IMPORTANT:
The app has already calculated the compatibility scores.
Do not change the scores.
Do not invent any percentage.
Do not write percentage numbers in your response.
Your job is to interpret the meaning of the calculated pattern.
Use the structured natal chart placements below as supporting astrology logic.
Do not reveal exact birth date, birth time, birthplace, coordinates, backend fields, or private JSON to the user.
Do not mention database, backend, helper, JSON, or AI.

User:
Name: ${user.name}
Sun Sign: ${userSun}
Moon Style: ${userMoon}

Partner:
Name: ${partner.name}
Sun Sign: ${partnerSun}
Moon Style: ${partnerMoon}

User saved natal chart for interpretation only:
${JSON.stringify(userNatalChart)}

Partner saved natal chart for interpretation only:
${JSON.stringify(partnerNatalChart)}

User's exact typed heart signal about partner:
"${partner.emotionalPrompt}"

Calculated scores for your understanding only:
Overall Compatibility: ${scores.overall}
Emotional Harmony: ${scores.emotional}
Attraction Pull: ${scores.attraction}
Communication: ${scores.communication}
Long-Term Stability: ${scores.stability}
Karmic Bond: ${scores.karmic}

36 Guna Marriage Match:
${JSON.stringify(marriageGunaMatch)}

Connection Type:
${connectionType}

Verdict Label:
${verdict}

Response format exactly:

Verdict:
Write 2 sentences giving the direct compatibility judgement using the verdict label and connection type. Do not mention any percentage.

Compatibility Snapshot:
Write 2 sentences naming the strongest compatibility area and the softest area from the calculated scores. Use words like strong, moderate, delicate, or needs maturity; do not mention any percentage.

Heart Signal:
First quote the user's exact typed feeling in quotation marks. Then explain what those exact words reveal emotionally. Do not say only "what you wrote"; interpret the actual words.

Emotional Bond:
Write 2 sentences explaining the emotional rhythm using the emotional harmony pattern and Moon styles. Do not mention any percentage.

Attraction & Chemistry:
Write 2 sentences explaining attraction and chemistry using the attraction pattern and the user's typed feeling if relevant. Do not mention any percentage.

Communication Pattern:
Write 2 sentences explaining how conversations, misunderstandings, silence, ego, or repair may work between them.

Long-Term Stability:
Write 2 sentences explaining consistency, loyalty, practical peace, and real-life future potential.

36 Guna Marriage Reading:
Write 2 sentences interpreting the 36 Guna total, level, summary, and any notable 8-koota items if present. You may mention the Guna fraction because it is not a percentage.

Karmic Lesson:
Write 2 sentences explaining what the karmic bond asks each person to learn.

Growth Edge:
Write 2 sentences naming the main risk area the user should watch, based on the softest score, the typed feeling, and the connection type.

Bhrigu Warning:
Write 1 honest warning or caution. Do not end with a question.

Bhrigu's Guidance:
Write 1 practical next step for the user. It must be gentle, grounded, and not manipulative.

Rules:
Use every section label exactly once, in the exact order above.
Keep each section body to 1 or 2 sentences, except Bhrigu Warning and Bhrigu's Guidance which are 1 sentence each.
Do not use markdown symbols.
Do not use bullet points.
Do not ask the user anything at the end.
Do not be overly positive.
Keep the tone mystical, direct, and emotionally intelligent.
${languageInstruction(aiResponseLanguage)}
`;

  let summary;
  try {
    summary = await generateGeminiReadingText({
      systemInstruction: `Follow the compatibility reading format exactly with every requested section label once and in order. Do not use markdown. Do not write percentage numbers. ${languageInstruction(aiResponseLanguage)}`,
      prompt,
      maxTokens: 1050,
      temperature: 0.35,
      model: GEMINI_FLASH_LITE_MODEL,
    });
  } catch (error) {
    console.error("Partner connection reading generation failed:", error.response?.data || error.message);
    summary = fallbackPartnerReading({
      user,
      partner,
      scores,
      marriageGunaMatch,
      userSun,
      partnerSun,
      userMoon,
      partnerMoon,
      connectionType,
      verdict,
    });
  }

  return {
    user,
    partner,
    scores,
    marriageGunaMatch,
    userSunSign: userSun,
    partnerSunSign: partnerSun,
    userMoonStyle: userMoon,
    partnerMoonStyle: partnerMoon,
    connectionType,
    verdict,
    summary: String(summary || "").trim(),
    createdAt: new Date().toISOString(),
    aiResponseLanguage,
    generatedByUid: authUid,
    partnerUid: otherUid,
  };
}

function parseSections(text, labels) {
  const result = {};
  const normalized = String(text || "").replace(/\*\*/g, "").trim();

  labels.forEach((label, index) => {
    const nextLabels = labels.slice(index + 1).map((item) =>
      item.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    );
    const nextPattern = nextLabels.length ? `(?=${nextLabels.join("|")}:|$)` : "$";
    const pattern = new RegExp(`${label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}:\\s*([\\s\\S]*?)${nextPattern}`, "i");
    const match = normalized.match(pattern);
    result[label] = match ? match[1].trim() : "";
  });

  return result;
}

async function readPublicProfile(uid) {
  const doc = await admin.firestore().collection("public_profiles").doc(uid).get();
  if (doc.exists) return doc.data();

  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  if (userDoc.exists) {
    return publicProfileFromUser(uid, userDoc.data() || {}, "");
  }

  return { uid, displayName: "BHR1GU user" };
}

/**
 * Verify the caller is a member of the connection.
 * By default also requires the connection to be "active".
 * Pass requireActive = false to allow pending connections too.
 */
async function requireConnectionMember(connectionId, uid, { requireActive = true } = {}) {
  const ref = admin.firestore().collection("connections").doc(connectionId);
  const doc = await ref.get();

  if (!doc.exists) {
    throw new HttpsError("not-found", "Connection not found.");
  }

  const data = doc.data() || {};
  if (!Array.isArray(data.memberIds) || !data.memberIds.includes(uid)) {
    throw new HttpsError("permission-denied", "You are not part of this connection.");
  }

  if (requireActive && data.status !== "active") {
    throw new HttpsError("failed-precondition", "Connection is not active.");
  }

  return { ref, data };
}

async function mirrorConnection({
  batch,
  uid,
  otherUid,
  connectionId,
  relationshipType,
  status,
  otherProfile,
  acceptedAt = null,
}) {
  const mirrorRef = admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("connections")
    .doc(otherUid);

  batch.set(
    mirrorRef,
    {
      connectionId,
      otherUid,
      relationshipType,
      status,
      otherProfile,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(acceptedAt ? { acceptedAt } : {}),
    },
    { merge: true }
  );
}

async function activateConnection({
  uidA,
  uidB,
  relationshipType,
  requesterUid = null,
}) {
  const connectionId = connectionIdFor(uidA, uidB);
  const [profileA, profileB] = await Promise.all([
    readPublicProfile(uidA),
    readPublicProfile(uidB),
  ]);
  const batch = admin.firestore().batch();
  const connectionRef = admin.firestore().collection("connections").doc(connectionId);
  const acceptedAt = admin.firestore.FieldValue.serverTimestamp();

  batch.set(
    connectionRef,
    {
      memberIds: [uidA, uidB].sort(),
      memberMap: {
        [uidA]: true,
        [uidB]: true,
      },
      relationshipType,
      status: "active",
      requesterUid,
      profiles: {
        [uidA]: profileA,
        [uidB]: profileB,
      },
      acceptedAt,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await mirrorConnection({
    batch,
    uid: uidA,
    otherUid: uidB,
    connectionId,
    relationshipType,
    status: "active",
    otherProfile: profileB,
    acceptedAt,
  });
  await mirrorConnection({
    batch,
    uid: uidB,
    otherUid: uidA,
    connectionId,
    relationshipType,
    status: "active",
    otherProfile: profileA,
    acceptedAt,
  });

  await batch.commit();
  return {
    connectionId,
    connection: {
      connectionId,
      memberIds: [uidA, uidB].sort(),
      memberMap: {
        [uidA]: true,
        [uidB]: true,
      },
      relationshipType,
      status: "active",
      requesterUid,
      profiles: {
        [uidA]: profileA,
        [uidB]: profileB,
      },
    },
  };
}

/**
 * Delete a pending connection document and both user mirror documents.
 * Used by both decline (recipient) and cancel (requester).
 */
async function deletePendingConnection(connectionId, memberIds) {
  const db = admin.firestore();
  const batch = db.batch();

  batch.delete(db.collection("connections").doc(connectionId));

  if (Array.isArray(memberIds) && memberIds.length === 2) {
    const [uidA, uidB] = memberIds;
    batch.delete(db.collection("users").doc(uidA).collection("connections").doc(uidB));
    batch.delete(db.collection("users").doc(uidB).collection("connections").doc(uidA));
  }

  await batch.commit();
}

/**
 * Delete all documents from a subcollection in batches of 400.
 */
async function deleteSubcollection(parentRef, subcollectionName) {
  const collRef = parentRef.collection(subcollectionName);
  let snap = await collRef.limit(400).get();

  while (!snap.empty) {
    const batch = admin.firestore().batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    snap = await collRef.limit(400).get();
  }
}

// ─── Exported Cloud Functions ────────────────────────────────────────────────

exports.acceptCircleSafetyPolicy = onCall(
  callableRuntimeOptions({ region: FUNCTION_REGION }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const requestData = requireRequestData(request, { maxBytes: 2000 });
    const version = boundedString(requestData.version, {
      field: "Circle policy version",
      max: 80,
      required: true,
      trim: true,
    });

    if (version !== CIRCLE_SAFETY_POLICY_VERSION) {
      throw new HttpsError(
        "invalid-argument",
        "Circle policy version is invalid."
      );
    }

    await admin.firestore().collection("users").doc(auth.uid).set(
      {
        circleSafetyPolicyVersion: CIRCLE_SAFETY_POLICY_VERSION,
        circleSafetyAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      ok: true,
      version: CIRCLE_SAFETY_POLICY_VERSION,
    };
  }
);

exports.createOrUpdatePublicProfile = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const uid = auth.uid;
    const requestData = requireRequestData(request, { maxBytes: 25000 });
    const username = cleanUsername(requestData.username);
    assertUsername(username);
    const onboardingUserData = normalizeOnboardingUserData(
      requestData.onboardingUserData,
      username
    );

    const firestore = admin.firestore();
    const userRef = firestore.collection("users").doc(uid);
    const usernameRef = firestore.collection("usernames").doc(username);
    const profileRef = firestore.collection("public_profiles").doc(uid);

    try {
      const profile = await firestore.runTransaction(async (transaction) => {
        const [userDoc, usernameDoc, profileDoc] = await Promise.all([
          transaction.get(userRef),
          transaction.get(usernameRef),
          transaction.get(profileRef),
        ]);

        const currentUserData = userDoc.exists ? userDoc.data() || {} : null;

        if (!currentUserData && !onboardingUserData) {
          throw new HttpsError("failed-precondition", "Finish onboarding first.");
        }

        if (usernameDoc.exists && usernameDoc.data().uid !== uid) {
          throw new HttpsError("already-exists", "That username is taken.");
        }

        let nextUserData = currentUserData || {};
        if (onboardingUserData && nextUserData.onboardingComplete !== true) {
          nextUserData = {
            ...onboardingUserData,
            createdAt: nextUserData.createdAt || onboardingUserData.createdAt,
          };
          transaction.set(userRef, nextUserData);
        }

        const oldUsername = cleanUsername(profileDoc.data()?.usernameLower);
        if (oldUsername && oldUsername !== username) {
          transaction.delete(firestore.collection("usernames").doc(oldUsername));
        }

        const nextProfile = publicProfileFromUser(uid, nextUserData, username);
        const writeProfile = {
          ...nextProfile,
          createdAt: profileDoc.exists
            ? profileDoc.data().createdAt || admin.firestore.FieldValue.serverTimestamp()
            : admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        transaction.set(usernameRef, {
          uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.set(profileRef, writeProfile, { merge: true });

        return nextProfile;
      });

      return { profile };
    } catch (error) {
      if (error.code === "already-exists" && onboardingUserData) {
        await clearUnreservedIncompleteUsername(firestore, uid);
      }

      throw error;
    }
  }
);

exports.searchPublicProfiles = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const requestData = requireRequestData(request, { maxBytes: 2000 });
    const username = cleanUsername(requestData.username);
    assertUsername(username);

    const usernameDoc = await admin.firestore().collection("usernames").doc(username).get();
    if (!usernameDoc.exists) return { profiles: [] };

    const uid = usernameDoc.data().uid;
    if (!uid || uid === auth.uid) return { profiles: [] };

    const profile = await readPublicProfile(uid);
    if (profile.allowSearch === false) return { profiles: [] };

    return { profiles: [profile] };
  }
);

exports.createInvite = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const requestData = requireRequestData(request, { maxBytes: 2000 });
    const relationshipType = cleanRelationshipType(requestData.relationshipType);

    // Rate limit: max 10 pending invites per hour per user.
    const oneHourAgoMillis = Date.now() - 1000 * 60 * 60;
    const inviterInvites = await admin
      .firestore()
      .collection("invites")
      .where("inviterUid", "==", auth.uid)
      .get();
    const recentInviteCount = inviterInvites.docs.filter((doc) => {
      const invite = doc.data() || {};
      return (
        invite.status === "pending" &&
        timestampMillis(invite.createdAt) >= oneHourAgoMillis
      );
    }).length;

    if (recentInviteCount >= 10) {
      throw new HttpsError(
        "resource-exhausted",
        "You have created too many invites recently. Please wait before creating more."
      );
    }

    const code = crypto.randomBytes(4).toString("hex").toUpperCase();
    const inviteRef = admin.firestore().collection("invites").doc();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + 1000 * 60 * 60 * 24 * 14
    );

    await inviteRef.set({
      code,
      inviterUid: auth.uid,
      relationshipType,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt,
    });

    return {
      inviteId: inviteRef.id,
      code,
      inviteLink: `https://astrology-guru-app.web.app/invite/${code}`,
      appLink: `bhrigu:///invite/${code}`,
    };
  }
);

exports.acceptInvite = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const requestData = requireRequestData(request, { maxBytes: 2000 });
    const code = boundedString(requestData.code, {
      field: "Invite code",
      max: 80,
      required: true,
      trim: true,
    }).toUpperCase();
    if (!code) throw new HttpsError("invalid-argument", "Invite code is required.");

    const snap = await admin
      .firestore()
      .collection("invites")
      .where("code", "==", code)
      .limit(1)
      .get();

    if (snap.empty) {
      throw new HttpsError("not-found", "Invite not found.");
    }

    const inviteDoc = snap.docs[0];
    const invite = inviteDoc.data() || {};

    if (invite.expiresAt && invite.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError("deadline-exceeded", "Invite has expired.");
    }

    if (invite.inviterUid === auth.uid) {
      throw new HttpsError("invalid-argument", "You cannot accept your own invite.");
    }

    if (invite.status !== "pending") {
      if (invite.status === "accepted" && invite.acceptedByUid === auth.uid) {
        const repaired = await activateConnection({
          uidA: invite.inviterUid,
          uidB: auth.uid,
          relationshipType: cleanRelationshipType(invite.relationshipType),
          requesterUid: invite.inviterUid,
        });

        await inviteDoc.ref.set(
          {
            connectionId: repaired.connectionId,
            repairedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        return repaired;
      }

      throw new HttpsError("failed-precondition", "Invite is no longer active.");
    }

    const activated = await activateConnection({
      uidA: invite.inviterUid,
      uidB: auth.uid,
      // Always use the relationship type the inviter chose — acceptor cannot change it.
      relationshipType: cleanRelationshipType(invite.relationshipType),
      requesterUid: invite.inviterUid,
    });

    await inviteDoc.ref.set(
      {
        status: "accepted",
        acceptedByUid: auth.uid,
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        connectionId: activated.connectionId,
      },
      { merge: true }
    );

    return activated;
  }
);

exports.sendConnectionRequest = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const requestData = requireRequestData(request, { maxBytes: 3000 });
    const targetUid = boundedString(requestData.targetUid, {
      field: "Target UID",
      max: 160,
      required: true,
      trim: true,
    });
    const relationshipType = cleanRelationshipType(requestData.relationshipType);

    if (!targetUid || targetUid === auth.uid) {
      throw new HttpsError("invalid-argument", "Choose another BHR1GU user.");
    }

    const connectionId = connectionIdFor(auth.uid, targetUid);
    const connectionRef = admin.firestore().collection("connections").doc(connectionId);
    const existingDoc = await connectionRef.get();
    const existing = existingDoc.exists ? existingDoc.data() || {} : null;

    if (existing) {
      if (existing.status === "active") {
        return { connectionId, status: "active" };
      }

      if (existing.status === "blocked") {
        throw new HttpsError("permission-denied", "This Circle connection is blocked.");
      }

      if (existing.status === "pending") {
        if (existing.requesterUid === targetUid && existing.recipientUid === auth.uid) {
          // The other person already sent a request — auto-accept using their relationship type.
          return await activateConnection({
            uidA: auth.uid,
            uidB: targetUid,
            relationshipType: cleanRelationshipType(existing.relationshipType),
            requesterUid: targetUid,
          });
        }

        return { connectionId, status: "pending" };
      }
    }

    const [profileA, profileB] = await Promise.all([
      readPublicProfile(auth.uid),
      readPublicProfile(targetUid),
    ]);
    const batch = admin.firestore().batch();

    batch.set(
      connectionRef,
      {
        memberIds: [auth.uid, targetUid].sort(),
        memberMap: {
          [auth.uid]: true,
          [targetUid]: true,
        },
        requesterUid: auth.uid,
        recipientUid: targetUid,
        relationshipType,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await mirrorConnection({
      batch,
      uid: auth.uid,
      otherUid: targetUid,
      connectionId,
      relationshipType,
      status: "outgoing",
      otherProfile: profileB,
    });
    await mirrorConnection({
      batch,
      uid: targetUid,
      otherUid: auth.uid,
      connectionId,
      relationshipType,
      status: "incoming",
      otherProfile: profileA,
    });

    await batch.commit();
    return { connectionId };
  }
);

exports.acceptConnectionRequest = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const requestData = requireRequestData(request, { maxBytes: 2000 });
    const requesterUid = boundedString(requestData.requesterUid, {
      field: "Requester UID",
      max: 160,
      required: true,
      trim: true,
    });

    if (!requesterUid || requesterUid === auth.uid) {
      throw new HttpsError("invalid-argument", "Requester is required.");
    }

    const connectionId = connectionIdFor(auth.uid, requesterUid);
    const connectionDoc = await admin.firestore().collection("connections").doc(connectionId).get();
    const data = connectionDoc.data() || {};

    if (!connectionDoc.exists || data.recipientUid !== auth.uid) {
      throw new HttpsError("permission-denied", "No incoming request found.");
    }

    if (data.status !== "pending") {
      throw new HttpsError("failed-precondition", "Request is no longer pending.");
    }

    // FIXED: Always use the requester's stored relationship type. The acceptor cannot change it.
    return await activateConnection({
      uidA: auth.uid,
      uidB: requesterUid,
      relationshipType: cleanRelationshipType(data.relationshipType),
      requesterUid,
    });
  }
);

/**
 * Decline an incoming connection request.
 * Deletes the shared connection doc and both user mirror docs entirely.
 * Only the recipient (the person receiving the request) can call this.
 */
exports.declineConnectionRequest = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const requestData = requireRequestData(request, { maxBytes: 2000 });
    const requesterUid = boundedString(requestData.requesterUid, {
      field: "Requester UID",
      max: 160,
      required: true,
      trim: true,
    });

    if (!requesterUid || requesterUid === auth.uid) {
      throw new HttpsError("invalid-argument", "Requester UID is required.");
    }

    const connectionId = connectionIdFor(auth.uid, requesterUid);
    const connectionDoc = await admin
      .firestore()
      .collection("connections")
      .doc(connectionId)
      .get();

    if (!connectionDoc.exists) {
      throw new HttpsError("not-found", "Connection request not found.");
    }

    const data = connectionDoc.data() || {};

    // Only the recipient may decline.
    if (data.recipientUid !== auth.uid) {
      throw new HttpsError("permission-denied", "Only the recipient can decline a request.");
    }

    if (data.status !== "pending") {
      throw new HttpsError("failed-precondition", "Request is no longer pending.");
    }

    const memberIds = Array.isArray(data.memberIds) ? data.memberIds : [auth.uid, requesterUid];
    await deletePendingConnection(connectionId, memberIds);

    return { ok: true };
  }
);

/**
 * Cancel an outgoing connection request.
 * Deletes the shared connection doc and both user mirror docs entirely.
 * Only the original requester can call this.
 */
exports.cancelConnectionRequest = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const requestData = requireRequestData(request, { maxBytes: 2000 });
    const targetUid = boundedString(requestData.targetUid, {
      field: "Target UID",
      max: 160,
      required: true,
      trim: true,
    });

    if (!targetUid || targetUid === auth.uid) {
      throw new HttpsError("invalid-argument", "Target UID is required.");
    }

    const connectionId = connectionIdFor(auth.uid, targetUid);
    const connectionDoc = await admin
      .firestore()
      .collection("connections")
      .doc(connectionId)
      .get();

    if (!connectionDoc.exists) {
      throw new HttpsError("not-found", "Connection request not found.");
    }

    const data = connectionDoc.data() || {};

    // Only the original requester may cancel.
    if (data.requesterUid !== auth.uid) {
      throw new HttpsError("permission-denied", "Only the requester can cancel this request.");
    }

    if (data.status !== "pending") {
      throw new HttpsError("failed-precondition", "Request is no longer pending.");
    }

    const memberIds = Array.isArray(data.memberIds) ? data.memberIds : [auth.uid, targetUid];
    await deletePendingConnection(connectionId, memberIds);

    return { ok: true };
  }
);

exports.removeConnection = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const requestData = requireRequestData(request, { maxBytes: 2000 });
    const connectionId = boundedString(requestData.connectionId, {
      field: "Connection ID",
      max: 340,
      required: true,
      trim: true,
    });
    // requireActive: false so that remove works on active connections (not pending — use cancel/decline for those)
    const { data } = await requireConnectionMember(connectionId, auth.uid, { requireActive: true });
    const memberIds = Array.isArray(data.memberIds) ? data.memberIds : [];
    const batch = admin.firestore().batch();

    batch.set(
      admin.firestore().collection("connections").doc(connectionId),
      {
        status: "archived",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    memberIds.forEach((uid) => {
      const otherUid = memberIds.find((item) => item !== uid);
      if (!otherUid) return;
      batch.set(
        admin.firestore().collection("users").doc(uid).collection("connections").doc(otherUid),
        { status: "archived", updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    });

    await batch.commit();
    return { ok: true };
  }
);

exports.blockConnection = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const requestData = requireRequestData(request, { maxBytes: 2000 });
    const otherUid = boundedString(requestData.otherUid, {
      field: "User",
      max: 160,
      required: true,
      trim: true,
    });
    if (!otherUid || otherUid === auth.uid) {
      throw new HttpsError("invalid-argument", "User is required.");
    }

    const connectionId = connectionIdFor(auth.uid, otherUid);
    const batch = admin.firestore().batch();

    batch.set(
      admin.firestore().collection("connections").doc(connectionId),
      {
        memberIds: [auth.uid, otherUid].sort(),
        memberMap: { [auth.uid]: true, [otherUid]: true },
        status: "blocked",
        blockedByUid: auth.uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // FIXED: Update blocker's mirror to "blocked".
    batch.set(
      admin.firestore().collection("users").doc(auth.uid).collection("connections").doc(otherUid),
      { connectionId, otherUid, status: "blocked", updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );

    // FIXED: Update blocked user's mirror to "archived" so they stop seeing the connection.
    batch.set(
      admin.firestore().collection("users").doc(otherUid).collection("connections").doc(auth.uid),
      { status: "archived", updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );

    await batch.commit();
    return { ok: true };
  }
);

/**
 * Switch the relationship type of an active connection.
 * Both members can initiate a switch.
 * Wipes all existing compatibility readings and daily energy so fresh data is generated.
 */
exports.switchRelationshipType = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const requestData = requireRequestData(request, { maxBytes: 3000 });
    const connectionId = boundedString(requestData.connectionId, {
      field: "Connection ID",
      max: 340,
      required: true,
      trim: true,
    });
    const newType = cleanRelationshipType(requestData.relationshipType);

    const { ref: connectionRef, data } = await requireConnectionMember(connectionId, auth.uid);
    const memberIds = Array.isArray(data.memberIds) ? data.memberIds : [];

    if (data.relationshipType === newType) {
      return { ok: true, relationshipType: newType };
    }

    // Update the shared connection doc.
    const batch = admin.firestore().batch();
    batch.set(
      connectionRef,
      { relationshipType: newType, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );

    // Update both user mirror docs.
    memberIds.forEach((uid) => {
      const otherUid = memberIds.find((item) => item !== uid);
      if (!otherUid) return;
      batch.set(
        admin.firestore().collection("users").doc(uid).collection("connections").doc(otherUid),
        { relationshipType: newType, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    });

    await batch.commit();

    // Wipe compatibility readings and daily energy so they're regenerated under the new type.
    await Promise.all([
      deleteSubcollection(connectionRef, "compatibility"),
      deleteSubcollection(connectionRef, "daily_energy"),
    ]);

    return { ok: true, relationshipType: newType };
  }
);

exports.generateConnectionCompatibility = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 180,
    memory: "256MiB",
  }),
  async (request) => {
    const requestData = requireRequestData(request, { maxBytes: 40000 });
    const auth = requireCallableAuth(request);
    const connectionId = boundedString(requestData.connectionId, {
      field: "connectionId",
      max: 128,
      required: true,
      trim: true,
    });
    const { data } = await requireConnectionMember(connectionId, auth.uid);
    const memberIds = memberPairFromConnection(data);
    const relationshipType = cleanRelationshipType(data.relationshipType);
    const [uidA, uidB] = memberIds;

    const compatibilityRef = admin
      .firestore()
      .collection("connections")
      .doc(connectionId)
      .collection("compatibility");

    // 10-day cooldown. Read this tiny per-connection subcollection directly so
    // Generate does not depend on a Firestore composite index.
    const tenDaysAgoMillis = Date.now() - 1000 * 60 * 60 * 24 * 10;
    const existingSnap = await compatibilityRef.get();
    const reusableDoc = existingSnap.docs
      .map((doc) => ({ doc, data: doc.data() || {} }))
      .filter(({ data: reading }) => {
        return (
          reading.type === relationshipType &&
          reading.contentVersion === SOCIAL_COMPATIBILITY_CONTENT_VERSION &&
          timestampMillis(reading.createdAt) >= tenDaysAgoMillis &&
          (relationshipType !== "partner" || reading.partnerMatchReading)
        );
      })
      .sort((a, b) => timestampMillis(b.data.createdAt) - timestampMillis(a.data.createdAt))[0];

    if (reusableDoc) {
      return { readingId: reusableDoc.doc.id, cached: true };
    }

    // No recent reading — generate a fresh one.
    const [userADoc, userBDoc, profileA, profileB] = await Promise.all([
      admin.firestore().collection("users").doc(uidA).get(),
      admin.firestore().collection("users").doc(uidB).get(),
      readPublicProfile(uidA),
      readPublicProfile(uidB),
    ]);
    const userA = userADoc.data() || {};
    const userB = userBDoc.data() || {};
    const aiResponseLanguage = await resolveAiResponseLanguage(auth.uid, requestData.aiResponseLanguage);
    const isFriend = relationshipType === "friend";

    if (!isFriend) {
      const heartSignal = boundedString(requestData.heartSignal, {
        field: "Heart signal",
        max: 500,
        required: true,
        trim: true,
      });

      const otherUid = memberIds.find((uid) => uid !== auth.uid);
      if (!otherUid) {
        throw new HttpsError("failed-precondition", "Connection member is missing.");
      }

      const userDataByUid = { [uidA]: userA, [uidB]: userB };
      const profileByUid = { [uidA]: profileA, [uidB]: profileB };
      const partnerMatchReading = await buildPartnerConnectionReading({
        authUid: auth.uid,
        otherUid,
        userData: userDataByUid[auth.uid] || {},
        otherData: userDataByUid[otherUid] || {},
        userProfile: profileByUid[auth.uid] || {},
        otherProfile: profileByUid[otherUid] || {},
        heartSignal,
        aiResponseLanguage,
      });

      const oldReadings = await compatibilityRef.get();
      const writeBatch = admin.firestore().batch();
      oldReadings.docs.forEach((doc) => writeBatch.delete(doc.ref));

      const readingRef = compatibilityRef.doc();
      writeBatch.set(readingRef, {
        type: "partner",
        scores: partnerMatchReading.scores,
        summary: partnerMatchReading.summary,
        strengths: "",
        tensions: "",
        advice: "",
        dailyBondSignal: partnerMatchReading.verdict,
        heartSignal,
        partnerMatchReading,
        contentVersion: SOCIAL_COMPATIBILITY_CONTENT_VERSION,
        scoreAlgorithmVersion: PARTNER_SCORE_ALGORITHM_VERSION,
        aiResponseLanguage,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdByUid: auth.uid,
      });

      await writeBatch.commit();

      await recordUsageEvent(auth.uid, {
        feature: "connection_partner_match",
        provider: "gemini",
        model: GEMINI_FLASH_LITE_MODEL,
        cached: false,
      });

      return { readingId: readingRef.id, cached: false };
    }

    const friendA = partnerProfileFromUserData(userA, profileA, "");
    const friendB = partnerProfileFromUserData(userB, profileB, "");
    const scores = calculateFriendBaseScores(friendA, friendB);
    const connectionType = friendConnectionTypeFor(scores);
    const verdict = friendVerdictForScore(scores.overall);
    const fallback = fallbackFriendSections({
      profileA,
      profileB,
      scores,
      connectionType,
      verdict,
    });
    const labels = ["SUMMARY", "STRENGTHS", "TENSIONS", "ADVICE", "DAILY_BOND_SIGNAL"];
    const prompt = `
You are BHR1GU, a social astrology guide with a blunt, poetic, app-native voice.

Create a shared friendship compatibility reading for two connected users.
The style should feel intimate, minimal, psychologically sharp, and slightly uncanny.
Do not imitate or name any existing astrology app or brand.
Use their saved cosmic blueprints, but never reveal exact birth date, birth time, birthplace, coordinates, database fields, or backend details.

Person A public profile:
${JSON.stringify(profileA)}
Person A private blueprint for interpretation only:
${JSON.stringify({ westernChart: userA.westernChart || null, vedicChart: userA.vedicChart || null })}

Person B public profile:
${JSON.stringify(profileB)}
Person B private blueprint for interpretation only:
${JSON.stringify({ westernChart: userB.westernChart || null, vedicChart: userB.vedicChart || null })}

Calculated scores:
${JSON.stringify(scores)}

Friendship verdict:
${verdict}

Friendship type:
${connectionType}

Rules:
This is strictly platonic friendship compatibility.
Do not mention attraction, chemistry, romance, dating, love, marriage, sexuality, spouse, couple dynamics, partner dynamics, or romantic long-term commitment.
Use the words friendship, friend, trust, effort, repair, loyalty, timing, respect, and boundaries.
Do not invent percentages beyond the provided scores.
Voice rules:
- Write like a social astrology app, not a horoscope article.
- Be brief, direct, and quotable.
- Prefer second person: "you two", "this friendship", "they", "you".
- Make each sentence carry one sharp insight.
- Use concrete relational behavior, not vague advice.
- Avoid generic lines like "communicate openly", "be patient", "trust the process", or "balance is important".
- Avoid therapy jargon, disclaimers, moralizing, and long explanations.
- Keep mysticism clean and modern, not ornate.

Respond in this exact format:
SUMMARY: [2-3 short sentences. Use the friendship verdict and friendship type. Make it feel like the core truth of the friendship.]
STRENGTHS: [2 short sentences. Name what works in the friendship without sounding sweet or generic.]
TENSIONS: [2 short sentences. Name the friendship friction bluntly but fairly.]
ADVICE: [2 short practical sentences. Tell them exactly what to do differently as friends.]
DAILY_BOND_SIGNAL: [1 sharp shareable sentence, max 14 words]
${languageInstruction(aiResponseLanguage)}
`;

    let parsed;
    try {
      const text = await generateGeminiReadingText({
        systemInstruction: `Return only the requested labels. Use a terse, original BHR1GU friendship-astrology voice. Do not imitate any existing brand. Do not use romantic, partner, attraction, marriage, or couple language. ${languageInstruction(aiResponseLanguage)}`,
        prompt,
        maxTokens: 620,
        temperature: 0.58,
        model: GEMINI_FLASH_LITE_MODEL,
      });
      const aiParsed = parseSections(text, labels);
      parsed = {
        SUMMARY: aiParsed.SUMMARY || fallback.summary,
        STRENGTHS: aiParsed.STRENGTHS || fallback.strengths,
        TENSIONS: aiParsed.TENSIONS || fallback.tensions,
        ADVICE: aiParsed.ADVICE || fallback.advice,
        DAILY_BOND_SIGNAL: aiParsed.DAILY_BOND_SIGNAL || fallback.dailyBondSignal,
      };
    } catch (error) {
      console.error("Friend connection reading generation failed:", error.response?.data || error.message);
      parsed = {
        SUMMARY: fallback.summary,
        STRENGTHS: fallback.strengths,
        TENSIONS: fallback.tensions,
        ADVICE: fallback.advice,
        DAILY_BOND_SIGNAL: fallback.dailyBondSignal,
      };
    }

    // Delete any older readings before writing the new one.
    const oldReadings = await compatibilityRef.get();
    const writeBatch = admin.firestore().batch();
    oldReadings.docs.forEach((doc) => writeBatch.delete(doc.ref));

    const readingRef = compatibilityRef.doc();
    writeBatch.set(readingRef, {
      type: relationshipType,
      scores,
      summary: parsed.SUMMARY || fallback.summary,
      strengths: parsed.STRENGTHS || "",
      tensions: parsed.TENSIONS || "",
      advice: parsed.ADVICE || "",
      dailyBondSignal: parsed.DAILY_BOND_SIGNAL || "",
      connectionType,
      verdict,
      contentVersion: SOCIAL_COMPATIBILITY_CONTENT_VERSION,
      scoreAlgorithmVersion: FRIEND_SCORE_ALGORITHM_VERSION,
      aiResponseLanguage,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdByUid: auth.uid,
    });

    await writeBatch.commit();

    await recordUsageEvent(auth.uid, {
      feature: "connection_compatibility",
      provider: "gemini",
      model: GEMINI_FLASH_LITE_MODEL,
      cached: false,
    });

    return { readingId: readingRef.id, cached: false };
  }
);

exports.generateConnectionDailyEnergy = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 180,
    memory: "256MiB",
  }),
  async (request) => {
    const requestData = requireRequestData(request, { maxBytes: 12000 });
    const auth = requireCallableAuth(request);
    const connectionId = boundedString(requestData.connectionId, {
      field: "connectionId",
      max: 128,
      required: true,
      trim: true,
    });

    // FIXED: Always compute dateKey server-side. Never trust the client-supplied value.
    const dateKey = dateKeyFromDate(new Date());

    const { data } = await requireConnectionMember(connectionId, auth.uid);
    const memberIds = memberPairFromConnection(data);
    const relationshipType = cleanRelationshipType(data.relationshipType);
    const [uidA, uidB] = memberIds;
    const [userADoc, userBDoc, profileA, profileB] = await Promise.all([
      admin.firestore().collection("users").doc(uidA).get(),
      admin.firestore().collection("users").doc(uidB).get(),
      readPublicProfile(uidA),
      readPublicProfile(uidB),
    ]);
    const userA = userADoc.data() || {};
    const userB = userBDoc.data() || {};
    const aiResponseLanguage = await resolveAiResponseLanguage(auth.uid, requestData.aiResponseLanguage);
    const labels = [
      "A_HEADING",
      "A_FEELING",
      "A_DO",
      "A_AVOID",
      "A_BEST_APPROACH",
      "B_HEADING",
      "B_FEELING",
      "B_DO",
      "B_AVOID",
      "B_BEST_APPROACH",
      "BOND_SIGNAL",
    ];
    const dailyRef = admin
      .firestore()
      .collection("connections")
      .doc(connectionId)
      .collection("daily_energy")
      .doc(dateKey);
    const cached = await dailyRef.get();
    if (cached.exists && cached.data().contentVersion === CONNECTION_DAILY_ENERGY_CONTENT_VERSION) {
      return { dateKey, cached: true };
    }

    const prompt = `
You are BHR1GU, creating today's social astrology guidance for a ${relationshipType} connection.
The style must be blunt, honest, straightforward, compact, and useful.
Do not imitate or name any existing astrology app or brand.
Date key: ${dateKey}

Person A:
${JSON.stringify(profileA)}
Blueprint for interpretation only:
${JSON.stringify({ westernChart: userA.westernChart || null, vedicChart: userA.vedicChart || null })}

Person B:
${JSON.stringify(profileB)}
Blueprint for interpretation only:
${JSON.stringify({ westernChart: userB.westernChart || null, vedicChart: userB.vedicChart || null })}

Rules:
Frame everything as astrology-informed guidance, not certainty about someone's mind.
Write advice for how the other person should approach them today.
Do not reveal birth date, birth time, birthplace, coordinates, backend details, or private chart JSON.
Friend mode must avoid romantic and partner language.
Voice rules:
- Write 2-3 short, punchy sentences per section. No long paragraphs.
- Use the voice of a dramatic, no-nonsense TikTok/Reels tarot reader. It should sound like an intense, hyper-specific personal call-out ("listen to me carefully," "this is exactly what's happening," "I need you to hear this").
- Drop the heavy mystical/cosmic astrology jargon; keep it snappy, modern, and highly dramatic.
- Each answer should sound like a direct, intense warning or revelation spoken directly to the camera.
- Be specific about tone, timing, pressure, silence, attention, or repair.
- Say the uncomfortable thing when the chart suggests friction, using bold, striking, "tea-spilling" words.
- Avoid cushioning every warning with positivity; give it to them straight.
- Avoid generic advice like "be supportive" or "listen more". Tell them exactly how to move.
- Keep the language emotionally sharp, punchy, and fiercely honest.
- CRITICAL PRONOUN RULE: You are writing notes that each person will read about the OTHER person.
- When writing the A_... sections (A_FEELING), write it as if Person B is reading it. Describe Person A in the THIRD PERSON ("They are feeling...", "${profileA.displayName} is..."). In A_DO, A_AVOID, A_BEST_APPROACH, speak directly to Person B ("You should do this...", "Avoid doing...").
- When writing the B_... sections (B_FEELING), write it as if Person A is reading it. Describe Person B in the THIRD PERSON ("They are feeling...", "${profileB.displayName} is..."). In B_DO, B_AVOID, B_BEST_APPROACH, speak directly to Person A ("You should do this...", "Avoid doing...").
- NEVER describe the energy using "You" or "Your" (e.g. "Your Moon is..."). Always describe their energy using "They", "Their", or their name (e.g. "Their Moon is...").

Respond exactly:
A_HEADING: [1 catchy, highly dramatic heading summarizing Person A's vibe today (max 6 words)]
A_FEELING: [2 dramatic, tea-spilling paragraphs about what Person A is currently feeling or experiencing. Accurately reference at least one specific detail from their cosmic blueprint (e.g., their Moon, Sun, or Rising sign) and transits. Use THIRD PERSON ("They/Their").]
A_DO: [2-3 direct, detailed sentences on what the reader (Person B) should actively DO with Person A today. Use "You" for the reader.]
A_AVOID: [2-3 specific, detailed sentences on what behaviors the reader (Person B) should strictly AVOID with Person A today. Use "You".]
A_BEST_APPROACH: [2-3 plain sentences on the best tone or timing the reader (Person B) should use.]
B_HEADING: [1 catchy, highly dramatic heading summarizing Person B's vibe today (max 6 words)]
B_FEELING: [2 dramatic, tea-spilling paragraphs about what Person B is currently feeling or experiencing. Accurately reference at least one specific detail from their cosmic blueprint (e.g., their Moon, Sun, or Rising sign) and transits. Use THIRD PERSON ("They/Their").]
B_DO: [2-3 direct, detailed sentences on what the reader (Person A) should actively DO with Person B today. Use "You" for the reader.]
B_AVOID: [2-3 specific, detailed sentences on what behaviors the reader (Person A) should strictly AVOID with Person B today. Use "You".]
B_BEST_APPROACH: [2-3 plain sentences on the best tone or timing the reader (Person A) should use.]
BOND_SIGNAL: [1 honest sentence about today's connection weather, max 14 words]
${languageInstruction(aiResponseLanguage)}
`;

    const text = await generateGeminiReadingText({
      systemInstruction: `Return only the requested labels. Use the highly dramatic, direct, call-out voice of a viral TikTok/Reels tarot reader. Do not imitate any existing brand. ${languageInstruction(aiResponseLanguage)}`,
      prompt,
      maxTokens: 800,
      temperature: 0.7,
      model: GEMINI_FLASH_LITE_MODEL,
    });
    const parsed = parseSections(text, labels);

    await dailyRef.set({
      dateKey,
      members: {
        [uidA]: {
          energy: parsed.A_FEELING || "",
          heading: parsed.A_HEADING || "",
          doText: parsed.A_DO || "",
          avoidText: parsed.A_AVOID || "",
          bestApproach: parsed.A_BEST_APPROACH || "",
        },
        [uidB]: {
          energy: parsed.B_FEELING || "",
          heading: parsed.B_HEADING || "",
          doText: parsed.B_DO || "",
          avoidText: parsed.B_AVOID || "",
          bestApproach: parsed.B_BEST_APPROACH || "",
        },
      },
      bondSignal: parsed.BOND_SIGNAL || "",
      contentVersion: CONNECTION_DAILY_ENERGY_CONTENT_VERSION,
      aiResponseLanguage,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      generatedByUid: auth.uid,
    });

    await recordUsageEvent(auth.uid, {
      feature: "connection_daily_energy",
      provider: "gemini",
      model: GEMINI_FLASH_LITE_MODEL,
      cached: false,
    });

    return { dateKey, cached: false };
  }
);

exports.createConnectionFollowUpContext = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const requestData = requireRequestData(request, { maxBytes: 40000 });
    const auth = requireCallableAuth(request);
    const sourceType = boundedString(requestData.sourceType, {
      field: "sourceType",
      max: 80,
      required: true,
      trim: true,
    });
    const allowedSourceTypes = new Set([
      "friend_compatibility",
      "partner_compatibility",
      "connection_daily_energy",
    ]);

    if (!allowedSourceTypes.has(sourceType)) {
      throw new HttpsError("invalid-argument", "Invalid follow-up source type.");
    }

    const connectionId = boundedString(requestData.connectionId, {
      field: "connectionId",
      max: 128,
      trim: true,
    });
    if (connectionId) {
      await requireConnectionMember(connectionId, auth.uid);
    }

    const userDoc = await admin.firestore().collection("users").doc(auth.uid).get();
    const userData = userDoc.data() || {};
    const aiResponseLanguage = await resolveAiResponseLanguage(
      auth.uid,
      requestData.aiResponseLanguage,
      userData
    );
    const contextRef = admin
      .firestore()
      .collection("users")
      .doc(auth.uid)
      .collection("follow_up_contexts")
      .doc();

    await contextRef.set({
      uid: auth.uid,
      sourceType,
      originalQuestion: boundedString(requestData.originalQuestion, {
        field: "Original question",
        max: 500,
      }),
      selectedFollowUpQuestion: boundedString(requestData.selectedFollowUpQuestion, {
        field: "Follow-up question",
        max: 500,
      }),
      readingTitle: boundedString(requestData.readingTitle, {
        field: "Reading title",
        max: 160,
        fallback: "Connection Reading",
      }),
      readingSummary: boundedString(requestData.readingSummary, {
        field: "Reading summary",
        max: 5000,
      }),
      sourceData: boundedPlainObject(requestData.sourceData, {
        field: "Source data",
        maxBytes: 20000,
      }),
      userSnapshot: {
        name: userData.name || "",
        westernChart: userData.westernChart || null,
        vedicChart: userData.vedicChart || null,
        chartGeneratedAt: userData.chartGeneratedAt || null,
        chartGeneratedBy: userData.chartGeneratedBy || null,
        chartCalculationSource: userData.chartCalculationSource || null,
        chartCalculationVersion: userData.chartCalculationVersion || null,
        chartCalculationMeta: userData.chartCalculationMeta || null,
        aiResponseLanguage,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      aiResponseLanguage,
    });

    return { contextId: contextRef.id };
  }
);
