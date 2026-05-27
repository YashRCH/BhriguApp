import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HeartSignalCard extends StatelessWidget {
  final String prompt;
  final String connectionType;

  const HeartSignalCard({
    super.key,
    required this.prompt,
    required this.connectionType,
  });

  String get _insight {
    final text = prompt.toLowerCase();

    if (text.contains('confusion') ||
        text.contains('confusing') ||
        text.contains('mixed signal') ||
        text.contains('distant') ||
        text.contains('unavailable')) {
      return 'Your words show attraction, but also uncertainty. Bhrigu reads this as a bond that may be magnetic, but not automatically peaceful.';
    }

    if (text.contains('safe') ||
        text.contains('calm') ||
        text.contains('peace') ||
        text.contains('comfort') ||
        text.contains('caring') ||
        text.contains('kind')) {
      return 'Your words point toward emotional safety. This is usually more valuable than intensity because peace can grow into trust.';
    }

    if (text.contains('attraction') ||
        text.contains('spark') ||
        text.contains('chemistry') ||
        text.contains('beautiful') ||
        text.contains('handsome') ||
        text.contains('smile') ||
        text.contains('eyes')) {
      return 'Your heart is responding to chemistry and visible magnetism. Bhrigu will compare whether this attraction has enough grounding to last.';
    }

    if (text.contains('confidence') ||
        text.contains('ambition') ||
        text.contains('ambitious') ||
        text.contains('mature') ||
        text.contains('responsible') ||
        text.contains('disciplined')) {
      return 'You are noticing strength, direction, or maturity. This can support long-term respect if the emotional rhythm is also healthy.';
    }

    if (text.contains('do not like') ||
        text.contains("don't like") ||
        text.contains('hate') ||
        text.contains('ego') ||
        text.contains('toxic') ||
        text.contains('rude') ||
        text.contains('annoying')) {
      return 'Your heart is not only attracted; it is also warning you. Bhrigu treats this as important because dislike often reveals the future friction point.';
    }

    return 'Your words give Bhrigu the emotional context behind the match. The chart shows the pattern, but your feeling shows where the connection touches you.';
  }

  @override
  Widget build(BuildContext context) {
    final cleanPrompt = prompt.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A18).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFC7A867).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD88A).withValues(alpha: 0.1),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Heart Signal',
            style: GoogleFonts.cinzel(
              color: const Color(0xFFC7A867),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 4, 0, 4),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Color(0xFFFFD88A),
                  width: 3,
                ),
              ),
            ),
            child: Text(
              cleanPrompt.isEmpty
                  ? 'No emotional prompt provided.'
                  : '"$cleanPrompt"',
              style: GoogleFonts.cormorantGaramond(
                color: Colors.white,
                fontSize: 22,
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _insight,
            style: GoogleFonts.cormorantGaramond(
              color: const Color(0xFFD4D4CE),
              fontSize: 18,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withAlpha(18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFF59E0B).withAlpha(70),
              ),
            ),
            child: Text(
              connectionType,
              style: GoogleFonts.inter(
                color: const Color(0xFFE8B530),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
