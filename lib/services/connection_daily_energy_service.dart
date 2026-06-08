import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../constants/firebase_constants.dart';
import '../models/social_connection_model.dart';
import '../utils/date_keys.dart';

class ConnectionDailyEnergyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );

  Stream<ConnectionDailyEnergy?> watchToday(String connectionId) {
    // BUG-G FIXED: Use UTC so the date key matches the server-side doc ID.
    // formatDateKey(DateTime.now()) used local time, which diverges from the
    // server after midnight in timezones ahead of UTC (e.g. IST UTC+5:30).
    final dateKey = formatDateKey(DateTime.now().toUtc());

    return _firestore
        .collection('connections')
        .doc(connectionId)
        .collection('daily_energy')
        .doc(dateKey)
        .snapshots()
        .map(
          (doc) => doc.exists ? ConnectionDailyEnergy.fromFirestore(doc) : null,
        );
  }

  Future<void> generateToday(String connectionId) async {
    final callable = _functions.httpsCallable('generateConnectionDailyEnergy');
    // dateKey is intentionally omitted — the server always derives it
    // server-side to prevent client clock manipulation.
    await callable.call({'connectionId': connectionId});
  }
}
