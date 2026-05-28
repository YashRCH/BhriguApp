part of '../home_screen.dart';

class _RealisticEnvelopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Shading for side and bottom flaps to give depth

    // Bottom Flap
    final bottomPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.38, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.72, size.width * 0.62, size.height * 0.65)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(bottomPath, Paint()..color = Colors.black.withValues(alpha: 0.25)..style = PaintingStyle.fill);

    // Left Flap
    final leftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.42, size.height * 0.52)
      ..quadraticBezierTo(size.width * 0.48, size.height * 0.6, size.width * 0.38, size.height * 0.65)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = Colors.black.withValues(alpha: 0.45)..style = PaintingStyle.fill);

    // Right Flap
    final rightPath = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width * 0.58, size.height * 0.52)
      ..quadraticBezierTo(size.width * 0.52, size.height * 0.6, size.width * 0.62, size.height * 0.65)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = Colors.black.withValues(alpha: 0.35)..style = PaintingStyle.fill);

    // Top Flap
    final topPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.42, size.height * 0.52)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.68, size.width * 0.58, size.height * 0.52)
      ..lineTo(size.width, 0)
      ..close();
    
    // Drop shadow for top flap
    canvas.drawPath(topPath, Paint()..color = Colors.black.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawPath(topPath, Paint()..color = Colors.black.withValues(alpha: 0.15)..style = PaintingStyle.fill);

    // Thin, subtle gold lines for the flap edges
    final goldLine = Paint()
      ..color = const Color(0xFFC7A867).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(topPath, goldLine);
    canvas.drawPath(leftPath, goldLine);
    canvas.drawPath(rightPath, goldLine);
    canvas.drawPath(bottomPath, goldLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ignore: unused_element
class _StreakRoadPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final bool unlocked;

  _StreakRoadPainter({
    required this.progress,
    required this.pulse,
    required this.unlocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(12, size.height / 2);
    final end = Offset(size.width - 48, size.height / 2);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    final edgePaint = Paint()
      ..color = const Color(0xFFB58E34).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;

    final basePaint = Paint()
      ..color = const Color(0xFF2E2650)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    final activeGlowPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.16 + pulse * 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final activePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFB58E34),
          Color(0xFFF59E0B),
          Color(0xFFC7A867),
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, shadowPaint);
    canvas.drawLine(start, end, edgePaint);
    canvas.drawLine(start, end, basePaint);

    final safeProgress = progress.clamp(0.0, 1.0);
    final activeEnd = Offset(
      start.dx + (end.dx - start.dx) * safeProgress,
      start.dy,
    );

    if (safeProgress > 0.0) {
      canvas.drawLine(start, activeEnd, activeGlowPaint);
      canvas.drawLine(start, activeEnd, activePaint);
    }

    final sparklePaint = Paint()
      ..color = const Color(0xFFF0ECF8).withValues(alpha: 0.36)
      ..style = PaintingStyle.fill;

    final activeLength = (end.dx - start.dx) * safeProgress;
    double distance = 14;

    while (distance < activeLength) {
      canvas.drawCircle(
        Offset(start.dx + distance, start.dy),
        1.45,
        sparklePaint,
      );
      distance += 18;
    }

    final giftSize = unlocked ? 44.0 : 38.0;

    canvas.save();
    canvas.translate(
      size.width - giftSize - 2,
      size.height / 2 - giftSize / 2,
    );

    _RewardGiftPainter(
      unlocked: unlocked,
      pulse: pulse,
    ).paint(
      canvas,
      Size(giftSize, giftSize),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StreakRoadPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.unlocked != unlocked;
  }
}

class _RewardGiftPainter extends CustomPainter {
  final bool unlocked;
  final double pulse;

  _RewardGiftPainter({
    required this.unlocked,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;

    final glowPaint = Paint()
      ..color = const Color(0xFFF59E0B)
          .withValues(alpha: unlocked ? 0.26 + pulse * 0.16 : 0.11)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(
      Offset(centerX, size.height * 0.55),
      unlocked ? size.width * 0.42 : size.width * 0.30,
      glowPaint,
    );

    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.40,
        size.width * 0.64,
        size.height * 0.40,
      ),
      const Radius.circular(6),
    );

    final lidRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.14,
        size.height * 0.31,
        size.width * 0.72,
        size.height * 0.17,
      ),
      const Radius.circular(5),
    );

    final boxPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF9D6FE8),
          Color(0xFF6B21A8),
          Color(0xFF2E1065),
        ],
      ).createShader(boxRect.outerRect);

    final lidPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFC7A867),
          Color(0xFFF59E0B),
          Color(0xFFB58E34),
        ],
      ).createShader(lidRect.outerRect);

    canvas.drawRRect(boxRect, boxPaint);
    canvas.drawRRect(lidRect, lidPaint);

    final ribbonPaint = Paint()
      ..color = const Color(0xFFC7A867)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - size.width * 0.06,
          size.height * 0.32,
          size.width * 0.12,
          size.height * 0.48,
        ),
        const Radius.circular(3),
      ),
      ribbonPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.14,
          size.height * 0.42,
          size.width * 0.72,
          size.height * 0.07,
        ),
        const Radius.circular(3),
      ),
      ribbonPaint,
    );

    final borderPaint = Paint()
      ..color = const Color(0xFFC7A867).withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(boxRect, borderPaint);
    canvas.drawRRect(lidRect, borderPaint);

    final bowPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFF59E0B),
          Color(0xFFC7A867),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final leftBow = Path()
      ..moveTo(centerX, size.height * 0.32)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.12,
        size.width * 0.18,
        size.height * 0.35,
        centerX,
        size.height * 0.37,
      );

    final rightBow = Path()
      ..moveTo(centerX, size.height * 0.32)
      ..cubicTo(
        size.width * 0.75,
        size.height * 0.12,
        size.width * 0.82,
        size.height * 0.35,
        centerX,
        size.height * 0.37,
      );

    canvas.drawPath(leftBow, bowPaint);
    canvas.drawPath(rightBow, bowPaint);

    canvas.drawCircle(
      Offset(centerX, size.height * 0.35),
      size.width * 0.07,
      Paint()..color = const Color(0xFFC7A867),
    );

    if (unlocked) {
      final sparklePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;

      void sparkle(Offset c, double s) {
        canvas.drawLine(
          Offset(c.dx - s, c.dy),
          Offset(c.dx + s, c.dy),
          sparklePaint,
        );
        canvas.drawLine(
          Offset(c.dx, c.dy - s),
          Offset(c.dx, c.dy + s),
          sparklePaint,
        );
      }

      sparkle(Offset(size.width * 0.20, size.height * 0.22), 3);
      sparkle(Offset(size.width * 0.82, size.height * 0.24), 2.6);
    }
  }

  @override
  bool shouldRepaint(covariant _RewardGiftPainter oldDelegate) {
    return oldDelegate.unlocked != unlocked || oldDelegate.pulse != pulse;
  }
}

