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
  requireCallableAuth,
  requireRequestData,
  boundedString,
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
exports.calculateNatalChart = onCall(
  callableRuntimeOptions({
    region: FUNCTION_REGION,
    timeoutSeconds: 180,
    memory: "256MiB",
  }),
  async (request) => {
    const data = requireRequestData(request, { maxBytes: 12000 });
    const auth = requireCallableAuth(request);
    const decodedToken = { uid: auth.uid };

    const birthDate = boundedString(data.birthDate, {
      field: "birthDate",
      max: 32,
      required: true,
      trim: true,
    });
    const timeOfBirth = boundedString(data.timeOfBirth, {
      field: "timeOfBirth",
      max: 32,
      trim: true,
    });
    const placeOfBirth = boundedString(data.placeOfBirth, {
      field: "placeOfBirth",
      max: 160,
      trim: true,
    });
    const latitude = typeof data.latitude === "number" ? data.latitude : null;
    const longitude = typeof data.longitude === "number" ? data.longitude : null;

    if (latitude !== null && (latitude < -90 || latitude > 90)) {
      throw new HttpsError("invalid-argument", "latitude is invalid.");
    }

    if (longitude !== null && (longitude < -180 || longitude > 180)) {
      throw new HttpsError("invalid-argument", "longitude is invalid.");
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

      await recordUsageEvent(decodedToken.uid, {
        feature: "natal_chart",
        provider: "nasa_jpl",
        model: "horizons",
        cached: false,
      });

      return {
        westernChart: charts.westernChart,
        vedicChart: charts.vedicChart,
        calculationMeta: charts.calculationMeta,
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
