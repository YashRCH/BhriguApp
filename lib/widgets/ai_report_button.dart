import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/ai_report_service.dart';
import 'ai_report_dialog.dart';

class AiReportButton extends StatelessWidget {
  final String feature;
  final String contentId;
  final String contentText;
  final String? label;

  const AiReportButton({
    super.key,
    required this.feature,
    required this.contentId,
    required this.contentText,
    this.label,
  });

  Future<void> _openReportDialog(BuildContext context) async {
    if (contentText.trim().isEmpty) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    final submitted = await showAiReportDialog(
      context: context,
      feature: feature,
      contentId: contentId.trim().isEmpty
          ? AiReportService.stableContentId(
              feature: feature,
              contentText: contentText,
            )
          : contentId.trim(),
      contentText: contentText,
    );

    if (submitted != true || messenger == null) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Report sent. Thank you.',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: const Color(0xFF21163A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = contentText.trim().isNotEmpty;
    final textLabel = label;

    if (textLabel == null) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Report AI content',
        onPressed: enabled ? () => _openReportDialog(context) : null,
        icon: const Icon(Icons.flag_outlined),
        color: const Color(0xFFC7A867),
        disabledColor: const Color(0xFF6B6080),
      );
    }

    return TextButton.icon(
      onPressed: enabled ? () => _openReportDialog(context) : null,
      icon: const Icon(Icons.flag_outlined, size: 16),
      label: Text(textLabel),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFC7A867),
        disabledForegroundColor: const Color(0xFF6B6080),
        visualDensity: VisualDensity.compact,
        textStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
