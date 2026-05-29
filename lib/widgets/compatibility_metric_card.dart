import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CompatibilityMetricCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int score;
  final IconData icon;

  const CompatibilityMetricCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final safeScore = score.clamp(0, 100).toInt();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2E1A4A), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF15110A),
              border: Border.all(
                color: const Color(0xFFF59E0B).withAlpha(80),
              ),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFFD88A),
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cinzel(
                    color: const Color(0xFFC7A867),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: safeScore / 100,
                    minHeight: 6,
                    backgroundColor: Colors.black,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFE8B530),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$safeScore%',
            style: GoogleFonts.inter(
              color: const Color(0xFFE8B530),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
