const {
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
  userReadingCacheRef,
  readCachedReading,
  writeCachedReading,
  callableRuntimeOptions,
  requireCallableAuth,
  requireRequestData,
  boundedString,
  boundedPlainObject,
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
} = require("../core");

function placementPhrase(planet = {}) {
  if (!planet?.name || !planet?.sign) return "";

  const degree = Number(planet.degree);
  const degreeText = Number.isFinite(degree)
    ? ` at ${roundTo(degree, 1)} degrees`
    : "";
  const retrogradeText = planet.retrograde ? " retrograde" : "";

  return `${planet.name}${retrogradeText} in ${planet.sign}${degreeText}`;
}

function buildDailyTransitSummary(dailyTransits, transitAspects) {
  if (!dailyTransits) return "";

  const aspects = Array.isArray(transitAspects) ? transitAspects : [];
  const primaryAspect = aspects[0];

  if (primaryAspect) {
    const transitPlanet = primaryAspect.transitPlanet || primaryAspect.planet;
    const aspectName = primaryAspect.aspect || primaryAspect.aspectName;
    const natalPlanet = primaryAspect.natalPlanet;
    const transitSign = primaryAspect.transitSign
      ? ` in ${primaryAspect.transitSign}`
      : "";
    const natalSign = primaryAspect.natalSign
      ? ` in ${primaryAspect.natalSign}`
      : "";
    const orb = Number(primaryAspect.orb);
    const orbText = Number.isFinite(orb)
      ? ` with a ${roundTo(orb, 2)} degree orb`
      : "";

    if (transitPlanet && aspectName && natalPlanet) {
      return `Transit data: ${transitPlanet}${transitSign} is forming a ${aspectName.toLowerCase()} to your natal ${natalPlanet}${natalSign}${orbText}.`;
    }
  }

  const tropicalPlanets = Array.isArray(dailyTransits.tropicalPlanets)
    ? dailyTransits.tropicalPlanets
    : [];
  const moon = tropicalPlanets.find((planet) => planet.name === "Moon");
  const moonText = moon ? placementPhrase(moon) : "";
  const siderealMoonText = dailyTransits.siderealMoonSign
    ? `The Vedic Moon is in ${dailyTransits.siderealMoonSign}${
        dailyTransits.siderealMoonNakshatra
          ? `, ${dailyTransits.siderealMoonNakshatra} nakshatra`
          : ""
      }`
    : "";
  const summaryParts = [
    moonText ? `Transit Moon: ${moonText}` : "",
    siderealMoonText,
  ].filter(Boolean);

  return summaryParts.length > 0
    ? `Transit data: ${summaryParts.join(". ")}.`
    : "";
}

function mergeTransitSummary(transitSummary, generatedTransit) {
  const summary = firstSentence(cleanGeneratedLine(transitSummary));
  const generated = firstSentence(cleanGeneratedLine(generatedTransit));

  if (!summary) return limitWords(generated, 55);
  if (!generated) return limitWords(summary, 55);

  return limitWords(`${summary} ${generated}`, 65);
}

const DAILY_HOROSCOPE_AI_ATTEMPTS = 3;
const DAILY_HOROSCOPE_AI_TIMEOUT_MS = Math.max(AI_REQUEST_TIMEOUT_MS, 45000);
const DAILY_HOROSCOPE_LOCK_TTL_MS = 3 * 60 * 1000;
const DAILY_HOROSCOPE_WAIT_TIMEOUT_MS = 150 * 1000;
const DAILY_HOROSCOPE_WAIT_POLL_MS = 1000;

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function hasCompleteDailyHoroscope(
  data,
  contentVersion,
  aiResponseLanguage
) {
  return Boolean(
    data &&
      data.contentVersion === contentVersion &&
      normalizeAiResponseLanguage(data.aiResponseLanguage) ===
        aiResponseLanguage &&
      (data.todayLine || data.morning || data.evening)
  );
}

function firestoreTimestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();

  const seconds = Number(value.seconds);
  if (Number.isFinite(seconds)) {
    const nanoseconds = Number(value.nanoseconds || 0);
    return seconds * 1000 + Math.floor(nanoseconds / 1000000);
  }

  const millis = Number(value);
  return Number.isFinite(millis) ? millis : 0;
}

