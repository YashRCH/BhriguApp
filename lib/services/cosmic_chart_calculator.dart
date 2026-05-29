import 'dart:math';

import '../models/planet_model.dart';
import '../models/vedic_chart_model.dart';
import '../models/western_chart_model.dart';

class CosmicChartResult {
  final WesternChartModel westernChart;
  final VedicChartModel vedicChart;

  const CosmicChartResult({
    required this.westernChart,
    required this.vedicChart,
  });
}

class CosmicChartCalculator {
  static const signs = [
    'Aries',
    'Taurus',
    'Gemini',
    'Cancer',
    'Leo',
    'Virgo',
    'Libra',
    'Scorpio',
    'Sagittarius',
    'Capricorn',
    'Aquarius',
    'Pisces',
  ];

  static const nakshatras = [
    'Ashwini',
    'Bharani',
    'Krittika',
    'Rohini',
    'Mrigashira',
    'Ardra',
    'Punarvasu',
    'Pushya',
    'Ashlesha',
    'Magha',
    'Purva Phalguni',
    'Uttara Phalguni',
    'Hasta',
    'Chitra',
    'Swati',
    'Vishakha',
    'Anuradha',
    'Jyeshtha',
    'Mula',
    'Purva Ashadha',
    'Uttara Ashadha',
    'Shravana',
    'Dhanishta',
    'Shatabhisha',
    'Purva Bhadrapada',
    'Uttara Bhadrapada',
    'Revati',
  ];

  const CosmicChartCalculator();

  CosmicChartResult calculate({
    required DateTime birthDate,
    required String timeOfBirth,
    required String placeOfBirth,
    double? latitude,
    double? longitude,
  }) {
    final place = _coordinatesFor(
      placeOfBirth: placeOfBirth,
      latitude: latitude,
      longitude: longitude,
    );
    final utcBirth = _estimatedUtcBirth(
      birthDate: birthDate,
      timeOfBirth: timeOfBirth,
      longitude: place?.longitude,
    );
    final days = _daysSinceJ2000(utcBirth);
    final ayanamsa = _lahiriAyanamsa(days);
    final localSolarMinutes = _localSolarMinutes(
      timeOfBirth,
      place?.longitude,
    );

    final tropicalBodies = _tropicalBodies(days);
    final tropicalAscendant = _ascendantLongitude(
      sunLongitude: tropicalBodies['Sun']!,
      localSolarMinutes: localSolarMinutes,
      latitude: place?.latitude,
      sidereal: false,
      ayanamsa: ayanamsa,
    );
    final siderealAscendant = _normalizeDegrees(
      tropicalAscendant - ayanamsa,
    );

    final westernPlanets = _planetModels(
      longitudes: tropicalBodies,
      ascendantLongitude: tropicalAscendant,
      sidereal: false,
      daysSinceJ2000: days,
    );

    final tropicalRahu = _meanLunarNodeLongitude(days);
    final siderealRahu = _normalizeDegrees(tropicalRahu - ayanamsa);
    final siderealBodies = <String, double>{
      for (final entry in tropicalBodies.entries)
        entry.key: _normalizeDegrees(entry.value - ayanamsa),
      'Rahu': siderealRahu,
      'Ketu': _normalizeDegrees(siderealRahu + 180),
    };
    final vedicPlanets = _planetModels(
      longitudes: siderealBodies,
      ascendantLongitude: siderealAscendant,
      sidereal: true,
      daysSinceJ2000: days,
    );

    final westernSunSign = _signName(tropicalBodies['Sun']!);
    final westernMoonSign = _signName(tropicalBodies['Moon']!);
    final westernRisingSign = _signName(tropicalAscendant);
    final vedicMoon = siderealBodies['Moon']!;

    final aspects = <String>[];
    final planetKeys = tropicalBodies.keys.toList();
    for (int i = 0; i < planetKeys.length; i++) {
      for (int j = i + 1; j < planetKeys.length; j++) {
        final p1 = planetKeys[i];
        final p2 = planetKeys[j];
        final deg1 = tropicalBodies[p1]!;
        final deg2 = tropicalBodies[p2]!;
        final dist = ((deg1 - deg2).abs() % 360);
        final shortestDist = dist > 180 ? 360 - dist : dist;
        
        if ((shortestDist - 60).abs() <= 6) {
          aspects.add('$p1 Sextile $p2');
        } else if ((shortestDist - 90).abs() <= 8) aspects.add('$p1 Square $p2');
        else if ((shortestDist - 120).abs() <= 8) aspects.add('$p1 Trine $p2');
        else if ((shortestDist - 180).abs() <= 8) aspects.add('$p1 Opposition $p2');
        else if (shortestDist <= 8) aspects.add('$p1 Conjunction $p2');
      }
    }

    return CosmicChartResult(
      westernChart: WesternChartModel(
        sunSign: westernSunSign,
        moonSign: westernMoonSign,
        risingSign: westernRisingSign,
        planets: westernPlanets,
        aspects: aspects,
      ),
      vedicChart: VedicChartModel(
        ascendant: _signName(siderealAscendant),
        moonSign: _signName(vedicMoon),
        nakshatra:
            nakshatras[(vedicMoon / (360 / 27)).floor().clamp(0, 26).toInt()],
        planets: vedicPlanets,
      ),
    );
  }

