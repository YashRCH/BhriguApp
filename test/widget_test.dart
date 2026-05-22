import 'package:flutter_test/flutter_test.dart';
import 'package:astrology_guru_app/constants/app_messages.dart';
import 'package:astrology_guru_app/constants/chat_hints.dart';
import 'package:astrology_guru_app/constants/firebase_constants.dart';
import 'package:astrology_guru_app/models/birth_place_suggestion.dart';
import 'package:astrology_guru_app/models/payment_feature.dart';
import 'package:astrology_guru_app/models/streak_reward_model.dart';
import 'package:astrology_guru_app/constants/tarot_hints.dart';
import 'package:astrology_guru_app/models/geomancy_figure_model.dart';
import 'package:astrology_guru_app/models/geomancy_reading_flow.dart';
import 'package:astrology_guru_app/models/partner_match_flow.dart';
import 'package:astrology_guru_app/models/partner_match_model.dart';
import 'package:astrology_guru_app/models/tarot_card.dart';
import 'package:astrology_guru_app/models/tarot_reading_flow.dart';
import 'package:astrology_guru_app/models/user_model.dart';
import 'package:astrology_guru_app/services/cosmic_chart_calculator.dart';
import 'package:astrology_guru_app/services/horoscope_service.dart';
import 'package:astrology_guru_app/services/vedic_match_calculator.dart';
import 'package:astrology_guru_app/utils/date_keys.dart';
import 'package:astrology_guru_app/utils/similarity.dart';

