import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/streak_reward_model.dart';
import '../services/horoscope_service.dart';
import '../services/streak_reward_service.dart';
import '../services/user_profile_cache_service.dart';
import '../widgets/ai_report_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _horoscopeService = HoroscopeService();
  final _streakRewardService = StreakRewardService();
  final _storage = const FlutterSecureStorage();

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _horoscope;
  bool _loading = true;
  bool _horoscopeLoading = true;
  bool _horoscopeRevealed = false;
  bool _showCosmicBlueprintHint = false;
  Timer? _cosmicBlueprintHintTimer;

  bool _streakLoading = true;
  bool _claimingStreak = false;
  bool _openingReward = false;

  int _rewardCycleDay = 0;

  bool _freeRewardAvailable = false;
  String? _freeRewardType;
  String? _lastClaimDate;

  late final AnimationController _roadFillController;
  Animation<double> _roadFillAnimation =
      const AlwaysStoppedAnimation<double>(0.0);
  double _displayedRoadProgress = 0.0;

  bool _bhriguGlowing = false;
  String _bhriguAnswer = '';
  late final AnimationController _plasmaController;

  static const _bhriguAnswers = [
    'It is certain.',
    'Without a doubt.',
    'Yes, definitely.',
    'As I see it, yes.',
    'Signs point to yes.',
    'Reply hazy, try again.',
    'Ask again later.',
    'Better not tell you now.',
    'Cannot predict now.',
    'Concentrate and ask again.',
    'Don\'t count on it.',
    'My reply is no.',
    'My sources say no.',
    'Outlook not so good.',
    'Very doubtful.',
  ];

  late Map<String, String> _angelNumber;
  static Map<String, String>? _sessionAngelNumber;

  late AnimationController _envelopeController;
  late Animation<double> _envelopeFade;

  static const _angelNumbers = [
    {
      'number': '111',
      'meaning':
          'A new beginning is manifesting. Your thoughts are becoming reality.'
    },
    {
      'number': '222',
      'meaning': 'Trust the process. Balance and harmony are aligning for you.'
    },
    {
      'number': '333',
      'meaning': 'The universe supports you. Your guides are near.'
    },
    {
      'number': '444',
      'meaning':
          'Protection surrounds you. You are exactly where you need to be.'
    },
    {
      'number': '555',
      'meaning': 'Major change is coming. Embrace the transformation.'
    },
    {
      'number': '666',
      'meaning':
          'Refocus your thoughts. Align your mind with your higher purpose.'
    },
    {
      'number': '777',
      'meaning': 'Divine luck flows toward you. A spiritual reward is near.'
    },
    {
      'number': '888',
      'meaning':
          'Abundance is on its way. Financial and spiritual wealth align.'
    },
    {
      'number': '999',
      'meaning':
          'A chapter closes. Release the old and welcome what comes next.'
    },
    {
      'number': '000',
      'meaning':
          'You are one with the universe. Infinite possibilities surround you.'
    },
    {
      'number': '1111',
      'meaning': 'A portal opens. Make a wish — the universe is listening.'
    },
    {
      'number': '1212',
      'meaning': 'Stay positive. Your spiritual growth is accelerating.'
    },
    {
      'number': '1234',
      'meaning': 'Step by step, you are moving in the right direction.'
    },
    {
      'number': '2222',
      'meaning': 'Patience. Everything you have planted is about to bloom.'
    },
    {
      'number': '3333',
      'meaning': 'Your ascended masters are with you. Ask for guidance freely.'
    },
  ];

  @override
  void initState() {
    super.initState();

    _sessionAngelNumber ??=
        _angelNumbers[math.Random().nextInt(_angelNumbers.length)];
    _angelNumber = _sessionAngelNumber!;

    _envelopeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _envelopeFade =
        CurvedAnimation(parent: _envelopeController, curve: Curves.easeIn);

    _plasmaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _roadFillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _roadFillController.addListener(() {
      if (!mounted) return;
      setState(() {
        _displayedRoadProgress = _roadFillAnimation.value;
      });
    });

    _loadData();
  }

  @override
  void dispose() {
    _cosmicBlueprintHintTimer?.cancel();
    _roadFillController.dispose();
    _envelopeController.dispose();
    _plasmaController.dispose();
    super.dispose();
  }

  bool _isTodayClaimed() {
    return StreakRewardState(
      rewardCycleDay: _rewardCycleDay,
      freeRewardAvailable: _freeRewardAvailable,
      freeRewardType: _freeRewardType,
      lastClaimDate: _lastClaimDate,
    ).isClaimedOn(DateTime.now());
  }

  void _animateRoadFill({
    required double from,
    required double to,
  }) {
    _roadFillController.stop();

    _roadFillAnimation = Tween<double>(
      begin: from.clamp(0.0, 1.0),
      end: to.clamp(0.0, 1.0),
    ).animate(
      CurvedAnimation(
        parent: _roadFillController,
        curve: Curves.easeOutCubic,
      ),
    );

    _roadFillController.forward(from: 0.0);
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ??
        await _storage.read(key: 'user_id');

    if (uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _streakLoading = false;
          _horoscopeLoading = false;
        });
      }
      return;
    }

    final userDataFuture = UserProfileCacheService.instance.userData();
    final horoscopeFuture = _horoscopeService.getDailyHoroscope(uid: uid);
    unawaited(_loadStreakReward(uid));
    unawaited(_maybeShowCosmicBlueprintHint(uid).catchError((_) {}));

    final userData = await userDataFuture.catchError((_) => null);

    if (!mounted) return;

    setState(() {
      _userData = userData;
      _loading = false;
    });

    final horoscope = await horoscopeFuture.catchError((_) => null);
    if (mounted) {
      setState(() {
        _horoscope = horoscope;
        _horoscopeLoading = false;
      });
    }
  }

  Future<void> _loadStreakReward(String uid) async {
    try {
      final rewardState = await _streakRewardService.load(uid);

      if (!mounted) return;

      setState(() {
        _streakLoading = false;
        _rewardCycleDay = rewardState.rewardCycleDay;
        _freeRewardAvailable = rewardState.freeRewardAvailable;
        _freeRewardType = rewardState.freeRewardType;
        _lastClaimDate = rewardState.lastClaimDate;
        _displayedRoadProgress = 0.0;
      });

      _animateRoadFill(from: 0.0, to: rewardState.roadProgress);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _streakLoading = false;
      });
    }
  }

  Future<void> _claimDailyStreak() async {
    if (_claimingStreak) return;

    if (_isTodayClaimed()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already claimed today. Come back tomorrow.'),
          backgroundColor: Color(0xFF1A1630),
        ),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ??
        await _storage.read(key: 'user_id');
    if (uid == null) return;

    final previousProgress = _displayedRoadProgress;

    setState(() {
      _claimingStreak = true;
    });

    try {
      final claim = await _streakRewardService.claimDaily(uid: uid);

      if (!mounted) return;

      setState(() {
        _rewardCycleDay = claim.state.rewardCycleDay;
        _lastClaimDate = claim.state.lastClaimDate;
        _freeRewardAvailable = claim.state.freeRewardAvailable;
        _freeRewardType = claim.state.freeRewardType;
        _claimingStreak = false;
      });

      _animateRoadFill(
        from: previousProgress,
        to: claim.nextProgress,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _claimingStreak = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not claim reward. Check Firestore rules.'),
          backgroundColor: Color(0xFF1A1630),
        ),
      );
    }
  }

  Future<void> _openFreeReward() async {
    if (!_freeRewardAvailable || _openingReward) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ??
        await _storage.read(key: 'user_id');
    if (uid == null) return;

    final rewardRoute = StreakRewardState(
      rewardCycleDay: _rewardCycleDay,
      freeRewardAvailable: _freeRewardAvailable,
      freeRewardType: _freeRewardType,
      lastClaimDate: _lastClaimDate,
    ).rewardRoute;

    setState(() {
      _openingReward = true;
    });

    try {
      await _streakRewardService.consumeFreeReward(uid);

      if (!mounted) return;

      setState(() {
        _freeRewardAvailable = false;
        _freeRewardType = null;
        _rewardCycleDay = 0;
        _openingReward = false;
      });

      _animateRoadFill(
        from: _displayedRoadProgress,
        to: 0.0,
      );

      context.push(rewardRoute);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _openingReward = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open gift. Please try again.'),
          backgroundColor: Color(0xFF1A1630),
        ),
      );
    }
  }

  Future<void> _maybeShowCosmicBlueprintHint(String uid) async {
    final seenKey = 'cosmic_blueprint_hint_seen_$uid';
    final alreadySeen = await _storage.read(key: seenKey);

    if (alreadySeen == 'true') return;

    final createdAt = FirebaseAuth.instance.currentUser?.metadata.creationTime;
    final isNewUser = createdAt != null &&
        DateTime.now().difference(createdAt).inMinutes <= 30;

    if (!isNewUser) return;

    await _storage.write(key: seenKey, value: 'true');

    if (!mounted) return;

    setState(() {
      _showCosmicBlueprintHint = true;
    });

    _cosmicBlueprintHintTimer?.cancel();
    _cosmicBlueprintHintTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;

      setState(() {
        _showCosmicBlueprintHint = false;
      });
    });
  }

  void _revealHoroscope() {
    if (_horoscopeRevealed) return;
    setState(() => _horoscopeRevealed = true);
    _envelopeController.forward();
  }

  void _askBhrigu() async {
    if (_bhriguGlowing) return;

    setState(() {
      _bhriguGlowing = true;
      _bhriguAnswer = '';
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      setState(() {
        _bhriguAnswer =
            _bhriguAnswers[math.Random().nextInt(_bhriguAnswers.length)];
        _bhriguGlowing = false;
      });
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _todayFormatted() {
    final now = DateTime.now();

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return _homeLoadingPage();
    }

    final now = DateTime.now();
    final name = _userData?['name'] ?? '';
    final sunSign = _horoscopeService.getSunSign(_userData?['dob']);
    final moonPhaseInfo = _horoscopeService.getMoonPhaseInfo(date: now);
    final dailyEnergy = _horoscopeService.getDailyEnergyInfo(date: now);
    final moonPhaseLine =
        (_horoscope?['moonPhaseLine'] as String? ?? '').trim();
    final dailyEnergyLine =
        (_horoscope?['dailyEnergyLine'] as String? ?? '').trim();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF9D6FE8),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _welcomeHeader(name, sunSign),
                const SizedBox(height: 24),
                _sectionLabel('TODAY\'S READING'),
                const SizedBox(height: 12),
                _horoscopeCard(),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _moonPhaseCard(
                          moonPhaseInfo: moonPhaseInfo,
                          subtitle: moonPhaseLine.isEmpty
                              ? _horoscopeService.getMoonPhaseOneLiner(
                                  moonPhaseInfo: moonPhaseInfo,
                                )
                              : moonPhaseLine,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: _dailyEnergyCard(
                          dailyEnergy,
                          subtitle: dailyEnergyLine.isEmpty
                              ? _horoscopeService.getDailyEnergyOneLiner(
                                  dailyEnergyInfo: dailyEnergy,
                                )
                              : dailyEnergyLine,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _angelNumberCard()),
                      const SizedBox(width: 12),
                      Expanded(child: _bhriguCard()),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _dreamCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _homeLoadingPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF03010A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF020008),
                  Color(0xFF080214),
                  Color(0xFF17062A),
                  Color(0xFF07010F),
                ],
                stops: [0.0, 0.38, 0.72, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.18, -0.12),
                radius: 0.82,
                colors: [
                  const Color(0xFF4A148C).withValues(alpha: 0.36),
                  const Color(0xFF14051F).withValues(alpha: 0.18),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.46, 1.0],
              ),
            ),
          ),
          CustomPaint(
            painter: _CosmicLoadingBackgroundPainter(),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _plasmaController,
              builder: (context, child) => Container(
                width: 112,
                height: 112,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE040FB).withValues(alpha: 0.22),
                      blurRadius: 42,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: CustomPaint(
                    painter: _TeslaGlobePainter(_plasmaController.value),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeHeader(String name, String sunSign) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _todayFormatted(),
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B6080),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${_greeting()}, ',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w300,
                        color: Color(0xFFF0ECF8),
                      ),
                    ),
                    TextSpan(
                      text: name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9D6FE8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1630),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2E2650),
                      ),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Color(0xFFB58E34),
                      size: 22,
                    ),
                  ),
                ),
                Positioned(
                  right: 50,
                  top: -4,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _showCosmicBlueprintHint ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 350),
                      child: Container(
                        width: 155,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1630),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                const Color(0xFFB58E34).withValues(alpha: 0.45),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'View your cosmic blueprint here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC7A867),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          sunSign,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFF59E0B),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF6B6080),
        letterSpacing: 2,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _horoscopeCard() {
    return GestureDetector(
      onTap: _revealHoroscope,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E1065), Color(0xFF1A1630)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6B21A8), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _horoscopeLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: Color(0xFF9D6FE8),
                    strokeWidth: 2,
                  ),
                ),
              )
            : _horoscope == null
                ? const Text(
                    'Could not load today\'s reading. Pull to refresh.',
                    style: TextStyle(color: Color(0xFF6B6080)),
                  )
                : _horoscopeRevealed
                    ? FadeTransition(
                        opacity: _envelopeFade,
                        child: _horoscopePremiumReading(),
                      )
                    : _envelopeLocked(),
      ),
    );
  }

  Widget _envelopeLocked() {
    return Column(
      children: [
        SizedBox(
          width: 72,
          height: 54,
          child: CustomPaint(painter: _EnvelopePainter()),
        ),
        const SizedBox(height: 16),
        const Text(
          'TAP TO OPEN YOUR READING',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF9D6FE8),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sealed with cosmic intent',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B6080)),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _horoscopeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('🌅', style: TextStyle(fontSize: 14)),
            SizedBox(width: 8),
            Text(
              'MORNING INSIGHT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF59E0B),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _horoscope!['morning'] ?? '',
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Color(0xFFF0ECF8),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(color: Color(0xFF2E2650)),
        const SizedBox(height: 16),
        const Row(
          children: [
            Text('🌙', style: TextStyle(fontSize: 14)),
            SizedBox(width: 8),
            Text(
              'EVENING REFLECTION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9D6FE8),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _horoscope!['evening'] ?? '',
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Color(0xFFF0ECF8),
          ),
        ),
      ],
    );
  }

  Widget _horoscopePremiumReading() {
    final bhriguToday = _horoscopeText(
      'bhriguToday',
      fallback: _horoscopeText(
        'morning',
        fallback: 'Notice what keeps asking for your attention.',
      ),
    );
    final yourTransit = _horoscopeText(
      'yourTransit',
      fallback: _horoscopeText(
        'evening',
        fallback: 'Today asks for patience before reaction.',
      ),
    );
    final doText = _horoscopeText(
      'doText',
      fallback: _horoscopeJoinedList(
        'doLines',
        fallback: 'Choose one clean action and finish it before seeking signs.',
      ),
    );
    final avoidText = _horoscopeText(
      'avoidText',
      fallback: _horoscopeJoinedList(
        'avoidLines',
        fallback: 'Avoid turning silence into evidence, drama, or prophecy.',
      ),
    );
    final relationships = _horoscopeText(
      'relationships',
      fallback: 'Let consistency matter more than charm today.',
    );
    final workMoney = _horoscopeText(
      'workMoney',
      fallback: 'Small discipline brings more luck than big ambition.',
    );
    final innerWeather = _horoscopeText(
      'innerWeather',
      fallback: 'Calm outside does not always mean settled inside.',
    );
    final mantra = _horoscopeText(
      'mantra',
      fallback: 'Do not romanticize what costs your peace.',
    );
    final today = DateTime.now();
    final horoscopeContentId =
        'horoscope_${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final horoscopeReportText = [
      bhriguToday,
      yourTransit,
      doText,
      avoidText,
      relationships,
      workMoney,
      innerWeather,
      mantra,
    ].where((text) => text.trim().isNotEmpty).join('\n\n');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1430),
            Color(0xFF0F0A18),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFC7A867).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _horoscopeHook(bhriguToday),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF2E2650)),
          const SizedBox(height: 20),
          _horoscopeTransit(yourTransit),
          const SizedBox(height: 24),
          _horoscopeActionParagraphCards(
            doText: doText,
            avoidText: avoidText,
          ),
          const SizedBox(height: 24),
          _horoscopeLifeArea(
            label: 'RELATIONSHIPS',
            text: relationships,
          ),
          _horoscopeLifeArea(
            label: 'WORK / MONEY',
            text: workMoney,
          ),
          _horoscopeLifeArea(
            label: 'INNER WEATHER',
            text: innerWeather,
            bottomGap: 0,
          ),
          const SizedBox(height: 24),
          _horoscopeMantra(mantra),
          Align(
            alignment: Alignment.centerRight,
            child: AiReportButton(
              feature: 'horoscope',
              contentId: horoscopeContentId,
              contentText: horoscopeReportText,
              label: 'Report',
            ),
          ),
        ],
      ),
    );
  }

  Widget _horoscopeHook(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'BHRIGU TODAY',
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            color: const Color(0xFF6B6080),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontStyle: FontStyle.italic,
            height: 1.4,
            color: const Color(0xFFE5D5F5),
          ),
        ),
      ],
    );
  }

  Widget _horoscopeTransit(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR TRANSIT',
          style: GoogleFonts.cinzel(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: const Color(0xFFC7A867),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.5,
            color: const Color(0xFFB8AEE0),
          ),
        ),
      ],
    );
  }

  Widget _horoscopeActionParagraphCards({
    required String doText,
    required String avoidText,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackCards = constraints.maxWidth < 330;
        final doCard = _horoscopeActionParagraphCard(
          label: 'DO',
          text: doText,
          accent: const Color(0xFFE8B530),
          textColor: const Color(0xFFE5D5F5),
        );
        final avoidCard = _horoscopeActionParagraphCard(
          label: 'AVOID',
          text: avoidText,
          accent: const Color(0xFFE040FB),
          textColor: const Color(0xFFD8B4E2),
        );

        if (stackCards) {
          return Column(
            children: [
              doCard,
              const SizedBox(height: 12),
              avoidCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: doCard),
            const SizedBox(width: 12),
            Expanded(child: avoidCard),
          ],
        );
      },
    );
  }

  Widget _horoscopeActionParagraphCard({
    required String label,
    required String text,
    required Color accent,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050408).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.cinzel(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              height: 1.42,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _horoscopeActionCards({
    required List<String> doLines,
    required List<String> avoidLines,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackCards = constraints.maxWidth < 330;
        final doCard = _horoscopeActionCard(
          label: 'DO',
          lines: doLines,
          accent: const Color(0xFFE8B530),
          bullet: '✦',
          textColor: const Color(0xFFE5D5F5),
        );
        final avoidCard = _horoscopeActionCard(
          label: 'AVOID',
          lines: avoidLines,
          accent: const Color(0xFFE040FB),
          bullet: '◌',
          textColor: const Color(0xFFD8B4E2),
        );

        if (stackCards) {
          return Column(
            children: [
              doCard,
              const SizedBox(height: 12),
              avoidCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: doCard),
            const SizedBox(width: 12),
            Expanded(child: avoidCard),
          ],
        );
      },
    );
  }

  Widget _horoscopeActionCard({
    required String label,
    required List<String> lines,
    required Color accent,
    required String bullet,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050408).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.cinzel(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: accent,
            ),
          ),
          const SizedBox(height: 12),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bullet,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        height: 1.35,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _horoscopeText(String key, {String fallback = ''}) {
    final value = (_horoscope?[key] as String? ?? '').trim();
    return value.isEmpty ? fallback : value;
  }

  // ignore: unused_element
  List<String> _horoscopeList(
    String key, {
    required List<String> fallback,
  }) {
    final value = _horoscope?[key];

    if (value is List) {
      final lines = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();

      if (lines.isNotEmpty) return lines;
    }

    return fallback;
  }

  String _horoscopeJoinedList(String key, {required String fallback}) {
    final value = _horoscope?[key];

    if (value is List) {
      final lines = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();

      if (lines.isNotEmpty) return lines.join(' ');
    }

    return fallback;
  }

  Widget _horoscopeLifeArea({
    required String label,
    required String text,
    double bottomGap = 20,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.cinzel(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: const Color(0xFF6B6080),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 2,
                height: 44,
                margin: const EdgeInsets.only(top: 4, right: 14),
                color: const Color(0xFFC7A867).withValues(alpha: 0.4),
              ),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 18,
                    height: 1.5,
                    color: const Color(0xFFD4D4CE),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _horoscopeMantra(String mantra) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF050408).withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF9D6FE8).withValues(alpha: 0.26),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8B530).withValues(alpha: 0.12),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'MANTRA',
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: 10,
              letterSpacing: 4,
              color: const Color(0xFF9D6FE8),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            mantra,
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.35,
              color: const Color(0xFFE8B530),
              shadows: [
                Shadow(
                  color: const Color(0xFFE8B530).withValues(alpha: 0.55),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _horoscopeReadingSection({
    required String label,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF130D1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E1A4A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 38,
            margin: const EdgeInsets.only(top: 4, right: 14),
            color: const Color(0xFF8A6B22).withValues(alpha: 0.62),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB58E34),
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _horoscopeLineList(List<String> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            line,
            style: const TextStyle(
              fontSize: 14,
              height: 1.42,
              color: Color(0xFFD4D4CE),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ignore: unused_element
  Widget _horoscopeBodyText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.55,
        color: Color(0xFFD4D4CE),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _moonPhaseCard({
    required MoonPhaseInfo moonPhaseInfo,
    required String subtitle,
  }) {
    return _cosmicStatusCard(
      label: 'MOON PHASE',
      mainIcon: moonPhaseInfo.icon,
      title: moonPhaseInfo.name,
      subtitle: subtitle,
      orbAccent: const Color(0xFF9D6FE8),
      titleColor: const Color(0xFFF0ECF8),
      isMoonCard: true,
    );
  }

  Widget _dailyEnergyCard(
    DailyEnergyInfo energy, {
    required String subtitle,
  }) {
    final symbol = energy.symbol;
    final planet = energy.planet;

    return _cosmicStatusCard(
      label: 'DAILY ENERGY',
      mainIcon: symbol,
      title: planet,
      subtitle: subtitle,
      orbAccent: const Color(0xFFF59E0B),
      titleColor: const Color(0xFFF59E0B),
      isMoonCard: false,
    );
  }

  Widget _cosmicStatusCard({
    required String label,
    required String mainIcon,
    required String title,
    required String subtitle,
    required Color orbAccent,
    required Color titleColor,
    required bool isMoonCard,
  }) {
    final titleWords = title.trim().split(RegExp(r'\s+'));

    Widget titleWidget;

    if (isMoonCard) {
      titleWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: titleWords.map((word) {
          return Text(
            word,
            style: TextStyle(
              fontSize: 14,
              color: titleColor,
              height: 1.12,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          );
        }).toList(),
      );
    } else {
      titleWidget = FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: titleColor,
            height: 1.18,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.clip,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 178),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1630),
            const Color(0xFF171228).withValues(alpha: 0.92),
            const Color(0xFF0D0B1E).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E2650)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _plasmaController,
        builder: (context, child) {
          final pulse = isMoonCard
              ? 0.55
              : 0.55 + math.sin(_plasmaController.value * math.pi * 2) * 0.18;

          final glowOpacity = (0.16 + pulse * 0.18).clamp(0.0, 1.0);
          final softOpacity = (0.08 + pulse * 0.08).clamp(0.0, 1.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF6B6080),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0B0F19),
                      border: Border.all(
                        color: orbAccent.withValues(alpha: 0.45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: orbAccent.withValues(alpha: glowOpacity),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: const Color(0xFFC7A867)
                              .withValues(alpha: softOpacity),
                          blurRadius: 24,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: isMoonCard
                          ? _MoonPhaseAsset(
                              phaseIcon: mainIcon,
                            )
                          : Text(
                              mainIcon,
                              style: const TextStyle(fontSize: 25),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: titleWidget,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0B1E).withValues(alpha: 0.46),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFB58E34).withValues(alpha: 0.20),
                  ),
                ),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFFC7A867),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                  softWrap: true,
                  maxLines: 6,
                  overflow: TextOverflow.clip,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _angelNumberCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1630),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E2650)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('✨', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text(
                'ANGEL NUMBER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B6080),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _angelNumber['number']!,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF59E0B),
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              _angelNumber['meaning']!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFF0ECF8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bhriguCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1630),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E2650)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ASK BHRIGU',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B6080),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _askBhrigu,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB58E34)
                        .withValues(alpha: _bhriguGlowing ? 0.6 : 0.0),
                    blurRadius: _bhriguGlowing ? 30 : 0,
                    spreadRadius: _bhriguGlowing ? 8 : 0,
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _plasmaController,
                builder: (context, child) => CustomPaint(
                  painter: _TeslaGlobePainter(_plasmaController.value),
                ),
              ),
            ),
          ),
          const Spacer(),
          _bhriguAnswer.isEmpty
              ? const Text(
                  'TAP TO ASK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B6080),
                    letterSpacing: 1,
                  ),
                )
              : Text(
                  _bhriguAnswer,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE5D5F5),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _dreamCard() {
    final todayClaimed = _isTodayClaimed();
    final progressPercent = (_displayedRoadProgress * 100).round();

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
      child: _streakLoading
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
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _plasmaController,
                      builder: (context, child) {
                        final glow = 0.35 +
                            math.sin(_plasmaController.value * math.pi * 2) *
                                0.18;

                        return Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2E1065),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB58E34)
                                    .withValues(alpha: glow),
                                blurRadius: 15,
                                spreadRadius: 1.5,
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0xFFB58E34)
                                  .withValues(alpha: 0.62),
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.local_fire_department_rounded,
                              color: Color(0xFFF59E0B),
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STREAK REWARDS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.6,
                              color: Color(0xFFC7A867),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Gift unlocks every 4 days',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF0ECF8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: _plasmaController,
                    builder: (context, child) {
                      final pulse = 0.75 +
                          math.sin(_plasmaController.value * math.pi * 2) *
                              0.25;

                      return CustomPaint(
                        painter: _StreakRoadPainter(
                          progress: _displayedRoadProgress.clamp(0.0, 1.0),
                          pulse: pulse,
                          unlocked: _freeRewardAvailable,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  _freeRewardAvailable
                      ? 'Your gift contains a free ${_freeRewardType == 'geomancy' ? 'Geomancy' : 'Tarot'} reading.'
                      : todayClaimed
                          ? 'Claimed today. Reward path is $progressPercent% complete.'
                          : 'Claim today to fill the golden path toward your gift.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFFE5D5F5),
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _openingReward
                            ? null
                            : () {
                                if (_freeRewardAvailable) {
                                  _openFreeReward();
                                } else {
                                  _claimDailyStreak();
                                }
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            gradient: LinearGradient(
                              colors: _freeRewardAvailable
                                  ? const [
                                      Color(0xFFB58E34),
                                      Color(0xFFF59E0B),
                                    ]
                                  : todayClaimed
                                      ? const [
                                          Color(0xFF2E2650),
                                          Color(0xFF2E2650),
                                        ]
                                      : const [
                                          Color(0xFF6B21A8),
                                          Color(0xFF9D6FE8),
                                        ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _openingReward
                                  ? 'OPENING...'
                                  : _claimingStreak
                                      ? 'CLAIMING...'
                                      : _freeRewardAvailable
                                          ? 'OPEN GIFT'
                                          : todayClaimed
                                              ? 'CLAIMED TODAY'
                                              : 'CLAIM TODAY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: todayClaimed && !_freeRewardAvailable
                                    ? const Color(0xFF6B6080)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _EnvelopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9D6FE8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF2E1065)
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );

    canvas.drawRRect(rect, fillPaint);
    canvas.drawRRect(rect, paint);

    canvas.drawLine(
      const Offset(0, 4),
      Offset(size.width / 2, size.height * 0.6),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 4),
      Offset(size.width / 2, size.height * 0.6),
      paint,
    );

    final dimPaint = Paint()
      ..color = const Color(0xFF6B21A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width * 0.35, size.height * 0.55),
      dimPaint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width * 0.65, size.height * 0.55),
      dimPaint,
    );

    final sealPaint = Paint()
      ..color = const Color(0xFF6B21A8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width / 2, size.height * 0.62), 7, sealPaint);
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.62),
      7,
      paint..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StreakRoadPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final bool unlocked;

  _StreakRoadPainter({
    required this.progress,
    required this.pulse,
    required this.unlocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(12, size.height / 2);
    final end = Offset(size.width - 48, size.height / 2);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    final edgePaint = Paint()
      ..color = const Color(0xFFB58E34).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;

    final basePaint = Paint()
      ..color = const Color(0xFF2E2650)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    final activeGlowPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.16 + pulse * 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final activePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFB58E34),
          Color(0xFFF59E0B),
          Color(0xFFC7A867),
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, shadowPaint);
    canvas.drawLine(start, end, edgePaint);
    canvas.drawLine(start, end, basePaint);

    final safeProgress = progress.clamp(0.0, 1.0);
    final activeEnd = Offset(
      start.dx + (end.dx - start.dx) * safeProgress,
      start.dy,
    );

    if (safeProgress > 0.0) {
      canvas.drawLine(start, activeEnd, activeGlowPaint);
      canvas.drawLine(start, activeEnd, activePaint);
    }

    final sparklePaint = Paint()
      ..color = const Color(0xFFF0ECF8).withValues(alpha: 0.36)
      ..style = PaintingStyle.fill;

    final activeLength = (end.dx - start.dx) * safeProgress;
    double distance = 14;

    while (distance < activeLength) {
      canvas.drawCircle(
        Offset(start.dx + distance, start.dy),
        1.45,
        sparklePaint,
      );
      distance += 18;
    }

    final giftSize = unlocked ? 44.0 : 38.0;

    canvas.save();
    canvas.translate(
      size.width - giftSize - 2,
      size.height / 2 - giftSize / 2,
    );

    _RewardGiftPainter(
      unlocked: unlocked,
      pulse: pulse,
    ).paint(
      canvas,
      Size(giftSize, giftSize),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StreakRoadPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.unlocked != unlocked;
  }
}

