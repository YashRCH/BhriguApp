import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_feature.dart';

class PaymentEntitlementService {
  final FirebaseFirestore _firestore;

  PaymentEntitlementService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<bool> hasActiveEntitlement({
    required String uid,
    required PaymentFeature feature,
    DateTime? now,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('entitlements')
        .doc(feature.entitlementId)
        .get();

    if (!doc.exists) return false;

    final data = doc.data() ?? {};
    final active = data['active'] == true;

    if (!active) return false;

    final expiresAt = data['expiresAt'];

    if (expiresAt is Timestamp) {
      return expiresAt.toDate().isAfter(now ?? DateTime.now());
    }

    return true;
  }
}