void main() {
  test('chat hints remain separate, polished suggestions', () {
    expect(chatHints, hasLength(12));
    expect(chatHints, everyElement(isNot(isEmpty)));
    expect(chatHints, contains('What lesson is the universe teaching me?'));
    expect(chatHints, contains('Are they thinking about me?'));
    expect(chatHints, contains('Will I make money from this endeavor?'));
    expect(
      chatHints.any(
        (hint) =>
            hint.contains('What lesson is the universe teaching me?') &&
            hint.contains('Are they thinking about me?'),
      ),
      isFalse,
    );
  });

  test('tarot hints stay available for the question prompt', () {
    expect(tarotHints, hasLength(10));
    expect(tarotHints, everyElement(isNot(isEmpty)));
    expect(tarotHints, contains('What does my heart need to know?'));
    expect(tarotHints, contains('What guidance do the cards hold for me?'));
  });

  test('user model serializes onboarding data for Firestore', () {
    final user = UserModel(
      name: 'Bhrigu',
      dob: DateTime(2000, 1, 2),
      timeOfBirth: '08:30',
      placeOfBirth: 'Delhi',
      latitude: 28.6139,
      longitude: 77.2090,
    );

    final map = user.toMap();

    expect(map['name'], 'Bhrigu');
    expect(map['dob'], '2000-01-02T00:00:00.000');
    expect(map['timeOfBirth'], '08:30');
    expect(map['placeOfBirth'], 'Delhi');
    expect(map['latitude'], 28.6139);
    expect(map['longitude'], 77.2090);
    expect(map['createdAt'], isA<String>());
  });

  test('shared date keys are stable and zero padded', () {
    expect(formatDateKey(DateTime(2026, 5, 9)), '2026-05-09');
    expect(formatDateKey(DateTime(42, 1, 2)), '0042-01-02');
  });

  test('cosine similarity handles normal and invalid vectors', () {
    expect(cosineSimilarity([1, 0], [1, 0]), 1);
    expect(cosineSimilarity([1, 0], [0, 1]), 0);
    expect(cosineSimilarity([], [1, 0]), 0);
    expect(cosineSimilarity([1], [1, 0]), 0);
  });

  test('moon phase calculation is stable around known lunations', () {
    final service = HoroscopeService();

    final newMoon = service.getMoonPhaseInfo(
      date: DateTime.utc(2000, 1, 6, 18, 14),
    );
    expect(newMoon.name, 'New Moon');
    expect(newMoon.moonAge, closeTo(0, 0.0001));
    expect(newMoon.illumination, closeTo(0, 0.0001));

    final fullMoon = service.getMoonPhaseInfo(
      date: DateTime.utc(2000, 1, 21, 12),
    );
    expect(fullMoon.name, 'Full Moon');
    expect(fullMoon.illumination, greaterThan(0.98));
  });

  test('daily planetary energy follows traditional weekday rulers', () {
    final service = HoroscopeService();

    expect(
      service.getDailyEnergyInfo(date: DateTime(2026, 5, 18)).planet,
      'Moon',
    );
    expect(
      service.getDailyEnergyInfo(date: DateTime(2026, 5, 19)).planet,
      'Mars',
    );
    expect(
      service.getDailyEnergyInfo(date: DateTime(2026, 5, 20)).planet,
      'Mercury',
    );
    expect(
      service.getDailyEnergyInfo(date: DateTime(2026, 5, 24)).planet,
      'Sun',
    );
  });

  test('daily card one-liners follow moon phase and planetary ruler', () {
    final service = HoroscopeService();
    final moonLine = service.getMoonPhaseOneLiner(
      date: DateTime.utc(2000, 1, 6, 18, 14),
    );
    final energyLine = service.getDailyEnergyOneLiner(
      date: DateTime.utc(2000, 1, 6, 18, 14),
    );

    expect(moonLine, contains('intention'));
    expect(energyLine, contains('Expand'));
  });

  test('shared app messages keep fallback copy consistent', () {
    expect(
      cosmicConnectionLostMessage,
      'The cosmic connection was lost. Please try again.',
    );
    expect(missingFirebaseIdTokenMessage, 'Missing Firebase ID token');
  });

  test('Firebase Functions region stays centralized', () {
    expect(firebaseFunctionsRegion, 'us-central1');
  });

  test('streak reward state exposes payment-ready reward routing', () {
    const empty = StreakRewardState.empty();
    expect(empty.roadProgress, 0);
    expect(empty.rewardRoute, '/tarot');

    const pendingGeomancy = StreakRewardState(
      rewardCycleDay: 0,
      freeRewardAvailable: true,
      freeRewardType: geomancyRewardType,
      lastClaimDate: '2026-05-19',
    );

    expect(pendingGeomancy.roadProgress, 1);
    expect(pendingGeomancy.rewardRoute, '/geomancy');
    expect(pendingGeomancy.isClaimedOn(DateTime(2026, 5, 19)), isTrue);
  });

  test('payment feature ids remain stable for checkout providers', () {
    expect(PaymentFeature.tarotReading.productId, 'bhrigu.tarot.reading');
    expect(PaymentFeature.tarotReading.entitlementId, 'tarot_reading');
    expect(PaymentFeature.geomancyReading.productId, 'bhrigu.geomancy.reading');
    expect(PaymentFeature.partnerMatch.entitlementId, 'partner_match');
    expect(PaymentFeature.bhriguChat.productId, 'bhrigu.chat.session');
  });

  test('tarot reading flow tracks reveal and payment-ready states', () {
    final cards = [
      majorArcana[0],
      majorArcana[1],
      majorArcana[2],
    ];

    var flow = TarotReadingFlow.drawn(cards);

    expect(flow.paymentFeature, PaymentFeature.tarotReading);
    expect(flow.hasCards, isTrue);
    expect(flow.canShare, isFalse);
    expect(flow.allRevealed, isFalse);

    flow = flow.reveal(0).reveal(1).reveal(2);
    expect(flow.allRevealed, isTrue);

    flow = flow.beginReading();
    expect(flow.readingStarted, isTrue);
    expect(flow.readingLoading, isTrue);

    flow = flow.completeReading('A clear answer.');
    expect(flow.readingLoading, isFalse);
    expect(flow.isFreshReading, isTrue);
    expect(flow.canShare, isTrue);
    expect(flow.canFollowUp, isTrue);
    expect(flow.canReset, isTrue);
  });

  test('geomancy reading flow tracks reveal and follow-up payload state', () {
    const figure = GeomancyFigureModel(
      name: 'Via',
      latinName: 'The Way',
      pattern: [1, 1, 1, 1],
      element: 'Water',
      planet: 'Moon',
      answerType: 'Moving',
      meaning: 'The path is open.',
    );

    const chart = GeomancyChartModel(
      mothers: [figure, figure, figure, figure],
      daughters: [figure, figure, figure, figure],
      nieces: [figure, figure, figure, figure],
      leftWitness: figure,
      rightWitness: figure,
      judge: figure,
      reconciler: figure,
    );

    const reading = GeomancyReadingModel(
      question: 'What now?',
      chart: chart,
      answer: 'The path is still moving',
      interpretation: 'Move with patience.',
    );

    var flow = GeomancyReadingFlow.initial();
    expect(flow.paymentFeature, PaymentFeature.geomancyReading);
    expect(flow.readyToReveal, isFalse);

    flow = flow.beginReading();
    expect(flow.isReadingLoading, isTrue);

    flow = flow.completeReading(
      reading: reading,
      lineValues: const [1, 2, 1, 2],
    );

    expect(flow.readyToReveal, isTrue);
    expect(flow.canFollowUp, isFalse);

    flow = flow.reveal();
    expect(flow.canShowResult, isTrue);
    expect(flow.canFollowUp, isTrue);

    final sourceData = flow.followUpSourceData(const []);
    expect(sourceData['answer'], 'The path is still moving');
    expect(sourceData['lineValues'], [1, 2, 1, 2]);
    expect((sourceData['judge'] as Map<String, dynamic>)['name'], 'Via');
  });

  test('partner match flow tracks payment feature and follow-up payload', () {
    final reading = PartnerMatchReading(
      user: PartnerBirthProfile(
        name: 'Asha',
        dob: DateTime(1998, 1, 2),
        timeOfBirth: '06:30',
        placeOfBirth: 'Delhi',
        latitude: 28.6139,
        longitude: 77.2090,
        emotionalPrompt: '',
      ),
      partner: PartnerBirthProfile(
        name: 'Ravi',
        dob: DateTime(1997, 3, 4),
        timeOfBirth: '18:45',
        placeOfBirth: 'Mumbai',
        latitude: 19.0760,
        longitude: 72.8777,
        emotionalPrompt: 'There is warmth and confusion.',
      ),
      scores: const CompatibilityScores(
        overall: 82,
        emotional: 80,
        attraction: 85,
        communication: 76,
        stability: 78,
        karmic: 88,
      ),
      marriageGunaMatch: const MarriageGunaMatch(
        totalScore: 24,
        maxScore: 36,
        level: 'Supportive',
        summary: 'A workable match.',
        items: [
          GunaScoreItem(
            name: 'Gana',
            score: 4,
            maxScore: 6,
            meaning: 'Temperament blends with effort.',
          ),
        ],
      ),
      userSunSign: 'Capricorn',
      partnerSunSign: 'Pisces',
      userMoonStyle: 'Grounded',
      partnerMoonStyle: 'Sensitive',
      connectionType: 'Karmic warmth',
      verdict: 'Promising with patience',
      summary: 'This match has warmth and lessons.',
      createdAt: DateTime(2026, 5, 19),
    );

    var flow = PartnerMatchFlow.initial();
    expect(flow.paymentFeature, PaymentFeature.partnerMatch);
    expect(flow.canFollowUp, isFalse);

    flow = flow.beginReading();
    expect(flow.loading, isTrue);

    flow = flow.completeReading(reading);
    expect(flow.loading, isFalse);
    expect(flow.canFollowUp, isTrue);

    final sourceData = flow.followUpSourceData();
    final user = sourceData['user'] as Map<String, dynamic>;
    final partner = sourceData['partner'] as Map<String, dynamic>;
    expect(user['name'], 'Asha');
    expect(user['latitude'], 28.6139);
    expect(user['longitude'], 77.2090);
    expect(partner['name'], 'Ravi');
    expect(partner['latitude'], 19.0760);
    expect(partner['longitude'], 72.8777);
    expect((sourceData['scores'] as Map<String, dynamic>)['overall'], 82);
    expect(sourceData['freshReadingOnly'], isTrue);
  });

  test('partner birth profile preserves coordinates across json', () {
    final profile = PartnerBirthProfile.fromJson({
      'name': 'Meera',
      'dob': '1999-07-08T00:00:00.000',
      'timeOfBirth': '04:15',
      'placeOfBirth': 'Bengaluru',
      'latitude': '12.9716',
      'longitude': 77.5946,
      'emotionalPrompt': 'A steady bond.',
    });

    expect(profile.latitude, 12.9716);
    expect(profile.longitude, 77.5946);

    final json = profile.toJson();
    expect(json['latitude'], 12.9716);
    expect(json['longitude'], 77.5946);
  });

  test('birth place suggestion accepts geocoded and legacy results', () {
    final geocoded = BirthPlaceSuggestion.fromMap({
      'description': 'Delhi, India',
      'latitude': 28.6139,
      'longitude': '77.2090',
    });

    expect(geocoded.description, 'Delhi, India');
    expect(geocoded.latitude, 28.6139);
    expect(geocoded.longitude, 77.2090);

    final legacy = BirthPlaceSuggestion.fromMap({
      'description': 'Typed place',
    });

    expect(legacy.description, 'Typed place');
    expect(legacy.latitude, isNull);
    expect(legacy.longitude, isNull);
  });

  test('vedic match calculator uses birth coordinates in signatures', () {
    const calculator = VedicMatchCalculator();
    final delhiSignature = calculator.signature(
      PartnerBirthProfile(
        name: 'Asha',
        dob: DateTime(1998, 1, 2),
        timeOfBirth: '06:30',
        placeOfBirth: 'Delhi',
        latitude: 28.6139,
        longitude: 77.2090,
        emotionalPrompt: '',
      ),
    );
    final losAngelesSignature = calculator.signature(
      PartnerBirthProfile(
        name: 'Asha',
        dob: DateTime(1998, 1, 2),
        timeOfBirth: '06:30',
        placeOfBirth: 'Los Angeles',
        latitude: 34.0522,
        longitude: -118.2437,
        emotionalPrompt: '',
      ),
    );

    expect(delhiSignature.moonSign, inInclusiveRange(0, 11));
    expect(delhiSignature.nakshatra, inInclusiveRange(0, 26));
    expect(
      delhiSignature.ascendantSign,
      isNot(losAngelesSignature.ascendantSign),
    );
  });

  test('vedic guna match keeps traditional eight-part score shape', () {
    const calculator = VedicMatchCalculator();
    final match = calculator.calculateMarriageGunaMatch(
      PartnerBirthProfile(
        name: 'Asha',
        dob: DateTime(1998, 1, 2),
        timeOfBirth: '06:30',
        placeOfBirth: 'Delhi',
        latitude: 28.6139,
        longitude: 77.2090,
        emotionalPrompt: '',
      ),
      PartnerBirthProfile(
        name: 'Ravi',
        dob: DateTime(1997, 3, 4),
        timeOfBirth: '18:45',
        placeOfBirth: 'Mumbai',
        latitude: 19.0760,
        longitude: 72.8777,
        emotionalPrompt: '',
      ),
    );

    expect(
      match.items.map((item) => item.name),
      [
        'Varna',
        'Vashya',
        'Tara',
        'Yoni',
        'Graha Maitri',
        'Gana',
        'Bhakoot',
        'Nadi',
      ],
    );
    expect(match.items.map((item) => item.maxScore), [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(
      match.totalScore,
      match.items.fold<int>(0, (total, item) => total + item.score),
    );
    expect(match.totalScore, inInclusiveRange(0, 36));
  });

  test('partner match math is deterministic for identical birth inputs', () {
    const calculator = VedicMatchCalculator();
    final user = PartnerBirthProfile(
      name: 'Asha',
      dob: DateTime(1998, 1, 2),
      timeOfBirth: '06:30',
      placeOfBirth: 'Delhi',
      latitude: 28.6139,
      longitude: 77.2090,
      emotionalPrompt: '',
    );
    final partner = PartnerBirthProfile(
      name: 'Ravi',
      dob: DateTime(1997, 3, 4),
      timeOfBirth: '18:45',
      placeOfBirth: 'Mumbai',
      latitude: 19.0760,
      longitude: 72.8777,
      emotionalPrompt: 'There is warmth and confusion.',
    );

    final firstBase = calculator.calculateBaseScores(user, partner);
    final secondBase = calculator.calculateBaseScores(user, partner);
    final firstGuna = calculator.calculateMarriageGunaMatch(user, partner);
    final secondGuna = calculator.calculateMarriageGunaMatch(user, partner);
    final firstFinal = calculator.applyMarriageScoreToOverall(
      firstBase,
      firstGuna,
    );
    final secondFinal = calculator.applyMarriageScoreToOverall(
      secondBase,
      secondGuna,
    );

    expect(firstBase.toJson(), secondBase.toJson());
    expect(firstGuna.toJson(), secondGuna.toJson());
    expect(firstFinal.toJson(), secondFinal.toJson());
  });

  test('cosmic chart calculator builds deterministic ephemeris charts', () {
    const calculator = CosmicChartCalculator();
    final charts = calculator.calculate(
      birthDate: DateTime(1998, 1, 2),
      timeOfBirth: '06:30',
      placeOfBirth: 'Delhi',
      latitude: 28.6139,
      longitude: 77.2090,
    );

    expect(charts.westernChart.planets, hasLength(7));
    expect(charts.vedicChart.planets, hasLength(7));
    expect(charts.westernChart.sunSign, 'Capricorn');
    expect(charts.vedicChart.nakshatra, isNotEmpty);
    expect(
      charts.westernChart.planets.every(
        (planet) => planet.degree >= 0 && planet.degree < 30,
      ),
      isTrue,
    );
    expect(
      charts.vedicChart.planets.every(
        (planet) => planet.house >= 1 && planet.house <= 12,
      ),
      isTrue,
    );

    final repeatedCharts = calculator.calculate(
      birthDate: DateTime(1998, 1, 2),
      timeOfBirth: '06:30',
      placeOfBirth: 'Delhi',
      latitude: 28.6139,
      longitude: 77.2090,
    );

    expect(charts.westernChart.toJson(), repeatedCharts.westernChart.toJson());
    expect(charts.vedicChart.toJson(), repeatedCharts.vedicChart.toJson());
  });

  test('cosmic chart houses respond to birth location coordinates', () {
    const calculator = CosmicChartCalculator();
    final delhi = calculator.calculate(
      birthDate: DateTime(1998, 1, 2),
      timeOfBirth: '06:30',
      placeOfBirth: 'Delhi',
      latitude: 28.6139,
      longitude: 77.2090,
    );
    final losAngeles = calculator.calculate(
      birthDate: DateTime(1998, 1, 2),
      timeOfBirth: '06:30',
      placeOfBirth: 'Los Angeles',
      latitude: 34.0522,
      longitude: -118.2437,
    );

    expect(delhi.westernChart.risingSign,
        isNot(losAngeles.westernChart.risingSign));
    expect(delhi.vedicChart.ascendant, isNot(losAngeles.vedicChart.ascendant));
  });
}
