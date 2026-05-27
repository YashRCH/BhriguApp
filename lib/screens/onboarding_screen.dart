import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  DateTime? _dob;
  TimeOfDay? _tob;
  String _place = '';
  double? _latitude;
  double? _longitude;
  String _aiResponseLanguage = englishAiResponseLanguage;

  int _step = 0;
  bool _saving = false;
  String? _submitError;

  late AnimationController _plasmaController;
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const List<String> _fallbackPlaces = [
    'New Delhi, India',
    'Delhi, India',
    'Mumbai, Maharashtra, India',
    'Bengaluru, Karnataka, India',
    'Kolkata, West Bengal, India',
    'Chennai, Tamil Nadu, India',
    'Hyderabad, Telangana, India',
    'Pune, Maharashtra, India',
    'Ahmedabad, Gujarat, India',
    'Jaipur, Rajasthan, India',
    'Lucknow, Uttar Pradesh, India',
    'Kanpur, Uttar Pradesh, India',
    'Varanasi, Uttar Pradesh, India',
    'Prayagraj, Uttar Pradesh, India',
    'Indore, Madhya Pradesh, India',
    'Bhopal, Madhya Pradesh, India',
    'Gwalior, Madhya Pradesh, India',
    'Jabalpur, Madhya Pradesh, India',
    'Patna, Bihar, India',
    'Ranchi, Jharkhand, India',
    'Bhubaneswar, Odisha, India',
    'Guwahati, Assam, India',
    'Chandigarh, India',
    'Ludhiana, Punjab, India',
    'Amritsar, Punjab, India',
    'Dehradun, Uttarakhand, India',
    'Haridwar, Uttarakhand, India',
    'Shimla, Himachal Pradesh, India',
    'Jammu, Jammu and Kashmir, India',
    'Srinagar, Jammu and Kashmir, India',
    'Raipur, Chhattisgarh, India',
    'Nagpur, Maharashtra, India',
    'Nashik, Maharashtra, India',
    'Surat, Gujarat, India',
    'Vadodara, Gujarat, India',
    'Rajkot, Gujarat, India',
    'Udaipur, Rajasthan, India',
    'Jodhpur, Rajasthan, India',
    'Kota, Rajasthan, India',
    'Agra, Uttar Pradesh, India',
    'Meerut, Uttar Pradesh, India',
    'Noida, Uttar Pradesh, India',
    'Ghaziabad, Uttar Pradesh, India',
    'Gurugram, Haryana, India',
    'Faridabad, Haryana, India',
    'Mysuru, Karnataka, India',
    'Mangaluru, Karnataka, India',
    'Kochi, Kerala, India',
    'Thiruvananthapuram, Kerala, India',
    'Coimbatore, Tamil Nadu, India',
    'Madurai, Tamil Nadu, India',
    'Vijayawada, Andhra Pradesh, India',
    'Visakhapatnam, Andhra Pradesh, India',
    'Warangal, Telangana, India',
    'Dubai, United Arab Emirates',
    'Abu Dhabi, United Arab Emirates',
    'Doha, Qatar',
    'London, United Kingdom',
    'Manchester, United Kingdom',
    'Birmingham, United Kingdom',
    'New York, United States',
    'Los Angeles, United States',
    'Chicago, United States',
    'Houston, United States',
    'San Francisco, United States',
    'Toronto, Canada',
    'Vancouver, Canada',
    'Sydney, Australia',
    'Melbourne, Australia',
    'Singapore',
    'Bangkok, Thailand',
    'Kuala Lumpur, Malaysia',
    'Tokyo, Japan',
    'Osaka, Japan',
    'Seoul, South Korea',
    'Paris, France',
    'Berlin, Germany',
    'Munich, Germany',
    'Rome, Italy',
    'Milan, Italy',
    'Madrid, Spain',
    'Barcelona, Spain',
    'Amsterdam, Netherlands',
    'Zurich, Switzerland',
    'Geneva, Switzerland',
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
    _plasmaController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFB58E34),
              onPrimary: Colors.black,
              surface: Color(0xFF1E1430),
              onSurface: Color(0xFFE5D5F5),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      _dob = picked;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 6, minute: 0),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFB58E34),
              onPrimary: Colors.black,
              surface: Color(0xFF1E1430),
              onSurface: Color(0xFFE5D5F5),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      _tob = picked;
    });
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

    if (_step < 5) {
      setState(() {
        _step++;
        _submitError = null;
      });
      return;
    }

    final user = UserModel(
      name: _nameController.text.trim(),
      dob: _dob!,
      timeOfBirth: _tob!.format(context),
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
      context.go('/home');
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
    if (_step == 2) return _dob != null;
    if (_step == 3) return _tob != null;
    if (_step == 4) return _place.trim().isNotEmpty;
    if (_step == 5) return true;
    return false;
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
                            5,
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
      'WHEN WERE YOU BORN?',
      'AT WHAT HOUR?',
      'WHERE WERE YOU BORN?',
      'HOW SHOULD BHRIGU RESPOND?',
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
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickDate,
              child: _glassInput(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFFB58E34),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _dob == null
                              ? 'Select date of birth'
                              : '${_dob!.day} / ${_dob!.month} / ${_dob!.year}',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 22,
                            color: _dob == null
                                ? Colors.white30
                                : const Color(0xFFE5D5F5),
                            fontStyle: _dob == null
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );

      case 3:
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickTime,
              child: _glassInput(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Color(0xFFB58E34),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _tob == null
                              ? 'Select time of birth'
                              : _tob!.format(context),
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 22,
                            color: _tob == null
                                ? Colors.white30
                                : const Color(0xFFE5D5F5),
                            fontStyle: _tob == null
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
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
                'Time of birth determines your Ascendant (Lagna) — the exact point where the eastern horizon met the cosmos at your arrival.',
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

      case 4:
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

      case 5:
        return _buildLanguageStep(key: key);

      default:
        return SizedBox(key: key);
    }
  }

  Widget _buildLanguageStep({required Key key}) {
    return SingleChildScrollView(
      key: key,
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _languageOption(
            language: englishAiResponseLanguage,
            title: 'English',
            subtitle: 'Bhrigu replies in polished English.',
          ),
          const SizedBox(height: 14),
          _languageOption(
            language: hinglishAiResponseLanguage,
            title: 'Hinglish',
            subtitle: 'Bhrigu replies in natural Roman-script Hinglish.',
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
              'This only changes AI-generated readings and chat replies. The app interface stays in English.',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 18,
                color: const Color(0xFFC7A867).withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageOption({
    required String language,
    required String title,
    required String subtitle,
  }) {
    final selected = _aiResponseLanguage == language;

    return GestureDetector(
      onTap: () {
        setState(() {
          _aiResponseLanguage = normalizeAiResponseLanguage(language);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0812).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFB58E34) : const Color(0xFF3A2D50),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFB58E34).withValues(alpha: 0.16),
                    blurRadius: 18,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color:
                  selected ? const Color(0xFFB58E34) : const Color(0xFF6B6080),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cinzel(
                      fontSize: 16,
                      color: const Color(0xFFE5D5F5),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 17,
                      color: const Color(0xFFC7A867).withValues(alpha: 0.85),
                      height: 1.35,
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
