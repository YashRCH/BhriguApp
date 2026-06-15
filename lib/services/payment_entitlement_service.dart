import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/monetization_constants.dart';
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
    final entitlements =
        _firestore.collection('users').doc(uid).collection('entitlements');

    final plusDoc = await entitlements.doc(bhriguPlusEntitlementId).get();
    if (_isActiveEntitlement(plusDoc.data(), now: now)) {
      return true;
    }

    final doc = await entitlements.doc(feature.entitlementId).get();

    return _isActiveEntitlement(doc.data(), now: now);
  }

  bool _isActiveEntitlement(Map<String, dynamic>? data, {DateTime? now}) {
    if (data == null) return false;

    final active = data['active'] == true;

    if (!active) return false;

    final expiresAt = data['expiresAt'];

    if (expiresAt is Timestamp) {
      return expiresAt.toDate().isAfter(now ?? DateTime.now());
    }

    return true;
  }
}
