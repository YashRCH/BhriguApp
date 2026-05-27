import 'package:flutter/material.dart';

class PlanetAsset extends StatelessWidget {
  const PlanetAsset({
    super.key,
    required this.planetName,
    this.size = 40,
    this.fallback,
  });

  final String planetName;
  final double size;
  final Widget? fallback;

  static const Map<String, String> _assetPaths = {
    'sun': 'assets/planets/planet_sun.jpg',
    'moon': 'assets/planets/planet_moon.jpg',
    'mercury': 'assets/planets/planet_mercury.jpg',
    'venus': 'assets/planets/planet_venus.jpg',
    'earth': 'assets/planets/planet_earth.jpg',
    'mars': 'assets/planets/planet_mars.jpg',
    'jupiter': 'assets/planets/planet_jupiter.jpg',
    'saturn': 'assets/planets/planet_saturn.jpg',
    'uranus': 'assets/planets/planet_uranus.jpg',
    'neptune': 'assets/planets/planet_neptune.jpg',
    'pluto': 'assets/planets/planet_pluto.jpg',
  };

  static String? assetPathForPlanet(String? planetName) {
    final key = planetName?.trim().toLowerCase();
    if (key == null || key.isEmpty) return null;

    return _assetPaths[key];
  }

  @override
  Widget build(BuildContext context) {
    final path = assetPathForPlanet(planetName);

    if (path == null) {
      return SizedBox.square(
        dimension: size,
        child: Center(child: fallback),
      );
    }

    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: Image.asset(
          path,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: planetName,
          errorBuilder: (context, error, stackTrace) {
            return Center(child: fallback);
          },
        ),
      ),
    );
  }
}
