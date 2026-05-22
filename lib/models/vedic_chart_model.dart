import 'planet_model.dart';

class VedicChartModel {
  final String ascendant;
  final String moonSign;
  final String nakshatra;

  final List<PlanetModel> planets;

  VedicChartModel({
    required this.ascendant,
    required this.moonSign,
    required this.nakshatra,
    required this.planets,
  });

  factory VedicChartModel.fromJson(Map<String, dynamic> json) {
    return VedicChartModel(
      ascendant: json['ascendant'] ?? '',
      moonSign: json['moonSign'] ?? '',
      nakshatra: json['nakshatra'] ?? '',
      planets: (json['planets'] as List<dynamic>? ?? [])
          .map((e) => PlanetModel.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ascendant': ascendant,
      'moonSign': moonSign,
      'nakshatra': nakshatra,
      'planets': planets.map((e) => e.toJson()).toList(),
    };
  }
}