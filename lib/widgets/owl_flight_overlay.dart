import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'owl_sprite_animator.dart';

/// Triggers a flying owl animation that soars across the screen as an overlay.
///
/// The owl enters from the left, flaps across with a sine-wave vertical
/// oscillation, and exits off the right edge. The overlay is self-removing.
///
/// Usage:
/// ```dart
/// OwlFlightOverlay.trigger(context);
/// ```
class OwlFlightOverlay {
  static OverlayEntry? _activeEntry;

  /// Trigger the owl flight animation across the screen.
  /// Only one flight can be active at a time.
  static void trigger(BuildContext context) {
    if (_activeEntry != null) return;

    final overlay = Overlay.of(context);

    _activeEntry = OverlayEntry(
      builder: (context) => _OwlFlightAnimation(
        onComplete: () {
          _activeEntry?.remove();
          _activeEntry = null;
        },
      ),
    );

    overlay.insert(_activeEntry!);
  }

  /// Cancel any active flight animation.
  static void cancel() {
    _activeEntry?.remove();
    _activeEntry = null;
  }
}

class _OwlFlightAnimation extends StatefulWidget {
  final VoidCallback onComplete;

  const _OwlFlightAnimation({required this.onComplete});

  @override
  State<_OwlFlightAnimation> createState() => _OwlFlightAnimationState();
}

class _OwlFlightAnimationState extends State<_OwlFlightAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _owlSize = 72.0;
  static const _flightDuration = Duration(milliseconds: 4500);
  static const _waveAmplitude = 45.0;
  static const _waveFrequency = 2.5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _flightDuration,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final baseY = screenHeight * 0.25;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        // Horizontal: off-screen left → off-screen right
        final x = -_owlSize + (screenWidth + _owlSize * 2) * t;

        // Vertical: sine wave oscillation for flapping feel
        final y = baseY +
            math.sin(t * math.pi * 2 * _waveFrequency) * _waveAmplitude;

        // Gentle tilt based on vertical direction
        final tilt =
            math.cos(t * math.pi * 2 * _waveFrequency) * 0.15;

        return Positioned(
          left: x,
          top: y,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: tilt,
              child: child,
            ),
          ),
        );
      },
      child: const SizedBox(
        width: _owlSize,
        height: _owlSize,
        child: OwlSpriteAnimator(
          pose: OwlPose.flying,
          size: _owlSize,
          frameDuration: Duration(milliseconds: 120),
        ),
      ),
    );
  }
}
