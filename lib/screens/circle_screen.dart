import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/social_connection_model.dart';
import '../services/connection_service.dart';
import '../widgets/cosmic_screen_background.dart';

class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key});

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen>
    with TickerProviderStateMixin {
  final _connectionService = ConnectionService();

  late final AnimationController _emblemController;
  late final AnimationController _breathController;
  late final Animation<double> _breathAnimation;

  @override
  void initState() {
    super.initState();
    _emblemController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 0.1, end: 0.35).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _emblemController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  Future<void> _accept(SocialConnection connection) async {
    try {
      // BUG-C FIXED: relationshipType param removed — the server uses the
      // stored value from the pending connection doc and ignores any client value.
      await _connectionService.acceptConnectionRequest(
        requesterUid: connection.otherUid,
      );
    } catch (e, stack) {
      _logError('Accept Circle request failed', e, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not accept request right now.')),
      );
    }
  }

  Future<void> _decline(SocialConnection connection) async {
    try {
      await _connectionService.declineConnectionRequest(
        requesterUid: connection.otherUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request declined.')),
      );
    } catch (e, stack) {
      _logError('Decline Circle request failed', e, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not decline request right now.')),
      );
    }
  }

  Future<void> _cancel(SocialConnection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF15110A),
        title: const Text(
          'Cancel request?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Your request to ${connection.otherProfile.displayName} will be deleted.',
          style: const TextStyle(color: Color(0xFFB8AEE0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Cancel it',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _connectionService.cancelConnectionRequest(
        targetUid: connection.otherUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request cancelled.')),
      );
    } catch (e, stack) {
      _logError('Cancel Circle request failed', e, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not cancel request right now.')),
      );
    }
  }

  void _logError(String message, Object error, StackTrace stack) {
    debugPrint('$message: $error');
    debugPrintStack(stackTrace: stack);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Scaffold(
      backgroundColor: const Color(0xFF050408),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'CIRCLE',
          style: GoogleFonts.cinzel(
            color: const Color(0xFFB58E34),
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Manual Match',
            onPressed: () => context.push('/bhrigu-match/manual'),
            icon: const Icon(Icons.favorite_rounded),
          ),
          IconButton(
            tooltip: 'Add',
            onPressed: () => context.push('/bhrigu-match/add'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      body: CosmicScreenBackground(
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _breathAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.6),
                      radius: 1.5,
                      colors: [
                        const Color(0xFFC7A867)
                            .withValues(alpha: _breathAnimation.value * 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: topPadding + 24,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 210,
                  height: 210,
                  child: AnimatedBuilder(
                    animation:
                        Listenable.merge([_emblemController, _breathAnimation]),
                    builder: (context, _) => CustomPaint(
                      painter: _CircleEmblemPainter(
                        rotationProgress: _emblemController.value,
                        pulse: _breathAnimation.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: StreamBuilder<List<SocialConnection>>(
                stream: _connectionService.watchConnections(),
                builder: (context, snapshot) {
                  // FIXED: Check loading state BEFORE processing data so the spinner
                  // is shown immediately rather than after an empty list flash.
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.data == null) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFD88A),
                      ),
                    );
                  }

                  final connections =
                      snapshot.data ?? const <SocialConnection>[];
                  final active = connections
                      .where(
                        (item) => item.status == SocialConnectionStatus.active,
                      )
                      .toList(growable: false);
                  final incoming = connections
                      .where(
                        (item) =>
                            item.status == SocialConnectionStatus.incoming,
                      )
                      .toList(growable: false);
                  final outgoing = connections
                      .where(
                        (item) =>
                            item.status == SocialConnectionStatus.outgoing,
                      )
                      .toList(growable: false);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
                    children: [
                      _sectionHeader('Your Circle', active.length),
                      if (active.isEmpty)
                        _emptyCard()
                      else
                        ...active.map(_connectionTile),
                      const SizedBox(height: 22),
                      _sectionHeader(
                        'Requests',
                        incoming.length + outgoing.length,
                      ),
                      if (incoming.isEmpty && outgoing.isEmpty)
                        _softCard(
                          child: const Text(
                            'No pending requests yet.',
                            style: TextStyle(color: Color(0xFFB8AEE0)),
                          ),
                        )
                      else ...[
                        ...incoming.map(
                          (connection) =>
                              _requestTile(connection, incoming: true),
                        ),
                        ...outgoing.map(
                          (connection) =>
                              _requestTile(connection, incoming: false),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFC7A867),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(color: Color(0xFF6B6080)),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return _softCard(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No one in your Circle yet.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add a friend or a spouse in Circle to view their daily energy, relationship compatibility, and private guidance based on your birth chart and theirs in Bhrigu Chat.\n\nTap the add icon above to search a username, share an invite link, or enter a code.',
            style: TextStyle(color: Color(0xFFB8AEE0), height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _connectionTile(SocialConnection connection) {
    return _softCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: _avatar(connection.otherProfile),
        title: Text(
          connection.otherProfile.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${connection.relationshipType.label} · ${connection.otherProfile.chartSummary}',
          style: const TextStyle(color: Color(0xFFB8AEE0)),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: Color(0xFFFFD88A),
          size: 16,
        ),
        onTap: () => context.push(
          '/bhrigu-match/connection/${connection.connectionId}',
        ),
      ),
    );
  }

  Widget _requestTile(
    SocialConnection connection, {
    required bool incoming,
  }) {
    return _softCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _avatar(connection.otherProfile),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connection.otherProfile.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  incoming
                      ? 'Wants to join your Circle as ${connection.relationshipType.label.toLowerCase()}.'
                      : 'Waiting for them to accept.',
                  style: const TextStyle(
                    color: Color(0xFFB8AEE0),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (incoming) ...[
            // Decline button for incoming requests
            TextButton(
              onPressed: () => _decline(connection),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF9E7070),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text('Decline'),
            ),
            // Accept button for incoming requests
            TextButton(
              onPressed: () => _accept(connection),
              child: const Text('Accept'),
            ),
          ] else
            // Cancel button for outgoing requests
            TextButton(
              onPressed: () => _cancel(connection),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF9E7070),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text('Cancel'),
            ),
        ],
      ),
    );
  }

  Widget _avatar(PublicAstrologyProfile profile) {
    final initial = profile.displayName.trim().isEmpty
        ? 'B'
        : profile.displayName.trim()[0].toUpperCase();

    return CircleAvatar(
      backgroundColor: const Color(0xFF21103D),
      foregroundColor: const Color(0xFFFFD88A),
      child: Text(initial),
    );
  }

  Widget _softCard({
    required Widget child,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF15110A).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A301C)),
      ),
      child: child,
    );
  }
}

