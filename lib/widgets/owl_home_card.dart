import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/owl_companion_state.dart';
import '../services/owl_companion_service.dart';
import 'owl_sprite_animator.dart';
import 'owl_flight_overlay.dart';

/// Cosmetic gift items the owl can bring.
const _celestialGifts = [
  {'name': 'Star Crystal', 'icon': '💎', 'lore': 'A shard of frozen starlight, said to amplify inner clarity.'},
  {'name': 'Lunar Feather', 'icon': '🪶', 'lore': 'A feather kissed by moonlight, carrying whispers of forgotten dreams.'},
  {'name': 'Cosmic Amulet', 'icon': '🔮', 'lore': 'An ancient charm that hums with the resonance of distant galaxies.'},
  {'name': 'Astral Seed', 'icon': '✨', 'lore': 'A seed from the celestial garden, waiting to bloom in your spirit.'},
  {'name': 'Nebula Tear', 'icon': '🌌', 'lore': 'A drop of condensed cosmos, shimmering with infinite potential.'},
];

/// Interactive Owl Companion card for the HomeScreen.
///
/// Self-loading, error-safe, and fully self-contained.
class OwlHomeCard extends StatefulWidget {
  final String uid;

  const OwlHomeCard({super.key, required this.uid});

  @override
  State<OwlHomeCard> createState() => _OwlHomeCardState();
}

