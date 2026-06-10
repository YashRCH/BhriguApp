import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../constants/ai_response_language.dart';
import '../constants/firebase_constants.dart';
import '../models/partner_match_model.dart';
import 'compatibility_rag_service.dart';
import 'firebase_session_service.dart';
import 'user_profile_cache_service.dart';
import 'vedic_match_calculator.dart';

class _PartnerMatchReadingResult {
  final String text;
  final String aiResponseLanguage;

  const _PartnerMatchReadingResult({
    required this.text,
    required this.aiResponseLanguage,
  });
}

class PartnerMatchService {
  final CompatibilityRagService _ragService = CompatibilityRagService();
  final VedicMatchCalculator _vedicCalculator = const VedicMatchCalculator();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );

  final FirebaseSessionService _session =
      FirebaseSessionService(debugLabel: 'Partner match');

  Future<PartnerMatchReading> createReading({
    required PartnerBirthProfile partner,
  }) async {
    final user = await _getUserProfile();
    final aiResponseLanguage = await UserProfileCacheService.instance
        .aiResponseLanguage(refresh: true);

    final baseScores = _calculateScores(user, partner);
    final marriageGunaMatch = _calculateMarriageGunaMatch(user, partner);

    final calculatedScores = _applyMarriageScoreToOverall(
      baseScores,
      marriageGunaMatch,
    );

    final scores = calculatedScores.copyWith(
      overall: calculatedScores.overall.clamp(60, 95).toInt(),
    );

    final userSun = _sunSign(user.dob);
    final partnerSun = _sunSign(partner.dob);
    final userMoon = _moonStyle(user);
    final partnerMoon = _moonStyle(partner);
    final connectionType = _connectionType(scores);
    final verdict = _verdict(scores.overall);

    final ragQuery = _buildCompatibilityRagQuery(
      user: user,
      partner: partner,
      scores: scores,
      marriageGunaMatch: marriageGunaMatch,
      userSun: userSun,
      partnerSun: partnerSun,
      userMoon: userMoon,
      partnerMoon: partnerMoon,
      connectionType: connectionType,
      verdict: verdict,
    );

    final retrievedChunks = await _ragService.retrieveRelevantChunks(
      query: ragQuery,
      limit: 5,
    );

    final retrievedKnowledge = retrievedChunks.isEmpty
        ? 'No specific compatibility knowledge retrieved.'
        : retrievedChunks.map((chunk) => chunk.formatted).join('\n---\n');

    final summaryResult = await _generateBhriguReading(
      user: user,
      partner: partner,
      scores: scores,
      marriageGunaMatch: marriageGunaMatch,
      userSun: userSun,
      partnerSun: partnerSun,
      userMoon: userMoon,
      partnerMoon: partnerMoon,
      connectionType: connectionType,
      verdict: verdict,
      retrievedKnowledge: retrievedKnowledge,
      aiResponseLanguage: aiResponseLanguage,
    );

    final reading = PartnerMatchReading(
      user: user,
      partner: partner,
      scores: scores,
      marriageGunaMatch: marriageGunaMatch,
      userSunSign: userSun,
      partnerSunSign: partnerSun,
      userMoonStyle: userMoon,
      partnerMoonStyle: partnerMoon,
      connectionType: connectionType,
      verdict: verdict,
      summary: summaryResult.text,
      createdAt: DateTime.now(),
      aiResponseLanguage: summaryResult.aiResponseLanguage,
    );

    await _saveReading(reading);

    return reading;
  }

  Future<List<PartnerMatchReading>> getSavedReadings({
    int limit = 30,
  }) async {
    try {
      final uid = await _getUid();

      if (uid == null) {
        return [];
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('partner_matches')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      final aiResponseLanguage = await UserProfileCacheService.instance
          .aiResponseLanguage(refresh: true);

      final readings = <PartnerMatchReading>[];

      for (final doc in snap.docs) {
        try {
          final data = Map<String, dynamic>.from(doc.data());
          final normalized = _normalizeReadingData(data);
          final reading = PartnerMatchReading.fromJson(normalized);
          if (reading.aiResponseLanguage == aiResponseLanguage) {
            readings.add(reading);
          }
        } catch (e) {
          debugPrint('Partner match history parse error: $e');
        }
      }

      return readings;
    } catch (e) {
      debugPrint('Partner match history load error: $e');
      return [];
    }
  }

  Future<void> deleteSavedReading({
    required String documentId,
  }) async {
    try {
      final uid = await _getUid();

      if (uid == null) {
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('partner_matches')
          .doc(documentId)
          .delete();
    } catch (e) {
      debugPrint('Delete partner match history error: $e');
    }
  }

  Future<String?> _getUid() => _session.userId();

  Map<String, dynamic> _normalizeReadingData(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];

    if (createdAt is Timestamp) {
      data['createdAt'] = createdAt.toDate().toIso8601String();
    } else if (createdAt is DateTime) {
      data['createdAt'] = createdAt.toIso8601String();
    } else if (createdAt is! String || createdAt.trim().isEmpty) {
      final createdAtIso = data['createdAtIso'];

      if (createdAtIso is String && createdAtIso.trim().isNotEmpty) {
        data['createdAt'] = createdAtIso;
      } else {
        data['createdAt'] = DateTime.now().toIso8601String();
      }
    }

    return data;
  }

  Future<void> _saveReading(PartnerMatchReading reading) async {
    try {
      final uid = await _getUid();

      if (uid == null) {
        debugPrint('Save partner match reading skipped: uid is null');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('partner_matches')
          .add({
        ...reading.toJson(),
        'scores': {
          ...reading.scores.toJson(),
          'overall': reading.scores.overall.clamp(60, 95).toInt(),
        },
        'createdAtIso': reading.createdAt.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Save partner match reading error: $e');
    }
  }

  Future<PartnerBirthProfile> _getUserProfile() async {
    final uid = await _getUid();

    if (uid == null) {
      return PartnerBirthProfile(
        name: 'You',
        dob: DateTime(2000),
        timeOfBirth: 'Unknown',
        placeOfBirth: 'Unknown',
        emotionalPrompt: '',
      );
    }

    final data =
        await UserProfileCacheService.instance.userDataWithFreshCharts() ?? {};

    return PartnerBirthProfile(
      name: data['name'] as String? ?? 'You',
      dob: DateTime.tryParse(data['dob'] as String? ?? '') ?? DateTime(2000),
      timeOfBirth: data['timeOfBirth'] as String? ?? 'Unknown',
      placeOfBirth: data['placeOfBirth'] as String? ?? 'Unknown',
      latitude: _doubleOrNull(data['latitude']),
      longitude: _doubleOrNull(data['longitude']),
      emotionalPrompt: '',
    );
  }

  CompatibilityScores _calculateScores(
    PartnerBirthProfile user,
    PartnerBirthProfile partner,
  ) {
    return _vedicCalculator.calculateBaseScores(user, partner);
  }

  MarriageGunaMatch _calculateMarriageGunaMatch(
    PartnerBirthProfile user,
    PartnerBirthProfile partner,
  ) {
    return _vedicCalculator.calculateMarriageGunaMatch(user, partner);
  }

  CompatibilityScores _applyMarriageScoreToOverall(
    CompatibilityScores baseScores,
    MarriageGunaMatch marriageGunaMatch,
  ) {
    return _vedicCalculator.applyMarriageScoreToOverall(
      baseScores,
      marriageGunaMatch,
    );
  }

  double? _doubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _sunSign(DateTime dob) {
    final m = dob.month;
    final d = dob.day;

    if ((m == 3 && d >= 21) || (m == 4 && d <= 19)) return 'Aries';
    if ((m == 4 && d >= 20) || (m == 5 && d <= 20)) return 'Taurus';
    if ((m == 5 && d >= 21) || (m == 6 && d <= 20)) return 'Gemini';
    if ((m == 6 && d >= 21) || (m == 7 && d <= 22)) return 'Cancer';
    if ((m == 7 && d >= 23) || (m == 8 && d <= 22)) return 'Leo';
    if ((m == 8 && d >= 23) || (m == 9 && d <= 22)) return 'Virgo';
    if ((m == 9 && d >= 23) || (m == 10 && d <= 22)) return 'Libra';
    if ((m == 10 && d >= 23) || (m == 11 && d <= 21)) return 'Scorpio';
    if ((m == 11 && d >= 22) || (m == 12 && d <= 21)) {
      return 'Sagittarius';
    }
    if ((m == 12 && d >= 22) || (m == 1 && d <= 19)) return 'Capricorn';
    if ((m == 1 && d >= 20) || (m == 2 && d <= 18)) return 'Aquarius';
    return 'Pisces';
  }

  String _moonStyle(PartnerBirthProfile profile) {
    const styles = [
      'Intuitive',
      'Protective',
      'Restless',
      'Deep-feeling',
      'Practical',
      'Romantic',
      'Private',
      'Fiery',
      'Grounded',
      'Detached',
      'Devotional',
      'Sensitive',
    ];

    final index = _vedicCalculator.signature(profile).moonSign;
    return styles[index % styles.length];
  }

  String _connectionType(CompatibilityScores scores) {
    if (scores.attraction >= 84 && scores.stability <= 64) {
      return 'High Chemistry, Low Peace';
    }

    if (scores.emotional >= 80 && scores.stability >= 76) {
      return 'Emotionally Safe Match';
    }

    if (scores.karmic >= 84 && scores.emotional < 72) {
      return 'Karmic Lesson';
    }

    if (scores.overall >= 86) {
      return 'Soulful Bond';
    }

    if (scores.attraction >= 82) {
      return 'Magnetic Attraction';
    }

    if (scores.stability >= 78) {
      return 'Stable Companion';
    }

    return 'Mixed but Meaningful';
  }

  String _verdict(int score) {
    if (score >= 88) return 'Rare cosmic alignment';
    if (score >= 80) return 'Strong compatibility';
    if (score >= 70) return 'Promising bond';
    return 'Challenging karmic connection';
  }

  String _buildCompatibilityRagQuery({
    required PartnerBirthProfile user,
    required PartnerBirthProfile partner,
    required CompatibilityScores scores,
    required MarriageGunaMatch marriageGunaMatch,
    required String userSun,
    required String partnerSun,
    required String userMoon,
    required String partnerMoon,
    required String connectionType,
    required String verdict,
  }) {
    return '''
User Sun Sign: $userSun
User Moon Style: $userMoon

Partner Sun Sign: $partnerSun
Partner Moon Style: $partnerMoon

Compatibility Scores:
Overall: ${scores.overall}
Emotional Harmony: ${scores.emotional}
Attraction Pull: ${scores.attraction}
Communication: ${scores.communication}
Long-term Stability: ${scores.stability}
Karmic Bond: ${scores.karmic}

36 Guna Marriage Match:
Total: ${marriageGunaMatch.totalScore}/${marriageGunaMatch.maxScore}
Level: ${marriageGunaMatch.level}
Summary: ${marriageGunaMatch.summary}
Breakdown:
${marriageGunaMatch.items.map((item) => '- ${item.name}: ${item.score}/${item.maxScore} - ${item.meaning}').join('\n')}

Connection Type: $connectionType
Verdict: $verdict

User emotional prompt about partner:
${partner.emotionalPrompt}

Retrieve astrology compatibility knowledge about:
- $userSun and $partnerSun compatibility
- Moon emotional compatibility
- Venus Mars attraction and romantic chemistry
- Saturn long-term stability
- Rahu Ketu karmic bonds
- 36 Guna Milan
- Varna, Vashya, Tara, Yoni, Graha Maitri, Gana, Bhakoot, Nadi
- marriage compatibility
- relationship prompt signals
- emotional safety, attraction, confusion, ego, distance, or communication patterns if relevant
''';
  }

  Future<_PartnerMatchReadingResult> _generateBhriguReading({
    required PartnerBirthProfile user,
    required PartnerBirthProfile partner,
    required CompatibilityScores scores,
    required MarriageGunaMatch marriageGunaMatch,
    required String userSun,
    required String partnerSun,
    required String userMoon,
    required String partnerMoon,
    required String connectionType,
    required String verdict,
    required String retrievedKnowledge,
    required String aiResponseLanguage,
  }) async {
    try {
      if (await _session.currentUserOrWait() == null) {
        throw Exception('User not signed in');
      }

      final callable = _functions.httpsCallable(
        'generatePartnerMatchReading',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 180),
        ),
      );

      final response = await callable.call(
        {
          'user': {
            'name': user.name,
            'dob': user.dob.toIso8601String(),
            'timeOfBirth': user.timeOfBirth,
            'placeOfBirth': user.placeOfBirth,
            'latitude': user.latitude,
            'longitude': user.longitude,
          },
          'partner': {
            'name': partner.name,
            'dob': partner.dob.toIso8601String(),
            'timeOfBirth': partner.timeOfBirth,
            'placeOfBirth': partner.placeOfBirth,
            'latitude': partner.latitude,
            'longitude': partner.longitude,
            'emotionalPrompt': partner.emotionalPrompt,
          },
          'scores': {
            'overall': scores.overall.clamp(60, 95).toInt(),
            'emotional': scores.emotional,
            'attraction': scores.attraction,
            'communication': scores.communication,
            'stability': scores.stability,
            'karmic': scores.karmic,
          },
          'marriageGunaMatch': marriageGunaMatch.toJson(),
          'userSun': userSun,
          'partnerSun': partnerSun,
          'userMoon': userMoon,
          'partnerMoon': partnerMoon,
          'connectionType': connectionType,
          'verdict': verdict,
          'retrievedKnowledge': retrievedKnowledge,
          'aiResponseLanguage': aiResponseLanguage,
        },
      );

      final data = Map<String, dynamic>.from(
        response.data as Map,
      );

      final responseLanguage = normalizeAiResponseLanguage(
        data['aiResponseLanguage'] ?? aiResponseLanguage,
      );

      return _PartnerMatchReadingResult(
        text: data['text'] as String? ??
            _fallbackReading(
              user: user,
              partner: partner,
              scores: scores,
              marriageGunaMatch: marriageGunaMatch,
              userSun: userSun,
              partnerSun: partnerSun,
              userMoon: userMoon,
              partnerMoon: partnerMoon,
              connectionType: connectionType,
              verdict: verdict,
              aiResponseLanguage: responseLanguage,
            ),
        aiResponseLanguage: responseLanguage,
      );
    } catch (e) {
      debugPrint('Partner match AI error: $e');

      return _PartnerMatchReadingResult(
        text: _fallbackReading(
          user: user,
          partner: partner,
          scores: scores,
          marriageGunaMatch: marriageGunaMatch,
          userSun: userSun,
          partnerSun: partnerSun,
          userMoon: userMoon,
          partnerMoon: partnerMoon,
          connectionType: connectionType,
          verdict: verdict,
          aiResponseLanguage: aiResponseLanguage,
        ),
        aiResponseLanguage: aiResponseLanguage,
      );
    }
  }

  String _strongestArea(CompatibilityScores scores) {
    return _scoreExtreme(scores, highest: true).key;
  }

  String _softestArea(CompatibilityScores scores) {
    return _scoreExtreme(scores, highest: false).key;
  }

  MapEntry<String, int> _scoreExtreme(
    CompatibilityScores scores, {
    required bool highest,
  }) {
    final areas = <String, int>{
      'emotional harmony': scores.emotional,
      'attraction pull': scores.attraction,
      'communication': scores.communication,
      'long-term stability': scores.stability,
      'karmic bond': scores.karmic,
    };

    return areas.entries.reduce((current, next) {
      if (highest) {
        return next.value > current.value ? next : current;
      }

      return next.value < current.value ? next : current;
    });
  }

  String _scoreQuality(int score) {
    if (score >= 82) return 'strong';
    if (score >= 72) return 'steady';
    if (score >= 64) return 'workable';
    return 'delicate';
  }

  String _fallbackReading({
    required PartnerBirthProfile user,
    required PartnerBirthProfile partner,
    required CompatibilityScores scores,
    required MarriageGunaMatch marriageGunaMatch,
    required String userSun,
    required String partnerSun,
    required String userMoon,
    required String partnerMoon,
    required String connectionType,
    required String verdict,
    required String aiResponseLanguage,
  }) {
    final strongest = _strongestArea(scores);
    final softest = _softestArea(scores);
    final heartSignal = partner.emotionalPrompt.trim().isEmpty
        ? 'No emotional prompt was provided.'
        : '"${partner.emotionalPrompt.trim()}"';
    final emotionalQuality = _scoreQuality(scores.emotional);
    final attractionQuality = _scoreQuality(scores.attraction);
    final communicationQuality = _scoreQuality(scores.communication);
    final stabilityQuality = _scoreQuality(scores.stability);
    final karmicQuality = _scoreQuality(scores.karmic);

    if (normalizeAiResponseLanguage(aiResponseLanguage) ==
        hinglishAiResponseLanguage) {
      return '''Verdict:
${partner.name} aur ${user.name} ka connection $verdict dikhata hai, $connectionType pattern ke through. Yeh bond random nahi lagta; isme ek clear emotional shape hai.

Compatibility Snapshot:
Is match ka strongest area $strongest hai, aur sabse zyada care $softest mein chahiye. Isliye is connection ko simple yes ya no ke bajay mature handling ke saath dekhna hoga.

Heart Signal:
$heartSignal
Yeh exact words dikhate hain ki aapka heart kis cheez par react kar raha hai, mind ke fully explain karne se pehle.

Emotional Bond:
${user.name} ka Moon style $userMoon hai, aur ${partner.name} ka Moon style $partnerMoon hai. Emotional bond $emotionalQuality hai, lekin comfort tabhi badhega jab dono log apni feelings ko calmly express karenge.

Attraction & Chemistry:
Attraction pull $attractionQuality hai, isliye chemistry ya curiosity naturally activate ho sakti hai. Lekin attraction ko emotional safety ka proof samajhne se pehle consistency dekhni hogi.

Communication Pattern:
Communication $communicationQuality hai, isliye baat-cheet mein clarity aur ego-management important rahega. Silence, mixed signals, ya overthinking aaye to direct but soft conversation is bond ko better sambhalegi.

Long-Term Stability:
Long-term stability $stabilityQuality hai, isliye real-life pressure mein behavior dekhna zaroori hai. $userSun aur $partnerSun ka dynamic tabhi mature hoga jab attraction ke saath patience bhi rahe.

36 Guna Marriage Reading:
36 Guna reading ${marriageGunaMatch.totalScore}/${marriageGunaMatch.maxScore} dikhati hai, ${marriageGunaMatch.level}. ${marriageGunaMatch.summary}

Karmic Lesson:
Karmic bond $karmicQuality hai, isliye yeh connection kuch lesson ya mirror lekar aa sakta hai. Dono logon ko attachment aur expectation ko maturity ke saath handle karna hoga.

Growth Edge:
Growth edge $softest hai, kyunki yahi area future friction bana sakta hai. Is match ko fantasy se zyada honest behavior aur repeat consistency chahiye.

Bhrigu Warning:
Intensity ko peace samajhne ki mistake mat kijiye; powerful bond bhi mature hone se pehle safe nahi hota.

Bhrigu's Guidance:
Slowly observe whether their actions match the feeling they create in you.''';
    }

    return '''Verdict:
${partner.name} and ${user.name} show $verdict through a $connectionType pattern. This bond has a clear emotional shape rather than being random.

Compatibility Snapshot:
The strongest area in this match is $strongest, while $softest needs the most care. This means the connection should be read with nuance, not as a simple yes or no.

Heart Signal:
$heartSignal
These exact words show what your heart is reacting to before your mind fully explains the connection.

Emotional Bond:
${user.name} carries a $userMoon Moon style, while ${partner.name} carries a $partnerMoon Moon style. The emotional bond is $emotionalQuality, but comfort grows only when both people can name their feelings without pressure.

Attraction & Chemistry:
The attraction pull is $attractionQuality, so chemistry or curiosity can rise naturally between them. Strong pull can create closeness, but it should not be mistaken for emotional safety by itself.

Communication Pattern:
Communication is $communicationQuality, so repair after misunderstanding matters more than perfect conversation. If silence, mixed signals, or ego appear, this bond needs direct but gentle truth.

Long-Term Stability:
Long-term stability is $stabilityQuality, so the future depends on consistency under real pressure. The $userSun and $partnerSun dynamic can mature when patience supports the attraction.

36 Guna Marriage Reading:
The 36 Guna reading shows ${marriageGunaMatch.totalScore}/${marriageGunaMatch.maxScore}, ${marriageGunaMatch.level}. ${marriageGunaMatch.summary}

Karmic Lesson:
The karmic bond is $karmicQuality, so this connection may mirror attachment, timing, or expectation patterns. Its lesson is to stay honest without forcing certainty too early.

Growth Edge:
The main growth edge is $softest, because that area can become the future friction point. This match needs repeated behavior, not only strong feeling.

Bhrigu Warning:
Do not confuse intensity with peace, because a bond can feel powerful and still require maturity before it becomes safe.

Bhrigu's Guidance:
Move slowly and observe whether their actions match the feeling they create in you.''';
  }
}