class _CosmicLoadingBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(11);
    final starPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 72; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final radius = 0.45 + random.nextDouble() * 1.05;
      final alpha = 0.16 + random.nextDouble() * 0.42;

      starPaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(dx, dy), radius, starPaint);
    }

    final veilPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7B1FA2).withValues(alpha: 0.12),
          const Color(0xFF1A0632).withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.62, size.height * 0.62),
          radius: size.shortestSide * 0.82,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.62),
      size.shortestSide * 0.82,
      veilPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CosmicLoadingBackgroundPainter oldDelegate) {
    return false;
  }
}

class _TeslaGlobePainter extends CustomPainter {
  final double progress;

  _TeslaGlobePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final glassPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF9D6FE8).withValues(alpha: 0.15),
        ],
        stops: const [0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, glassPaint);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFB58E34).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.drawCircle(
      center,
      radius * 0.25,
      Paint()
        ..color = const Color(0xFFB58E34).withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()..color = const Color(0xFFC7A867),
    );

    canvas.drawCircle(
      center,
      radius * 0.06,
      Paint()..color = Colors.white,
    );

    final fixedRandom = math.Random(42);
    const numTendrils = 7;

    for (int i = 0; i < numTendrils; i++) {
      final baseAngle = i * 2 * math.pi / numTendrils;
      final dynamicAngle =
          baseAngle + math.sin(progress * 2 * math.pi + i) * 0.5;

      final endPoint = Offset(
        center.dx + math.cos(dynamicAngle) * radius * 0.95,
        center.dy + math.sin(dynamicAngle) * radius * 0.95,
      );

      final wave1 = math.cos(progress * 4 * math.pi + i * 2);
      final wave2 = math.sin(progress * 6 * math.pi + i * 3);

      final cp1 = Offset(
        center.dx + math.cos(dynamicAngle + wave1 * 0.8) * radius * 0.4,
        center.dy + math.sin(dynamicAngle + wave1 * 0.8) * radius * 0.4,
      );

      final cp2 = Offset(
        center.dx + math.cos(dynamicAngle - wave2 * 0.6) * radius * 0.7,
        center.dy + math.sin(dynamicAngle - wave2 * 0.6) * radius * 0.7,
      );

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, endPoint.dx, endPoint.dy);

      final flicker = 0.5 +
          fixedRandom.nextDouble() * 0.5 +
          math.sin(progress * 20 * math.pi + i) * 0.2;

      final safeFlicker = flicker.clamp(0.2, 1.0);

      final tendrilColor =
          i % 2 == 0 ? const Color(0xFFE040FB) : const Color(0xFF00E5FF);

      canvas.drawPath(
        path,
        Paint()
          ..color = tendrilColor.withValues(alpha: 0.6 * safeFlicker)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFE5D5F5).withValues(alpha: 0.9 * safeFlicker)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      canvas.drawCircle(
        endPoint,
        3.0 * safeFlicker,
        Paint()
          ..color = const Color(0xFFE5D5F5).withValues(alpha: safeFlicker)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TeslaGlobePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _MoonPhaseAsset extends StatelessWidget {
  final String phaseIcon;

  const _MoonPhaseAsset({
    required this.phaseIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD7C6FF).withValues(
                    alpha: 0.18,
                  ),
                  blurRadius: 9,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: const Color(0xFFFFF3C4).withValues(
                    alpha: 0.08,
                  ),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          ClipOval(
            child: Image.asset(
              _assetPathForPhase(phaseIcon),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  '🌕',
                  style: TextStyle(fontSize: 25),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _assetPathForPhase(String icon) {
    if (icon.isEmpty) return 'assets/planets/moon_phase_full.png';

    return switch (icon.runes.first) {
      0x1F311 => 'assets/planets/moon_phase_new.png',
      0x1F312 => 'assets/planets/moon_phase_waxing_crescent.png',
      0x1F313 => 'assets/planets/moon_phase_first_quarter.png',
      0x1F314 => 'assets/planets/moon_phase_waxing_gibbous.png',
      0x1F315 => 'assets/planets/moon_phase_full.png',
      0x1F316 => 'assets/planets/moon_phase_waning_gibbous.png',
      0x1F317 => 'assets/planets/moon_phase_last_quarter.png',
      0x1F318 => 'assets/planets/moon_phase_waning_crescent.png',
      _ => 'assets/planets/moon_phase_full.png',
    };
  }
}
