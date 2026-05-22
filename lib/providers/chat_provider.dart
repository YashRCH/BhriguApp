import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/chat_message.dart';

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final _storage = const FlutterSecureStorage();

  ChatNotifier() : super([]) {
    _load();
  }

  Future<String?> _uid() => _storage.read(key: 'user_id');

  Future<void> _load() async {
    final uid = await _uid();

    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat')
          .orderBy('timestamp')
          .limit(50)
          .get();

      state = snap.docs
          .map(
            (d) => ChatMessage(
              role: d['role'] as String,
              content: d['content'] as String,
              timestamp: DateTime.parse(d['timestamp'] as String),
            ),
          )
          .toList();
    } catch (_) {
      state = [];
    }
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

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (_) {
      state = oldState;
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>(
  (ref) => ChatNotifier(),
);