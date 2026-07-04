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
exports.generateTarotEmbedding = onCall(
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
      "Tarot embedding generation is server-side only."
    );
  }
);

exports.generateTarotReading = onCall(
  callableRuntimeOptions({
    secrets: [GEMINI_API_KEY, REVENUECAT_SECRET_API_KEY],
    region: FUNCTION_REGION,
    timeoutSeconds: 120,
    memory: "1GiB",
  }),
  async (request) => {
    const data = requireRequestData(request, { maxBytes: 70000 });
    const auth = requireCallableAuth(request);
    const decodedToken = { uid: auth.uid };

    const birthData = boundedString(data.birthData, {
      field: "Birth data",
      max: 2500,
      fallback: "Birth data not available.",
    });
    const aiResponseLanguage = await resolveAiResponseLanguage(
      decodedToken.uid,
      data.aiResponseLanguage
    );
    const question = boundedString(data.question, {
      field: "Question",
      max: 1000,
      trim: true,
    });
    const enquiryText =
      question.length === 0
        ? "General tarot guidance. No specific enquiry was provided."
        : question;
    const pastName = boundedString(data.pastName, { field: "Past card", max: 80 });
    const presentName = boundedString(data.presentName, { field: "Present card", max: 80 });
    const futureName = boundedString(data.futureName, { field: "Future card", max: 80 });
    const pastKnowledgeFallback = boundedString(data.pastKnowledge, {
      field: "Past knowledge",
      max: 5000,
    });
    const presentKnowledgeFallback = boundedString(data.presentKnowledge, {
      field: "Present knowledge",
      max: 5000,
    });
    const futureKnowledgeFallback = boundedString(data.futureKnowledge, {
      field: "Future knowledge",
      max: 5000,
    });
    const pastKeywords = boundedString(data.pastKeywords, {
      field: "Past keywords",
      max: 500,
    });
    const presentKeywords = boundedString(data.presentKeywords, {
      field: "Present keywords",
      max: 500,
    });
    const futureKeywords = boundedString(data.futureKeywords, {
      field: "Future keywords",
      max: 500,
    });
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

    const meteringCharge = await requireMeteredFeature(decodedToken.uid, "tarot");
    let cachedText;

    try {
      cachedText = await readCachedReading(
        decodedToken.uid,
        cacheKey,
        TAROT_READING_CONTENT_VERSION,
        aiResponseLanguage
      );
    } catch (error) {
      try {
        await refundMeteredFeatureCharge(decodedToken.uid, meteringCharge);
      } catch (refundError) {
        console.error("Tarot cache metering refund failed:", refundError);
      }

      throw error;
    }

    if (cachedText) {
      try {
        const safeCachedText = await ensureHinglishText({
          text: cachedText,
          aiResponseLanguage,
          preserveFormatInstruction:
            "Preserve PAST, PRESENT, FUTURE headings and all card names exactly.",
          enquiryContext: `The user's original enquiry was: "${enquiryText}". CRITICAL: You must preserve every specific reference, noun, and detail related to this enquiry from the original text.`,
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
      } catch (error) {
        try {
          await refundMeteredFeatureCharge(decodedToken.uid, meteringCharge);
        } catch (refundError) {
          console.error("Tarot cached-reading metering refund failed:", refundError);
        }

        throw error;
      }
    }

    let pastKnowledge;
    let presentKnowledge;
    let futureKnowledge;

    try {
      [pastKnowledge, presentKnowledge, futureKnowledge] = await Promise.all([
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
    } catch (error) {
      console.error(
        "Tarot knowledge retrieval error:",
        error.response?.data || error.message
      );

      try {
        await refundMeteredFeatureCharge(decodedToken.uid, meteringCharge);
      } catch (refundError) {
        console.error("Tarot metering refund failed:", refundError);
      }

      throw new HttpsError(
        "internal",
        "Tarot reading generation failed."
      );
    }

    const prompt = `
You are Bhrigu, a Vedic sage and experienced tarot reader inside the BHR1GU app.

CORE TASK:
Answer the SEEKER_ENQUIRY through the three drawn tarot cards.
The enquiry is the anchor. Every section must directly interpret its card in relation to that exact enquiry.
If the enquiry names love, career, money, health, family, timing, choice, or spiritual direction, stay inside that domain unless a card clearly adds a necessary connected warning.
If the enquiry is empty or generic, give a general reading, but do not invent unrelated dramatic scenarios.

HOW TO READ:
- You are not explaining cards. You are looking through them. Write as a seer who perceives the seeker's situation: "I see...", "the cards show me...", "there is an energy around you that...".
- Begin from the seeker's energy: somewhere in the reading, name one true-feeling thing you perceive about who they are or what they carry (their patience, their instinct, how much they give, what they have quietly survived). Deliver it as something the cards revealed to you, never as a compliment. It must feel discovered, not given.
- Each card section is built around one vivid, picturable image tied to this exact enquiry - a place, gesture, object, or moment the seeker can see in their mind - never a textbook card meaning that could fit any question.
- The FUTURE card must make a real prediction: a committed outcome with a soft timeframe ("before this season turns", "within a few weeks", "sooner than you think") and one distinctive detail. Do not hedge it into meaninglessness.
- Let each card say what it actually says. One may be pure encouragement, one a quiet warning, one a foreseen event. Never force the same internal shape onto all three sections, and never balance every hope with a caution out of habit.
- When a card carries a hard truth, tell it - but frame it as a test this seeker in particular has the strength to pass, because of the quality you perceived in their energy.
- Always leave the seeker with hope. Point to the direction and the opening, never hand over a complete step-by-step solution; the future should feel promising and still unfolding.
- STRICT: every section is about the enquiry, start to finish. The image you build, the energy you describe, and the prediction you make must all exist to answer SEEKER_ENQUIRY - a sentence that would survive unchanged under a different question does not belong. Reference the enquiry's subject naturally in each section, but vary the wording; do not repeat the same enquiry phrase in more than two sections.
- Do not switch domains. For example, if the enquiry is about love, do not make the answer mainly about career or money.
- Do not overuse birth data. Use it only as quiet background when it sharpens the tarot answer.

VOICE:
- STRICT: speak normally, like a real human in 2026 - the register of an average American girl in her twenties: casual, warm, direct, contractions everywhere. No performance, no forced or overused slang, no theatrical mysticism.
- Speak directly to the seeker by name when a name is available.
- STRICT: no stock tarot filler. Words like "journey", "embrace", "align", "manifest", "crossroads", "chapter", "the universe has a plan" may appear at most once in the whole reading; prefer a fresh synonym or a plainer phrase every time, so two readings for the same user never sound alike.
- Vary sentence rhythm. No two sections may open with the same sentence pattern.

SHAPE:
- Each card section is 60 to 130 words, 3 to 6 sentences. Sections do not need to be the same length; let them breathe.
- Build a clear story from past to present to future, but keep each card distinct.
- Plant exactly one deliberately unresolved thread inside the past, present, or future section, written as an intriguing statement and never as a question, so the seeker is left wanting to ask a follow-up. Keep the closing a firm final answer.
- The closing is the verdict: 25 to 45 words, one firm hopeful answer to the enquiry, spoken with certainty.
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

    function parseTarotJsonText(rawText) {
      const source = String(rawText || "").trim();
      const jsonStart = source.indexOf("{");
      const jsonEnd = source.lastIndexOf("}");

      if (jsonStart === -1 || jsonEnd === -1) {
        throw new Error("No JSON object found");
      }

      const parsed = JSON.parse(source.substring(jsonStart, jsonEnd + 1));
      const requiredKeys = ["past", "present", "future", "closing"];

      for (const key of requiredKeys) {
        if (typeof parsed[key] !== "string" || parsed[key].trim().length === 0) {
          throw new Error(`Missing tarot JSON field: ${key}`);
        }
      }

      return parsed;
    }

    async function repairTarotJson(rawText) {
      const repairText = await generateGeminiReadingText({
        systemInstruction:
          `You convert tarot reading drafts into strict JSON for an app. Preserve the user's enquiry, assigned card names, card positions, specific advice, and retrieved tarot knowledge. If the draft answers only the enquiry without using cards and positions, rebuild it from the retrieved tarot knowledge below. Return only valid JSON with keys past, present, future, and closing. Do not add markdown, headings, labels, or questions.\n${languageInstruction(aiResponseLanguage)}`,
        prompt: `
SEEKER_ENQUIRY:
${enquiryText}

PAST CARD:
${pastName}

PRESENT CARD:
${presentName}

FUTURE CARD:
${futureName}

Retrieved tarot knowledge:
PAST: ${pastKnowledge}
PRESENT: ${presentKnowledge}
FUTURE: ${futureKnowledge}

Required simple formula:
PAST = SEEKER_ENQUIRY + past-tense meaning of ${pastName} + PAST retrieved tarot knowledge.
PRESENT = SEEKER_ENQUIRY + present-tense meaning of ${presentName} + PRESENT retrieved tarot knowledge.
FUTURE = SEEKER_ENQUIRY + future-facing meaning of ${futureName} + FUTURE retrieved tarot knowledge.

Rules:
- Name the assigned card once in each section.
- Do not answer SEEKER_ENQUIRY by itself.
- Do not mix card positions.
- Keep language simple, casual, and modern - plain spoken English, no stock tarot filler.

Draft to preserve and structure:
${String(rawText || "").slice(0, 8000)}

Return only valid JSON in this exact structure:
{
  "past": "60 to 130 words, 3 to 6 sentences. Use past tense. Name ${pastName} once. Use PAST retrieved tarot knowledge to describe what you see shaped SEEKER_ENQUIRY.",
  "present": "60 to 130 words, 3 to 6 sentences. Use present tense. Name ${presentName} once. Use PRESENT retrieved tarot knowledge to describe the energy around SEEKER_ENQUIRY right now.",
  "future": "60 to 130 words, 3 to 6 sentences. Use future-facing language. Name ${futureName} once. Use FUTURE retrieved tarot knowledge to make a hopeful committed prediction for SEEKER_ENQUIRY with a soft timeframe.",
  "closing": "25 to 45 words. Give one firm hopeful final answer tying all three cards to SEEKER_ENQUIRY. No question."
}`,
        maxTokens: TAROT_MAX_OUTPUT_TOKENS,
        temperature: 0.2,
        model: GEMINI_FLASH_LITE_MODEL,
        responseMimeType: "application/json",
      });

      return parseTarotJsonText(repairText);
    }

    try {
      const rawText = await generateGeminiReadingText({
        systemInstruction:
          `You are generating tarot reading content for an app. Return only valid JSON. Follow the user's tarot enquiry exactly. Every JSON value must answer the enquiry directly, stay in the enquiry's domain, and avoid generic card meanings. Do not include markdown, headings, labels, conclusion headings, or a question at the end.\n${languageInstruction(aiResponseLanguage)}`,
        prompt: `${prompt}

Return only valid JSON in this exact structure:
{
  "past": "60 to 130 words, 3 to 6 sentences for the past card. Speak as a seer answering SEEKER_ENQUIRY: what you see that shaped this situation, built around one vivid picturable image. Casual, warm, modern spoken English.",
  "present": "60 to 130 words, 3 to 6 sentences for the present card. Speak as a seer answering SEEKER_ENQUIRY: the energy around the seeker right now, built around one vivid picturable image. Do not mirror the shape of the past section.",
  "future": "60 to 130 words, 3 to 6 sentences for the future card. Make a real prediction for SEEKER_ENQUIRY: a committed outcome, a soft timeframe, one distinctive detail, and hope. Never a hedged answer that fits anyone.",
  "closing": "25 to 45 words. Give one firm hopeful final answer tying all three cards to SEEKER_ENQUIRY. No question."
}

Hard constraints:
- If any section could be reused for a different enquiry, rewrite it to be more specific.
- Keep the answer inside the user's enquiry domain.
- Do not write PAST, PRESENT, FUTURE, Conclusion, Final Message, Overall Reading, or Closing Insight inside the JSON values.
- Plain modern spoken English, no stock tarot filler words, no repeated sentence openers across sections.
- Only write the actual reading content.`,
        maxTokens: TAROT_MAX_OUTPUT_TOKENS,
        temperature: TAROT_READING_TEMPERATURE,
        model: GEMINI_FLASH_LITE_MODEL,
        responseMimeType: "application/json",
      });

      let parsed;

      try {
        parsed = parseTarotJsonText(rawText);
      } catch (parseError) {
        console.warn("Tarot JSON parse error, attempting repair:", parseError);

        try {
          parsed = await repairTarotJson(rawText);

          await recordUsageEvent(decodedToken.uid, {
            feature: "tarot_reading_json_repair",
            provider: "gemini",
            model: GEMINI_FLASH_LITE_MODEL,
            cached: false,
          });
        } catch (repairError) {
          console.error("Tarot JSON repair error:", repairError);

          throw repairError;
        }
      }

      const finalText = await ensureHinglishText({
        text: buildFinalText(parsed),
        aiResponseLanguage,
        preserveFormatInstruction:
          "Preserve PAST, PRESENT, FUTURE headings and all card names exactly.",
        enquiryContext: `The user's original enquiry was: "${enquiryText}". CRITICAL: You must preserve every specific reference, noun, and detail related to this enquiry from the original text.`,
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
      const aiError = error.response?.data || error.responseData || {};
      const aiDetails = {
        status: error.response?.status || null,
        code: aiError.error?.code || aiError.code || null,
        type: aiError.error?.type || aiError.type || null,
        message: aiError.error?.message || aiError.message || error.message,
        finishReasons: error.finishReasons || null,
        candidateCount: error.candidateCount || null,
        usage: {
          totalTokens: 0,
          model: GEMINI_FLASH_LITE_MODEL,
          provider: "gemini",
        },
      };

      console.error("Tarot Gemini error:", aiDetails);

      try {
        await refundMeteredFeatureCharge(decodedToken.uid, meteringCharge);
      } catch (refundError) {
        console.error("Tarot metering refund failed:", refundError);
      }

      await recordUsageEvent(decodedToken.uid, {
        feature: "tarot_reading_failed",
        provider: "gemini",
        model: GEMINI_FLASH_LITE_MODEL,
        cached: false,
      });

      throw new HttpsError(
        isTimeoutError(error) ? "deadline-exceeded" : "internal",
        "Tarot reading generation failed. Please try again.",
        aiDetails
      );
    }
  }
);
