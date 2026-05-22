import 'dart:math';

import '../models/partner_match_model.dart';

class VedicBirthSignature {
  final int siderealSunSign;
  final int moonSign;
  final int ascendantSign;
  final int mercurySign;
  final int venusSign;
  final int marsSign;
  final int saturnSign;
  final int rahuSign;
  final int nakshatra;

  const VedicBirthSignature({
    required this.siderealSunSign,
    required this.moonSign,
    required this.ascendantSign,
    required this.mercurySign,
    required this.venusSign,
    required this.marsSign,
    required this.saturnSign,
    required this.rahuSign,
    required this.nakshatra,
  });
}

class VedicMatchCalculator {
  const VedicMatchCalculator();

  VedicBirthSignature signature(PartnerBirthProfile profile) {
    final utcBirth = _estimatedUtcBirth(profile);
    final days = _daysSinceJ2000(utcBirth);
    final ayanamsa = _lahiriAyanamsa(days);
    final siderealSun = _siderealSunLongitude(days, ayanamsa);
    final siderealMoon = _siderealMoonLongitude(days, ayanamsa);
    final place = _coordinatesFor(profile);
    final localSolarMinutes = _localSolarMinutes(
      profile.timeOfBirth,
      place?.longitude,
    );

    return VedicBirthSignature(
      siderealSunSign: _signFromLongitude(siderealSun),
      moonSign: _signFromLongitude(siderealMoon),
      ascendantSign: _ascendantSign(
        siderealSun,
        localSolarMinutes,
        place?.latitude,
      ),
      mercurySign: _meanPlanetSign(252.25084, 4.09233445, days, ayanamsa),
      venusSign: _meanPlanetSign(181.97973, 1.60213034, days, ayanamsa),
      marsSign: _meanPlanetSign(355.433, 0.5240207766, days, ayanamsa),
      saturnSign: _meanPlanetSign(50.077, 0.03345965, days, ayanamsa),
      rahuSign: _meanPlanetSign(125.04452, -0.05295377, days, ayanamsa),
      nakshatra: (siderealMoon / (360 / 27)).floor().clamp(0, 26).toInt(),
    );
  }

  MarriageGunaMatch calculateMarriageGunaMatch(
    PartnerBirthProfile user,
    PartnerBirthProfile partner,
  ) {
    final userSignature = signature(user);
    final partnerSignature = signature(partner);

    final items = <GunaScoreItem>[
      _varnaGuna(userSignature.moonSign, partnerSignature.moonSign),
      _vashyaGuna(userSignature.moonSign, partnerSignature.moonSign),
      _taraGuna(userSignature.nakshatra, partnerSignature.nakshatra),
      _yoniGuna(userSignature.nakshatra, partnerSignature.nakshatra),
      _grahaMaitriGuna(userSignature.moonSign, partnerSignature.moonSign),
      _ganaGuna(userSignature.nakshatra, partnerSignature.nakshatra),
      _bhakootGuna(userSignature.moonSign, partnerSignature.moonSign),
      _nadiGuna(userSignature.nakshatra, partnerSignature.nakshatra),
    ];

    final total = items.fold<int>(
      0,
      (currentTotal, item) => currentTotal + item.score,
    );

    return MarriageGunaMatch(
      totalScore: total.clamp(0, 36).toInt(),
      maxScore: 36,
      level: _marriageLevel(total),
      summary: _marriageSummary(total),
      items: items,
    );
  }

