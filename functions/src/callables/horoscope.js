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
        "NASA API is busy and couldn't load transit data to build the horoscope. Please try again later."
      );
    }

    let ragQuery = "";
    if (transitAspects && transitAspects.length > 0) {
      const primary = transitAspects[0];
      ragQuery = `${primary.planet} transit ${primary.aspectName} ${primary.natalPlanet}`;
    } else if (dailyTransits && Array.isArray(dailyTransits.planets)) {
      const moon = dailyTransits.planets.find((p) => p.name === "Moon");
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

    prompt = `${prompt}

NASA/JPL daily transit cache for ${dateKey}:
${JSON.stringify(dailyTransits)}

Transit-to-natal aspects for ${dateKey}:
${JSON.stringify(transitAspects)}

${ragContextText}

Use these transits as today's astronomical context. Do not claim NASA/JPL creates astrological interpretations; use the cached placements only as transit data.

STRICT ASTROLOGY ACCURACY (ZERO HALLUCINATION RULE):
You are strictly forbidden from inventing, guessing, or hallucinating chart placements, house numbers, or signs. Only use the provided transit and aspect data.

STRICT RESPONSE STRUCTURE:
Generate the daily reading using the following strict structure. Do not use markdown bolding (**) for the body text, only for headers. Keep prose poetic, slightly detached, and fiercely direct (Bhrigu style).
Return each header on its own line, followed by its content on the next line.
Every sentence must be complete and end with a period.
Do not use ellipses.
Do not repeat any sentence or key phrase across sections.
MANTRA must not restate or summarize BHRIGU TODAY; it must be a separate command.
If you cannot use a real transit or aspect, say the lunar context plainly instead of inventing a placement.
Never ask the user direct questions. If you must use a question, it MUST be strictly rhetorical.

Every section below (EXCEPT [YOUR TRANSIT]) must follow the Bhrigu 'hook and validation' personality cycle. Ensure there is a strict 50/50 chance each day that the overall tone leans either toward a blunt, sharp 'hard truth' OR a deeply affirmative, validating relief. Do not default to negative. Bump up the psychological creativity—make the user feel profoundly seen and completely surprised by your insight without constant doom.
You must actively fight repetition. Never use the same generic advice (like 'do one thing perfectly' or 'take a breath') across days. Force extreme thematic variation ('spice') based purely on the exact planetary geometry of the day.

[BHRIGU TODAY] (2-3 sentences max. Establish the core psychological insight for the day using the randomized hook/validation tone.)
[YOUR TRANSIT] (1 sentence detailing planetary mechanics, 1 sentence on how it feels. Keep this purely astrological and literal.)
[DO] (One complete paragraph, 1-2 sentences. Actionable, highly specific, and wildly variable based on the transit. Add spice: one day it might be about reckless creativity, another about ruthless boundary setting. Never give generic productivity advice. No bullet points.)
[AVOID] (One complete paragraph, 1-2 sentences. Psychologically sharp warning that changes drastically every day. Ban generic clichés. No bullet points.)
[RELATIONSHIPS] (2 sentences on romantic or platonic dynamics using the hook/validation cycle. Keep it unpredictable.)
[WORK / MONEY] (1-2 sentences on material wealth or discipline. Force high variation daily.)
[INNER WEATHER] (1 sentence describing the internal emotional climate.)
[MANTRA] (1 short, powerful, imperative sentence. Radically different every day. Add spice, attitude, and edge. Complete your sentence with a firm stop.)
`;
    prompt = `${prompt}${languageInstruction(aiResponseLanguage)}`;

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
        aiResponseLanguage,
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