  Map<String, double> _tropicalBodies(double daysSinceJ2000) {
    final sun = _sunLongitude(daysSinceJ2000);
    final moon = _moonLongitude(daysSinceJ2000);

    return {
      'Sun': sun,
      'Moon': moon,
      'Mercury': _innerPlanetLongitude(
        daysSinceJ2000,
        base: 252.25084,
        motion: 4.09233445,
        amplitude: 23,
        solarLongitude: sun,
      ),
      'Venus': _innerPlanetLongitude(
        daysSinceJ2000,
        base: 181.97973,
        motion: 1.60213034,
        amplitude: 46,
        solarLongitude: sun,
      ),
      'Mars': _outerPlanetLongitude(
        daysSinceJ2000,
        base: 355.433,
        motion: 0.5240207766,
        amplitude: 11,
        solarLongitude: sun,
      ),
      'Jupiter': _outerPlanetLongitude(
        daysSinceJ2000,
        base: 34.351,
        motion: 0.08308529,
        amplitude: 6,
        solarLongitude: sun,
      ),
      'Saturn': _outerPlanetLongitude(
        daysSinceJ2000,
        base: 50.077,
        motion: 0.03345965,
        amplitude: 6,
        solarLongitude: sun,
      ),
    };
  }

  List<PlanetModel> _planetModels({
    required Map<String, double> longitudes,
    required double ascendantLongitude,
    required bool sidereal,
    required double daysSinceJ2000,
  }) {
    const symbols = {
      'Sun': '☉',
      'Moon': '☽',
      'Mercury': '☿',
      'Venus': '♀',
      'Mars': '♂',
      'Jupiter': '♃',
      'Saturn': '♄',
    };

    const nodeSymbols = {
      'Rahu': '☊',
      'Ketu': '☋',
    };

    return longitudes.entries.map((entry) {
      final longitude = entry.value;
      final signIndex = _signIndex(longitude);
      final signStart = signIndex * 30;
      final house = _wholeSignHouse(longitude, ascendantLongitude);

      return PlanetModel(
        name: entry.key,
        symbol: symbols[entry.key] ?? nodeSymbols[entry.key] ?? '*',
        sign: signs[signIndex],
        degree: _normalizeDegrees(longitude - signStart),
        house: house,
        retrograde: _isRetrograde(
          entry.key,
          daysSinceJ2000: daysSinceJ2000,
          sidereal: sidereal,
        ),
      );
    }).toList();
  }

  double _sunLongitude(double daysSinceJ2000) {
    final meanLongitude = _normalizeDegrees(
      280.46646 + (0.98564736 * daysSinceJ2000),
    );
    final meanAnomaly = _normalizeDegrees(
      357.52911 + (0.98560028 * daysSinceJ2000),
    );
    final center = (1.914602 * _sinDeg(meanAnomaly)) +
        (0.019993 * _sinDeg(2 * meanAnomaly)) +
        (0.000289 * _sinDeg(3 * meanAnomaly));

    return _normalizeDegrees(meanLongitude + center);
  }

