import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_messages.dart';
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
${marriageGunaMatch.items.map((item) => '- ${item.name}: ${item.score}/${item.maxScore} — ${item.meaning}').join('\n')}

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
      final idToken = await _session.idToken();

      if (idToken == null) {
        throw Exception(missingFirebaseIdTokenMessage);
      }

      final callable = _functions.httpsCallable(
        'generatePartnerMatchReading',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 180),
        ),
      );

      final response = await callable.call(
        {
          'idToken': idToken,
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
              marriageGunaMatch: marriageGunaMatch,
              connectionType: connectionType,
              verdict: verdict,
              aiResponseLanguage: responseLanguage,
            ),
        aiResponseLanguage: responseLanguage,
      );
    } catch (e) {
      debugPrint('Partner match Groq error: $e');

      return _PartnerMatchReadingResult(
        text: normalizeAiResponseLanguage(aiResponseLanguage) ==
                hinglishAiResponseLanguage
            ? _fallbackReading(
                user: user,
                partner: partner,
                marriageGunaMatch: marriageGunaMatch,
                connectionType: connectionType,
                verdict: verdict,
                aiResponseLanguage: aiResponseLanguage,
              )
            : '''Verdict:
${partner.name} and ${user.name} show $verdict through a $connectionType pattern. This bond has a clear emotional shape rather than being random.

36 Guna Marriage Match:
${marriageGunaMatch.totalScore}/${marriageGunaMatch.maxScore} - ${marriageGunaMatch.level}
${marriageGunaMatch.summary}

Heart Signal:
"${partner.emotionalPrompt}"
These exact words show what your heart is reacting to before your mind fully explains the connection.

Emotional Bond:
The emotional pattern suggests that both people may feel a real pull, but the ease of understanding depends on patience and emotional clarity. If the bond feels intense, both people need to slow down enough to understand what is actually being felt.

Attraction:
The attraction pattern shows that chemistry is present in the connection. Strong pull can create closeness, but it should not be mistaken for emotional safety by itself.

Long-Term Potential:
The long-term potential depends on communication, consistency, and how both people behave under real pressure. This connection needs honesty more than fantasy.

Bhrigu Warning:
Do not confuse intensity with peace, because a bond can feel powerful and still require maturity before it becomes safe.''',
        aiResponseLanguage: aiResponseLanguage,
      );
    }
  }

  String _fallbackReading({
    required PartnerBirthProfile user,
    required PartnerBirthProfile partner,
    required MarriageGunaMatch marriageGunaMatch,
    required String connectionType,
    required String verdict,
    required String aiResponseLanguage,
  }) {
    if (normalizeAiResponseLanguage(aiResponseLanguage) ==
        hinglishAiResponseLanguage) {
      return '''Verdict:
${partner.name} aur ${user.name} ka connection $verdict dikhata hai, $connectionType pattern ke through. Yeh bond random nahi lagta; isme ek clear emotional shape hai.

36 Guna Marriage Match:
${marriageGunaMatch.totalScore}/${marriageGunaMatch.maxScore} - ${marriageGunaMatch.level}
${marriageGunaMatch.summary}

Heart Signal:
"${partner.emotionalPrompt}"
Yeh exact words dikhate hain ki aapka heart kis cheez par react kar raha hai, mind ke fully explain karne se pehle.

Emotional Bond:
Emotional pattern real pull dikhata hai, lekin samajh aur comfort patience par depend karega. Agar bond intense feel ho raha hai, dono logon ko slow down karke actual feelings samajhni hongi.

Attraction:
Attraction present hai. Strong pull closeness create kar sakta hai, lekin usse emotional safety ka proof mat samjhiye.

Long-Term Potential:
Long-term potential communication, consistency, aur pressure ke time behavior par depend karta hai. Is connection ko fantasy se zyada honesty chahiye.

Bhrigu Warning:
Intensity ko peace samajhne ki mistake mat kijiye; powerful bond bhi mature hone se pehle safe nahi hota.''';
    }

    return '''Verdict:
${partner.name} and ${user.name} show $verdict through a $connectionType pattern. This bond has a clear emotional shape rather than being random.

36 Guna Marriage Match:
${marriageGunaMatch.totalScore}/${marriageGunaMatch.maxScore} - ${marriageGunaMatch.level}
${marriageGunaMatch.summary}

Heart Signal:
"${partner.emotionalPrompt}"
These exact words show what your heart is reacting to before your mind fully explains the connection.

Emotional Bond:
The emotional pattern suggests that both people may feel a real pull, but the ease of understanding depends on patience and emotional clarity. If the bond feels intense, both people need to slow down enough to understand what is actually being felt.

Attraction:
The attraction pattern shows that chemistry is present in the connection. Strong pull can create closeness, but it should not be mistaken for emotional safety by itself.

Long-Term Potential:
The long-term potential depends on communication, consistency, and how both people behave under real pressure. This connection needs honesty more than fantasy.

Bhrigu Warning:
Do not confuse intensity with peace, because a bond can feel powerful and still require maturity before it becomes safe.''';
  }
}