  CompatibilityScores calculateBaseScores(
    PartnerBirthProfile user,
    PartnerBirthProfile partner,
  ) {
    final userSignature = signature(user);
    final partnerSignature = signature(partner);

    final userMoonIndex = userSignature.moonSign;
    final partnerMoonIndex = partnerSignature.moonSign;
    final userVenusIndex = userSignature.venusSign;
    final partnerVenusIndex = partnerSignature.venusSign;
    final userMarsIndex = userSignature.marsSign;
    final partnerMarsIndex = partnerSignature.marsSign;
    final userMercuryIndex = userSignature.mercurySign;
    final partnerMercuryIndex = partnerSignature.mercurySign;
    final userSaturnIndex = userSignature.saturnSign;
    final partnerSaturnIndex = partnerSignature.saturnSign;
    final userRahuIndex = userSignature.rahuSign;
    final partnerRahuIndex = partnerSignature.rahuSign;
    final userAscendantIndex = userSignature.ascendantSign;
    final partnerAscendantIndex = partnerSignature.ascendantSign;
    final userSunIndex = userSignature.siderealSunSign;
    final partnerSunIndex = partnerSignature.siderealSunSign;

    int emotional = 48;
    int attraction = 48;
    int communication = 48;
    int stability = 48;
    int karmic = 48;

    emotional += _relationshipScore(
      userMoonIndex,
      partnerMoonIndex,
      mode: _ScoreMode.emotional,
    );
    emotional += _elementScore(
      userMoonIndex,
      partnerMoonIndex,
      mode: _ScoreMode.emotional,
    );

    attraction += _relationshipScore(
      userVenusIndex,
      partnerMarsIndex,
      mode: _ScoreMode.attraction,
    );
    attraction += _relationshipScore(
      partnerVenusIndex,
      userMarsIndex,
      mode: _ScoreMode.attraction,
    );
    attraction += _relationshipScore(
      userSunIndex,
      partnerSunIndex,
      mode: _ScoreMode.attraction,
    );

    communication += _relationshipScore(
      userMercuryIndex,
      partnerMercuryIndex,
      mode: _ScoreMode.communication,
    );
    communication += _elementScore(
      userMercuryIndex,
      partnerMercuryIndex,
      mode: _ScoreMode.communication,
    );

    stability += _relationshipScore(
      userSaturnIndex,
      partnerSaturnIndex,
      mode: _ScoreMode.stability,
    );
    stability += _relationshipScore(
      userAscendantIndex,
      partnerAscendantIndex,
      mode: _ScoreMode.stability,
    );
    stability += _elementScore(
      userSunIndex,
      partnerSunIndex,
      mode: _ScoreMode.stability,
    );

    karmic += _relationshipScore(
      userRahuIndex,
      partnerSunIndex,
      mode: _ScoreMode.karmic,
    );
    karmic += _relationshipScore(
      partnerRahuIndex,
      userSunIndex,
      mode: _ScoreMode.karmic,
    );
    karmic += _relationshipScore(
      userMoonIndex,
      partnerMoonIndex,
      mode: _ScoreMode.karmic,
    );

    final promptScores = _promptAdjustments(partner.emotionalPrompt);

    emotional += promptScores.emotional;
    attraction += promptScores.attraction;
    communication += promptScores.communication;
    stability += promptScores.stability;
    karmic += promptScores.karmic;

    emotional = emotional.clamp(60, 96).toInt();
    attraction = attraction.clamp(60, 96).toInt();
    communication = communication.clamp(60, 96).toInt();
    stability = stability.clamp(60, 96).toInt();
    karmic = karmic.clamp(60, 96).toInt();

    final overall = ((emotional * 0.25) +
            (attraction * 0.25) +
            (communication * 0.15) +
            (stability * 0.20) +
            (karmic * 0.15))
        .round()
        .clamp(60, 96)
        .toInt();

    return CompatibilityScores(
      overall: overall,
      emotional: emotional,
      attraction: attraction,
      communication: communication,
      stability: stability,
      karmic: karmic,
    );
  }

