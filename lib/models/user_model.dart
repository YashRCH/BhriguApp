class UserModel {
  final String name;
  final DateTime dob;
  final String timeOfBirth;
  final String placeOfBirth;
  final double? latitude;
  final double? longitude;

  UserModel({
    required this.name,
    required this.dob,
    required this.timeOfBirth,
    required this.placeOfBirth,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'dob': dob.toIso8601String(),
        'timeOfBirth': timeOfBirth,
        'placeOfBirth': placeOfBirth,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': DateTime.now().toIso8601String(),
      };
}
