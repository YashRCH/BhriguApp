import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../constants/firebase_constants.dart';
import '../utils/similarity.dart';
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
      final queryEmbedding = await _embedQuery(query);

      if (queryEmbedding.isEmpty) {
        return [];
      }

      final snap = await FirebaseFirestore.instance
          .collection('compatibility_knowledge')
          .get();

      final scoredChunks = <CompatibilityKnowledgeChunk>[];

      for (final doc in snap.docs) {
        final data = doc.data();

        final rawEmbedding = data['embedding'];
        if (rawEmbedding is! List) continue;

        final storedEmbedding =
            rawEmbedding.map((value) => (value as num).toDouble()).toList();

        final score = cosineSimilarity(queryEmbedding, storedEmbedding);

        scoredChunks.add(
          CompatibilityKnowledgeChunk(
            title: data['title'] as String? ?? '',
            category: data['category'] as String? ?? '',
            tags: ((data['tags'] as List?) ?? [])
                .map((tag) => tag.toString())
                .toList(),
            text: data['text'] as String? ?? '',
            score: score,
          ),
        );
      }

      scoredChunks.sort((a, b) => b.score.compareTo(a.score));

      return scoredChunks.take(limit).toList();
    } catch (e) {
      debugPrint('Compatibility RAG retrieve error: $e');
      return [];
    }
  }

  Future<List<double>> _embedQuery(String text) async {
    try {
      final idToken = await _session.idToken();

      if (idToken == null) {
        return [];
      }

      final callable = _functions.httpsCallable(
        'generateCompatibilityEmbedding',
      );

      final response = await callable.call(
        {
          'idToken': idToken,
          'text': text,
        },
      );

      final data = Map<String, dynamic>.from(
        response.data as Map,
      );

      final values = data['values'] as List;

      return values.map((value) => (value as num).toDouble()).toList();
    } catch (e) {
      debugPrint('Compatibility Gemini embedding error: $e');
      return [];
    }
  }
}
