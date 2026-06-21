import 'package:cloud_firestore/cloud_firestore.dart';

class DakshanaWallet {
  final int chat;
  final int tarot;
  final int geomancy;
  final bool active;

  const DakshanaWallet({
    required this.chat,
    required this.tarot,
    required this.geomancy,
    required this.active,
  });

  const DakshanaWallet.empty()
      : chat = 0,
        tarot = 0,
        geomancy = 0,
        active = false;

  int get totalCredits => chat + tarot + geomancy;

  factory DakshanaWallet.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const DakshanaWallet.empty();

    final chat = _intValue(data['chat']);
    final tarot = _intValue(data['tarot']);
    final geomancy = _intValue(data['geomancy']);

    return DakshanaWallet(
      chat: chat,
      tarot: tarot,
      geomancy: geomancy,
      active: data['active'] == true || chat + tarot + geomancy > 0,
    );
  }
}

class MonetizationStatus {
  final String mode;
  final bool plusActive;
  final String plan;
  final DateTime? plusExpiresAt;
  final DakshanaWallet dakshana;
  final Map<String, int> usage;
  final Map<String, int> rewards;
  final Map<String, int> limits;

  const MonetizationStatus({
    required this.mode,
    required this.plusActive,
    required this.plan,
    required this.plusExpiresAt,
    required this.dakshana,
    required this.usage,
    required this.rewards,
    required this.limits,
  });

  const MonetizationStatus.free()
      : mode = 'off',
        plusActive = false,
        plan = 'free',
        plusExpiresAt = null,
        dakshana = const DakshanaWallet.empty(),
        usage = const {},
        rewards = const {},
        limits = const {};

  const MonetizationStatus.unavailable()
      : mode = 'unavailable',
        plusActive = false,
        plan = 'free',
        plusExpiresAt = null,
        dakshana = const DakshanaWallet.empty(),
        usage = const {},
        rewards = const {},
        limits = const {};

  bool get canBuyDakshana => dakshana.totalCredits == 0;

  factory MonetizationStatus.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const MonetizationStatus.free();

    return MonetizationStatus(
      mode: data['mode']?.toString() ?? 'off',
      plusActive: data['plusActive'] == true,
      plan: data['plan']?.toString() ?? 'free',
      plusExpiresAt: _dateValue(data['plusExpiresAt']),
      dakshana: DakshanaWallet.fromMap(
        data['dakshana'] is Map
            ? Map<String, dynamic>.from(data['dakshana'] as Map)
            : null,
      ),
      usage: _intMap(data['usage']),
      rewards: _intMap(data['rewards']),
      limits: _intMap(data['limits']),
    );
  }

  static Map<String, int> _intMap(dynamic value) {
    if (value is! Map) return const {};

    return value.map(
      (key, mapValue) => MapEntry(key.toString(), _intValue(mapValue)),
    );
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _dateValue(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
