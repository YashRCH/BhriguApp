import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../constants/firebase_constants.dart';
import 'firebase_session_service.dart';

class CompatibilityKnowledgeChunk {
  final String title;
  final String category;
  final List<String> tags;
  final String text;
  final double score;

  const CompatibilityKnowledgeChunk({
    required this.title,
    required this.category,
    required this.tags,
    required this.text,
    required this.score,
  });

  String get formatted {
    return '''
Title: $title
Category: $category
Tags: ${tags.join(', ')}
Knowledge: $text
''';
  }
}

class CompatibilityRagService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );

  final FirebaseSessionService _session =
      FirebaseSessionService(debugLabel: 'Compatibility RAG');

  Future<List<CompatibilityKnowledgeChunk>> retrieveRelevantChunks({
    required String query,
    int limit = 5,
  }) async {
    try {
      if (await _session.currentUserOrWait() == null) {
        return [];
      }

      final callable = _functions.httpsCallable(
        'retrieveCompatibilityKnowledge',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );

      final response = await callable.call(
        {
          'query': query,
          'limit': limit,
        },
      );

      final data = Map<String, dynamic>.from(
        response.data as Map,
      );
      final chunks = data['chunks'];

      if (chunks is! List) {
        return [];
      }

      return chunks.whereType<Map>().map((chunk) {
        final normalized = Map<String, dynamic>.from(chunk);

        return CompatibilityKnowledgeChunk(
          title: normalized['title'] as String? ?? '',
          category: normalized['category'] as String? ?? '',
          tags: ((normalized['tags'] as List?) ?? [])
              .map((tag) => tag.toString())
              .toList(),
          text: normalized['text'] as String? ?? '',
          score: (normalized['score'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('Compatibility RAG retrieve error: $e');
      return [];
    }
  }
}
