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
const {
  requireMeteredFeature,
  refundMeteredFeatureCharge,
  REVENUECAT_SECRET_API_KEY,
} = require("../monetization/quota");
exports.generateCompatibilityEmbedding = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const data = requireRequestData(request, { maxBytes: 12000 });
    requireCallableAuth(request);

    boundedString(data.text, {
      field: "Text",
      max: 4000,
      required: true,
      trim: true,
    });

    throw new HttpsError(
      "failed-precondition",
      "Compatibility embedding generation is server-side only."
    );
  }
);

function formatCompatibilityKnowledgeChunk(chunk) {
  const tags = Array.isArray(chunk.tags) && chunk.tags.length
    ? `Tags: ${chunk.tags.join(", ")}`
    : "";
  return [
    chunk.title ? `Title: ${chunk.title}` : "",
    chunk.category ? `Category: ${chunk.category}` : "",
    tags,
    chunk.text || "",
  ]
    .filter(Boolean)
    .join("\n")
    .trim();
}

// Also used by the circle connection readings in social.js.
async function retrieveCompatibilityKnowledgeForMatch(uid, query, limit = 5) {
  try {
    const queryEmbedding = await generateGeminiEmbedding(query);
    const docs = await readCompatibilityKnowledgeDocs();
    const scoredChunks = [];

    docs.forEach((data) => {
      if (!Array.isArray(data.embedding)) return;

      const score = cosineSimilarity(queryEmbedding, data.embedding);
      const tags = Array.isArray(data.tags)
        ? data.tags.map((tag) => String(tag))
        : [];

      scoredChunks.push({
        title: String(data.title || ""),
        category: String(data.category || ""),
        tags,
        text: String(data.text || ""),
        score,
      });
    });

    scoredChunks.sort((a, b) => b.score - a.score);

    await recordUsageEvent(uid, {
      feature: "compatibility_rag",
      provider: "gemini",
      model: "gemini-embedding-001",
      cached: false,
    });

    const knowledge = scoredChunks
      .slice(0, limit)
      .map(formatCompatibilityKnowledgeChunk)
      .filter(Boolean)
      .join("\n---\n");

    return knowledge || "No specific compatibility knowledge retrieved.";
  } catch (error) {
    console.error(
      "Compatibility retrieval error:",
      error.response?.data || error.message
    );
    return "No specific compatibility knowledge retrieved.";
  }
}

function buildCompatibilityRetrievalQuery({
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
  return `
User Sun Sign: ${userSun}
User Moon Style: ${userMoon}

Partner Sun Sign: ${partnerSun}
Partner Moon Style: ${partnerMoon}

Compatibility Scores:
Overall: ${scores.overall}
Emotional Harmony: ${scores.emotional}
Attraction Pull: ${scores.attraction}
Communication: ${scores.communication}
Long-term Stability: ${scores.stability}
Karmic Bond: ${scores.karmic}

36 Guna Marriage Match:
${JSON.stringify(marriageGunaMatch)}

Connection Type: ${connectionType}
Verdict: ${verdict}
User feeling: ${partner.emotionalPrompt || ""}
`;
}

exports.retrieveCompatibilityKnowledge = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 60,
    memory: "256MiB",
  }),
  async (request) => {
    const data = requireRequestData(request, { maxBytes: 14000 });
    requireCallableAuth(request);

    boundedString(data.query, {
      field: "Query",
      max: 4000,
      required: true,
      trim: true,
    });
    Math.min(
      10,
      Math.max(1, Number.parseInt(data.limit, 10) || 5)
    );

    return { chunks: [] };
  }
);