  CompatibilityScores applyMarriageScoreToOverall(
    CompatibilityScores baseScores,
    MarriageGunaMatch marriageGunaMatch,
  ) {
    final safeMaxScore =
        marriageGunaMatch.maxScore <= 0 ? 36 : marriageGunaMatch.maxScore;
    final safeGunaTotal =
        marriageGunaMatch.totalScore.clamp(0, safeMaxScore).toInt();
    final gunaPercent =
        ((safeGunaTotal / safeMaxScore) * 100).round().clamp(0, 100).toInt();
    final safeBaseOverall = baseScores.overall.clamp(42, 96).toInt();
    final blended = ((safeBaseOverall * 0.65) + (gunaPercent * 0.35))
        .round()
        .clamp(0, 100)
        .toInt();
    final uniquenessSeed =
        '${marriageGunaMatch.totalScore}-${baseScores.emotional}-${baseScores.attraction}-${baseScores.communication}-${baseScores.stability}-${baseScores.karmic}'
            .codeUnits
            .fold<int>(0, (previous, element) => previous + element);
    final uniqueShift = (uniquenessSeed % 5) - 2;

    int finalOverall = blended + uniqueShift;

    if (safeGunaTotal <= 18 || finalOverall < 70) {
      finalOverall = finalOverall.clamp(60, 69).toInt();
    } else if (safeGunaTotal <= 27 || finalOverall < 80) {
      finalOverall = finalOverall.clamp(70, 79).toInt();
    } else {
      finalOverall = finalOverall.clamp(80, 95).toInt();
    }

    return baseScores.copyWith(overall: finalOverall.clamp(60, 95).toInt());
  }

  DateTime _estimatedUtcBirth(PartnerBirthProfile profile) {
    final place = _coordinatesFor(profile);
    final birthMinutes = _parseBirthMinutes(profile.timeOfBirth);
    final longitudeOffsetMinutes = ((place?.longitude ?? 0) * 4).round();
    final localDate = DateTime.utc(
      profile.dob.year,
      profile.dob.month,
      profile.dob.day,
    );

    return localDate.add(
      Duration(minutes: birthMinutes - longitudeOffsetMinutes),
    );
  }

  double _daysSinceJ2000(DateTime utcBirth) {
    final j2000 = DateTime.utc(2000, 1, 1, 12);
    return utcBirth.difference(j2000).inMilliseconds / 86400000;
  }

  double _lahiriAyanamsa(double daysSinceJ2000) {
    return 23.8531 + ((daysSinceJ2000 / 36525) * 1.396);
  }

  double _siderealSunLongitude(double daysSinceJ2000, double ayanamsa) {
    final meanLongitude = _normalizeDegrees(
      280.46646 + (0.98564736 * daysSinceJ2000),
    );
    final meanAnomaly = _normalizeDegrees(
      357.52911 + (0.98560028 * daysSinceJ2000),
    );
    final center = (1.914602 * _sinDeg(meanAnomaly)) +
        (0.019993 * _sinDeg(2 * meanAnomaly)) +
        (0.000289 * _sinDeg(3 * meanAnomaly));

    return _normalizeDegrees(meanLongitude + center - ayanamsa);
  }

  double _siderealMoonLongitude(double daysSinceJ2000, double ayanamsa) {
    final meanLongitude = _normalizeDegrees(
      218.3164477 + (13.17639648 * daysSinceJ2000),
    );
    final meanAnomaly = _normalizeDegrees(
      134.9633964 + (13.06499295 * daysSinceJ2000),
    );
    final elongation = _normalizeDegrees(
      297.8501921 + (12.19074912 * daysSinceJ2000),
    );
    final sunAnomaly = _normalizeDegrees(
      357.5291092 + (0.98560028 * daysSinceJ2000),
    );

    final longitude = meanLongitude +
        (6.289 * _sinDeg(meanAnomaly)) +
        (1.274 * _sinDeg((2 * elongation) - meanAnomaly)) +
        (0.658 * _sinDeg(2 * elongation)) +
        (0.214 * _sinDeg(2 * meanAnomaly)) -
        (0.186 * _sinDeg(sunAnomaly));

    return _normalizeDegrees(longitude - ayanamsa);
  }

  int _meanPlanetSign(
    double epochLongitude,
    double dailyMotion,
    double daysSinceJ2000,
    double ayanamsa,
  ) {
    return _signFromLongitude(
      _normalizeDegrees(
          epochLongitude + (dailyMotion * daysSinceJ2000) - ayanamsa),
    );
  }

