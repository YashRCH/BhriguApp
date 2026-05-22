import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FirebaseSessionService {
  final FirebaseAuth _auth;
  final FlutterSecureStorage _storage;
  final String debugLabel;

  FirebaseSessionService({
    required this.debugLabel,
    FirebaseAuth? auth,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage;

  User? get currentUser => _auth.currentUser;

  Future<String?> userId() async {
    final authUid = _auth.currentUser?.uid;

    if (authUid != null && authUid.isNotEmpty) {
      return authUid;
    }

    final storedUid = await _storage.read(key: 'user_id');

    if (storedUid != null && storedUid.isNotEmpty) {
      return storedUid;
    }

    return null;
  }

  Future<String?> idToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;

    if (user == null) {
      debugPrint('$debugLabel error: FirebaseAuth.currentUser is null');
      return null;
    }

    final token = await user.getIdToken(forceRefresh);

    if (token == null || token.isEmpty) {
      debugPrint('$debugLabel error: Firebase ID token is empty');
      return null;
    }

    return token;
  }
}
