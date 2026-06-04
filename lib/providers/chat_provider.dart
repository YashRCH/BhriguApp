import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ai_response_language.dart';
import '../models/chat_message.dart';
import '../services/firebase_session_service.dart';
import '../services/user_profile_cache_service.dart';

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final FirebaseSessionService _session =
      FirebaseSessionService(debugLabel: 'Chat history');
  String _activeLanguage = englishAiResponseLanguage;

  ChatNotifier() : super([]) {
    _load();
  }

  Future<String?> _uid() async => _session.userId();

  Future<void> _load() async {
    final uid = await _uid();

    if (uid == null) return;

    try {
      _activeLanguage = await UserProfileCacheService.instance
          .aiResponseLanguage(refresh: true);

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat')
          .orderBy('timestamp')
          .limit(50)
          .get();

      final messages = <ChatMessage>[];

      for (final d in snap.docs) {
        final data = d.data();
        final message = _messageFromData(data);

        if (message != null && message.aiResponseLanguage == _activeLanguage) {
          messages.add(message);
        }
      }

      state = messages;
    } catch (_) {
      state = [];
    }
  }

  ChatMessage? _messageFromData(Map<String, dynamic> data) {
    final role = data['role'];
    final content = data['content'];
    final timestampValue = data['timestamp'];

    if (role is! String || content is! String) {
      return null;
    }

    // Handle both ISO string timestamps (saved by client) and Firestore
    // Timestamp objects (returned by the SDK for server-written fields).
    DateTime? timestamp;
    if (timestampValue is String) {
      timestamp = DateTime.tryParse(timestampValue);
    } else if (timestampValue is Timestamp) {
      timestamp = timestampValue.toDate();
    }

    if (timestamp == null) return null;

    return ChatMessage(
      role: role,
      content: content,
      timestamp: timestamp,
      aiResponseLanguage: data['aiResponseLanguage'],
    );
  }

  Future<String> ensureActiveLanguage() async {
    final language =
        await UserProfileCacheService.instance.aiResponseLanguage();

    if (language != _activeLanguage) {
      _activeLanguage = language;
      state = [];
      await _load();
    }

    return _activeLanguage;
  }

  Future<void> _save(ChatMessage msg) async {
    final uid = await _uid();

    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chat')
        .add({
      'role': msg.role,
      'content': msg.content,
      'timestamp': msg.timestamp.toIso8601String(),
      'aiResponseLanguage': msg.aiResponseLanguage,
    });
  }

  void addMessage(ChatMessage msg) {
    state = [...state, msg];

    if (msg.role == 'user') {
      unawaited(
        _save(msg).catchError((Object e) {
          debugPrint('Save chat message error: $e');
        }),
      );
    }
  }

  void updateLast(String content) {
    if (state.isEmpty) return;

    final updated = List<ChatMessage>.from(state);
    final previous = updated.last;

    if (previous.role != 'assistant') return;

    updated[updated.length - 1] = ChatMessage(
      role: 'assistant',
      content: content,
      timestamp: previous.timestamp,
      aiResponseLanguage: _activeLanguage,
    );

    state = updated;
  }

  Future<void> finalizeLastMessage(String content) async {
    updateLast(content);

    if (content.trim().isEmpty) return;

    final uid = await _uid();

    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat')
          .add({
        'role': 'assistant',
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
        'aiResponseLanguage': _activeLanguage,
      });
    } catch (e) {
      debugPrint('Save assistant chat message error: $e');
    }
  }

  Future<void> clear() async {
    final oldState = state;

    state = [];

    final uid = await _uid();

    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat')
          .get();

      if (snap.docs.isEmpty) return;

      var batch = FirebaseFirestore.instance.batch();
      var pendingDeletes = 0;

      for (final doc in snap.docs) {
        if (normalizeAiResponseLanguage(doc.data()['aiResponseLanguage']) ==
            _activeLanguage) {
          batch.delete(doc.reference);
          pendingDeletes++;

          if (pendingDeletes >= 450) {
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
            pendingDeletes = 0;
          }
        }
      }

      if (pendingDeletes > 0) {
        await batch.commit();
      }
    } catch (_) {
      state = oldState;
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>(
  (ref) => ChatNotifier(),
);
