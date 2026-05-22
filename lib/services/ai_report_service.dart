import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AiReportService {
  AiReportService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  static const int previewLimit = 500;
  static const int commentLimit = 300;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> submitReport({
    required String feature,
    required String contentId,
    required String contentText,
    required String reason,
    String? optionalComment,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to report this content.');
    }

    final cleanFeature = feature.trim();
    final cleanContent = contentText.trim();
    final cleanReason = reason.trim();
    final cleanComment = optionalComment?.trim() ?? '';

    if (cleanFeature.isEmpty || cleanContent.isEmpty || cleanReason.isEmpty) {
      throw ArgumentError('Report details are incomplete.');
    }

    final data = <String, dynamic>{
      'userId': user.uid,
      'feature': cleanFeature,
      'contentId': contentId.trim().isEmpty
          ? stableContentId(
              feature: cleanFeature,
              contentText: cleanContent,
            )
          : contentId.trim(),
      'contentPreview': _preview(cleanContent),
      'reason': cleanReason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
      'platform': _platformLabel(),
    };

    if (cleanComment.isNotEmpty) {
      data['optionalComment'] = _limit(cleanComment, commentLimit);
    }

    final appVersion = await _appVersion();
    if (appVersion != null) {
      data['appVersion'] = appVersion;
    }

    await _firestore.collection('aiReports').add(data);
  }

  static String stableContentId({
    required String feature,
    required String contentText,
  }) {
    final normalized = contentText.trim().replaceAll(RegExp(r'\s+'), ' ');
    var hash = 2166136261;

    for (final codeUnit in normalized.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }

    return '${feature.trim()}_${normalized.length}_${hash.toRadixString(16)}';
  }

  static String _preview(String value) => _limit(value, previewLimit);

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
