import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../constants/firebase_constants.dart';
import '../models/vedic_chart_model.dart';
import '../models/western_chart_model.dart';
import 'cosmic_chart_calculator.dart';
import 'firebase_session_service.dart';

class AstrologyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );
  final FirebaseSessionService _session =
      FirebaseSessionService(debugLabel: 'Natal chart');
  final CosmicChartCalculator _calculator = const CosmicChartCalculator();

  Future<void> generateAndSaveCharts({
    required String uid,
    required DateTime birthDate,
    String timeOfBirth = '',
    String placeOfBirth = '',
    double? latitude,
    double? longitude,
  }) async {
    try {
      final user = await _session.currentUserOrWait();

      if (user == null || user.uid != uid) {
        throw StateError('Firebase ID token is unavailable.');
      }

      final callable = _functions.httpsCallable(
        'calculateNatalChart',
        options: HttpsCallableOptions(
          timeout: const Duration(
            seconds: 180,
          ),
        ),
      );
      final result = await callable.call(
        {
          'birthDate': birthDate.toIso8601String(),
          'timeOfBirth': timeOfBirth,
          'placeOfBirth': placeOfBirth,
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      final data = Map<String, dynamic>.from(result.data as Map);
      final westernChart = data['westernChart'];
      final vedicChart = data['vedicChart'];

      if (westernChart is Map && vedicChart is Map) return;

      return;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('calculateNatalChart function code: ${e.code}');
      debugPrint('calculateNatalChart function message: ${e.message}');
      debugPrint('calculateNatalChart function details: ${e.details}');
    } catch (e, stack) {
      debugPrint('calculateNatalChart unavailable, using fallback: $e');
      debugPrint('Stack: $stack');
    }

    _generateFallbackCharts(
      birthDate: birthDate,
      timeOfBirth: timeOfBirth,
      placeOfBirth: placeOfBirth,
      latitude: latitude,
      longitude: longitude,
    );
  }

  void _generateFallbackCharts({
    required DateTime birthDate,
    required String timeOfBirth,
    required String placeOfBirth,
    required double? latitude,
    required double? longitude,
  }) async {
    final charts = _calculator.calculate(
      birthDate: birthDate,
      timeOfBirth: timeOfBirth,
      placeOfBirth: placeOfBirth,
      latitude: latitude,
      longitude: longitude,
    );

    debugPrint(
      'Local fallback chart calculated but not persisted; chart fields are server-owned. '
      'Western=${charts.westernChart.sunSign}, Vedic=${charts.vedicChart.moonSign}',
    );
  }

  Future<WesternChartModel?> getWesternChart(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null || data['westernChart'] == null) return null;

    return WesternChartModel.fromJson(
      Map<String, dynamic>.from(data['westernChart']),
    );
  }

  Future<VedicChartModel?> getVedicChart(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null || data['vedicChart'] == null) return null;

    return VedicChartModel.fromJson(
      Map<String, dynamic>.from(data['vedicChart']),
    );
  }
}
