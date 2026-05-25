import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/ai_response_language.dart';
import '../models/chat_message.dart';
import '../services/user_profile_cache_service.dart';

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final _storage = const FlutterSecureStorage();
  String _activeLanguage = englishAiResponseLanguage;

  ChatNotifier() : super([]) {
    _load();
  }

  Future<String?> _uid() => _storage.read(key: 'user_id');

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

      state = snap.docs.where((d) {
        final data = d.data();
        return normalizeAiResponseLanguage(data['aiResponseLanguage']) ==
            _activeLanguage;
      }).map((d) {
        final data = d.data();
        return ChatMessage(
          role: data['role'] as String,
          content: data['content'] as String,
          timestamp: DateTime.parse(data['timestamp'] as String),
          aiResponseLanguage: data['aiResponseLanguage'] as String?,
        );
      }).toList();
    } catch (_) {
      state = [];
    }
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
      _save(msg);
    }
  }

  void updateLast(String content) {
    if (state.isEmpty) return;

    final updated = List<ChatMessage>.from(state);

    updated[updated.length - 1] = ChatMessage(
      role: 'assistant',
      content: content,
      aiResponseLanguage: _activeLanguage,
    );

    state = updated;
  }

  Future<void> finalizeLastMessage(String content) async {
    updateLast(content);

    final uid = await _uid();

    if (uid == null) return;

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
