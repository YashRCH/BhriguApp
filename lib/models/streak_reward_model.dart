import '../utils/date_keys.dart';

const tarotRewardType = 'tarot';
const geomancyRewardType = 'geomancy';

class StreakRewardState {
  final int rewardCycleDay;
  final bool freeRewardAvailable;
  final String? freeRewardType;
  final String? lastClaimDate;

  const StreakRewardState({
    required this.rewardCycleDay,
    required this.freeRewardAvailable,
    required this.freeRewardType,
    required this.lastClaimDate,
  });

  const StreakRewardState.empty()
      : rewardCycleDay = 0,
        freeRewardAvailable = false,
        freeRewardType = null,
        lastClaimDate = null;

  factory StreakRewardState.fromMap(Map<String, dynamic> data) {
    return StreakRewardState(
      rewardCycleDay: _intFromValue(data['rewardCycleDay']),
      freeRewardAvailable: data['freeRewardAvailable'] == true,
      freeRewardType: data['freeRewardType'] as String?,
      lastClaimDate: data['lastClaimDate'] as String?,
    );
  }

  bool isClaimedOn(DateTime date) {
    return lastClaimDate == formatDateKey(date);
  }

  double get roadProgress {
    if (freeRewardAvailable) return 1.0;

    final progress = rewardCycleDay.clamp(0, 4).toDouble() / 4.0;
    return progress.clamp(0.0, 1.0).toDouble();
  }

  String get rewardRoute {
    return freeRewardType == geomancyRewardType ? '/geomancy' : '/tarot';
  }
}

class StreakRewardClaim {
  final StreakRewardState state;
  final bool unlockedReward;
  final bool carriedPendingReward;

  const StreakRewardClaim({
    required this.state,
    required this.unlockedReward,
    required this.carriedPendingReward,
  });

  double get nextProgress {
    if (unlockedReward || carriedPendingReward) return 1.0;
    return (state.rewardCycleDay / 4.0).clamp(0.0, 1.0).toDouble();
  }
}

int _intFromValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return num.tryParse(value)?.round() ?? 0;
  return 0;
}
