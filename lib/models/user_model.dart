import '../constants/ai_response_language.dart';

class UserModel {
  final String name;
  final DateTime dob;
  final String timeOfBirth;
  final String placeOfBirth;
  final double? latitude;
  final double? longitude;
  final String aiResponseLanguage;

  UserModel({
    required this.name,
    required this.dob,
    required this.timeOfBirth,
    required this.placeOfBirth,
    this.latitude,
    this.longitude,
    this.aiResponseLanguage = englishAiResponseLanguage,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'dob': dob.toIso8601String(),
        'timeOfBirth': timeOfBirth,
        'placeOfBirth': placeOfBirth,
        'latitude': latitude,
        'longitude': longitude,
        'aiResponseLanguage': normalizeAiResponseLanguage(aiResponseLanguage),
        'createdAt': DateTime.now().toIso8601String(),
      };
}
