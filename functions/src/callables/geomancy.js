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
  ensureHinglishText,
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
exports.generateGeomancyReading = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const decodedToken = { uid: auth.uid };

    const question =
      typeof request.data.question === "string"
        ? request.data.question.trim()
        : "";
    const aiResponseLanguage = await resolveAiResponseLanguage(
      decodedToken.uid,
      request.data.aiResponseLanguage
    );
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
      temperature: GEOMANCY_READING_TEMPERATURE,
      question,
      birthData,
      answer,
      chart,
      aiResponseLanguage,
    });

    const cachedText = await readCachedReading(
      decodedToken.uid,
      cacheKey,
      GEOMANCY_READING_CONTENT_VERSION,
      aiResponseLanguage
    );

    if (cachedText) {
      const safeCachedText = await ensureHinglishText({
        text: cachedText,
        aiResponseLanguage,
        preserveFormatInstruction:
          "Preserve THE JUDGEMENT, THE WITNESSES, THE RECONCILER, and EARTH'S COUNSEL headings exactly.",
        enquiryContext: `The user's original enquiry was: "${question}". CRITICAL: You must preserve every specific reference, noun, and detail related to this enquiry from the original text.`,
        maxTokens: GEOMANCY_MAX_OUTPUT_TOKENS,
      });

      if (safeCachedText !== cachedText) {
        try {
          await writeCachedReading(
            decodedToken.uid,
            cacheKey,
            GEOMANCY_READING_CONTENT_VERSION,
            safeCachedText,
            aiResponseLanguage
          );
        } catch (repairError) {
          console.warn(
            "Failed to persist repaired geomancy cache text.",
            repairError
          );
        }
      }

      await recordUsageEvent(decodedToken.uid, {
        feature: "geomancy_reading",
        provider: "firestore_cache",
        model: "cached",
        cached: true,
      });

      return {
        text: safeCachedText,
        cached: true,
        deduped: true,
        aiResponseLanguage,
      };
    }

    const geminiPrompt = `${languageInstruction(aiResponseLanguage)}
Give one short symbolic context paragraph for this geomancy chart in relation to the user's question.

User question:
${question || "General geomancy guidance. No specific question was provided."}

Judge: ${judge.name || ""}
Left Witness: ${leftWitness.name || ""}
Right Witness: ${rightWitness.name || ""}
Reconciler: ${reconciler.name || ""}

Keep it under 70 words. Stay in the user's question domain. No markdown.
`;

    let geminiContext =
      "The figure pattern suggests a movement from visible circumstances toward a deeper hidden lesson.";

    try {
      geminiContext = await generateGeminiReadingText({
        prompt: geminiPrompt,
        maxTokens: 150,
        temperature: GEOMANCY_READING_TEMPERATURE,
        model: GEMINI_FLASH_LITE_MODEL,
      });
    } catch (error) {
      console.error(
        "Geomancy Gemini error:",
        error.response?.data || error.message
      );
    }

    const q =
      question.length === 0
        ? "The user did not type a question. Give a general reading from the pattern."
        : question;

    const prompt = `${languageInstruction(aiResponseLanguage)}
You are Bhrigu Geomancer inside the BHR1GU astrology app.
You are interpreting a geomancy shield chart created by the user's sixteen hand-drawn ritual marks.

Speak like Bhrigu: wise, direct, mystical but grounded in earth magic. 
Do not sound like a generic horoscope. Keep it premium, emotionally engaging, and specific to the geomantic figures.

CORE TASK:
Answer the USER QUESTION through the Judge, Witnesses, and Reconciler.
The user's question is the anchor. Every section must directly interpret the figures in relation to that exact question.
If the question names love, career, money, health, family, timing, a choice, conflict, or spiritual direction, stay inside that domain unless a figure clearly adds a necessary connected warning.
If no specific question was provided, give a general geomancy reading from the chart without inventing a dramatic scenario.

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
[3 to 4 sentences directly answering the user's question using the Judge figure and the Judge answer. Be definitive. Mention the user's question domain and the Judge figure by name. Include the main opportunity and the main caution.]

THE WITNESSES
[4 to 5 sentences explaining the underlying forces at play using the Left and Right Witnesses. Name both witness figures. Explain what is pushing the user forward, what is resisting or delaying the matter, and how these forces affect the exact question asked.]

THE RECONCILER
[3 to 4 sentences explaining the hidden lesson, practical integration, and likely outcome using the Reconciler figure. Name the Reconciler figure. Show how it resolves the tension between the Judge and Witnesses for the user's question.]

EARTH'S COUNSEL
[2 to 3 short sentences. Give one strict action, one clear boundary or timing instruction, and one grounded mantra if it fits naturally.]

RULES:
- Do not add any conversational filler (e.g., "Here is your reading").
- Do not give generic figure meanings that could fit any question.
- Do not switch to astrology, planets, houses, signs, or transits unless the user explicitly asked for astrology.
- Treat the Judge answer as the verdict and do not contradict it.
- Reuse key nouns from the user's question naturally in every section.
- Do not add extra headings or rename the headings.
- Never ask a question at the end.
- Use the exact all-caps headings shown above.
`;

    try {
      let text = await generateGeminiReadingText({
        systemInstruction: `${languageInstruction(aiResponseLanguage)}
Follow the geomancy reading structure exactly. Preserve the required all-caps headings. Return only the reading.`,
        prompt,
        maxTokens: GEOMANCY_MAX_OUTPUT_TOKENS,
        temperature: GEOMANCY_READING_TEMPERATURE,
        model: GEMINI_FLASH_LITE_MODEL,
      });
      text = await ensureHinglishText({
        text,
        aiResponseLanguage,
        preserveFormatInstruction:
          "Preserve THE JUDGEMENT, THE WITNESSES, THE RECONCILER, and EARTH'S COUNSEL headings exactly.",
        enquiryContext: `The user's original enquiry was: "${question}". CRITICAL: You must preserve every specific reference, noun, and detail related to this enquiry from the original text.`,
        maxTokens: GEOMANCY_MAX_OUTPUT_TOKENS,
      });
      await writeCachedReading(
        decodedToken.uid,
        cacheKey,
        GEOMANCY_READING_CONTENT_VERSION,
        text,
        aiResponseLanguage
      );

      await recordUsageEvent(decodedToken.uid, {
        feature: "geomancy_reading",
        provider: "gemini",
        model: GEMINI_FLASH_LITE_MODEL,
        cached: false,
      });

      return {
        text: text,
        cached: false,
        aiResponseLanguage,
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
