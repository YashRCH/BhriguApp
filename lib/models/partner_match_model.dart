import '../constants/ai_response_language.dart';

class PartnerBirthProfile {
  final String name;
  final DateTime dob;
  final String timeOfBirth;
  final String placeOfBirth;
  final double? latitude;
  final double? longitude;
  final String emotionalPrompt;

  const PartnerBirthProfile({
    required this.name,
    required this.dob,
    required this.timeOfBirth,
    required this.placeOfBirth,
    this.latitude,
    this.longitude,
    required this.emotionalPrompt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'dob': dob.toIso8601String(),
        'timeOfBirth': timeOfBirth,
        'placeOfBirth': placeOfBirth,
        'latitude': latitude,
        'longitude': longitude,
        'emotionalPrompt': emotionalPrompt,
      };

  factory PartnerBirthProfile.fromJson(Map<String, dynamic> json) {
    return PartnerBirthProfile(
      name: json['name'] as String? ?? '',
      dob: DateTime.tryParse(json['dob'] as String? ?? '') ?? DateTime.now(),
      timeOfBirth: json['timeOfBirth'] as String? ?? '',
      placeOfBirth: json['placeOfBirth'] as String? ?? '',
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
      emotionalPrompt: json['emotionalPrompt'] as String? ?? '',
    );
  }

  static double? _doubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class CompatibilityScores {
  final int overall;
  final int emotional;
  final int attraction;
  final int communication;
  final int stability;
  final int karmic;

  const CompatibilityScores({
    required this.overall,
    required this.emotional,
    required this.attraction,
    required this.communication,
    required this.stability,
    required this.karmic,
  });

  CompatibilityScores copyWith({
    int? overall,
    int? emotional,
    int? attraction,
    int? communication,
    int? stability,
    int? karmic,
  }) {
    return CompatibilityScores(
      overall: overall ?? this.overall,
      emotional: emotional ?? this.emotional,
      attraction: attraction ?? this.attraction,
      communication: communication ?? this.communication,
      stability: stability ?? this.stability,
      karmic: karmic ?? this.karmic,
    );
  }

  Map<String, dynamic> toJson() => {
        'overall': overall,
        'emotional': emotional,
        'attraction': attraction,
        'communication': communication,
        'stability': stability,
        'karmic': karmic,
      };

  factory CompatibilityScores.fromJson(Map<String, dynamic> json) {
    return CompatibilityScores(
      overall: _intFromValue(json['overall']),
      emotional: _intFromValue(json['emotional']),
      attraction: _intFromValue(json['attraction']),
      communication: _intFromValue(json['communication']),
      stability: _intFromValue(json['stability']),
      karmic: _intFromValue(json['karmic']),
    );
  }
}

class GunaScoreItem {
  final String name;
  final int score;
  final int maxScore;
  final String meaning;

  const GunaScoreItem({
    required this.name,
    required this.score,
    required this.maxScore,
    required this.meaning,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'maxScore': maxScore,
        'meaning': meaning,
      };

  factory GunaScoreItem.fromJson(Map<String, dynamic> json) {
    return GunaScoreItem(
      name: json['name'] as String? ?? '',
      score: _intFromValue(json['score']),
      maxScore: _intFromValue(json['maxScore']),
      meaning: json['meaning'] as String? ?? '',
    );
  }
}

class MarriageGunaMatch {
  final int totalScore;
  final int maxScore;
  final String level;
  final String summary;
  final List<GunaScoreItem> items;

  const MarriageGunaMatch({
    required this.totalScore,
    required this.maxScore,
    required this.level,
    required this.summary,
    required this.items,
  });

  static const MarriageGunaMatch empty = MarriageGunaMatch(
    totalScore: 0,
    maxScore: 36,
    level: '',
    summary: '',
    items: [],
  );

  double get percentage {
    if (maxScore <= 0) return 0;
    return totalScore / maxScore;
  }

  Map<String, dynamic> toJson() => {
        'totalScore': totalScore,
        'maxScore': maxScore,
        'level': level,
        'summary': summary,
        'items': items.map((item) => item.toJson()).toList(),
      };

  factory MarriageGunaMatch.fromJson(Map<String, dynamic> json) {
    return MarriageGunaMatch(
      totalScore: _intFromValue(json['totalScore']),
      maxScore: _intFromValue(json['maxScore'], fallback: 36),
      level: json['level'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      items: ((json['items'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => GunaScoreItem.fromJson(_mapFromValue(item)))
          .toList(),
    );
  }
}

class PartnerMatchReading {
  final PartnerBirthProfile user;
  final PartnerBirthProfile partner;
  final CompatibilityScores scores;
  final MarriageGunaMatch marriageGunaMatch;
  final String userSunSign;
  final String partnerSunSign;
  final String userMoonStyle;
  final String partnerMoonStyle;
  final String connectionType;
  final String verdict;
  final String summary;
  final DateTime createdAt;
  final String aiResponseLanguage;

  const PartnerMatchReading({
    required this.user,
    required this.partner,
    required this.scores,
    this.marriageGunaMatch = MarriageGunaMatch.empty,
    required this.userSunSign,
    required this.partnerSunSign,
    required this.userMoonStyle,
    required this.partnerMoonStyle,
    required this.connectionType,
    required this.verdict,
    required this.summary,
    required this.createdAt,
    this.aiResponseLanguage = englishAiResponseLanguage,
  });

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'partner': partner.toJson(),
        'scores': scores.toJson(),
        'marriageGunaMatch': marriageGunaMatch.toJson(),
        'userSunSign': userSunSign,
        'partnerSunSign': partnerSunSign,
        'userMoonStyle': userMoonStyle,
        'partnerMoonStyle': partnerMoonStyle,
        'connectionType': connectionType,
        'verdict': verdict,
        'summary': summary,
        'createdAt': createdAt.toIso8601String(),
        'aiResponseLanguage': normalizeAiResponseLanguage(aiResponseLanguage),
      };

  factory PartnerMatchReading.fromJson(Map<String, dynamic> json) {
    return PartnerMatchReading(
      user: PartnerBirthProfile.fromJson(
        _mapFromValue(json['user']),
      ),
      partner: PartnerBirthProfile.fromJson(
        _mapFromValue(json['partner']),
      ),
      scores: CompatibilityScores.fromJson(
        _mapFromValue(json['scores']),
      ),
      marriageGunaMatch: json['marriageGunaMatch'] == null
          ? MarriageGunaMatch.empty
          : MarriageGunaMatch.fromJson(
              _mapFromValue(json['marriageGunaMatch']),
            ),
      userSunSign: json['userSunSign'] as String? ?? '',
      partnerSunSign: json['partnerSunSign'] as String? ?? '',
      userMoonStyle: json['userMoonStyle'] as String? ?? '',
      partnerMoonStyle: json['partnerMoonStyle'] as String? ?? '',
      connectionType: json['connectionType'] as String? ?? '',
      verdict: json['verdict'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      aiResponseLanguage: normalizeAiResponseLanguage(
        json['aiResponseLanguage'],
      ),
    );
  }
}

int _intFromValue(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return num.tryParse(value)?.round() ?? fallback;
  return fallback;
}

Map<String, dynamic> _mapFromValue(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
