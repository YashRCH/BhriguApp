import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/ai_response_language.dart';
import '../constants/firebase_constants.dart';
import '../services/auth_service.dart';
import '../services/user_profile_cache_service.dart';
import '../utils/zodiac_signs.dart';
import '../widgets/zodiac_sign_icon.dart';
import 'cosmic_blueprint_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  bool _loading = true;
  bool _deletingAccount = false;
  bool _updatingLanguage = false;
  String _version = '';

  late final AnimationController _blueprintController;
  late final Animation<double> _blueprintPulse;
  late final Animation<double> _blueprintFloat;

  @override
  void initState() {
    super.initState();

    _blueprintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _blueprintPulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _blueprintController,
        curve: Curves.easeInOut,
      ),
    );

    _blueprintFloat = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(
        parent: _blueprintController,
        curve: Curves.easeInOut,
      ),
    );

    _loadData();
  }

  @override
  void dispose() {
    _blueprintController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final uid = await AuthService().getUserId();

      if (uid == null) {
        if (!mounted) return;

        setState(() {
          _userData = null;
          _loading = false;
        });
        return;
      }

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final info = await PackageInfo.fromPlatform();

      if (!mounted) return;

      setState(() {
        _userData = doc.data();
        _version = 'v${info.version}';
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('Profile data load failed: $e');
      debugPrintStack(stackTrace: stack);

      if (!mounted) return;

      setState(() {
        _userData = null;
        _loading = false;
      });
    }
  }

  String get _currentAiResponseLanguage {
    return normalizeAiResponseLanguage(_userData?['aiResponseLanguage']);
  }

  Future<void> _setAiResponseLanguage(String language) async {
    final normalized = normalizeAiResponseLanguage(language);
    if (_updatingLanguage || normalized == _currentAiResponseLanguage) return;

    setState(() {
      _updatingLanguage = true;
    });

    try {
      await UserProfileCacheService.instance.updateAiResponseLanguage(
        normalized,
      );

      if (!mounted) return;

      setState(() {
        _userData = {
          ...?_userData,
          'aiResponseLanguage': normalized,
        };
        _updatingLanguage = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _updatingLanguage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update response language: $e'),
          backgroundColor: const Color(0xFF1A1630),
        ),
      );
    }
  }

  String _formatDob(String? iso) {
    if (iso == null) return '—';

    final d = DateTime.tryParse(iso);

    if (d == null) return iso;

    return '${d.day} / ${d.month} / ${d.year}';
  }

  Future<void> _confirmDeleteAccount() async {
    if (_deletingAccount) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_deletingAccount,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151126),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Delete account?',
            style: TextStyle(
              color: Color(0xFFFFD88A),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This will permanently delete your profile, chat history, readings, rewards, and Firebase account. This action cannot be undone.',
            style: TextStyle(
              color: Color(0xFFB8AEE0),
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF8E83B5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    final uid = user?.uid;

    if (user == null || uid == null || uid.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No signed-in account found.'),
          backgroundColor: Color(0xFF1A1630),
        ),
      );

      return;
    }

    setState(() {
      _deletingAccount = true;
    });

    try {
      await _reauthenticateForDeletion(user);

      await auth.currentUser?.reload();
      final refreshedUser = auth.currentUser;
      if (refreshedUser == null || refreshedUser.uid != uid) {
        throw FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'Signed-in account changed during reauthentication.',
        );
      }
      await refreshedUser.getIdToken(true);

      final callable = FirebaseFunctions.instanceFor(
        region: firebaseFunctionsRegion,
      ).httpsCallable(
        'deleteAccount',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 540),
        ),
      );

      await callable.call();
      await AuthService().clearLocalSession(uid: uid);

      try {
        await GoogleSignIn().signOut();
      } catch (e) {
        debugPrint('Google sign-out after deletion skipped: $e');
      }

      try {
        await auth.signOut();
      } catch (e) {
        debugPrint('Firebase sign-out after deletion skipped: $e');
      }

      if (!mounted) return;

      context.go('/login');
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      setState(() {
        _deletingAccount = false;
      });

      debugPrint(
        'deleteAccount function failed: ${e.code} ${e.message} ${e.details}',
      );

      final message = _deleteAccountFunctionMessage(e);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF1A1630),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _deletingAccount = false;
      });

      final message = e.code == 'requires-recent-login'
          ? 'For security, please sign out and sign in again before deleting your account.'
          : e.code == 'operation-cancelled'
              ? 'Account deletion cancelled.'
              : 'Could not confirm your identity. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF1A1630),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _deletingAccount = false;
      });

      debugPrint('Account deletion failed before completion: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete account. Please try again.'),
          backgroundColor: Color(0xFF1A1630),
        ),
      );
    }
  }

  String _deleteAccountFunctionMessage(FirebaseFunctionsException e) {
    if (e.code == 'failed-precondition') {
      return 'For security, please sign in again before deleting your account.';
    }
    if (e.code == 'unauthenticated') {
      return 'Your session expired. Please sign in again before deleting your account.';
    }
    if (e.code == 'not-found') {
      return 'Delete account service is not deployed yet. Deploy functions, then try again.';
    }
    if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
      return 'Could not reach delete account service. Check your connection and try again.';
    }
    return 'Could not delete account. Please try again.';
  }

  Future<void> _reauthenticateForDeletion(User user) async {
    final providers = user.providerData.map((info) => info.providerId).toSet();

    if (providers.contains(EmailAuthProvider.PROVIDER_ID)) {
      await _reauthenticateWithPassword(user);
      return;
    }

    if (providers.contains(GoogleAuthProvider.PROVIDER_ID)) {
      await _reauthenticateWithGoogle(user);
      return;
    }

    throw FirebaseAuthException(
      code: 'requires-recent-login',
      message: 'No supported sign-in provider found for reauthentication.',
    );
  }

  Future<void> _reauthenticateWithPassword(User user) async {
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'Email is required to confirm this account.',
      );
    }

    final password = await _promptForPassword();
    if (password == null) {
      throw FirebaseAuthException(
        code: 'operation-cancelled',
        message: 'Account deletion cancelled.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  Future<void> _reauthenticateWithGoogle(User user) async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'operation-cancelled',
        message: 'Account deletion cancelled.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await user.reauthenticateWithCredential(credential);
  }

  Future<String?> _promptForPassword() async {
    final controller = TextEditingController();

    try {
      return showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF151126),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Confirm password',
              style: TextStyle(
                color: Color(0xFFFFD88A),
                fontWeight: FontWeight.w900,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              style: const TextStyle(color: Color(0xFFE5D5F5)),
              decoration: const InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(color: Color(0xFF6B6080)),
              ),
              onSubmitted: (_) {
                final password = controller.text.trim();
                if (password.isNotEmpty) Navigator.pop(ctx, password);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF8E83B5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final password = controller.text.trim();
                  if (password.isNotEmpty) Navigator.pop(ctx, password);
                },
                child: const Text(
                  'Confirm',
                  style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0D0B1E),
      appBar: AppBar(
        title: const Text(
          'PROFILE',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            color: Color(0xFFE5D5F5),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFE5D5F5),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.45),
            radius: 1.45,
            colors: [
              Color(0xFF1E1430),
              Color(0xFF0F0A18),
              Color(0xFF050408),
            ],
            stops: [0.0, 0.58, 1.0],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFB58E34),
                  ),
                )
              : _userData == null
                  ? const Center(
                      child: Text(
                        'No data found',
                        style: TextStyle(color: Color(0xFFE5D5F5)),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          _profileHeader(),
                          const SizedBox(height: 28),
                          _sectionLabel('BIRTH DETAILS'),
                          const SizedBox(height: 12),
                          _infoCard(
                            Icons.cake_outlined,
                            'Date of Birth',
                            _formatDob(_userData!['dob']),
                          ),
                          const SizedBox(height: 12),
                          _infoCard(
                            Icons.access_time,
                            'Time of Birth',
                            _userData!['timeOfBirth'] ?? '—',
                          ),
                          const SizedBox(height: 12),
                          _infoCard(
                            Icons.location_on_outlined,
                            'Place of Birth',
                            _userData!['placeOfBirth'] ?? '—',
                          ),
                          const SizedBox(height: 28),
                          _sectionLabel('YOUR COSMIC MAP'),
                          const SizedBox(height: 12),
                          _cosmicBlueprintCard(),
                          const SizedBox(height: 28),
                          _sectionLabel('PLAN'),
                          const SizedBox(height: 12),
                          _planCard(),
                          const SizedBox(height: 28),
                          _sectionLabel('AI RESPONSE'),
                          const SizedBox(height: 12),
                          _languageCard(),
                          const SizedBox(height: 14),
                          TextButton.icon(
                            onPressed: _deletingAccount
                                ? null
                                : () async {
                                    await AuthService().signOut();

                                    if (context.mounted) {
                                      context.go('/login');
                                    }
                                  },
                            icon: const Icon(
                              Icons.logout,
                              color: Color(0xFF6B6080),
                              size: 18,
                            ),
                            label: const Text(
                              'Sign out',
                              style: TextStyle(
                                color: Color(0xFF6B6080),
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Text(
                            _version,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B6080),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _deleteAccountButton(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _profileHeader() {
    final sunSign = zodiacSignNameFromIso(_userData!['dob']?.toString());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0812).withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF3A2D50).withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFF2E2650),
                  Color(0xFF1A1630),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFB58E34),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB58E34).withValues(alpha: 0.18),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.person_outline,
              size: 42,
              color: Color(0xFFB58E34),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _userData!['name'] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE5D5F5),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF151126),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isKnownZodiacSign(sunSign)) ...[
                  ZodiacSignIcon(
                    sign: sunSign,
                    size: 24,
                    fallbackColor: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  sunSign,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFF59E0B),
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF6B6080),
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _cosmicBlueprintCard() {
    return AnimatedBuilder(
      animation: _blueprintController,
      builder: (context, child) {
        final glow = 0.14 + (_blueprintPulse.value * 0.18);

        return Transform.translate(
          offset: Offset(0, _blueprintFloat.value),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CosmicBlueprintScreen(),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFB58E34).withValues(alpha: 0.55),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2E1065),
                    Color(0xFF1A1630),
                    Color(0xFF0F0A18),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB58E34).withValues(alpha: glow),
                    blurRadius: 28 + (_blueprintPulse.value * 12),
                    spreadRadius: 1 + (_blueprintPulse.value * 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0F0A18).withValues(alpha: 0.6),
                      border: Border.all(
                        color: const Color(0xFFB58E34).withValues(alpha: 0.55),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9D6FE8)
                              .withValues(alpha: 0.18 + glow),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          angle: _blueprintPulse.value * 0.8,
                          child: const Text(
                            '✦',
                            style: TextStyle(
                              fontSize: 28,
                              color: Color(0xFFB58E34),
                            ),
                          ),
                        ),
                        Transform.rotate(
                          angle: -_blueprintPulse.value * 0.6,
                          child: Text(
                            '◌',
                            style: TextStyle(
                              fontSize: 44,
                              color: const Color(0xFFE5D5F5)
                                  .withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cosmic Blueprint',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE5D5F5),
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Western • Vedic • Compatibility',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFC7A867),
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Open your complete birth map',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B6080),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF151126),
                      border: Border.all(
                        color: const Color(0xFFB58E34).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFFB58E34),
                      size: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _planCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3A2D50),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1630),
            Color(0xFF151126),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free Tier',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE5D5F5),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '5 messages / day',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6080),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB58E34),
              foregroundColor: const Color(0xFF050408),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Upgrade',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3A2D50),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1630),
            Color(0xFF151126),
          ],
        ),
      ),
      child: Column(
        children: [
          _languageRow(
            language: englishAiResponseLanguage,
            title: 'English',
            subtitle: 'AI readings and chat replies stay in English.',
          ),
          const SizedBox(height: 10),
          _languageRow(
            language: hinglishAiResponseLanguage,
            title: 'Hinglish',
            subtitle: 'AI replies use natural Roman-script Hinglish.',
          ),
        ],
      ),
    );
  }

  Widget _languageRow({
    required String language,
    required String title,
    required String subtitle,
  }) {
    final selected = _currentAiResponseLanguage == language;

    return InkWell(
      onTap: _updatingLanguage ? null : () => _setAiResponseLanguage(language),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0F0A18).withValues(alpha: 0.72)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFB58E34).withValues(alpha: 0.45)
                : const Color(0xFF2E2650),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color:
                  selected ? const Color(0xFFB58E34) : const Color(0xFF6B6080),
              size: 21,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE5D5F5),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B6080),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (_updatingLanguage && selected)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFB58E34),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _deleteAccountButton() {
    return GestureDetector(
      onTap: _deletingAccount ? null : _confirmDeleteAccount,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF12080D).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.35),
          ),
        ),
        child: Center(
          child: _deletingAccount
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF6B6B),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_forever_outlined,
                      color: Color(0xFFFF6B6B),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Delete Account',
                      style: TextStyle(
                        color: Color(0xFFFF6B6B),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _infoCard(
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1630).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF2E2650),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0A18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFB58E34).withValues(alpha: 0.25),
              ),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFB58E34),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B6080),
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFFE5D5F5),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