  int _ascendantSign(
    double siderealSunLongitude,
    int localSolarMinutes,
    double? latitude,
  ) {
    final sunriseRelativeMinutes =
        ((localSolarMinutes - 360) % 1440 + 1440) % 1440;
    final signShift = (sunriseRelativeMinutes / 120).floor();
    final latitudeShift = latitude == null ? 0 : (latitude.abs() / 55).floor();

    return (_signFromLongitude(siderealSunLongitude) +
            signShift +
            latitudeShift) %
        12;
  }

  int _signFromLongitude(double longitude) {
    return (_normalizeDegrees(longitude) / 30).floor().clamp(0, 11).toInt();
  }

  int _localSolarMinutes(String time, double? longitude) {
    final clockMinutes = _parseBirthMinutes(time);
    final longitudeOffset = longitude == null ? 0 : (longitude * 4).round();
    final rawMinutes = clockMinutes + longitudeOffset;
    return ((rawMinutes % 1440) + 1440) % 1440;
  }

  int _parseBirthMinutes(String time) {
    final normalized = time.trim().toUpperCase();
    final match = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(normalized);

    if (match == null) return 720;

    var hour = int.tryParse(match.group(1) ?? '') ?? 12;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final isPm = normalized.contains('PM');
    final isAm = normalized.contains('AM');

    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    return ((hour.clamp(0, 23) * 60) + minute.clamp(0, 59)) % 1440;
  }

  GunaScoreItem _varnaGuna(int userMoonSign, int partnerMoonSign) {
    final userVarna = _varnaRank(userMoonSign);
    final partnerVarna = _varnaRank(partnerMoonSign);
    final score = (userVarna - partnerVarna).abs() <= 1 ? 1 : 0;

    return GunaScoreItem(
      name: 'Varna',
      score: score,
      maxScore: 1,
      meaning: 'Moon-sign varna balance for dharma, ego, and values.',
    );
  }

  CompatibilityScores _promptAdjustments(String prompt) {
    final text = prompt.toLowerCase();

    int emotional = 0;
    int attraction = 0;
    int communication = 0;
    int stability = 0;
    int karmic = 0;

    bool hasAny(List<String> words) {
      return words.any((word) => text.contains(word));
    }

    if (hasAny([
      'calm',
      'caring',
      'kind',
      'safe',
      'understands',
      'listen',
      'gentle',
      'loyal',
      'comfort',
      'peace',
    ])) {
      emotional += 6;
      stability += 2;
    }

    if (hasAny([
      'confidence',
      'ambition',
      'ambitious',
      'driven',
      'successful',
      'mature',
      'responsible',
      'disciplined',
      'consistent',
    ])) {
      stability += 5;
      attraction += 2;
    }

    if (hasAny([
      'attraction',
      'attractive',
      'chemistry',
      'spark',
      'beautiful',
      'handsome',
      'hot',
      'magnetic',
      'smile',
      'eyes',
    ])) {
      attraction += 6;
      karmic += 2;
    }

    if (hasAny([
      'talk',
      'conversation',
      'communicate',
      'funny',
      'intelligent',
      'mindset',
      'ideas',
      'voice',
      'laugh',
    ])) {
      communication += 5;
    }

    if (hasAny([
      'confusion',
      'confusing',
      'mixed signal',
      'distant',
      'unavailable',
      'ego',
      'toxic',
      'obsession',
      'anxious',
      'overthink',
    ])) {
      karmic += 7;
      stability -= 5;
      emotional -= 3;
    }

    if (hasAny([
      'dont like',
      "don't like",
      'do not like',
      'hate',
      'annoying',
      'irritating',
      'rude',
      'angry',
    ])) {
      communication -= 3;
      emotional -= 3;
      stability -= 2;
      karmic += 4;
    }

    return CompatibilityScores(
      overall: 0,
      emotional: emotional.clamp(-6, 6).toInt(),
      attraction: attraction.clamp(-6, 6).toInt(),
      communication: communication.clamp(-6, 6).toInt(),
      stability: stability.clamp(-6, 6).toInt(),
      karmic: karmic.clamp(-6, 8).toInt(),
    );
  }

