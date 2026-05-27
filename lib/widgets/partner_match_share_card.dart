import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/partner_match_model.dart';

class PartnerMatchShareButton extends StatefulWidget {
  final PartnerMatchReading reading;

  const PartnerMatchShareButton({
    super.key,
    required this.reading,
  });

  @override
  State<PartnerMatchShareButton> createState() =>
      _PartnerMatchShareButtonState();
}

class _PartnerMatchShareButtonState extends State<PartnerMatchShareButton> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareCard() async {
    if (_sharing) return;

    setState(() {
      _sharing = true;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 180));

      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Share card is not ready.');
      }

      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Could not create share image.');
      }

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();

      final safePartnerName = widget.reading.partner.name
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .toLowerCase();

      final file = File(
        '${tempDir.path}/bhrigu_match_$safePartnerName.png',
      );

      await file.writeAsBytes(bytes);

      final shareText =
          'My BHR1GU compatibility reading with ${widget.reading.partner.name}.';

      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share card: $e'),
          backgroundColor: const Color(0xFF0D0B08),
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _sharing ? null : _shareCard,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0D0B08),
                  Color(0xFF15110A),
                ],
              ),
              border: const Border.fromBorderSide(
                BorderSide(
                  color: Color(0xFFFFD88A),
                  width: 1.1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withAlpha(70),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: _sharing
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Color(0xFFFFD88A),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.ios_share_rounded,
                          color: Color(0xFFFFD88A),
                          size: 19,
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Share Match Card',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        Positioned(
          left: -2400,
          top: 0,
          child: RepaintBoundary(
            key: _cardKey,
            child: PartnerMatchShareCard(
              reading: widget.reading,
            ),
          ),
        ),
      ],
    );
  }
}

class PartnerMatchShareCard extends StatelessWidget {
  final PartnerMatchReading reading;

  const PartnerMatchShareCard({
    super.key,
    required this.reading,
  });

  @override
  Widget build(BuildContext context) {
    final safeOverall = reading.scores.overall.clamp(60, 95).toInt();
    final marriage = reading.marriageGunaMatch;
    final hasMarriage = marriage.maxScore > 0;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 1080,
        height: 1920,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.55),
            radius: 1.35,
            colors: [
              Color(0xFF2A1444),
              Color(0xFF120A22),
              Color(0xFF050408),
            ],
            stops: [0.0, 0.58, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -120,
              child: _GlowOrb(
                size: 390,
                color: const Color(0xFF9D6FE8).withAlpha(70),
              ),
            ),
            Positioned(
              bottom: -130,
              left: -120,
              child: _GlowOrb(
                size: 430,
                color: const Color(0xFFF59E0B).withAlpha(60),
              ),
            ),
            Positioned(
              top: 56,
              left: 56,
              right: 56,
              bottom: 56,
              child: Container(
                padding: const EdgeInsets.fromLTRB(48, 38, 48, 36),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(54),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A1630).withAlpha(245),
                      const Color(0xFF0D0B1E).withAlpha(245),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFFFFD88A).withAlpha(130),
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(120),
                      blurRadius: 55,
                      offset: const Offset(0, 24),
                    ),
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withAlpha(35),
                      blurRadius: 75,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'BHR1GU',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFD88A),
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 9,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'COSMIC COMPATIBILITY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFE5D5F5).withAlpha(210),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ScoreMedallion(score: safeOverall),
                        if (hasMarriage) ...[
                          const SizedBox(width: 34),
                          _MarriageMedallion(
                            total: marriage.totalScore,
                            max: marriage.maxScore,
                            level: marriage.level,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text(
                      '${reading.user.name} × ${reading.partner.name}',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF0ECF8),
                        fontSize: 40,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF21163A),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: const Color(0xFFFFD88A).withAlpha(100),
                          width: 1.6,
                        ),
                      ),
                      child: Text(
                        reading.connectionType,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFD88A),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _AllScoresPanel(reading: reading),
                    if (hasMarriage && marriage.items.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _GunaBreakdownPanel(reading: reading),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      reading.verdict,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFFD88A),
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        height: 1.22,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 1.3,
                      width: double.infinity,
                      color: const Color(0xFFFFD88A).withAlpha(80),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Generated by BHR1GU • Your Personal Vedic AI Sage',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFC7A867).withAlpha(210),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
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
}

class _AllScoresPanel extends StatelessWidget {
  final PartnerMatchReading reading;

  const _AllScoresPanel({
    required this.reading,
  });

