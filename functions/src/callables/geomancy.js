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
  retrieveGeomancyKnowledge,
} = require("../core");
const {
  requireMeteredFeature,
  refundMeteredFeatureCharge,
  REVENUECAT_SECRET_API_KEY,
} = require("../monetization/quota");

// Opening sentences from the user's most recent saved geomancy readings, fed
// into the prompt as phrasing the model must not echo. Never throws —
// uniqueness help must not block reading generation.
async function readRecentGeomancyOpeners(uid) {
  try {
    const snap = await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection("geomancy_readings")
      .orderBy("createdAt", "desc")
      .limit(2)
      .get();

    const openers = [];

    snap.forEach((doc) => {
      const reading = String(doc.data()?.interpretation || "");

      reading.split(/\n\n+/).forEach((section) => {
        const body = section
          .replace(
            /^(THE JUDGEMENT|THE WITNESSES|THE RECONCILER|EARTH'S COUNSEL)[^\n]*\n/i,
            ""
          )
          .trim();
        const sentence = (body.match(/[^.!?]+[.!?]/) || [""])[0].trim();

        if (sentence) {
          openers.push(sentence);
        }
      });
    });

    return openers.slice(0, 8).join("\n");
  } catch (error) {
    console.warn("Geomancy recent openers lookup failed:", error.message);
    return "";
  }
}

exports.generateGeomancyReading = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY, REVENUECAT_SECRET_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 120,
    memory: "256MiB",
  }),
  async (request) => {
    const data = requireRequestData(request, { maxBytes: 50000 });
    const auth = requireCallableAuth(request);
    const decodedToken = { uid: auth.uid };

    const question = boundedString(data.question, {
      field: "Question",
      max: 1000,
      trim: true,
    });
    const aiResponseLanguage = await resolveAiResponseLanguage(
      decodedToken.uid,
      data.aiResponseLanguage
    );
    const birthData = boundedString(data.birthData, {
      field: "Birth data",
      max: 2500,
      fallback: "Birth data not available.",
    });
    const answer = boundedString(data.answer, {
      field: "Answer",
      max: 120,
      fallback: "Mixed result",
    });
    const chart = boundedPlainObject(data.chart, {
      field: "Geomancy chart",
      maxBytes: 16000,
    });

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

    const meteringCharge = await requireMeteredFeature(decodedToken.uid, "geomancy");
    let cachedText;

    try {
      cachedText = await readCachedReading(
        decodedToken.uid,
        cacheKey,
        GEOMANCY_READING_CONTENT_VERSION,
        aiResponseLanguage
      );
    } catch (error) {
      try {
        await refundMeteredFeatureCharge(decodedToken.uid, meteringCharge);
      } catch (refundError) {
        console.error("Geomancy cache metering refund failed:", refundError);
      }

      throw error;
    }

    if (cachedText) {
      try {
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
      } catch (error) {
        try {
          await refundMeteredFeatureCharge(decodedToken.uid, meteringCharge);
        } catch (refundError) {
          console.error(
            "Geomancy cached-reading metering refund failed:",
            refundError
          );
        }

        throw error;
      }
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

    let judgeKnowledge;
    let leftWitnessKnowledge;
    let rightWitnessKnowledge;
    let reconcilerKnowledge;
    let geminiContext;
    let recentOpeners = "";

    try {
      // The context paragraph and recent-opener lookup only need the figure
      // names and question, so they run in parallel with knowledge retrieval
      // instead of after it. Both are self-caught and fall back safely; only
      // a knowledge retrieval failure rejects and refunds.
      [
        judgeKnowledge,
        leftWitnessKnowledge,
        rightWitnessKnowledge,
        reconcilerKnowledge,
        geminiContext,
        recentOpeners,
      ] = await Promise.all([
        retrieveGeomancyKnowledge({ figureName: judge.name, role: "judge" }),
        retrieveGeomancyKnowledge({
          figureName: leftWitness.name,
          role: "witness",
        }),
        retrieveGeomancyKnowledge({
          figureName: rightWitness.name,
          role: "witness",
        }),
        retrieveGeomancyKnowledge({
          figureName: reconciler.name,
          role: "reconciler",
        }),
        generateGeminiReadingText({
          prompt: geminiPrompt,
          maxTokens: 150,
          temperature: GEOMANCY_READING_TEMPERATURE,
          model: GEMINI_FLASH_LITE_MODEL,
        }).catch((error) => {
          console.error(
            "Geomancy Gemini error:",
            error.response?.data || error.message
          );
          return "The figure pattern suggests a movement from visible circumstances toward a deeper hidden lesson.";
        }),
        readRecentGeomancyOpeners(decodedToken.uid),
      ]);
    } catch (error) {
      console.error("Geomancy knowledge retrieval error:", error.message);

      try {
        await refundMeteredFeatureCharge(decodedToken.uid, meteringCharge);
      } catch (refundError) {
        console.error("Geomancy metering refund failed:", refundError);
      }

      throw new HttpsError(
        "internal",
        "Geomancy reading generation failed."
      );
    }

    const q =
      question.length === 0
        ? "The user did not type a question. Give a general reading from the pattern."
        : question;

    const prompt = `${languageInstruction(aiResponseLanguage)}
You are Bhrigu Geomancer inside the BHR1GU astrology app.
You are interpreting a geomancy shield chart created by the user's sixteen hand-drawn ritual marks.

You are not explaining figures. You are looking through them. Write as a seer who perceives the user's situation through the chart. Voice that perception in your own words each time; never open two sections, or two readings, with the same seer phrase.
Somewhere in the reading, name one true-feeling thing you perceive about who the user is or what they carry (their patience, their instinct, how much they give, what they have quietly survived). Deliver it as something the chart revealed to you, never as a compliment. It must feel discovered, not given.
When a figure carries a hard truth, tell it - but frame it as a test this user in particular has the strength to pass, because of the quality you perceived in their energy.
Always leave the user with hope. Point to the direction and the opening, never hand over a complete step-by-step solution; the outcome should feel promising and still unfolding.

VOICE:
- STRICT: speak normally, like a real human in 2026 - the register of an average American girl in her twenties: casual, warm, direct, contractions everywhere. No performance, no forced or overused slang, no theatrical mysticism. Do not sound like a generic horoscope.
- STRICT: no stock filler. Words like "journey", "embrace", "align", "manifest", "crossroads", "chapter", "the universe has a plan" may appear at most once in the whole reading; prefer a fresh synonym or a plainer phrase every time, so two readings for the same user never sound alike.
- Vary sentence rhythm. No two sections may open with the same sentence pattern.

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

Retrieved figure knowledge (ground every interpretation in this; never invent or soften figure meanings):

JUDGE - ${judge.name || ""}:
${judgeKnowledge}

LEFT WITNESS - ${leftWitness.name || ""}:
${leftWitnessKnowledge}

RIGHT WITNESS - ${rightWitness.name || ""}:
${rightWitnessKnowledge}

RECONCILER - ${reconciler.name || ""}:
${reconcilerKnowledge}

Gemini contextual note:
${geminiContext}
${recentOpeners ? `
RECENT READINGS (already heard by this user):
The user has recently heard readings opening with the lines below. Do not reuse their sentence patterns, images, metaphors, or phrases anywhere in this reading:
${recentOpeners}
` : ""}

STRICT RESPONSE STRUCTURE:
You MUST format your response exactly like this. Plain text only. No markdown (no ** or *). Separate each section with a double line break. 

THE JUDGEMENT
[2 to 4 sentences directly answering the user's question using the Judge figure and the Judge answer. Be definitive and speak as a seer. Name the Judge figure. Build it around what you see for this exact question, not a textbook figure meaning.]

THE WITNESSES
[3 to 5 sentences on the underlying forces using the Left and Right Witnesses. Name both witness figures. Describe the energy pushing this matter forward and the energy resisting or slowing it, as things you perceive around the user's exact question. Do not mirror the shape of the previous section.]

THE RECONCILER
[3 to 4 sentences using the Reconciler figure. Name it. Make a real prediction here: a committed direction for the user's question with a soft natural timeframe you invent yourself - never a stock phrase - and one distinctive detail. Do not hedge it into meaninglessness, and leave the outcome feeling hopeful and still unfolding.]

EARTH'S COUNSEL
[2 to 3 short sentences. One simple, doable next step and one thing to hold back from or wait for - given as direction, not a full solution. End on hope.]

RULES:
- Do not add any conversational filler (e.g., "Here is your reading").
- Ground every figure interpretation in the retrieved figure knowledge above, using each figure's role (Judge, Witness, Reconciler) and the domain of the user's question. Never contradict or soften that knowledge.
- STRICT: every section is about the user's question, start to finish. The image you build, the energy you describe, and the prediction you make must all exist to answer that exact question - a sentence that would survive unchanged under a different question does not belong. Reference the question's subject naturally in each section, but vary the wording; do not repeat the same question phrase in more than two sections.
- Each section is built around one concrete, sensory, real-life image the user can actually picture (a place, object, gesture, or moment) tied to their exact question, never an abstract line that could fit anyone.
- Each section must also grow out of its own figure's retrieved knowledge: if a different figure sat in that position, the section must have to change. A section that could sit under another figure unchanged must be rewritten.
- Let each figure say what it actually says. One section may be pure encouragement, another a quiet warning, another a foreseen event. Never force the same internal shape onto every section, and never balance every hope with a caution out of habit.
- Do not switch to astrology, planets, houses, signs, or transits unless the user explicitly asked for astrology.
- Treat the Judge answer as the verdict and do not contradict it.
- Never name or label beats; do not write meta phrases like "the main opportunity is", "the caution here is", or "the next step is". Just say the thing directly.
- Plant exactly one deliberately unresolved thread inside THE WITNESSES or THE RECONCILER, written as an intriguing statement and never as a question, so the user is left wanting to ask a follow-up. Keep THE JUDGEMENT and EARTH'S COUNSEL definitive.
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

      try {
        await refundMeteredFeatureCharge(decodedToken.uid, meteringCharge);
      } catch (refundError) {
        console.error("Geomancy metering refund failed:", refundError);
      }

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
