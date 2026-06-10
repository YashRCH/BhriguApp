import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ai_response_language.dart';
import 'partner_match_model.dart';

enum SocialRelationshipType {
  friend,
  partner;

  String get value => name;

  String get label {
    switch (this) {
      case SocialRelationshipType.friend:
        return 'Friend';
      case SocialRelationshipType.partner:
        return 'Partner';
    }
  }

  static SocialRelationshipType fromValue(dynamic value) {
    final text = value?.toString().trim().toLowerCase();
    if (text == 'spouse') return SocialRelationshipType.partner;

    return SocialRelationshipType.values.firstWhere(
      (type) => type.value == text,
      orElse: () => SocialRelationshipType.friend,
    );
  }
}

enum SocialConnectionStatus {
  active,
  incoming,
  outgoing,
  blocked,
  archived;

  String get value => name;

  static SocialConnectionStatus fromValue(dynamic value) {
    final text = value?.toString().trim().toLowerCase();

    return SocialConnectionStatus.values.firstWhere(
      (status) => status.value == text,
      // FIXED: default to 'archived' (neutral / invisible) rather than
      // 'outgoing', which would cause every unknown-status connection to
      // appear as a fake pending outgoing tile in the Circle screen.
      orElse: () => SocialConnectionStatus.archived,
    );
  }
}

class PublicAstrologyProfile {
  final String uid;
  final String username;
  final String displayName;
  final String photoUrl;
  final String sunSign;
  final String moonSign;
  final String risingSign;

  const PublicAstrologyProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.photoUrl,
    required this.sunSign,
    required this.moonSign,
    required this.risingSign,
  });

  String get chartSummary {
    final parts = <String>[
      if (sunSign.trim().isNotEmpty) '$sunSign Sun',
      if (moonSign.trim().isNotEmpty) '$moonSign Moon',
      if (risingSign.trim().isNotEmpty) '$risingSign Rising',
    ];

    return parts.isEmpty ? 'Cosmic blueprint hidden' : parts.join(' · ');
  }

  factory PublicAstrologyProfile.empty(String uid) {
    return PublicAstrologyProfile(
      uid: uid,
      username: '',
      displayName: 'BHR1GU user',
      photoUrl: '',
      sunSign: '',
      moonSign: '',
      risingSign: '',
    );
  }

  factory PublicAstrologyProfile.fromMap(Map<String, dynamic> data) {
    return PublicAstrologyProfile(
      uid: data['uid'] as String? ?? '',
      username: data['username'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'BHR1GU user',
      photoUrl: data['photoUrl'] as String? ?? '',
      sunSign: data['sunSign'] as String? ?? '',
      moonSign: data['moonSign'] as String? ?? '',
      risingSign: data['risingSign'] as String? ?? '',
    );
  }
}

class SocialConnection {
  final String connectionId;
  final String otherUid;
  final SocialRelationshipType relationshipType;
  final SocialConnectionStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final PublicAstrologyProfile otherProfile;

  const SocialConnection({
    required this.connectionId,
    required this.otherUid,
    required this.relationshipType,
    required this.status,
    required this.createdAt,
    required this.acceptedAt,
    required this.otherProfile,
  });

  factory SocialConnection.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final otherUid = data['otherUid'] as String? ?? doc.id;

    // FIXED: Fall back to doc.id only as a last resort. The connectionId field
    // must always be written by the Cloud Function; doc.id here is the otherUid
    // of the mirror document and is NOT the connectionId — this path should
    // never be reached in practice.
    final storedId = data['connectionId'] as String? ?? '';
    final connectionId = storedId.isNotEmpty ? storedId : doc.id;

    return SocialConnection(
      connectionId: connectionId,
      otherUid: otherUid,
      relationshipType: SocialRelationshipType.fromValue(
        data['relationshipType'],
      ),
      status: SocialConnectionStatus.fromValue(data['status']),
      createdAt: _parseDate(data['createdAt']),
      acceptedAt:
          data['acceptedAt'] == null ? null : _parseDate(data['acceptedAt']),
      otherProfile: data['otherProfile'] is Map
          ? PublicAstrologyProfile.fromMap(
              Map<String, dynamic>.from(data['otherProfile'] as Map),
            )
          : PublicAstrologyProfile.empty(otherUid),
    );
  }
}