class _CircleEmblemPainter extends CustomPainter {
  final double rotationProgress;
  final double pulse;

  _CircleEmblemPainter({required this.rotationProgress, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.42;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    final timeMs = DateTime.now().millisecondsSinceEpoch;
    final tCycle = timeMs % 1200;
    double beatScale = 1.0;
    if (tCycle < 150) {
      beatScale = 1.0 + 0.06 * math.sin((tCycle / 150) * math.pi);
    } else if (tCycle > 250 && tCycle < 450) {
      beatScale = 1.0 + 0.04 * math.sin(((tCycle - 250) / 200) * math.pi);
    }

    canvas.save();
    canvas.rotate(-rotationProgress * 2 * math.pi * 0.5);
    final orbitPaint = Paint()
      ..color = const Color(0xFFC7A867)
          .withValues(alpha: 0.2 + 0.1 * pulse + (beatScale - 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + ((beatScale - 1.0) * 20);

    final currentRadius = maxRadius * beatScale;
    _drawDashedCircle(canvas, Offset.zero, currentRadius, orbitPaint);
    canvas.restore();

    canvas.rotate(rotationProgress * 2 * math.pi);

    final linePaint = Paint()
      ..color = const Color(0xFFC7A867).withValues(alpha: 0.35 + 0.25 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 + (0.3 * pulse);

    final highlightPaint = Paint()
      ..color = const Color(0xFFE5D5F5).withValues(alpha: 0.5 + 0.3 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final vpRadius = maxRadius * 0.45;
    for (int i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 2);
      canvas.drawCircle(Offset(vpRadius * 0.8, 0), vpRadius, linePaint);
      canvas.restore();
    }

    final hexRadius = maxRadius * 0.75;
    final triangle1 = Path();
    final triangle2 = Path();

    for (int i = 0; i < 3; i++) {
      final angle1 = i * (2 * math.pi / 3) - math.pi / 2;
      final p1 =
          Offset(hexRadius * math.cos(angle1), hexRadius * math.sin(angle1));
      if (i == 0) {
        triangle1.moveTo(p1.dx, p1.dy);
      } else {
        triangle1.lineTo(p1.dx, p1.dy);
      }

      final angle2 = i * (2 * math.pi / 3) + math.pi / 2;
      final p2 =
          Offset(hexRadius * math.cos(angle2), hexRadius * math.sin(angle2));
      if (i == 0) {
        triangle2.moveTo(p2.dx, p2.dy);
      } else {
        triangle2.lineTo(p2.dx, p2.dy);
      }
    }
    triangle1.close();
    triangle2.close();

    canvas.drawPath(triangle1, linePaint);
    canvas.drawPath(triangle2, linePaint);

    for (int i = 0; i < 6; i++) {
      final angle = i * (math.pi / 3) + math.pi / 6;
      final p =
          Offset(hexRadius * math.cos(angle), hexRadius * math.sin(angle));
      canvas.drawLine(Offset.zero, p, highlightPaint);
    }

    final diamondRadius = maxRadius * 0.15;
    final diamond = Path()
      ..moveTo(0, -diamondRadius)
      ..lineTo(diamondRadius, 0)
      ..lineTo(0, diamondRadius)
      ..lineTo(-diamondRadius, 0)
      ..close();

    final fillPaint = Paint()
      ..color = const Color(0xFFC7A867).withValues(alpha: 0.15 + 0.15 * pulse)
      ..style = PaintingStyle.fill;

    canvas.drawPath(diamond, fillPaint);
    canvas.drawPath(diamond, highlightPaint);

    canvas.drawCircle(Offset.zero, hexRadius, linePaint);

    canvas.restore();
  }

  void _drawDashedCircle(
      Canvas canvas, Offset center, double radius, Paint paint) {
    const int dashCount = 36;
    final double dashLength = (2 * math.pi * radius) / (dashCount * 2);
    final double dashAngle = dashLength / radius;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * 2 * dashAngle;
      final path = Path()
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          dashAngle,
          true,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircleEmblemPainter oldDelegate) {
    return oldDelegate.rotationProgress != rotationProgress ||
        oldDelegate.pulse != pulse;
  }
}
