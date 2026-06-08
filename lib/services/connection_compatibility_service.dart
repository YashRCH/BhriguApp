import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../constants/firebase_constants.dart';
import '../models/social_connection_model.dart';

class ConnectionCompatibilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );

  Stream<List<ConnectionCompatibilityReading>> watchReadings(
    String connectionId,
  ) {
    return _firestore
        .collection('connections')
        .doc(connectionId)
        .collection('compatibility')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(ConnectionCompatibilityReading.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<ConnectionCompatibilityReading> generateCompatibility({
    required String connectionId,
    String? heartSignal,
  }) async {
    final callable =
        _functions.httpsCallable('generateConnectionCompatibility');
    final result = await callable.call({
      'connectionId': connectionId,
      if (heartSignal != null) 'heartSignal': heartSignal,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final readingId = data['readingId'] as String? ?? '';
    final doc = await _firestore
        .collection('connections')
        .doc(connectionId)
        .collection('compatibility')
        .doc(readingId)
        .get();

    return ConnectionCompatibilityReading.fromFirestore(doc);
  }
}
