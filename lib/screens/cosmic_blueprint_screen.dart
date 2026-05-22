import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../widgets/compatibility_signature_card.dart';
import '../widgets/planet_placements_card.dart';
import '../widgets/vedic_chart_card.dart';
import '../widgets/western_chart_card.dart';

class CosmicBlueprintScreen extends StatefulWidget {
  const CosmicBlueprintScreen({super.key});

  @override
  State<CosmicBlueprintScreen> createState() =>
      _CosmicBlueprintScreenState();
}

class _CosmicBlueprintScreenState
    extends State<CosmicBlueprintScreen> {
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF2A1B4D),
                    Color(0xFF0D0B1E),
                  ],
                  radius: 1.2,
                  center: Alignment.topCenter,
                ),
              ),
            ),
          ),

          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurple.withValues(alpha: 0.25),
              ),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(
                    reverse: true,
                  ),
                )
                .scale(
                  duration: 6.seconds,
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Text(
                        'Cosmic Blueprint',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    children: const [
                      WesternChartCard(),
                      VedicChartCard(),
                      PlanetPlacementsCard(),
                      CompatibilitySignatureCard(),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                SmoothPageIndicator(
                  controller: _pageController,
                  count: 4,
                  effect: const ExpandingDotsEffect(
                    dotHeight: 8,
                    dotWidth: 8,
                    activeDotColor: Colors.deepPurpleAccent,
                    dotColor: Colors.white24,
                  ),
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}