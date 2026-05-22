import 'package:cloud_firestore/cloud_firestore.dart';

class FollowUpContext {
  final String id;
  final String uid;

  final String sourceType;
  final String originalQuestion;
  final String selectedFollowUpQuestion;

  final String readingTitle;
  final String readingSummary;

  final Map<String, dynamic> sourceData;
  final Map<String, dynamic> userSnapshot;

  final DateTime createdAt;

  const FollowUpContext({
    required this.id,
    required this.uid,
    required this.sourceType,
    required this.originalQuestion,
    required this.selectedFollowUpQuestion,
    required this.readingTitle,
    required this.readingSummary,
    required this.sourceData,
    required this.userSnapshot,
    required this.createdAt,
  });

  factory FollowUpContext.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return FollowUpContext(
      id: doc.id,
      uid: data['uid'] ?? '',
      sourceType: data['sourceType'] ?? '',
      originalQuestion: data['originalQuestion'] ?? '',
      selectedFollowUpQuestion: data['selectedFollowUpQuestion'] ?? '',
      readingTitle: data['readingTitle'] ?? '',
      readingSummary: data['readingSummary'] ?? '',
      sourceData: Map<String, dynamic>.from(data['sourceData'] ?? {}),
      userSnapshot: Map<String, dynamic>.from(data['userSnapshot'] ?? {}),
      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'sourceType': sourceType,
      'originalQuestion': originalQuestion,
      'selectedFollowUpQuestion': selectedFollowUpQuestion,
      'readingTitle': readingTitle,
      'readingSummary': readingSummary,
      'sourceData': sourceData,
      'userSnapshot': userSnapshot,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }
}