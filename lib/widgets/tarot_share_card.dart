import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../models/tarot_card.dart';
import '../services/share_file_service.dart';

class TarotShareButton extends StatefulWidget {
  final String question;
  final TarotCard past;
  final TarotCard present;
  final TarotCard future;
  final String reading;

  const TarotShareButton({
    super.key,
    required this.question,
    required this.past,
    required this.present,
    required this.future,
    required this.reading,
  });

  @override
  State<TarotShareButton> createState() => _TarotShareButtonState();
}

class _TarotShareButtonState extends State<TarotShareButton> {
  final GlobalKey _shareKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareCard() async {
    if (_sharing) return;

    setState(() {
      _sharing = true;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 180));

      final context = _shareKey.currentContext;

      if (context == null) {
        throw Exception('Share card is not ready yet.');
      }

      if (!context.mounted) return;

      final boundary = context.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Share card is not ready yet.');
      }

      if (boundary.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
        await Future.delayed(const Duration(milliseconds: 180));
      }

      if (boundary.debugNeedsPaint) {
        throw Exception(
            'Share card is still preparing. Please tap share again.');
      }

      final pngBytes = await _capturePng(boundary);
      final file = await _writeTempImage(pngBytes);

      await ShareFileService.shareImageFile(
        file,
        text: 'My Tarot reading from BHR1GU',
      );
    } catch (e, stack) {
      debugPrint('Tarot share failed: $e');
      debugPrintStack(stackTrace: stack);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share tarot card. Please try again.'),
          backgroundColor: Color(0xFF1A1630),
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

  Future<Uint8List> _capturePng(RenderRepaintBoundary boundary) async {
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Could not create share image.');
    }

    return byteData.buffer.asUint8List();
  }

  Future<File> _writeTempImage(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final fileName =
        'bhrigu_tarot_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${dir.path}/$fileName');
    return file.writeAsBytes(bytes, flush: true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
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
                  child: TarotShareCardPreview(
                    question: widget.question,
                    past: widget.past,
                    present: widget.present,
                    future: widget.future,
                    reading: widget.reading,
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
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: _sharing
                    ? const [
                        Color(0xFF21163A),
                        Color(0xFF151126),
                      ]
                    : const [
                        Color(0xFF8A6B22),
                        Color(0xFFFFD88A),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD88A).withValues(alpha: 0.18),
                  blurRadius: 22,
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
                  _sharing ? 'CREATING SHARE CARD...' : 'SHARE TAROT CARD',
                  style: GoogleFonts.cinzel(
                    color: _sharing
                        ? const Color(0xFFFFD88A)
                        : const Color(0xFF160C24),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

class TarotShareCardPreview extends StatelessWidget {
  final String question;
  final TarotCard past;
  final TarotCard present;
  final TarotCard future;
  final String reading;

  const TarotShareCardPreview({
    super.key,
    required this.question,
    required this.past,
    required this.present,
    required this.future,
    required this.reading,
  });

  @override
  Widget build(BuildContext context) {
    final closing = _closingLine(reading);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 1080,
        height: 1500,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.25,
            colors: [
              Color(0xFF2B1743),
              Color(0xFF130D1E),
              Color(0xFF050408),
            ],
            stops: [0.0, 0.58, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TarotShareBackgroundPainter(),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(74, 70, 74, 62),
                child: Column(
                  children: [
                    Text(
                      'BHR1GU',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFFFFD88A),
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 9,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TAROT READING',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFFB58E34),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 46),
                    _questionBox(),
                    const SizedBox(height: 54),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _cardColumn('PAST', past),
                        _cardColumn('PRESENT', present),
                        _cardColumn('FUTURE', future),
                      ],
                    ),
                    const SizedBox(height: 58),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(42),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF090712).withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color:
                                const Color(0xFFFFD88A).withValues(alpha: 0.42),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.44),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'BHRIGU SPEAKS',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cinzel(
                                color: const Color(0xFFFFD88A),
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 5,
                              ),
                            ),
                            const SizedBox(height: 30),
                            Expanded(
                              child: Center(
                                child: Text(
                                  closing,
                                  textAlign: TextAlign.center,
                                  maxLines: 10,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cormorantGaramond(
                                    color: const Color(0xFFF0ECF8),
                                    fontSize: 42,
                                    height: 1.28,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      'Made with BHR1GU',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFFB58E34),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
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
    final safeQuestion =
        question.trim().isEmpty ? 'A general tarot reading' : question.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 26),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0812).withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF9D6FE8).withValues(alpha: 0.36),
          width: 2,
        ),
      ),
      child: Text(
        safeQuestion,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.cormorantGaramond(
          color: const Color(0xFFC7A867),
          fontSize: 34,
          height: 1.25,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _cardColumn(String label, TarotCard card) {
    return SizedBox(
      width: 280,
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.cinzel(
              color: const Color(0xFFB58E34),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 225,
            height: 362,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1430),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFFFD88A).withValues(alpha: 0.55),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD88A).withValues(alpha: 0.14),
                  blurRadius: 26,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.58),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                card.asset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(18),
                  alignment: Alignment.center,
                  child: Text(
                    card.name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cinzel(
                      color: const Color(0xFFFFD88A),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            card.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cinzel(
              color: const Color(0xFFF0ECF8),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
        ],
      ),
    );
  }

  String _closingLine(String value) {
    final cleaned = value
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (cleaned.isEmpty) {
      return 'The cards reveal a movement from what shaped you, to what is testing you, to what is quietly forming ahead.';
    }

    final lastUseful = cleaned.reversed.firstWhere(
      (line) =>
          !line.toUpperCase().startsWith('PAST') &&
          !line.toUpperCase().startsWith('PRESENT') &&
          !line.toUpperCase().startsWith('FUTURE'),
      orElse: () => cleaned.last,
    );

    if (lastUseful.length <= 520) {
      return lastUseful;
    }

    return '${lastUseful.substring(0, 520).trim()}...';
  }
}

