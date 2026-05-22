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
      degree: (json['degree'] ?? 0).toDouble(),
      house: json['house'] ?? 0,
      symbol: json['symbol'] ?? '',
      retrograde: json['retrograde'] ?? false,
    );
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