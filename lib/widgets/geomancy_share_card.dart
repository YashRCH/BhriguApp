import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../models/geomancy_figure_model.dart';
import '../services/share_file_service.dart';
import 'geomancy_line_cast_widget.dart';

class GeomancyShareButton extends StatefulWidget {
  final GeomancyReadingModel reading;
  final List<int> lineValues;
  final List<GeomancyCastLine> drawnLines;

  const GeomancyShareButton({
    super.key,
    required this.reading,
    required this.lineValues,
    this.drawnLines = const [],
  });

  @override
  State<GeomancyShareButton> createState() => _GeomancyShareButtonState();
}

class _GeomancyShareButtonState extends State<GeomancyShareButton> {
  final GlobalKey _shareKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareCard() async {
    if (_sharing) return;

    setState(() {
      _sharing = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 250));
      await WidgetsBinding.instance.endOfFrame;

      final shareContext = _shareKey.currentContext;

      if (shareContext == null) {
        throw Exception('Share card is not ready yet.');
      }

      if (!shareContext.mounted) return;

      final boundary =
          shareContext.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Share card could not be prepared.');
      }

      await WidgetsBinding.instance.endOfFrame;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Could not create share image.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final file = await _writeTempImage(pngBytes);

      await ShareFileService.shareImageFile(
        file,
        text: 'My Geomancy reading from BHRIGU',
      );
    } catch (e, stack) {
      debugPrint('Geomancy share failed: $e');
      debugPrintStack(stackTrace: stack);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share geomancy card. Please try again.'),
          backgroundColor: Color(0xFF151126),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
        });
      }
    }
  }

  Future<File> _writeTempImage(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final fileName =
        'bhrigu_geomancy_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${dir.path}/$fileName');
    return file.writeAsBytes(bytes, flush: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Opacity(
          opacity: 0.01,
          child: IgnorePointer(
            child: SizedBox(
              width: 1,
              height: 1,
              child: OverflowBox(
                minWidth: 1080,
                maxWidth: 1080,
                minHeight: 1500,
                maxHeight: 1500,
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: _shareKey,
                  child: GeomancyShareCardPreview(
                    reading: widget.reading,
                    lineValues: widget.lineValues,
                    drawnLines: widget.drawnLines,
                  ),
                ),
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: _sharing ? null : _shareCard,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: _sharing
                    ? const [
                        Color(0xFF21163A),
                        Color(0xFF151126),
                      ]
                    : const [
                        Color(0xFFE68A00),
                        Color(0xFFFFD88A),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD88A).withAlpha(42),
                  blurRadius: 24,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_sharing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFFD88A),
                    ),
                  )
                else
                  const Icon(
                    Icons.ios_share_rounded,
                    color: Color(0xFF160C24),
                    size: 19,
                  ),
                const SizedBox(width: 10),
                Text(
                  _sharing ? 'CREATING SHARE CARD...' : 'SHARE GEOMANCY CARD',
                  style: TextStyle(
                    color: _sharing
                        ? const Color(0xFFFFD88A)
                        : const Color(0xFF160C24),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class GeomancyShareCardPreview extends StatelessWidget {
  final GeomancyReadingModel reading;
  final List<int> lineValues;
  final List<GeomancyCastLine> drawnLines;

  const GeomancyShareCardPreview({
    super.key,
    required this.reading,
    required this.lineValues,
    this.drawnLines = const [],
  });

  @override
  Widget build(BuildContext context) {
    final chart = reading.chart;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 1080,
        height: 1500,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.52),
            radius: 1.28,
            colors: [
              Color(0xFF2A1245),
              Color(0xFF120A21),
              Color(0xFF050408),
            ],
            stops: [0.0, 0.56, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GeomancyShareBackgroundPainter(
                  lineValues: lineValues,
                  chart: chart,
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(54, 44, 54, 38),
                child: Column(
                  children: [
                    const Text(
                      'BHRIGU',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFD88A),
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'GEOMANCY READING',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFD4B872),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _questionBox(),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 350,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 11,
                            child: _userShieldPanel(),
                          ),
                          const SizedBox(width: 22),
                          Expanded(
                            flex: 12,
                            child: _judgePanel(chart),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _witnessRow(chart),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _interpretationBox(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Made with BHRIGU',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFD4B872),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionBox() {
    final question = reading.question.trim().isEmpty
        ? 'A general geomancy reading'
        : reading.question.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF090712).withAlpha(190),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF9D6FE8).withAlpha(90),
          width: 2,
        ),
      ),
      child: Text(
        question,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFFFD88A),
          fontSize: 28,
          height: 1.16,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _userShieldPanel() {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF090712).withAlpha(205),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFFFD88A).withAlpha(120),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD88A).withAlpha(30),
            blurRadius: 26,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'YOUR DRAWN SHIELD',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD4B872),
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: CustomPaint(
              painter: _UserDrawnShieldPainter(
                lineValues: lineValues,
                drawnLines: drawnLines,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _lineValuesText(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFB8AEE0).withAlpha(210),
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  String _lineValuesText() {
    final safeValues = lineValues.length == 16
        ? lineValues
        : List<int>.generate(16, (index) => index.isEven ? 1 : 2);

    return safeValues
        .map((value) => value == 1 ? '•' : '••')
        .toList()
        .join('  ');
  }

  Widget _judgePanel(GeomancyChartModel chart) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF090712).withAlpha(205),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFFFD88A).withAlpha(120),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD88A).withAlpha(30),
            blurRadius: 26,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          _figureGlyph(chart.judge, size: 124),
          const SizedBox(width: 26),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THE JUDGE',
                  style: TextStyle(
                    color: Color(0xFF9D6FE8),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  chart.judge.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFD88A),
                    fontSize: 38,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  chart.judge.latinName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD8B4E2),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21163A),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFFFD88A).withAlpha(90),
                    ),
                  ),
                  child: Text(
                    reading.answer,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF0ECF8),
                      fontSize: 19,
                      height: 1.16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _witnessRow(GeomancyChartModel chart) {
    return SizedBox(
      height: 166,
      child: Row(
        children: [
          Expanded(
            child: _smallFigureCard(
              label: 'LEFT WITNESS',
              figure: chart.leftWitness,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _smallFigureCard(
              label: 'RIGHT WITNESS',
              figure: chart.rightWitness,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _smallFigureCard(
              label: 'RECONCILER',
              figure: chart.reconciler,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallFigureCard({
    required String label,
    required GeomancyFigureModel figure,
  }) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF151126).withAlpha(222),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: const Color(0xFF2E2650),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFD4B872),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 9),
          _figureGlyph(figure, size: 60),
          const SizedBox(height: 9),
          Text(
            figure.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF0ECF8),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _interpretationBox() {
    final text = _cleanInterpretation(reading.interpretation);
    final fontSize = _fontSizeFor(text);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF090712).withAlpha(205),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFFFD88A).withAlpha(92),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(110),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'BHRIGU READS THE SHIELD',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFFD88A),
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 17),
          Expanded(
            child: Center(
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 34,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFF0ECF8),
                  fontSize: fontSize,
                  height: 1.17,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _figureGlyph(GeomancyFigureModel figure, {required double size}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GeomancyFigureGlyphPainter(figure.pattern),
      ),
    );
  }

  String _cleanInterpretation(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (cleaned.isEmpty) {
      return 'The shield gives a symbolic answer shaped by the Judge, the Witnesses, and the Reconciler.';
    }

    if (cleaned.length <= 1650) {
      return cleaned;
    }

    return '${cleaned.substring(0, 1650).trim()}...';
  }

  double _fontSizeFor(String text) {
    final length = text.length;

    if (length <= 360) return 29;
    if (length <= 520) return 26;
    if (length <= 720) return 23;
    if (length <= 950) return 20;
    if (length <= 1250) return 18;
    return 16.5;
  }
}

