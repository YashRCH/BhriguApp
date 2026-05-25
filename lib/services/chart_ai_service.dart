import 'package:cloud_functions/cloud_functions.dart';

import '../constants/ai_response_language.dart';
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
    final aiResponseLanguage = normalizeAiResponseLanguage(
      data['aiResponseLanguage'],
    );

    try {
      if (await _session.currentUserOrWait() == null) {
        throw Exception('User not signed in');
      }

      final callable = _functions.httpsCallable(
        'generateCompatibilityInsight',
      );

      final response = await callable.call(
        {
          'westernChart': westernChart,
          'vedicChart': vedicChart,
          'aiResponseLanguage': aiResponseLanguage,
        },
      );

      final resultData = Map<String, dynamic>.from(
        response.data as Map,
      );

      final text = resultData['text'] as String;

      return text.trim();
    } catch (_) {
      if (aiResponseLanguage == hinglishAiResponseLanguage) {
        return 'Aapka chart intense emotional selectiveness aur steady, mature, spiritually grounded logon ki taraf attraction dikhata hai. Bond powerful ho sakta hai, lekin caution yeh hai ki trust earn hone se pehle depth expect mat kijiye.';
      }

      return 'Your chart shows intense emotional selectiveness and strong attraction to people who feel steady, mature, and spiritually grounded. The bond can become powerful, but the caution is expecting depth too quickly before trust has been earned.';
    }
  }
}
