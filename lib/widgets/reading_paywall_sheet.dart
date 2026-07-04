import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/follow_up_context_model.dart';
import 'plans_cta_button.dart';

const _gold = Color(0xFFB58E34);
const _softGold = Color(0xFFC7A867);
const _panel = Color(0xFF1A1630);
const _ink = Color(0xFFE5D5F5);
const _muted = Color(0xFF8E83A8);
const _border = Color(0xFF3A2D50);

/// Contextual paywall shown when a chat message is blocked by the plan
/// allowance. When the user was following up on a reading, the sheet is
/// framed around continuing that exact reading, with a blurred teaser of
/// what Bhrigu still has to say.
Future<void> showReadingPaywallSheet(
  BuildContext context, {
  FollowUpContext? followUpContext,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _ReadingPaywallSheet(
      followUpContext: followUpContext,
    ),
  );
}

class _ReadingPaywallSheet extends StatelessWidget {
  const _ReadingPaywallSheet({this.followUpContext});

  final FollowUpContext? followUpContext;

  @override
  Widget build(BuildContext context) {
    final readingTitle = followUpContext?.readingTitle.trim() ?? '';
    final hasReading = readingTitle.isNotEmpty;
    final teaserText = _teaserText();

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasReading
                  ? 'Bhrigu has more to say'
                  : 'Your messages are used up',
              style: GoogleFonts.inter(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasReading
                  ? 'Your reading "$readingTitle" left a thread open. '
                      'Your plan allowance ran out before Bhrigu could follow it.'
                  : 'This month\'s free messages are done, but Bhrigu is still here.',
              style: GoogleFonts.inter(
                color: _muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _blurredTeaser(teaserText),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(plansRoute);
                },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _gold,
                  foregroundColor: const Color(0xFF050408),
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  hasReading ? 'Continue this reading' : 'See plans',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Maybe later',
                  style: GoogleFonts.inter(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _teaserText() {
    final summary = followUpContext?.readingSummary.trim() ?? '';
    if (summary.isNotEmpty) {
      // The user's own reading summary, blurred: concrete enough to feel
      // real, hidden enough to pull them through.
      return summary;
    }

    return 'The pattern in your chart points somewhere specific this month, '
        'and the timing around it is closer than it feels. There is one '
        'detail worth asking about before it passes.';
  }

  Widget _blurredTeaser(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A18).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 13, color: _softGold),
              const SizedBox(width: 6),
              Text(
                'Waiting for you',
                style: GoogleFonts.inter(
                  color: _softGold,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: _ink.withValues(alpha: 0.85),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
