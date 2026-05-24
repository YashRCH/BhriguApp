class PlanetModel {
  final String name;
  final String sign;
  final double degree;
  final int house;
  final String symbol;
  final bool retrograde;

  PlanetModel({
    required this.name,
    required this.sign,
    required this.degree,
    required this.house,
    required this.symbol,
    required this.retrograde,
  });

  factory PlanetModel.fromJson(Map<String, dynamic> json) {
    return PlanetModel(
      name: json['name'] ?? '',
      sign: json['sign'] ?? '',
      degree: _doubleFromJson(json['degree']),
      house: _intFromJson(json['house']),
      symbol: json['symbol'] ?? '',
      retrograde: _boolFromJson(json['retrograde']),
    );
  }

  static double _doubleFromJson(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _intFromJson(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _boolFromJson(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sign': sign,
      'degree': degree,
      'house': house,
      'symbol': symbol,
      'retrograde': retrograde,
    };
  }
}
