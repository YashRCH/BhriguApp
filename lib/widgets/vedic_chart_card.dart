import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/user_profile_cache_service.dart';

class VedicChartCard extends StatefulWidget {
  const VedicChartCard({super.key});

  @override
  State<VedicChartCard> createState() => _VedicChartCardState();
}

class _VedicChartCardState extends State<VedicChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _lineAnimation;
  late Animation<double> _planetAnimation;

  bool loading = true;

  String ascendant = '—';
  String moonSign = '—';
  String nakshatra = '—';
  String dominantPlanet = '—';

  List<Map<String, dynamic>> planets = [];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _lineAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.0,
          0.6,
          curve: Curves.easeInOutCubic,
        ),
      ),
    );

    _planetAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.5,
          1.0,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    _loadVedicChart();
  }

  Future<void> _loadVedicChart() async {
    final data =
        await UserProfileCacheService.instance.userDataWithFreshCharts();
    final vedicChart = _extractVedicChart(data);

    if (vedicChart != null) {
      final rawPlanets = vedicChart['planets'];

      if (rawPlanets is List) {
        planets = rawPlanets
            .map((planet) => Map<String, dynamic>.from(planet))
            .toList();
      }

      ascendant = vedicChart['ascendant'] ?? '—';
      moonSign = vedicChart['moonSign'] ?? '—';
      nakshatra = vedicChart['nakshatra'] ?? '—';
      dominantPlanet = _calculateDominantPlanet(planets);
    }

    if (mounted) {
      setState(() {
        loading = false;
      });

      _animationController.forward(from: 0);
    }
  }

  Map<String, dynamic>? _extractVedicChart(Map<String, dynamic>? data) {
    if (data == null) return null;

    final chart = data['vedicChart'];

    if (chart is Map<String, dynamic>) {
      return chart;
    }

    if (chart is Map) {
      return Map<String, dynamic>.from(chart);
    }

    return null;
  }

  String _calculateDominantPlanet(List<Map<String, dynamic>> chartPlanets) {
    if (chartPlanets.isEmpty) return '—';

    final priority = [
      'Saturn',
      'Jupiter',
      'Moon',
      'Venus',
      'Mars',
      'Sun',
      'Mercury',
      'Rahu',
      'Ketu',
    ];

    for (final name in priority) {
      final found = chartPlanets.any((planet) => planet['name'] == name);
      if (found) return name;
    }

    return chartPlanets.first['name'] ?? '—';
  }

  List<Map<String, dynamic>> _visiblePlanets() {
    if (planets.isEmpty) {
      return [];
    }

    return planets;
  }

  String _planetShortName(Map<String, dynamic> planet) {
    final name = planet['name'] ?? '';

    switch (name) {
      case 'Sun':
        return 'Su';
      case 'Moon':
        return 'Mo';
      case 'Mercury':
        return 'Me';
      case 'Venus':
        return 'Ve';
      case 'Mars':
        return 'Ma';
      case 'Jupiter':
        return 'Ju';
      case 'Saturn':
        return 'Sa';
      case 'Rahu':
        return 'Ra';
      case 'Ketu':
        return 'Ke';
      default:
        return name.toString().length >= 2
            ? name.toString().substring(0, 2)
            : 'Pl';
    }
  }

  int _planetHouse(Map<String, dynamic> planet) {
    final rawHouse = planet['house'];

    if (rawHouse is int) {
      return rawHouse.clamp(1, 12);
    }

    if (rawHouse is double) {
      return rawHouse.round().clamp(1, 12);
    }

    return int.tryParse(rawHouse.toString())?.clamp(1, 12) ?? 1;
  }

  Offset _housePosition(int house) {
    switch (house) {
      case 1:
        return const Offset(135, 55);
      case 2:
        return const Offset(70, 28);
      case 3:
        return const Offset(30, 82);
      case 4:
        return const Offset(65, 135);
      case 5:
        return const Offset(30, 195);
      case 6:
        return const Offset(70, 245);
      case 7:
        return const Offset(135, 205);
      case 8:
        return const Offset(200, 245);
      case 9:
        return const Offset(240, 195);
      case 10:
        return const Offset(205, 135);
      case 11:
        return const Offset(240, 82);
      case 12:
        return const Offset(200, 28);
      default:
        return const Offset(135, 135);
    }
  }

  Offset _planetPosition(
    Map<String, dynamic> planet,
    List<Map<String, dynamic>> allPlanets,
  ) {
    final house = _planetHouse(planet);
    final base = _housePosition(house);

    final sameHousePlanets =
        allPlanets.where((item) => _planetHouse(item) == house).toList();

    final positionInHouse = sameHousePlanets.indexWhere(
      (item) => item['name'] == planet['name'],
    );

    final safePosition = positionInHouse == -1 ? 0 : positionInHouse;
    final totalInHouse = sameHousePlanets.length;

    if (totalInHouse <= 1) {
      return base;
    }

    const double spreadRadius = 22;

    final angle = -math.pi / 2 + safePosition * 2 * math.pi / totalInHouse;

    return Offset(
      base.dx + spreadRadius * math.cos(angle),
      base.dy + spreadRadius * math.sin(angle),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayPlanets = _visiblePlanets();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF140B22),
              Color(0xFF221238),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFFE0C48F).withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withValues(alpha: 0.18),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFE0C48F),
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vedic Birth Chart',
                        style: GoogleFonts.cinzel(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Traditional North Indian Kundli',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Center(
                        child: SizedBox(
                          width: 300,
                          height: 300,
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _NorthIndianChartPainter(
                                  progress: _lineAnimation.value,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    for (int i = 0;
                                        i < displayPlanets.length;
                                        i++)
                                      _animatedPlanet(
                                        _planetShortName(displayPlanets[i]),
                                        _planetPosition(
                                          displayPlanets[i],
                                          displayPlanets,
                                        ).dx,
                                        _planetPosition(
                                          displayPlanets[i],
                                          displayPlanets,
                                        ).dy,
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _infoTile(
                        'Ascendant',
                        ascendant,
                      ),
                      const SizedBox(height: 14),
                      _infoTile(
                        'Moon Sign',
                        moonSign,
                      ),
                      const SizedBox(height: 14),
                      _infoTile(
                        'Moon Nakshatra',
                        nakshatra,
                      ),
                      const SizedBox(height: 14),
                      _infoTile(
                        'Dominant Planet',
                        dominantPlanet,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _animatedPlanet(
    String text,
    double left,
    double top,
  ) {
    return Positioned(
      left: left - 14,
      top: top - 14,
      child: ScaleTransition(
        scale: _planetAnimation,
        child: FadeTransition(
          opacity: _planetAnimation,
          child: _planet(text),
        ),
      ),
    );
  }

  Widget _planet(String text) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2B1D47),
        border: Border.all(
          color: const Color(0xFFE0C48F).withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0C48F).withValues(alpha: 0.20),
            blurRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: const Color(0xFFE0C48F),
            fontWeight: FontWeight.w900,
            fontSize: 10.5,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _infoTile(
    String title,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFFE0C48F),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NorthIndianChartPainter extends CustomPainter {
  final double progress;

  _NorthIndianChartPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE0C48F)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();

    path.addRect(
      Rect.fromLTWH(
        0,
        0,
        size.width,
        size.height,
      ),
    );

    path.moveTo(0, 0);
    path.lineTo(size.width, size.height);

    path.moveTo(size.width, 0);
    path.lineTo(0, size.height);

    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, size.height / 2);
    path.close();

    for (final metric in path.computeMetrics()) {
      final extractPath = metric.extractPath(
        0.0,
        metric.length * progress,
      );

      canvas.drawPath(
        extractPath,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NorthIndianChartPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
