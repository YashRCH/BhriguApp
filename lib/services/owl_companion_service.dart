import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/owl_companion_state.dart';
import '../utils/date_keys.dart';

/// Manages the owl companion state in Firestore.
///
/// Document path: `users/{uid}/owlCompanion/state`
class OwlCompanionService {
  final FirebaseFirestore _firestore;

  OwlCompanionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _stateRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('owlCompanion').doc('state');
  }

  /// Load the owl companion state. Creates a default document if missing.
  Future<OwlCompanionState> loadOwlState(String uid) async {
    try {
      final doc = await _stateRef(uid).get();

      if (doc.exists && doc.data() != null) {
        return OwlCompanionState.fromMap(doc.data()!);
      }

      // Create default state
      const defaultState = OwlCompanionState();
      await _stateRef(uid).set(defaultState.toMap());
      return defaultState;
    } catch (e) {
      debugPrint('OwlCompanionService.loadOwlState error: $e');
      return const OwlCompanionState.empty();
    }
  }

  /// Pet the owl. Returns a [PetResult] with the updated state and a message.
  Future<PetResult> petOwl(String uid) async {
    try {
      final doc = await _stateRef(uid).get();
      final state = doc.exists && doc.data() != null
          ? OwlCompanionState.fromMap(doc.data()!)
          : const OwlCompanionState();

      final today = formatDateKey(DateTime.now());

      // Petting is unlimited, but the Moon Bond only fills once a day.
      int newProgress = state.petProgress;
      bool newRewardAvailable = state.rewardAvailable;

      if (state.lastPetDate != today && !state.rewardAvailable) {
        newProgress += 1;
        if (newProgress >= 4) {
          newProgress = 0;
          newRewardAvailable = true;
        }
      }

      final updatedState = state.copyWith(
        petProgress: newProgress,
        lastPetDate: today,
        rewardAvailable: newRewardAvailable,
        updatedAt: DateTime.now(),
      );

      await _stateRef(uid).set(updatedState.toMap(), SetOptions(merge: true));

      return PetResult(
        state: updatedState,
        success: true,
        message: 'Hoot.',
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
  Future<OwlCompanionState> claimReward(String uid) async {
    try {
      final doc = await _stateRef(uid).get();
      final state = doc.exists && doc.data() != null
          ? OwlCompanionState.fromMap(doc.data()!)
          : const OwlCompanionState();

      if (!state.rewardAvailable) {
        return state;
      }

      final updatedState = state.copyWith(
        rewardAvailable: false,
        rewardClaimedCount: state.rewardClaimedCount + 1,
        updatedAt: DateTime.now(),
      );

      await _stateRef(uid).set(updatedState.toMap(), SetOptions(merge: true));

      return updatedState;
    } catch (e) {
      debugPrint('OwlCompanionService.claimReward error: $e');
      return const OwlCompanionState.empty();
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
