import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../constants/app_messages.dart';
import '../constants/firebase_constants.dart';
import 'firebase_session_service.dart';
import 'user_profile_cache_service.dart';

class ChartAiService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );

  final FirebaseSessionService _session =
      FirebaseSessionService(debugLabel: 'Chart AI');

  Future<String> generateCompatibilityInsight(String uid) async {
    final data =
        await UserProfileCacheService.instance.userDataWithFreshCharts();

    if (data == null) {
      return 'Your compatibility signature is still forming.';
    }

    final westernChart = data['westernChart'];
    final vedicChart = data['vedicChart'];

    try {
      final idToken = await _session.idToken();

      if (idToken == null) {
        throw Exception(missingFirebaseIdTokenMessage);
      }

      final callable = _functions.httpsCallable(
        'generateCompatibilityInsight',
      );

      final response = await callable.call(
        {
          'idToken': idToken,
          'westernChart': westernChart,
          'vedicChart': vedicChart,
        },
      );

      final resultData = Map<String, dynamic>.from(
        response.data as Map,
      );

      final text = resultData['text'] as String;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'compatibilityAiInsight': text.trim(),
        'compatibilityAiGeneratedAt': FieldValue.serverTimestamp(),
      });

      return text.trim();
    } catch (_) {
      return 'Your chart shows intense emotional selectiveness and strong attraction to people who feel steady, mature, and spiritually grounded. The bond can become powerful, but the caution is expecting depth too quickly before trust has been earned.';
    }
  }
}
