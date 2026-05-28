import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/user_profile_cache_service.dart';
import '../utils/zodiac_signs.dart';
import 'zodiac_sign_icon.dart';

class WesternChartCard extends StatefulWidget {
  const WesternChartCard({super.key});

  @override
  State<WesternChartCard> createState() => _WesternChartCardState();
}

class _WesternChartCardState extends State<WesternChartCard>
    with SingleTickerProviderStateMixin {
  static const double _chartLogicalSize = 300;
  static const double _chartDisplayMaxSize = 520;

  late AnimationController _rotationController;
  Map<String, ui.Image> _zodiacImages = {};

  bool loading = true;

  String sunSign = '—';
  String moonSign = '—';
  String risingSign = '—';
  List<Map<String, dynamic>> planets = [];

  @override
  void initState() {
    super.initState();

    // Slow, majestic rotation
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 80),
    )..repeat();

    _loadZodiacImages();
    _loadWesternChart();
  }

  Future<void> _loadZodiacImages() async {
    final images = <String, ui.Image>{};

    try {
      for (final sign in zodiacSignNames) {
        final path = zodiacAssetPath(sign);
        if (path == null) continue;

        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        images[sign] = frame.image;
      }
    } catch (e) {
      debugPrint('Zodiac asset load failed: $e');
      for (final image in images.values) {
        image.dispose();
      }
      return;
    }

    if (!mounted) {
      for (final image in images.values) {
        image.dispose();
      }
      return;
    }

    setState(() {
      for (final image in _zodiacImages.values) {
        image.dispose();
      }
      _zodiacImages = images;
    });
  }

  Future<void> _loadWesternChart() async {
    final data =
        await UserProfileCacheService.instance.userDataWithFreshCharts();
    final westernChart = _extractWesternChart(data);

    if (westernChart != null) {
      final rawPlanets = westernChart['planets'];

      if (rawPlanets is List) {
        planets = rawPlanets
            .map((planet) => Map<String, dynamic>.from(planet))
            .toList();
      }

      sunSign = westernChart['sunSign'] ?? '—';
      moonSign = westernChart['moonSign'] ?? '—';
      risingSign = westernChart['risingSign'] ?? '—';
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Map<String, dynamic>? _extractWesternChart(Map<String, dynamic>? data) {
    if (data == null) return null;

    final chart = data['westernChart'];

    if (chart is Map<String, dynamic>) {
      return chart;
    }

    if (chart is Map) {
      return Map<String, dynamic>.from(chart);
    }

    return null;
  }

  @override
  void dispose() {
    _rotationController.dispose();
    for (final image in _zodiacImages.values) {
      image.dispose();
    }
    super.dispose();
  }

  String _planetSign(String planetName) {
    for (final planet in planets) {
      if (planet['name'] == planetName) {
        return planet['sign'] ?? '—';
      }
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: const RadialGradient(
            center: Alignment(-0.5, -0.8),
            radius: 1.5,
            colors: [
              Color(0xFF2A1B4D),
              Color(0xFF0F0A18),
              Color(0xFF050408),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
          border: Border.all(
            color: const Color(0xFF9D6FE8).withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF050408).withValues(alpha: 0.8),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 14),
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF9D6FE8),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        'WESTERN\nBLUEPRINT',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cinzel(
                          color: const Color(0xFFE5D5F5),
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your celestial personality matrix',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        color: Colors.white60,
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availableWidth = constraints.maxWidth.isFinite
                              ? constraints.maxWidth
                              : _chartDisplayMaxSize;
                          final chartSize = min(
                            _chartDisplayMaxSize,
                            availableWidth,
                          );

                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                Center(
                                  child: SizedBox.square(
                                    dimension: chartSize,
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: SizedBox(
                                        width: _chartLogicalSize,
                                        height: _chartLogicalSize,
                                        child: RotationTransition(
                                          turns: _rotationController,
                                          child: CustomPaint(
                                            painter: WesternWheelPainter(
                                              planets: planets,
                                              zodiacImages: _zodiacImages,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _infoTile(
                                  '☉',
                                  'Sun',
                                  sunSign,
                                  const Color(0xFFFFD166),
                                ),
                                const SizedBox(height: 10),
                                _infoTile(
                                  '☽',
                                  'Moon',
                                  moonSign,
                                  const Color(0xFF4EEBFE),
                                ),
                                const SizedBox(height: 10),
                                _infoTile(
                                  '↑',
                                  'Rising',
                                  risingSign,
                                  const Color(0xFFC77DFF),
                                ),
                                const SizedBox(height: 10),
                                _infoTile(
                                  '♀',
                                  'Venus',
                                  _planetSign('Venus'),
                                  const Color(0xFFFE8CFE),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _infoTile(String symbol, String title, String sign, Color glowColor) {
    final showZodiacIcon = isKnownZodiacSign(sign);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1430).withValues(alpha: 0.5),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Text(
                symbol,
                style: TextStyle(
                  color: glowColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                        color: glowColor.withValues(alpha: 0.6),
                        blurRadius: 12),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFF6B6080),
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (showZodiacIcon) ...[
                          ZodiacSignIcon(
                            sign: sign,
                            size: 20,
                            fallbackColor: const Color(0xFFE5D5F5),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            sign,
                            style: GoogleFonts.cormorantGaramond(
                              color: const Color(0xFFE5D5F5),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WesternWheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> planets;
  final Map<String, ui.Image> zodiacImages;

  WesternWheelPainter({
    required this.planets,
    required this.zodiacImages,
  });

  static const Color _antiqueGold = Color(0xFFB58E34);
  static const Color _goldLine = Color(0xFFE0C48F);
  static const Color _moonlightSilver = Color(0xFFE5D5F5);
  static const Color _deepCosmicPurple = Color(0xFF2A1B4D);
  static const Color _spaceBlack = Color(0xFF0F0A18);
  static const Color _pureWhite = Colors.white;

  final List<String> houseRoman = const [
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
    'IX',
    'X',
    'XI',
    'XII',
  ];

  static const Map<String, Color> _planetColors = {
    'Sun': _antiqueGold,
    'Moon': _moonlightSilver,
    'Mercury': Color(0xFFD7CDE8),
    'Venus': Color(0xFFCFA7FF),
    'Mars': Color(0xFFD98F73),
    'Jupiter': _goldLine,
    'Saturn': Color(0xFFC7C9D9),
    'Uranus': Color(0xFFBFA6E8),
    'Neptune': Color(0xFFB7C4D8),
    'Pluto': Color(0xFFD6B577),
  };

  void _drawPremiumLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Color color, {
    double strokeWidth = 1.0,
    double glow = 0,
    double alpha = 0.7,
  }) {
    if (glow > 0) {
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.32)
          ..strokeWidth = strokeWidth + 2
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow),
      );
    }

    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawPremiumCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    double strokeWidth = 1.0,
    double glow = 0,
    double alpha = 0.75,
  }) {
    if (glow > 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.28)
          ..strokeWidth = strokeWidth + 2
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow),
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  double _getPlanetDegree(Map<String, dynamic> planet) {
    final sign = planet['sign'] ?? '';
    final signIndex = zodiacSignNames.indexOf(sign);

    final degreeRaw = planet['degree'] ?? 0;
    final degree = degreeRaw is int
        ? degreeRaw.toDouble()
        : double.tryParse(degreeRaw.toString()) ?? 0;

    final safeSignIndex = signIndex == -1 ? 0 : signIndex;
    final totalDegree = safeSignIndex * 30 + degree;
    return (totalDegree % 360 + 360) % 360;
  }

  // Extracts the absolute angle on the wheel for a given planet
  double _getPlanetAngle(Map<String, dynamic> planet) {
    return _angleForDegree(_getPlanetDegree(planet));
  }

  double _angleForDegree(double degree) {
    return degree * pi / 180 - pi / 2;
  }

  double _degreeDistance(double a, double b) {
    final diff = (a - b).abs() % 360;
    return diff > 180 ? 360 - diff : diff;
  }

  List<_WesternPlanetPlot> _planetPlots(double planetTrackRadius) {
    final plots = <_WesternPlanetPlot>[
      for (int i = 0; i < planets.length; i++)
        _WesternPlanetPlot(
          index: i,
          planet: planets[i],
          trueDegree: _getPlanetDegree(planets[i]),
          trueAngle: _getPlanetAngle(planets[i]),
        ),
    ];

    if (plots.length < 2) {
      return plots;
    }

    final sorted = [...plots]
      ..sort((a, b) => a.trueDegree.compareTo(b.trueDegree));

    final clusters = <List<_WesternPlanetPlot>>[];
    var currentCluster = <_WesternPlanetPlot>[sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      final previous = sorted[i - 1];
      final current = sorted[i];

      if (_degreeDistance(previous.trueDegree, current.trueDegree) <= 5) {
        currentCluster.add(current);
      } else {
        clusters.add(currentCluster);
        currentCluster = <_WesternPlanetPlot>[current];
      }
    }
    clusters.add(currentCluster);

    if (clusters.length > 1 &&
        _degreeDistance(
              clusters.first.first.trueDegree,
              clusters.last.last.trueDegree,
            ) <=
            5) {
      final wrappedCluster = [
        ...clusters.removeLast(),
        ...clusters.removeAt(0),
      ];
      clusters.insert(0, wrappedCluster);
    }

    final minSeparation =
        (22 / planetTrackRadius).clamp(6 * pi / 180, 11 * pi / 180).toDouble();

    for (final cluster in clusters) {
      if (cluster.length <= 1) {
        continue;
      }

      final crossesZero = cluster.any((plot) => plot.trueDegree > 300) &&
          cluster.any((plot) => plot.trueDegree < 60);

      cluster.sort((a, b) {
        final aDegree = crossesZero && a.trueDegree < 180
            ? a.trueDegree + 360
            : a.trueDegree;
        final bDegree = crossesZero && b.trueDegree < 180
            ? b.trueDegree + 360
            : b.trueDegree;
        return aDegree.compareTo(bDegree);
      });

      for (int i = 0; i < cluster.length; i++) {
        final offset = (i - (cluster.length - 1) / 2) * minSeparation;
        cluster[i].renderAngle = cluster[i].trueAngle + offset;
      }
    }

    plots.sort((a, b) => a.index.compareTo(b.index));
    return plots;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 0.98;

    final outerZodiacRadius = radius;
    final houseRingRadius = radius * 0.82;
    final innerPlanetRadius = radius * 0.65;
    final planetTrackRadius = innerPlanetRadius - 18;
    final zodiacTextRadius = (outerZodiacRadius + houseRingRadius) / 2;
    final houseTextRadius = (houseRingRadius + innerPlanetRadius) / 2;

    final starRandom = Random(42);
    for (int i = 0; i < 260; i++) {
      final starRadius = starRandom.nextDouble() * innerPlanetRadius * 0.96;
      final theta = starRandom.nextDouble() * 2 * pi;

      canvas.drawCircle(
        Offset(
          center.dx + starRadius * cos(theta),
          center.dy + starRadius * sin(theta),
        ),
        starRandom.nextDouble() * 1.1,
        Paint()
          ..color = _pureWhite.withValues(
            alpha: 0.10 + (starRandom.nextDouble() * 0.55),
          ),
      );
    }

    final zodiacBand = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: outerZodiacRadius))
      ..addOval(Rect.fromCircle(center: center, radius: houseRingRadius));

    canvas.drawPath(
      zodiacBand,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _deepCosmicPurple.withValues(alpha: 0.24),
            _spaceBlack.withValues(alpha: 0.08),
          ],
        ).createShader(
          Rect.fromCircle(center: center, radius: outerZodiacRadius),
        ),
    );

    final innerField = Rect.fromCircle(
      center: center,
      radius: innerPlanetRadius,
    );
    canvas.drawCircle(
      center,
      innerPlanetRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _deepCosmicPurple.withValues(alpha: 0.16),
            _spaceBlack.withValues(alpha: 0.02),
          ],
        ).createShader(innerField),
    );

    // 1. Draw the three thin instrument rings.
    _drawPremiumCircle(
      canvas,
      center,
      outerZodiacRadius,
      _pureWhite,
      strokeWidth: 1,
      glow: 2,
      alpha: 0.62,
    );
    _drawPremiumCircle(
      canvas,
      center,
      houseRingRadius,
      _moonlightSilver,
      strokeWidth: 0.9,
      alpha: 0.48,
    );
    _drawPremiumCircle(
      canvas,
      center,
      innerPlanetRadius,
      _pureWhite,
      strokeWidth: 0.9,
      alpha: 0.54,
    );

    // 2. Draw Zodiac and house sections.
    for (int i = 0; i < 12; i++) {
      final angle = (2 * pi / 12) * i - pi / 2;
      final labelAngle = angle + (pi / 12);

      _drawPremiumLine(
        canvas,
        Offset(
          center.dx + cos(angle) * innerPlanetRadius,
          center.dy + sin(angle) * innerPlanetRadius,
        ),
        Offset(
          center.dx + cos(angle) * outerZodiacRadius,
          center.dy + sin(angle) * outerZodiacRadius,
        ),
        _pureWhite,
        strokeWidth: 0.72,
        alpha: 0.30,
      );

      final zodiacSign = zodiacSignNames[i];
      final zodiacImage = zodiacImages[zodiacSign];

      if (zodiacImage == null) {
        _drawWheelText(
          canvas,
          zodiacSignInitials(zodiacSign),
          center,
          zodiacTextRadius,
          labelAngle,
          9.5,
          _moonlightSilver,
          fontWeight: FontWeight.w800,
        );
      } else {
        _drawWheelImage(
          canvas,
          zodiacImage,
          center,
          zodiacTextRadius,
          labelAngle,
          24,
        );
      }

      final houseLabel = switch (i) {
        9 => 'ASC',
        0 => 'MC',
        _ => houseRoman[i],
      };
      _drawWheelText(
        canvas,
        houseLabel,
        center,
        houseTextRadius,
        labelAngle,
        houseLabel.length > 2 ? 9.5 : 10.5,
        _pureWhite.withValues(alpha: 0.72),
        fontWeight: FontWeight.w600,
      );
    }

    // 3. Draw the aspect web using true planetary degrees.
    for (int i = 0; i < planets.length; i++) {
      for (int j = i + 1; j < planets.length; j++) {
        final deg1 = _getPlanetDegree(planets[i]);
        final deg2 = _getPlanetDegree(planets[j]);
        final dist = _degreeDistance(deg1, deg2);

        final isSextile = (dist - 60).abs() <= 6;
        final isSquare = (dist - 90).abs() <= 8;
        final isTrine = (dist - 120).abs() <= 8;
        final isOpposition = (dist - 180).abs() <= 8;

        if (isSextile || isSquare || isTrine || isOpposition) {
          final angle1 = _getPlanetAngle(planets[i]);
          final angle2 = _getPlanetAngle(planets[j]);

          final p1 = Offset(
            center.dx + cos(angle1) * innerPlanetRadius,
            center.dy + sin(angle1) * innerPlanetRadius,
          );
          final p2 = Offset(
            center.dx + cos(angle2) * innerPlanetRadius,
            center.dy + sin(angle2) * innerPlanetRadius,
          );

          Color aspectColor = _goldLine;
          if (isSquare || isOpposition) {
            aspectColor = const Color(0xFFE57373); // Reddish for hard aspects
          } else if (isTrine || isSextile) {
            aspectColor = const Color(0xFF81C784); // Greenish for soft aspects
          }

          _drawPremiumLine(
            canvas,
            p1,
            p2,
            aspectColor,
            strokeWidth: 0.75,
            alpha: 0.4,
          );
        }
      }
    }

    // 4. Draw minimalist planet marks, ticks, and true-degree pointers.
    for (final plot in _planetPlots(planetTrackRadius)) {
      final planet = plot.planet;
      final tickStart = Offset(
        center.dx + cos(plot.trueAngle) * innerPlanetRadius,
        center.dy + sin(plot.trueAngle) * innerPlanetRadius,
      );
      final tickEnd = Offset(
        center.dx + cos(plot.trueAngle) * (innerPlanetRadius - 7),
        center.dy + sin(plot.trueAngle) * (innerPlanetRadius - 7),
      );
      final position = Offset(
        center.dx + cos(plot.renderAngle) * planetTrackRadius,
        center.dy + sin(plot.renderAngle) * planetTrackRadius,
      );

      final name = planet['name'] ?? '';
      final color = _planetColors[name] ?? _deepCosmicPurple;

      canvas.drawLine(
        tickStart,
        tickEnd,
        Paint()
          ..color = _pureWhite.withValues(alpha: 0.72)
          ..strokeWidth = 1.35
          ..style = PaintingStyle.stroke,
      );

      if (plot.isStaggered) {
        final trueDegreePoint = Offset(
          center.dx + cos(plot.trueAngle) * (innerPlanetRadius - 7),
          center.dy + sin(plot.trueAngle) * (innerPlanetRadius - 7),
        );

        canvas.drawLine(
          position,
          trueDegreePoint,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.3)
            ..strokeWidth = 0.8
            ..style = PaintingStyle.stroke,
        );
      }

      canvas.drawCircle(
        position,
        8.5,
        Paint()
          ..color = color.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      canvas.drawCircle(
        position,
        8.5,
        Paint()..color = _spaceBlack.withValues(alpha: 0.55),
      );

      canvas.drawCircle(
        position,
        8.5,
        Paint()
          ..color = _pureWhite.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.75,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: planet['symbol'] ?? '✦',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
            shadows: [
              Shadow(
                color: color.withValues(alpha: 0.85),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      tp.layout();
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(-pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  void _drawWheelImage(
    Canvas canvas,
    ui.Image image,
    Offset center,
    double radius,
    double angle,
    double size,
  ) {
    final offset = Offset(
      center.dx + cos(angle) * radius,
      center.dy + sin(angle) * radius,
    );
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final destination = Rect.fromCenter(
      center: Offset.zero,
      width: size,
      height: size,
    );

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.rotate(angle + pi / 2);
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  void _drawWheelText(
    Canvas canvas,
    String text,
    Offset center,
    double radius,
    double angle,
    double fontSize,
    Color color, {
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final offset = Offset(
      center.dx + cos(angle) * radius,
      center.dy + sin(angle) * radius,
    );

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: 'Roboto',
          shadows: [
            Shadow(
              color: _antiqueGold.withValues(alpha: 0.26),
              blurRadius: 5,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.rotate(angle + pi / 2);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WesternWheelPainter oldDelegate) {
    return oldDelegate.planets != planets ||
        oldDelegate.zodiacImages != zodiacImages;
  }
}

class _WesternPlanetPlot {
  _WesternPlanetPlot({
    required this.index,
    required this.planet,
    required this.trueDegree,
    required this.trueAngle,
  }) : renderAngle = trueAngle;

  final int index;
  final Map<String, dynamic> planet;
  final double trueDegree;
  final double trueAngle;
  double renderAngle;

  bool get isStaggered => (renderAngle - trueAngle).abs() > 0.001;
}
