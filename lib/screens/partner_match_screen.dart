import 'dart:math' as math;

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
import '../widgets/zodiac_sign_icon.dart';

const _matchBlack = Color(0xFF050505);
const _matchPanel = Color(0xFF0D0B08);
const _matchPanelSoft = Color(0xFF15110A);
const _matchGold = Color(0xFFFFD88A);
const _matchGoldDeep = Color(0xFFC7A867);
const _matchWhite = Color(0xFFFFFFFF);
const _matchMuted = Color(0xCCFFFFFF);
const _matchLine = Color(0xFF3A301C);

class PartnerMatchScreen extends StatefulWidget {
  const PartnerMatchScreen({super.key});

  @override
  State<PartnerMatchScreen> createState() => _PartnerMatchScreenState();
}

class _PartnerMatchScreenState extends State<PartnerMatchScreen>
    with TickerProviderStateMixin {
  final PartnerMatchService _service = PartnerMatchService();
  final FollowUpContextService _followUpService = FollowUpContextService();

  late final AnimationController _breathController;
  late final Animation<double> _breathAnimation;
  late final AnimationController _emblemController;

  PartnerMatchFlow _flow = PartnerMatchFlow.initial();
  int _readingRequestId = 0;

  bool get _loading => _flow.loading;
  bool get _creatingFollowUp => _flow.creatingFollowUp;
  PartnerMatchReading? get _reading => _flow.reading;

  Future<void> _createReading(PartnerBirthProfile partner) async {
    if (_loading) return;

    final requestId = ++_readingRequestId;

    setState(() {
      _flow = _flow.beginReading();
    });

    try {
      final reading = await _service.createReading(partner: partner);

      if (!mounted || requestId != _readingRequestId) return;

      setState(() {
        _flow = _flow.completeReading(reading);
      });
    } catch (e) {
      if (!mounted || requestId != _readingRequestId) return;

      setState(() {
        _flow = PartnerMatchFlow.initial();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create this match reading. Try again.'),
          backgroundColor: _matchPanel,
        ),
      );
    }
  }

  void _reset() {
    _readingRequestId++;
    setState(() {
      _flow = PartnerMatchFlow.initial();
    });
  }

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 0.1, end: 0.35).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    _emblemController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _emblemController.dispose();
    _breathController.dispose();
    super.dispose();
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
              _readingRequestId++;
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
        aiResponseLanguage: reading.aiResponseLanguage,
      );

      if (!mounted) return;

      context.push('/chat', extra: contextId);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open follow-up chat: $e'),
          backgroundColor: _matchPanel,
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
      backgroundColor: const Color(0xFF050408),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'BHRIGU MATCH',
            style: GoogleFonts.cinzel(
              color: const Color(0xFFB58E34).withValues(alpha: 0.9),
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 4.0,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFB58E34)),
        leading: IconButton(
          onPressed: _openHistory,
          icon: const Icon(Icons.menu_book_rounded),
          tooltip: 'Match history',
        ),
        actions: [
          IconButton(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1.2,
                colors: [
                  Color(0xFF1E1430),
                  Color(0xFF0F0A18),
                  Color(0xFF050408),
                ],
              ),
            ),
          ),
          Opacity(
            opacity: 0.08,
            child: CustomPaint(
              size: Size.infinite,
              painter: _CelestialConnectionPainter(),
            ),
          ),
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
          SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                if (!_flow.isRevealed) ...[
                  _heroCard(),
                  const SizedBox(height: 24),
                  Center(
                    child: SizedBox(
                      width: 210,
                      height: 210,
                      child: AnimatedBuilder(
                        animation: Listenable.merge(
                            [_emblemController, _breathAnimation]),
                        builder: (context, _) => CustomPaint(
                          painter: _MatchEmblemPainter(
                            rotationProgress: _emblemController.value,
                            pulse: _breathAnimation.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PartnerBirthForm(
                    loading: _loading,
                    onSubmit: _createReading,
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 16),
                    _loadingCard(),
                  ],
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutQuart,
                  alignment: Alignment.topCenter,
                  child: _flow.isRevealed
                      ? Column(
                          children: [
                            _resultCard(_reading!),
                            if (_flow.canFollowUp) ...[
                              const SizedBox(height: 16),
                              _followUpCard(_reading!),
                            ],
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return _glassCard(
      padding: const EdgeInsets.all(24),
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
              color: const Color(0xFFE5D5F5).withValues(alpha: 0.7),
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
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const _TeslaGlobeLoader(size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Bhrigu is reading the two birth blueprints...',
              style: GoogleFonts.cormorantGaramond(
                color: const Color(0xFFE5D5F5).withValues(alpha: 0.7),
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
    final showLegacyVerdict = reading.summary.trim().isEmpty;

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
                  color: _matchPanelSoft,
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
                '${reading.user.name} x ${reading.partner.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _matchWhite,
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
        _compatibilityMapCard(reading),
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
        _bhriguVerdictCard(reading),
        if (showLegacyVerdict) const SizedBox(height: 14),
        if (showLegacyVerdict)
          _glassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Bhrigu's Verdict",
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
                    color: _matchWhite,
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

  Widget _compatibilityMapCard(PartnerMatchReading reading) {
    final scores = reading.scores;
    final strongest = _scoreArea(scores, highest: true);
    final softest = _scoreArea(scores, highest: false);
    final marriage = reading.marriageGunaMatch;
    final marriageText = marriage.maxScore > 0
        ? '${marriage.totalScore}/${marriage.maxScore} - ${marriage.level}'
        : 'Not enough Guna data';

    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compatibility Map',
            style: GoogleFonts.cinzel(
              color: _matchGold,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.1,
            ),
          ),
          const SizedBox(height: 12),
          _dataInsightRow(
            icon: Icons.trending_up_rounded,
            title: 'Strongest Pull',
            value: strongest.label,
            body: _scoreAreaMeaning(strongest, positive: true),
          ),
          _dataInsightRow(
            icon: Icons.tune_rounded,
            title: 'Growth Edge',
            value: softest.label,
            body: _scoreAreaMeaning(softest, positive: false),
          ),
          _dataInsightRow(
            icon: Icons.auto_awesome,
            title: 'Marriage Lens',
            value: marriageText,
            body: marriage.summary.trim().isEmpty
                ? 'Bhrigu still weighs daily behavior, emotional maturity, and consistency alongside the score.'
                : marriage.summary,
          ),
          _dataInsightRow(
            icon: Icons.join_inner_rounded,
            title: 'Connection Dynamic',
            value: reading.connectionType,
            body:
                'Read this match as a living dynamic between ${reading.userSunSign} and ${reading.partnerSunSign}, not as a fixed fate.',
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _dataInsightRow({
    required IconData icon,
    required String title,
    required String value,
    required String body,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _matchPanelSoft,
                  border: Border.all(
                    color: _matchGold.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  icon,
                  color: _matchGold,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cinzel(
                        color: _matchGoldDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: _matchWhite,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      body,
                      style: GoogleFonts.cormorantGaramond(
                        color: _matchMuted,
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            color: _matchGold.withValues(alpha: 0.16),
            height: 1,
          ),
      ],
    );
  }

  Widget _bhriguVerdictCard(PartnerMatchReading reading) {
    final sections = _verdictSections(reading.summary);

    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _matchPanelSoft,
                  border: Border.all(
                    color: _matchGold.withValues(alpha: 0.65),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _matchGold.withValues(alpha: 0.16),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: _matchGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Bhrigu's Verdict",
                      style: TextStyle(
                        color: _matchGold,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A fuller reading of the compatibility data, heart signal, Guna match, and growth areas.',
                      style: GoogleFonts.inter(
                        color: _matchMuted,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sections.map(_verdictSectionBlock),
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
    );
  }

  Widget _verdictSectionBlock(_VerdictSection section) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
      decoration: BoxDecoration(
        color: _matchBlack.withValues(alpha: 0.34),
        border: Border(
          left: BorderSide(
            color: _matchGold.withValues(alpha: 0.85),
            width: 3,
          ),
          top: BorderSide(
            color: _matchGold.withValues(alpha: 0.12),
          ),
          right: BorderSide(
            color: _matchGold.withValues(alpha: 0.12),
          ),
          bottom: BorderSide(
            color: _matchGold.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: GoogleFonts.cinzel(
              color: _matchGoldDeep,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            section.body,
            style: GoogleFonts.cormorantGaramond(
              color: _matchWhite,
              fontSize: 17,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<_VerdictSection> _verdictSections(String text) {
    final cleaned = text.replaceAll('\r\n', '\n').trim();

    if (cleaned.isEmpty) {
      return const [
        _VerdictSection(
          title: 'Verdict',
          body: 'Bhrigu could not generate a detailed verdict for this match.',
        ),
      ];
    }

    final sections = <_VerdictSection>[];
    String? currentTitle;
    final buffer = <String>[];

    void flush() {
      final title = currentTitle;
      final body = buffer.join('\n').trim();

      if (title != null && body.isNotEmpty) {
        sections.add(_VerdictSection(title: title, body: body));
      }

      buffer.clear();
    }

    for (final line in cleaned.split('\n')) {
      final header = _verdictHeader(line);

      if (header != null) {
        flush();
        currentTitle = header.title;
        if (header.trailingText.isNotEmpty) {
          buffer.add(header.trailingText);
        }
        continue;
      }

      currentTitle ??= 'Bhrigu Reading';
      buffer.add(line.trimRight());
    }

    flush();

    if (sections.isEmpty) {
      return [
        _VerdictSection(title: 'Bhrigu Reading', body: cleaned),
      ];
    }

    return sections;
  }

  _VerdictHeader? _verdictHeader(String line) {
    final trimmed = line.trim();

    for (final entry in _verdictSectionAliases.entries) {
      final prefix = '${entry.key}:';

      if (trimmed.toLowerCase().startsWith(prefix.toLowerCase())) {
        return _VerdictHeader(
          title: entry.value,
          trailingText: trimmed.substring(prefix.length).trim(),
        );
      }
    }

    return null;
  }

  _ScoreArea _scoreArea(CompatibilityScores scores, {required bool highest}) {
    final areas = <_ScoreArea>[
      _ScoreArea(
        label: 'Emotional Harmony',
        score: scores.emotional,
        strengthText: 'Feelings have the clearest path to trust here.',
        growthText: 'Emotional needs may require slower, clearer reassurance.',
      ),
      _ScoreArea(
        label: 'Attraction Pull',
        score: scores.attraction,
        strengthText: 'Chemistry is the visible spark in this connection.',
        growthText: 'Chemistry should be checked against emotional safety.',
      ),
      _ScoreArea(
        label: 'Communication',
        score: scores.communication,
        strengthText: 'Conversation can become a bridge when both stay honest.',
        growthText:
            'Misunderstandings need repair before they become distance.',
      ),
      _ScoreArea(
        label: 'Long-term Stability',
        score: scores.stability,
        strengthText: 'Consistency can give this bond a practical foundation.',
        growthText: 'Daily consistency is the test this match should not skip.',
      ),
      _ScoreArea(
        label: 'Karmic Bond',
        score: scores.karmic,
        strengthText: 'There is a strong lesson or familiar pull between them.',
        growthText:
            'The lesson needs maturity so it does not become obsession.',
      ),
    ];

    return areas.reduce((current, next) {
      if (highest) {
        return next.score > current.score ? next : current;
      }

      return next.score < current.score ? next : current;
    });
  }

  String _scoreAreaMeaning(_ScoreArea area, {required bool positive}) {
    return positive ? area.strengthText : area.growthText;
  }

  static const _verdictSectionAliases = <String, String>{
    'Compatibility Snapshot': 'Compatibility Snapshot',
    'Attraction & Chemistry': 'Attraction & Chemistry',
    '36 Guna Marriage Reading': '36 Guna Marriage Reading',
    '36 Guna Marriage Match': '36 Guna Marriage Reading',
    "Bhrigu's Guidance": "Bhrigu's Guidance",
    'Long-Term Stability': 'Long-Term Stability',
    'Long-Term Potential': 'Long-Term Stability',
    'Communication Pattern': 'Communication Pattern',
    'Karmic Lesson': 'Karmic Lesson',
    'Growth Edge': 'Growth Edge',
    'Bhrigu Warning': 'Bhrigu Warning',
    'Emotional Bond': 'Emotional Bond',
    'Heart Signal': 'Heart Signal',
    'Attraction': 'Attraction & Chemistry',
    'Verdict': 'Verdict',
  };

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
                      _matchGoldDeep,
                      _matchGold,
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
                        color: _matchMuted,
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
                    color: _matchPanelSoft,
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
                            color: _matchWhite,
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
              color: _matchMuted,
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
                      _matchGoldDeep,
                      _matchGold,
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
                        color: _matchMuted,
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
                  color: _matchPanelSoft,
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
                backgroundColor: _matchBlack,
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
              color: _matchWhite,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            marriage.summary,
            style: const TextStyle(
              color: _matchMuted,
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
              color: _matchMuted,
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
                '*',
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
                        color: _matchMuted,
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
        if (showDivider) const Divider(color: _matchLine, height: 1),
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
                    color: _matchWhite,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.meaning,
                  style: const TextStyle(
                    color: _matchMuted,
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
              color: _matchPanelSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _matchGold.withAlpha(80),
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
            borderColor: _matchGoldDeep.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _signChip(
            title: reading.partner.name,
            sign: reading.partnerSunSign,
            mood: reading.partnerMoonStyle,
            borderColor: _matchGold.withValues(alpha: 0.55),
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
              color: _matchWhite,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ZodiacSignIcon(
                sign: sign,
                size: 30,
                fallbackColor: const Color(0xFFFFD88A),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  sign,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFD88A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$mood Moon',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _matchMuted,
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
    EdgeInsetsGeometry padding = const EdgeInsets.all(24),
    double? width,
    Color? glowColor,
  }) {
    final effectiveGlow = glowColor ?? const Color(0xFFC7A867).withAlpha(22);

    return Container(
      width: width ?? double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2E1A4A), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          if (effectiveGlow.a > 0)
            BoxShadow(
              color: effectiveGlow,
              blurRadius: 36,
              spreadRadius: 2,
            ),
        ],
      ),
      child: child,
    );
  }
}

class _CelestialConnectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC7A867).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center1 = Offset(size.width * 0.3, size.height * 0.4);
    final center2 = Offset(size.width * 0.7, size.height * 0.6);

    canvas.drawLine(center1, center2, paint);

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center1, 30.0 * i, paint);
      canvas.drawCircle(center2, 30.0 * i, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MatchEmblemPainter extends CustomPainter {
  final double rotationProgress;
  final double pulse;

  _MatchEmblemPainter({required this.rotationProgress, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.42;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Heartbeat Math (lub-dub)
    final timeMs = DateTime.now().millisecondsSinceEpoch;
    final tCycle = timeMs % 1200; // 1.2 second resting heart rate
    double beatScale = 1.0;
    if (tCycle < 150) {
      beatScale = 1.0 + 0.06 * math.sin((tCycle / 150) * math.pi); // Lub
    } else if (tCycle > 250 && tCycle < 450) {
      beatScale =
          1.0 + 0.04 * math.sin(((tCycle - 250) / 200) * math.pi); // Dub
    }

    // Outer rotating dotted orbit (with heartbeat pulse)
    canvas.save();
    canvas.rotate(-rotationProgress * 2 * math.pi * 0.5);
    final orbitPaint = Paint()
      ..color = const Color(0xFFC7A867)
          .withValues(alpha: 0.2 + 0.1 * pulse + (beatScale - 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          1.0 + ((beatScale - 1.0) * 20); // Thickens slightly on beat

    final currentRadius = maxRadius * beatScale;
    _drawDashedCircle(canvas, Offset.zero, currentRadius, orbitPaint);
    canvas.restore();

    // Rotate the inner geometric construct
    canvas.rotate(rotationProgress * 2 * math.pi);

    final linePaint = Paint()
      ..color = const Color(0xFFC7A867).withValues(alpha: 0.35 + 0.25 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 + (0.3 * pulse);

    final highlightPaint = Paint()
      ..color = const Color(0xFFE5D5F5).withValues(alpha: 0.5 + 0.3 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // 1. Double Vesica Piscis (vertical and horizontal)
    final vpRadius = maxRadius * 0.45;
    for (int i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 2);
      canvas.drawCircle(Offset(vpRadius * 0.8, 0), vpRadius, linePaint);
      canvas.restore();
    }

    // 2. The central hexagonal star (Merkabah / Star of David)
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

    // 3. Connect the vertices to the center to form 3D geometry rays
    for (int i = 0; i < 6; i++) {
      final angle = i * (math.pi / 3) + math.pi / 6;
      final p =
          Offset(hexRadius * math.cos(angle), hexRadius * math.sin(angle));
      canvas.drawLine(Offset.zero, p, highlightPaint);
    }

    // 4. Central diamond focus point
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

    // 5. Outer enclosing ring bounding the hexagram
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
  bool shouldRepaint(covariant _MatchEmblemPainter oldDelegate) {
    return oldDelegate.rotationProgress != rotationProgress ||
        oldDelegate.pulse != pulse;
  }
}

class _VerdictSection {
  final String title;
  final String body;

  const _VerdictSection({
    required this.title,
    required this.body,
  });
}

class _VerdictHeader {
  final String title;
  final String trailingText;

  const _VerdictHeader({
    required this.title,
    required this.trailingText,
  });
}

class _ScoreArea {
  final String label;
  final int score;
  final String strengthText;
  final String growthText;

  const _ScoreArea({
    required this.label,
    required this.score,
    required this.strengthText,
    required this.growthText,
  });
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
  static const _firestoreBatchWriteLimit = 500;

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
          backgroundColor: _matchPanel,
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
              color: _matchMuted,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: _matchMuted,
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

      var batch = FirebaseFirestore.instance.batch();
      var writes = 0;

      for (final doc in snap.docs) {
        batch.delete(doc.reference);
        writes++;

        if (writes >= _firestoreBatchWriteLimit) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          writes = 0;
        }
      }

      if (writes > 0) {
        await batch.commit();
      }

      widget.onCleared();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match history cleared.'),
          backgroundColor: _matchPanel,
        ),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not clear history: $e'),
          backgroundColor: _matchPanel,
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
            color: _matchBlack,
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
                  color: _matchLine,
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
                      color: _matchMuted,
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
                              color: _matchMuted,
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
              _matchPanelSoft,
              _matchPanel,
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _matchLine,
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
                color: _matchPanelSoft,
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
                    '${reading.user.name} x ${reading.partner.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _matchWhite,
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
                      color: _matchMuted,
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
                          '  -  ',
                          style: TextStyle(
                            color: _matchMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      Text(
                        dateText,
                        style: const TextStyle(
                          color: _matchMuted,
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
              color: _matchMuted,
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
          _matchGold.withAlpha(38),
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

      final tendrilColor = i % 2 == 0 ? _matchGold : _matchGoldDeep;

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
          ..color = _matchWhite.withAlpha((230 * safeFlicker).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      canvas.drawCircle(
        endPoint,
        3.0 * safeFlicker,
        Paint()
          ..color = _matchWhite.withAlpha((255 * safeFlicker).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TeslaGlobePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