class _RewardGiftPainter extends CustomPainter {
  final bool unlocked;
  final double pulse;

  _RewardGiftPainter({
    required this.unlocked,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;

    final glowPaint = Paint()
      ..color = const Color(0xFFF59E0B)
          .withValues(alpha: unlocked ? 0.26 + pulse * 0.16 : 0.11)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(
      Offset(centerX, size.height * 0.55),
      unlocked ? size.width * 0.42 : size.width * 0.30,
      glowPaint,
    );

    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.40,
        size.width * 0.64,
        size.height * 0.40,
      ),
      const Radius.circular(6),
    );

    final lidRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.14,
        size.height * 0.31,
        size.width * 0.72,
        size.height * 0.17,
      ),
      const Radius.circular(5),
    );

    final boxPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF9D6FE8),
          Color(0xFF6B21A8),
          Color(0xFF2E1065),
        ],
      ).createShader(boxRect.outerRect);

    final lidPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFC7A867),
          Color(0xFFF59E0B),
          Color(0xFFB58E34),
        ],
      ).createShader(lidRect.outerRect);

    canvas.drawRRect(boxRect, boxPaint);
    canvas.drawRRect(lidRect, lidPaint);

    final ribbonPaint = Paint()
      ..color = const Color(0xFFC7A867)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - size.width * 0.06,
          size.height * 0.32,
          size.width * 0.12,
          size.height * 0.48,
        ),
        const Radius.circular(3),
      ),
      ribbonPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.14,
          size.height * 0.42,
          size.width * 0.72,
          size.height * 0.07,
        ),
        const Radius.circular(3),
      ),
      ribbonPaint,
    );

    final borderPaint = Paint()
      ..color = const Color(0xFFC7A867).withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(boxRect, borderPaint);
    canvas.drawRRect(lidRect, borderPaint);

    final bowPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFF59E0B),
          Color(0xFFC7A867),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final leftBow = Path()
      ..moveTo(centerX, size.height * 0.32)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.12,
        size.width * 0.18,
        size.height * 0.35,
        centerX,
        size.height * 0.37,
      );

    final rightBow = Path()
      ..moveTo(centerX, size.height * 0.32)
      ..cubicTo(
        size.width * 0.75,
        size.height * 0.12,
        size.width * 0.82,
        size.height * 0.35,
        centerX,
        size.height * 0.37,
      );

    canvas.drawPath(leftBow, bowPaint);
    canvas.drawPath(rightBow, bowPaint);

    canvas.drawCircle(
      Offset(centerX, size.height * 0.35),
      size.width * 0.07,
      Paint()..color = const Color(0xFFC7A867),
    );

    if (unlocked) {
      final sparklePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;

      void sparkle(Offset c, double s) {
        canvas.drawLine(
          Offset(c.dx - s, c.dy),
          Offset(c.dx + s, c.dy),
          sparklePaint,
        );
        canvas.drawLine(
          Offset(c.dx, c.dy - s),
          Offset(c.dx, c.dy + s),
          sparklePaint,
        );
      }

      sparkle(Offset(size.width * 0.20, size.height * 0.22), 3);
      sparkle(Offset(size.width * 0.82, size.height * 0.24), 2.6);
    }
  }

  @override
  bool shouldRepaint(covariant _RewardGiftPainter oldDelegate) {
    return oldDelegate.unlocked != unlocked || oldDelegate.pulse != pulse;
  }
}

