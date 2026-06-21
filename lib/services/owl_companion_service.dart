import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../constants/firebase_constants.dart';
import '../models/owl_companion_state.dart';
import '../utils/cloud_function_error_messages.dart';

/// Manages the owl companion state in Firestore.
///
/// Document path: `users/{uid}/owlCompanion/state`
class OwlCompanionService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  OwlCompanionService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: firebaseFunctionsRegion);

  DocumentReference<Map<String, dynamic>> _stateRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('owlCompanion')
        .doc('state');
  }

  /// Load the owl companion state. Missing documents use local defaults until
  /// the backend creates server-managed progress on the first pet.
  Future<OwlCompanionState> loadOwlState(String uid) async {
    try {
      final doc = await _stateRef(uid).get();

      if (doc.exists && doc.data() != null) {
        return OwlCompanionState.fromMap(doc.data()!);
      }

      return const OwlCompanionState();
    } catch (e) {
      debugPrint('OwlCompanionService.loadOwlState error: $e');
      return const OwlCompanionState.empty();
    }
  }

  /// Pet the owl. Returns a [PetResult] with the updated state and a message.
  Future<PetResult> petOwl(String uid) async {
    try {
      final response = await _functions.httpsCallable('petOwlCompanion').call();
      final data = _mapFromValue(response.data);
      final state = OwlCompanionState.fromMap(
        _mapFromValue(data?['state']) ?? const <String, dynamic>{},
      );

      return PetResult(
        state: state,
        success: data?['success'] == true,
        rewardType: data?['rewardType']?.toString(),
        readingCreditsGranted: _intFromValue(data?['readingCreditsGranted']),
        message: data?['message']?.toString() ?? 'Hoot.',
      );
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('OwlCompanionService.petOwl function code: ${e.code}');
        debugPrint('OwlCompanionService.petOwl function message: ${e.message}');
        debugPrint('OwlCompanionService.petOwl function details: ${e.details}');
      }
      return PetResult(
        state: const OwlCompanionState.empty(),
        success: false,
        message: functionErrorMessage(
          e,
          fallback: 'Could not pet the owl. Please try again.',
        ),
      );
    } catch (e) {
      debugPrint('OwlCompanionService.petOwl error: $e');
      return const PetResult(
        state: OwlCompanionState.empty(),
        success: false,
        message: 'The owl seems restless. Please try again.',
      );
    }
  }

  /// Claim the available reward.
  Future<OwlRewardClaimResult> claimReward(String uid) async {
    try {
      final response =
          await _functions.httpsCallable('claimOwlMoonReward').call();
      final data = _mapFromValue(response.data);
      final state = OwlCompanionState.fromMap(
        _mapFromValue(data?['state']) ?? const <String, dynamic>{},
      );

      return OwlRewardClaimResult(
        state: state,
        success: true,
        claimed: data?['claimed'] == true,
        rewardType: data?['rewardType']?.toString(),
        chatMessagesGranted: _intFromValue(data?['chatMessagesGranted']),
        readingCreditsGranted: _intFromValue(data?['readingCreditsGranted']),
        message: data?['message']?.toString() ?? 'Gift opened.',
      );
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('OwlCompanionService.claimReward function code: ${e.code}');
        debugPrint(
          'OwlCompanionService.claimReward function message: ${e.message}',
        );
        debugPrint(
            'OwlCompanionService.claimReward function details: ${e.details}');
      }
      return OwlRewardClaimResult(
        state: const OwlCompanionState.empty(),
        success: false,
        claimed: false,
        rewardType: null,
        chatMessagesGranted: 0,
        readingCreditsGranted: 0,
        message: functionErrorMessage(
          e,
          fallback: 'Could not open gift. Try again.',
        ),
      );
    } catch (e) {
      debugPrint('OwlCompanionService.claimReward error: $e');
      return const OwlRewardClaimResult(
        state: OwlCompanionState.empty(),
        success: false,
        claimed: false,
        rewardType: null,
        chatMessagesGranted: 0,
        readingCreditsGranted: 0,
        message: 'Could not open gift. Try again.',
      );
    }
  }

  /// Update the owl's custom name.
  Future<OwlCompanionState> updateOwlName(String uid, String newName) async {
    try {
      final trimmedName = newName.trim();
      if (trimmedName.isEmpty) return await loadOwlState(uid);

      await _stateRef(uid).set({
        'owlName': trimmedName,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      return await loadOwlState(uid);
    } catch (e) {
      debugPrint('OwlCompanionService.updateOwlName error: $e');
      return const OwlCompanionState.empty();
    }
  }
}

Map<String, dynamic>? _mapFromValue(dynamic value) {
  if (value is! Map) return null;

  return value.map(
    (key, mapValue) => MapEntry(key.toString(), mapValue),
  );
}

int _intFromValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
