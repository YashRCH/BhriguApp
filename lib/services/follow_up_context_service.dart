import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/ai_response_language.dart';
import '../models/follow_up_context_model.dart';
import 'user_profile_cache_service.dart';

class FollowUpContextService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> createTarotFollowUpContext({
    required String originalQuestion,
    required String selectedFollowUpQuestion,
    required String readingSummary,
    required String pastCard,
    required String presentCard,
    required String futureCard,
    required String fullReading,
    String? aiResponseLanguage,
  }) async {
    final uid = _requireUid();
    final userSnapshot = await _loadUserSnapshot(uid);
    final contextLanguage = _contextLanguage(
      userSnapshot,
      aiResponseLanguage,
    );

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('follow_up_contexts')
        .doc();

    final context = FollowUpContext(
      id: docRef.id,
      uid: uid,
      sourceType: 'tarot',
      originalQuestion: originalQuestion,
      selectedFollowUpQuestion: selectedFollowUpQuestion,
      readingTitle: 'Three Card Tarot Reading',
      readingSummary: readingSummary,
      sourceData: {
        'pastCard': pastCard,
        'presentCard': presentCard,
        'futureCard': futureCard,
        'fullReading': fullReading,
      },
      userSnapshot: userSnapshot,
      createdAt: DateTime.now(),
      aiResponseLanguage: contextLanguage,
    );

    await docRef.set({
      ...context.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<String> createGeomancyFollowUpContext({
    required String originalQuestion,
    required String selectedFollowUpQuestion,
    required String readingSummary,
    required Map<String, dynamic> sourceData,
    String? aiResponseLanguage,
  }) async {
    final uid = _requireUid();
    final userSnapshot = await _loadUserSnapshot(uid);
    final contextLanguage = _contextLanguage(
      userSnapshot,
      aiResponseLanguage,
    );

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('follow_up_contexts')
        .doc();

    final context = FollowUpContext(
      id: docRef.id,
      uid: uid,
      sourceType: 'geomancy',
      originalQuestion: originalQuestion,
      selectedFollowUpQuestion: selectedFollowUpQuestion,
      readingTitle: 'Geomancy Shield Reading',
      readingSummary: readingSummary,
      sourceData: sourceData,
      userSnapshot: userSnapshot,
      createdAt: DateTime.now(),
      aiResponseLanguage: contextLanguage,
    );

    await docRef.set({
      ...context.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<String> createMatchFollowUpContext({
    required String originalQuestion,
    required String selectedFollowUpQuestion,
    required String readingSummary,
    required Map<String, dynamic> sourceData,
    String? aiResponseLanguage,
  }) async {
    final uid = _requireUid();
    final userSnapshot = await _loadUserSnapshot(uid);
    final contextLanguage = _contextLanguage(
      userSnapshot,
      aiResponseLanguage,
    );

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('follow_up_contexts')
        .doc();

    final context = FollowUpContext(
      id: docRef.id,
      uid: uid,
      sourceType: 'bhrigu_match',
      originalQuestion: originalQuestion,
      selectedFollowUpQuestion: selectedFollowUpQuestion,
      readingTitle: 'Bhrigu Match Reading',
      readingSummary: readingSummary,
      sourceData: sourceData,
      userSnapshot: userSnapshot,
      createdAt: DateTime.now(),
      aiResponseLanguage: contextLanguage,
    );

    await docRef.set({
      ...context.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<String> createHoroscopeFollowUpContext({
    required String originalQuestion,
    required String selectedFollowUpQuestion,
    required String readingSummary,
    required Map<String, dynamic> sourceData,
    String? aiResponseLanguage,
  }) async {
    final uid = _requireUid();
    final userSnapshot = await _loadUserSnapshot(uid);
    final contextLanguage = _contextLanguage(
      userSnapshot,
      aiResponseLanguage,
    );

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('follow_up_contexts')
        .doc();

    final context = FollowUpContext(
      id: docRef.id,
      uid: uid,
      sourceType: 'horoscope',
      originalQuestion: originalQuestion,
      selectedFollowUpQuestion: selectedFollowUpQuestion,
      readingTitle: 'Daily Horoscope Reading',
      readingSummary: readingSummary,
      sourceData: sourceData,
      userSnapshot: userSnapshot,
      createdAt: DateTime.now(),
      aiResponseLanguage: contextLanguage,
    );

    await docRef.set({
      ...context.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<FollowUpContext?> getFollowUpContext(String contextId) async {
    final uid = _requireUid();

    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('follow_up_contexts')
        .doc(contextId)
        .get();

    if (!doc.exists) return null;

    return FollowUpContext.fromFirestore(doc);
  }

  String _contextLanguage(
    Map<String, dynamic> userSnapshot,
    String? aiResponseLanguage,
  ) {
    return normalizeAiResponseLanguage(
      aiResponseLanguage ?? userSnapshot['aiResponseLanguage'],
    );
  }

  Future<Map<String, dynamic>> _loadUserSnapshot(String uid) async {
    final data =
        await UserProfileCacheService.instance.userDataWithFreshCharts() ?? {};

    return {
      'name': data['name'],
      'dob': data['dob'],
      'timeOfBirth': data['timeOfBirth'],
      'placeOfBirth': data['placeOfBirth'],
      'westernChart': data['westernChart'],
      'vedicChart': data['vedicChart'],
      'chartGeneratedAt': data['chartGeneratedAt'],
      'chartGeneratedBy': data['chartGeneratedBy'],
      'chartCalculationSource': data['chartCalculationSource'],
      'chartCalculationVersion': data['chartCalculationVersion'],
      'chartCalculationMeta': data['chartCalculationMeta'],
      'aiResponseLanguage': normalizeAiResponseLanguage(
        data['aiResponseLanguage'],
      ),
    };
  }

  String _requireUid() {
    final uid = _auth.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      throw Exception('User not signed in');
    }

    return uid;
  }
}
