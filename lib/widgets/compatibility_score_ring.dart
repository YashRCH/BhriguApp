import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CompatibilityScoreRing extends StatelessWidget {
  final int score;
  final double size;

  const CompatibilityScoreRing({
    super.key,
    required this.score,
    this.size = 150,
  });

  @override
  Widget build(BuildContext context) {
    final safeScore = score.clamp(60, 95).toInt();
    final progressValue = safeScore / 100;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progressValue),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ScoreRingPainter(value: value.clamp(0.0, 1.0)),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$safeScore%',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE8B530),
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color:
                              const Color(0xFFE8B530).withValues(alpha: 0.65),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'MATCH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double value;

  const _ScoreRingPainter({
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 9;

    final basePaint = Paint()
      ..color = const Color(0xFF3A301C)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = const Color(0xFFF59E0B).withAlpha(80)
      ..strokeWidth = 15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFC7A867),
          Color(0xFFF59E0B),
          Color(0xFFFFD88A),
        ],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
      )
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, basePaint);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      glowPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
