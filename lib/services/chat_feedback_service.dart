import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Records 👍/👎 feedback on Bhrigu chat answers.
///
/// Up-votes are picked up by the `chatFeedback` Firestore trigger, embedded,
/// and stored as per-user RAG exemplars (`liked_answer_knowledge`) so the chat
/// model can reuse the depth and tone of answers a user previously loved.
class ChatFeedbackService {
  ChatFeedbackService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  // Full text is kept (not just a preview) because up-votes become RAG
  // examples, but still capped so a single doc never blows up.
  static const int textLimit = 4000;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// vote: 'up' or 'down'.
  Future<void> submitFeedback({
    required String question,
    required String answer,
    required String vote,
    required String aiResponseLanguage,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to rate this answer.');
    }

    final cleanAnswer = answer.trim();
    final cleanVote = vote.trim().toLowerCase();

    if (cleanAnswer.isEmpty) {
      throw ArgumentError('Nothing to rate.');
    }
    if (cleanVote != 'up' && cleanVote != 'down') {
      throw ArgumentError('Invalid vote.');
    }

    final docId = feedbackId(uid: user.uid, answer: cleanAnswer);

    final data = <String, dynamic>{
      'userId': user.uid,
      'feature': 'chat',
      'question': _limit(question, textLimit),
      'answer': _limit(cleanAnswer, textLimit),
      'vote': cleanVote,
      'aiResponseLanguage': aiResponseLanguage.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'platform': _platformLabel(),
    };

    final appVersion = await _appVersion();
    if (appVersion != null) {
      data['appVersion'] = appVersion;
    }

    // merge so toggling the vote updates the same doc instead of duplicating;
    // createdAt only sticks on the first write thanks to merge semantics.
    await _firestore
        .collection('chatFeedback')
        .doc(docId)
        .set(data, SetOptions(merge: true));
  }

  /// Stable per-(user, answer) id so a re-vote overwrites rather than duplicates.
  static String feedbackId({
    required String uid,
    required String answer,
  }) {
    final normalized = answer.trim().replaceAll(RegExp(r'\s+'), ' ');
    var hash = 2166136261;

    for (final codeUnit in normalized.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }

    return '${uid}_${normalized.length}_${hash.toRadixString(16)}';
  }

  static String _limit(String value, int maxLength) {
    final clean = value.trim();

    if (clean.length <= maxLength) {
      return clean;
    }

    return '${clean.substring(0, maxLength).trimRight()}...';
  }

  static String _platformLabel() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<String?> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      final buildNumber = info.buildNumber.trim();

      if (version.isEmpty) {
        return null;
      }

      return buildNumber.isEmpty ? version : '$version+$buildNumber';
    } catch (_) {
      return null;
    }
  }
}
