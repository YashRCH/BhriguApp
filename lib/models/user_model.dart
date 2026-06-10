import '../constants/ai_response_language.dart';

class UserModel {
  final String name;
  final String username;
  final DateTime dob;
  final String timeOfBirth;
  final String placeOfBirth;
  final double? latitude;
  final double? longitude;
  final String aiResponseLanguage;
  final List<String> fcmTokens;

  UserModel({
    required this.name,
    required this.dob,
    required this.timeOfBirth,
    required this.placeOfBirth,
    this.username = '',
    this.latitude,
    this.longitude,
    this.aiResponseLanguage = englishAiResponseLanguage,
    this.fcmTokens = const [],
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'username': _cleanUsername(username),
        'usernameLower': _cleanUsername(username),
        'dob': dob.toIso8601String(),
        'timeOfBirth': timeOfBirth,
        'placeOfBirth': placeOfBirth,
        'latitude': latitude,
        'longitude': longitude,
        'aiResponseLanguage': normalizeAiResponseLanguage(aiResponseLanguage),
        'onboardingComplete': false,
        'createdAt': DateTime.now().toIso8601String(),
      };
}

String _cleanUsername(String value) {
  return value.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
}
