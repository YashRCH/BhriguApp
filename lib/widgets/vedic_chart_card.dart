import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/cosmic_chart_calculator.dart';
import '../services/user_profile_cache_service.dart';

class VedicChartCard extends StatefulWidget {
  const VedicChartCard({super.key});

  @override
  State<VedicChartCard> createState() => _VedicChartCardState();
}

class _VedicChartCardState extends State<VedicChartCard>
    with SingleTickerProviderStateMixin {
  static const double _chartLogicalSize = 300;
  static const double _chartDisplayMaxSize = 330;
  static const double _planetDiameter = 28;

  final CosmicChartCalculator _chartCalculator = const CosmicChartCalculator();

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
        planets = _withCalculatedLunarNodes(
          planets,
          data,
          vedicChart,
        );
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

  List<Map<String, dynamic>> _withCalculatedLunarNodes(
    List<Map<String, dynamic>> chartPlanets,
    Map<String, dynamic>? userData,
    Map<String, dynamic> vedicChart,
  ) {
    final hasRahu = chartPlanets.any((planet) => planet['name'] == 'Rahu');
    final hasKetu = chartPlanets.any((planet) => planet['name'] == 'Ketu');

    if (hasRahu && hasKetu) {
      return chartPlanets;
    }

    final birthDate = _dateFromUserData(userData?['dob']);
    if (birthDate == null) {
      return chartPlanets;
    }

    final calculatedChart = _chartCalculator.calculate(
      birthDate: birthDate,
      timeOfBirth: userData?['timeOfBirth']?.toString() ?? '',
      placeOfBirth: userData?['placeOfBirth']?.toString() ?? '',
      latitude: _doubleOrNull(userData?['latitude']),
      longitude: _doubleOrNull(userData?['longitude']),
    );

    final augmentedPlanets = [...chartPlanets];
    final chartAscendant = vedicChart['ascendant']?.toString();
    for (final node in calculatedChart.vedicChart.planets.where(
      (planet) => planet.name == 'Rahu' || planet.name == 'Ketu',
    )) {
      final alreadyPresent =
          augmentedPlanets.any((planet) => planet['name'] == node.name);
      if (!alreadyPresent) {
        final nodeJson = node.toJson();
        nodeJson['house'] = _houseFromAscendantSign(
          node.sign,
          chartAscendant,
          fallback: node.house,
        );
        augmentedPlanets.add(nodeJson);
      }
    }

    return augmentedPlanets;
  }

  int _houseFromAscendantSign(
    String planetSign,
    String? ascendantSign, {
    required int fallback,
  }) {
    final planetSignIndex = CosmicChartCalculator.signs.indexOf(planetSign);
    final ascendantSignIndex =
        CosmicChartCalculator.signs.indexOf(ascendantSign ?? '');

    if (planetSignIndex == -1 || ascendantSignIndex == -1) {
      return fallback;
    }

    return ((planetSignIndex - ascendantSignIndex + 12) % 12) + 1;
  }

  DateTime? _dateFromUserData(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    try {
      final dynamic timestamp = value;
      final converted = timestamp?.toDate();
      if (converted is DateTime) {
        return converted;
      }
    } catch (_) {
      // Firestore Timestamp is optional here; string dates are the common path.
    }

    return DateTime.tryParse(value?.toString() ?? '');
  }

  double? _doubleOrNull(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
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

    final positionInHouse = sameHousePlanets.indexOf(planet);
    final safePosition = positionInHouse == -1 ? 0 : positionInHouse;
    final totalInHouse = sameHousePlanets.length;

    if (totalInHouse <= 1) {
      return base;
    }

    const edgePadding = (_planetDiameter / 2) + 2;
    final offset = _planetGridOffset(safePosition, totalInHouse);

    return Offset(
      (base.dx + offset.dx)
          .clamp(edgePadding, _chartLogicalSize - edgePadding)
          .toDouble(),
      (base.dy + offset.dy)
          .clamp(edgePadding, _chartLogicalSize - edgePadding)
          .toDouble(),
    );
  }

  Offset _planetGridOffset(int index, int total) {
    const tightX = 13.0;
    const tightY = 11.0;

    if (total == 2) {
      return [const Offset(-tightX, 0), const Offset(tightX, 0)][index];
    }

    if (total == 3) {
      return [
        const Offset(0, -tightY),
        const Offset(-tightX, tightY),
        const Offset(tightX, tightY),
      ][index];
    }

    if (total == 4) {
      return [
        const Offset(-tightX, -tightY),
        const Offset(tightX, -tightY),
        const Offset(-tightX, tightY),
        const Offset(tightX, tightY),
      ][index];
    }

    const wrapColumns = 3;
    const wrapX = 17.0;
    const wrapY = 17.0;
    final row = index ~/ wrapColumns;
    final rows = (total / wrapColumns).ceil();
    final itemsInRow = math.min(wrapColumns, total - row * wrapColumns);
    final col = index % wrapColumns;

    return Offset(
      (col - (itemsInRow - 1) / 2) * wrapX,
      (row - (rows - 1) / 2) * wrapY,
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final chartSize = math.min(
                            _chartDisplayMaxSize,
                            constraints.maxWidth,
                          );

                          return Center(
                            child: SizedBox.square(
                              dimension: chartSize,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: _chartLogicalSize,
                                  height: _chartLogicalSize,
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
                                                _planetShortName(
                                                  displayPlanets[i],
                                                ),
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
                            ),
                          );
                        },
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
      left: left - (_planetDiameter / 2),
      top: top - (_planetDiameter / 2),
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
    final isShadowPlanet = text == 'Ra' || text == 'Ke';
    final accentColor =
        isShadowPlanet ? const Color(0xFFE5D5F5) : const Color(0xFFE0C48F);

    return Container(
      width: _planetDiameter,
      height: _planetDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isShadowPlanet
            ? const Color(0xFF4A3B69).withValues(alpha: 0.78)
            : const Color(0xFF2B1D47),
        border: Border.all(
          color: accentColor.withValues(alpha: isShadowPlanet ? 0.78 : 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isShadowPlanet ? 0.34 : 0.20),
            blurRadius: isShadowPlanet ? 13 : 10,
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: accentColor,
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
    final stars = math.Random(42);
    for (int i = 0; i < 120; i++) {
      canvas.drawCircle(
        Offset(
          stars.nextDouble() * size.width,
          stars.nextDouble() * size.height,
        ),
        stars.nextDouble() * 0.9,
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.08 + (stars.nextDouble() * 0.22),
          ),
      );
    }

    final glowPaint = Paint()
      ..color = const Color(0xFFE0C48F).withValues(alpha: 0.22)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final paint = Paint()
      ..color = const Color(0xFFE0C48F)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

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
        glowPaint,
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
