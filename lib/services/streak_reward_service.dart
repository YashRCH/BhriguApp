import 'package:cloud_functions/cloud_functions.dart';

import '../constants/firebase_constants.dart';
import '../models/streak_reward_model.dart';

class StreakRewardService {
  final FirebaseFunctions _functions;

  StreakRewardService({
    FirebaseFunctions? functions,
  }) : _functions = functions ??
            FirebaseFunctions.instanceFor(
              region: firebaseFunctionsRegion,
            );

  Future<StreakRewardState> load(String uid) async {
    final response = await _functions.httpsCallable('loadStreakReward').call();
    final data = Map<String, dynamic>.from(response.data as Map);

    return StreakRewardState.fromMap(data);
  }

  Future<StreakRewardClaim> claimDaily({
    required String uid,
    DateTime? now,
  }) async {
    final response =
        await _functions.httpsCallable('claimDailyStreakReward').call();
    final data = Map<String, dynamic>.from(response.data as Map);
    final state = StreakRewardState.fromMap(
      Map<String, dynamic>.from(data['state'] as Map),
    );

    return StreakRewardClaim(
      state: state,
      unlockedReward: data['unlockedReward'] == true,
      carriedPendingReward: data['carriedPendingReward'] == true,
    );
  }

  Future<void> consumeFreeReward(String uid) async {
    await _functions.httpsCallable('consumeFreeReward').call();
  }
}
