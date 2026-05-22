import 'dart:math' as math;
import 'package:flutter/material.dart';

class GeomancyCastLine {
  final Offset start;
  final Offset control;
  final Offset end;
  final int value;
  final double length;
  final int index;
  final double angle;
  final double intensity;

  const GeomancyCastLine({
    required this.start,
    required this.control,
    required this.end,
    required this.value,
    required this.length,
    required this.index,
    required this.angle,
    required this.intensity,
  });
}

class GeomancyLineCastWidget extends StatelessWidget {
  final List<GeomancyCastLine> lines;
  final Offset? currentStart;
  final Offset? currentControl;
  final double currentAngle;
  final double currentLength;
  final double currentProgress;
  final bool isHolding;
  final int lineCount;
  final ValueChanged<Size>? onCanvasSizeChanged;

  const GeomancyLineCastWidget({
    super.key,
    required this.lines,
    required this.currentStart,
    required this.currentControl,
    required this.currentAngle,
    required this.currentLength,
    required this.currentProgress,
    required this.isHolding,
    required this.lineCount,
    this.onCanvasSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          onCanvasSizeChanged?.call(size);
        });

        return CustomPaint(
          painter: _GeomancyLinePainter(
            lines: lines,
            currentStart: currentStart,
            currentControl: currentControl,
            currentAngle: currentAngle,
            currentLength: currentLength,
            currentProgress: currentProgress,
            isHolding: isHolding,
            lineCount: lineCount,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _GeomancyLinePainter extends CustomPainter {
  final List<GeomancyCastLine> lines;
  final Offset? currentStart;
  final Offset? currentControl;
  final double currentAngle;
  final double currentLength;
  final double currentProgress;
  final bool isHolding;
  final int lineCount;

  _GeomancyLinePainter({
    required this.lines,
    required this.currentStart,
    required this.currentControl,
    required this.currentAngle,
    required this.currentLength,
    required this.currentProgress,
    required this.isHolding,
    required this.lineCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawSacredGeometry(canvas, size);
    _drawCompletedLines(canvas);
    _drawCurrentLine(canvas);
    _drawSegmentedSeal(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF100B1A),
          Color(0xFF090712),
          Color(0xFF1A0C2E),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, bgPaint);

    // Ethereal core glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          const Color(0xFF6B21A8).withAlpha(45),
          const Color(0xFFF59E0B).withAlpha(15),
          Colors.transparent,
        ],
      ).createShader(rect);

    canvas.drawRect(rect, glowPaint);

    // Stardust particles
    final starPaint = Paint()
      ..color = const Color(0xFFFFD88A).withAlpha(70)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 80; i++) {
      final x = (math.sin(i * 14.137) * 43758.5453).abs() % 1 * size.width;
      final y = (math.sin(i * 81.91) * 31415.926).abs() % 1 * size.height;
      final r = 0.4 + ((i % 4) * 0.25);
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }
  }

  void _drawSacredGeometry(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height);