  int _relationshipScore(
    int a,
    int b, {
    required _ScoreMode mode,
  }) {
    final d = _distance(a, b);

    switch (mode) {
      case _ScoreMode.emotional:
        switch (d) {
          case 0:
            return 13;
          case 2:
            return 14;
          case 4:
            return 18;
          case 6:
            return 10;
          case 3:
            return 5;
          case 1:
            return 3;
          case 5:
            return 2;
        }

      case _ScoreMode.attraction:
        switch (d) {
          case 0:
            return 12;
          case 2:
            return 12;
          case 4:
            return 15;
          case 6:
            return 17;
          case 3:
            return 16;
          case 1:
            return 7;
          case 5:
            return 5;
        }

      case _ScoreMode.communication:
        switch (d) {
          case 0:
            return 13;
          case 2:
            return 14;
          case 4:
            return 16;
          case 6:
            return 8;
          case 3:
            return 5;
          case 1:
            return 4;
          case 5:
            return 3;
        }

      case _ScoreMode.stability:
        switch (d) {
          case 0:
            return 12;
          case 2:
            return 12;
          case 4:
            return 16;
          case 6:
            return 9;
          case 3:
            return 7;
          case 1:
            return 4;
          case 5:
            return 3;
        }

      case _ScoreMode.karmic:
        switch (d) {
          case 0:
            return 14;
          case 6:
            return 17;
          case 3:
            return 16;
          case 5:
            return 12;
          case 4:
            return 8;
          case 2:
            return 7;
          case 1:
            return 6;
        }
    }

    return 5;
  }

  int _elementScore(
    int a,
    int b, {
    required _ScoreMode mode,
  }) {
    final first = _element(a);
    final second = _element(b);

    if (first == second) {
      return mode == _ScoreMode.attraction ? 7 : 10;
    }

    final supportive = (first == 'fire' && second == 'air') ||
        (first == 'air' && second == 'fire') ||
        (first == 'earth' && second == 'water') ||
        (first == 'water' && second == 'earth');

    if (supportive) {
      return mode == _ScoreMode.stability ? 10 : 8;
    }

    final friction = (first == 'fire' && second == 'water') ||
        (first == 'water' && second == 'fire') ||
        (first == 'air' && second == 'earth') ||
        (first == 'earth' && second == 'air');

    if (friction) {
      return mode == _ScoreMode.karmic ? 10 : 3;
    }

    return 5;
  }

  int _distance(int a, int b) {
    final diff = (a - b).abs();
    return min(diff, 12 - diff);
  }

  String _element(int signIndex) {
    switch (signIndex) {
      case 0:
      case 4:
      case 8:
        return 'fire';
      case 1:
      case 5:
      case 9:
        return 'earth';
      case 2:
      case 6:
      case 10:
        return 'air';
      default:
        return 'water';
    }
  }

  GunaScoreItem _vashyaGuna(int userMoonSign, int partnerMoonSign) {
    final userGroup = _vashyaGroup(userMoonSign);
    final partnerGroup = _vashyaGroup(partnerMoonSign);
    final score = userGroup == partnerGroup
        ? 2
        : _friendlyVashya(userGroup, partnerGroup)
            ? 1
            : 0;

    return GunaScoreItem(
      name: 'Vashya',
      score: score,
      maxScore: 2,
      meaning: 'Natural pull, influence, and ease of yielding.',
    );
  }