class _CosmicLoadingBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(11);
    final starPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 72; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final radius = 0.45 + random.nextDouble() * 1.05;
      final alpha = 0.16 + random.nextDouble() * 0.42;

      starPaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(dx, dy), radius, starPaint);
    }

    final veilPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7B1FA2).withValues(alpha: 0.12),
          const Color(0xFF1A0632).withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.62, size.height * 0.62),
          radius: size.shortestSide * 0.82,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.62),
      size.shortestSide * 0.82,
      veilPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CosmicLoadingBackgroundPainter oldDelegate) {
    return false;
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

class _MoonPhaseAsset extends StatelessWidget {
  final String phaseIcon;

  const _MoonPhaseAsset({
    required this.phaseIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD7C6FF).withValues(
                    alpha: 0.18,
                  ),
                  blurRadius: 9,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: const Color(0xFFFFF3C4).withValues(
                    alpha: 0.08,
                  ),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          ClipOval(
            child: Image.asset(
              _assetPathForPhase(phaseIcon),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  '🌕',
                  style: TextStyle(fontSize: 25),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _assetPathForPhase(String icon) {
    if (icon.isEmpty) return 'assets/planets/moon_phase_full.png';

    return switch (icon.runes.first) {
      0x1F311 => 'assets/planets/moon_phase_new.png',
      0x1F312 => 'assets/planets/moon_phase_waxing_crescent.png',
      0x1F313 => 'assets/planets/moon_phase_first_quarter.png',
      0x1F314 => 'assets/planets/moon_phase_waxing_gibbous.png',
      0x1F315 => 'assets/planets/moon_phase_full.png',
      0x1F316 => 'assets/planets/moon_phase_waning_gibbous.png',
      0x1F317 => 'assets/planets/moon_phase_last_quarter.png',
      0x1F318 => 'assets/planets/moon_phase_waning_crescent.png',
      _ => 'assets/planets/moon_phase_full.png',
    };
  }
}
