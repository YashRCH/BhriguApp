import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../constants/monetization_constants.dart';

class RevenueCatService {
  RevenueCatService._();

  static final RevenueCatService instance = RevenueCatService._();
  static const _configureTimeout = Duration(seconds: 8);

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _configured = false;
  Future<void>? _configureFuture;
  String? _identifiedUid;

  bool get isConfigured => _configured;

  Future<void> configure() async {
    if (_configured) return;

    _configureFuture ??= _configure();

    try {
      await _configureFuture;
    } finally {
      if (!_configured) {
        _configureFuture = null;
      }
    }
  }

  Future<void> _configure() async {
    if (kIsWeb) return;

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    final apiKey = _apiKeyForPlatform();
    if (apiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'RevenueCat skipped: pass --dart-define=REVENUECAT_ANDROID_API_KEY=... '
          'for Android billing builds.',
        );
      }
      return;
    }

    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    }

    final configuration = PurchasesConfiguration(apiKey);
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      configuration.appUserID = uid;
      _identifiedUid = uid;
    }

    await Purchases.configure(configuration).timeout(_configureTimeout);
    _configured = true;
  }

  Future<void> identifyCurrentUser() async {
    try {
      await configure();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RevenueCat identify skipped: $e');
      }
      return;
    }

    if (!_configured) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || uid == _identifiedUid) return;

    try {
      await Purchases.logIn(uid);
      _identifiedUid = uid;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RevenueCat login skipped: $e');
      }
    }
  }

  Future<void> logOut() async {
    if (!_configured) return;

    try {
      await Purchases.logOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RevenueCat logout skipped: $e');
      }
    } finally {
      _identifiedUid = null;
    }
  }

  Future<Offerings?> getOfferings() async {
    await configure();
    if (!_configured) return null;
    await identifyCurrentUser();

    return Purchases.getOfferings();
  }

  Future<CustomerInfo?> restorePurchases() async {
    await configure();
    if (!_configured) return null;
    await identifyCurrentUser();

    return Purchases.restorePurchases();
  }

  Future<CustomerInfo?> getCustomerInfo() async {
    await configure();
    if (!_configured) return null;
    await identifyCurrentUser();

    return Purchases.getCustomerInfo();
  }

  Future<CustomerInfo?> purchasePackage(Package package) async {
    await configure();
    if (!_configured) return null;
    await identifyCurrentUser();

    return Purchases.purchasePackage(package);
  }

  String _apiKeyForPlatform() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return revenueCatAndroidApiKey;
    }

    return '';
  }
}
