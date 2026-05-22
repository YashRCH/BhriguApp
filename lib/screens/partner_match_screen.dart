import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/partner_match_flow.dart';
import '../models/partner_match_model.dart';
import '../services/partner_match_service.dart';
import '../services/follow_up_context_service.dart';
import '../widgets/ai_report_button.dart';
import '../widgets/compatibility_metric_card.dart';
import '../widgets/compatibility_score_ring.dart';
import '../widgets/heart_signal_card.dart';
import '../widgets/partner_birth_form.dart';
import '../widgets/partner_match_share_card.dart';

class PartnerMatchScreen extends StatefulWidget {
  const PartnerMatchScreen({super.key});

  @override
  State<PartnerMatchScreen> createState() => _PartnerMatchScreenState();
}

class _PartnerMatchScreenState extends State<PartnerMatchScreen> {
  final PartnerMatchService _service = PartnerMatchService();
  final FollowUpContextService _followUpService = FollowUpContextService();

  PartnerMatchFlow _flow = PartnerMatchFlow.initial();

  bool get _loading => _flow.loading;
  bool get _creatingFollowUp => _flow.creatingFollowUp;
  PartnerMatchReading? get _reading => _flow.reading;

  Future<void> _createReading(PartnerBirthProfile partner) async {
    setState(() {
      _flow = _flow.beginReading();
    });

    final reading = await _service.createReading(partner: partner);

    if (!mounted) return;

    setState(() {
      _flow = _flow.completeReading(reading);
    });
  }

  void _reset() {
    setState(() {
      _flow = PartnerMatchFlow.initial();
    });
  }