    final faintPurple = Paint()
      ..color = const Color(0xFF9D6FE8).withAlpha(18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final faintGold = Paint()
      ..color = const Color(0xFFF59E0B).withAlpha(22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Concentric celestial spheres
    canvas.drawCircle(center, radius * 0.15, faintPurple);
    canvas.drawCircle(center, radius * 0.30, faintGold);
    canvas.drawCircle(center, radius * 0.45, faintPurple);

    // 8-Pointed Star (Octagram) base
    final points = <Offset>[];
    for (int i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      points.add(center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.45);
    }

    for (int i = 0; i < points.length; i++) {
      canvas.drawLine(points[i], points[(i + 2) % points.length], faintPurple);
      canvas.drawLine(points[i], points[(i + 3) % points.length], faintGold);
    }
  }

  void _drawCompletedLines(Canvas canvas) {
    for (final line in lines) {
      final path = Path()
        ..moveTo(line.start.dx, line.start.dy)
        ..quadraticBezierTo(
          line.control.dx,
          line.control.dy,
          line.end.dx,
          line.end.dy,
        );

      // Outer astral aura
      final auraPaint = Paint()
        ..color = const Color(0xFF9D6FE8).withAlpha(40)
        ..strokeWidth = 18
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

      // Core gold glow
      final glowPaint = Paint()
        ..color = const Color(0xFFF59E0B)
            .withAlpha((50 + line.intensity * 60).round())
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      // The thread itself
      final linePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFD8B4E2).withAlpha(200),
            const Color(0xFFFFD88A),
            const Color(0xFFFFFFFF),
          ],
        ).createShader(Rect.fromPoints(line.start, line.end))
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, auraPaint);
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);

      // Residual stardust along the path
      final dotPaint = Paint()
        ..color = const Color(0xFFFFD88A).withAlpha(190)
        ..style = PaintingStyle.fill;

      final count = math.max(4, (line.length / 18).round());

      for (int i = 0; i <= count; i++) {
        final t = i / count;
        final p = _quadraticPoint(line.start, line.control, line.end, t);
        canvas.drawCircle(p, 1.0 + line.intensity * 0.6, dotPaint);
      }

      // Anchoring nodes at the ends
      final nodeGlow = Paint()
        ..color = const Color(0xFFFFD88A)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(line.end, 3.5, nodeGlow);
      
      final nodeCore = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(line.end, 1.5, nodeCore);
    }
  }

  void _drawCurrentLine(Canvas canvas) {
    if (!isHolding || currentStart == null || currentControl == null) return;

    final curved = Curves.easeOutQuart.transform(currentProgress.clamp(0.0, 1.0));
    final rawEnd = currentStart! +
        Offset(math.cos(currentAngle), math.sin(currentAngle)) *
            currentLength *
            curved;

    final dynamicControl = Offset.lerp(currentStart!, currentControl!, curved)!;

    final path = Path()
      ..moveTo(currentStart!.dx, currentStart!.dy)
      ..quadraticBezierTo(
        dynamicControl.dx,
        dynamicControl.dy,
        rawEnd.dx,
        rawEnd.dy,
      );

    // Active blazing aura
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD88A).withAlpha(140)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // Active thread core
    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFF59E0B),
          Color(0xFFFFD88A),
          Colors.white,
        ],
      ).createShader(Rect.fromPoints(currentStart!, rawEnd))
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    // Guiding star (the tip of the drawing line)
    final orbAura = Paint()
      ..color = const Color(0xFFFFD88A)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(rawEnd, 8.0, orbAura);

    final orbCore = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(rawEnd, 3.0, orbCore);
  }

  Offset _quadraticPoint(Offset p0, Offset p1, Offset p2, double t) {
    final a = Offset.lerp(p0, p1, t)!;
    final b = Offset.lerp(p1, p2, t)!;
    return Offset.lerp(a, b, t)!;
  }

  // Segmented Astral Ring replacing the basic progress circle
  void _drawSegmentedSeal(Canvas canvas, Size size) {
    final center = Offset(size.width - 40, 40);
    const radius = 18.0;
    const totalSegments = 16;
    
    // Background dial
    canvas.drawCircle(
      center, 
      radius + 6, 
      Paint()..color = const Color(0xFF090712).withAlpha(180)..style = PaintingStyle.fill
    );

    for (int i = 0; i < totalSegments; i++) {
      final angle = -math.pi / 2 + (i * 2 * math.pi / totalSegments);
      final isCompleted = i < lineCount;
      final isActive = i == lineCount && isHolding;

      final start = center + Offset(math.cos(angle), math.sin(angle)) * (radius - 2.5);
      final end = center + Offset(math.cos(angle), math.sin(angle)) * (radius + 2.5);

      final segmentPaint = Paint()
        ..color = isCompleted 
            ? const Color(0xFFFFD88A) 
            : isActive 
                ? const Color(0xFF9D6FE8) 
                : const Color(0xFF2E2650)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (isCompleted || isActive) {
        final glowPaint = Paint()
          ..color = isCompleted ? const Color(0xFFF59E0B).withAlpha(120) : const Color(0xFF9D6FE8).withAlpha(120)
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawLine(start, end, glowPaint);
      }

      canvas.drawLine(start, end, segmentPaint);
    }

    // Number indicator in the center
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$lineCount',
        style: TextStyle(
          color: lineCount == 16 ? const Color(0xFFFFD88A) : const Color(0xFFD8B4E2),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _GeomancyLinePainter oldDelegate) {
    return oldDelegate.lines != lines ||
        oldDelegate.currentProgress != currentProgress ||
        oldDelegate.isHolding != isHolding ||
        oldDelegate.lineCount != lineCount ||
        oldDelegate.currentAngle != currentAngle ||
        oldDelegate.currentLength != currentLength ||
        oldDelegate.currentControl != currentControl;
  }
}