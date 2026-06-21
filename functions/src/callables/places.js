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
exports.searchBirthPlaces = onCall(
  callableRuntimeOptions({
    region: FUNCTION_REGION,
    secrets: [GOOGLE_PLACES_API_KEY],
  }),
  async (request) => {
    try {
      const data = requireRequestData(request, { maxBytes: 4000 });
      const auth = requireCallableAuth(request);
      const query = boundedString(data.query, {
        field: "Search query",
        max: 120,
        trim: true,
      });

      if (query.length < 2) {
        return {
          places: [],
          placeDetails: [],
        };
      }

      const response = await fetch(
        "https://places.googleapis.com/v1/places:autocomplete",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY.value(),
            "X-Goog-FieldMask":
              "suggestions.placePrediction.placeId,suggestions.placePrediction.text.text,suggestions.placePrediction.structuredFormat.mainText.text,suggestions.placePrediction.structuredFormat.secondaryText.text",
          },
          body: JSON.stringify({
            input: query,
            includeQueryPredictions: false,
            languageCode: "en",
          }),
          signal: AbortSignal.timeout(PLACES_REQUEST_TIMEOUT_MS),
        }
      );

      const responseText = await response.text();

      if (!response.ok) {
        console.error(
          "Google Places error:",
          response.status,
          responseText
        );

        throw new HttpsError(
          "internal",
          `Google Places failed with status ${response.status}.`
        );
      }

      const json = JSON.parse(responseText);

      const suggestions = Array.isArray(json.suggestions)
        ? json.suggestions
        : [];

      const placePredictions = suggestions
        .map((suggestion) => {
          const prediction = suggestion.placePrediction || {};
          const structuredFormat = prediction.structuredFormat || {};
          const placeId = prediction.placeId || "";
          const mainText = structuredFormat.mainText?.text || "";
          const secondaryText = structuredFormat.secondaryText?.text || "";
          const fallbackText = prediction.text?.text || "";

          let description = "";

          if (mainText && secondaryText) {
            description = `${mainText}, ${secondaryText}`;
          } else if (fallbackText) {
            description = fallbackText;
          } else if (mainText) {
            description = mainText;
          }

          return {
            placeId,
            description,
          };
        })
        .filter((place) => place.description.trim().length > 0)
        .filter(
          (place, index, array) =>
            array.findIndex(
              (item) => item.description === place.description
            ) === index
        )
        .slice(0, 8);

      const placeDetails = await Promise.all(
        placePredictions.map(async (place) => {
          if (!place.placeId) {
            return {
              description: place.description,
              latitude: null,
              longitude: null,
            };
          }

          // 1. Check Firestore Cache
          const cacheRef = admin.firestore().collection("googlePlacesCache").doc(place.placeId);
          try {
            const cacheDoc = await cacheRef.get();
            if (cacheDoc.exists) {
              const cachedData = cacheDoc.data() || {};
              return {
                description: place.description,
                latitude: typeof cachedData.latitude === "number" ? cachedData.latitude : null,
                longitude: typeof cachedData.longitude === "number" ? cachedData.longitude : null,
              };
            }
          } catch (cacheErr) {
            console.warn("Places cache read error:", cacheErr.message);
          }

          // 2. Fetch from Google API
          try {
            const detailResponse = await fetch(
              `https://places.googleapis.com/v1/places/${place.placeId}`,
              {
                method: "GET",
                headers: {
                  "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY.value(),
                  "X-Goog-FieldMask": "location",
                },
                signal: AbortSignal.timeout(PLACES_REQUEST_TIMEOUT_MS),
              }
            );

            if (!detailResponse.ok) {
              return {
                description: place.description,
                latitude: null,
                longitude: null,
              };
            }

            const detailJson = await detailResponse.json();
            const location = detailJson.location || {};
            const lat = typeof location.latitude === "number" ? location.latitude : null;
            const lng = typeof location.longitude === "number" ? location.longitude : null;

            // 3. Cache the result in Firestore
            if (lat !== null && lng !== null) {
              try {
                await cacheRef.set({
                  latitude: lat,
                  longitude: lng,
                  description: place.description,
                  cachedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
              } catch (cacheWriteErr) {
                console.warn("Places cache write error:", cacheWriteErr.message);
              }
            }

            return {
              description: place.description,
              latitude: lat,
              longitude: lng,
            };
          } catch (detailError) {
            console.error("Google Place detail error:", detailError);
            return {
              description: place.description,
              latitude: null,
              longitude: null,
            };
          }
        })
      );

      await recordUsageEvent(auth.uid, {
        feature: "birth_place_search",
        provider: "google_places",
        model: "places_autocomplete",
        cached: false,
      });

      return {
        places: placeDetails.map((place) => place.description),
        placeDetails,
      };
    } catch (error) {
      console.error("searchBirthPlaces error:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "Could not search birth places right now."
      );
    }
  }
);
