import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/firebase_constants.dart';

class CircleSafetyService {
  static const policyVersion = 'circle_safety_v1';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CircleSafetyService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: firebaseFunctionsRegion);

  Future<bool> hasAcceptedCurrentPolicy() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;

    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return false;

    return data['circleSafetyPolicyVersion'] == policyVersion;
  }

  Future<void> acceptCurrentPolicy() async {
    final callable = _functions.httpsCallable('acceptCircleSafetyPolicy');
    await callable.call({'version': policyVersion});
  }
}
