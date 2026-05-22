import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/streak_reward_model.dart';
import '../utils/date_keys.dart';

class StreakRewardService {
  final FirebaseFirestore _firestore;

  StreakRewardService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _rewardRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('rewards')
        .doc('streak_calendar');
  }

  Future<StreakRewardState> load(String uid) async {
    final doc = await _rewardRef(uid).get();

    if (!doc.exists) {
      return const StreakRewardState.empty();
    }

    return StreakRewardState.fromMap(doc.data() ?? {});
  }

  Future<StreakRewardClaim> claimDaily({
    required String uid,
    DateTime? now,
  }) async {
    final today = formatDateKey(now ?? DateTime.now());
    final ref = _rewardRef(uid);
    final doc = await ref.get();
    final data = doc.data() ?? {};

    final oldStreakCount = data['streakCount'] as int? ?? 0;
    final oldCycleDay = data['rewardCycleDay'] as int? ?? 0;
    final oldLastClaimDate = data['lastClaimDate'] as String?;
    final hasPendingReward = data['freeRewardAvailable'] == true;

    int newStreakCount = oldStreakCount;
    int newCycleDay = oldCycleDay;

    if (oldLastClaimDate != today) {
      newStreakCount = oldStreakCount + 1;

      if (!hasPendingReward) {
        newCycleDay = oldCycleDay + 1;
      }
    }

    final shouldUnlockReward = !hasPendingReward && newCycleDay >= 4;
    final rewardType = shouldUnlockReward
        ? (newStreakCount % 8 == 0 ? geomancyRewardType : tarotRewardType)
        : data['freeRewardType'] as String?;

    final updatedCycleDay = shouldUnlockReward ? 0 : newCycleDay;
    final updatedDaysUntilReward =
        shouldUnlockReward || hasPendingReward ? 0 : 4 - updatedCycleDay;

    await ref.set(
      {
        'streakCount': newStreakCount,
        'rewardCycleDay': updatedCycleDay,
        'daysUntilReward': updatedDaysUntilReward,
        'lastClaimDate': today,
        'freeRewardAvailable': shouldUnlockReward || hasPendingReward,
        'freeRewardType': rewardType,
        'updatedAt': FieldValue.serverTimestamp(),
        if (shouldUnlockReward) 'unlockedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return StreakRewardClaim(
      state: StreakRewardState(
        rewardCycleDay: updatedCycleDay,
        freeRewardAvailable: shouldUnlockReward || hasPendingReward,
        freeRewardType: rewardType,
        lastClaimDate: today,
      ),
      unlockedReward: shouldUnlockReward,
      carriedPendingReward: hasPendingReward,
    );
  }

  Future<void> consumeFreeReward(String uid) async {
    await _rewardRef(uid).set(
      {
        'freeRewardAvailable': false,
        'freeRewardType': null,
        'rewardCycleDay': 0,
        'daysUntilReward': 4,
        'openedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
