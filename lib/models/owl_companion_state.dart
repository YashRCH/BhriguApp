import '../utils/date_keys.dart';

const defaultOwlName = "Bhrigu's Owl";

class OwlCompanionState {
  final String owlName;
  final int petProgress;
  final String? lastPetDate;
  final bool rewardAvailable;
  final int rewardClaimedCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OwlCompanionState({
    this.owlName = defaultOwlName,
    this.petProgress = 0,
    this.lastPetDate,
    this.rewardAvailable = false,
    this.rewardClaimedCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  const OwlCompanionState.empty()
      : owlName = defaultOwlName,
        petProgress = 0,
        lastPetDate = null,
        rewardAvailable = false,
        rewardClaimedCount = 0,
        createdAt = null,
        updatedAt = null;

  factory OwlCompanionState.fromMap(Map<String, dynamic> data) {
    return OwlCompanionState(
      owlName: (data['owlName'] as String?) ?? defaultOwlName,
      petProgress: _intFromValue(data['petProgress']),
      lastPetDate: data['lastPetDate'] as String?,
      rewardAvailable: data['rewardAvailable'] == true,
      rewardClaimedCount: _intFromValue(data['rewardClaimedCount']),
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
      'rewardClaimedCount': rewardClaimedCount,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  bool isPettedToday() {
    return lastPetDate == formatDateKey(DateTime.now());
  }

  OwlCompanionState copyWith({
    String? owlName,
    int? petProgress,
    String? lastPetDate,
    bool? rewardAvailable,
    int? rewardClaimedCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OwlCompanionState(
      owlName: owlName ?? this.owlName,
      petProgress: petProgress ?? this.petProgress,
      lastPetDate: lastPetDate ?? this.lastPetDate,
      rewardAvailable: rewardAvailable ?? this.rewardAvailable,
      rewardClaimedCount: rewardClaimedCount ?? this.rewardClaimedCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PetResult {
  final OwlCompanionState state;
  final bool success;
  final String message;

  const PetResult({
    required this.state,
    required this.success,
    required this.message,
  });
}

int _intFromValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return num.tryParse(value)?.round() ?? 0;
  return 0;
}

DateTime? _dateFromValue(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
