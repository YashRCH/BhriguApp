import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/firebase_constants.dart';
import '../models/social_connection_model.dart';

class CreatedInvite {
  final String code;
  final String inviteLink;
  final String appLink;

  const CreatedInvite({
    required this.code,
    required this.inviteLink,
    required this.appLink,
  });
}

class ConnectionService {
  // ─── Static cache ────────────────────────────────────────────────────────
  // Shared across all instances so the same data is served everywhere.
  // Cleared whenever the signed-in UID changes to prevent cross-user leaks.
  static final Map<String, SocialConnection> _connectionCache = {};
  static String? _cacheUid;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );

  String? get currentUid => _auth.currentUser?.uid;

  // ─── Watch connections stream ─────────────────────────────────────────────

  Stream<List<SocialConnection>> watchConnections() {
    final uid = currentUid;
    if (uid == null) {
      _connectionCache.clear();
      _cacheUid = null;
      return Stream.value(const []);
    }

    _prepareCacheForUid(uid);
    return _watchConnectionsForUid(uid);
  }

  Stream<List<SocialConnection>> _watchConnectionsForUid(String uid) async* {
    if (_connectionCache.isNotEmpty) {
      yield _sortedConnections(_connectionCache.values);
    }

    try {
      await for (final snap in _firestore
          .collection('users')
          .doc(uid)
          .collection('connections')
          .snapshots()) {
        final connections = snap.docs
            .map(SocialConnection.fromFirestore)
            .where(
              (connection) =>
                  connection.connectionId.isNotEmpty &&
                  connection.otherUid.isNotEmpty &&
                  // BUG-E FIXED: Never surface archived or blocked connections
                  // in the Circle list — they produce stale tiles after block/remove.
                  connection.status != SocialConnectionStatus.archived &&
                  connection.status != SocialConnectionStatus.blocked,
            )
            .toList(growable: false);

        _connectionCache
          ..clear()
          ..addEntries(
            connections.map(
              (connection) => MapEntry(
                connection.connectionId,
                connection,
              ),
            ),
          );

        yield _sortedConnections(connections);
      }
    } catch (e, stack) {
      debugPrint('Circle mirror sync failed: $e');
      debugPrintStack(stackTrace: stack);

      // FIXED: Only fall back to the shared-doc query for non-auth errors.
      // Permission-denied means the user is logged out or has no access;
      // in that case yield the cache and stop to avoid an infinite error loop.
      if (e is FirebaseException &&
          (e.code == 'permission-denied' || e.code == 'unauthenticated')) {
        yield _sortedConnections(_connectionCache.values);
        return;
      }

      yield* _watchSharedConnectionsForUid(uid);
    }
  }

  Stream<List<SocialConnection>> _watchSharedConnectionsForUid(
    String uid,
  ) async* {
    try {
      await for (final snap in _firestore
          .collection('connections')
          .where('memberIds', arrayContains: uid)
          .snapshots()) {
        final connections = await Future.wait(
          snap.docs.map(_connectionFromSharedDoc),
        );

        final visibleConnections = [
          ...connections.whereType<SocialConnection>(),
          ..._connectionCache.values.where((connection) {
            return connection.otherUid.isNotEmpty &&
                !_connectionExists(connections, connection.connectionId);
          }),
        ];

        yield _sortedConnections(visibleConnections);
      }
    } catch (e, stack) {
      debugPrint('Circle connection sync failed: $e');
      debugPrintStack(stackTrace: stack);

      yield _sortedConnections(_connectionCache.values);
    }
  }

  // ─── Single connection fetch ──────────────────────────────────────────────

  Future<SocialConnection?> getConnection(String connectionId) async {
    final uid = currentUid;
    if (uid == null) return null;

    _prepareCacheForUid(uid);

    // Guard: do not return a cached connection from a different UID.
    if (_cacheUid == uid && _connectionCache.containsKey(connectionId)) {
      final cached = _connectionCache[connectionId];
      if (cached != null && cached.otherUid.isNotEmpty) {
        // Still attempt a fresh fetch but return cache immediately.
        _refreshConnectionInBackground(connectionId, uid);
        return cached;
      }
    }

    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('connections')
          .where('connectionId', isEqualTo: connectionId)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final connection = SocialConnection.fromFirestore(snap.docs.first);
        _connectionCache[connection.connectionId] = connection;
        return connection;
      }
    } catch (e, stack) {
      debugPrint('User connection mirror read failed: $e');
      debugPrintStack(stackTrace: stack);
    }

    try {
      final connection = await getConnectionFromSharedDoc(connectionId);
      if (connection != null) {
        _connectionCache[connection.connectionId] = connection;
        return connection;
      }
    } catch (e, stack) {
      debugPrint('Shared connection read failed: $e');
      debugPrintStack(stackTrace: stack);
    }

    return _connectionCache[connectionId];
  }

  void _refreshConnectionInBackground(String connectionId, String uid) {
    _firestore
        .collection('users')
        .doc(uid)
        .collection('connections')
        .where('connectionId', isEqualTo: connectionId)
        .limit(1)
        .get()
        .then((snap) {
      if (snap.docs.isNotEmpty) {
        final connection = SocialConnection.fromFirestore(snap.docs.first);
        _connectionCache[connection.connectionId] = connection;
      }
    }).catchError((Object e) {
      debugPrint('Background connection refresh failed: $e');
    });
  }

  Future<SocialConnection?> getConnectionFromSharedDoc(
      String connectionId) async {
    final uid = currentUid;
    if (uid == null) return null;

    final doc =
        await _firestore.collection('connections').doc(connectionId).get();
    return _connectionFromSharedDoc(doc);
  }

  Future<SocialConnection?> _connectionFromSharedDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final uid = currentUid;
    if (uid == null) return null;

    final data = doc.data();
    if (!doc.exists || data == null) return null;

    final memberIds = (data['memberIds'] as List?)
            ?.map((item) => item.toString())
            .toList(growable: false) ??
        const <String>[];
    if (!memberIds.contains(uid)) return null;

    final otherUid = memberIds.firstWhere(
      (item) => item != uid,
      orElse: () => '',
    );
    if (otherUid.isEmpty) return null;

    final profiles = data['profiles'];
    final embeddedProfileData = profiles is Map && profiles[otherUid] is Map
        ? Map<String, dynamic>.from(profiles[otherUid] as Map)
        : null;
    final profileData = embeddedProfileData ??
        (await _firestore.collection('public_profiles').doc(otherUid).get())
            .data();
    final otherProfile = profileData == null
        ? PublicAstrologyProfile.empty(otherUid)
        : PublicAstrologyProfile.fromMap({
            ...profileData,
            'uid': otherUid,
          });

    return SocialConnection(
      connectionId: doc.id,
      otherUid: otherUid,
      relationshipType: SocialRelationshipType.fromValue(
        data['relationshipType'],
      ),
      status: _statusFromSharedConnection(data, uid),
      createdAt: _dateFromValue(data['createdAt']),
      acceptedAt: data['acceptedAt'] == null
          ? null
          : _dateFromValue(data['acceptedAt']),
      otherProfile: otherProfile,
    );
  }

  // ─── Mutation methods (all delegate to Cloud Functions) ───────────────────

  Future<void> sendConnectionRequest({
    required String targetUid,
    required SocialRelationshipType relationshipType,
  }) async {
    final callable = _functions.httpsCallable('sendConnectionRequest');
    await callable.call({
      'targetUid': targetUid,
      'relationshipType': relationshipType.value,
    });
  }

  Future<void> acceptConnectionRequest({
    required String requesterUid,
    // BUG-C FIXED: relationshipType removed — the server always uses the
    // stored value from the pending connection doc and ignores any client value.
  }) async {
    final callable = _functions.httpsCallable('acceptConnectionRequest');
    await callable.call({'requesterUid': requesterUid});
  }

  /// Decline an incoming connection request.
  /// Permanently deletes the pending connection and both mirror docs.
  Future<void> declineConnectionRequest({
    required String requesterUid,
  }) async {
    final callable = _functions.httpsCallable('declineConnectionRequest');
    await callable.call({'requesterUid': requesterUid});
  }

  /// Cancel an outgoing connection request that hasn't been accepted yet.
  /// Permanently deletes the pending connection and both mirror docs.
  Future<void> cancelConnectionRequest({
    required String targetUid,
  }) async {
    final callable = _functions.httpsCallable('cancelConnectionRequest');
    await callable.call({'targetUid': targetUid});
  }

  Future<void> removeConnection(String connectionId) async {
    final callable = _functions.httpsCallable('removeConnection');
    await callable.call({'connectionId': connectionId});
  }

  Future<void> blockConnection(String otherUid) async {
    final callable = _functions.httpsCallable('blockConnection');
    await callable.call({'otherUid': otherUid});
  }

  /// Switch the relationship type of an active connection.
  /// Wipes all existing compatibility readings and daily energy.
  Future<void> switchRelationshipType({
    required String connectionId,
    required SocialRelationshipType relationshipType,
  }) async {
    final callable = _functions.httpsCallable('switchRelationshipType');
    await callable.call({
      'connectionId': connectionId,
      'relationshipType': relationshipType.value,
    });
    _connectionCache.remove(connectionId);
  }

  Future<CreatedInvite> createInvite({
    required SocialRelationshipType relationshipType,
  }) async {
    final callable = _functions.httpsCallable('createInvite');
    final result = await callable.call({
      'relationshipType': relationshipType.value,
    });
    final data = Map<String, dynamic>.from(result.data as Map);

    final code = data['code'] as String? ?? '';

    return CreatedInvite(
      code: code,
      inviteLink: data['inviteLink'] as String? ??
          'https://astrology-guru-app.web.app/invite/$code',
      appLink: data['appLink'] as String? ?? 'bhrigu:///invite/$code',
    );
  }

  Future<String?> acceptInvite(String code) async {
    final uid = currentUid;
    if (uid != null) {
      _prepareCacheForUid(uid);
    }

    final callable = _functions.httpsCallable('acceptInvite');
    final result = await callable.call({'code': code.trim()});
    final data = result.data;

    if (data is Map) {
      final connection = _connectionFromCallableData(
        Map<String, dynamic>.from(data),
      );
      if (connection != null) {
        _connectionCache[connection.connectionId] = connection;
        return connection.connectionId;
      }

      return data['connectionId'] as String?;
    }

    return null;
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  SocialConnection? _connectionFromCallableData(Map<String, dynamic> data) {
    final uid = currentUid;
    if (uid == null) return null;

    _prepareCacheForUid(uid);

    final connectionData = data['connection'];
    if (connectionData is! Map) return null;

    final connection = Map<String, dynamic>.from(connectionData);
    final memberIds = (connection['memberIds'] as List?)
            ?.map((item) => item.toString())
            .toList(growable: false) ??
        const <String>[];
    if (!memberIds.contains(uid)) return null;

    final otherUid = memberIds.firstWhere(
      (item) => item != uid,
      orElse: () => '',
    );
    if (otherUid.isEmpty) return null;

    final profiles = connection['profiles'];
    final otherProfileData = profiles is Map && profiles[otherUid] is Map
        ? Map<String, dynamic>.from(profiles[otherUid] as Map)
        : null;

    // FIXED: Parse timestamps from the server response if present.
    // The server returns FieldValue.serverTimestamp() which arrives as null
    // in the callable response — use DateTime.now() only as a true last resort.
    final connectionId = data['connectionId'] as String? ??
        connection['connectionId'] as String? ??
        '';

    return SocialConnection(
      connectionId: connectionId,
      otherUid: otherUid,
      relationshipType: SocialRelationshipType.fromValue(
        connection['relationshipType'],
      ),
      status: SocialConnectionStatus.fromValue(connection['status']),
      // Server timestamps come back as null from callable responses — the
      // stream will immediately refresh with real values from Firestore.
      createdAt: DateTime.now(),
      acceptedAt: DateTime.now(),
      otherProfile: otherProfileData == null
          ? PublicAstrologyProfile.empty(otherUid)
          : PublicAstrologyProfile.fromMap({
              ...otherProfileData,
              'uid': otherUid,
            }),
    );
  }

  void _prepareCacheForUid(String uid) {
    if (_cacheUid == uid) return;

    _connectionCache.clear();
    _cacheUid = uid;
  }
}

// ─── Top-level helpers ────────────────────────────────────────────────────────

bool _connectionExists(
  List<SocialConnection?> connections,
  String connectionId,
) {
  return connections.any((connection) {
    return connection?.connectionId == connectionId;
  });
}

List<SocialConnection> _sortedConnections(
  Iterable<SocialConnection> connections,
) {
  return connections.toList(growable: false)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

DateTime _dateFromValue(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

SocialConnectionStatus _statusFromSharedConnection(
  Map<String, dynamic> data,
  String uid,
) {
  final status = data['status']?.toString().trim().toLowerCase();
  if (status == 'pending') {
    return data['recipientUid'] == uid
        ? SocialConnectionStatus.incoming
        : SocialConnectionStatus.outgoing;
  }

  return SocialConnectionStatus.fromValue(status);
}
