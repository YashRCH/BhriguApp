import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/ai_response_language.dart';
import '../constants/firebase_constants.dart';
import '../models/birth_place_suggestion.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();

  DateTime? _dob = _defaultBirthDate;
  TimeOfDay? _tob = _defaultBirthTime;
  final ValueNotifier<DateTime> _dobPreview =
      ValueNotifier<DateTime>(_defaultBirthDate);
  final ValueNotifier<TimeOfDay> _tobPreview =
      ValueNotifier<TimeOfDay>(_defaultBirthTime);
  String _place = '';
  double? _latitude;
  double? _longitude;
  final String _aiResponseLanguage = englishAiResponseLanguage;

  int _step = 0;
  bool _saving = false;
  String? _submitError;

  static final DateTime _defaultBirthDate = DateTime(2002, 1, 1);
  static const TimeOfDay _defaultBirthTime = TimeOfDay(hour: 11, minute: 11);

  late AnimationController _plasmaController;
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const List<String> _fallbackPlaces = [
    'New York, United States',
    'Los Angeles, United States',
    'Chicago, United States',
    'Houston, United States',
    'San Francisco, United States',
    'London, United Kingdom',
    'Paris, France',
    'Berlin, Germany',
    'Rome, Italy',
    'Madrid, Spain',
    'Toronto, Canada',
    'Vancouver, Canada',
    'Sydney, Australia',
    'Melbourne, Australia',
    'Tokyo, Japan',
    'Beijing, China',
    'Hong Kong, China',
    'Singapore',
    'Dubai, United Arab Emirates',
    'Mumbai, India',
    'New Delhi, India',
    'São Paulo, Brazil',
    'Buenos Aires, Argentina',
    'Mexico City, Mexico',
    'Cairo, Egypt',
    'Cape Town, South Africa',
    'Seoul, South Korea',
    'Istanbul, Turkey',
    'Bangkok, Thailand',
    'Jakarta, Indonesia',
  ];

  @override
  void initState() {
    super.initState();

    _plasmaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.2,
          1.0,
          curve: Curves.easeOut,
        ),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.0,
          1.0,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _dobPreview.dispose();
    _tobPreview.dispose();
    _plasmaController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _pickPlace() async {
    FocusScope.of(context).unfocus();

    final selected = await showModalBottomSheet<BirthPlaceSuggestion>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OnboardingPlacePickerSheet(
        initialValue: _place.trim(),
        fallbackPlaces: _fallbackPlaces,
      ),
    );

    if (selected == null || selected.description.trim().isEmpty || !mounted) {
      return;
    }

    setState(() {
      _place = selected.description.trim();
      _latitude = selected.latitude;
      _longitude = selected.longitude;
    });
  }

  void _back() {
    if (_step <= 0 || _saving) return;

    setState(() {
      _step--;
      _submitError = null;
    });
  }

  Future<void> _next() async {
    if (_saving) return;

    final formattedTob = _tob?.format(context) ?? '';

    if (_step == 2) {
      setState(() {
        _saving = true;
        _submitError = null;
      });

      try {
        final username = _cleanUsername(_usernameController.text);
        final doc = await FirebaseFirestore.instance
            .collection('usernames')
            .doc(username)
            .get();
        if (doc.exists) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (doc.data()?['uid'] != uid) {
            setState(() {
              _saving = false;
              _submitError = 'That username is taken. Choose another one.';
            });
            return;
          }
        }
      } catch (e) {
        setState(() {
          _saving = false;
          _submitError =
              'Could not verify username. Please check your connection and try again.';
        });
        return;
      }

      setState(() {
        _saving = false;
      });
    }

    if (_step < 5) {
      setState(() {
        _step++;
        _submitError = null;
      });
      return;
    }

    final user = UserModel(
      name: _nameController.text.trim(),
      username: _cleanUsername(_usernameController.text),
      dob: _dob!,
      timeOfBirth: formattedTob,
      placeOfBirth: _place.trim(),
      latitude: _latitude,
      longitude: _longitude,
      aiResponseLanguage: _aiResponseLanguage,
    );

    var saved = false;

    setState(() {
      _saving = true;
      _submitError = null;
    });

    try {
      await AuthService().saveUserData(user);

      if (!mounted) return;

      saved = true;
      context.go(_postOnboardingLocation());
    } on FirebaseFunctionsException catch (e, stack) {
      debugPrint('Onboarding save failed: ${e.code} ${e.message}');
      debugPrintStack(stackTrace: stack);

      if (!mounted) return;

      setState(() {
        if (e.code == 'already-exists') {
          _step = 2;
          _submitError = 'That username is taken. Choose another one.';
        } else if (e.code == 'invalid-argument') {
          _step = 2;
          _submitError =
              'Choose a username with 3-24 letters, numbers, or underscores.';
        } else {
          _submitError =
              'Could not create your Circle profile. Please check your connection and try again.';
        }
      });
    } catch (e, stack) {
      debugPrint('Onboarding save failed: $e');
      debugPrintStack(stackTrace: stack);

      if (!mounted) return;

      setState(() {
        _submitError =
            'Could not save your birth profile. Please check your connection and try again.';
      });
    } finally {
      if (mounted && !saved) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  bool get _canProceed {
    if (_step == 0) return true;
    if (_step == 1) return _nameController.text.trim().isNotEmpty;
    if (_step == 2) return _usernameError == null;
    if (_step == 3) return _dob != null;
    if (_step == 4) return _tob != null;
    if (_step == 5) return _place.trim().isNotEmpty;
    return false;
  }

  String? get _usernameError {
    final username = _cleanUsername(_usernameController.text);
    if (username.isEmpty) return 'Choose a username.';
    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username)) {
      return 'Use 3-24 letters, numbers, or underscores.';
    }

    return null;
  }

  String _cleanUsername(String value) {
    return value.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
  }

  String _postOnboardingLocation() {
    return _safeRedirectLocation(
          GoRouterState.of(context).uri.queryParameters['from'],
        ) ??
        '/home';
  }

  String? _safeRedirectLocation(String? value) {
    final location = value?.trim();
    if (location == null || location.isEmpty) return null;
    if (!location.startsWith('/') || location.startsWith('//')) return null;
    if (location.startsWith('/login') || location.startsWith('/onboarding')) {
      return null;
    }

    return location;
  }

  String get _buttonText {
    if (_step == 0) return 'BEGIN THE JOURNEY';
    if (_step == 5) return 'ENTER THE COSMOS';
    return 'CONTINUE';
  }

  @override
  Widget build(BuildContext context) {
    final canTapNext = _canProceed && !_saving;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.5,
            colors: [
              Color(0xFF1E1430),
              Color(0xFF0F0A18),
              Color(0xFF050408),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                AnimatedOpacity(
                  opacity: _step == 0 ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _step == 0 ? null : _back,
                        child: Container(
                          width: 34,
                          height: 34,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0F0A18).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFB58E34)
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Color(0xFFB58E34),
                            size: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: List.generate(
                            6,
                            (i) => Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(right: 8),
                                height: 4,
                                decoration: BoxDecoration(
                                  color: (i + 1) <= _step
                                      ? const Color(0xFFB58E34)
                                      : const Color(0xFF3A2D50),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: (i + 1) <= _step
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFB58E34)
                                                .withValues(alpha: 0.5),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  alignment:
                      _step == 0 ? Alignment.center : Alignment.centerLeft,
                  child: Text(
                    'BHR1GU',
                    style: GoogleFonts.cinzel(
                      fontSize: _step == 0 ? 42 : 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: const Color(0xFFE5D5F5),
                      shadows: [
                        Shadow(
                          color: const Color(0xFFE5D5F5).withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _stepSubtitle(),
                    key: ValueKey<int>(_step),
                    textAlign: _step == 0 ? TextAlign.center : TextAlign.left,
                    style: GoogleFonts.cinzel(
                      fontSize: 14,
                      color: const Color(0xFFB58E34),
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _buildStep(key: ValueKey<int>(_step)),
                  ),
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _submitError!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE53E3E).withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
                GestureDetector(
                  onTap: canTapNext ? _next : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: canTapNext
                          ? const Color(0xFF1E1430)
                          : const Color(0xFF0F0A18),
                      border: Border.all(
                        color: canTapNext
                            ? const Color(0xFFB58E34).withValues(alpha: 0.6)
                            : const Color(0xFF3A2D50),
                      ),
                      boxShadow: canTapNext
                          ? [
                              BoxShadow(
                                color: const Color(0xFFB58E34)
                                    .withValues(alpha: 0.2),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Color(0xFFB58E34),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _buttonText,
                              style: GoogleFonts.cinzel(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: canTapNext
                                    ? const Color(0xFFB58E34)
                                    : const Color(0xFF6B6080),
                                letterSpacing: 3.0,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stepSubtitle() {
    const titles = [
      'THE ANCIENT SAGE REBORN',
      'WHAT SHALL I CALL YOU?',
      'CHOOSE YOUR CIRCLE NAME',
      'WHEN WERE YOU BORN?',
      'AT WHAT HOUR?',
      'WHERE WERE YOU BORN?',
    ];

    return titles[_step];
  }

  Widget _buildStep({required Key key}) {
    switch (_step) {
      case 0:
        return _buildIntroStep(key: key);

      case 1:
        return _glassInput(
          key: key,
          child: TextField(
            controller: _nameController,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              color: const Color(0xFFE5D5F5),
            ),
            cursorColor: const Color(0xFFB58E34),
            decoration: _inputDecoration('Your name'),
          ),
        );

      case 2:
        return _buildUsernameStep(key: key);

      case 3:
        return SingleChildScrollView(
          key: key,
          primary: false,
          physics: const BouncingScrollPhysics(),
          child: _buildInlineDateStep(),
        );

      case 4:
        return SingleChildScrollView(
          key: key,
          primary: false,
          physics: const BouncingScrollPhysics(),
          child: _buildInlineTimeStep(),
        );

      case 5:
        return SingleChildScrollView(
          key: key,
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickPlace,
                child: _glassInput(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFFB58E34),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _place.trim().isEmpty
                                ? 'Search city, town, district, or country'
                                : _place.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 22,
                              color: _place.trim().isEmpty
                                  ? Colors.white30
                                  : const Color(0xFFE5D5F5),
                              fontStyle: _place.trim().isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF6B6080),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: const Color(0xFFB58E34).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  'Your birthplace helps BHR1GU anchor the birth chart to the horizon and local sky of your arrival.',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 18,
                    color: const Color(0xFFC7A867).withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0A18).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFB58E34).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      color: Color(0xFFB58E34),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Once you enter the cosmos, these details cannot be changed. Please make sure your birth details are accurate before continuing.',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 17,
                          color: const Color(0xFFC7A867).withValues(alpha: 0.9),
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      default:
        return SizedBox(key: key);
    }
  }

  Widget _buildInlineDateStep() {
    final selectedDate = _dob ?? _defaultBirthDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<DateTime>(
          valueListenable: _dobPreview,
          builder: (context, value, _) {
            return _pickerLabel(
              icon: Icons.calendar_today,
              label: 'Select date of birth',
              value: _formatSelectedDate(value),
            );
          },
        ),
        const SizedBox(height: 14),
        _inlineWheelFrame(
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: selectedDate,
            minimumDate: DateTime(1900),
            maximumDate: DateTime.now(),
            backgroundColor: Colors.transparent,
            changeReportingBehavior: ChangeReportingBehavior.onScrollEnd,
            onDateTimeChanged: (value) {
              final selected = DateTime(value.year, value.month, value.day);
              _dob = selected;
              _dobPreview.value = selected;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInlineTimeStep() {
    final selectedTime = _tob ?? _defaultBirthTime;
    final selectedDateTime = DateTime(
      2002,
      1,
      1,
      selectedTime.hour,
      selectedTime.minute,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<TimeOfDay>(
          valueListenable: _tobPreview,
          builder: (context, value, _) {
            return _pickerLabel(
              icon: Icons.access_time,
              label: 'Select time of birth',
              value: value.format(context),
            );
          },
        ),
        const SizedBox(height: 14),
        _inlineWheelFrame(
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            initialDateTime: selectedDateTime,
            use24hFormat: false,
            minuteInterval: 1,
            backgroundColor: Colors.transparent,
            changeReportingBehavior: ChangeReportingBehavior.onScrollEnd,
            onDateTimeChanged: (value) {
              final selected =
                  TimeOfDay(hour: value.hour, minute: value.minute);
              _tob = selected;
              _tobPreview.value = selected;
            },
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: const Color(0xFFB58E34).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
          ),
          child: Text(
            'Time of birth determines your Ascendant (Lagna) - the exact point where the eastern horizon met the cosmos at your arrival.',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              color: const Color(0xFFC7A867).withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pickerLabel({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: const Color(0xFFB58E34),
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFFBEB2D4),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cinzel(
              color: const Color(0xFFB58E34),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _inlineWheelFrame({required Widget child}) {
    return SizedBox(
      height: 156,
      width: double.infinity,
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFFB58E34),
          scaffoldBackgroundColor: Colors.transparent,
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: GoogleFonts.inter(
              color: const Color(0xFFE5D5F5),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            child,
            IgnorePointer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _wheelGuideLine(),
                  const SizedBox(height: 36),
                  _wheelGuideLine(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheelGuideLine() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFB58E34).withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  String _formatSelectedDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildUsernameStep({required Key key}) {
    final usernameError =
        _usernameController.text.trim().isEmpty ? null : _usernameError;

    return SingleChildScrollView(
      key: key,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _glassInput(
            child: TextField(
              controller: _usernameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {
                _submitError = null;
              }),
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                color: const Color(0xFFE5D5F5),
              ),
              cursorColor: const Color(0xFFB58E34),
              decoration: _inputDecoration('username').copyWith(
                prefixText: '@',
                prefixStyle: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  color: const Color(0xFFB58E34),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (usernameError != null) ...[
            const SizedBox(height: 10),
            Text(
              usernameError,
              style: GoogleFonts.inter(
                color: const Color(0xFFE53E3E).withValues(alpha: 0.9),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: const Color(0xFFB58E34).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
            child: Text(
              'Your username lets friends and partners find you in Circle. Your exact birth details stay private.',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                color: const Color(0xFFC7A867).withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0A18).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF3A2D50),
              ),
            ),
            child: Text(
              'Use 3-24 letters, numbers, or underscores.',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 17,
                color: const Color(0xFFC7A867).withValues(alpha: 0.9),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroStep({required Key key}) {
    return FadeTransition(
      key: key,
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _plasmaController,
                builder: (context, child) => SizedBox(
                  width: 140,
                  height: 140,
                  child: CustomPaint(
                    painter: _TeslaGlobePainter(_plasmaController.value),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'BHR1GU is your personal AI sage — created to read your birth blueprint, guide your questions, and reveal the hidden patterns of your life, love, and destiny. He combines ancient prediction algorithms with modern ones to give you the most accurate and insightful readings possible.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE5D5F5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0A18).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3A2D50)),
                ),
                child: Text(
                  'Named after Maharishi Bhrigu, one of the seven great sages (Saptarishis), who compiled the Bhrigu Samhita — the legendary astrological classic containing the karmic destinies of all humanity across time.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 17,
                    color: const Color(0xFFC7A867).withValues(alpha: 0.9),
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassInput({required Widget child, Key? key}) {
    return ClipRRect(
      key: key,
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0812).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3A2D50)),
          ),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.cormorantGaramond(
        color: Colors.white30,
        fontStyle: FontStyle.italic,
        fontSize: 20,
      ),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.all(20),
    );
  }
}

class _OnboardingPlacePickerSheet extends StatefulWidget {
  final String initialValue;
  final List<String> fallbackPlaces;

  const _OnboardingPlacePickerSheet({
    required this.initialValue,
    required this.fallbackPlaces,
  });

  @override
  State<_OnboardingPlacePickerSheet> createState() =>
      _OnboardingPlacePickerSheetState();
}

class _OnboardingPlacePickerSheetState
    extends State<_OnboardingPlacePickerSheet> {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final TextEditingController _searchController;

  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<BirthPlaceSuggestion> _places = [];

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(text: widget.initialValue);
    _places = _fallbackMatches(widget.initialValue);

    _searchController.addListener(_onSearchChanged);

    final initial = widget.initialValue.trim();
    if (initial.length >= 2) {
      _searchPlaces(initial);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    _debounce?.cancel();

    if (query.length < 2) {
      setState(() {
        _loading = false;
        _error = null;
        _places = _fallbackMatches(query);
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    _debounce = Timer(const Duration(milliseconds: 550), () {
      _searchPlaces(query);
    });
  }

  List<BirthPlaceSuggestion> _fallbackMatches(String query) {
    final text = query.trim().toLowerCase();

    if (text.isEmpty) {
      return widget.fallbackPlaces
          .take(20)
          .map((place) => BirthPlaceSuggestion(description: place))
          .toList();
    }

    return widget.fallbackPlaces
        .where((place) => place.toLowerCase().contains(text))
        .take(20)
        .map((place) => BirthPlaceSuggestion(description: place))
        .toList();
  }

  Future<void> _searchPlaces(String query) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('User not signed in');
      }

      final callable = _functions.httpsCallable('searchBirthPlaces');

      final response = await callable.call({
        'query': query,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final rawPlaceDetails = data['placeDetails'];
      final rawPlaces = data['places'];

      final detailedResults = rawPlaceDetails is List
          ? rawPlaceDetails
              .whereType<Map>()
              .map(
                (place) => BirthPlaceSuggestion.fromMap(
                  Map<String, dynamic>.from(place),
                ),
              )
              .where((place) => place.description.trim().isNotEmpty)
              .toList()
          : <BirthPlaceSuggestion>[];

      final legacyResults = rawPlaces is List
          ? rawPlaces
              .map((place) => place.toString().trim())
              .where((place) => place.isNotEmpty)
              .map((place) => BirthPlaceSuggestion(description: place))
              .toList()
          : <BirthPlaceSuggestion>[];

      final results =
          detailedResults.isNotEmpty ? detailedResults : legacyResults;

      if (!mounted || _searchController.text.trim() != query) return;

      setState(() {
        _loading = false;
        _error = null;
        _places = results.isEmpty ? _fallbackMatches(query) : results;
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'Onboarding place search FirebaseFunctionsException code: ${e.code}',
      );
      debugPrint(
        'Onboarding place search FirebaseFunctionsException message: ${e.message}',
      );
      debugPrint(
        'Onboarding place search FirebaseFunctionsException details: ${e.details}',
      );

      if (!mounted || _searchController.text.trim() != query) return;

      setState(() {
        _loading = false;
        _error =
            'Online place search failed: ${e.code}. You can still use the typed place.';
        _places = _fallbackMatches(query);
      });
    } catch (e, stack) {
      debugPrint('Onboarding place search error: $e');
      debugPrint('Onboarding place search stack: $stack');

      if (!mounted || _searchController.text.trim() != query) return;

      setState(() {
        _loading = false;
        _error = 'Could not search online. You can still use the typed place.';
        _places = _fallbackMatches(query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final typedValue = _searchController.text.trim();

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.50,
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
                  color: const Color(0xFF3A2D50),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFFB58E34),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Search Birth Place',
                        style: GoogleFonts.cinzel(
                          color: const Color(0xFFB58E34),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: GoogleFonts.cormorantGaramond(
                    color: const Color(0xFFE5D5F5),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: const Color(0xFFB58E34),
                  decoration: InputDecoration(
                    hintText: 'Type city, town, district, or country',
                    hintStyle: GoogleFonts.cormorantGaramond(
                      color: Colors.white30,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFFB58E34),
                    ),
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFB58E34),
                              ),
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF151126),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    _error!,
                    style: GoogleFonts.cormorantGaramond(
                      color: const Color(0xFFC7A867).withValues(alpha: 0.75),
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (typedValue.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(
                      context,
                      BirthPlaceSuggestion(description: typedValue),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151126),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color:
                              const Color(0xFFB58E34).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_location_alt_outlined,
                            color: Color(0xFFB58E34),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Use "$typedValue"',
                              style: GoogleFonts.cormorantGaramond(
                                color: const Color(0xFFE5D5F5),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: _places.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Start typing a city, town, district, or country.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cormorantGaramond(
                              color: const Color(0xFFC7A867)
                                  .withValues(alpha: 0.75),
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                        itemCount: _places.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final place = _places[index];

                          return GestureDetector(
                            onTap: () => Navigator.pop(context, place),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF151126),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFF3A2D50),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.place_outlined,
                                    color: Color(0xFFB58E34),
                                    size: 19,
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Text(
                                      place.description,
                                      style: GoogleFonts.cormorantGaramond(
                                        color: const Color(0xFFE5D5F5),
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF9D6FE8).withValues(alpha: 0.6 * safeFlicker)
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
