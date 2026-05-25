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
  userReadingCacheRef,
  readCachedReading,
  writeCachedReading,
  callableRuntimeOptions,
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
    memory: "512MiB",
  }),
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
        await recordUsageEvent(decodedToken.uid, {
          feature: "daily_horoscope",
          provider: "firestore_cache",
          model: "cached",
          cached: true,
        });

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
