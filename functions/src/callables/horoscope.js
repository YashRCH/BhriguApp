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

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
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

exports.generateDailyHoroscope = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 180,
    memory: "1GiB",
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const decodedToken = { uid: auth.uid };

    let prompt = request.data.prompt;
    const aiResponseLanguage = await resolveAiResponseLanguage(
      decodedToken.uid,
      request.data.aiResponseLanguage
    );

    if (!prompt || typeof prompt !== "string") {
      throw new HttpsError("invalid-argument", "Prompt is required.");
    }

    if (prompt.length > 14000) {
      throw new HttpsError("invalid-argument", "Prompt is too long.");
    }

    const dateKey = String(request.data.dateKey || "").trim();
    const horoscopeDocId =
      aiResponseLanguage === "hinglish" ? `${dateKey}_hinglish` : dateKey;
    const contentVersion = HOME_HOROSCOPE_CONTENT_VERSION;

    if (!dateKey) {
      throw new HttpsError("invalid-argument", "dateKey is required.");
    }

    const horoscopeRef = admin
      .firestore()
      .collection("users")
      .doc(decodedToken.uid)
      .collection("horoscopes")
      .doc(horoscopeDocId);
    const horoscopeDoc = await horoscopeRef.get();

    if (horoscopeDoc.exists) {
      const cached = horoscopeDoc.data() || {};

      if (
          cached.contentVersion === contentVersion &&
          normalizeAiResponseLanguage(cached.aiResponseLanguage) === aiResponseLanguage &&
          (cached.todayLine || cached.morning || cached.evening)
      ) {
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
      const horoscopeMeta = request.data.horoscopeMeta || {};
      const parsed = parseDailyHoroscopeText(text, {
        moonPhaseLine: request.data.moonPhaseLine,
        dailyEnergyLine: request.data.dailyEnergyLine,
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
  }
);
