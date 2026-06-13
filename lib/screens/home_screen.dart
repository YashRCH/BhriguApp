import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/streak_reward_model.dart';
import '../services/horoscope_service.dart';
import '../services/streak_reward_service.dart';
import '../services/user_profile_cache_service.dart';
import '../utils/zodiac_signs.dart';
import '../widgets/ai_report_button.dart';
import '../widgets/planet_asset.dart';
import '../widgets/owl_home_card.dart';
import '../widgets/owl_sprite_animator.dart';
import '../widgets/zodiac_sign_icon.dart';

part 'home/home_screen_sections.dart';
part 'home/home_screen_visuals.dart';

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

  // ignore: unused_field
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
    final uid = FirebaseAuth.instance.currentUser?.uid;

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

  // ignore: unused_element
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

    final uid = FirebaseAuth.instance.currentUser?.uid;
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
          content: Text('Could not claim reward. Please try again.'),
          backgroundColor: Color(0xFF1A1630),
        ),
      );
    }
  }

  // ignore: unused_element
  Future<void> _openFreeReward() async {
    if (!_freeRewardAvailable || _openingReward) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
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
      extendBodyBehindAppBar: true,
      body: Container(
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
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFFC7A867),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
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
                OwlHomeCard(uid: FirebaseAuth.instance.currentUser?.uid ?? ''),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
