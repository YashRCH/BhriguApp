import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/ai_report_service.dart';

const List<String> aiReportReasons = [
  'Offensive or hateful',
  'Sexual content',
  'Harassment or bullying',
  'Self-harm or dangerous advice',
  'False or misleading',
  'Other',
];

Future<bool?> showAiReportDialog({
  required BuildContext context,
  required String feature,
  required String contentId,
  required String contentText,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AiReportDialog(
      feature: feature,
      contentId: contentId,
      contentText: contentText,
    ),
  );
}

class AiReportDialog extends StatefulWidget {
  final String feature;
  final String contentId;
  final String contentText;

  const AiReportDialog({
    super.key,
    required this.feature,
    required this.contentId,
    required this.contentText,
  });

  @override
  State<AiReportDialog> createState() => _AiReportDialogState();
}

class _AiReportDialogState extends State<AiReportDialog> {
  final _service = AiReportService();
  final _commentController = TextEditingController();

  String _reason = aiReportReasons.first;
  String? _error;
  bool _submitting = false;

  bool get _isCircleReport {
    final feature = widget.feature.trim().toLowerCase();
    return feature == 'circle' || feature == 'connection';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _service.submitReport(
        feature: widget.feature,
        contentId: widget.contentId,
        contentText: widget.contentText,
        reason: _reason,
        optionalComment: _commentController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not send report. Please try again.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F0A18),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: const Color(0xFFC7A867).withValues(alpha: 0.32),
        ),
      ),
      title: Text(
        _isCircleReport ? 'Report Circle' : 'Report AI Content',
        style: GoogleFonts.cinzel(
          color: const Color(0xFFC7A867),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isCircleReport ? 'Tell us what happened.' : 'Choose a reason.',
              style: GoogleFonts.inter(
                color: const Color(0xFFB8AEE0),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            ...aiReportReasons.map(
              (reason) {
                final selected = _reason == reason;

                return InkWell(
                  onTap: _submitting
                      ? null
                      : () {
                          setState(() => _reason = reason);
                        },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected
                              ? const Color(0xFFC7A867)
                              : const Color(0xFF6B6080),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            reason,
                            style: GoogleFonts.inter(
                              color: const Color(0xFFE5D5F5),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              enabled: !_submitting,
              maxLength: AiReportService.commentLimit,
              maxLines: 3,
              style: GoogleFonts.inter(
                color: const Color(0xFFF0ECF8),
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Optional note',
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFF6B6080),
                ),
                counterStyle: const TextStyle(color: Color(0xFF6B6080)),
                filled: true,
                fillColor: const Color(0xFF050408).withValues(alpha: 0.55),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E2650)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E2650)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFC7A867)),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF8A80),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(color: const Color(0xFFB8AEE0)),
          ),
        ),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFC7A867),
                  ),
                )
              : Text(
                  'Submit',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFC7A867),
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}
