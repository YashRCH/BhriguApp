import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/firebase_constants.dart';
import '../models/vedic_chart_model.dart';
import '../models/western_chart_model.dart';
import 'cosmic_chart_calculator.dart';

class AstrologyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );
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
      final user = _auth.currentUser;
      final idToken = await user?.getIdToken();

      if (idToken == null || idToken.isEmpty) {
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
          'idToken': idToken,
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

      if (westernChart is Map && vedicChart is Map) {
        await _firestore.collection('users').doc(uid).update({
          'westernChart': Map<String, dynamic>.from(westernChart),
          'vedicChart': Map<String, dynamic>.from(vedicChart),
          'chartGeneratedBy': 'nasa_jpl_horizons',
          'chartGeneratedAt': FieldValue.serverTimestamp(),
          'chartCalculationSource': 'NASA/JPL Horizons API',
          'chartCalculationVersion': 'nasa_jpl_horizons_v4_observer_ecliptic',
        });
      }

      return;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('calculateNatalChart function code: ${e.code}');
      debugPrint('calculateNatalChart function message: ${e.message}');
      debugPrint('calculateNatalChart function details: ${e.details}');
    } catch (e, stack) {
      debugPrint('calculateNatalChart unavailable, using fallback: $e');
      debugPrint('Stack: $stack');
    }

    await _generateAndSaveFallbackCharts(
      uid: uid,
      birthDate: birthDate,
      timeOfBirth: timeOfBirth,
      placeOfBirth: placeOfBirth,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> _generateAndSaveFallbackCharts({
    required String uid,
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

    await _firestore.collection('users').doc(uid).update({
      'westernChart': charts.westernChart.toJson(),
      'vedicChart': charts.vedicChart.toJson(),
      'chartGeneratedBy': 'local_ephemeris_engine_fallback',
      'chartGeneratedAt': FieldValue.serverTimestamp(),
      'chartCalculationSource': 'Local fallback ephemeris engine',
      'chartCalculationVersion': 'local_ephemeris_engine_fallback_v1',
    });
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