  @override
  Widget build(BuildContext context) {
    final scores = reading.scores;
    final marriage = reading.marriageGunaMatch;
    final hasMarriage = marriage.maxScore > 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF090712).withAlpha(135),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: const Color(0xFF2E2650),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          _ShareMetricRow(
            label: 'Overall Match',
            valueText: '${scores.overall.clamp(60, 95).toInt()}%',
            progress: scores.overall.clamp(0, 100).toDouble() / 100,
            highlight: true,
          ),
          const SizedBox(height: 13),
          if (hasMarriage) ...[
            _ShareMetricRow(
              label: '36 Guna Marriage',
              valueText: '${marriage.totalScore}/${marriage.maxScore}',
              progress: marriage.percentage.clamp(0.0, 1.0),
              highlight: true,
            ),
            const SizedBox(height: 13),
          ],
          _ShareMetricRow(
            label: 'Emotional Harmony',
            valueText: '${scores.emotional.clamp(0, 100).toInt()}%',
            progress: scores.emotional.clamp(0, 100).toDouble() / 100,
          ),
          const SizedBox(height: 13),
          _ShareMetricRow(
            label: 'Attraction Pull',
            valueText: '${scores.attraction.clamp(0, 100).toInt()}%',
            progress: scores.attraction.clamp(0, 100).toDouble() / 100,
          ),
          const SizedBox(height: 13),
          _ShareMetricRow(
            label: 'Communication',
            valueText: '${scores.communication.clamp(0, 100).toInt()}%',
            progress: scores.communication.clamp(0, 100).toDouble() / 100,
          ),
          const SizedBox(height: 13),
          _ShareMetricRow(
            label: 'Long-term Stability',
            valueText: '${scores.stability.clamp(0, 100).toInt()}%',
            progress: scores.stability.clamp(0, 100).toDouble() / 100,
          ),
          const SizedBox(height: 13),
          _ShareMetricRow(
            label: 'Karmic Bond',
            valueText: '${scores.karmic.clamp(0, 100).toInt()}%',
            progress: scores.karmic.clamp(0, 100).toDouble() / 100,
          ),
        ],
      ),
    );
  }
}

class _GunaBreakdownPanel extends StatelessWidget {
  final PartnerMatchReading reading;

  const _GunaBreakdownPanel({
    required this.reading,
  });

  @override
  Widget build(BuildContext context) {
    final marriage = reading.marriageGunaMatch;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151126).withAlpha(200),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: const Color(0xFFFFD88A).withAlpha(80),
          width: 1.4,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFFFFD88A),
                size: 21,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '8-Koota Guna Breakdown',
                  style: TextStyle(
                    color: Color(0xFFFFD88A),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  marriage.level,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB8AEE0),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: marriage.items.map((item) {
              return _GunaScoreChip(item: item);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _GunaScoreChip extends StatelessWidget {
  final GunaScoreItem item;

  const _GunaScoreChip({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF090712).withAlpha(150),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2E2650),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF0ECF8),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${item.score}/${item.maxScore}',
            style: const TextStyle(
              color: Color(0xFFFFD88A),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareMetricRow extends StatelessWidget {
  final String label;
  final String valueText;
  final double progress;
  final bool highlight;

  const _ShareMetricRow({
    required this.label,
    required this.valueText,
    required this.progress,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color:
                  highlight ? const Color(0xFFFFD88A) : const Color(0xFFE5D5F5),
              fontSize: highlight ? 21 : 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 17),
        SizedBox(
          width: 245,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: LinearProgressIndicator(
              value: safeProgress,
              minHeight: highlight ? 13 : 11,
              backgroundColor: const Color(0xFF2E2650),
              valueColor: AlwaysStoppedAnimation<Color>(
                highlight ? const Color(0xFFFFD88A) : const Color(0xFFF59E0B),
              ),
            ),
          ),
        ),
        const SizedBox(width: 17),
        SizedBox(
          width: 86,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: const Color(0xFFFFD88A),
              fontSize: highlight ? 22 : 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreMedallion extends StatelessWidget {
  final int score;

  const _ScoreMedallion({
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final safeScore = score.clamp(60, 95).toInt();

    return Container(
      width: 245,
      height: 245,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFFFFD88A),
            Color(0xFFF59E0B),
            Color(0xFF6B21A8),
          ],
          stops: [0.0, 0.58, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withAlpha(120),
            blurRadius: 55,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 200,
          height: 200,
          decoration: const BoxDecoration(
            color: Color(0xFF0D0B1E),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$safeScore%',
                  style: const TextStyle(
                    color: Color(0xFFFFD88A),
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'OVERALL',
                  style: TextStyle(
                    color: Color(0xFFB8AEE0),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarriageMedallion extends StatelessWidget {
  final int total;
  final int max;
  final String level;

  const _MarriageMedallion({
    required this.total,
    required this.max,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final safeMax = max <= 0 ? 36 : max;
    final safeTotal = total.clamp(0, safeMax).toInt();

    return Container(
      width: 245,
      height: 245,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFFE5D5F5),
            Color(0xFF9D6FE8),
            Color(0xFF21103D),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9D6FE8).withAlpha(100),
            blurRadius: 55,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 200,
          height: 200,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF0D0B1E),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$safeTotal/$safeMax',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFD88A),
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'GUNA',
                  style: TextStyle(
                    color: Color(0xFFB8AEE0),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  level,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB8AEE0),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 140,
            spreadRadius: 80,
          ),
        ],
      ),
    );
  }
}
