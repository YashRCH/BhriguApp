import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';
import 'astrology_service.dart';
import 'user_profile_cache_service.dart';

class AuthService {
  static const _currentChartCalculationVersion =
      'nasa_jpl_horizons_v5_observer_ecliptic_nodes';

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = const FlutterSecureStorage();
  final _googleSignIn = GoogleSignIn();

  final _astrologyService = AstrologyService();
  static final Map<String, bool> _onboardingCache = {};
  static final Map<String, Future<bool>> _onboardingInFlight = {};

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> getUserId() async {
    return _auth.currentUser?.uid;
  }

  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    try {
      await cred.user?.sendEmailVerification();
    } catch (e) {
      debugPrint('Verification email request failed: $e');
      await signOut();
      rethrow;
    }
    unawaited(_storage.delete(key: 'user_id'));

    return cred;
  }

  Future<UserCredential> signInWithEmail(
    String email,
    String password,
  ) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    await cred.user?.reload();
    final user = _auth.currentUser ?? cred.user;

    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
      } catch (e) {
        debugPrint('Verification email resend skipped: $e');
      }
      await signOut();
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Please verify your email before signing in.',
      );
    }

    unawaited(_storage.delete(key: 'user_id'));

    _generateChartsAfterLogin(cred.user!.uid);

    return cred;
  }

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();

    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(
      credential,
    );

    unawaited(_storage.delete(key: 'user_id'));

    _generateChartsAfterLogin(cred.user!.uid);

    return cred;
  }

  Future<void> saveUserData(UserModel user) async {
    final uid = _auth.currentUser?.uid;

    if (uid == null) return;

    unawaited(_storage.delete(key: 'user_id'));

    await _db.collection('users').doc(uid).set(
          user.toMap(),
        );

    UserProfileCacheService.instance.primeCurrentUser(user.toMap());
    _onboardingCache[uid] = true;
    unawaited(_storage.write(
      key: _onboardingStorageKey(uid),
      value: 'true',
    ));

    await _astrologyService.generateAndSaveCharts(
      uid: uid,
      birthDate: user.dob,
      timeOfBirth: user.timeOfBirth,
      placeOfBirth: user.placeOfBirth,
      latitude: user.latitude,
      longitude: user.longitude,
    );

    final refreshedDoc = await _db.collection('users').doc(uid).get();
    final refreshedData = refreshedDoc.data();

    if (refreshedData != null) {
      UserProfileCacheService.instance.primeCurrentUser(refreshedData);
    }
  }

  Future<void> _generateChartsIfMissing(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();

      if (data == null || !_shouldGenerateCharts(data)) return;

      final dob = DateTime.tryParse(data['dob']?.toString() ?? '');

      if (dob == null) return;

      await _astrologyService.generateAndSaveCharts(
        uid: uid,
        birthDate: dob,
        timeOfBirth: data['timeOfBirth']?.toString() ?? '',
        placeOfBirth: data['placeOfBirth']?.toString() ?? '',
        latitude: _doubleOrNull(data['latitude']),
        longitude: _doubleOrNull(data['longitude']),
      );

      final refreshedDoc = await _db.collection('users').doc(uid).get();
      final refreshedData = refreshedDoc.data();

      if (refreshedData != null) {
        UserProfileCacheService.instance.primeCurrentUser(refreshedData);
      }
    } catch (e) {
      debugPrint('Login chart generation skipped: $e');
    }
  }

  void _generateChartsAfterLogin(String uid) {
    unawaited(
      _generateChartsIfMissing(uid).catchError((Object e) {
        debugPrint('Login chart generation background task failed: $e');
      }),
    );
  }

  bool _shouldGenerateCharts(Map<String, dynamic> data) {
    final hasCharts =
        data['westernChart'] != null && data['vedicChart'] != null;
    final generatedBy = data['chartGeneratedBy']?.toString();
    final calculationVersion = data['chartCalculationVersion']?.toString();

    return !hasCharts ||
        generatedBy == 'local_ephemeris_engine' ||
        (generatedBy == 'nasa_jpl_horizons' &&
            calculationVersion != _currentChartCalculationVersion);
  }

  double? _doubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<bool> hasCompletedOnboarding({bool refresh = false}) async {
    final uid = _auth.currentUser?.uid;

    if (uid == null) return false;

    if (!refresh && _onboardingCache.containsKey(uid)) {
      return _onboardingCache[uid]!;
    }

    if (!refresh) {
      final cachedCompletion = await _storage.read(
        key: _onboardingStorageKey(uid),
      );

      if (cachedCompletion == 'true') {
        _onboardingCache[uid] = true;
        unawaited(
          _refreshOnboardingCompletion(uid).catchError((Object _) => true),
        );
        return true;
      }
    }

    final inFlight = _onboardingInFlight[uid];
    if (!refresh && inFlight != null) return inFlight;

    final future = _refreshOnboardingCompletion(uid).whenComplete(() {
      _onboardingInFlight.remove(uid);
    });

    _onboardingInFlight[uid] = future;
    return future;
  }

  Future<bool> _refreshOnboardingCompletion(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    final completed = doc.exists;

    _onboardingCache[uid] = completed;

    if (data != null) {
      UserProfileCacheService.instance.primeCurrentUser(data);
    }

    if (completed) {
      unawaited(_storage.write(
        key: _onboardingStorageKey(uid),
        value: 'true',
      ));
    } else {
      unawaited(_storage.delete(
        key: _onboardingStorageKey(uid),
      ));
    }

    return completed;
  }

  String _onboardingStorageKey(String uid) {
    return 'onboarding_completed_$uid';
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> clearLocalSession({String? uid}) async {
    await _storage.delete(
      key: 'user_id',
    );

    if (uid != null) {
      await _storage.delete(
        key: _onboardingStorageKey(uid),
      );
      _onboardingCache.remove(uid);
      _onboardingInFlight.remove(uid);
    } else {
      _onboardingCache.clear();
      _onboardingInFlight.clear();
    }

    UserProfileCacheService.instance.clear();
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;

    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google sign-out skipped: $e');
    }

    await _auth.signOut();

    await clearLocalSession(uid: uid);
  }
}
