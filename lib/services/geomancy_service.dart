import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../constants/ai_response_language.dart';
import '../constants/firebase_constants.dart';
import '../models/geomancy_figure_model.dart';
import 'firebase_session_service.dart';
import 'user_profile_cache_service.dart';

const int _savedReadingLimit = 5;
const int _firestoreBatchWriteLimit = 500;

class _GeomancyInterpretationResult {
  final String text;
  final String aiResponseLanguage;

  const _GeomancyInterpretationResult({
    required this.text,
    required this.aiResponseLanguage,
  });
}

class GeomancyService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );

  final FirebaseSessionService _session =
      FirebaseSessionService(debugLabel: 'Geomancy');

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _lastSavedSignature;

  static const List<GeomancyFigureModel> figures = [
    GeomancyFigureModel(
      name: 'Via',
      latinName: 'The Way',
      pattern: [1, 1, 1, 1],
      element: 'Water',
      planet: 'Moon',
      answerType: 'Moving',
      meaning:
          'The path is open, but nothing is fixed yet. Movement matters more than certainty.',
    ),
    GeomancyFigureModel(
      name: 'Populus',
      latinName: 'The People',
      pattern: [2, 2, 2, 2],
      element: 'Water',
      planet: 'Moon',
      answerType: 'Collective',
      meaning:
          'The situation is shaped by people, mood, and outside influence. Do not decide in isolation.',
    ),
    GeomancyFigureModel(
      name: 'Fortuna Major',
      latinName: 'Greater Fortune',
      pattern: [2, 2, 1, 1],
      element: 'Fire',
      planet: 'Sun',
      answerType: 'Strong Yes',
      meaning:
          'A powerful sign of success through patience, dignity, and steady effort.',
    ),
    GeomancyFigureModel(
      name: 'Fortuna Minor',
      latinName: 'Lesser Fortune',
      pattern: [1, 1, 2, 2],
      element: 'Fire',
      planet: 'Sun',
      answerType: 'Quick Yes',
      meaning:
          'The opportunity is favorable, but timing is sensitive. Act while the door is open.',
    ),
    GeomancyFigureModel(
      name: 'Conjunctio',
      latinName: 'Union',
      pattern: [2, 1, 1, 2],
      element: 'Air',
      planet: 'Mercury',
      answerType: 'Connection',
      meaning:
          'Two forces are meeting. The result depends on communication, timing, and mutual intent.',
    ),
    GeomancyFigureModel(
      name: 'Carcer',
      latinName: 'Prison',
      pattern: [1, 2, 2, 1],
      element: 'Earth',
      planet: 'Saturn',
      answerType: 'Blocked',
      meaning:
          'The matter is restricted for now. Pressure will not open what requires maturity.',
    ),
    GeomancyFigureModel(
      name: 'Tristitia',
      latinName: 'Sorrow',
      pattern: [2, 2, 2, 1],
      element: 'Earth',
      planet: 'Saturn',
      answerType: 'Difficult',
      meaning:
          'There is heaviness around the matter. Do not ignore what already feels draining.',
    ),
    GeomancyFigureModel(
      name: 'Laetitia',
      latinName: 'Joy',
      pattern: [1, 2, 2, 2],
      element: 'Fire',
      planet: 'Jupiter',
      answerType: 'Positive',
      meaning:
          'The pattern rises upward. Growth, relief, and emotional lightness are possible.',
    ),
    GeomancyFigureModel(
      name: 'Puella',
      latinName: 'The Girl',
      pattern: [1, 2, 1, 1],
      element: 'Water',
      planet: 'Venus',
      answerType: 'Gentle Yes',
      meaning:
          'Beauty, attraction, and softness influence the matter. Avoid forcing what needs grace.',
    ),
    GeomancyFigureModel(
      name: 'Puer',
      latinName: 'The Boy',
      pattern: [1, 1, 2, 1],
      element: 'Fire',
      planet: 'Mars',
      answerType: 'Impulsive',
      meaning:
          'There is courage here, but also impatience. Action helps only if ego stays controlled.',
    ),
    GeomancyFigureModel(
      name: 'Albus',
      latinName: 'White',
      pattern: [2, 2, 1, 2],
      element: 'Air',
      planet: 'Mercury',
      answerType: 'Wise Yes',
      meaning:
          'Clarity is available. Choose the path that is calm, intelligent, and clean.',
    ),
    GeomancyFigureModel(
      name: 'Rubeus',
      latinName: 'Red',
      pattern: [2, 1, 2, 2],
      element: 'Fire',
      planet: 'Mars',
      answerType: 'Unstable',
      meaning:
          'Strong desire is present, but the energy is volatile. Wait before reacting.',
    ),
    GeomancyFigureModel(
      name: 'Acquisitio',
      latinName: 'Gain',
      pattern: [2, 1, 2, 1],
      element: 'Air',
      planet: 'Jupiter',
      answerType: 'Gain',
      meaning:
          'This favors increase, support, profit, or receiving something valuable.',
    ),
    GeomancyFigureModel(
      name: 'Amissio',
      latinName: 'Loss',
      pattern: [1, 2, 1, 2],
      element: 'Earth',
      planet: 'Venus',
      answerType: 'Release',
      meaning:
          'Something may leave your hand, but the loss may clear space for better alignment.',
    ),
    GeomancyFigureModel(
      name: 'Caput Draconis',
      latinName: 'Head of the Dragon',
      pattern: [2, 1, 1, 1],
      element: 'Earth',
      planet: 'North Node',
      answerType: 'Beginning',
      meaning:
          'A new gate opens. Enter carefully, because the first step defines the pattern.',
    ),
    GeomancyFigureModel(
      name: 'Cauda Draconis',
      latinName: 'Tail of the Dragon',
      pattern: [1, 1, 1, 2],
      element: 'Fire',
      planet: 'South Node',
      answerType: 'Ending',
      meaning:
          'A cycle is closing. Do not revive what has already taught its lesson.',
    ),
  ];

  Future<GeomancyReadingModel> buildReading({
    required String question,
    required List<int> lineValues,
  }) async {
    final aiResponseLanguage = await UserProfileCacheService.instance
        .aiResponseLanguage(refresh: true);
    final chart = buildChart(lineValues);
    final answer = _answerFromJudge(chart.judge);
    final interpretationResult = await _generateBhriguReading(
      question: question,
      chart: chart,
      answer: answer,
      aiResponseLanguage: aiResponseLanguage,
    );

    final reading = GeomancyReadingModel(
      question: question.trim().isEmpty
          ? 'The user asked for a general geomancy reading.'
          : question.trim(),
      chart: chart,
      answer: answer,
      interpretation: interpretationResult.text,
      aiResponseLanguage: interpretationResult.aiResponseLanguage,
    );

    await saveReading(
      reading: reading,
      lineValues: lineValues,
      aiResponseLanguage: interpretationResult.aiResponseLanguage,
    );

    return reading;
  }

  GeomancyChartModel buildChart(List<int> lineValues) {
    if (lineValues.length != 16) {
      throw ArgumentError('Geomancy requires exactly 16 line values.');
    }

    final motherPatterns = [
      lineValues.sublist(0, 4),
      lineValues.sublist(4, 8),
      lineValues.sublist(8, 12),
      lineValues.sublist(12, 16),
    ];

    final daughterPatterns = [
      [
        motherPatterns[0][0],
        motherPatterns[1][0],
        motherPatterns[2][0],
        motherPatterns[3][0],
      ],
      [
        motherPatterns[0][1],
        motherPatterns[1][1],
        motherPatterns[2][1],
        motherPatterns[3][1],
      ],
      [
        motherPatterns[0][2],
        motherPatterns[1][2],
        motherPatterns[2][2],
        motherPatterns[3][2],
      ],
      [
        motherPatterns[0][3],
        motherPatterns[1][3],
        motherPatterns[2][3],
        motherPatterns[3][3],
      ],
    ];

    final niecePatterns = [
      _combine(motherPatterns[0], motherPatterns[1]),
      _combine(motherPatterns[2], motherPatterns[3]),
      _combine(daughterPatterns[0], daughterPatterns[1]),
      _combine(daughterPatterns[2], daughterPatterns[3]),
    ];

    final leftWitnessPattern = _combine(niecePatterns[0], niecePatterns[1]);
    final rightWitnessPattern = _combine(niecePatterns[2], niecePatterns[3]);
    final judgePattern = _combine(leftWitnessPattern, rightWitnessPattern);
    final reconcilerPattern = _combine(judgePattern, motherPatterns[0]);

    return GeomancyChartModel(
      mothers: motherPatterns.map(_figureFromPattern).toList(),
      daughters: daughterPatterns.map(_figureFromPattern).toList(),
      nieces: niecePatterns.map(_figureFromPattern).toList(),
      leftWitness: _figureFromPattern(leftWitnessPattern),
      rightWitness: _figureFromPattern(rightWitnessPattern),
      judge: _figureFromPattern(judgePattern),
      reconciler: _figureFromPattern(reconcilerPattern),
    );
  }

  List<int> _combine(List<int> a, List<int> b) {
    return List.generate(4, (i) => ((a[i] + b[i]).isOdd) ? 1 : 2);
  }

  GeomancyFigureModel _figureFromPattern(List<int> pattern) {
    final key = pattern.join();

    return figures.firstWhere(
      (figure) => figure.key == key,
      orElse: () => GeomancyFigureModel(
        name: 'Unknown Figure',
        latinName: 'Hidden Form',
        pattern: pattern,
        element: 'Spirit',
        planet: 'Unknown',
        answerType: 'Unclear',
        meaning:
            'The pattern is unusual. Read this as a signal to pause and observe.',
      ),
    );
  }

  String _answerFromJudge(GeomancyFigureModel judge) {
    switch (judge.answerType) {
      case 'Strong Yes':
        return 'Strongly favorable';
      case 'Quick Yes':
        return 'Favorable, but timing matters';
      case 'Gentle Yes':
        return 'Favorable if handled softly';
      case 'Wise Yes':
        return 'Yes, with clarity and restraint';
      case 'Positive':
        return 'Positive movement ahead';
      case 'Gain':
        return 'Gain is possible';
      case 'Blocked':
        return 'Blocked for now';
      case 'Difficult':
        return 'Difficult and heavy';
      case 'Unstable':
        return 'Unstable, wait before acting';
      case 'Release':
        return 'Something must be released';
      case 'Beginning':
        return 'A new beginning is opening';
      case 'Ending':
        return 'A cycle is ending';
      case 'Connection':
        return 'Depends on connection and communication';
      case 'Moving':
        return 'The path is still moving';
      case 'Collective':
        return 'Other people strongly influence this';
      default:
        return 'Mixed result';
    }
  }

  Future<_GeomancyInterpretationResult> _generateBhriguReading({
    required String question,
    required GeomancyChartModel chart,
    required String answer,
    required String aiResponseLanguage,
  }) async {
    final birthData = await _getBirthData();

    try {
      final idToken = await _session.idToken();

      if (idToken == null) {
        return _GeomancyInterpretationResult(
          text: _fallbackReading(
            question,
            chart,
            answer,
            aiResponseLanguage: aiResponseLanguage,
          ),
          aiResponseLanguage: aiResponseLanguage,
        );
      }

      final callable = _functions.httpsCallable(
        'generateGeomancyReading',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 120),
        ),
      );

      final response = await callable.call(
        {
          'idToken': idToken,
          'question': question,
          'birthData': birthData,
          'answer': answer,
          'chart': {
            'judge': {
              'name': chart.judge.name,
              'latinName': chart.judge.latinName,
              'meaning': chart.judge.meaning,
            },
            'leftWitness': {
              'name': chart.leftWitness.name,
              'meaning': chart.leftWitness.meaning,
            },
            'rightWitness': {
              'name': chart.rightWitness.name,
              'meaning': chart.rightWitness.meaning,
            },
            'reconciler': {
              'name': chart.reconciler.name,
              'meaning': chart.reconciler.meaning,
            },
          },
          'aiResponseLanguage': aiResponseLanguage,
        },
      );

      final data = Map<String, dynamic>.from(
        response.data as Map,
      );
      final responseLanguage = normalizeAiResponseLanguage(
        data['aiResponseLanguage'] ?? aiResponseLanguage,
      );

      return _GeomancyInterpretationResult(
        text: data['text'] as String? ??
            _fallbackReading(
              question,
              chart,
              answer,
              aiResponseLanguage: responseLanguage,
            ),
        aiResponseLanguage: responseLanguage,
      );
    } catch (e) {
      debugPrint('Geomancy Groq error: $e');
      return _GeomancyInterpretationResult(
        text: _fallbackReading(
          question,
          chart,
          answer,
          aiResponseLanguage: aiResponseLanguage,
        ),
        aiResponseLanguage: aiResponseLanguage,
      );
    }
  }

  Future<String> _getBirthData() async {
    try {
      final data = await UserProfileCacheService.instance.userData();
      if (data == null) return 'Birth data not available.';

      return 'Name: ${data['name'] ?? 'Unknown'}, DOB: ${data['dob'] ?? 'Unknown'}, Time: ${data['timeOfBirth'] ?? 'Unknown'}, Place: ${data['placeOfBirth'] ?? 'Unknown'}';
    } catch (e) {
      return 'Birth data not available.';
    }
  }

  Future<void> saveReading({
    required GeomancyReadingModel reading,
    required List<int> lineValues,
    String aiResponseLanguage = englishAiResponseLanguage,
  }) async {
    try {
      final uid = await _session.userId();

      if (uid == null || uid.isEmpty) {
        throw Exception('User not signed in');
      }

      final signature =
          '${normalizeAiResponseLanguage(aiResponseLanguage)}|${reading.question}|${lineValues.join(',')}|${reading.chart.judge.name}|${reading.answer}';

      if (_lastSavedSignature == signature) {
        return;
      }

      _lastSavedSignature = signature;

      final savedReading = GeomancySavedReading(
        id: '',
        reading: reading,
        lineValues: List<int>.from(lineValues),
        createdAt: DateTime.now(),
        aiResponseLanguage: aiResponseLanguage,
      );

      final ref = _firestore
          .collection('users')
          .doc(uid)
          .collection('geomancy_readings');

      await ref.add(savedReading.toJson());
      await _pruneSavedReadings(
        ref,
        aiResponseLanguage: aiResponseLanguage,
      );
    } catch (e) {
      debugPrint('Save geomancy reading error: $e');
    }
  }

  Future<List<GeomancySavedReading>> getSavedReadings() async {
    try {
      final uid = await _session.userId();

      if (uid == null || uid.isEmpty) {
        throw Exception('User not signed in');
      }

      final ref = _firestore
          .collection('users')
          .doc(uid)
          .collection('geomancy_readings');

      final snap = await ref.orderBy('createdAt', descending: true).get();

      final aiResponseLanguage = await UserProfileCacheService.instance
          .aiResponseLanguage(refresh: true);
      await _pruneSavedReadings(
        ref,
        orderedDocs: snap.docs,
        aiResponseLanguage: aiResponseLanguage,
      );

      return snap.docs
          .map((doc) {
            return GeomancySavedReading.fromJson(
              id: doc.id,
              json: doc.data(),
            );
          })
          .where(
            (reading) => reading.aiResponseLanguage == aiResponseLanguage,
          )
          .take(_savedReadingLimit)
          .toList();
    } catch (e) {
      debugPrint('Get geomancy readings error: $e');
      return [];
    }
  }

  Future<void> clearSavedReadings() async {
    final uid = await _session.userId();

    if (uid == null || uid.isEmpty) {
      throw Exception('User not signed in');
    }

    final ref =
        _firestore.collection('users').doc(uid).collection('geomancy_readings');

    final snap = await ref.get();

    final batch = _firestore.batch();

    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
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

      var batch = _firestore.batch();
      var writes = 0;

      for (final doc in oldDocs) {
        batch.delete(doc.reference);
        writes++;

        if (writes == _firestoreBatchWriteLimit) {
          await batch.commit();
          batch = _firestore.batch();
          writes = 0;
        }
      }

      if (writes > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Prune geomancy readings error: $e');
    }
  }

  String _fallbackReading(
    String question,
    GeomancyChartModel chart,
    String answer, {
    String aiResponseLanguage = englishAiResponseLanguage,
  }) {
    final q = question.trim().isEmpty ? 'your question' : question.trim();

    if (normalizeAiResponseLanguage(aiResponseLanguage) ==
        hinglishAiResponseLanguage) {
      return '''
DIRECT ANSWER
$q ke liye Judge ${chart.judge.name} hai, isliye answer hai: $answer. Yeh random sign nahi hai; aapki sixteen lines se bana hua final signal hai.

THE JUDGE
${chart.judge.name}, ${chart.judge.latinName}, matter ki main force dikhata hai. ${chart.judge.meaning} Isse main verdict samjho, poori kahani nahi.

THE WITNESSES
Left Witness, ${chart.leftWitness.name}, situation mein already active force dikhata hai. Right Witness, ${chart.rightWitness.name}, batata hai ki kya approach kar raha hai ya abhi form ho raha hai. Dono milkar answer ke peeche ki movement explain karte hain.

THE RECONCILER
Reconciler, ${chart.reconciler.name}, deeper lesson dikhata hai: ${chart.reconciler.meaning} Is answer ko impulse se nahi, steady judgement se use karo.

CLOSING
Pattern ne itna clearly bol diya hai ki aap next step zyada grounded tareeke se le sakte ho.
'''
          .trim();
    }

    return '''
DIRECT ANSWER
For $q, the Judge is ${chart.judge.name}, so the answer is $answer. This is not a random sign; it is the final voice formed from your sixteen lines.

THE JUDGE
${chart.judge.name}, ${chart.judge.latinName}, shows the central force of the matter. ${chart.judge.meaning} Treat this as the main verdict, not as the whole story.

THE WITNESSES
The Left Witness, ${chart.leftWitness.name}, shows the force already active in the situation. The Right Witness, ${chart.rightWitness.name}, shows what is approaching, responding, or still forming. Together, they describe the movement behind the answer.

THE RECONCILER
The Reconciler, ${chart.reconciler.name}, reveals the deeper lesson: ${chart.reconciler.meaning} Let the answer guide your next step with patience, not impulse.

CLOSING
The pattern has spoken clearly enough for you to move with steadier judgment.
'''
        .trim();
  }
}
