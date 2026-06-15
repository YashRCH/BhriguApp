import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/ai_response_language.dart';
import '../constants/firebase_constants.dart';
import '../services/auth_service.dart';
import '../services/monetization_service.dart';
import '../services/user_profile_cache_service.dart';
import '../utils/zodiac_signs.dart';
import '../widgets/monetization_paywall_preview.dart';
import '../widgets/zodiac_sign_icon.dart';
import 'cosmic_blueprint_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _monetizationService = MonetizationService();
  Map<String, dynamic>? _userData;
  bool _loading = true;
  bool _deletingAccount = false;
  bool _updatingLanguage = false;
  bool _languageExpanded = false;
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

  String _profileUsername() {
    final username = _userData?['username']?.toString().trim();
    if (username != null && username.isNotEmpty) {
      return username.replaceFirst(RegExp(r'^@+'), '');
    }

    final usernameLower = _userData?['usernameLower']?.toString().trim();
    if (usernameLower != null && usernameLower.isNotEmpty) {
      return usernameLower.replaceFirst(RegExp(r'^@+'), '');
    }

    return '';
  }

  Future<void> _copyUsername() async {
    final username = _profileUsername();
    if (username.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: '@$username'));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Username copied.'),
        backgroundColor: Color(0xFF1A1630),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    if (_deletingAccount) return;

    final confirmed = await _promptForDeleteConfirmation();
    if (!confirmed) return;

    await _deleteAccount();
  }

  Future<bool> _promptForDeleteConfirmation() async {
    final controller = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final canDelete =
                  controller.text.trim().toLowerCase() == 'confirm';

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
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This will permanently delete your profile, chat history, readings, rewards, and Firebase account. This action cannot be undone.',
                      style: TextStyle(
                        color: Color(0xFFB8AEE0),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Type confirm to continue.',
                      style: TextStyle(
                        color: Color(0xFFE5D5F5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Color(0xFFE5D5F5)),
                      decoration: const InputDecoration(
                        hintText: 'confirm',
                        hintStyle: TextStyle(color: Color(0xFF6B6080)),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      onSubmitted: (_) {
                        if (!canDelete) return;
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.pop(ctx, true);
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(ctx, false);
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF8E83B5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: canDelete
                        ? () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.pop(ctx, true);
                          }
                        : null,
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: canDelete
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF6B6080),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      // Wait for the confirmation dialog to fully animate out
      // before proceeding, to prevent OverlayEntry widget tree crashes.
      await Future.delayed(const Duration(milliseconds: 300));

      return confirmed == true;
    } finally {
      controller.dispose();
    }
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

      await callable.call({'confirmation': 'confirm'});
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
              : 'Your session could not be verified. Please sign in again and try deleting your account.';

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
      return 'For security, please sign out and sign in again before deleting your account.';
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
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
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
                          _sectionLabel('LEGAL'),
                          const SizedBox(height: 12),
                          _legalCard(),
                          const SizedBox(height: 18),
                          _languageCard(),
                          const SizedBox(height: 14),
                          TextButton.icon(
                            onPressed: _deletingAccount
                                ? null
                                : () async {
                                    await AuthService().signOut();
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
    final username = _profileUsername();

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
          _usernamePill(username),
          const SizedBox(height: 10),
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

  Widget _usernamePill(String username) {
    final hasUsername = username.isNotEmpty;

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.only(left: 14, right: 6, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF151126).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF6B6080).withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.alternate_email,
            size: 16,
            color:
                hasUsername ? const Color(0xFFC7A867) : const Color(0xFF6B6080),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              hasUsername ? '@$username' : 'No username set',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: hasUsername
                    ? const Color(0xFFE5D5F5)
                    : const Color(0xFF8E83B5),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Copy username',
            onPressed: hasUsername ? _copyUsername : null,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
              minWidth: 34,
              minHeight: 34,
            ),
            icon: Icon(
              Icons.copy_rounded,
              size: 16,
              color: hasUsername
                  ? const Color(0xFFB58E34)
                  : const Color(0xFF6B6080),
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
    return MonetizationPaywallPreview(
      service: _monetizationService,
    );
  }

  Widget _languageCard() {
    final currentLanguageLabel =
        aiResponseLanguageLabel(_currentAiResponseLanguage);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _languageExpanded = !_languageExpanded;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF120F22).withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF3A2D50).withValues(
                alpha: _languageExpanded ? 0.9 : 0.48,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0A18).withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: const Color(0xFF3A2D50).withValues(alpha: 0.55),
                      ),
                    ),
                    child: const Icon(
                      Icons.translate_rounded,
                      color: Color(0xFFB58E34),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Language',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD8C9EA),
                      ),
                    ),
                  ),
                  Text(
                    currentLanguageLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E83A8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _languageExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF6B6080),
                      size: 20,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Column(
                    children: [
                      _languageRow(
                        language: englishAiResponseLanguage,
                        title: 'English',
                        subtitle:
                            'AI readings and chat replies stay in English.',
                      ),
                      const SizedBox(height: 8),
                      _languageRow(
                        language: hinglishAiResponseLanguage,
                        title: 'Experimental Hinglish',
                        subtitle:
                            'AI replies use natural Roman-script Hinglish.',
                      ),
                    ],
                  ),
                ),
                crossFadeState: _languageExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
                firstCurve: Curves.easeOutCubic,
                secondCurve: Curves.easeOutCubic,
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legalCard() {
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
          _legalRow(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () async {
              final url = Uri.parse(
                  'https://astrology-guru-app.firebaseapp.com/privacy.html?v=1');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.inAppBrowserView);
              }
            },
          ),
          const SizedBox(height: 16),
          _legalRow(
            icon: Icons.gavel_rounded,
            title: 'Terms of Service & Disclaimer',
            onTap: () async {
              final url = Uri.parse(
                  'https://astrology-guru-app.firebaseapp.com/terms.html?v=1');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.inAppBrowserView);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _legalRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFB58E34),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5D5F5),
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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
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
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE5D5F5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
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
