import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/user_profile_cache_service.dart';

class WesternChartCard extends StatefulWidget {
  const WesternChartCard({super.key});

  @override
  State<WesternChartCard> createState() => _WesternChartCardState();
}

class _WesternChartCardState extends State<WesternChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

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

    _loadWesternChart();
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
      padding: const EdgeInsets.all(18),
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
          padding: const EdgeInsets.all(24),
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF9D6FE8),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WESTERN\nBLUEPRINT',
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFFE5D5F5),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your celestial personality matrix',
                      style: GoogleFonts.cormorantGaramond(
                        color: Colors.white60,
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF9D6FE8)
                                          .withValues(alpha: 0.15),
                                      blurRadius: 60,
                                      spreadRadius: 10,
                                    )
                                  ],
                                ),
                              ),
                              RotationTransition(
                                turns: _rotationController,
                                child: CustomPaint(
                                  size: const Size(
                                      double.infinity, double.infinity),
                                  painter: WesternWheelPainter(
                                    planets: planets,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Row(
                      children: [
                        Expanded(
                          child: _infoTile(
                            '☉',
                            'Sun',
                            sunSign,
                            const Color(0xFFFFD166),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _infoTile(
                            '☽',
                            'Moon',
                            moonSign,
                            const Color(0xFF4EEBFE),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _infoTile(
                            '↑',
                            'Rising',
                            risingSign,
                            const Color(0xFFC77DFF),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _infoTile(
                            '♀',
                            'Venus',
                            _planetSign('Venus'),
                            const Color(0xFFFE8CFE),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _infoTile(String symbol, String title, String sign, Color glowColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
              const SizedBox(width: 12),
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
                    Text(
                      sign,
                      style: GoogleFonts.cormorantGaramond(
                        color: const Color(0xFFE5D5F5),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  WesternWheelPainter({
    required this.planets,
  });

  final List<String> zodiacGlyphs = const [
    '♈',
    '♉',
    '♊',
    '♋',
    '♌',
    '♍',
    '♎',
    '♏',
    '♐',
    '♑',
    '♒',
    '♓',
  ];

  final List<String> zodiacSigns = const [
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

  final Map<String, Color> planetColors = const {
    'Sun': Color(0xFFFFD166),
    'Moon': Color(0xFF4EEBFE),
    'Mercury': Color(0xFFA7F3D0),
    'Venus': Color(0xFFFE8CFE),
    'Mars': Color(0xFFFE4D4D),
    'Jupiter': Color(0xFFFFD36E),
    'Saturn': Color(0xFFC7C9D9),
  };

  void _drawNeonLine(Canvas canvas, Offset p1, Offset p2, Color color) {
    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawNeonCircle(Canvas canvas, Offset center, double radius, Color color,
      {double strokeWidth = 1.0}) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = strokeWidth * 3
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  // Extracts the absolute angle on the wheel for a given planet
  double _getPlanetAngle(Map<String, dynamic> planet) {
    final sign = planet['sign'] ?? '';
    final signIndex = zodiacSigns.indexOf(sign);

    final degreeRaw = planet['degree'] ?? 0;
    final degree = degreeRaw is int
        ? degreeRaw.toDouble()
        : double.tryParse(degreeRaw.toString()) ?? 0;

    final safeSignIndex = signIndex == -1 ? 0 : signIndex;
    final totalDegree = safeSignIndex * 30 + degree;
    return totalDegree * pi / 180 - pi / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const Color glowCyan = Color(0xFF00E5FF);
    const Color aspectTrineBlue = Color(0xFF7C3AED);

    // 1. Draw Outer Zodiac Rings
    _drawNeonCircle(canvas, center, radius, glowCyan, strokeWidth: 1.5);
    _drawNeonCircle(canvas, center, radius * 0.75, glowCyan, strokeWidth: 1.0);

    // 2. Draw House Spokes
    for (int i = 0; i < 12; i++) {
      final angle = (2 * pi / 12) * i - pi / 2;
      _drawNeonLine(
        canvas,
        Offset(center.dx + cos(angle) * radius * 0.4,
            center.dy + sin(angle) * radius * 0.4),
        Offset(
            center.dx + cos(angle) * radius, center.dy + sin(angle) * radius),
        glowCyan,
      );
    }

    // 3. Draw The New Cosmic Compass Center (Replaces the white dot)
    // Outer core ring
    _drawNeonCircle(canvas, center, radius * 0.4, const Color(0xFF9D6FE8),
        strokeWidth: 1.5);

    // Glowing aura behind star
    canvas.drawCircle(
        center,
        12,
        Paint()
          ..color = const Color(0xFFE040FB).withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // 8-Pointed Star
    final starPath = Path();
    for (int i = 0; i < 16; i++) {
      final a = i * pi / 8;
      // Alternate between long point, short point, inner dip
      final rStar = i % 2 == 0 ? (i % 4 == 0 ? 14.0 : 8.0) : 3.0;
      final p = Offset(center.dx + cos(a) * rStar, center.dy + sin(a) * rStar);
      if (i == 0) {
        starPath.moveTo(p.dx, p.dy);
      } else {
        starPath.lineTo(p.dx, p.dy);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, Paint()..color = Colors.white);

    // 4. Draw Crisp Zodiac Glyphs inside the track
    for (int i = 0; i < 12; i++) {
      final angle = (2 * pi / 12) * i - pi / 2 + (pi / 12);

      final offset = Offset(
        center.dx + cos(angle) * radius * 0.87,
        center.dy + sin(angle) * radius * 0.87,
      );

      final glyphPainter = TextPainter(
        text: TextSpan(
          text: zodiacGlyphs[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      glyphPainter.layout();
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(angle + pi / 2);
      glyphPainter.paint(
          canvas, Offset(-glyphPainter.width / 2, -glyphPainter.height / 2));
      canvas.restore();
    }

    // 5. Draw Aspect Lines linking base degrees on the track
    if (planets.length >= 3) {
      final aspectPoints = planets.take(3).map((planet) {
        final a = _getPlanetAngle(planet);
        // Connect the lines at the edge of the inner circle to keep it clean
        return Offset(center.dx + cos(a) * radius * 0.4,
            center.dy + sin(a) * radius * 0.4);
      }).toList();

      if (aspectPoints.length == 3) {
        _drawNeonLine(
            canvas, aspectPoints[0], aspectPoints[1], aspectTrineBlue);
        _drawNeonLine(
            canvas, aspectPoints[1], aspectPoints[2], aspectTrineBlue);
        _drawNeonLine(
            canvas, aspectPoints[2], aspectPoints[0], aspectTrineBlue);
      }
    }

    // 6. Draw Crisp Planets with Collision Detection (Radial Staggering)
    List<double> placedAngles = [];

    for (final planet in planets) {
      final baseAngle = _getPlanetAngle(planet);
      double currentRadius = radius * 0.65; // Base radius for planets

      // Check how many planets are already at a similar angle
      int overlapDepth = 0;
      for (var placed in placedAngles) {
        // If angle difference is less than ~15 degrees
        double diff = (placed - baseAngle).abs();
        if (diff > pi) diff = 2 * pi - diff; // Handle circle wrap-around
        if (diff < (pi / 12)) {
          overlapDepth++;
        }
      }
      placedAngles.add(baseAngle);

      // Stagger inward by 22 pixels for every collision
      currentRadius -= (overlapDepth * 22.0);

      // Base anchor point on the wheel
      final anchorPosition = Offset(
        center.dx + cos(baseAngle) * radius * 0.70,
        center.dy + sin(baseAngle) * radius * 0.70,
      );

      // Staggered draw position
      final position = Offset(
        center.dx + cos(baseAngle) * currentRadius,
        center.dy + sin(baseAngle) * currentRadius,
      );

      final name = planet['name'] ?? '';
      final color = planetColors[name] ?? const Color(0xFF9D6FE8);

      // If it was pushed inward, draw a sleek connector line to its true position
      if (overlapDepth > 0) {
        canvas.drawLine(
            position,
            anchorPosition,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.3)
              ..strokeWidth = 1.0
              ..style = PaintingStyle.stroke);
      }

      // Solid dark background for readability
      canvas.drawCircle(position, 12, Paint()..color = const Color(0xFF0F0A18));

      // Crisp colored border
      canvas.drawCircle(
          position,
          12,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);

      // Soft glow behind
      canvas.drawCircle(
          position,
          12,
          Paint()
            ..color = color.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

      // Crisp text
      final tp = TextPainter(
        text: TextSpan(
          text: planet['symbol'] ?? '✦',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
            shadows: [Shadow(color: color, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      tp.layout();
      canvas.save();
      canvas.translate(position.dx, position.dy);
      // Counter-rotate text so it stays upright despite the parent container spinning
      canvas.rotate(-pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant WesternWheelPainter oldDelegate) {
    return oldDelegate.planets != planets;
  }
}