  double _moonLongitude(double daysSinceJ2000) {
    final meanLongitude = _normalizeDegrees(
      218.3164477 + (13.17639648 * daysSinceJ2000),
    );
    final meanAnomaly = _normalizeDegrees(
      134.9633964 + (13.06499295 * daysSinceJ2000),
    );
    final elongation = _normalizeDegrees(
      297.8501921 + (12.19074912 * daysSinceJ2000),
    );
    final sunAnomaly = _normalizeDegrees(
      357.5291092 + (0.98560028 * daysSinceJ2000),
    );

    return _normalizeDegrees(
      meanLongitude +
          (6.289 * _sinDeg(meanAnomaly)) +
          (1.274 * _sinDeg((2 * elongation) - meanAnomaly)) +
          (0.658 * _sinDeg(2 * elongation)) +
          (0.214 * _sinDeg(2 * meanAnomaly)) -
          (0.186 * _sinDeg(sunAnomaly)),
    );
  }

  double _meanLunarNodeLongitude(double daysSinceJ2000) {
    final t = daysSinceJ2000 / 36525;
    final t2 = t * t;
    final t3 = t2 * t;
    final t4 = t3 * t;

    return _normalizeDegrees(
      125.04455501 -
          (1934.1361849 * t) +
          (0.0020762 * t2) +
          (t3 / 467410) -
          (t4 / 60616000),
    );
  }

  double _innerPlanetLongitude(
    double daysSinceJ2000, {
    required double base,
    required double motion,
    required double amplitude,
    required double solarLongitude,
  }) {
    final mean = _normalizeDegrees(base + (motion * daysSinceJ2000));
    final elongation = _signedAngularDistance(mean, solarLongitude);
    final limitedElongation = elongation.clamp(-amplitude, amplitude);
    return _normalizeDegrees(solarLongitude + limitedElongation);
  }

  double _outerPlanetLongitude(
    double daysSinceJ2000, {
    required double base,
    required double motion,
    required double amplitude,
    required double solarLongitude,
  }) {
    final mean = _normalizeDegrees(base + (motion * daysSinceJ2000));
    final anomaly = _signedAngularDistance(mean, solarLongitude);
    return _normalizeDegrees(mean + (amplitude * _sinDeg(anomaly)));
  }

  double _ascendantLongitude({
    required double sunLongitude,
    required int localSolarMinutes,
    required double? latitude,
    required bool sidereal,
    required double ayanamsa,
  }) {
    final sunriseRelativeMinutes =
        ((localSolarMinutes - 360) % 1440 + 1440) % 1440;
    final latitudeCorrection =
        latitude == null ? 0 : latitude.clamp(-66, 66) * 0.28;
    final longitude = sunLongitude +
        ((sunriseRelativeMinutes / 1440) * 360) +
        latitudeCorrection;

    return _normalizeDegrees(sidereal ? longitude - ayanamsa : longitude);
  }

  DateTime _estimatedUtcBirth({
    required DateTime birthDate,
    required String timeOfBirth,
    required double? longitude,
  }) {
    final birthMinutes = _parseBirthMinutes(timeOfBirth);
    final longitudeOffsetMinutes = ((longitude ?? 0) * 4).round();
    final localDate = DateTime.utc(
      birthDate.year,
      birthDate.month,
      birthDate.day,
    );

    return localDate.add(
      Duration(minutes: birthMinutes - longitudeOffsetMinutes),
    );
  }

  double _daysSinceJ2000(DateTime utcBirth) {
    final j2000 = DateTime.utc(2000, 1, 1, 12);
    return utcBirth.difference(j2000).inMilliseconds / 86400000;
  }

  double _lahiriAyanamsa(double daysSinceJ2000) {
    return 23.8531 + ((daysSinceJ2000 / 36525) * 1.396);
  }

  int _localSolarMinutes(String time, double? longitude) {
    final clockMinutes = _parseBirthMinutes(time);
    final longitudeOffset = longitude == null ? 0 : (longitude * 4).round();
    final rawMinutes = clockMinutes + longitudeOffset;
    return ((rawMinutes % 1440) + 1440) % 1440;
  }

  int _parseBirthMinutes(String time) {
    final normalized = time.trim().toUpperCase();
    final match = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(normalized);

    if (match == null) return 720;

    var hour = int.tryParse(match.group(1) ?? '') ?? 12;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final isPm = normalized.contains('PM');
    final isAm = normalized.contains('AM');

    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    return ((hour.clamp(0, 23) * 60) + minute.clamp(0, 59)) % 1440;
  }

  int _wholeSignHouse(double longitude, double ascendantLongitude) {
    final planetSign = _signIndex(longitude);
    final ascendantSign = _signIndex(ascendantLongitude);
    return ((planetSign - ascendantSign + 12) % 12) + 1;
  }