class ConnectionCompatibilityReading {
  final String id;
  final String type;
  final Map<String, int> scores;
  final String summary;
  final String strengths;
  final String tensions;
  final String advice;
  final String dailyBondSignal;
  final String connectionType;
  final String verdict;
  final String aiResponseLanguage;
  final DateTime createdAt;
  final PartnerMatchReading? partnerMatchReading;

  const ConnectionCompatibilityReading({
    required this.id,
    required this.type,
    required this.scores,
    required this.summary,
    required this.strengths,
    required this.tensions,
    required this.advice,
    required this.dailyBondSignal,
    required this.connectionType,
    required this.verdict,
    required this.aiResponseLanguage,
    required this.createdAt,
    this.partnerMatchReading,
  });

  factory ConnectionCompatibilityReading.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final rawScores = data['scores'];

    return ConnectionCompatibilityReading(
      id: doc.id,
      type: data['type'] as String? ?? 'friend',
      scores: rawScores is Map
          ? rawScores.map(
              (key, value) => MapEntry(
                key.toString(),
                _intFromValue(value),
              ),
            )
          : const {},
      summary: data['summary'] as String? ?? '',
      strengths: data['strengths'] as String? ?? '',
      tensions: data['tensions'] as String? ?? '',
      advice: data['advice'] as String? ?? '',
      dailyBondSignal: data['dailyBondSignal'] as String? ?? '',
      connectionType: data['connectionType'] as String? ?? '',
      verdict: data['verdict'] as String? ?? '',
      aiResponseLanguage: normalizeAiResponseLanguage(
        data['aiResponseLanguage'],
      ),
      createdAt: _parseDate(data['createdAt']),
      partnerMatchReading: data['partnerMatchReading'] is Map
          ? PartnerMatchReading.fromJson(
              _mapFromValue(data['partnerMatchReading']),
            )
          : null,
    );
  }
}

class PersonDailyEnergy {
  final String energy;
  final String heading;
  final String doText;
  final String avoidText;
  final String bestApproach;

  const PersonDailyEnergy({
    required this.energy,
    required this.heading,
    required this.doText,
    required this.avoidText,
    required this.bestApproach,
  });

  factory PersonDailyEnergy.fromMap(Map<String, dynamic> data) {
    return PersonDailyEnergy(
      energy: data['energy'] as String? ?? '',
      heading: data['heading'] as String? ?? '',
      doText: data['doText'] as String? ?? '',
      avoidText: data['avoidText'] as String? ?? '',
      bestApproach: data['bestApproach'] as String? ?? '',
    );
  }
}

class ConnectionDailyEnergy {
  final String id;
  final String dateKey;
  final String bondSignal;
  final Map<String, PersonDailyEnergy> members;
  final DateTime createdAt;

  const ConnectionDailyEnergy({
    required this.id,
    required this.dateKey,
    required this.bondSignal,
    required this.members,
    required this.createdAt,
  });

  factory ConnectionDailyEnergy.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final rawMembers = data['members'];
    final members = <String, PersonDailyEnergy>{};

    if (rawMembers is Map) {
      rawMembers.forEach((key, value) {
        if (value is Map) {
          members[key.toString()] = PersonDailyEnergy.fromMap(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    return ConnectionDailyEnergy(
      id: doc.id,
      dateKey: data['dateKey'] as String? ?? doc.id,
      bondSignal: data['bondSignal'] as String? ?? '',
      members: members,
      createdAt: _parseDate(data['createdAt']),
    );
  }
}

DateTime _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

int _intFromValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return num.tryParse(value)?.round() ?? 0;
  return 0;
}

Map<String, dynamic> _mapFromValue(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