  GunaScoreItem _taraGuna(int userNakshatra, int partnerNakshatra) {
    final userToPartner = _isAuspiciousTara(userNakshatra, partnerNakshatra);
    final partnerToUser = _isAuspiciousTara(partnerNakshatra, userNakshatra);
    final score = userToPartner && partnerToUser
        ? 3
        : userToPartner || partnerToUser
            ? 1
            : 0;

    return GunaScoreItem(
      name: 'Tara',
      score: score,
      maxScore: 3,
      meaning: 'Birth-star support for luck, protection, and timing.',
    );
  }

  GunaScoreItem _yoniGuna(int userNakshatra, int partnerNakshatra) {
    final userYoni = _yoniAnimal(userNakshatra);
    final partnerYoni = _yoniAnimal(partnerNakshatra);

    int score;
    if (userYoni == partnerYoni) {
      score = 4;
    } else if (_enemyYoni(userYoni, partnerYoni)) {
      score = 0;
    } else if (_sameYoniTemperament(userYoni, partnerYoni)) {
      score = 3;
    } else {
      score = 2;
    }

    return GunaScoreItem(
      name: 'Yoni',
      score: score,
      maxScore: 4,
      meaning: 'Instinctive chemistry, desire rhythm, and intimacy comfort.',
    );
  }

  GunaScoreItem _grahaMaitriGuna(int userMoonSign, int partnerMoonSign) {
    final userLord = _signLord(userMoonSign);
    final partnerLord = _signLord(partnerMoonSign);
    final first = _planetRelation(userLord, partnerLord);
    final second = _planetRelation(partnerLord, userLord);
    final relationTotal = first + second;

    final score = switch (relationTotal) {
      4 => 5,
      3 => 4,
      2 => 3,
      1 => 2,
      _ => 0,
    };

    return GunaScoreItem(
      name: 'Graha Maitri',
      score: score,
      maxScore: 5,
      meaning: 'Moon-lord friendship for mental acceptance and trust.',
    );
  }

  GunaScoreItem _ganaGuna(int userNakshatra, int partnerNakshatra) {
    final userGana = _gana(userNakshatra);
    final partnerGana = _gana(partnerNakshatra);

    int score;
    if (userGana == partnerGana) {
      score = 6;
    } else if (_hasGanaPair(userGana, partnerGana, 0, 1)) {
      score = 5;
    } else if (_hasGanaPair(userGana, partnerGana, 1, 2)) {
      score = 3;
    } else {
      score = 1;
    }

    return GunaScoreItem(
      name: 'Gana',
      score: score,
      maxScore: 6,
      meaning: 'Temperament class: deva, manushya, or rakshasa nature.',
    );
  }

  GunaScoreItem _bhakootGuna(int userMoonSign, int partnerMoonSign) {
    final forward = ((partnerMoonSign - userMoonSign + 12) % 12) + 1;
    final reverse = ((userMoonSign - partnerMoonSign + 12) % 12) + 1;
    final challenging = _hasRashiPair(forward, reverse, 2, 12) ||
        _hasRashiPair(forward, reverse, 5, 9) ||
        _hasRashiPair(forward, reverse, 6, 8);

    return GunaScoreItem(
      name: 'Bhakoot',
      score: challenging ? 0 : 7,
      maxScore: 7,
      meaning: 'Moon-sign placement for family harmony and shared prosperity.',
    );
  }

  GunaScoreItem _nadiGuna(int userNakshatra, int partnerNakshatra) {
    final userNadi = _nadi(userNakshatra);
    final partnerNadi = _nadi(partnerNakshatra);

    return GunaScoreItem(
      name: 'Nadi',
      score: userNadi == partnerNadi ? 0 : 8,
      maxScore: 8,
      meaning: 'Pranic compatibility, health harmony, and lineage balance.',
    );
  }

  int _varnaRank(int moonSign) {
    final element = moonSign % 4;
    if (element == 0) return 2;
    if (element == 1) return 1;
    if (element == 2) return 0;
    return 3;
  }

