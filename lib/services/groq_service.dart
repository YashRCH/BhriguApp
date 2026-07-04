import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_messages.dart';
import '../constants/ai_response_language.dart';
import '../constants/firebase_constants.dart';
import '../models/chat_message.dart';
import '../models/follow_up_context_model.dart';
import '../utils/cloud_function_error_messages.dart';
import 'firebase_session_service.dart';
import 'user_profile_cache_service.dart';

class GroqService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );

  final FirebaseSessionService _session =
      FirebaseSessionService(debugLabel: 'Bhrigu chat');

  Stream<String> streamMessage(
    List<ChatMessage> history, {
    FollowUpContext? followUpContext,
    void Function(String message)? onFeatureAccessBlocked,
  }) async* {
    final user = await _session.currentUserOrWait();

    if (user == null) {
      debugPrint('Bhrigu chat blocked: FirebaseAuth.currentUser is null');
      yield cosmicConnectionLostMessage;
      return;
    }

    debugPrint('Firebase session ready for Bhrigu chat.');

    final lastUserMessage = history.isNotEmpty
        ? history
            .lastWhere(
              (m) => m.role == 'user',
              orElse: () => ChatMessage(
                role: 'user',
                content: '',
              ),
            )
            .content
        : '';
    final aiResponseLanguage = await UserProfileCacheService.instance
        .aiResponseLanguage(refresh: true);

    if (lastUserMessage.trim().isEmpty) {
      debugPrint('Bhrigu chat blocked: last user message is empty');
      yield cosmicConnectionLostMessage;
      return;
    }

    final safeHistory = history
        .where((m) => m.content.trim().isNotEmpty)
        .where((m) => m.aiResponseLanguage == aiResponseLanguage)
        .map(
          (m) => {
            'role': m.role,
            'content': m.content,
            'aiResponseLanguage': m.aiResponseLanguage,
          },
        )
        .toList();

    final payload = <String, dynamic>{
      'message': lastUserMessage,
      'history': safeHistory,
      'aiResponseLanguage': aiResponseLanguage,
    };

    if (followUpContext != null) {
      payload['followUpContext'] = _followUpContextPayload(followUpContext);

      debugPrint(
        'Sending follow-up context to Bhrigu chat: ${followUpContext.sourceType} / ${followUpContext.id}',
      );
    }

    try {
      final callable = _functions.httpsCallable(
        'generateBhriguChat',
        // The function runs up to 120s server-side; the SDK default of 70s
        // made the client report a lost connection while the server finished
        // (and charged) anyway.
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 180),
        ),
      );

      debugPrint('Calling Bhrigu chat function.');

      final result = await callable.call(payload);

      final data = Map<String, dynamic>.from(
        result.data as Map,
      );

      final text = data['text'] as String? ?? '';

      if (text.trim().isEmpty) {
        debugPrint('Bhrigu chat returned empty response');
        yield cosmicConnectionLostMessage;
        return;
      }

      // Reveal word-by-word rather than character-by-character so the text is
      // easier to read and triggers far fewer scroll updates on screen. The
      // regex keeps each word together with its trailing whitespace, so blank
      // lines and paragraph breaks in the response are preserved.
      final buffer = StringBuffer();

      for (final match in RegExp(r'\S+\s*').allMatches(text)) {
        buffer.write(match.group(0));

        yield buffer.toString();

        await Future.delayed(
          const Duration(milliseconds: 30),
        );
      }

      // Safety net: if anything was missed (e.g. leading whitespace), make sure
      // the final yielded value is the complete text.
      if (buffer.toString() != text) {
        yield text;
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('Cloud Function error code: ${e.code}');
        debugPrint('Cloud Function error message: ${e.message}');
        debugPrint('Cloud Function error details: ${e.details}');
      }

      if (isFeatureAccessException(e)) {
        onFeatureAccessBlocked?.call(functionErrorMessage(e));
      }

      yield functionErrorMessage(e);
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('Unknown Bhrigu chat error: $e');
        debugPrint('Stack: $stack');
      }

      yield cosmicConnectionLostMessage;
    }
  }

  Map<String, dynamic> _followUpContextPayload(
    FollowUpContext context,
  ) {
    return {
      'id': context.id,
      'uid': context.uid,
      'sourceType': context.sourceType,
      'originalQuestion': context.originalQuestion,
      'selectedFollowUpQuestion': context.selectedFollowUpQuestion,
      'readingTitle': context.readingTitle,
      'readingSummary': context.readingSummary,
      'sourceData': _sanitizeMap(context.sourceData),
      'userSnapshot': _sanitizeMap(context.userSnapshot),
      'createdAt': context.createdAt.toIso8601String(),
      'aiResponseLanguage': normalizeAiResponseLanguage(
        context.aiResponseLanguage,
      ),
    };
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> input) {
    final output = <String, dynamic>{};

    input.forEach((key, value) {
      output[key] = _sanitizeValue(value);
    });

    return output;
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value == null) return null;

    if (value is String || value is num || value is bool) {
      return value;
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is List) {
      return value.map(_sanitizeValue).toList();
    }

    if (value is Map) {
      final cleaned = <String, dynamic>{};

      value.forEach((dynamic key, dynamic mapValue) {
        cleaned[key.toString()] = _sanitizeValue(mapValue);
      });

      return cleaned;
    }

    return value.toString();
  }
}
