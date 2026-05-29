import 'dart:async';
import 'package:flutter/material.dart';

/// Frame counts for each owl pose extracted from owl_stripe.png.
class OwlPose {
  final String name;
  final int frameCount;

  const OwlPose._(this.name, this.frameCount);

  static const idle = OwlPose._('idle', 4);
  static const blink = OwlPose._('blink', 3);
  static const takeoff = OwlPose._('takeoff', 3);
  static const flying = OwlPose._('flying', 7);
  static const landing = OwlPose._('landing', 5);
  static const walking = OwlPose._('walking', 4);
  static const sleeping = OwlPose._('sleeping', 2);
  static const alerted = OwlPose._('alerted', 2);
  static const wakingUp = OwlPose._('waking_up', 4);
  static const nesting = OwlPose._('nesting', 4);
  static const perching = OwlPose._('perching', 4);
  static const grooming = OwlPose._('grooming', 7);
  static const writing = OwlPose._('writing', 6);
  static const eating = OwlPose._('eating', 6);
}

/// Animates extracted owl sprite frames at a configurable frame rate.
///
/// Usage:
/// ```dart
/// OwlSpriteAnimator(
///   pose: OwlPose.idle,
///   size: 80,
///   frameDuration: Duration(milliseconds: 200),
/// )
/// ```
class OwlSpriteAnimator extends StatefulWidget {
  final OwlPose pose;
  final double size;
  final Duration frameDuration;
  final bool loop;

  /// Called when a non-looping animation completes.
  final VoidCallback? onComplete;

  const OwlSpriteAnimator({
    super.key,
    required this.pose,
    this.size = 96,
    this.frameDuration = const Duration(milliseconds: 180),
    this.loop = true,
    this.onComplete,
  });

  @override
  State<OwlSpriteAnimator> createState() => _OwlSpriteAnimatorState();
}

class _OwlSpriteAnimatorState extends State<OwlSpriteAnimator> {
  int _currentFrame = 0;
  Timer? _timer;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void didUpdateWidget(OwlSpriteAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pose.name != widget.pose.name ||
        oldWidget.frameDuration != widget.frameDuration) {
      _currentFrame = 0;
      _hasError = false;
      _startAnimation();
    }
  }

  void _startAnimation() {
    _timer?.cancel();
    if (widget.pose.frameCount <= 1) return;

    _timer = Timer.periodic(widget.frameDuration, (_) {
      if (!mounted) return;

      final nextFrame = _currentFrame + 1;

      if (nextFrame >= widget.pose.frameCount) {
        if (widget.loop) {
          setState(() => _currentFrame = 0);
        } else {
          _timer?.cancel();
          widget.onComplete?.call();
        }
      } else {
        setState(() => _currentFrame = nextFrame);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _framePath =>
      'assets/images/owl/frames/${widget.pose.name}/$_currentFrame.png';

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _fallbackIcon();
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Image.asset(
        _framePath,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none, // pixel-art crisp rendering
        gaplessPlayback: true, // Prevents black flashes between frames
        errorBuilder: (_, __, ___) {
          // Set error flag to avoid repeated asset loading attempts
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hasError = true);
          });
          return _fallbackIcon();
        },
      ),
    );
  }

  Widget _fallbackIcon() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: Icon(
          Icons.auto_awesome,
          color: const Color(0xFFC7A867),
          size: widget.size * 0.5,
        ),
      ),
    );
  }
}
