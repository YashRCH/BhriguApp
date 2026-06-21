import '../utils/date_keys.dart';

const defaultOwlName = "Bhrigu's Owl";

class OwlCompanionState {
  final String owlName;
  final int petProgress;
  final String? lastPetDate;
  final bool rewardAvailable;
  final String? rewardType;
  final bool rewardReadingGranted;
  final int rewardClaimedCount;
  final String? lastRewardClaimDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OwlCompanionState({
    this.owlName = defaultOwlName,
    this.petProgress = 0,
    this.lastPetDate,
    this.rewardAvailable = false,
    this.rewardType,
    this.rewardReadingGranted = false,
    this.rewardClaimedCount = 0,
    this.lastRewardClaimDate,
    this.createdAt,
    this.updatedAt,
  });

  const OwlCompanionState.empty()
      : owlName = defaultOwlName,
        petProgress = 0,
        lastPetDate = null,
        rewardAvailable = false,
        rewardType = null,
        rewardReadingGranted = false,
        rewardClaimedCount = 0,
        lastRewardClaimDate = null,
        createdAt = null,
        updatedAt = null;

  factory OwlCompanionState.fromMap(Map<String, dynamic> data) {
    return OwlCompanionState(
      owlName: (data['owlName'] as String?) ?? defaultOwlName,
      petProgress: _intFromValue(data['petProgress']),
      lastPetDate: data['lastPetDate'] as String?,
      rewardAvailable: data['rewardAvailable'] == true,
      rewardType: _rewardTypeFromValue(data['rewardType']),
      rewardReadingGranted: data['rewardReadingGranted'] == true,
      rewardClaimedCount: _intFromValue(data['rewardClaimedCount']),
      lastRewardClaimDate: data['lastRewardClaimDate'] as String?,
      createdAt: _dateFromValue(data['createdAt']),
      updatedAt: _dateFromValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'owlName': owlName,
      'petProgress': petProgress,
      'lastPetDate': lastPetDate,
      'rewardAvailable': rewardAvailable,
      'rewardType': rewardType,
      'rewardReadingGranted': rewardReadingGranted,
      'rewardClaimedCount': rewardClaimedCount,
      'lastRewardClaimDate': lastRewardClaimDate,
      'createdAt':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  bool isPettedToday() {
    final now = DateTime.now();
    return lastPetDate == formatDateKey(now) ||
        lastPetDate == formatDateKey(now.toUtc());
  }

  OwlCompanionState copyWith({
    String? owlName,
    int? petProgress,
    String? lastPetDate,
    bool? rewardAvailable,
    String? rewardType,
    bool? rewardReadingGranted,
    int? rewardClaimedCount,
    String? lastRewardClaimDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OwlCompanionState(
      owlName: owlName ?? this.owlName,
      petProgress: petProgress ?? this.petProgress,
      lastPetDate: lastPetDate ?? this.lastPetDate,
      rewardAvailable: rewardAvailable ?? this.rewardAvailable,
      rewardType: rewardType ?? this.rewardType,
      rewardReadingGranted: rewardReadingGranted ?? this.rewardReadingGranted,
      rewardClaimedCount: rewardClaimedCount ?? this.rewardClaimedCount,
      lastRewardClaimDate: lastRewardClaimDate ?? this.lastRewardClaimDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PetResult {
  final OwlCompanionState state;
  final bool success;
  final String? rewardType;
  final int readingCreditsGranted;
  final String message;

  const PetResult({
    required this.state,
    required this.success,
    this.rewardType,
    this.readingCreditsGranted = 0,
    required this.message,
  });
}

class OwlRewardClaimResult {
  final OwlCompanionState state;
  final bool success;
  final bool claimed;
  final String? rewardType;
  final int chatMessagesGranted;
  final int readingCreditsGranted;
  final String message;

  const OwlRewardClaimResult({
    required this.state,
    required this.success,
    required this.claimed,
    required this.rewardType,
    required this.chatMessagesGranted,
    required this.readingCreditsGranted,
    required this.message,
  });
}

int _intFromValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return num.tryParse(value)?.round() ?? 0;
  return 0;
}

String? _rewardTypeFromValue(dynamic value) {
  if (value == 'tarot' || value == 'geomancy') return value as String;
  return null;
}

DateTime? _dateFromValue(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value != null) {
    try {
      final date = value.toDate();
      if (date is DateTime) return date;
    } catch (_) {
      return null;
    }
  }
  return null;
}