  bool _isRetrograde(
    String planetName, {
    required double daysSinceJ2000,
    required bool sidereal,
  }) {
    if (planetName == 'Rahu' || planetName == 'Ketu') return true;
    if (planetName == 'Sun' || planetName == 'Moon') return false;

    final cycle = switch (planetName) {
      'Mercury' => 116.0,
      'Venus' => 584.0,
      'Mars' => 780.0,
      'Jupiter' => 399.0,
      'Saturn' => 378.0,
      _ => 365.25,
    };
    final phase = _normalizeDegrees((daysSinceJ2000 / cycle) * 360);
    final retrogradeWindow = switch (planetName) {
      'Mercury' => 26.0,
      'Venus' => 18.0,
      'Mars' => 36.0,
      'Jupiter' => 54.0,
      'Saturn' => 56.0,
      _ => 30.0,
    };
    final center = sidereal ? 190.0 : 180.0;

    return _signedAngularDistance(phase, center).abs() <= retrogradeWindow;
  }

  int _signIndex(double longitude) {
    return (_normalizeDegrees(longitude) / 30).floor().clamp(0, 11).toInt();
  }

  String _signName(double longitude) {
    return signs[_signIndex(longitude)];
  }

  double _signedAngularDistance(double a, double b) {
    return ((_normalizeDegrees(a - b) + 540) % 360) - 180;
  }

  double _sinDeg(double degrees) => sin(degrees * pi / 180);

  double _normalizeDegrees(double value) {
    return ((value % 360) + 360) % 360;
  }

  _BirthCoordinates? _coordinatesFor({
    required String placeOfBirth,
    required double? latitude,
    required double? longitude,
  }) {
    if (latitude != null && longitude != null) {
      return _BirthCoordinates(latitude: latitude, longitude: longitude);
    }

    return _knownCoordinates(placeOfBirth);
  }

  _BirthCoordinates? _knownCoordinates(String place) {
    final normalized = place.toLowerCase();

    const known = <String, _BirthCoordinates>{
      'new delhi': _BirthCoordinates(latitude: 28.6139, longitude: 77.2090),
      'delhi': _BirthCoordinates(latitude: 28.6139, longitude: 77.2090),
      'mumbai': _BirthCoordinates(latitude: 19.0760, longitude: 72.8777),
      'bengaluru': _BirthCoordinates(latitude: 12.9716, longitude: 77.5946),
      'bangalore': _BirthCoordinates(latitude: 12.9716, longitude: 77.5946),
      'kolkata': _BirthCoordinates(latitude: 22.5726, longitude: 88.3639),
      'chennai': _BirthCoordinates(latitude: 13.0827, longitude: 80.2707),
      'hyderabad': _BirthCoordinates(latitude: 17.3850, longitude: 78.4867),
      'pune': _BirthCoordinates(latitude: 18.5204, longitude: 73.8567),
      'ahmedabad': _BirthCoordinates(latitude: 23.0225, longitude: 72.5714),
      'jaipur': _BirthCoordinates(latitude: 26.9124, longitude: 75.7873),
      'lucknow': _BirthCoordinates(latitude: 26.8467, longitude: 80.9462),
      'varanasi': _BirthCoordinates(latitude: 25.3176, longitude: 82.9739),
      'london': _BirthCoordinates(latitude: 51.5074, longitude: -0.1278),
      'new york': _BirthCoordinates(latitude: 40.7128, longitude: -74.0060),
      'los angeles': _BirthCoordinates(latitude: 34.0522, longitude: -118.2437),
      'chicago': _BirthCoordinates(latitude: 41.8781, longitude: -87.6298),
      'toronto': _BirthCoordinates(latitude: 43.6532, longitude: -79.3832),
      'sydney': _BirthCoordinates(latitude: -33.8688, longitude: 151.2093),
      'melbourne': _BirthCoordinates(latitude: -37.8136, longitude: 144.9631),
      'singapore': _BirthCoordinates(latitude: 1.3521, longitude: 103.8198),
      'dubai': _BirthCoordinates(latitude: 25.2048, longitude: 55.2708),
    };

    for (final entry in known.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }
}

class _BirthCoordinates {
  final double latitude;
  final double longitude;

  const _BirthCoordinates({
    required this.latitude,
    required this.longitude,
  });
}