exports.generatePartnerMatchReading = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY, REVENUECAT_SECRET_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 180,
    memory: "256MiB",
  }),
  async (request) => {
    const data = requireRequestData(request, { maxBytes: 90000 });
    const auth = requireCallableAuth(request);
    const decodedToken = { uid: auth.uid };

    const user = boundedPlainObject(data.user, {
      field: "User profile",
      maxBytes: 16000,
    });
    const partner = boundedPlainObject(data.partner, {
      field: "Partner profile",
      maxBytes: 16000,
    });
    const scores = boundedPlainObject(data.scores, {
      field: "Scores",
      maxBytes: 4000,
    });
    const marriageGunaMatch = boundedPlainObject(data.marriageGunaMatch, {
      field: "Guna match",
      maxBytes: 16000,
    });
    const userSun = boundedString(data.userSun, { field: "User sun", max: 80 });
    const partnerSun = boundedString(data.partnerSun, { field: "Partner sun", max: 80 });
    const userMoon = boundedString(data.userMoon, { field: "User moon", max: 120 });
    const partnerMoon = boundedString(data.partnerMoon, { field: "Partner moon", max: 120 });
    const connectionType = boundedString(data.connectionType, {
      field: "Connection type",
      max: 80,
    });
    const verdict = boundedString(data.verdict, { field: "Verdict", max: 160 });
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(decodedToken.uid)
      .get();
    const userData = userDoc.data() || {};
    const aiResponseLanguage = await resolveAiResponseLanguage(
      decodedToken.uid,
      data.aiResponseLanguage,
      userData
    );
    const userNatalChart = {
      westernChart: userData.westernChart || null,
      vedicChart: userData.vedicChart || null,
      chartGeneratedBy: userData.chartGeneratedBy || "Unknown",
      chartCalculationVersion: userData.chartCalculationVersion || "Unknown",
    };
    let partnerNatalChart = null;
    const meteringCharge = await requireMeteredFeature(
      decodedToken.uid,
      "manualMatch"
    );

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

    const retrievedKnowledge = await retrieveCompatibilityKnowledgeForMatch(
      decodedToken.uid,
      buildCompatibilityRetrievalQuery({
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
      }),
      5
    );

    const prompt = `
Write as Bhrigu, an ancient calm sage speaking with quiet certainty. The tone should feel wise, spiritual, poetic, and human, not like a report. Use simple but sacred language. Avoid robotic phrases like "pattern suggests", "compatibility judgement", "emotional rhythm", or "future potential" unless they sound natural. Speak as if reading two souls, while still grounding every claim in the data below.

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
If chart data is missing or incomplete, do not pretend it is complete. Lean on the scores, Moon styles, signs, emotional prompt, and 36 Guna data instead.


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

36 Guna Marriage Match:
${JSON.stringify(marriageGunaMatch)}

Connection Type:
${connectionType}

Verdict Label:
${verdict}

Retrieved Compatibility Knowledge:
${retrievedKnowledge}

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
Write 2 sentences explaining attraction and chemistry using the attraction pattern and the user's typed feeling if it mentions attraction, spark, beauty, confidence, voice, smile, or chemistry. Do not mention any percentage.

Communication Pattern:
Write 2 sentences explaining how conversations, misunderstandings, silence, ego, or repair may work between them. Use the communication score and the typed feeling if relevant.

Long-Term Stability:
Write 2 sentences explaining consistency, loyalty, practical peace, and real-life future potential. Use the stability score without mentioning any percentage.

36 Guna Marriage Reading:
Write 2 sentences interpreting the 36 Guna total, level, summary, and any notable 8-koota items if present. You may mention the Guna fraction because it is not a percentage.

Karmic Lesson:
Write 2 sentences explaining what the karmic bond asks each person to learn. Use Rahu/Ketu/Saturn language only if the provided chart or retrieved knowledge supports it.

Growth Edge:
Write 2 sentences naming the main risk area the user should watch, based on the softest score, the typed feeling, and the connection type.

Bhrigu Warning:
Write 1 honest warning or caution. Do not end with a question.

Bhrigu's Guidance:
Write 1 practical next step for the user. It must be gentle, grounded, and not manipulative.

Rules:
Use every section label exactly once, in the exact order above.
Keep each section body to 1 or 2 sentences, except Bhrigu Warning and Bhrigu's Guidance which are 1 sentence each.
Every section must be grounded in at least one of these: scores, Moon styles, Sun signs, 36 Guna data, natal chart placements, retrieved compatibility knowledge, connection type, verdict label, or the user's typed feeling.
Do not write any percentage numbers.
Do not mention database, RAG, retrieved knowledge, or AI.
Do not use markdown symbols.
Do not use bullet points.
Do not use asterisks.
Do not ask the user anything at the end.
Do not end with a question.
Do not be overly positive.
Keep the tone mystical, direct, and emotionally intelligent.
${languageInstruction(aiResponseLanguage)}
`;

    const systemInstruction =
      `Follow the compatibility reading format exactly with every requested section label once and in order. Do not use markdown. Do not use bullet points. Do not ask a question at the end. Do not write percentage numbers.\n${languageInstruction(aiResponseLanguage)}`;
    let providerUsed = "gemini";
    let modelUsed = GEMINI_FLASH_LITE_MODEL;

    try {
      let text = await generateGeminiReadingText({
        systemInstruction,
        prompt,
        maxTokens: 1050,
        temperature: 0.35,
        model: GEMINI_FLASH_LITE_MODEL,
      });
      text = await ensureHinglishText({
        text,
        aiResponseLanguage,
        preserveFormatInstruction:
          "Preserve Verdict, Compatibility Snapshot, Heart Signal, Emotional Bond, Attraction & Chemistry, Communication Pattern, Long-Term Stability, 36 Guna Marriage Reading, Karmic Lesson, Growth Edge, Bhrigu Warning, and Bhrigu's Guidance labels exactly.",
        enquiryContext: partner.emotionalPrompt ? `The user's exact typed feeling about the partner was: "${partner.emotionalPrompt}". CRITICAL: You must preserve the specific interpretation of these feelings from the original text.` : "",
        maxTokens: 1050,
      });

      await recordUsageEvent(decodedToken.uid, {
        feature: "partner_match",
        provider: providerUsed,
        model: modelUsed,
        cached: false,
      });

      return {
        text: text.trim(),
        aiResponseLanguage,
      };
    } catch (error) {
      try {
        await refundMeteredFeatureCharge(decodedToken.uid, meteringCharge);
      } catch (refundError) {
        console.error("Partner match metering refund failed:", refundError);
      }

      console.error(
        "Partner match Gemini error:",
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
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const data = requireRequestData(request, { maxBytes: 60000 });
    const auth = requireCallableAuth(request);
    const decodedToken = { uid: auth.uid };

    const westernChart = boundedPlainObject(data.westernChart, {
      field: "Western chart",
      maxBytes: 24000,
    });
    const vedicChart = boundedPlainObject(data.vedicChart, {
      field: "Vedic chart",
      maxBytes: 24000,
    });
    const aiResponseLanguage = await resolveAiResponseLanguage(
      decodedToken.uid,
      data.aiResponseLanguage
    );

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
${languageInstruction(aiResponseLanguage)}
`;

    try {
      let text = await generateUserReadingText({
        requestData: {},
        prompt,
        temperature: 0.75,
        maxTokens: 160,
      });
      text = await ensureHinglishText({
        text,
        aiResponseLanguage,
        preserveFormatInstruction:
          "Preserve names, sign names, and relationship meaning. Return one short paragraph.",
        maxTokens: 180,
      });

      await admin.firestore().collection("users").doc(decodedToken.uid).set(
        {
          compatibilityAiInsight: text.trim(),
          compatibilityAiInsightLanguage: aiResponseLanguage,
          compatibilityAiGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      await recordUsageEvent(decodedToken.uid, {
        feature: "compatibility_insight",
        provider: "gemini",
        model: GEMINI_FLASH_LITE_MODEL,
        cached: false,
      });

      return {
        text: text.trim(),
        aiResponseLanguage,
      };
    } catch (error) {
      console.error(
        "Compatibility insight Gemini error:",
        error.response?.data || error.message
      );

      throw new HttpsError(
        "internal",
        "Compatibility insight generation failed."
      );
    }
  }
);

exports.retrieveCompatibilityKnowledgeForMatch = retrieveCompatibilityKnowledgeForMatch;
