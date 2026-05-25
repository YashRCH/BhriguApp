import 'package:firebase_auth/firebase_auth.dart';

class FirebaseSessionService {
  final FirebaseAuth _auth;
  final String debugLabel;

  FirebaseSessionService({
    required this.debugLabel,
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<User?> currentUserOrWait({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final existing = _auth.currentUser;

    if (existing != null) return existing;

    try {
      return await _auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(timeout);
    } catch (_) {
      return _auth.currentUser;
    }
  }

  Future<String?> userId() async {
    final authUid = (await currentUserOrWait())?.uid;

    if (authUid != null && authUid.isNotEmpty) {
      return authUid;
    }

    return null;
  }
}
