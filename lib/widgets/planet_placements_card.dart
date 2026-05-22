import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/user_profile_cache_service.dart';

class PlanetPlacementsCard extends StatefulWidget {
  const PlanetPlacementsCard({super.key});

  @override
  State<PlanetPlacementsCard> createState() => _PlanetPlacementsCardState();
}

class _PlanetPlacementsCardState extends State<PlanetPlacementsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;

  List<Map<String, dynamic>> planets = [];
  bool loading = true;

  final Map<String, Color> planetColors = const {
    'Sun': Color(0xFFFFB547),
    'Moon': Color(0xFF9CC9FF),
    'Mercury': Color(0xFFA7F3D0),
    'Venus': Color(0xFFFF9BD2),
    'Mars': Color(0xFFFF7A7A),
    'Jupiter': Color(0xFFFFD36E),
    'Saturn': Color(0xFFC7C9D9),
  };

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _loadPlanets();
  }

  Future<void> _loadPlanets() async {
    final data =
        await UserProfileCacheService.instance.userDataWithFreshCharts();
    final rawPlanets = _extractPlanets(data);

    if (rawPlanets != null && rawPlanets.isNotEmpty) {
      planets = rawPlanets
          .map((planet) => Map<String, dynamic>.from(planet))
          .toList();
    }

    if (mounted) {
      setState(() {
        loading = false;
      });

      _entranceController.forward(from: 0);
    }
  }

  List<dynamic>? _extractPlanets(Map<String, dynamic>? data) {
    if (data == null) return null;

    final westernChart = data['westernChart'];

    if (westernChart is Map<String, dynamic>) {
      final rawPlanets = westernChart['planets'];

      if (rawPlanets is List) {
        return rawPlanets;
      }
    }

    if (westernChart is Map) {
      final chart = Map<String, dynamic>.from(westernChart);
      final rawPlanets = chart['planets'];

      if (rawPlanets is List) {
        return rawPlanets;
      }
    }

    return null;
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Color _planetColor(String name) {
    return planetColors[name] ?? const Color(0xFF9B6DFF);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0B2E),
              Color(0xFF0B051A),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF9B6DFF).withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9B6DFF).withValues(alpha: 0.12),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Planet Placements',
                style: GoogleFonts.cormorantGaramond(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(
                      color: Colors.white54,
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your cosmic planetary alignment',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF9B6DFF),
                        ),
                      )
                    : planets.isEmpty
                        ? Center(
                            child: Text(
                              'Birth chart is still being prepared',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: planets.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final planet = planets[index];

                              final name = planet['name'] ?? '';
                              final symbol = planet['symbol'] ?? '✦';
                              final sign = planet['sign'] ?? '—';
                              final degree = planet['degree'] ?? 0;
                              final house = planet['house'] ?? 1;
                              final retrograde = planet['retrograde'] == true;
                              final color = _planetColor(name);

                              final double start =
                                  (index * 0.1).clamp(0.0, 1.0);

                              final double end = (start + 0.4).clamp(0.0, 1.0);

                              final opacityAnim = Tween<double>(
                                begin: 0.0,
                                end: 1.0,
                              ).animate(
                                CurvedAnimation(
                                  parent: _entranceController,
                                  curve: Interval(
                                    start,
                                    end,
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                              );

                              final slideAnim = Tween<Offset>(
                                begin: const Offset(0, 0.3),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: _entranceController,
                                  curve: Interval(
                                    start,
                                    end,
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                              );

                              return AnimatedBuilder(
                                animation: _entranceController,
                                builder: (context, child) {
                                  return FadeTransition(
                                    opacity: opacityAnim,
                                    child: SlideTransition(
                                      position: slideAnim,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    color: Colors.white.withValues(alpha: 0.03),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.06),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: color.withValues(alpha: 0.12),
                                          border: Border.all(
                                            color: color.withValues(alpha: 0.3),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  color.withValues(alpha: 0.3),
                                              blurRadius: 16,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            symbol,
                                            style: TextStyle(
                                              fontSize: 28,
                                              color: color,
                                              shadows: [
                                                Shadow(
                                                  color: color,
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$sign • ${degree.toString()}°${retrograde ? ' R' : ''}',
                                              style: GoogleFonts.inter(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF4C2A85),
                                              Color(0xFF2B1654),
                                            ],
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF9B6DFF)
                                                .withValues(alpha: 0.3),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF4C2A85)
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          '${house}H',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
}
