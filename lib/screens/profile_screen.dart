import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/auth_service.dart';
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
    final uid = await AuthService().getUserId();

    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final info = await PackageInfo.fromPlatform();

    if (mounted) {
      setState(() {
        _userData = doc.data();
        _version = 'v${info.version}';
        _loading = false;
      });
    }
  }

  String _sunSign(String? isoDate) {
    if (isoDate == null) return '—';

    final d = DateTime.tryParse(isoDate);

    if (d == null) return '—';

    final m = d.month;
    final day = d.day;

    if ((m == 3 && day >= 21) || (m == 4 && day <= 19)) {
      return 'Aries ♈';
    }

    if ((m == 4 && day >= 20) || (m == 5 && day <= 20)) {
      return 'Taurus ♉';
    }

    if ((m == 5 && day >= 21) || (m == 6 && day <= 20)) {
      return 'Gemini ♊';
    }

    if ((m == 6 && day >= 21) || (m == 7 && day <= 22)) {
      return 'Cancer ♋';
    }

    if ((m == 7 && day >= 23) || (m == 8 && day <= 22)) {
      return 'Leo ♌';
    }

    if ((m == 8 && day >= 23) || (m == 9 && day <= 22)) {
      return 'Virgo ♍';
    }

    if ((m == 9 && day >= 23) || (m == 10 && day <= 22)) {
      return 'Libra ♎';
    }

    if ((m == 10 && day >= 23) || (m == 11 && day <= 21)) {
      return 'Scorpio ♏';
    }

    if ((m == 11 && day >= 22) || (m == 12 && day <= 21)) {
      return 'Sagittarius ♐';
    }

    if ((m == 12 && day >= 22) || (m == 1 && day <= 19)) {
      return 'Capricorn ♑';
    }

    if ((m == 1 && day >= 20) || (m == 2 && day <= 18)) {
      return 'Aquarius ♒';
    }

    return 'Pisces ♓';
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
      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('users').doc(uid);

      await _deleteCollection(userRef.collection('chat'));
      await _deleteCollection(userRef.collection('follow_up_contexts'));
      await _deleteCollection(userRef.collection('partner_matches'));
      await _deleteCollection(userRef.collection('rewards'));
      await _deleteCollection(userRef.collection('horoscopes'));

      await userRef.delete();
      await user.delete();

      if (!mounted) return;

      context.go('/login');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _deletingAccount = false;
      });

      final message = e.code == 'requires-recent-login'
          ? 'For security, please sign out and sign in again before deleting your account.'
          : 'Could not delete account: ${e.message ?? e.code}';

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete account: $e'),
          backgroundColor: const Color(0xFF1A1630),
        ),
      );
    }
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    const batchSize = 100;

    while (true) {
      final snapshot = await collection.limit(batchSize).get();

      if (snapshot.docs.isEmpty) break;

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (snapshot.docs.length < batchSize) break;
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
            child: Text(
              _sunSign(_userData!['dob']),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFF59E0B),
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
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