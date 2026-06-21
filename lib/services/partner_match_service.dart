import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../constants/ai_response_language.dart';
import '../constants/firebase_constants.dart';
import '../models/partner_match_model.dart';
import '../utils/cloud_function_error_messages.dart';
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
    required String aiResponseLanguage,
  }) async {
    try {
      if (await _session.currentUserOrWait() == null) {
        throw const FeatureAccessException(
          'Please sign in again to continue.',
        );
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
          'aiResponseLanguage': aiResponseLanguage,
        },
      );

      final data = Map<String, dynamic>.from(
        response.data as Map,
      );

      final responseLanguage = normalizeAiResponseLanguage(
        data['aiResponseLanguage'] ?? aiResponseLanguage,
      );
      final text = data['text'] as String?;

      if (text == null || text.trim().isEmpty) {
        throw StateError('Partner match function returned an empty reading.');
      }

      return _PartnerMatchReadingResult(
        text: text,
        aiResponseLanguage: responseLanguage,
      );
    } on FeatureAccessException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('Partner match function code: ${e.code}');
        debugPrint('Partner match function message: ${e.message}');
        debugPrint('Partner match function details: ${e.details}');
      }
      throw featureAccessExceptionFrom(e);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Partner match AI error: $e');
      }

      throw Exception('Could not create this match reading.');
    }
  }
}
