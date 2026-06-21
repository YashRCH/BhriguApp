import 'package:cloud_functions/cloud_functions.dart';

import '../constants/app_messages.dart';

class FeatureAccessException implements Exception {
  const FeatureAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool isFeatureAccessException(FirebaseFunctionsException error) {
  final message = (error.message ?? '').toLowerCase();

  return error.code == 'resource-exhausted' ||
      message.contains('bhrigu plus') ||
      message.contains('dakshana') ||
      message.contains('monthly limit');
}

String functionErrorMessage(
  FirebaseFunctionsException error, {
  String fallback = cosmicConnectionLostMessage,
}) {
  final message = (error.message ?? '').trim();

  if (isFeatureAccessException(error)) {
    if (message.toLowerCase().contains('monthly limit')) {
      return 'Quota exhausted. $message See plans to continue.';
    }

    if (message.isNotEmpty) {
      return '$message See plans to continue.';
    }

    return 'This feature needs Bhrigu Plus or Dakshana. See plans to continue.';
  }

  if (error.code == 'unauthenticated') {
    return 'Please sign in again to continue.';
  }

  if (error.code == 'permission-denied') {
    return 'This build could not pass app verification. Install from the Play testing link and try again.';
  }

  return fallback;
}

FeatureAccessException featureAccessExceptionFrom(
  FirebaseFunctionsException error,
) {
  return FeatureAccessException(functionErrorMessage(error));
}