async function claimDailyHoroscopeGeneration(
  horoscopeRef,
  {
    contentVersion,
    aiResponseLanguage,
    dateKey,
    lockOwner,
  }
) {
  const nowMs = Date.now();
  const lockExpiresAt = admin.firestore.Timestamp.fromMillis(
    nowMs + DAILY_HOROSCOPE_LOCK_TTL_MS
  );

  return admin.firestore().runTransaction(async (transaction) => {
    const doc = await transaction.get(horoscopeRef);
    const data = doc.exists ? doc.data() || {} : {};

    if (hasCompleteDailyHoroscope(data, contentVersion, aiResponseLanguage)) {
      return { state: "cached", data };
    }

    const activeLockExpiresAt = firestoreTimestampMillis(
      data.generationLockExpiresAt
    );
    const lockIsActive =
      data.generationLockOwner && activeLockExpiresAt > nowMs;

    if (lockIsActive) {
      return {
        state: "wait",
        lockOwner: data.generationLockOwner,
        lockExpiresAt: activeLockExpiresAt,
      };
    }

    transaction.set(
      horoscopeRef,
      {
        dateKey,
        contentVersion,
        aiResponseLanguage,
        generationStatus: "generating",
        generationLockOwner: lockOwner,
        generationLockExpiresAt: lockExpiresAt,
        generationStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { state: "generate" };
  });
}

async function markDailyHoroscopeGenerationFailed(
  horoscopeRef,
  lockOwner,
  error
) {
  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(horoscopeRef);
      const data = doc.exists ? doc.data() || {} : {};

      if (data.generationLockOwner !== lockOwner) return;

      transaction.set(
        horoscopeRef,
        {
          generationStatus: "failed",
          generationLockOwner: null,
          generationLockExpiresAt: null,
          generationError: String(error?.message || error || "unknown error")
            .slice(0, 500),
          generationFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
  } catch (lockError) {
    console.error(
      "Daily horoscope lock cleanup error:",
      lockError.message || lockError
    );
  }
}

function isRetryableDailyHoroscopeAiError(error) {
  const message = String(error?.message || "").toLowerCase();

  return (
    isRetryableAiError(error) ||
    message.includes("empty reading") ||
    message.includes("no candidates") ||
    message.includes("candidate") ||
    message.includes("finish reason")
  );
}

async function generateDailyHoroscopeText(prompt) {
  let lastError = null;

  for (let attempt = 1; attempt <= DAILY_HOROSCOPE_AI_ATTEMPTS; attempt += 1) {
    try {
      return await generateGeminiReadingText({
        prompt,
        maxTokens: 900,
        temperature: 0.7,
        timeoutMs: DAILY_HOROSCOPE_AI_TIMEOUT_MS,
        model: GEMINI_FLASH_LITE_MODEL,
      });
    } catch (error) {
      lastError = error;

      if (
        attempt < DAILY_HOROSCOPE_AI_ATTEMPTS &&
        isRetryableDailyHoroscopeAiError(error)
      ) {
        console.warn(
          `Daily horoscope Gemini attempt ${attempt} failed; retrying.`,
          error.response?.data || error.message
        );
        await delay(700 * attempt);
        continue;
      }

      throw error;
    }
  }

  throw lastError || new Error("Daily horoscope Gemini generation failed.");
}

function dailyHoroscopeDocId(dateKey, aiResponseLanguage) {
  return aiResponseLanguage === "hinglish" ? `${dateKey}_hinglish` : dateKey;
}

function dailyHoroscopeRef(uid, dateKey, aiResponseLanguage) {
  return admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("horoscopes")
    .doc(dailyHoroscopeDocId(dateKey, aiResponseLanguage));
}

function dartStyleValue(value) {
  if (value === null || value === undefined) return "null";

  if (Array.isArray(value)) {
    return `[${value.map((item) => dartStyleValue(item)).join(", ")}]`;
  }

  if (typeof value === "object") {
    if (typeof value.toDate === "function") {
      return value.toDate().toISOString();
    }

    return `{${Object.entries(value)
      .map(([key, item]) => `${key}: ${dartStyleValue(item)}`)
      .join(", ")}}`;
  }

  return String(value);
}

function dateFromDateKey(dateKey) {
  const parsed = moment.tz(
    `${dateKey} 00:00`,
    "YYYY-MM-DD HH:mm",
    "Asia/Kolkata"
  );

  return parsed.isValid() ? parsed.toDate() : new Date();
}

function getMoonPhaseInfo(date = new Date()) {
  const knownNewMoon = Date.UTC(2000, 0, 6, 18, 14);
  const synodicMonth = 29.530588853;
  const daysSinceKnownNewMoon =
    (date.getTime() - knownNewMoon) / MILLISECONDS_PER_DAY;
  const moonAge =
    ((daysSinceKnownNewMoon % synodicMonth) + synodicMonth) % synodicMonth;
  const phase = moonAge / synodicMonth;
  const illumination = (1 - Math.cos(phase * 2 * Math.PI)) / 2;

  if (moonAge < 1.0 || moonAge > synodicMonth - 0.5) {
    return {
      name: "New Moon",
      advice: "Pause, reset, and set one clear intention before taking action.",
      phase,
      moonAge,
      illumination,
    };
  }

  if (phase < 0.1875) {
    return {
      name: "Waxing Crescent",
      advice: "Take one small step toward something you want to grow.",
      phase,
      moonAge,
      illumination,
    };
  }

  if (phase < 0.3125) {
    return {
      name: "First Quarter",
      advice: "Choose action over overthinking. A decision needs movement.",
      phase,
      moonAge,
      illumination,
    };
  }

  if (phase < 0.4375) {
    return {
      name: "Waxing Gibbous",
      advice: "Refine your plans. Improve what is already in motion.",
      phase,
      moonAge,
      illumination,
    };
  }

  if (phase < 0.5625) {
    return {
      name: "Full Moon",
      advice: "Notice what is being revealed. Release emotional excess tonight.",
      phase,
      moonAge,
      illumination,
    };
  }

  if (phase < 0.6875) {
    return {
      name: "Waning Gibbous",
      advice: "Review the lesson, share wisdom, and avoid forcing outcomes.",
      phase,
      moonAge,
      illumination,
    };
  }

  if (phase < 0.8125) {
    return {
      name: "Last Quarter",
      advice: "Cut away what drains you. Simplify your energy and commitments.",
      phase,
      moonAge,
      illumination,
    };
  }

  return {
    name: "Waning Crescent",
    advice: "Rest, reflect, and prepare for a fresh emotional cycle.",
    phase,
    moonAge,
    illumination,
  };
}

function getDailyEnergyInfo(date = new Date()) {
  const isoWeekday = Number(moment(date).tz("Asia/Kolkata").isoWeekday());
  const planets = {
    1: {
      planet: "Moon",
      advice: "trust your intuition today",
      theme: "emotional clarity",
    },
    2: {
      planet: "Mars",
      advice: "channel your energy with purpose",
      theme: "courage and action",
    },
    3: {
      planet: "Mercury",
      advice: "choose precise words and clear decisions",
      theme: "communication",
    },
    4: {
      planet: "Jupiter",
      advice: "expand with wisdom, not excess",
      theme: "growth and perspective",
    },
    5: {
      planet: "Venus",
      advice: "nurture love, beauty, and harmony",
      theme: "relationships",
    },
    6: {
      planet: "Saturn",
      advice: "honor discipline and structure",
      theme: "responsibility",
    },
    7: {
      planet: "Sun",
      advice: "step into your power with humility",
      theme: "confidence",
    },
  };

  return planets[isoWeekday] || planets[7];
}

function getMoonPhaseOneLiner(moon) {
  switch (moon.name) {
    case "New Moon":
      return "Plant one clean intention before the day gets loud.";
    case "Waxing Crescent":
      return "Take the smallest useful step toward growth.";
    case "First Quarter":
      return "Choose action where hesitation has been winning.";
    case "Waxing Gibbous":
      return "Refine the plan before asking for results.";
    case "Full Moon":
      return "Let the revealed truth simplify your next move.";
    case "Waning Gibbous":
      return "Carry the lesson forward without forcing closure.";
    case "Last Quarter":
      return "Release the commitment that keeps draining focus.";
    default:
      return "Rest, clear space, and prepare for renewal.";
  }
}

function getDailyEnergyOneLiner(energy) {
  switch (energy.planet) {
    case "Moon":
      return "Let emotion inform you without running the day.";
    case "Mars":
      return "Move with courage, but keep your aim clean.";
    case "Mercury":
      return "Say less, mean more, and decide clearly.";
    case "Jupiter":
      return "Expand the right thing, not every thing.";
    case "Venus":
      return "Choose harmony without abandoning your own value.";
    case "Saturn":
      return "Structure gives your energy somewhere useful to land.";
    default:
      return "Lead from center, not from the need to prove.";
  }
}

function buildDailyHoroscopePrompt({
  userData,
  dateKey,
  date = dateFromDateKey(dateKey),
}) {
  const moonPhase = getMoonPhaseInfo(date);
  const dailyEnergy = getDailyEnergyInfo(date);
  const moonPhaseLine = getMoonPhaseOneLiner(moonPhase);
  const dailyEnergyLine = getDailyEnergyOneLiner(dailyEnergy);
  const birthData =
    `Name: ${dartStyleValue(userData.name)}, ` +
    `DOB: ${dartStyleValue(userData.dob)}, ` +
    `Time: ${dartStyleValue(userData.timeOfBirth)}, ` +
    `Place: ${dartStyleValue(userData.placeOfBirth)}`;
  const westernChart = dartStyleValue(userData.westernChart);
  const vedicChart = dartStyleValue(userData.vedicChart);
  const chartGeneratedBy = userData.chartGeneratedBy ?? "unknown";
  const chartCalculationSource = userData.chartCalculationSource ?? "unknown";
  const chartCalculationVersion = userData.chartCalculationVersion ?? "unknown";
  const chartCalculationMeta = dartStyleValue(userData.chartCalculationMeta);

  const prompt = `
You are Bhrigu, a Vedic and Western astrology sage.
Generate a daily horoscope for ${dateKey} for this person: ${birthData}

User cosmic blueprint generated source:
chartGeneratedBy: ${chartGeneratedBy}
chartCalculationSource: ${chartCalculationSource}
chartCalculationVersion: ${chartCalculationVersion}
chartCalculationMeta: ${chartCalculationMeta}

User NASA/JPL-backed cosmic blueprint placements:
Western chart: ${westernChart}
Vedic chart: ${vedicChart}

Use the saved chart placements as the user's natal blueprint. NASA/JPL supplies astronomical planet positions only; you provide interpretation from the chart placements and today's transits.

Today's lunar and planetary context:
Moon phase: ${moonPhase.name}, age ${moonPhase.moonAge.toFixed(2)} days, illumination ${Math.round(moonPhase.illumination * 100)}%.
Daily planetary ruler: ${dailyEnergy.planet}.
Fallback moon phase line: ${moonPhaseLine}
Fallback daily energy line: ${dailyEnergyLine}

Respond in this exact format and nothing else:
BHRIGU_TODAY: [1 sharp sentence, maximum 22 words]
YOUR_TRANSIT: [1-2 sentences explaining the strongest NASA/JPL-backed chart/transit logic provided by the backend]

DO: [One complete paragraph, 1-2 sentences. Make it actionable and specific. No bullet points.]

AVOID: [One complete paragraph, 1-2 sentences. Make it psychologically sharp. No bullet points.]

RELATIONSHIPS: [1-2 direct sentences]
WORK_MONEY: [1-2 direct sentences]
INNER_WEATHER: [1-2 direct sentences]
MANTRA: [Exactly one memorable sentence, maximum 14 words]
MOON_PHASE_LINE: [1 short line, maximum 12 words, based on the moon phase and the user's cosmic blueprint]
DAILY_ENERGY_LINE: [1 short line, maximum 12 words, based on today's planetary ruler and the user's cosmic blueprint]

Style reference:
BHRIGU_TODAY: You already know what is draining you. You are just waiting for it to become dramatic enough to justify leaving.
YOUR_TRANSIT: The Moon activates your natal Venus while Saturn pressures your emotional rhythm. Desire and duty are not moving at the same speed today.

DO: Choose the slower answer and clean one unfinished task before you ask the universe for another sign. Let someone prove consistency before you reward potential.

AVOID: Avoid explaining your pain too beautifully or checking for signs instead of patterns. Do not make loyalty out of fear.

RELATIONSHIPS: A soft message may hide a serious need. Do not punish someone for being indirect, but do not translate their silence into love.
WORK_MONEY: Small discipline brings more luck than big ambition today.
INNER_WEATHER: You may feel calm outside and restless inside. That is not confusion; it is restraint.
MANTRA: Do not romanticize what repeatedly costs you peace.

Use the user's saved NASA/JPL-backed chart placements, daily transits, and transit-to-natal aspects when provided by the backend.
Do not invent missing placements. Do not write generic sun-sign horoscope content.
Keep this sparse, impressive, modern, slightly confronting, and useful. Do not copy the example.
Every sentence must be complete and end with a period. Do not use ellipses.
Do not repeat any sentence or key phrase across sections.
MANTRA must be exactly one sentence. MANTRA must not repeat, summarize, or rephrase BHRIGU_TODAY; it must be a separate command.
Do not ask questions at the end. Do not sound like a newspaper horoscope. Do not overuse mystical words.
`;

  return {
    prompt,
    moonPhaseLine,
    dailyEnergyLine,
    horoscopeMeta: {
      moonPhase: moonPhase.name,
      moonAge: moonPhase.moonAge,
      moonIllumination: moonPhase.illumination,
      dailyPlanet: dailyEnergy.planet,
    },
  };
}

async function generateAndStoreDailyHoroscope({
  uid,
  dateKey,
  aiResponseLanguage,
  prompt,
  horoscopeRef,
  userData = null,
  horoscopeMeta = {},
  moonPhaseLine = "",
  dailyEnergyLine = "",
  recordUsage = true,
  maskAiErrors = false,
}) {
  let dailyTransits = null;
  let transitAspects = [];
  let generationUserData = userData;

  if (!generationUserData) {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    generationUserData = userDoc.data() || {};
  }

  try {
    dailyTransits = await getDailyTransits(dateKey);
    transitAspects = calculateTransitAspects(dailyTransits, generationUserData);
  } catch (transitError) {
    console.error("Daily transit cache error:", transitError);
    throw new HttpsError(
      "internal",
      "NASA/JPL transit data could not be loaded, so today's horoscope was not generated. Please try again shortly."
    );
  }

  const transitSummaryText = buildDailyTransitSummary(
    dailyTransits,
    transitAspects
  );

  if (!transitSummaryText) {
    console.error("Daily transit summary missing:", dailyTransits);
    throw new HttpsError(
      "internal",
      "NASA/JPL transit data was incomplete, so today's horoscope was not generated. Please try again shortly."
    );
  }

  let ragQuery = "";
  if (transitAspects && transitAspects.length > 0) {
    const primary = transitAspects[0];
    const transitPlanet = primary.transitPlanet || primary.planet;
    const aspectName = primary.aspect || primary.aspectName;
    const natalPlanet = primary.natalPlanet;

    if (transitPlanet && aspectName && natalPlanet) {
      ragQuery = `${transitPlanet} transit ${aspectName} ${natalPlanet}`;
    }
  } else if (dailyTransits && Array.isArray(dailyTransits.tropicalPlanets)) {
    const moon = dailyTransits.tropicalPlanets.find((p) => p.name === "Moon");
    if (moon) ragQuery = `Moon in ${moon.sign}`;
  }

  let retrievedKnowledge = "";
  if (ragQuery) {
    try {
      retrievedKnowledge = await retrieveBhriguChatKnowledge({
        message: ragQuery,
        category: "daily transit",
        limit: 2,
      });
    } catch (ragError) {
      console.error("Horoscope RAG error:", ragError.message);
    }
  }

  const ragContextText = retrievedKnowledge
    ? `Supporting astrological reference wisdom:\n${retrievedKnowledge}\n\nWeave this wisdom organically into [BHRIGU TODAY] or the action advice.`
    : "";
  const transitContextText = `NASA/JPL daily transit cache for ${dateKey}:
${JSON.stringify(dailyTransits)}

Transit-to-natal aspects for ${dateKey}:
${JSON.stringify(transitAspects)}

Use these transits as today's astronomical context. Do not claim NASA/JPL creates astrological interpretations; use the cached placements only as transit data.`;
  const actionBasis = "based purely on the NASA/JPL transit data above";

  let generationPrompt = `${prompt}

${transitContextText}
Transit summary that MUST appear near the start of [YOUR TRANSIT]:
${transitSummaryText}

${ragContextText}

STRICT ASTROLOGY ACCURACY (ZERO HALLUCINATION RULE):
You are strictly forbidden from inventing, guessing, or hallucinating chart placements, house numbers, signs, or aspects. NASA/JPL transit data is required for this reading. Only use the provided transit and aspect data.

STRICT RESPONSE STRUCTURE:
Generate the daily reading using the following strict structure. Do not use markdown bolding (**) for the body text, only for headers. Keep prose poetic, slightly detached, and fiercely direct (Bhrigu style).
Return each header on its own line, followed by its content on the next line.
Every sentence must be complete and end with a period.
Do not use ellipses.
Do not repeat any sentence or key phrase across sections.
MANTRA must be exactly one sentence. MANTRA must not restate or summarize BHRIGU TODAY; it must be a separate command.
If no transit-to-natal aspect is listed, use the NASA/JPL Moon and wider sky placements from the transit summary instead of inventing an aspect.
Never ask the user direct questions. If you must use a question, it MUST be strictly rhetorical.

Every section below (EXCEPT [YOUR TRANSIT]) must follow the Bhrigu 'hook and validation' personality cycle. Ensure there is a strict 50/50 chance each day that the overall tone leans either toward a blunt, sharp 'hard truth' OR a deeply affirmative, validating relief. Do not default to negative. Bump up the psychological creativityâ€”make the user feel profoundly seen and completely surprised by your insight without constant doom.
You must actively fight repetition. Never use the same generic advice (like 'do one thing perfectly' or 'take a breath') across days. Force extreme thematic variation ('spice') based purely on the exact planetary geometry of the day.

[BHRIGU TODAY] (1-2 sentences, maximum 45 words. Establish the core psychological insight for the day using the randomized hook/validation tone.)
[YOUR TRANSIT] (1-2 sentences. First sentence MUST name the exact transit/aspect or Moon/sign/nakshatra from the transit summary above. Include the orb when an aspect has one. If using a second sentence, explain how it feels. Keep this astrological, literal, and specific.)
[DO] (One complete paragraph, 1-2 sentences. MUST strictly be love, career, and general lifestyle advice ${actionBasis}. No bullet points.)
[AVOID] (One complete paragraph, 1-2 sentences. What one should avoid in love, career, and lifestyle ${actionBasis}. Ban generic cliches. No bullet points.)
[RELATIONSHIPS] (1-2 direct sentences on romantic or platonic dynamics.)
[WORK / MONEY] (1-2 direct sentences on material wealth or discipline.)
[INNER WEATHER] (1-2 direct sentences describing the internal emotional climate.)
[MANTRA] (Exactly 1 short, powerful, imperative sentence. Radically different every day. Add spice, attitude, and edge. Complete your sentence with a firm stop.)
`;
  generationPrompt = `${generationPrompt}${languageInstruction(aiResponseLanguage)}`;

  try {
    const text = await generateDailyHoroscopeText(generationPrompt);
    const parsed = parseDailyHoroscopeText(text, {
      moonPhaseLine,
      dailyEnergyLine,
    });
    const expandedParsed = {
      ...parsed,
      yourTransit: mergeTransitSummary(
        transitSummaryText,
        parsed.yourTransit
      ),
    };
    const storedHoroscope = {
      dateKey,
      contentVersion: HOME_HOROSCOPE_CONTENT_VERSION,
      aiResponseLanguage,
      ...expandedParsed,
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
      transitSummary: transitSummaryText,
      rawText: text,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      generationStatus: "ready",
      generationLockOwner: null,
      generationLockExpiresAt: null,
      generationError: null,
    };

    await horoscopeRef.set(storedHoroscope, { merge: true });

    if (recordUsage) {
      await recordUsageEvent(uid, {
        feature: "daily_horoscope",
        provider: "gemini",
        model: GEMINI_FLASH_LITE_MODEL,
        cached: false,
      });
    }

    return {
      storedHoroscope,
      payload: dailyHoroscopePayload({
        ...storedHoroscope,
        generatedAt: undefined,
      }),
    };
  } catch (error) {
    console.error(
      "Daily horoscope Gemini error:",
      error.response?.data || error.message
    );

    if (maskAiErrors) {
      throw new HttpsError(
        "internal",
        "Daily horoscope generation failed."
      );
    }

    throw error;
  }
}

const generateDailyHoroscopeLegacy = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 180,
    memory: "1GiB",
    concurrency: 10,
    maxInstances: 10,
  }),
  async (request) => {
    const data = requireRequestData(request, { maxBytes: 24000 });
    const auth = requireCallableAuth(request);
    const decodedToken = { uid: auth.uid };

    let prompt = boundedString(data.prompt, {
      field: "Prompt",
      max: 14000,
      required: true,
    });
    const aiResponseLanguage = await resolveAiResponseLanguage(
      decodedToken.uid,
      data.aiResponseLanguage
    );

    const dateKey = boundedString(data.dateKey, {
      field: "dateKey",
      max: 32,
      required: true,
      trim: true,
    });
    const horoscopeDocId =
      aiResponseLanguage === "hinglish" ? `${dateKey}_hinglish` : dateKey;
    const contentVersion = HOME_HOROSCOPE_CONTENT_VERSION;

    const horoscopeRef = admin
      .firestore()
      .collection("users")
      .doc(decodedToken.uid)
      .collection("horoscopes")
      .doc(horoscopeDocId);
    const horoscopeDoc = await horoscopeRef.get();

    if (horoscopeDoc.exists) {
      const cached = horoscopeDoc.data() || {};

      if (hasCompleteDailyHoroscope(cached, contentVersion, aiResponseLanguage)) {
        await recordUsageEvent(decodedToken.uid, {
          feature: "daily_horoscope",
          provider: "firestore_cache",
          model: "cached",
          cached: true,
        });

        return {
          ...dailyHoroscopePayload(cached),
          cached: true,
          aiResponseLanguage,
        };
      }
    }

    const horoscopeLockOwner = crypto.randomUUID();
    const horoscopeWaitUntil = Date.now() + DAILY_HOROSCOPE_WAIT_TIMEOUT_MS;
    let ownsHoroscopeGenerationLock = false;

    while (!ownsHoroscopeGenerationLock) {
      const lockDecision = await claimDailyHoroscopeGeneration(horoscopeRef, {
        contentVersion,
        aiResponseLanguage,
        dateKey,
        lockOwner: horoscopeLockOwner,
      });

      if (lockDecision.state === "cached") {
        await recordUsageEvent(decodedToken.uid, {
          feature: "daily_horoscope",
          provider: "firestore_cache",
          model: "cached",
          cached: true,
        });

        return {
          ...dailyHoroscopePayload(lockDecision.data),
          cached: true,
          aiResponseLanguage,
        };
      }

      if (lockDecision.state === "generate") {
        ownsHoroscopeGenerationLock = true;
        break;
      }

      const remainingWaitMs = horoscopeWaitUntil - Date.now();
      if (remainingWaitMs <= 0) {
        throw new HttpsError(
          "deadline-exceeded",
          "Daily horoscope is still being generated. Please try again shortly."
        );
      }

      await delay(Math.min(DAILY_HOROSCOPE_WAIT_POLL_MS, remainingWaitMs));
    }

    try {
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
    } catch (transitError) {
      console.error("Daily transit cache error:", transitError);
      throw new HttpsError(
        "internal",
        "NASA/JPL transit data could not be loaded, so today's horoscope was not generated. Please try again shortly."
      );
    }

    const transitSummaryText = buildDailyTransitSummary(
      dailyTransits,
      transitAspects
    );

    if (!transitSummaryText) {
      console.error("Daily transit summary missing:", dailyTransits);
      throw new HttpsError(
        "internal",
        "NASA/JPL transit data was incomplete, so today's horoscope was not generated. Please try again shortly."
      );
    }

    let ragQuery = "";
    if (transitAspects && transitAspects.length > 0) {
      const primary = transitAspects[0];
      const transitPlanet = primary.transitPlanet || primary.planet;
      const aspectName = primary.aspect || primary.aspectName;
      const natalPlanet = primary.natalPlanet;

      if (transitPlanet && aspectName && natalPlanet) {
        ragQuery = `${transitPlanet} transit ${aspectName} ${natalPlanet}`;
      }
    } else if (dailyTransits && Array.isArray(dailyTransits.tropicalPlanets)) {
      const moon = dailyTransits.tropicalPlanets.find((p) => p.name === "Moon");
      if (moon) ragQuery = `Moon in ${moon.sign}`;
    }

    let retrievedKnowledge = "";
    if (ragQuery) {
      try {
        retrievedKnowledge = await retrieveBhriguChatKnowledge({
          message: ragQuery,
          category: "daily transit",
          limit: 2,
        });
      } catch (ragError) {
        console.error("Horoscope RAG error:", ragError.message);
      }
    }

    const ragContextText = retrievedKnowledge
      ? `Supporting astrological reference wisdom:\n${retrievedKnowledge}\n\nWeave this wisdom organically into [BHRIGU TODAY] or the action advice.`
      : "";
    const transitContextText = `NASA/JPL daily transit cache for ${dateKey}:
${JSON.stringify(dailyTransits)}

Transit-to-natal aspects for ${dateKey}:
${JSON.stringify(transitAspects)}

Use these transits as today's astronomical context. Do not claim NASA/JPL creates astrological interpretations; use the cached placements only as transit data.`;
    const actionBasis = "based purely on the NASA/JPL transit data above";

    prompt = `${prompt}

${transitContextText}
Transit summary that MUST appear near the start of [YOUR TRANSIT]:
${transitSummaryText}

${ragContextText}

STRICT ASTROLOGY ACCURACY (ZERO HALLUCINATION RULE):
You are strictly forbidden from inventing, guessing, or hallucinating chart placements, house numbers, signs, or aspects. NASA/JPL transit data is required for this reading. Only use the provided transit and aspect data.

STRICT RESPONSE STRUCTURE:
Generate the daily reading using the following strict structure. Do not use markdown bolding (**) for the body text, only for headers. Keep prose poetic, slightly detached, and fiercely direct (Bhrigu style).
Return each header on its own line, followed by its content on the next line.
Every sentence must be complete and end with a period.
Do not use ellipses.
Do not repeat any sentence or key phrase across sections.
MANTRA must be exactly one sentence. MANTRA must not restate or summarize BHRIGU TODAY; it must be a separate command.
If no transit-to-natal aspect is listed, use the NASA/JPL Moon and wider sky placements from the transit summary instead of inventing an aspect.
Never ask the user direct questions. If you must use a question, it MUST be strictly rhetorical.

Every section below (EXCEPT [YOUR TRANSIT]) must follow the Bhrigu 'hook and validation' personality cycle. Ensure there is a strict 50/50 chance each day that the overall tone leans either toward a blunt, sharp 'hard truth' OR a deeply affirmative, validating relief. Do not default to negative. Bump up the psychological creativity—make the user feel profoundly seen and completely surprised by your insight without constant doom.
You must actively fight repetition. Never use the same generic advice (like 'do one thing perfectly' or 'take a breath') across days. Force extreme thematic variation ('spice') based purely on the exact planetary geometry of the day.

[BHRIGU TODAY] (1-2 sentences, maximum 45 words. Establish the core psychological insight for the day using the randomized hook/validation tone.)
[YOUR TRANSIT] (1-2 sentences. First sentence MUST name the exact transit/aspect or Moon/sign/nakshatra from the transit summary above. Include the orb when an aspect has one. If using a second sentence, explain how it feels. Keep this astrological, literal, and specific.)
[DO] (One complete paragraph, 1-2 sentences. MUST strictly be love, career, and general lifestyle advice ${actionBasis}. No bullet points.)
[AVOID] (One complete paragraph, 1-2 sentences. What one should avoid in love, career, and lifestyle ${actionBasis}. Ban generic cliches. No bullet points.)
[RELATIONSHIPS] (1-2 direct sentences on romantic or platonic dynamics.)
[WORK / MONEY] (1-2 direct sentences on material wealth or discipline.)
[INNER WEATHER] (1-2 direct sentences describing the internal emotional climate.)
[MANTRA] (Exactly 1 short, powerful, imperative sentence. Radically different every day. Add spice, attitude, and edge. Complete your sentence with a firm stop.)
`;
    prompt = `${prompt}${languageInstruction(aiResponseLanguage)}`;

    try {
      const text = await generateDailyHoroscopeText(prompt);
      const horoscopeMeta = boundedPlainObject(data.horoscopeMeta, {
        field: "horoscopeMeta",
        maxBytes: 6000,
      });
      const parsed = parseDailyHoroscopeText(text, {
        moonPhaseLine: data.moonPhaseLine,
        dailyEnergyLine: data.dailyEnergyLine,
      });
      const expandedParsed = {
        ...parsed,
        yourTransit: mergeTransitSummary(
          transitSummaryText,
          parsed.yourTransit
        ),
      };
      const storedHoroscope = {
        dateKey,
        contentVersion,
        aiResponseLanguage,
        ...expandedParsed,
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
        transitSummary: transitSummaryText,
        rawText: text,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        generationStatus: "ready",
        generationLockOwner: null,
        generationLockExpiresAt: null,
        generationError: null,
      };

      await horoscopeRef.set(storedHoroscope, { merge: true });

      await recordUsageEvent(decodedToken.uid, {
        feature: "daily_horoscope",
        provider: "gemini",
        model: GEMINI_FLASH_LITE_MODEL,
        cached: false,
      });

      return {
        ...dailyHoroscopePayload({
          ...storedHoroscope,
          generatedAt: undefined,
        }),
        cached: false,
        aiResponseLanguage,
      };
    } catch (error) {
      console.error("Daily horoscope Gemini error:", error.response?.data || error.message);

      throw new HttpsError(
        "internal",
        "Daily horoscope generation failed."
      );
    }
    } catch (error) {
      await markDailyHoroscopeGenerationFailed(
        horoscopeRef,
        horoscopeLockOwner,
        error
      );
      throw error;
    }
  }
);

