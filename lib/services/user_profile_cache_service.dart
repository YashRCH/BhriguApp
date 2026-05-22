import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileCacheService {
  UserProfileCacheService._();

  static final UserProfileCacheService instance = UserProfileCacheService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _cachedUid;
  Map<String, dynamic>? _cachedData;
  Future<Map<String, dynamic>?>? _userDataInFlight;

  Future<Map<String, dynamic>?> userData({bool refresh = false}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    if (!refresh && _cachedUid == uid && _cachedData != null) {
      return _cachedData;
    }

    final inFlight = _userDataInFlight;
    if (!refresh && inFlight != null) {
      return inFlight;
    }

    final future = _db.collection('users').doc(uid).get().then((doc) {
      final data = doc.data();
      _cachedUid = uid;
      _cachedData = data == null ? null : Map<String, dynamic>.from(data);
      return _cachedData;
    }).whenComplete(() {
      _userDataInFlight = null;
    });

    _userDataInFlight = future;
    return future;
  }

  Future<Map<String, dynamic>?> userDataWithFreshCharts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    return userData();
  }

  void primeCurrentUser(Map<String, dynamic> data) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _cachedUid = uid;
    _cachedData = Map<String, dynamic>.from(data);
  }

  void clear() {
    _cachedUid = null;
    _cachedData = null;
    _userDataInFlight = null;
  }
}
