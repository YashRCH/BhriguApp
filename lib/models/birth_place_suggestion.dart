class BirthPlaceSuggestion {
  final String description;
  final double? latitude;
  final double? longitude;

  const BirthPlaceSuggestion({
    required this.description,
    this.latitude,
    this.longitude,
  });

  factory BirthPlaceSuggestion.fromMap(Map<String, dynamic> json) {
    return BirthPlaceSuggestion(
      description: json['description'] as String? ?? '',
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
    );
  }

  static double? _doubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