class _UserDrawnShieldPainter extends CustomPainter {
  final List<int> lineValues;
  final List<GeomancyCastLine> drawnLines;

  _UserDrawnShieldPainter({
    required this.lineValues,
    required this.drawnLines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final safeValues = lineValues.length == 16
        ? lineValues
        : List<int>.generate(16, (index) => index.isEven ? 1 : 2);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.38;
    final completeDrawnLines = drawnLines.length == 16;

    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD88A).withAlpha(58),
          const Color(0xFF9D6FE8).withAlpha(28),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius * 1.35),
      );

    canvas.drawCircle(center, radius * 1.35, auraPaint);

    _drawPanelGeometry(canvas, center, radius);

    if (completeDrawnLines) {
      _drawActualCastLines(canvas, size, safeValues);
    } else {
      _drawParitySeal(canvas, center, radius, safeValues);
    }

    final labelPainter = TextPainter(
      text: TextSpan(
        text:
            completeDrawnLines ? 'actual drawn ritual line' : '16 ritual marks',
        style: const TextStyle(
          color: Color(0xFFD8B4E2),
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    labelPainter.paint(
      canvas,
      Offset(
        center.dx - labelPainter.width / 2,
        center.dy + radius * 1.15,
      ),
    );
  }

  void _drawPanelGeometry(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..color = const Color(0xFFFFD88A).withAlpha(82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final faintRingPaint = Paint()
      ..color = const Color(0xFF9D6FE8).withAlpha(48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawCircle(center, radius * 1.03, ringPaint);
    canvas.drawCircle(center, radius * 0.72, faintRingPaint);
    canvas.drawCircle(center, radius * 1.21, faintRingPaint);
  }

  void _drawParitySeal(
    Canvas canvas,
    Offset center,
    double radius,
    List<int> safeValues,
  ) {
    final motherPaint = Paint()
      ..color = const Color(0xFFFFD88A).withAlpha(118)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    final tracePaint = Paint()
      ..color = const Color(0xFF9D6FE8).withAlpha(84)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    Offset pointAt(int index, double r) {
      final angle = -math.pi / 2 + (2 * math.pi * index / 16);
      return Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
    }

    final ritualPoints = <Offset>[];

    for (int i = 0; i < 16; i++) {
      final wave = math.sin(i * 1.7) * radius * 0.05;
      final r = radius * (safeValues[i] == 1 ? 0.78 : 0.95) + wave;
      ritualPoints.add(pointAt(i, r));
    }

    final shieldPath = Path();

    for (int i = 0; i < ritualPoints.length; i++) {
      final current = ritualPoints[i];

      if (i == 0) {
        shieldPath.moveTo(current.dx, current.dy);
      } else {
        final previous = ritualPoints[i - 1];
        final mid = Offset.lerp(previous, current, 0.5)!;
        final control = Offset(
          mid.dx + math.sin(i * 1.9) * 14,
          mid.dy + math.cos(i * 1.4) * 14,
        );

        shieldPath.quadraticBezierTo(
          control.dx,
          control.dy,
          current.dx,
          current.dy,
        );
      }
    }

    final first = ritualPoints.first;
    final last = ritualPoints.last;
    final closingMid = Offset.lerp(last, first, 0.5)!;

    shieldPath.quadraticBezierTo(
      closingMid.dx - 10,
      closingMid.dy - 18,
      first.dx,
      first.dy,
    );

    canvas.drawPath(shieldPath, motherPaint);

    final innerPath = Path();

    for (int i = 0; i < 16; i += 2) {
      final a = ritualPoints[i];
      final b = ritualPoints[(i + 5) % 16];

      innerPath
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(center.dx, center.dy, b.dx, b.dy);
    }

    canvas.drawPath(innerPath, tracePaint);

    final goldDotPaint = Paint()
      ..color = const Color(0xFFFFD88A)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    final glowDotPaint = Paint()
      ..color = const Color(0xFFFFD88A).withAlpha(86)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    final violetDotPaint = Paint()
      ..color = const Color(0xFF9D6FE8).withAlpha(190)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);

    for (int i = 0; i < ritualPoints.length; i++) {
      final point = ritualPoints[i];
      final isSingle = safeValues[i] == 1;

      if (isSingle) {
        canvas.drawCircle(point, 8.6, glowDotPaint);
        canvas.drawCircle(point, 3.8, goldDotPaint);
      } else {
        final tangentAngle = -math.pi / 2 + (2 * math.pi * i / 16);
        final normal = Offset(
          math.cos(tangentAngle + math.pi / 2),
          math.sin(tangentAngle + math.pi / 2),
        );

        final p1 = point - normal * 6.5;
        final p2 = point + normal * 6.5;

        canvas.drawCircle(p1, 7.2, glowDotPaint);
        canvas.drawCircle(p2, 7.2, glowDotPaint);
        canvas.drawCircle(p1, 3.3, violetDotPaint);
        canvas.drawCircle(p2, 3.3, violetDotPaint);
      }
    }

    final centerPaint = Paint()
      ..color = const Color(0xFFFFD88A).withAlpha(180)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, 5.4, centerPaint);
  }

  void _drawActualCastLines(
    Canvas canvas,
    Size size,
    List<int> safeValues,
  ) {
    final transform = _CastLineTransform.fromLines(drawnLines, size);

    for (final line in drawnLines) {
      final start = transform.map(line.start);
      final control = transform.map(line.control);
      final end = transform.map(line.end);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

      final auraPaint = Paint()
        ..color = const Color(0xFF9D6FE8).withAlpha(42)
        ..strokeWidth = 18
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

      final glowPaint = Paint()
        ..color = const Color(0xFFF59E0B)
            .withAlpha((46 + line.intensity * 58).round())
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      final linePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFD8B4E2).withAlpha(210),
            const Color(0xFFFFD88A),
            Colors.white,
          ],
        ).createShader(Rect.fromPoints(start, end))
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, auraPaint);
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, linePaint);
    }

    final dotGlowPaint = Paint()
      ..color = const Color(0xFFFFD88A).withAlpha(82)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    final goldDotPaint = Paint()
      ..color = const Color(0xFFFFD88A)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    final violetDotPaint = Paint()
      ..color = const Color(0xFF9D6FE8).withAlpha(205)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);

    for (final line in drawnLines) {
      final end = transform.map(line.end);
      final tangent = Offset(
        math.cos(line.angle + math.pi / 2),
        math.sin(line.angle + math.pi / 2),
      );
      final value = line.index > 0 && line.index <= safeValues.length
          ? safeValues[line.index - 1]
          : line.value;

      if (value == 1) {
        canvas.drawCircle(end, 8.6, dotGlowPaint);
        canvas.drawCircle(end, 3.8, goldDotPaint);
      } else {
        final p1 = end - tangent * 6.5;
        final p2 = end + tangent * 6.5;
        canvas.drawCircle(p1, 7.2, dotGlowPaint);
        canvas.drawCircle(p2, 7.2, dotGlowPaint);
        canvas.drawCircle(p1, 3.3, violetDotPaint);
        canvas.drawCircle(p2, 3.3, violetDotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _UserDrawnShieldPainter oldDelegate) {
    return oldDelegate.lineValues.join() != lineValues.join() ||
        oldDelegate.drawnLines.length != drawnLines.length ||
        oldDelegate.drawnLines != drawnLines;
  }
}

class _CastLineTransform {
  final Rect sourceBounds;
  final Rect destinationBounds;
  final double scale;

  const _CastLineTransform({
    required this.sourceBounds,
    required this.destinationBounds,
    required this.scale,
  });

  factory _CastLineTransform.fromLines(
    List<GeomancyCastLine> lines,
    Size destinationSize,
  ) {
    final points = <Offset>[
      for (final line in lines) ...[
        line.start,
        line.control,
        line.end,
      ],
    ];

    var minX = points.first.dx;
    var maxX = points.first.dx;
    var minY = points.first.dy;
    var maxY = points.first.dy;

    for (final point in points.skip(1)) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }

    final sourceWidth = math.max(1.0, maxX - minX);
    final sourceHeight = math.max(1.0, maxY - minY);
    final sourceBounds = Rect.fromLTWH(
      minX,
      minY,
      sourceWidth,
      sourceHeight,
    );
    final destinationBounds = Rect.fromLTWH(
      destinationSize.width * 0.08,
      destinationSize.height * 0.10,
      destinationSize.width * 0.84,
      destinationSize.height * 0.72,
    );
    final scale = math.min(
      destinationBounds.width / sourceBounds.width,
      destinationBounds.height / sourceBounds.height,
    );

    return _CastLineTransform(
      sourceBounds: sourceBounds,
      destinationBounds: destinationBounds,
      scale: scale,
    );
  }

  Offset map(Offset point) {
    final sourceCenter = sourceBounds.center;
    final destinationCenter = destinationBounds.center;
    final translated = point - sourceCenter;

    return destinationCenter + translated * scale;
  }
}