class _TarotShareBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..color = const Color(0xFFFFD88A).withValues(alpha: 0.19)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final purplePaint = Paint()
      ..color = const Color(0xFF9D6FE8).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final center = Offset(size.width / 2, size.height * 0.43);
    final radius = size.width * 0.39;

    canvas.drawCircle(center, radius, goldPaint);
    canvas.drawCircle(center, radius * 0.78, purplePaint);
    canvas.drawCircle(center, radius * 1.13, purplePaint);

    final points = <Offset>[];

    for (int i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / 5);
      points.add(
        Offset(
          center.dx + math.cos(angle) * radius * 0.92,
          center.dy + math.sin(angle) * radius * 0.92,
        ),
      );
    }

    final starPath = Path()..moveTo(points[0].dx, points[0].dy);
    const order = [0, 2, 4, 1, 3, 0];

    for (int i = 1; i < order.length; i++) {
      starPath.lineTo(points[order[i]].dx, points[order[i]].dy);
    }

    canvas.drawPath(starPath, goldPaint);

    final dotPaint = Paint()
      ..color = const Color(0xFFFFD88A).withValues(alpha: 0.36)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 42; i++) {
      final angle = 2 * math.pi * i / 42;
      final dot = Offset(
        center.dx + math.cos(angle) * radius * 1.02,
        center.dy + math.sin(angle) * radius * 1.02,
      );
      canvas.drawCircle(dot, i % 6 == 0 ? 4.4 : 2.4, dotPaint);
    }

    final vinePaint = Paint()
      ..color = const Color(0xFF3A2D50).withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    void drawCurve(Offset a, Offset b, Offset c) {
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(b.dx, b.dy, c.dx, c.dy);
      canvas.drawPath(path, vinePaint);
    }

    drawCurve(
      Offset(0, size.height * 0.18),
      Offset(size.width * 0.18, size.height * 0.12),
      Offset(size.width * 0.30, size.height * 0.22),
    );

    drawCurve(
      Offset(size.width, size.height * 0.18),
      Offset(size.width * 0.82, size.height * 0.12),
      Offset(size.width * 0.70, size.height * 0.22),
    );

    drawCurve(
      Offset(0, size.height * 0.82),
      Offset(size.width * 0.18, size.height * 0.88),
      Offset(size.width * 0.30, size.height * 0.78),
    );

    drawCurve(
      Offset(size.width, size.height * 0.82),
      Offset(size.width * 0.82, size.height * 0.88),
      Offset(size.width * 0.70, size.height * 0.78),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
