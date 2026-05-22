import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/chart_ai_service.dart';
import '../services/user_profile_cache_service.dart';

class CompatibilitySignatureCard extends StatefulWidget {
  const CompatibilitySignatureCard({super.key});

  @override
  State<CompatibilitySignatureCard> createState() =>
      _CompatibilitySignatureCardState();
}

class _CompatibilitySignatureCardState extends State<CompatibilitySignatureCard>
    with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final ChartAiService _chartAiService = ChartAiService();

  bool loading = true;

  int score = 87;
  String soulBond = 'Strong';
  String chemistry = 'High';
  String communication = 'Aligned';
  String destiny = 'Karmic';

  String aiInsight =
      'Your emotional frequencies indicate deep long-term resonance with spiritually mature partners. Venus and Moon alignment suggest powerful emotional attraction and karmic familiarity.';

  @override
  void initState() {
    super.initState();

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _loadCompatibility();
  }

  Future<void> _loadCompatibility() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
      return;
    }

    final data =
        await UserProfileCacheService.instance.userDataWithFreshCharts();

    if (data == null) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
      return;
    }

    final calculatedSignature = _calculateSignature(data);

    String insight =
        data['compatibilityAiInsight'] ?? data['compatibilityInsight'] ?? '';

    if (insight.trim().isEmpty) {
      insight = await _chartAiService.generateCompatibilityInsight(uid);
    }

    if (mounted) {
      setState(() {
        score = calculatedSignature['score'] as int;
        soulBond = calculatedSignature['soulBond'] as String;
        chemistry = calculatedSignature['chemistry'] as String;
        communication = calculatedSignature['communication'] as String;
        destiny = calculatedSignature['destiny'] as String;
        aiInsight = insight;
        loading = false;
      });
    }
  }

  Map<String, dynamic> _calculateSignature(Map<String, dynamic>? data) {
    final westernChart = _asMap(data?['westernChart']);
    final vedicChart = _asMap(data?['vedicChart']);

    final westernPlanets = _asList(westernChart?['planets']);
    final vedicPlanets = _asList(vedicChart?['planets']);

    final venus = _findPlanet(westernPlanets, 'Venus');
    final moon = _findPlanet(westernPlanets, 'Moon');
    final mars = _findPlanet(westernPlanets, 'Mars');
    final saturn = _findPlanet(vedicPlanets, 'Saturn');

    final venusHouse = _toInt(venus?['house'], fallback: 7);
    final moonHouse = _toInt(moon?['house'], fallback: 4);
    final marsHouse = _toInt(mars?['house'], fallback: 1);
    final saturnHouse = _toInt(saturn?['house'], fallback: 10);

    int calculatedScore =
        64 + ((venusHouse + moonHouse + marsHouse + saturnHouse) % 30);

    if (calculatedScore > 94) calculatedScore = 94;
    if (calculatedScore < 62) calculatedScore = 62;

    return {
      'score': calculatedScore,
      'soulBond': _labelFromValue(moonHouse + venusHouse),
      'chemistry': _chemistryLabel(marsHouse, venusHouse),
      'communication': _communicationLabel(moonHouse),
      'destiny': saturnHouse >= 7 ? 'Karmic' : 'Growing',
    };
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) return [];

    return value.map((item) {
      if (item is Map<String, dynamic>) return item;
      if (item is Map) return Map<String, dynamic>.from(item);
      return <String, dynamic>{};
    }).toList();
  }

  Map<String, dynamic>? _findPlanet(
    List<Map<String, dynamic>> planets,
    String name,
  ) {
    for (final planet in planets) {
      if (planet['name'] == name) {
        return planet;
      }
    }

    return null;
  }

  int _toInt(
    dynamic value, {
    required int fallback,
  }) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? fallback;
  }

  String _labelFromValue(int value) {
    final normalized = value % 4;

    if (normalized == 0) return 'Deep';
    if (normalized == 1) return 'Strong';
    if (normalized == 2) return 'Magnetic';

    return 'Intense';
  }

  String _chemistryLabel(
    int marsHouse,
    int venusHouse,
  ) {
    final value = (marsHouse + venusHouse) % 4;

    if (value == 0) return 'High';
    if (value == 1) return 'Electric';
    if (value == 2) return 'Warm';

    return 'Magnetic';
  }

  String _communicationLabel(int moonHouse) {
    final value = moonHouse % 3;

    if (value == 0) return 'Aligned';
    if (value == 1) return 'Intuitive';

    return 'Sensitive';
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2A0845),
              Color(0xFF100720),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFFE8CFE).withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFE8CFE).withValues(alpha: 0.12),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFE8CFE),
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COMPATIBILITY\nSIGNATURE',
                        style: GoogleFonts.cormorantGaramond(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          height: 1,
                          shadows: const [
                            Shadow(
                              color: Colors.white70,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Your energetic relationship blueprint',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 38),
                      Center(
                        child: SizedBox(
                          width: 240,
                          height: 240,
                          child: AnimatedBuilder(
                            animation: Listenable.merge([
                              _orbitController,
                              _pulseController,
                            ]),
                            builder: (context, child) {
                              final orbitAngle =
                                  _orbitController.value * 2 * pi;

                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFE8CFE)
                                              .withValues(
                                            alpha: 0.15 * _pulseAnimation.value,
                                          ),
                                          blurRadius: 60,
                                          spreadRadius: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                  _hollowRing(
                                    220,
                                    const Color(0xFF9B6DFF),
                                    0.3,
                                  ),
                                  _hollowRing(
                                    140,
                                    Colors.white,
                                    0.1,
                                  ),
                                  CustomPaint(
                                    size: const Size(240, 240),
                                    painter: _EnergyWebPainter(
                                      angleOffset: orbitAngle,
                                      radius: 95,
                                    ),
                                  ),
                                  _orbitingPlanet(
                                    symbol: '☉',
                                    baseAngle: 0,
                                    currentAngle: orbitAngle,
                                    radius: 95,
                                    glowColor: const Color(0xFFFFD166),
                                  ),
                                  _orbitingPlanet(
                                    symbol: '☽',
                                    baseAngle: pi / 2,
                                    currentAngle: orbitAngle,
                                    radius: 95,
                                    glowColor: const Color(0xFF4EEBFE),
                                  ),
                                  _orbitingPlanet(
                                    symbol: '♀',
                                    baseAngle: pi,
                                    currentAngle: orbitAngle,
                                    radius: 95,
                                    glowColor: const Color(0xFFFE8CFE),
                                  ),
                                  _orbitingPlanet(
                                    symbol: '♂',
                                    baseAngle: 3 * pi / 2,
                                    currentAngle: orbitAngle,
                                    radius: 95,
                                    glowColor: const Color(0xFFFF5E5E),
                                  ),
                                  ScaleTransition(
                                    scale: _pulseAnimation,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const RadialGradient(
                                          colors: [
                                            Color(0xFFD8B4FF),
                                            Color(0xFF7B4DFF),
                                            Color(0xFF4A148C),
                                          ],
                                          radius: 0.8,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF7B4DFF)
                                                .withValues(alpha: 0.6),
                                            blurRadius: 20,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.4),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$score%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black45,
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 38),
                      Row(
                        children: [
                          Expanded(
                            child: _energyTile(
                              title: 'Soul Bond',
                              value: soulBond,
                              icon: Icons.favorite_rounded,
                              glow: const Color(0xFFFE8CFE),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _energyTile(
                              title: 'Chemistry',
                              value: chemistry,
                              icon: Icons.auto_awesome,
                              glow: const Color(0xFFFFD166),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _energyTile(
                              title: 'Communication',
                              value: communication,
                              icon: Icons.chat_bubble_rounded,
                              glow: const Color(0xFF4EEBFE),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _energyTile(
                              title: 'Destiny',
                              value: destiny,
                              icon: Icons.stars_rounded,
                              glow: const Color(0xFF9B6DFF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: Colors.white.withValues(alpha: 0.03),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.psychology_alt,
                                  color: Color(0xFFB28DFF),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'AI Cosmic Insight',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFB28DFF),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              aiInsight,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.6,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _hollowRing(
    double size,
    Color color,
    double opacity,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _orbitingPlanet({
    required String symbol,
    required double baseAngle,
    required double currentAngle,
    required double radius,
    required Color glowColor,
  }) {
    final double angle = baseAngle + currentAngle;
    final double cx = 120 + cos(angle) * radius;
    final double cy = 120 + sin(angle) * radius;

    return Positioned(
      left: cx - 21,
      top: cy - 21,
      child: _planetNode(
        symbol,
        glowColor,
      ),
    );
  }

  Widget _planetNode(
    String symbol,
    Color glowColor,
  ) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF241035),
        border: Border.all(
          color: glowColor.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: glowColor,
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _energyTile({
    required String title,
    required String value,
    required IconData icon,
    required Color glow,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: glow,
            size: 24,
            shadows: [
              Shadow(
                color: glow.withValues(alpha: 0.6),
                blurRadius: 8,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyWebPainter extends CustomPainter {
  final double angleOffset;
  final double radius;

  _EnergyWebPainter({
    required this.angleOffset,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final paint = Paint()
      ..color = const Color(0xFF9B6DFF).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();

    for (int i = 0; i < 4; i++) {
      final double angle = (i * pi / 2) + angleOffset;

      final point = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );

      if (i == 0) {
        path.moveTo(
          point.dx,
          point.dy,
        );
      } else {
        path.lineTo(
          point.dx,
          point.dy,
        );
      }
    }

    path.close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _EnergyWebPainter oldDelegate) {
    return oldDelegate.angleOffset != angleOffset;
  }
}