  int _vashyaGroup(int moonSign) {
    if (moonSign == 2 || moonSign == 5 || moonSign == 6 || moonSign == 10) {
      return 0;
    }
    if (moonSign == 0 || moonSign == 1 || moonSign == 4 || moonSign == 8) {
      return 1;
    }
    if (moonSign == 3 || moonSign == 9 || moonSign == 11) return 2;
    return 3;
  }

  bool _friendlyVashya(int a, int b) {
    return _hasGanaPair(a, b, 0, 1) || _hasGanaPair(a, b, 2, 3);
  }

  bool _isAuspiciousTara(int fromNakshatra, int toNakshatra) {
    final count = ((toNakshatra - fromNakshatra + 27) % 27) + 1;
    final tara = count % 9;
    return tara == 0 || tara == 2 || tara == 4 || tara == 6 || tara == 8;
  }

  int _yoniAnimal(int nakshatra) {
    const animals = [
      0,
      1,
      2,
      3,
      3,
      4,
      5,
      2,
      5,
      6,
      6,
      7,
      8,
      9,
      8,
      9,
      10,
      10,
      4,
      11,
      12,
      11,
      13,
      0,
      13,
      7,
      1,
    ];

    return animals[nakshatra.clamp(0, 26).toInt()];
  }

  bool _enemyYoni(int a, int b) {
    const enemies = [
      (0, 8),
      (1, 13),
      (2, 11),
      (3, 12),
      (4, 10),
      (5, 6),
      (7, 9),
    ];

    return enemies.any((pair) => _hasGanaPair(a, b, pair.$1, pair.$2));
  }

  bool _sameYoniTemperament(int a, int b) {
    const soft = {0, 1, 5, 7, 10};
    const active = {2, 4, 6, 8, 11};
    const intense = {3, 9, 12, 13};

    return (soft.contains(a) && soft.contains(b)) ||
        (active.contains(a) && active.contains(b)) ||
        (intense.contains(a) && intense.contains(b));
  }

  int _signLord(int sign) {
    const lords = [
      2,
      5,
      3,
      1,
      0,
      3,
      5,
      2,
      4,
      6,
      6,
      4,
    ];

    return lords[sign.clamp(0, 11).toInt()];
  }

  int _planetRelation(int fromLord, int toLord) {
    const friends = {
      0: {1, 2, 4},
      1: {0, 3},
      2: {0, 1, 4},
      3: {0, 5},
      4: {0, 1, 2},
      5: {3, 6},
      6: {3, 5},
    };

    const enemies = {
      0: {5, 6},
      1: <int>{},
      2: {3},
      3: {1},
      4: {3, 5},
      5: {0, 1},
      6: {0, 1, 2},
    };

    if (friends[fromLord]?.contains(toLord) ?? false) return 2;
    if (enemies[fromLord]?.contains(toLord) ?? false) return 0;
    return 1;
  }

  int _gana(int nakshatra) {
    const gana = [
      0,
      1,
      2,
      1,
      0,
      1,
      0,
      0,
      2,
      2,
      1,
      1,
      1,
      0,
      0,
      2,
      0,
      2,
      2,
      1,
      1,
      0,
      2,
      2,
      1,
      2,
      0,
    ];

    return gana[nakshatra.clamp(0, 26).toInt()];
  }

  int _nadi(int nakshatra) {
    const nadi = [
      0,
      1,
      2,
      2,
      1,
      0,
      0,
      1,
      2,
      2,
      1,
      0,
      0,
      1,
      2,
      2,
      1,
      0,
      0,
      1,
      2,
      2,
      1,
      0,
      0,
      1,
      2,
    ];

    return nadi[nakshatra.clamp(0, 26).toInt()];
  }

  bool _hasGanaPair(int a, int b, int first, int second) {
    return (a == first && b == second) || (a == second && b == first);
  }

  bool _hasRashiPair(int a, int b, int first, int second) {
    return (a == first && b == second) || (a == second && b == first);
  }

  String _marriageLevel(int score) {
    if (score >= 29) return 'Excellent Marriage Match';
    if (score >= 22) return 'Good Marriage Match';
    if (score >= 18) return 'Average Marriage Match';
    return 'Challenging Marriage Match';
  }