  Future<void> _openHistory() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _MatchHistorySheet(
          service: _service,
          onSelect: (reading) {
            Navigator.pop(context);
            setState(() {
              _flow = _flow.loadSaved(reading);
            });
          },
          onCleared: () {
            setState(() {
              _flow = PartnerMatchFlow.initial();
            });
          },
        );
      },
    );
  }

  Future<void> _openFollowUpChat({
    required PartnerMatchReading reading,
    required String question,
  }) async {
    if (_creatingFollowUp) return;

    setState(() {
      _flow = _flow.withFollowUpLoading(true);
    });

    try {
      final contextId = await _followUpService.createMatchFollowUpContext(
        originalQuestion: reading.partner.emotionalPrompt.trim().isEmpty
            ? 'Bhrigu Match compatibility reading for ${reading.user.name} and ${reading.partner.name}'
            : reading.partner.emotionalPrompt.trim(),
        selectedFollowUpQuestion: question,
        readingSummary: reading.summary,
        sourceData: _flow.followUpSourceData(),
      );

      if (!mounted) return;

      context.push('/chat', extra: contextId);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open follow-up chat: $e'),
          backgroundColor: const Color(0xFF6B21A8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _flow = _flow.withFollowUpLoading(false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090712),
      appBar: AppBar(
        leading: IconButton(
          onPressed: _openHistory,
          icon: const Icon(
            Icons.menu_book_rounded,
            color: Color(0xFFFFD88A),
          ),
          tooltip: 'Match history',
        ),
        title: const Text(
          'Bhrigu Match',
          style: TextStyle(
            color: Color(0xFFFFD88A),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF090712),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _reset,
            icon: const Icon(
              Icons.refresh,
              color: Color(0xFF9D6FE8),
            ),
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.7),
            radius: 1.25,
            colors: [
              Color(0xFF1A0C2E),
              Color(0xFF090712),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _heroCard(),
              const SizedBox(height: 16),
              PartnerBirthForm(
                loading: _loading,
                onSubmit: _createReading,
              ),
              if (_loading) ...[
                const SizedBox(height: 16),
                _loadingCard(),
              ],
              if (_reading != null) ...[
                const SizedBox(height: 16),
                _resultCard(_reading!),
                if (_flow.canFollowUp) ...[
                  const SizedBox(height: 16),
                  _followUpCard(_reading!),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compare two birth blueprints',
            style: GoogleFonts.cinzel(
              color: const Color(0xFFE5D5F5),
              fontSize: 23,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bhrigu reads emotional harmony, attraction, stability, karmic bond, and 36 Guna marriage compatibility.',
            style: GoogleFonts.cormorantGaramond(
              color: const Color(0xFFD4D4CE),
              fontSize: 18,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingCard() {
    return _glassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const _TeslaGlobeLoader(size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Bhrigu is reading the two birth blueprints...',
              style: GoogleFonts.cormorantGaramond(
                color: const Color(0xFFD4D4CE),
                fontSize: 18,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(PartnerMatchReading reading) {
    final scores = reading.scores;
    final safeOverallScore = scores.overall.clamp(60, 95).toInt();

    return Column(
      children: [
        _glassCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              CompatibilityScoreRing(score: safeOverallScore),
              const SizedBox(height: 18),
              Text(
                reading.verdict,
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFC7A867),
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF21163A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withAlpha(90),
                  ),
                ),
                child: Text(
                  reading.connectionType,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8B530),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${reading.user.name} × ${reading.partner.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB8AEE0),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _signRow(reading),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PartnerMatchShareButton(reading: reading),
        const SizedBox(height: 14),
        HeartSignalCard(
          prompt: reading.partner.emotionalPrompt,
          connectionType: reading.connectionType,
        ),
        const SizedBox(height: 14),
        CompatibilityMetricCard(
          title: 'Emotional Harmony',
          subtitle: 'Moon style and emotional rhythm',
          score: scores.emotional,
          icon: Icons.favorite_border,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Attraction Pull',
          subtitle: 'Chemistry, desire, and magnetic force',
          score: scores.attraction,
          icon: Icons.local_fire_department_outlined,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Communication',
          subtitle: 'How easily both minds understand each other',
          score: scores.communication,
          icon: Icons.forum_outlined,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Long-term Stability',
          subtitle: 'Patience, loyalty, and real-life bonding',
          score: scores.stability,
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Karmic Bond',
          subtitle: 'Lessons, familiarity, and soul-pattern intensity',
          score: scores.karmic,
          icon: Icons.all_inclusive,
        ),
        if (reading.marriageGunaMatch.items.isNotEmpty) ...[
          const SizedBox(height: 14),
          _marriageGunaCard(reading),
        ],
        const SizedBox(height: 14),
        _glassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bhrigu’s Verdict',
                style: TextStyle(
                  color: Color(0xFFFFD88A),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                reading.summary,
                style: const TextStyle(
                  color: Color(0xFFB8AEE0),
                  fontSize: 14.5,
                  height: 1.65,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: AiReportButton(
                  feature: 'match',
                  contentId: 'match_${reading.createdAt.toIso8601String()}',
                  contentText: reading.summary,
                  label: 'Report',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _followUpCard(PartnerMatchReading reading) {
    final questions = [
      'Should I trust this connection?',
      'What should I do next with this person?',
      'What is the karmic lesson in this match?',
    ];

    return _glassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF59E0B),
                      Color(0xFFFFD88A),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withAlpha(80),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: Color(0xFF21103D),
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask Bhrigu Deeper',
                      style: TextStyle(
                        color: Color(0xFFFFD88A),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Continue this fresh match reading in chat.',
                      style: TextStyle(
                        color: Color(0xFF8E83B5),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...questions.map(
            (question) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: _creatingFollowUp
                    ? null
                    : () => _openFollowUpChat(
                          reading: reading,
                          question: question,
                        ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21163A),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withAlpha(90),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          question,
                          style: const TextStyle(
                            color: Color(0xFFF0ECF8),
                            fontSize: 13.5,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _creatingFollowUp
                          ? const _TeslaGlobeLoader(size: 20)
                          : const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFFFFD88A),
                              size: 19,
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Text(
            'Follow-ups are created only from this current match, not from old history.',
            style: TextStyle(
              color: Color(0xFF6B6080),
              fontSize: 11.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _marriageGunaCard(PartnerMatchReading reading) {
    final marriage = reading.marriageGunaMatch;

    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF59E0B),
                      Color(0xFFFFD88A),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withAlpha(80),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF21103D),
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '36 Guna Marriage Match',
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFFC7A867),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Traditional 8-koota marriage harmony',
                      style: TextStyle(
                        color: Color(0xFF8E83B5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF21163A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withAlpha(100),
                  ),
                ),
                child: Text(
                  '${marriage.totalScore}/${marriage.maxScore}',
                  style: const TextStyle(
                    color: Color(0xFFFFD88A),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE8B530).withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: marriage.percentage.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: const Color(0xFF151126),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFE8B530),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            marriage.level,
            style: const TextStyle(
              color: Color(0xFFF0ECF8),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            marriage.summary,
            style: const TextStyle(
              color: Color(0xFFB8AEE0),
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: marriage.items.asMap().entries.map((entry) {
              return _gunaItemRow(
                entry.value,
                showDivider: entry.key != marriage.items.length - 1,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Bhrigu blends this marriage score into the overall compatibility result.',
            style: GoogleFonts.inter(
              color: const Color(0xFF6B6080),
              fontSize: 11.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gunaItemRow(GunaScoreItem item, {required bool showDivider}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '✦',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFE8B530),
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFFD4D4CE),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.meaning,
                      style: GoogleFonts.cormorantGaramond(
                        color: const Color(0xFFB8AEE0),
                        fontSize: 15.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${item.score}/${item.maxScore}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFE8B530),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(color: Color(0xFF2E2650), height: 1),
      ],
    );
  }

  // ignore: unused_element
  Widget _oldGunaItemRow(GunaScoreItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: Color(0xFFFFD88A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Color(0xFFF0ECF8),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.meaning,
                  style: const TextStyle(
                    color: Color(0xFF8E83B5),
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF21163A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF9D6FE8).withAlpha(80),
              ),
            ),
            child: Text(
              '${item.score}/${item.maxScore}',
              style: const TextStyle(
                color: Color(0xFFFFD88A),
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signRow(PartnerMatchReading reading) {
    return Row(
      children: [
        Expanded(
          child: _signChip(
            title: reading.user.name,
            sign: reading.userSunSign,
            mood: reading.userMoonStyle,
            borderColor: const Color(0xFFB58E34).withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _signChip(
            title: reading.partner.name,
            sign: reading.partnerSunSign,
            mood: reading.partnerMoonStyle,
            borderColor: const Color(0xFF9D6FE8).withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _signChip({
    required String title,
    required String sign,
    required String mood,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A18).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cinzel(
              color: const Color(0xFFE5D5F5),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            sign,
            style: const TextStyle(
              color: Color(0xFFFFD88A),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$mood Moon',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF8E83B5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    double borderRadius = 26,
    double? width,
    Color? borderColor,
  }) {
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9D6FE8).withValues(alpha: 0.1),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0A18).withValues(alpha: 0.5),
              borderRadius: radius,
              border: Border.all(
                color: borderColor ??
                    const Color(0xFFC7A867).withValues(alpha: 0.3),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  BoxDecoration _cardDecoration({
    Color? borderColor,
    Color? glowColor,
  }) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF151126),
          Color(0xFF0D0B1E),
        ],
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(
        color: borderColor ?? const Color(0xFF2E2650),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: glowColor ?? Colors.black.withAlpha(70),
          blurRadius: glowColor != null ? 34 : 22,
          spreadRadius: glowColor != null ? 3 : 0,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

class _MatchHistorySheet extends StatefulWidget {
  final PartnerMatchService service;
  final ValueChanged<PartnerMatchReading> onSelect;
  final VoidCallback onCleared;

  const _MatchHistorySheet({
    required this.service,
    required this.onSelect,
    required this.onCleared,
  });

  @override
  State<_MatchHistorySheet> createState() => _MatchHistorySheetState();
}

class _MatchHistorySheetState extends State<_MatchHistorySheet> {
  late Future<List<PartnerMatchReading>> _future;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _future = widget.service.getSavedReadings();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.service.getSavedReadings();
    });
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151126),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Clear match history?',
            style: TextStyle(
              color: Color(0xFFFFD88A),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This will permanently delete all saved Bhrigu Match readings from your history.',
            style: TextStyle(
              color: Color(0xFFB8AEE0),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF8E83B5),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: Color(0xFFFFD88A),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _clearing = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null || uid.isEmpty) {
        throw Exception('User not signed in');
      }

      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('partner_matches');

      final snap = await ref.get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      widget.onCleared();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match history cleared.'),
          backgroundColor: Color(0xFF6B21A8),
        ),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not clear history: $e'),
          backgroundColor: const Color(0xFF6B21A8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _clearing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF090712),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2650),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      color: Color(0xFFFFD88A),
                      size: 23,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Bhrigu Match History',
                        style: TextStyle(
                          color: Color(0xFFFFD88A),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _clearing ? null : _clearHistory,
                      tooltip: 'Clear history',
                      icon: _clearing
                          ? const _TeslaGlobeLoader(size: 22)
                          : const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFFFD88A),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Open a previous compatibility reading.',
                    style: TextStyle(
                      color: Color(0xFF8E83B5),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: FutureBuilder<List<PartnerMatchReading>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: _TeslaGlobeLoader(size: 54),
                      );
                    }

                    final readings = snapshot.data ?? [];

                    if (readings.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(26),
                          child: Text(
                            'No saved matches yet. Create a Bhrigu Match and it will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF8E83B5),
                              fontSize: 13.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      itemCount: readings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final reading = readings[index];
                        return _historyTile(reading);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _historyTile(PartnerMatchReading reading) {
    final safeOverall = reading.scores.overall.clamp(60, 95).toInt();
    final date = reading.createdAt;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return GestureDetector(
      onTap: () => widget.onSelect(reading),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF151126),
              Color(0xFF0D0B1E),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF2E2650),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF21163A),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withAlpha(100),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withAlpha(35),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$safeOverall',
                  style: const TextStyle(
                    color: Color(0xFFFFD88A),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${reading.user.name} × ${reading.partner.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF0ECF8),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    reading.connectionType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB8AEE0),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (reading.marriageGunaMatch.maxScore > 0)
                        Text(
                          '${reading.marriageGunaMatch.totalScore}/${reading.marriageGunaMatch.maxScore} Guna',
                          style: const TextStyle(
                            color: Color(0xFFFFD88A),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (reading.marriageGunaMatch.maxScore > 0)
                        const Text(
                          '  •  ',
                          style: TextStyle(
                            color: Color(0xFF6B6080),
                            fontSize: 11.5,
                          ),
                        ),
                      Text(
                        dateText,
                        style: const TextStyle(
                          color: Color(0xFF6B6080),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF6B6080),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeslaGlobeLoader extends StatefulWidget {
  final double size;

  const _TeslaGlobeLoader({required this.size});

  @override
  State<_TeslaGlobeLoader> createState() => _TeslaGlobeLoaderState();
}

class _TeslaGlobeLoaderState extends State<_TeslaGlobeLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _TeslaGlobePainter(_controller.value),
          );
        },
      ),
    );
  }
}

class _TeslaGlobePainter extends CustomPainter {
  final double progress;

  _TeslaGlobePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final glassPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF9D6FE8).withAlpha(38),
        ],
        stops: const [0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, glassPaint);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFB58E34).withAlpha(102)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.drawCircle(
      center,
      radius * 0.25,
      Paint()
        ..color = const Color(0xFFB58E34).withAlpha(153)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()..color = const Color(0xFFC7A867),
    );

    canvas.drawCircle(
      center,
      radius * 0.06,
      Paint()..color = Colors.white,
    );

    final fixedRandom = math.Random(42);
    const numTendrils = 7;

    for (int i = 0; i < numTendrils; i++) {
      final baseAngle = i * 2 * math.pi / numTendrils;
      final dynamicAngle =
          baseAngle + math.sin(progress * 2 * math.pi + i) * 0.5;

      final endPoint = Offset(
        center.dx + math.cos(dynamicAngle) * radius * 0.95,
        center.dy + math.sin(dynamicAngle) * radius * 0.95,
      );

      final wave1 = math.cos(progress * 4 * math.pi + i * 2);
      final wave2 = math.sin(progress * 6 * math.pi + i * 3);

      final cp1 = Offset(
        center.dx + math.cos(dynamicAngle + wave1 * 0.8) * radius * 0.4,
        center.dy + math.sin(dynamicAngle + wave1 * 0.8) * radius * 0.4,
      );

      final cp2 = Offset(
        center.dx + math.cos(dynamicAngle - wave2 * 0.6) * radius * 0.7,
        center.dy + math.sin(dynamicAngle - wave2 * 0.6) * radius * 0.7,
      );

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, endPoint.dx, endPoint.dy);

      final flicker = 0.5 +
          fixedRandom.nextDouble() * 0.5 +
          math.sin(progress * 20 * math.pi + i) * 0.2;

      final safeFlicker = flicker.clamp(0.2, 1.0);

      final tendrilColor =
          i % 2 == 0 ? const Color(0xFFE040FB) : const Color(0xFF00E5FF);

      canvas.drawPath(
        path,
        Paint()
          ..color = tendrilColor.withAlpha((153 * safeFlicker).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      canvas.drawPath(
        path,
        Paint()
          ..color =
              const Color(0xFFE5D5F5).withAlpha((230 * safeFlicker).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      canvas.drawCircle(
        endPoint,
        3.0 * safeFlicker,
        Paint()
          ..color =
              const Color(0xFFE5D5F5).withAlpha((255 * safeFlicker).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TeslaGlobePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
