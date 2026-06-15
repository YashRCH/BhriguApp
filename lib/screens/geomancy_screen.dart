import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../models/geomancy_figure_model.dart';
import '../models/geomancy_reading_flow.dart';
import '../services/geomancy_service.dart';
import '../services/follow_up_context_service.dart';
import '../widgets/ai_report_button.dart';
import '../widgets/ai_disclaimer.dart';
import '../widgets/geomancy_line_cast_widget.dart';
import '../widgets/geomancy_shield_chart.dart';
import '../widgets/geomancy_share_card.dart';
import '../constants/random_prompts.dart';

class GeomancyScreen extends StatefulWidget {
  const GeomancyScreen({super.key});

  @override
  State<GeomancyScreen> createState() => _GeomancyScreenState();
}

class _GeomancyScreenState extends State<GeomancyScreen>
    with TickerProviderStateMixin {
  final TextEditingController _questionController = TextEditingController();
  final GeomancyService _service = GeomancyService();
  final FollowUpContextService _followUpService = FollowUpContextService();
  final math.Random _random = math.Random();

  Timer? _questionHintTimer;
  int _questionHintIndex = 0;

  static const List<String> _questionHints = [
    'Will this path bring peace or confusion?',
    'What should I understand about this relationship?',
    'Is this the right time to move forward?',
    'What is hidden beneath this situation?',
    'What does my heart need to know?',
    'Is this connection meant to grow?',
    'What energy surrounds this decision?',
    'Where should I place my trust now?',
  ];

  late final AnimationController _breathController;
  late final Animation<double> _breathAnimation;
  late final AnimationController _holdController;
  late final AnimationController _plasmaController;
  late final AnimationController _emblemController;

  final List<GeomancyCastLine> _lines = [];

  GeomancyReadingFlow _flow = GeomancyReadingFlow.initial();
  int _readingRequestId = 0;

  Size _canvasSize = const Size(320, 300);
  Offset? _currentStart;
  Offset? _currentControl;
  double _currentAngle = 0;
  double _currentMaxLength = 120;

  bool _isHolding = false;
  bool _isQuestionSubmitted = false;
  bool _isArtGlowing = false;
  static const double _minLineLength = 40;
  static const double _absoluteMaxLength = 160;

  static const List<String> _geomancyFollowUpQuestions = [
    'What should I do next based on this shield?',
    'What is the hidden lesson in this pattern?',
    'Is this situation moving toward peace or delay?',
    'What should I avoid after this reading?',
    'What does the Judge reveal about my question?',
  ];
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

    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _plasmaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _emblemController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isHolding) {
        _sealCurrentLine(forceMax: true);
      }
    });

    _questionHintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      if (_questionController.text.trim().isNotEmpty) return;
      if (_isReadingLoading || _isRevealed) return;

      setState(() {
        _questionHintIndex = (_questionHintIndex + 1) % _questionHints.length;
      });
    });
  }

  @override
  void dispose() {
    _questionHintTimer?.cancel();
    _breathController.dispose();
    _holdController.dispose();
    _plasmaController.dispose();
    _emblemController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  int get _lineCount => _lines.length;

  List<int> get _lineValues => _lines.map((line) => line.value).toList();

  GeomancyReadingModel? get _reading => _flow.reading;
  bool get _isRevealed => _flow.isRevealed;
  bool get _isReadingLoading => _flow.isReadingLoading;
  bool get _creatingFollowUp => _flow.creatingFollowUp;

  String get _stage {
    if (_lineCount < 4) return 'The Mothers forming';
    if (_lineCount < 8) return 'The Daughters awakening';
    if (_lineCount < 12) return 'The Nieces aligning';
    if (_lineCount < 16) return 'The Witnesses preparing';
    return 'The Shield is sealed';
  }

  String get _instruction {
    if (_isReadingLoading) return 'Bhrigu is reading your geomantic shield...';
    if (_lineCount == 16) return 'All sixteen marks are drawn.';
    if (_isHolding) return 'Release when the thread feels complete.';
    return 'Hold the seal to draw mark ${_lineCount + 1}.';
  }

  void _startLine() {
    if (_lineCount >= 16 || _isHolding || _isRevealed || _isReadingLoading) {
      return;
    }

    FocusScope.of(context).unfocus();
    unawaited(HapticFeedback.lightImpact());

    final center = Offset(_canvasSize.width / 2, _canvasSize.height / 2);
    final start = _lines.isEmpty ? center : _lines.last.end;

    final angle = _nextAngle(start, center);
    final maxLength = _safeMaxLength(start, angle);
    final end = start + Offset(math.cos(angle), math.sin(angle)) * maxLength;
    final control = _makeControlPoint(start, end, angle);

    setState(() {
      _currentStart = start;
      _currentAngle = angle;
      _currentMaxLength = maxLength;
      _currentControl = control;
      _isHolding = true;
    });

    _holdController.forward(from: 0);
  }

  void _cancelLine() {
    if (!_isHolding) return;
    _sealCurrentLine();
  }

  Future<void> _sealCurrentLine({bool forceMax = false}) async {
    if (!_isHolding || _currentStart == null || _currentControl == null) {
      return;
    }

    if (_lineCount >= 16) return;

    final rawProgress = forceMax ? 1.0 : _holdController.value.clamp(0.08, 1.0);
    final curved = Curves.easeOutQuart.transform(rawProgress);
    final length =
        _minLineLength + ((_currentMaxLength - _minLineLength) * curved);
    final safeLength =
        math.min(length, _safeMaxLength(_currentStart!, _currentAngle));

    final end = _currentStart! +
        Offset(math.cos(_currentAngle), math.sin(_currentAngle)) * safeLength;

    final control = _makeControlPoint(_currentStart!, end, _currentAngle);

    final segmentCount = math.max(1, (safeLength / 12).round());
    final value = segmentCount.isOdd ? 1 : 2;

    final line = GeomancyCastLine(
      start: _currentStart!,
      control: control,
      end: end,
      value: value,
      length: safeLength,
      index: _lineCount + 1,
      angle: _currentAngle,
      intensity: rawProgress.toDouble(),
    );

    _holdController.stop();
    unawaited(
      line.index == 16
          ? HapticFeedback.heavyImpact()
          : HapticFeedback.mediumImpact(),
    );

    setState(() {
      _lines.add(line);
      _isHolding = false;
      _currentStart = null;
      _currentControl = null;
    });

    if (_lines.length == 16) {
      await _buildReading();
    }
  }

  Future<void> _buildReading() async {
    final requestId = ++_readingRequestId;
    final lineValues = List<int>.from(_lineValues);

    setState(() {
      _flow = _flow.beginReading();
    });

    try {
      final reading = await _service.buildReading(
        question: _questionController.text.trim(),
        lineValues: lineValues,
      );

      if (!mounted || requestId != _readingRequestId) return;

      setState(() {
        _flow = _flow.completeReading(
          reading: reading,
          lineValues: lineValues,
        );
      });
    } catch (e) {
      if (!mounted || requestId != _readingRequestId) return;

      setState(() {
        _lines.clear();
        _flow = GeomancyReadingFlow.initial();
        _currentStart = null;
        _currentControl = null;
        _isHolding = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not complete this geomancy reading. Try again.'),
          backgroundColor: Color(0xFF1A1630),
        ),
      );
    }
  }

  void _revealShield() {
    if (_reading == null || _isReadingLoading) return;

    setState(() {
      _flow = _flow.reveal();
    });
  }

  void _resetCast() {
    _readingRequestId++;
    _holdController.stop();

    setState(() {
      _lines.clear();
      _flow = GeomancyReadingFlow.initial();
      _currentStart = null;
      _currentControl = null;
      _isHolding = false;
      _isQuestionSubmitted = false;
    });
  }

  Future<void> _openGeomancyFollowUp(String selectedQuestion) async {
    final reading = _reading;

    if (reading == null || !_flow.canFollowUp) {
      return;
    }

    setState(() {
      _flow = _flow.withFollowUpLoading(true);
    });

    try {
      final contextId = await _followUpService.createGeomancyFollowUpContext(
        originalQuestion: _questionController.text.trim().isEmpty
            ? 'The user asked for a general geomancy reading.'
            : _questionController.text.trim(),
        selectedFollowUpQuestion: selectedQuestion,
        readingSummary: reading.interpretation,
        sourceData: _flow.followUpSourceData(_lineValues),
        aiResponseLanguage: reading.aiResponseLanguage,
      );

      if (!mounted) return;

      context.push('/chat', extra: contextId);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open follow-up: $e'),
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

  Future<void> _openHistory() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _GeomancyHistorySheet(
          service: _service,
          onSelect: (savedReading) {
            Navigator.pop(context);
            _readingRequestId++;
            _holdController.stop();

            setState(() {
              _lines.clear();
              _flow = GeomancyReadingFlow.saved(
                reading: savedReading.reading,
                lineValues: savedReading.lineValues,
              );
              _currentStart = null;
              _currentControl = null;
              _isHolding = false;
              _isQuestionSubmitted = true;
              _questionController.text = savedReading.reading.question;
            });
          },
          onCleared: () {
            setState(() {
              _lines.clear();
              _flow = GeomancyReadingFlow.initial();
              _currentStart = null;
              _currentControl = null;
              _isHolding = false;
              _isQuestionSubmitted = false;
            });
          },
        );
      },
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF151126),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF2E2650)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What is Geomancy?',
                  style: TextStyle(
                    color: Color(0xFFFFD88A),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Geomancy is an old divination method where random marks are turned into symbolic figures. Traditionally, people made dots in sand or soil, then counted them as odd or even.',
                  style: TextStyle(
                    color: Color(0xFFB8AEE0),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'In BHR1GU, you hold the seal sixteen times. Each curved line becomes either one point or two points. These marks form Mothers, Daughters, Witnesses, a Judge, and then Bhrigu reads the pattern.',
                  style: TextStyle(
                    color: Color(0xFFB8AEE0),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'It is not mind reading. Your timing creates the marks, the marks create the shield, and the shield gives a symbolic answer.',
                  style: TextStyle(
                    color: Color(0xFFF0ECF8),
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text(
                        'UNDERSTOOD',
                        style: TextStyle(
                          color: Color(0xFF160C24),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _nextAngle(Offset start, Offset center) {
    final baseAngles = [
      0.0,
      math.pi / 3,
      2 * math.pi / 3,
      math.pi,
      4 * math.pi / 3,
      5 * math.pi / 3,
    ];

    final base = baseAngles[_lineCount % baseAngles.length];

    final distanceToCenter = (start - center).distance;
    final maxAllowedDistance = _canvasSize.width * 0.35;

    if (distanceToCenter > maxAllowedDistance && _lineCount > 0) {
      final inwardAngle =
          math.atan2(center.dy - start.dy, center.dx - start.dx);
      return inwardAngle + (_random.nextDouble() - 0.5) * 0.8;
    }

    final randomOffset = (_random.nextDouble() - 0.5) * 0.6;
    return base + randomOffset;
  }

  Offset _makeControlPoint(Offset start, Offset end, double angle) {
    final mid = Offset.lerp(start, end, 0.5)!;
    final normal = Offset(-math.sin(angle), math.cos(angle));

    final curvePower = 15 + _random.nextDouble() * 20;
    final direction = _lineCount.isEven ? 1.0 : -1.0;
    final control = mid + normal * curvePower * direction;

    return Offset(
      control.dx.clamp(30.0, _canvasSize.width - 30.0),
      control.dy.clamp(30.0, _canvasSize.height - 30.0),
    );
  }

  double _safeMaxLength(Offset start, double angle) {
    const margin = 36.0;

    final dx = math.cos(angle);
    final dy = math.sin(angle);

    double maxX = _absoluteMaxLength;
    double maxY = _absoluteMaxLength;

    if (dx > 0) {
      maxX = (_canvasSize.width - margin - start.dx) / dx;
    } else if (dx < 0) {
      maxX = (margin - start.dx) / dx;
    }

    if (dy > 0) {
      maxY = (_canvasSize.height - margin - start.dy) / dy;
    } else if (dy < 0) {
      maxY = (margin - start.dy) / dy;
    }

    final safe = math.min(_absoluteMaxLength, math.min(maxX.abs(), maxY.abs()));
    return safe.clamp(60.0, _absoluteMaxLength);
  }

  void _onCanvasSizeChanged(Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    if ((_canvasSize.width - size.width).abs() < 1 &&
        (_canvasSize.height - size.height).abs() < 1) {
      return;
    }

    _canvasSize = size;
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
          tooltip: 'Geomancy history',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'GEOMANCY',
            style: GoogleFonts.cinzel(
              color: const Color(0xFFB58E34).withValues(alpha: 0.9),
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 4.0,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFB58E34)),
        actions: [
          IconButton(
            onPressed: _showInfo,
            icon: const Icon(Icons.info_outline, color: Color(0xFFB58E34)),
            tooltip: 'What is Geomancy?',
          ),
          IconButton(
            onPressed: _resetCast,
            icon: const Icon(Icons.refresh, color: Color(0xFFB58E34)),
            tooltip: 'Reset Ritual',
          ),
        ],
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
                painter: _SacredGeometryPainter(),
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
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(
                  left: 24, right: 24, top: 10, bottom: 120),
              children: [
                if (!_isQuestionSubmitted) ...[
                  if (_lineCount == 0 && _reading == null) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: AnimatedBuilder(
                          animation: Listenable.merge(
                              [_emblemController, _breathAnimation]),
                          builder: (context, _) => Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (_) =>
                                setState(() => _isArtGlowing = true),
                            onPointerUp: (_) =>
                                setState(() => _isArtGlowing = false),
                            onPointerCancel: (_) =>
                                setState(() => _isArtGlowing = false),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: () {
                                final prompt = randomPrompts[math.Random()
                                    .nextInt(randomPrompts.length)];
                                setState(() {
                                  _questionController.value = TextEditingValue(
                                    text: prompt,
                                    selection: TextSelection.collapsed(
                                        offset: prompt.length),
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
                                            color: const Color(0xFFC7A867)
                                                .withValues(alpha: 0.6),
                                            blurRadius: 40,
                                            spreadRadius: 20,
                                          )
                                        ]
                                      : null,
                                ),
                                child: CustomPaint(
                                  painter: _ShieldEmblemPainter(
                                    rotationProgress: _emblemController.value,
                                    pulse: _breathAnimation.value,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: _showGuideText ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 800),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Center(
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
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Ask the Earth',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC7A867),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Quiet your mind. Hold your question.\nThe marks await your hand.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
                        color: Colors.white60,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                  _questionCard(),
                ] else ...[
                  _ritualCard(),
                  const SizedBox(height: 18),
                  if (_isReadingLoading) _loadingCard(),
                  if (_flow.readyToReveal) _readyCard(),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutQuart,
                    alignment: Alignment.topCenter,
                    child: _flow.canShowResult
                        ? Column(
                            children: [
                              _resultCard(_reading!),
                              const SizedBox(height: 18),
                              GeomancyShareButton(
                                reading: _reading!,
                                lineValues:
                                    _flow.lineValuesForShare(_lineValues),
                                drawnLines: List<GeomancyCastLine>.unmodifiable(
                                  _lines,
                                ),
                              ),
                              if (_flow.canFollowUp) ...[
                                const SizedBox(height: 18),
                                _geomancyFollowUpCard(),
                              ],
                              const SizedBox(height: 18),
                              _shieldCard(_reading!.chart),
                              const SizedBox(height: 40),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionCard() {
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ASK THE EARTH',
            style: GoogleFonts.cinzel(
              color: const Color(0xFFC7A867),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0812),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3A2D50)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _questionController,
              enabled: !_isReadingLoading && !_isRevealed,
              style: GoogleFonts.cormorantGaramond(
                color: const Color(0xFFE5D5F5),
                fontSize: 20,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: _questionHints[_questionHintIndex],
                hintStyle: GoogleFonts.cormorantGaramond(
                  color: const Color(0xFFE5D5F5).withValues(alpha: 0.4),
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _questionController,
            builder: (context, value, child) {
              final hasText = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText
                    ? () {
                        setState(() {
                          _isQuestionSubmitted = true;
                        });
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: hasText
                        ? const Color(0xFF1E1430)
                        : const Color(0xFF151126),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasText
                          ? const Color(0xFF8A6B22)
                          : const Color(0xFF3A2D50),
                    ),
                    boxShadow: hasText
                        ? [
                            BoxShadow(
                              color: const Color(0xFF8A6B22)
                                  .withValues(alpha: 0.2),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      'BEGIN RITUAL',
                      style: GoogleFonts.cinzel(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                        color: hasText
                            ? const Color(0xFFC7A867)
                            : const Color(0xFFE5D5F5).withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _ritualCard() {
    return _glassCard(
      padding: const EdgeInsets.all(18),
      glowColor: const Color(0xFF8B5CF6).withAlpha(28),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _stage,
                  style: GoogleFonts.cinzel(
                    color: const Color(0xFFD8B4E2),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0A18).withAlpha(130),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFC7A867).withAlpha(70),
                  ),
                ),
                child: Text(
                  '$_lineCount / 16',
                  style: GoogleFonts.cinzel(
                    color: const Color(0xFFC7A867),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SizedBox(
              height: 350,
              child: AnimatedBuilder(
                animation: _holdController,
                builder: (context, _) {
                  return GeomancyLineCastWidget(
                    lines: _lines,
                    currentStart: _currentStart,
                    currentControl: _currentControl,
                    currentAngle: _currentAngle,
                    currentLength: _currentMaxLength,
                    currentProgress: _holdController.value,
                    isHolding: _isHolding,
                    lineCount: _lineCount,
                    onCanvasSizeChanged: _onCanvasSizeChanged,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _instruction,
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              color: const Color(0xFFE5D5F5),
              fontSize: 18,
              height: 1.5,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _holdButton(),
        ],
      ),
    );
  }

  Widget _holdButton() {
    final disabled = _lineCount >= 16 || _isRevealed || _isReadingLoading;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => _startLine(),
      onTapUp: disabled ? null : (_) => _cancelLine(),
      onTapCancel: disabled ? null : _cancelLine,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: disabled
              ? const Color(0xFF151126)
              : _isHolding
                  ? const Color(0xFF2E1A4A)
                  : const Color(0xFF1E1430),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: disabled ? const Color(0xFF3A2D50) : const Color(0xFF8A6B22),
          ),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF8A6B22).withValues(
                      alpha: _isHolding ? 0.5 : 0.2,
                    ),
                    blurRadius: _isHolding ? 24 : 12,
                    spreadRadius: _isHolding ? 2 : 1,
                  ),
                ],
        ),
        child: Center(
          child: Text(
            disabled
                ? 'SEAL COMPLETE'
                : _isHolding
                    ? 'RELEASE TO LOCK'
                    : 'HOLD TO FORM SEAL',
            style: GoogleFonts.cinzel(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: disabled
                  ? const Color(0xFFE5D5F5).withValues(alpha: 0.4)
                  : const Color(0xFFC7A867),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingCard() {
    return _glassCard(
      padding: const EdgeInsets.all(24),
      borderColor: const Color(0xFFC7A867).withAlpha(95),
      glowColor: const Color(0xFFC7A867).withAlpha(34),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: AnimatedBuilder(
              animation: _plasmaController,
              builder: (context, child) => CustomPaint(
                painter: _TeslaGlobePainter(_plasmaController.value),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              'Interpreting the Geomantic Shield...',
              style: GoogleFonts.cinzel(
                color: const Color(0xFFD8B4E2),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readyCard() {
    return _glassCard(
      padding: const EdgeInsets.all(24),
      borderColor: const Color(0xFFE8B530).withAlpha(115),
      glowColor: const Color(0xFFE8B530).withAlpha(40),
      child: Column(
        children: [
          Text(
            'The Shield is Ready',
            style: GoogleFonts.cinzel(
              color: const Color(0xFFC7A867),
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "The geometric pattern is sealed. Reveal Bhrigu's reading.",
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              color: const Color(0xFFE5D5F5),
              fontSize: 18,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _revealShield,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFFC7A867), Color(0xFFE8B530)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE8B530).withAlpha(115),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'REVEAL READING',
                  style: GoogleFonts.cinzel(
                    color: const Color(0xFF050408),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(GeomancyReadingModel reading) {
    return _glassCard(
      padding: const EdgeInsets.all(24),
      borderColor: const Color(0xFFE8B530).withAlpha(140),
      glowColor: const Color(0xFFE8B530).withAlpha(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BHRIGU READS THE JUDGE',
            style: GoogleFonts.cinzel(
              color: const Color(0xFFC7A867),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            reading.chart.judge.name.toUpperCase(),
            style: GoogleFonts.cinzel(
              color: const Color(0xFFE8B530),
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.7,
              shadows: [
                Shadow(
                  color: const Color(0xFFE8B530).withAlpha(120),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0A18).withAlpha(120),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFD946EF).withAlpha(85),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE8B530).withAlpha(22),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Text(
              reading.answer.toUpperCase(),
              style: GoogleFonts.inter(
                color: const Color(0xFFE5D5F5),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ..._buildGeomancyReadingSections(reading.interpretation),
          Align(
            alignment: Alignment.centerRight,
            child: AiReportButton(
              feature: 'geomancy',
              contentId: '',
              contentText: reading.interpretation,
              label: 'Report',
            ),
          ),
          const AiDisclaimer(),
        ],
      ),
    );
  }

  List<Widget> _buildGeomancyReadingSections(String interpretation) {
    final sections = interpretation.split(RegExp(r'\n\s*\n'));
    final widgets = <Widget>[];
    const knownHeadings = {
      'THE JUDGEMENT',
      'THE WITNESSES',
      'THE RECONCILER',
      "EARTH'S COUNSEL",
    };

    for (final section in sections) {
      final trimmed = section.trim();
      if (trimmed.isEmpty) continue;

      final lines = trimmed.split('\n');
      final heading = lines.first.trim().toUpperCase();
      final hasHeading = knownHeadings.contains(heading);
      final body = hasHeading ? lines.skip(1).join('\n').trim() : trimmed;

      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: hasHeading ? 22 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 2,
                height: hasHeading ? 72 : 96,
                margin: const EdgeInsets.only(top: 4, right: 16),
                color: const Color(0xFF8A6B22).withAlpha(155),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasHeading) ...[
                      Text(
                        heading,
                        style: GoogleFonts.cinzel(
                          color: const Color(0xFFC7A867),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      body,
                      style: GoogleFonts.cormorantGaramond(
                        color: hasHeading && heading == "EARTH'S COUNSEL"
                            ? const Color(0xFFE5D5F5)
                            : const Color(0xFFD4D4CE),
                        fontSize: 18,
                        height: 1.6,
                        fontStyle: hasHeading && heading == "EARTH'S COUNSEL"
                            ? FontStyle.italic
                            : FontStyle.normal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _geomancyFollowUpCard() {
    return _glassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      borderColor: const Color(0xFFC7A867).withAlpha(85),
      glowColor: const Color(0xFF9D6FE8).withAlpha(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ASK BHRIGU DEEPER',
            style: GoogleFonts.cinzel(
              color: const Color(0xFFC7A867),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Continue this exact shield reading in Bhrigu Chat. The answer will use this Judge, Witnesses, Reconciler, and your sixteen marks as context.',
            style: GoogleFonts.cormorantGaramond(
              color: const Color(0xFFE5D5F5),
              fontSize: 17,
              height: 1.55,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You can change the selected prompt on the chat screen before sending.',
            style: GoogleFonts.inter(
              color: const Color(0xFFE5D5F5).withAlpha(120),
              fontSize: 11.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ..._geomancyFollowUpQuestions.map(
            (question) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: _creatingFollowUp
                    ? null
                    : () => _openGeomancyFollowUp(question),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0A18).withAlpha(
                      _creatingFollowUp ? 100 : 180,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFC7A867).withAlpha(
                        _creatingFollowUp ? 45 : 95,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          question,
                          style: GoogleFonts.cormorantGaramond(
                            color: _creatingFollowUp
                                ? const Color(0xFF6B6080)
                                : const Color(0xFFE5D5F5),
                            fontSize: 17,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _creatingFollowUp
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFFD88A),
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFFFFD88A),
                              size: 18,
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shieldCard(GeomancyChartModel chart) {
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: GeomancyShieldChart(chart: chart),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    Color? borderColor,
    Color? glowColor,
    double radius = 28,
    double? width,
  }) {
    final effectiveBorder =
        borderColor ?? const Color(0xFFC7A867).withAlpha(77);
    final effectiveGlow = glowColor ?? const Color(0xFFC7A867).withAlpha(22);

    return Container(
      width: width ?? double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A18),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: effectiveBorder, width: 1),
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

class _GeomancyHistorySheet extends StatefulWidget {
  final GeomancyService service;
  final ValueChanged<GeomancySavedReading> onSelect;
  final VoidCallback onCleared;

  const _GeomancyHistorySheet({
    required this.service,
    required this.onSelect,
    required this.onCleared,
  });

  @override
  State<_GeomancyHistorySheet> createState() => _GeomancyHistorySheetState();
}

class _GeomancyHistorySheetState extends State<_GeomancyHistorySheet> {
  late Future<List<GeomancySavedReading>> _future;
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
            'Clear geomancy history?',
            style: TextStyle(
              color: Color(0xFFFFD88A),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This will permanently delete all saved Geomancy readings from your history.',
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
      await widget.service.clearSavedReadings();
      widget.onCleared();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geomancy history cleared.'),
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
                        'Geomancy History',
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
                    'Open a previous shield reading. Old readings can be viewed and shared, but follow-up chat is only for fresh readings.',
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
                child: FutureBuilder<List<GeomancySavedReading>>(
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
                            'No saved geomancy readings yet. Complete a shield reading and it will appear here.',
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
                        final savedReading = readings[index];
                        return _historyTile(savedReading);
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

  Widget _historyTile(GeomancySavedReading savedReading) {
    final reading = savedReading.reading;
    final date = savedReading.createdAt;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return GestureDetector(
      onTap: () => widget.onSelect(savedReading),
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
                  reading.chart.judge.name.isEmpty
                      ? '?'
                      : reading.chart.judge.name.characters.first,
                  style: const TextStyle(
                    color: Color(0xFFFFD88A),
                    fontSize: 22,
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
                    reading.question.trim().isEmpty
                        ? 'General geomancy reading'
                        : reading.question.trim(),
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
                    '${reading.chart.judge.name} • ${reading.answer}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB8AEE0),
                      fontSize: 12.5,
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
          const Color(0xFF9D6FE8).withValues(alpha: 0.15),
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
        ..strokeWidth = 1.5,
    );

    canvas.drawCircle(
      center,
      radius * 0.25,
      Paint()
        ..color = const Color(0xFFB58E34).withValues(alpha: 0.6)
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

    final math.Random fixedRandom = math.Random(42);
    const int numTendrils = 7;

    for (int i = 0; i < numTendrils; i++) {
      final double baseAngle = i * 2 * math.pi / numTendrils;
      final double dynamicAngle =
          baseAngle + math.sin(progress * 2 * math.pi + i) * 0.5;

      final Offset endPoint = Offset(
        center.dx + math.cos(dynamicAngle) * radius * 0.95,
        center.dy + math.sin(dynamicAngle) * radius * 0.95,
      );

      final double wave1 = math.cos(progress * 4 * math.pi + i * 2);
      final double wave2 = math.sin(progress * 6 * math.pi + i * 3);

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
          math.sin(progress * 20 * math.pi + i) * 0.2;

      final double safeFlicker = flicker.clamp(0.2, 1.0);

      final Color tendrilColor =
          i % 2 == 0 ? const Color(0xFFE040FB) : const Color(0xFF00E5FF);

      canvas.drawPath(
        path,
        Paint()
          ..color = tendrilColor.withValues(alpha: 0.6 * safeFlicker)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFE5D5F5).withValues(alpha: 0.9 * safeFlicker)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      canvas.drawCircle(
        endPoint,
        3.0 * safeFlicker,
        Paint()
          ..color = const Color(0xFFE5D5F5).withValues(alpha: safeFlicker)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TeslaGlobePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SacredGeometryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC7A867).withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw some concentric circles and diamonds
    for (int i = 1; i <= 5; i++) {
      final radius = size.width * 0.15 * i;
      canvas.drawCircle(center, radius, paint);

      final path = Path()
        ..moveTo(center.dx, center.dy - radius)
        ..lineTo(center.dx + radius, center.dy)
        ..lineTo(center.dx, center.dy + radius)
        ..lineTo(center.dx - radius, center.dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ShieldEmblemPainter extends CustomPainter {
  final double rotationProgress;
  final double pulse;

  _ShieldEmblemPainter({required this.rotationProgress, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC7A867).withValues(alpha: 0.5 + 0.3 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + (0.5 * pulse);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationProgress * 2 * math.pi);

    // Outer circle
    canvas.drawCircle(Offset.zero, radius, paint);

    // Inner circle
    canvas.drawCircle(Offset.zero, radius * 0.65, paint);

    // Draw square 1
    _drawPolygon(canvas, 4, radius, 0, paint);

    // Draw square 2 (rotated by 45 degrees to form an 8-pointed star shape with square 1)
    _drawPolygon(canvas, 4, radius, math.pi / 4, paint);

    // Draw triangle
    _drawPolygon(canvas, 3, radius * 0.65, -math.pi / 2, paint);

    // Draw an inner hexagram
    _drawPolygon(canvas, 3, radius * 0.4, -math.pi / 2, paint);
    _drawPolygon(canvas, 3, radius * 0.4, math.pi / 2, paint);

    canvas.restore();
  }

  void _drawPolygon(Canvas canvas, int sides, double radius, double offsetAngle,
      Paint paint) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final angle = offsetAngle + i * (2 * math.pi / sides);
      final point = Offset(radius * math.cos(angle), radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ShieldEmblemPainter oldDelegate) {
    return oldDelegate.rotationProgress != rotationProgress ||
        oldDelegate.pulse != pulse;
  }
}
