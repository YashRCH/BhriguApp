import 'planet_model.dart';

class WesternChartModel {
  final String sunSign;
  final String moonSign;
  final String risingSign;

  final List<PlanetModel> planets;
  final List<String> aspects;

  WesternChartModel({
    required this.sunSign,
    required this.moonSign,
    required this.risingSign,
    required this.planets,
    this.aspects = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'sunSign': sunSign,
      'moonSign': moonSign,
      'risingSign': risingSign,
      'planets': planets.map((planet) => planet.toJson()).toList(),
      'aspects': aspects,
    };
  }

  factory WesternChartModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return WesternChartModel(
      sunSign: json['sunSign'] ?? '',
      moonSign: json['moonSign'] ?? '',
      risingSign: json['risingSign'] ?? '',
      planets: (json['planets'] as List<dynamic>? ?? [])
          .map(
            (planet) => PlanetModel.fromJson(
              Map<String, dynamic>.from(planet),
            ),
          )
          .toList(),
      aspects: (json['aspects'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
