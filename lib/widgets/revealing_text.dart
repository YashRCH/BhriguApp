import 'dart:async';

import 'package:flutter/material.dart';

/// Reveals [text] word-by-word like a typewriter when [animate] is true,
/// otherwise renders it instantly. Mirrors the reveal cadence used in Bhrigu
/// chat so generated readings type in the same way.
///
/// The reveal only runs on first mount (or when [text] actually changes). A
/// parent rebuilding with a different [animate] value but the same text will
/// NOT restart the animation, so a Firestore stream re-emitting the same
/// reading leaves a completed reveal untouched.
class RevealingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool animate;
  final Duration startDelay;
  final Duration wordInterval;

  const RevealingText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.animate = false,
    this.startDelay = Duration.zero,
    this.wordInterval = const Duration(milliseconds: 26),
  });

  @override
  State<RevealingText> createState() => _RevealingTextState();
}

class _RevealingTextState extends State<RevealingText> {
  late String _visible;
  Timer? _startTimer;
  Timer? _wordTimer;
  List<int> _wordEnds = const [];
  int _wordIndex = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(RevealingText oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only restart when the actual content changes. Ignoring animate-only
    // changes keeps a finished (or in-flight) reveal stable across rebuilds.
    if (oldWidget.text != widget.text) {
      _start();
    }
  }

  void _start() {
    _cancelTimers();

    if (!widget.animate || widget.text.isEmpty) {
      _visible = widget.text;
      return;
    }

    _wordEnds = _computeWordEnds(widget.text);
    _wordIndex = 0;

    if (_wordEnds.isEmpty) {
      _visible = widget.text;
      return;
    }

    _visible = '';
    _startTimer = Timer(widget.startDelay, _beginReveal);
  }

  void _beginReveal() {
    if (!mounted) return;

    _revealNextWord();

    _wordTimer = Timer.periodic(widget.wordInterval, (_) {
      _revealNextWord();
    });
  }

  void _revealNextWord() {
    if (!mounted) {
      _cancelTimers();
      return;
    }

    if (_wordIndex >= _wordEnds.length) {
      _wordTimer?.cancel();
      return;
    }

    setState(() {
      _visible = widget.text.substring(0, _wordEnds[_wordIndex]);
    });

    _wordIndex++;
  }

  static List<int> _computeWordEnds(String text) {
    final ends = <int>[];

    for (final match in RegExp(r'\S+\s*').allMatches(text)) {
      ends.add(match.end);
    }

    return ends;
  }

  void _cancelTimers() {
    _startTimer?.cancel();
    _wordTimer?.cancel();
    _startTimer = null;
    _wordTimer = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _visible,
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }
}
