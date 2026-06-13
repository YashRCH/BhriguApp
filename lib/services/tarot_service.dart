import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_messages.dart';
import '../constants/ai_response_language.dart';
import '../constants/firebase_constants.dart';
import '../models/tarot_card.dart';
import 'firebase_session_service.dart';
import 'user_profile_cache_service.dart';

const int _savedReadingLimit = 5;
const int _firestoreBatchWriteLimit = 500;

class TarotInterpretationResult {
  final String text;
  final String aiResponseLanguage;

  const TarotInterpretationResult({
    required this.text,
    required this.aiResponseLanguage,
  });
}

class TarotService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );

  final FirebaseSessionService _session =
      FirebaseSessionService(debugLabel: 'Tarot');

  List<TarotCard> drawThreeCards() {
    final deck = List<TarotCard>.from(majorArcana)..shuffle();
    return deck.take(3).toList();
  }

  Future<Map<String, dynamic>> _getUserData() async {
    return await UserProfileCacheService.instance.userDataWithFreshCharts() ??
        {};
  }

  Future<TarotInterpretationResult> interpretReading({
    required String question,
    required TarotCard past,
    required TarotCard present,
    required TarotCard future,
  }) async {
    var aiResponseLanguage = englishAiResponseLanguage;

    try {
      if (await _session.currentUserOrWait() == null) {
        return TarotInterpretationResult(
          text: cosmicConnectionLostMessage,
          aiResponseLanguage: aiResponseLanguage,
        );
      }

      final userData = await _getUserData();
      aiResponseLanguage = normalizeAiResponseLanguage(
        userData['aiResponseLanguage'],
      );

      final birthData = userData.isEmpty
          ? 'Birth data not available.'
          : 'Name: ${userData['name']}, DOB: ${userData['dob']}, '
              'Time: ${userData['timeOfBirth']}, Place: ${userData['placeOfBirth']}';

      final callable = _functions.httpsCallable(
        'generateTarotReading',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 120),
        ),
      );

      final response = await callable.call(
        {
          'birthData': birthData,
          'question': question,
          'pastName': past.name,
          'presentName': present.name,
          'futureName': future.name,
          'pastKeywords': past.keywords,
          'presentKeywords': present.keywords,
          'futureKeywords': future.keywords,
          'pastKnowledge': past.uprightMeaning,
          'presentKnowledge': present.uprightMeaning,
          'futureKnowledge': future.uprightMeaning,
          'aiResponseLanguage': aiResponseLanguage,
        },
      );

      final data = Map<String, dynamic>.from(
        response.data as Map,
      );

      final text = data['text'] as String? ?? '';
      final responseLanguage = normalizeAiResponseLanguage(
        data['aiResponseLanguage'] ?? aiResponseLanguage,
      );

      if (text.trim().isNotEmpty) {
        await saveReading(
          question: question,
          past: past,
          present: present,
          future: future,
          reading: text.trim(),
          aiResponseLanguage: responseLanguage,
        );
      }

      return TarotInterpretationResult(
        text: text.trim().isEmpty ? cosmicConnectionLostMessage : text.trim(),
        aiResponseLanguage: responseLanguage,
      );
    } catch (e) {
      debugPrint('Tarot error: $e');
      return TarotInterpretationResult(
        text: cosmicConnectionLostMessage,
        aiResponseLanguage: aiResponseLanguage,
      );
    }
  }

  Future<void> saveReading({
    required String question,
    required TarotCard past,
    required TarotCard present,
    required TarotCard future,
    required String reading,
    String aiResponseLanguage = englishAiResponseLanguage,
  }) async {
    try {
      final uid = await _session.userId();

      if (uid == null || uid.isEmpty) {
        throw Exception('User not signed in');
      }

      final cleanQuestion = question.trim().isEmpty
          ? 'The user asked for a general tarot reading.'
          : question.trim();

      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tarot_readings');

      final duplicateSnap = await ref
          .where('question', isEqualTo: cleanQuestion)
          .where('past.name', isEqualTo: past.name)
          .where('present.name', isEqualTo: present.name)
          .where('future.name', isEqualTo: future.name)
          .where(
            'aiResponseLanguage',
            isEqualTo: normalizeAiResponseLanguage(aiResponseLanguage),
          )
          .limit(1)
          .get();

      if (duplicateSnap.docs.isNotEmpty) {
        debugPrint('Tarot save skipped: duplicate reading already exists');
        await _pruneSavedReadings(
          ref,
          aiResponseLanguage: aiResponseLanguage,
        );
        return;
      }

      final savedReading = TarotSavedReading(
        id: '',
        question: cleanQuestion,
        past: past,
        present: present,
        future: future,
        reading: reading.trim(),
        createdAt: DateTime.now(),
        aiResponseLanguage: aiResponseLanguage,
      );

      await ref.add(savedReading.toJson());
      await _pruneSavedReadings(
        ref,
        aiResponseLanguage: aiResponseLanguage,
      );
    } catch (e) {
      debugPrint('Save tarot reading error: $e');
    }
  }

  Future<List<TarotSavedReading>> getSavedReadings() async {
    try {
      final uid = await _session.userId();

      if (uid == null || uid.isEmpty) {
        throw Exception('User not signed in');
      }

      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tarot_readings');

      final snap = await ref.orderBy('createdAt', descending: true).get();

      final aiResponseLanguage = await UserProfileCacheService.instance
          .aiResponseLanguage(refresh: true);
      await _pruneSavedReadings(
        ref,
        orderedDocs: snap.docs,
        aiResponseLanguage: aiResponseLanguage,
      );

      final readings = <TarotSavedReading>[];

      for (final doc in snap.docs) {
        try {
          final reading = TarotSavedReading.fromJson(
            id: doc.id,
            json: doc.data(),
          );

          if (reading.aiResponseLanguage == aiResponseLanguage) {
            readings.add(reading);
          }

          if (readings.length >= _savedReadingLimit) break;
        } catch (e) {
          debugPrint('Tarot history parse error: $e');
        }
      }

      return readings;
    } catch (e) {
      debugPrint('Get tarot readings error: $e');
      return [];
    }
  }

  Future<void> clearSavedReadings() async {
    final uid = await _session.userId();

    if (uid == null || uid.isEmpty) {
      throw Exception('User not signed in');
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tarot_readings');

    final snap = await ref.get();

    var batch = FirebaseFirestore.instance.batch();
    var writes = 0;

    for (final doc in snap.docs) {
      batch.delete(doc.reference);
      writes++;

      if (writes >= _firestoreBatchWriteLimit) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        writes = 0;
      }
    }

    if (writes > 0) {
      await batch.commit();
    }
  }

  Future<void> _pruneSavedReadings(
    CollectionReference<Map<String, dynamic>> ref, {
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>>? orderedDocs,
    String aiResponseLanguage = englishAiResponseLanguage,
  }) async {
    try {
      final docs = orderedDocs ??
          (await ref.orderBy('createdAt', descending: true).get()).docs;
      final normalizedLanguage =
          normalizeAiResponseLanguage(aiResponseLanguage);
      final oldDocs = docs.where((doc) {
        return normalizeAiResponseLanguage(doc.data()['aiResponseLanguage']) ==
            normalizedLanguage;
      }).skip(_savedReadingLimit);

      var batch = FirebaseFirestore.instance.batch();
      var writes = 0;

      for (final doc in oldDocs) {
        batch.delete(doc.reference);
        writes++;

        if (writes == _firestoreBatchWriteLimit) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          writes = 0;
        }
      }

      if (writes > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Prune tarot readings error: $e');
    }
  }
}
