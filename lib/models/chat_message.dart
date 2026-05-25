import '../constants/ai_response_language.dart';

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final String aiResponseLanguage;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    dynamic aiResponseLanguage = englishAiResponseLanguage,
  })  : timestamp = timestamp ?? DateTime.now(),
        aiResponseLanguage = normalizeAiResponseLanguage(aiResponseLanguage);

  Map<String, dynamic> toGroq() => {
        'role': role,
        'content': content,
      };
}
