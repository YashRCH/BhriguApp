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
exports.generateTarotEmbedding = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const decodedToken = { uid: auth.uid };

    const text = request.data.text;

    if (!text || typeof text !== "string") {
      throw new HttpsError("invalid-argument", "Text is required.");
    }

    if (text.length > 4000) {
      throw new HttpsError("invalid-argument", "Text is too long.");
    }

    try {
      const values = await generateGeminiEmbedding(text);

      await recordUsageEvent(decodedToken.uid, {
        feature: "tarot_embedding",
        provider: "gemini",
        model: "gemini-embedding-001",
        cached: false,
      });

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

exports.generateTarotReading = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 120,
    memory: "1GiB",
  }),
  async (request) => {
    const auth = requireCallableAuth(request);
    const decodedToken = { uid: auth.uid };

    const birthData = request.data.birthData || "Birth data not available.";
    const aiResponseLanguage = await resolveAiResponseLanguage(
      decodedToken.uid,
      request.data.aiResponseLanguage
    );
    const question =
      typeof request.data.question === "string"
        ? request.data.question.trim()
        : "";
    const enquiryText =
      question.length === 0
        ? "General tarot guidance. No specific enquiry was provided."
        : question;
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
      temperature: TAROT_READING_TEMPERATURE,
      birthData,
      question,
      pastName,
      presentName,
      futureName,
      pastKeywords,
      presentKeywords,
      futureKeywords,
      aiResponseLanguage,
    });

    const cachedText = await readCachedReading(
      decodedToken.uid,
      cacheKey,
      TAROT_READING_CONTENT_VERSION,
      aiResponseLanguage
    );

    if (cachedText) {
      const safeCachedText = await ensureHinglishText({
        text: cachedText,
        aiResponseLanguage,
        preserveFormatInstruction:
          "Preserve PAST, PRESENT, FUTURE headings and all card names exactly.",
        maxTokens: TAROT_MAX_OUTPUT_TOKENS,
      });

      if (safeCachedText !== cachedText) {
        try {
          await writeCachedReading(
            decodedToken.uid,
            cacheKey,
            TAROT_READING_CONTENT_VERSION,
            safeCachedText,
            aiResponseLanguage
          );
        } catch (repairError) {
          console.warn(
            "Failed to persist repaired tarot cache text.",
            repairError
          );
        }
      }

      await recordUsageEvent(decodedToken.uid, {
        feature: "tarot_reading",
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
You are Bhrigu, a Vedic sage and experienced tarot reader inside the BHR1GU app.

CORE TASK:
Answer the SEEKER_ENQUIRY through the three drawn tarot cards.
The enquiry is the anchor. Every section must directly interpret its card in relation to that exact enquiry.
If the enquiry names love, career, money, health, family, timing, choice, or spiritual direction, stay inside that domain unless a card clearly adds a necessary connected warning.
If the enquiry is empty or generic, give a general reading, but do not invent unrelated dramatic scenarios.

STRICT ENQUIRY RULES:
- Treat SEEKER_ENQUIRY as the question being judged by the spread, not as optional background.
- Each card section must contain at least two specific references to the enquiry's subject or situation.
- Reuse key nouns from SEEKER_ENQUIRY naturally in every card section.
- Do not give a generic meaning that could fit any question.
- Do not switch domains. For example, if the enquiry is about love, do not make the answer mainly about career or money.
- Do not overuse birth data. Use it only as quiet background when it sharpens the tarot answer.
- Be concrete, personal, and useful. Name the pattern, the opportunity, the risk, and the likely direction.

SECTION DEPTH:
- Write 4 to 5 complete sentences for PAST, PRESENT, and FUTURE.
- Each card section must be 85 to 120 words.
- Include one positive prospect, one honest challenge or caution, and one practical implication for the enquiry.
- Build a clear story from past to present to future, but keep each card distinct.
- The closing must be 25 to 45 words and must answer the enquiry in one firm statement.

VOICE AND FORMAT:
- Speak directly and warmly to the seeker by name when a name is available.
- Keep Bhrigu's voice wise, direct, mystical but grounded.
- Plain text only. No markdown, no asterisks, no bullet points in the answer.
- No headings inside JSON values.
- No question at the end.

SEEKER: ${birthData}
SEEKER_ENQUIRY: ${enquiryText}

PAST CARD: ${pastName}
Past card knowledge: ${pastKnowledge}

PRESENT CARD: ${presentName}
Present card knowledge: ${presentKnowledge}

FUTURE CARD: ${futureName}
Future card knowledge: ${futureKnowledge}
${languageInstruction(aiResponseLanguage)}
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
      if (aiResponseLanguage === "hinglish") {
        return `PAST - ${pastName}
Is card ka core signal yeh hai: ${cleanText(pastKnowledge)} Isse past energy ka pata chalta hai, lekin answer ko abhi simple rakhna better hai.

PRESENT - ${presentName}
Abhi present mein ${cleanText(presentKnowledge)} Yeh aapke sawaal ke around current mood aur choice ko dikhata hai.

FUTURE - ${futureName}
Aage ka signal ${cleanText(futureKnowledge)} Future fixed nahi hai, par direction yeh keh raha hai ki patience aur clear action zaruri hai.

Yeh teen cards ek movement dikhate hain: jo aapko shape kar chuka hai, jo abhi test kar raha hai, aur jo dheere dheere form ho raha hai.`;
      }
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
          `You are generating tarot reading content for an app. Return only valid JSON. Follow the user's tarot enquiry exactly. Every JSON value must answer the enquiry directly, stay in the enquiry's domain, and avoid generic card meanings. Do not include markdown, headings, labels, conclusion headings, or a question at the end.\n${languageInstruction(aiResponseLanguage)}`,
        prompt: `${prompt}

Return only valid JSON in this exact structure:
{
  "past": "85 to 120 words, 4 to 5 complete sentences for the past card. Directly answer SEEKER_ENQUIRY. Reuse key nouns from the enquiry, include the enquiry subject at least twice, one positive prospect, one honest challenge, and one practical implication.",
  "present": "85 to 120 words, 4 to 5 complete sentences for the present card. Directly answer SEEKER_ENQUIRY. Reuse key nouns from the enquiry, include the enquiry subject at least twice, one positive prospect, one honest challenge, and one practical implication.",
  "future": "85 to 120 words, 4 to 5 complete sentences for the future card. Directly answer SEEKER_ENQUIRY. Reuse key nouns from the enquiry, include the enquiry subject at least twice, one positive prospect, one honest challenge, and one practical implication.",
  "closing": "25 to 45 words. Give one firm final answer tying all three cards to SEEKER_ENQUIRY. No question."
}

Hard constraints:
- If any section could be reused for a different enquiry, rewrite it to be more specific.
- Keep the answer inside the user's enquiry domain.
- Do not write PAST, PRESENT, FUTURE, Conclusion, Final Message, Overall Reading, or Closing Insight inside the JSON values.
- Only write the actual reading content.`,
        maxTokens: TAROT_MAX_OUTPUT_TOKENS,
        temperature: TAROT_READING_TEMPERATURE,
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

        await recordUsageEvent(decodedToken.uid, {
          feature: "tarot_reading_fallback",
          provider: "local_fallback",
          model: "fallback",
          cached: false,
        });

        return {
          text: await ensureHinglishText({
            text: buildFallbackText(),
            aiResponseLanguage,
            preserveFormatInstruction:
              "Preserve PAST, PRESENT, FUTURE headings and all card names exactly.",
            maxTokens: TAROT_MAX_OUTPUT_TOKENS,
          }),
          aiResponseLanguage,
        };
      }

      const finalText = await ensureHinglishText({
        text: buildFinalText(parsed),
        aiResponseLanguage,
        preserveFormatInstruction:
          "Preserve PAST, PRESENT, FUTURE headings and all card names exactly.",
        maxTokens: TAROT_MAX_OUTPUT_TOKENS,
      });
      await writeCachedReading(
        decodedToken.uid,
        cacheKey,
        TAROT_READING_CONTENT_VERSION,
        finalText,
        aiResponseLanguage
      );

      await recordUsageEvent(decodedToken.uid, {
        feature: "tarot_reading",
        provider: "gemini",
        model: GEMINI_FLASH_LITE_MODEL,
        cached: false,
      });

      return {
        text: finalText,
        cached: false,
        aiResponseLanguage,
      };
    } catch (error) {
      console.error(
        "Tarot Gemini error:",
        error.response?.data || error.message
      );

      await recordUsageEvent(decodedToken.uid, {
        feature: "tarot_reading_fallback",
        provider: "local_fallback",
        model: "fallback",
        cached: false,
      });

      return {
        text: await ensureHinglishText({
          text: buildFallbackText(),
          aiResponseLanguage,
          preserveFormatInstruction:
            "Preserve PAST, PRESENT, FUTURE headings and all card names exactly.",
          maxTokens: TAROT_MAX_OUTPUT_TOKENS,
        }),
        fallback: true,
        timeout: isTimeoutError(error),
        aiResponseLanguage,
      };
    }
  }
);