class _GeomancyFigureGlyphPainter extends CustomPainter {
  final List<int> pattern;

  _GeomancyFigureGlyphPainter(this.pattern);

  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..color = const Color(0xFFFFD88A)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);

    final glowPaint = Paint()
      ..color = const Color(0xFFFFD88A).withAlpha(90)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final linePaint = Paint()
      ..color = const Color(0xFF9D6FE8).withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.018;

    final safePattern = pattern.length == 4 ? pattern : const <int>[1, 1, 1, 1];

    final rowGap = size.height / 5;
    final dotRadius = size.width * 0.055;

    for (int i = 0; i < 4; i++) {
      final y = rowGap * (i + 1);

      if (safePattern[i] == 1) {
        final center = Offset(size.width / 2, y);
        canvas.drawCircle(center, dotRadius * 2.1, glowPaint);
        canvas.drawCircle(center, dotRadius, goldPaint);
      } else {
        final left = Offset(size.width * 0.38, y);
        final right = Offset(size.width * 0.62, y);

        canvas.drawLine(left, right, linePaint);
        canvas.drawCircle(left, dotRadius * 2.1, glowPaint);
        canvas.drawCircle(right, dotRadius * 2.1, glowPaint);
        canvas.drawCircle(left, dotRadius, goldPaint);
        canvas.drawCircle(right, dotRadius, goldPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GeomancyFigureGlyphPainter oldDelegate) {
    return oldDelegate.pattern.join() != pattern.join();
  }
}

class _GeomancyShareBackgroundPainter extends CustomPainter {
  final List<int> lineValues;
  final GeomancyChartModel chart;

  _GeomancyShareBackgroundPainter({
    required this.lineValues,
    required this.chart,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.43);
    final radius = size.width * 0.40;

    final circlePaint = Paint()
      ..color = const Color(0xFFFFD88A).withAlpha(32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final purplePaint = Paint()
      ..color = const Color(0xFF9D6FE8).withAlpha(24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, circlePaint);
    canvas.drawCircle(center, radius * 0.72, purplePaint);
    canvas.drawCircle(center, radius * 1.13, purplePaint);

    final values = lineValues.length == 16
        ? lineValues
        : List<int>.generate(16, (index) => index.isEven ? 1 : 2);

    Offset pointFor(int index, double r) {
      final angle = -math.pi / 2 + (2 * math.pi * index / 16);
      return Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
    }

    final dotPaint = Paint()
      ..color = const Color(0xFFFFD88A).withAlpha(54)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 16; i++) {
      final p = pointFor(i, radius * (values[i] == 1 ? 0.86 : 0.98));
      canvas.drawCircle(p, values[i] == 1 ? 4.8 : 3.2, dotPaint);
    }

    final glyphPaint = Paint()
      ..color = const Color(0xFF9D6FE8).withAlpha(22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final points = <Offset>[];

    for (int i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / 6);
      points.add(
        Offset(
          center.dx + math.cos(angle) * radius * 0.58,
          center.dy + math.sin(angle) * radius * 0.58,
        ),
      );
    }

    for (int i = 0; i < points.length; i++) {
      canvas.drawLine(points[i], points[(i + 2) % points.length], glyphPaint);
    }

    final cornerPaint = Paint()
      ..color = const Color(0xFF3A2D50).withAlpha(78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    void curve(Offset a, Offset b, Offset c) {
      final p = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(b.dx, b.dy, c.dx, c.dy);
      canvas.drawPath(p, cornerPaint);
    }

    curve(
      Offset(0, size.height * 0.17),
      Offset(size.width * 0.17, size.height * 0.09),
      Offset(size.width * 0.34, size.height * 0.18),
    );

    curve(
      Offset(size.width, size.height * 0.17),
      Offset(size.width * 0.83, size.height * 0.09),
      Offset(size.width * 0.66, size.height * 0.18),
    );

    curve(
      Offset(0, size.height * 0.84),
      Offset(size.width * 0.17, size.height * 0.91),
      Offset(size.width * 0.34, size.height * 0.82),
    );

    curve(
      Offset(size.width, size.height * 0.84),
      Offset(size.width * 0.83, size.height * 0.91),
      Offset(size.width * 0.66, size.height * 0.82),
    );
  }

  @override
  bool shouldRepaint(covariant _GeomancyShareBackgroundPainter oldDelegate) {
    return oldDelegate.lineValues.join() != lineValues.join() ||
        oldDelegate.chart.judge.name != chart.judge.name;
  }
}
