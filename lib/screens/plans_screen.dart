import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/monetization_status.dart';
import '../services/monetization_service.dart';
import '../widgets/monetization_paywall_preview.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final _monetizationService = MonetizationService();
  late Future<MonetizationStatus> _statusFuture;

  static const _gold = Color(0xFFC7A867);
  static const _deepGold = Color(0xFFB58E34);
  static const _ink = Color(0xFFE5D5F5);
  static const _muted = Color(0xFF9C90B8);
  static const _panel = Color(0xFF151126);

  @override
  void initState() {
    super.initState();
    _statusFuture = _monetizationService.status();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _ink,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        title: Text(
          'PLANS',
          style: GoogleFonts.cinzel(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _PlansBackdrop()),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 126),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  _heroPanel(),
                  const SizedBox(height: 18),
                  MonetizationPaywallPreview(
                    service: _monetizationService,
                    onStatusChanged: _handleStatusChanged,
                  ),
                  const SizedBox(height: 14),
                  _quietNote(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleStatusChanged(MonetizationStatus status) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _statusFuture = Future.value(status);
      });
    });
  }

  Widget _heroPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR ACCESS',
                style: GoogleFonts.cinzel(
                  color: _gold,
                  fontSize: 11,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<MonetizationStatus>(
                future: _statusFuture,
                builder: (context, snapshot) {
                  final status = snapshot.data;
                  return Text(
                    'Your plan: ${_currentPlanLabel(status)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              Text(
                'Choose your pace of guidance.',
                style: GoogleFonts.cormorantGaramond(
                  color: _ink,
                  fontSize: 31,
                  height: 1.02,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Free keeps Circle compatibility, your profile, and a small monthly allowance. Plus is for regular messages and readings. Dakshana is a small pack for occasional use.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _GlassPill(label: 'Circle stays free'),
                  _GlassPill(label: 'Yearly is unlimited'),
                  _GlassPill(label: 'Manual match in Plus'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quietNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _deepGold.withValues(alpha: 0.14)),
      ),
      child: const Text(
        'After a Google Play purchase, access usually updates automatically. If it does not appear right away, tap Restore or Refresh here. Subscriptions stay active until the paid period ends, even if renewal is cancelled.',
        style: TextStyle(
          color: _muted,
          fontSize: 11.5,
          height: 1.35,
        ),
      ),
    );
  }

  static String _currentPlanLabel(MonetizationStatus? status) {
    if (status == null || status.mode == 'unavailable') return 'Checking';
    if (status.plusActive) {
      switch (status.plan.trim().toLowerCase()) {
        case 'yearly':
        case 'annual':
          return 'Yearly Plus';
        case 'monthly':
          return 'Monthly Plus';
        default:
          return 'Bhrigu Plus';
      }
    }

    if (status.dakshana.totalCredits > 0) {
      return 'Dakshana credits';
    }

    return 'Free';
  }
}

class _PlansBackdrop extends StatelessWidget {
  const _PlansBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.35, -0.62),
          radius: 1.35,
          colors: [
            Color(0xFF2A183C),
            Color(0xFF100B1C),
            Color(0xFF050408),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFC7A867).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 118,
            child: Container(
              height: 1,
              color: const Color(0xFFC7A867).withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFFC7A867).withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC7A867),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
