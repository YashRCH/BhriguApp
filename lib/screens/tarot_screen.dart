import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/tarot_hints.dart';
import '../models/tarot_card.dart';
import '../models/tarot_reading_flow.dart';
import '../services/follow_up_context_service.dart';
import '../services/tarot_service.dart';
import '../widgets/ai_report_button.dart';
import '../widgets/ai_disclaimer.dart';
import '../widgets/feature_quota_chip.dart';
import '../widgets/plans_cta_button.dart';
import '../widgets/tarot_share_card.dart';
import '../constants/random_prompts.dart';

class TarotScreen extends StatefulWidget {
  const TarotScreen({super.key});

  @override
  State<TarotScreen> createState() => _TarotScreenState();
}

class _TarotScreenState extends State<TarotScreen>
    with TickerProviderStateMixin {
  final _service = TarotService();
  final _followUpService = FollowUpContextService();
  final _questionController = TextEditingController();

  Timer? _hintTimer;
  int _hintIndex = 0;

  TarotReadingFlow _flow = TarotReadingFlow.initial();
  final List<AnimationController> _flipControllers = [];
  final List<Animation<double>> _flipAnimations = [];
  int _readingRequestId = 0;
  int _quotaRefreshTick = 0;

  late final AnimationController _breathController;
  late final Animation<double> _breathAnimation;

  late final AnimationController _plasmaController;

  ui.Image? _tarotBackImage;

  List<TarotCard>? get _cards => _flow.cards;
  List<bool> get _revealed => _flow.revealed;
  String get _reading => _flow.reading;
  bool get _readingLoading => _flow.readingLoading;
  bool get _allRevealed => _flow.allRevealed;
  bool get _followUpLoading => _flow.followUpLoading;
  bool get _readingStarted => _flow.readingStarted;
  bool _isArtGlowing = false;
  bool _showGuideText = true;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showGuideText = false);
    });

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _plasmaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    for (int i = 0; i < 3; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600),
      );
      _flipControllers.add(ctrl);
      _flipAnimations.add(
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic),
        ),
      );
    }

    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      if (_questionController.text.trim().isNotEmpty) return;
      if (_cards != null) return;

      setState(() {
        _hintIndex = (_hintIndex + 1) % tarotHints.length;
      });
    });

    _loadTarotBackImage();
  }

  Future<void> _loadTarotBackImage() async {
    try {
      final data = await DefaultAssetBundle.of(context)
          .load('assets/tarot/Tarotback.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _tarotBackImage = frame.image;
        });
      }
    } catch (_) {
      // Falls back to canvas design if image can't load
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _breathController.dispose();
    _plasmaController.dispose();
    for (final c in _flipControllers) {
      c.dispose();
    }
    _questionController.dispose();
    super.dispose();
  }

  void _drawCards() {
    if (_questionController.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _readingRequestId++;
      _flow = TarotReadingFlow.drawn(_service.drawThreeCards());
    });
    for (final c in _flipControllers) {
      c.reset();
    }
  }

  Future<void> _revealCard(int index) async {
    if (_revealed[index] || _cards == null) return;
    setState(() => _flow = _flow.reveal(index));
    await _flipControllers[index].forward();
    if (!mounted) return;
    if (_revealed.every((r) => r) && !_readingStarted) {
      _startReading();
    }
  }

  void _startReading() async {
    final cards = _cards;

    if (cards == null || _readingStarted) return;

    final requestId = ++_readingRequestId;

    setState(() {
      _flow = _flow.beginReading();
    });
    final result = await _service.interpretReading(
      question: _questionController.text.trim(),
      past: cards[0],
      present: cards[1],
      future: cards[2],
    );

    if (!mounted || requestId != _readingRequestId) return;

    setState(() {
      _flow = _flow.completeReading(
        result.text,
        aiResponseLanguage: result.aiResponseLanguage,
      );
      _quotaRefreshTick++;
    });
  }

  Future<void> _openHistory() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _TarotHistorySheet(
          service: _service,
          onSelect: (savedReading) {
            Navigator.pop(context);
            for (final c in _flipControllers) {
              c.value = 1;
            }
            setState(() {
              _readingRequestId++;
              _questionController.text = savedReading.question;
              _flow = TarotReadingFlow.saved(
                reading: savedReading.reading,
                past: savedReading.past,
                present: savedReading.present,
                future: savedReading.future,
                aiResponseLanguage: savedReading.aiResponseLanguage,
              );
            });
          },
          onCleared: () {
            setState(() {
              _readingRequestId++;
              _flow = TarotReadingFlow.initial();
              _questionController.clear();
            });
          },
        );
      },
    );
  }

  Future<void> _openTarotFollowUp(String selectedFollowUpQuestion) async {
    if (_cards == null || _reading.trim().isEmpty || _readingLoading) return;
    if (_followUpLoading) return;

    setState(() {
      _flow = _flow.withFollowUpLoading(true);
    });

    try {
      final contextId = await _followUpService.createTarotFollowUpContext(
        originalQuestion: _questionController.text.trim(),
        selectedFollowUpQuestion: selectedFollowUpQuestion,
        readingSummary: _reading.trim(),
        pastCard: _cards![0].name,
        presentCard: _cards![1].name,
        futureCard: _cards![2].name,
        fullReading: _reading.trim(),
        aiResponseLanguage: _flow.aiResponseLanguage,
      );

      if (!mounted) return;

      context.push('/chat', extra: contextId);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not prepare this follow-up. Please try again.'),
          backgroundColor: Color(0xFF1A1630),
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: _openHistory,
          icon: const Icon(
            Icons.menu_book_rounded,
            color: Color(0xFFB58E34),
          ),
          tooltip: 'Tarot history',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'TAROT',
          style: GoogleFonts.cinzel(
            color: const Color(0xFFB58E34).withValues(alpha: 0.9),
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 6.0,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFB58E34)),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.2,
                colors: [
                  Color(0xFF1E1430),
                  Color(0xFF0F0A18),
                  Color(0xFF050408),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: CustomPaint(
                painter: _MysticVinePainter(),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _breathAnimation,
            builder: (context, _) => Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.5),
                    radius: 1.5,
                    colors: [
                      const Color(0xFFB58E34).withValues(
                        alpha: 0.04 * _breathAnimation.value,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                  left: 24, right: 24, top: 10, bottom: 120),
              child: _cards == null ? _initialState() : _spreadState(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialState() {
    final canDraw = _questionController.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Text(
          'Sit with Bhrigu',
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFC7A867),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Quiet your mind. Hold your question.\nThe deck awaits your hand.',
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 18,
            color: Colors.white60,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => setState(() => _isArtGlowing = true),
          onPointerUp: (_) => setState(() => _isArtGlowing = false),
          onPointerCancel: (_) => setState(() => _isArtGlowing = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () {
              final prompt =
                  randomPrompts[math.Random().nextInt(randomPrompts.length)];
              setState(() {
                _questionController.value = TextEditingValue(
                  text: prompt,
                  selection: TextSelection.collapsed(offset: prompt.length),
                );
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: _isArtGlowing
                    ? [
                        BoxShadow(
                          color: const Color(0xFFC7A867).withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        )
                      ]
                    : null,
              ),
              child: _tarotAltarDeck(),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: _showGuideText ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 800),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              "Tap and hold for a guided question",
              style: GoogleFonts.cormorantGaramond(
                fontSize: 14,
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        FeatureQuotaChip(
          feature: FeatureQuotaKind.tarot,
          refreshKey: _quotaRefreshTick,
          alignment: Alignment.center,
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0812).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3A2D50)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: TextField(
            controller: _questionController,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              color: const Color(0xFFC7A867),
            ),
            maxLines: 3,
            minLines: 1,
            cursorColor: const Color(0xFFB58E34),
            decoration: InputDecoration(
              hintText: tarotHints[_hintIndex],
              hintStyle: GoogleFonts.cormorantGaramond(
                color: Colors.white30,
                fontStyle: FontStyle.italic,
                fontSize: 18,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ),
        const SizedBox(height: 30),
        GestureDetector(
          onTap: canDraw ? _drawCards : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color:
                  canDraw ? const Color(0xFF1E1430) : const Color(0xFF0F0A18),
              border: Border.all(
                color: canDraw
                    ? const Color(0xFF8A6B22).withValues(alpha: 0.5)
                    : const Color(0xFF3A2D50),
              ),
            ),
            child: Center(
              child: Text(
                'DRAW CARDS',
                style: GoogleFonts.cinzel(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: canDraw
                      ? const Color(0xFFB58E34)
                      : const Color(0xFF6B6080),
                  letterSpacing: 3.0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _tarotAltarDeck() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _breathController,
        _plasmaController,
      ]),
      builder: (context, _) {
        return SizedBox(
          width: double.infinity,
          height: 344,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final altarSize = math.min(constraints.maxWidth, 348.0);

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: -2,
                    child: CustomPaint(
                      size: Size(altarSize, altarSize),
                      painter: _PentacleAltarPainter(
                        progress: _plasmaController.value,
                        glow: _breathAnimation.value,
                        cardImage: _tarotBackImage,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _spreadState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        Text(
          'Turn the cards to reveal the weave',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 18,
            color: Colors.white54,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(3, (i) => _buildCard(i)),
        ),
        const SizedBox(height: 40),
        FeatureQuotaChip(
          feature: FeatureQuotaKind.tarot,
          refreshKey: _quotaRefreshTick,
          alignment: Alignment.center,
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF050408),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2E1A4A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'YOUR INQUIRY',
                style: GoogleFonts.cinzel(
                  fontSize: 11,
                  color: const Color(0xFF6B6080),
                  letterSpacing: 3.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _questionController.text,
                textAlign: TextAlign.center,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 18,
                  color: const Color(0xFFC7A867),
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_allRevealed) _readingCard(),
        if (_flow.canShare) ...[
          const SizedBox(height: 16),
          TarotShareButton(
            question: _questionController.text.trim(),
            past: _cards![0],
            present: _cards![1],
            future: _cards![2],
            reading: _reading.trim(),
          ),
        ],
        if (_flow.canFollowUp) ...[
          const SizedBox(height: 16),
          _followUpCard(),
        ],
        const SizedBox(height: 24),
        if (_flow.canReset)
          TextButton(
            onPressed: () => setState(() {
              _readingRequestId++;
              _flow = TarotReadingFlow.initial();
              _questionController.clear();
            }),
            child: Text(
              'Ask another question',
              style: GoogleFonts.cormorantGaramond(
                color: const Color(0xFF6B6080),
                fontSize: 16,
              ),
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildCard(int index) {
    final labels = ['PAST', 'PRESENT', 'FUTURE'];

    return GestureDetector(
      onTap: () => _revealCard(index),
      child: Column(
        children: [
          Text(
            labels[index],
            style: GoogleFonts.cinzel(
              fontSize: 11,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B6080),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _flipAnimations[index],
            builder: (_, __) {
              final angle = _flipAnimations[index].value * math.pi;
              final isFront = angle > (math.pi / 2);
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: isFront
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _cardFront(index),
                      )
                    : _cardBack(width: 104, height: 170),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_revealed[index] && _cards != null)
            SizedBox(
              width: 104,
              child: Text(
                _cards![index].name.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFB58E34).withValues(alpha: 0.8),
                  height: 1.3,
                ),
              ),
            )
          else
            Text(
              'Tap',
              style: GoogleFonts.cinzel(
                fontSize: 11,
                color: const Color(0xFF6B6080),
                letterSpacing: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardBack({
    double width = 104,
    double height = 170,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF0F0A18),
        border: Border.all(
          color: const Color(0xFF3A2D50),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 15,
            offset: const Offset(4, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(
          'assets/tarot/Tarotback.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(width, height),
                painter: _CardBackPainter(),
              ),
              Icon(
                Icons.nights_stay_rounded,
                color: const Color(0xFFB58E34).withValues(alpha: 0.15),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardFront(int index) {
    if (_cards == null) return const SizedBox();
    return Container(
      width: 100,
      height: 165,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF1E1430),
        border: Border.all(
          color: const Color(0xFF8A6B22).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB58E34).withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          _cards![index].asset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _cards![index].name,
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFC7A867),
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _readingCard() {
    return AnimatedOpacity(
      opacity: _reading.isEmpty && !_readingLoading ? 0 : 1,
      duration: const Duration(milliseconds: 1000),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0A18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2E1A4A), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: _readingLoading
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _plasmaController,
                      builder: (context, child) => SizedBox(
                        width: 48,
                        height: 48,
                        child: CustomPaint(
                          painter: _TeslaGlobePainter(_plasmaController.value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Bhrigu is reading the cards...',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
                        color: const Color(0xFF6B6080),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      'BHRIGU SPEAKS',
                      style: GoogleFonts.cinzel(
                        fontSize: 14,
                        color: const Color(0xFFC7A867),
                        letterSpacing: 4.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ..._buildReadingParagraphs(_reading),
                  if (isPlansRecoveryMessage(_reading)) ...[
                    const SizedBox(height: 12),
                    PlansCtaButton(message: _reading),
                    const SizedBox(height: 4),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: AiReportButton(
                      feature: 'tarot',
                      contentId: '',
                      contentText: _reading,
                      label: 'Report',
                    ),
                  ),
                  const AiDisclaimer(),
                ],
              ),
      ),
    );
  }

  Widget _followUpCard() {
    final questions = [
      'What should I do next?',
      'What pattern am I repeating?',
      'What is the hidden warning?',
      'How does this connect to my birth chart?',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0812).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF8A6B22).withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              'ASK BHRIGU DEEPER',
              style: GoogleFonts.cinzel(
                fontSize: 12,
                color: const Color(0xFFC7A867),
                letterSpacing: 3.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Follow up using this exact reading and your cosmic blueprint.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              color: Colors.white54,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          if (_followUpLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _plasmaController,
                    builder: (context, child) => SizedBox(
                      width: 42,
                      height: 42,
                      child: CustomPaint(
                        painter: _TeslaGlobePainter(_plasmaController.value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Preparing context for Bhrigu...',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 16,
                      color: const Color(0xFF6B6080),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              'You can change the selected prompt on the chat screen before sending.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: Colors.white38,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            ...questions.map(_followUpButton),
          ],
        ],
      ),
    );
  }

  Widget _followUpButton(String question) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _openTarotFollowUp(question),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1430),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF3A2D50),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFB58E34),
                size: 17,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 17,
                    color: const Color(0xFFC7A867),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF6B6080),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildReadingParagraphs(String reading) {
    final sections = reading.split('\n\n');
    final widgets = <Widget>[];

    for (final section in sections) {
      if (section.trim().isEmpty) continue;

      final isPast = section.toUpperCase().startsWith('PAST');
      final isPresent = section.toUpperCase().startsWith('PRESENT');
      final isFuture = section.toUpperCase().startsWith('FUTURE');

      if (isPast || isPresent || isFuture) {
        final lines = section.split('\n');
        final label = lines.first.trim();
        final body = lines.skip(1).join('\n').trim();

        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF130D1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2E1A4A)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 2,
                  height: 40,
                  margin: const EdgeInsets.only(top: 4, right: 16),
                  color: const Color(0xFF8A6B22).withValues(alpha: 0.6),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.cinzel(
                          fontSize: 13,
                          color: const Color(0xFFB58E34),
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        body,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 18,
                          height: 1.6,
                          color: const Color(0xFFD4D4CE),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: const Color(0xFFB58E34).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
            child: Text(
              section.trim(),
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                height: 1.6,
                color: const Color(0xFFC7A867).withValues(alpha: 0.9),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }
}

class _TarotHistorySheet extends StatefulWidget {
  final TarotService service;
  final ValueChanged<TarotSavedReading> onSelect;
  final VoidCallback onCleared;

  const _TarotHistorySheet({
    required this.service,
    required this.onSelect,
    required this.onCleared,
  });

  @override
  State<_TarotHistorySheet> createState() => _TarotHistorySheetState();
}

class _TarotHistorySheetState extends State<_TarotHistorySheet> {
  late Future<List<TarotSavedReading>> _future;
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
          title: Text(
            'Clear tarot history?',
            style: GoogleFonts.cinzel(
              color: const Color(0xFFFFD88A),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'This will permanently delete all saved Tarot readings from your history.',
            style: GoogleFonts.cormorantGaramond(
              color: const Color(0xFFB8AEE0),
              fontSize: 17,
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
      await widget.service.clearSavedReadings();
      widget.onCleared();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarot history cleared.'),
          backgroundColor: Color(0xFF1A1630),
        ),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not clear tarot history: $e'),
          backgroundColor: const Color(0xFF1A1630),
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
                    Expanded(
                      child: Text(
                        'Tarot History',
                        style: GoogleFonts.cinzel(
                          color: const Color(0xFFFFD88A),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Open a previous Tarot reading. Follow-ups stay available only for fresh readings.',
                    style: GoogleFonts.cormorantGaramond(
                      color: const Color(0xFF8E83B5),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: FutureBuilder<List<TarotSavedReading>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: _TeslaGlobeLoader(size: 54),
                      );
                    }

                    final readings = snapshot.data ?? [];

                    if (readings.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(26),
                          child: Text(
                            'No saved Tarot readings yet. Draw cards and the reading will appear here.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cormorantGaramond(
                              color: const Color(0xFF8E83B5),
                              fontSize: 17,
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

  Widget _historyTile(TarotSavedReading reading) {
    final date = reading.createdAt;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    final question = reading.question.trim().isEmpty
        ? 'General Tarot reading'
        : reading.question.trim();

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
              color: Colors.black.withValues(alpha: 0.35),
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
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFFD88A),
                  size: 23,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cormorantGaramond(
                      color: const Color(0xFFF0ECF8),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${reading.past.name} • ${reading.present.name} • ${reading.future.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cormorantGaramond(
                      color: const Color(0xFFB8AEE0),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
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

class _PentacleAltarPainter extends CustomPainter {
  final double progress;
  final double glow;
  final ui.Image? cardImage;

  _PentacleAltarPainter({
    required this.progress,
    required this.glow,
    this.cardImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);

    final linePaint = Paint()
      ..color = const Color(0xFFC7A867).withValues(alpha: 0.5 + 0.3 * glow)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + (0.5 * glow);

    final highlightPaint = Paint()
      ..color = const Color(0xFFE5D5F5).withValues(alpha: 0.5 + 0.3 * glow)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // -------------------------------------------------------------
    // Shuffling Animated Geometric Cards (Looping Fan Out / Fan In)
    // -------------------------------------------------------------

    // We want a precise timing: Fan out (1.5s), Wait (4s), Fan in (1.5s), Wait (4s)
    final timeMs = DateTime.now().millisecondsSinceEpoch;
    final cycleMs = timeMs % 11000;

    double fanProgress = 0.0;
    if (cycleMs < 1500) {
      // Fan out smooth ease
      final t = cycleMs / 1500;
      fanProgress = (1 - math.cos(t * math.pi)) / 2;
    } else if (cycleMs < 5500) {
      // Wait 4 sec fanned out
      fanProgress = 1.0;
    } else if (cycleMs < 7000) {
      // Fan in smooth ease
      final t = (cycleMs - 5500) / 1500;
      fanProgress = (1 + math.cos(t * math.pi)) / 2;
    } else {
      // Wait 4 sec fanned in
      fanProgress = 0.0;
    }

    // Bigger cards
    final cardWidth = size.width * 0.40;
    final cardHeight = cardWidth * 1.6;
    final cardRect = Rect.fromCenter(
        center: Offset.zero, width: cardWidth, height: cardHeight);
    final cardRRect =
        RRect.fromRectAndRadius(cardRect, const Radius.circular(8));

    // The pivot point for fanning is near the bottom of the card
    final pivot = Offset(0, cardHeight * 0.35);

    // We draw 7 cards
    for (int i = 0; i < 7; i++) {
      canvas.save();

      // Calculate rotation for this specific card
      // Card indices: 0, 1, 2, 3 (center), 4, 5, 6
      final offsetFromCenter = i - 3;

      // Max rotation for the outermost cards (0 and 6)
      // A slightly tighter spread since there are more cards
      final maxAngle = offsetFromCenter * (math.pi / 9);
      final currentAngle = maxAngle * fanProgress;

      // Translate to pivot, rotate, translate back
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(currentAngle);
      canvas.translate(-pivot.dx, -pivot.dy);

      if (cardImage != null) {
        // Draw Tarotback.png as the card face
        final imgPaint = Paint();
        final srcRect = Rect.fromLTWH(
          0,
          0,
          cardImage!.width.toDouble(),
          cardImage!.height.toDouble(),
        );
        final clipPath = Path()..addRRect(cardRRect);
        canvas.clipPath(clipPath);
        canvas.drawImageRect(cardImage!, srcRect, cardRect, imgPaint);
        // Restore clip then re-apply transform to draw border on top
        canvas.restore();
        canvas.save();
        canvas.translate(pivot.dx, pivot.dy);
        canvas.rotate(currentAngle);
        canvas.translate(-pivot.dx, -pivot.dy);
        canvas.drawRRect(cardRRect, linePaint);
      } else {
        // Fallback: original canvas design
        final cardBgPaint = Paint()
          ..color = const Color(0xFF0F0A18).withValues(alpha: 0.95)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(cardRRect, cardBgPaint);
        canvas.drawRRect(cardRRect, linePaint);
        canvas.drawRRect(cardRRect, highlightPaint);
      }

      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PentacleAltarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glow != glow ||
        oldDelegate.cardImage != cardImage;
  }
}

// ignore: unused_element
class _TarotCandlePainter extends CustomPainter {
  final double progress;
  final double glow;
  final bool mirrored;

  _TarotCandlePainter({
    required this.progress,
    required this.glow,
    required this.mirrored,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final candleTop = size.height * 0.36;
    final candleBottom = size.height * 0.93;
    final candleWidth = size.width * 0.38;
    final flameShift =
        math.sin(progress * 2 * math.pi + (mirrored ? 1.3 : 0.0)) * 2.8;
    final flameSquash =
        0.92 + 0.08 * math.sin(progress * 6 * math.pi + (mirrored ? 0.8 : 0.0));
    final flameHeight = size.height * 0.255 * flameSquash;
    final flameCenter = Offset(centerX + flameShift, candleTop - 18);

    final flameGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF2C2).withValues(alpha: 0.48 * glow),
          const Color(0xFFFFD88A).withValues(alpha: 0.28 * glow),
          const Color(0xFFF59E0B).withValues(alpha: 0.12 * glow),
          Colors.transparent,
        ],
        stops: const [0.0, 0.30, 0.58, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: flameCenter,
          radius: size.width * 0.72,
        ),
      );

    canvas.drawCircle(flameCenter, size.width * 0.72, flameGlowPaint);

    final outerFlame = Path()
      ..moveTo(flameCenter.dx, flameCenter.dy - flameHeight * 0.62)
      ..cubicTo(
        flameCenter.dx + size.width * 0.19,
        flameCenter.dy - flameHeight * 0.20,
        flameCenter.dx + size.width * 0.15,
        flameCenter.dy + flameHeight * 0.28,
        flameCenter.dx,
        flameCenter.dy + flameHeight * 0.44,
      )
      ..cubicTo(
        flameCenter.dx - size.width * 0.17,
        flameCenter.dy + flameHeight * 0.20,
        flameCenter.dx - size.width * 0.15,
        flameCenter.dy - flameHeight * 0.20,
        flameCenter.dx,
        flameCenter.dy - flameHeight * 0.62,
      );

    canvas.drawPath(
      outerFlame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFF2C2),
            Color(0xFFFFD88A),
            Color(0xFFF59E0B),
          ],
        ).createShader(
          Rect.fromCenter(
            center: flameCenter,
            width: size.width * 0.48,
            height: flameHeight * 1.35,
          ),
        ),
    );

    final innerFlame = Path()
      ..moveTo(flameCenter.dx + flameShift * 0.12,
          flameCenter.dy - flameHeight * 0.27)
      ..cubicTo(
        flameCenter.dx + size.width * 0.08,
        flameCenter.dy + flameHeight * 0.02,
        flameCenter.dx + size.width * 0.06,
        flameCenter.dy + flameHeight * 0.25,
        flameCenter.dx,
        flameCenter.dy + flameHeight * 0.33,
      )
      ..cubicTo(
        flameCenter.dx - size.width * 0.07,
        flameCenter.dy + flameHeight * 0.15,
        flameCenter.dx - size.width * 0.04,
        flameCenter.dy - flameHeight * 0.06,
        flameCenter.dx + flameShift * 0.12,
        flameCenter.dy - flameHeight * 0.27,
      );

    canvas.drawPath(
      innerFlame,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.92),
    );

    final wickPaint = Paint()
      ..color = const Color(0xFF21103D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(centerX, candleTop - 2),
      Offset(centerX + flameShift * 0.2, candleTop + 13),
      wickPaint,
    );

    final candleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, (candleTop + candleBottom) / 2),
        width: candleWidth,
        height: candleBottom - candleTop,
      ),
      const Radius.circular(10),
    );

    final waxPaint = Paint()
      ..shader = LinearGradient(
        begin: mirrored ? Alignment.centerRight : Alignment.centerLeft,
        end: mirrored ? Alignment.centerLeft : Alignment.centerRight,
        colors: const [
          Color(0xFFE8E1D0),
          Color(0xFFFFFBF0),
          Color(0xFFFFFFFF),
          Color(0xFFD6C8AF),
        ],
        stops: const [0.0, 0.30, 0.62, 1.0],
      ).createShader(candleRect.outerRect);

    canvas.drawRRect(candleRect, waxPaint);

    final topOval = Rect.fromCenter(
      center: Offset(centerX, candleTop),
      width: candleWidth,
      height: 13,
    );

    canvas.drawOval(
      topOval,
      Paint()..color = const Color(0xFFFFFBF0),
    );

    canvas.drawOval(
      topOval.deflate(3),
      Paint()..color = const Color(0xFFD8C8A8).withValues(alpha: 0.55),
    );

    canvas.drawRRect(
      candleRect,
      Paint()
        ..color = const Color(0xFFFFD88A).withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    final dripPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFE7D7B9),
        ],
      ).createShader(candleRect.outerRect)
      ..style = PaintingStyle.fill;

    void drip(double xFactor, double yStart, double length, double width) {
      final x = centerX + candleWidth * xFactor;
      final path = Path()
        ..moveTo(x - width / 2, candleTop + yStart)
        ..quadraticBezierTo(x - width * 0.7, candleTop + yStart + length * 0.45,
            x, candleTop + yStart + length)
        ..quadraticBezierTo(x + width * 0.7, candleTop + yStart + length * 0.45,
            x + width / 2, candleTop + yStart)
        ..close();
      canvas.drawPath(path, dripPaint);
    }

    drip(-0.24, 8, 44, 7);
    drip(0.18, 20, 64, 8);
    drip(0.02, 34, 28, 5);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(centerX - candleWidth * 0.20, candleTop + 18),
      Offset(centerX - candleWidth * 0.20, candleBottom - 12),
      highlightPaint,
    );

    final baseRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, candleBottom + 10),
        width: candleWidth * 1.72,
        height: 14,
      ),
      const Radius.circular(12),
    );

    canvas.drawRRect(
      baseRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF0F0A18),
            Color(0xFF2E2650),
            Color(0xFF0F0A18),
          ],
        ).createShader(baseRect.outerRect),
    );

    canvas.drawRRect(
      baseRect,
      Paint()
        ..color = const Color(0xFFB58E34).withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _TarotCandlePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glow != glow ||
        oldDelegate.mirrored != mirrored;
  }
}

class _MysticVinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3A2D50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final leafPaint = Paint()
      ..color = const Color(0xFF3A2D50)
      ..style = PaintingStyle.fill;

    void drawVine(Offset start, Offset control, Offset end) {
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      canvas.drawPath(path, paint);

      canvas.drawCircle(end, 2.5, leafPaint);

      final midX = (start.dx + 2 * control.dx + end.dx) / 4;
      final midY = (start.dy + 2 * control.dy + end.dy) / 4;
      canvas.drawCircle(Offset(midX, midY), 1.5, leafPaint);
    }

    drawVine(const Offset(0, 50), const Offset(50, 60), const Offset(80, 20));
    drawVine(
        const Offset(0, 100), const Offset(80, 100), const Offset(120, 50));

    drawVine(
      Offset(size.width, 50),
      Offset(size.width - 50, 60),
      Offset(size.width - 80, 20),
    );
    drawVine(
      Offset(size.width, 100),
      Offset(size.width - 80, 100),
      Offset(size.width - 120, 50),
    );

    drawVine(
      Offset(0, size.height - 50),
      Offset(50, size.height - 60),
      Offset(80, size.height - 20),
    );
    drawVine(
      Offset(0, size.height - 150),
      Offset(80, size.height - 100),
      Offset(120, size.height - 50),
    );

    drawVine(
      Offset(size.width, size.height - 50),
      Offset(size.width - 50, size.height - 60),
      Offset(size.width - 80, size.height - 20),
    );
    drawVine(
      Offset(size.width, size.height - 150),
      Offset(size.width - 80, size.height - 100),
      Offset(size.width - 120, size.height - 50),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..color = const Color(0xFF2E1A4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(
      Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
      paint,
    );

    final path = Path()
      ..moveTo(center.dx, 16)
      ..lineTo(size.width - 16, center.dy)
      ..lineTo(center.dx, size.height - 16)
      ..lineTo(16, center.dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          const Color(0xFF9D6FE8).withValues(alpha: 0.15)
        ],
        stops: const [0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, glassPaint);

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFFB58E34).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    canvas.drawCircle(
        center,
        radius * 0.25,
        Paint()
          ..color = const Color(0xFFB58E34).withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    canvas.drawCircle(
        center, radius * 0.12, Paint()..color = const Color(0xFFC7A867));
    canvas.drawCircle(center, radius * 0.06, Paint()..color = Colors.white);

    final math.Random fixedRandom = math.Random(42);
    const int numTendrils = 7;

    for (int i = 0; i < numTendrils; i++) {
      final double baseAngle = (i * 2 * math.pi / numTendrils);

      final double dynamicAngle =
          baseAngle + math.sin(progress * 2 * math.pi + i) * 0.5;

      final Offset endPoint = Offset(
        center.dx + math.cos(dynamicAngle) * radius * 0.95,
        center.dy + math.sin(dynamicAngle) * radius * 0.95,
      );

      final double wave1 = math.cos(progress * 4 * math.pi + (i * 2));
      final double wave2 = math.sin(progress * 6 * math.pi + (i * 3));

      final Offset cp1 = Offset(
        center.dx + math.cos(dynamicAngle + wave1 * 0.8) * radius * 0.4,
        center.dy + math.sin(dynamicAngle + wave1 * 0.8) * radius * 0.4,
      );

      final Offset cp2 = Offset(
        center.dx + math.cos(dynamicAngle - wave2 * 0.6) * radius * 0.7,
        center.dy + math.sin(dynamicAngle - wave2 * 0.6) * radius * 0.7,
      );

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, endPoint.dx, endPoint.dy);

      final double flicker = 0.5 +
          fixedRandom.nextDouble() * 0.5 +
          (math.sin(progress * 20 * math.pi + i) * 0.2);
      final double safeFlicker = flicker.clamp(0.2, 1.0);

      canvas.drawPath(
          path,
          Paint()
            ..color =
                const Color(0xFF9D6FE8).withValues(alpha: 0.6 * safeFlicker)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

      canvas.drawPath(
          path,
          Paint()
            ..color =
                const Color(0xFFE5D5F5).withValues(alpha: 0.9 * safeFlicker)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);

      canvas.drawCircle(
          endPoint,
          3.0 * safeFlicker,
          Paint()
            ..color = const Color(0xFFE5D5F5).withValues(alpha: safeFlicker)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }

  @override
  bool shouldRepaint(covariant _TeslaGlobePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
