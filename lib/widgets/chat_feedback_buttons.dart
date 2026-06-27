import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/chat_feedback_service.dart';

/// 👍 / 👎 rating shown under a Bhrigu chat answer. An up-vote feeds the
/// per-user liked-answer RAG pool; a down-vote removes it (see the
/// `chatFeedback` Firestore trigger).
class ChatFeedbackButtons extends StatefulWidget {
  final String question;
  final String answer;
  final String aiResponseLanguage;
  final ChatFeedbackService? service;

  const ChatFeedbackButtons({
    super.key,
    required this.question,
    required this.answer,
    required this.aiResponseLanguage,
    this.service,
  });

  @override
  State<ChatFeedbackButtons> createState() => _ChatFeedbackButtonsState();
}

class _ChatFeedbackButtonsState extends State<ChatFeedbackButtons> {
  late final ChatFeedbackService _service =
      widget.service ?? ChatFeedbackService();

  String? _vote; // 'up', 'down', or null
  bool _submitting = false;

  Future<void> _vote_(String vote) async {
    if (_submitting || widget.answer.trim().isEmpty) return;

    // tapping the active vote again clears it.
    final nextVote = _vote == vote ? null : vote;

    setState(() => _submitting = true);

    try {
      // submit only when setting a vote; clearing is local-only (no delete path
      // needed for MVP — a flipped vote overwrites the same doc).
      if (nextVote != null) {
        await _service.submitFeedback(
          question: widget.question,
          answer: widget.answer,
          vote: nextVote,
          aiResponseLanguage: widget.aiResponseLanguage,
        );
      }

      if (!mounted) return;

      setState(() {
        _vote = nextVote;
        _submitting = false;
      });

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (nextVote != null && messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              nextVote == 'up'
                  ? 'Thanks — Bhrigu will lean into answers like this.'
                  : 'Thanks for the feedback.',
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
    } catch (_) {
      if (!mounted) return;

      setState(() => _submitting = false);

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'Could not save your feedback. Please try again.',
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
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_submitting && widget.answer.trim().isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _voteButton(
          icon: _vote == 'up'
              ? Icons.thumb_up_alt
              : Icons.thumb_up_alt_outlined,
          active: _vote == 'up',
          tooltip: 'Good answer',
          onTap: enabled ? () => _vote_('up') : null,
        ),
        _voteButton(
          icon: _vote == 'down'
              ? Icons.thumb_down_alt
              : Icons.thumb_down_alt_outlined,
          active: _vote == 'down',
          tooltip: 'Bad answer',
          onTap: enabled ? () => _vote_('down') : null,
        ),
      ],
    );
  }

  Widget _voteButton({
    required IconData icon,
    required bool active,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon),
      color: active ? const Color(0xFFC7A867) : const Color(0xFF8A7FB0),
      disabledColor: const Color(0xFF6B6080),
    );
  }
}