class _OwlHomeCardState extends State<OwlHomeCard>
    with SingleTickerProviderStateMixin {
  final _service = OwlCompanionService();

  OwlCompanionState _state = const OwlCompanionState.empty();
  bool _loading = true;
  bool _petting = false;
  bool _claiming = false;
  String? _statusMessage;

  OwlPose _currentPose = OwlPose.idle;
  Timer? _blinkTimer;

  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _loadState();
    _scheduleNextBlink();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    final delay = math.Random().nextInt(6) + 3; // 3 to 8 seconds
    _blinkTimer = Timer(Duration(seconds: delay), _playBlink);
  }

  void _playBlink() {
    if (!mounted) return;
    if (_currentPose == OwlPose.idle) {
      setState(() => _currentPose = OwlPose.blink);
      Future.delayed(const Duration(milliseconds: 750), () {
        if (mounted && _currentPose == OwlPose.blink) {
          setState(() => _currentPose = OwlPose.idle);
        }
        _scheduleNextBlink();
      });
    } else {
      _scheduleNextBlink();
    }
  }

  Future<void> _loadState() async {
    if (widget.uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final state = await _service.loadOwlState(widget.uid);
      if (!mounted) return;
      setState(() {
        _state = state;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _petOwl() async {
    if (_petting || widget.uid.isEmpty) return;

    setState(() => _petting = true);

    try {
      final result = await _service.petOwl(widget.uid);
      if (!mounted) return;

      setState(() {
        _state = result.state;
        _petting = false;
        _statusMessage = result.message;
      });

      if (result.success) {
        // Show happy animation briefly
        setState(() => _currentPose = OwlPose.alerted);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _currentPose = OwlPose.idle);
        });

        // Trigger owl flight across screen!
        if (mounted) {
          OwlFlightOverlay.trigger(context);
        }
      }

      // Clear status after a delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _statusMessage = null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _petting = false;
        _statusMessage = 'The owl seems restless. Try again.';
      });
    }
  }

  Future<void> _claimReward() async {
    if (_claiming || widget.uid.isEmpty) return;

    setState(() => _claiming = true);

    try {
      final updatedState = await _service.claimReward(widget.uid);
      if (!mounted) return;

      setState(() {
        _state = updatedState;
        _claiming = false;
      });

      _showGiftDialog();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _claiming = false;
        _statusMessage = 'Could not open gift. Try again.';
      });
    }
  }

  void _showGiftDialog() {
    final gift = _celestialGifts[math.Random().nextInt(_celestialGifts.length)];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1630),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: const Color(0xFFB58E34).withValues(alpha: 0.5),
          ),
        ),
        title: Column(
          children: [
            Text(
              gift['icon']!,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 8),
            Text(
              gift['name']!,
              textAlign: TextAlign.center,
              style: GoogleFonts.cinzelDecorative(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFC7A867),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              gift['lore']!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFFE5D5F5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Hoot! Your owl brought you a gift.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFFC7A867).withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Thank you',
              style: TextStyle(color: Color(0xFFC7A867)),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _state.owlName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1630),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: const Color(0xFFB58E34).withValues(alpha: 0.5),
          ),
        ),
        title: Text(
          'Name Your Owl',
          style: GoogleFonts.cinzelDecorative(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFC7A867),
          ),
        ),
        content: TextField(
          controller: controller,
          maxLength: 24,
          style: const TextStyle(color: Color(0xFFF0ECF8)),
          decoration: InputDecoration(
            hintText: defaultOwlName,
            hintStyle: TextStyle(
              color: const Color(0xFF6B6080).withValues(alpha: 0.6),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: const Color(0xFFB58E34).withValues(alpha: 0.4),
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFC7A867)),
            ),
            counterStyle: const TextStyle(color: Color(0xFF6B6080)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B6080)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != _state.owlName) {
                try {
                  final updated = await _service.updateOwlName(widget.uid, newName);
                  if (mounted) setState(() => _state = updated);
                } catch (_) {
                  // Silently fail
                }
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFFC7A867)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1630),
            Color(0xFF211637),
            Color(0xFF0D0B1E),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFB58E34).withValues(alpha: 0.42),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  color: Color(0xFFB58E34),
                  strokeWidth: 2,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: owl name + edit icon
                _buildHeader(),
                const SizedBox(height: 10),
                // Owl sprite + moon bond progress
                _buildOwlSection(),
                const SizedBox(height: 10),
                // Status message
                if (_statusMessage != null) ...[
                  Text(
                    _statusMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFFE5D5F5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // Action button
                _buildActionButton(),
                const SizedBox(height: 12),
                // Footer message
                const Center(
                  child: Text(
                    'Owl brings a gift when moon bond is filled or when he feels like it',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8B80A0),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _showRenameDialog,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _state.owlName.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.6,
                      color: Color(0xFFC7A867),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: const Color(0xFFC7A867).withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOwlSection() {
    return Row(
      children: [
        // Animated owl sprite
        GestureDetector(
          onTap: _petOwl,
          child: OwlSpriteAnimator(
            pose: _currentPose,
            size: 80,
            frameDuration: _currentPose == OwlPose.alerted
                ? const Duration(milliseconds: 150)
                : const Duration(milliseconds: 250),
          ),
        ),
        const SizedBox(width: 14),
        // Moon bond progress
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Moon Bond',
                style: GoogleFonts.cinzel(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: const Color(0xFFC7A867),
                ),
              ),
              const SizedBox(height: 8),
              _buildMoonDots(),
              const SizedBox(height: 6),
              Text(
                _state.rewardAvailable
                    ? 'Your owl has a gift for you!'
                    : _state.isPettedToday()
                        ? 'Moon Bond filled for today ✓'
                        : 'Pet your owl to fill the Moon Bond',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFE5D5F5),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoonDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final filled = i < _state.petProgress;
        return AnimatedBuilder(
          animation: _glowController,
          builder: (context, _) {
            final glowIntensity = filled
                ? 0.4 + math.sin(_glowController.value * math.pi * 2 + i * 0.5) * 0.2
                : 0.0;
            return Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? const Color(0xFFC7A867)
                    : const Color(0xFF2E2650),
                border: Border.all(
                  color: filled
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF3D3560),
                  width: 1.5,
                ),
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: glowIntensity),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  filled ? '🌕' : '🌑',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildActionButton() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _claiming || _petting
                ? null
                : () {
                    if (_state.rewardAvailable) {
                      _claimReward();
                    } else {
                      _petOwl();
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(
                  colors: _state.rewardAvailable
                      ? const [Color(0xFFB58E34), Color(0xFFF59E0B)]
                      : const [Color(0xFF5D4037), Color(0xFF3E2723)], // Branch-like brown
                ),
              ),
              child: Center(
                child: Text(
                  _claiming
                      ? 'OPENING...'
                      : _petting
                          ? 'PETTING...'
                          : _state.rewardAvailable
                              ? 'OPEN GIFT'
                              : 'PET OWL',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