  String _marriageSummary(int score) {
    if (score >= 29) {
      return 'The Vedic Guna pattern shows strong marriage harmony, emotional support, and long-term promise.';
    }

    if (score >= 22) {
      return 'The Vedic Guna pattern is supportive, with good potential if both partners communicate with maturity.';
    }

    if (score >= 18) {
      return 'The Vedic Guna pattern is moderate. The bond may work, but emotional patience and family alignment matter.';
    }

    return 'The Vedic Guna pattern shows tension in long-term adjustment. This match needs careful thought, patience, and maturity.';
  }

  _BirthCoordinates? _coordinatesFor(PartnerBirthProfile profile) {
    final latitude = profile.latitude ?? _knownLatitude(profile.placeOfBirth);
    final longitude =
        profile.longitude ?? _knownLongitude(profile.placeOfBirth);

    if (latitude == null || longitude == null) return null;

    return _BirthCoordinates(latitude: latitude, longitude: longitude);
  }

  double? _knownLatitude(String place) {
    return _knownCoordinates(place)?.latitude;
  }

  double? _knownLongitude(String place) {
    return _knownCoordinates(place)?.longitude;
  }

  _BirthCoordinates? _knownCoordinates(String place) {
    final normalized = place.toLowerCase();

    const known = <String, _BirthCoordinates>{
      'new delhi': _BirthCoordinates(latitude: 28.6139, longitude: 77.2090),
      'delhi': _BirthCoordinates(latitude: 28.6139, longitude: 77.2090),
      'mumbai': _BirthCoordinates(latitude: 19.0760, longitude: 72.8777),
      'bengaluru': _BirthCoordinates(latitude: 12.9716, longitude: 77.5946),
      'bangalore': _BirthCoordinates(latitude: 12.9716, longitude: 77.5946),
      'kolkata': _BirthCoordinates(latitude: 22.5726, longitude: 88.3639),
      'chennai': _BirthCoordinates(latitude: 13.0827, longitude: 80.2707),
      'hyderabad': _BirthCoordinates(latitude: 17.3850, longitude: 78.4867),
      'pune': _BirthCoordinates(latitude: 18.5204, longitude: 73.8567),
      'ahmedabad': _BirthCoordinates(latitude: 23.0225, longitude: 72.5714),
      'jaipur': _BirthCoordinates(latitude: 26.9124, longitude: 75.7873),
      'lucknow': _BirthCoordinates(latitude: 26.8467, longitude: 80.9462),
      'varanasi': _BirthCoordinates(latitude: 25.3176, longitude: 82.9739),
      'london': _BirthCoordinates(latitude: 51.5074, longitude: -0.1278),
      'new york': _BirthCoordinates(latitude: 40.7128, longitude: -74.0060),
      'los angeles': _BirthCoordinates(latitude: 34.0522, longitude: -118.2437),
      'chicago': _BirthCoordinates(latitude: 41.8781, longitude: -87.6298),
      'toronto': _BirthCoordinates(latitude: 43.6532, longitude: -79.3832),
      'sydney': _BirthCoordinates(latitude: -33.8688, longitude: 151.2093),
      'melbourne': _BirthCoordinates(latitude: -37.8136, longitude: 144.9631),
      'singapore': _BirthCoordinates(latitude: 1.3521, longitude: 103.8198),
      'dubai': _BirthCoordinates(latitude: 25.2048, longitude: 55.2708),
    };

    for (final entry in known.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  double _sinDeg(double degrees) => sin(degrees * pi / 180);

  double _normalizeDegrees(double value) {
    return ((value % 360) + 360) % 360;
  }
}

class _BirthCoordinates {
  final double latitude;
  final double longitude;

  const _BirthCoordinates({
    required this.latitude,
    required this.longitude,
  });
}

enum _ScoreMode {
  emotional,
  attraction,
  communication,
  stability,
  karmic,
}