exports.generateDailyHoroscope = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 180,
    memory: "1GiB",
    concurrency: 10,
    maxInstances: 10,
  }),
  async (request) => {
    const data = requireRequestData(request, { maxBytes: 24000 });
    const auth = requireCallableAuth(request);
    const decodedToken = { uid: auth.uid };

    const prompt = boundedString(data.prompt, {
      field: "Prompt",
      max: 14000,
      required: true,
    });
    const aiResponseLanguage = await resolveAiResponseLanguage(
      decodedToken.uid,
      data.aiResponseLanguage
    );

    const dateKey = boundedString(data.dateKey, {
      field: "dateKey",
      max: 32,
      required: true,
      trim: true,
    });
    const contentVersion = HOME_HOROSCOPE_CONTENT_VERSION;

    const horoscopeRef = dailyHoroscopeRef(
      decodedToken.uid,
      dateKey,
      aiResponseLanguage
    );
    const horoscopeDoc = await horoscopeRef.get();

    if (horoscopeDoc.exists) {
      const cached = horoscopeDoc.data() || {};

      if (hasCompleteDailyHoroscope(cached, contentVersion, aiResponseLanguage)) {
        await recordUsageEvent(decodedToken.uid, {
          feature: "daily_horoscope",
          provider: "firestore_cache",
          model: "cached",
          cached: true,
        });

        return {
          ...dailyHoroscopePayload(cached),
          cached: true,
          aiResponseLanguage,
        };
      }
    }

    const horoscopeLockOwner = crypto.randomUUID();
    const horoscopeWaitUntil = Date.now() + DAILY_HOROSCOPE_WAIT_TIMEOUT_MS;
    let ownsHoroscopeGenerationLock = false;

    while (!ownsHoroscopeGenerationLock) {
      const lockDecision = await claimDailyHoroscopeGeneration(horoscopeRef, {
        contentVersion,
        aiResponseLanguage,
        dateKey,
        lockOwner: horoscopeLockOwner,
      });

      if (lockDecision.state === "cached") {
        await recordUsageEvent(decodedToken.uid, {
          feature: "daily_horoscope",
          provider: "firestore_cache",
          model: "cached",
          cached: true,
        });

        return {
          ...dailyHoroscopePayload(lockDecision.data),
          cached: true,
          aiResponseLanguage,
        };
      }

      if (lockDecision.state === "generate") {
        ownsHoroscopeGenerationLock = true;
        break;
      }

      const remainingWaitMs = horoscopeWaitUntil - Date.now();
      if (remainingWaitMs <= 0) {
        throw new HttpsError(
          "deadline-exceeded",
          "Daily horoscope is still being generated. Please try again shortly."
        );
      }

      await delay(Math.min(DAILY_HOROSCOPE_WAIT_POLL_MS, remainingWaitMs));
    }

    try {
      const generated = await generateAndStoreDailyHoroscope({
        uid: decodedToken.uid,
        dateKey,
        aiResponseLanguage,
        prompt,
        horoscopeRef,
        horoscopeMeta: boundedPlainObject(data.horoscopeMeta, {
          field: "horoscopeMeta",
          maxBytes: 6000,
        }),
        moonPhaseLine: data.moonPhaseLine,
        dailyEnergyLine: data.dailyEnergyLine,
        recordUsage: true,
        maskAiErrors: true,
      });

      return {
        ...generated.payload,
        cached: false,
        aiResponseLanguage,
      };
    } catch (error) {
      await markDailyHoroscopeGenerationFailed(
        horoscopeRef,
        horoscopeLockOwner,
        error
      );
      throw error;
    }
  }
);

Object.defineProperty(exports, "__dailyHoroscopeInternals", {
  enumerable: false,
  value: {
    buildDailyHoroscopePrompt,
    dailyHoroscopeRef,
    generateAndStoreDailyHoroscope,
    hasCompleteDailyHoroscope,
  },
});
