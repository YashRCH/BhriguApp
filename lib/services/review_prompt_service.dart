import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_review/in_app_review.dart';

/// Surfaces the Google Play in-app review flow once a user has gotten enough
/// value out of BHR1GU to exhaust their free readings. It is shown at most
/// once per install, ever.
///
/// IMPORTANT: this must never be wired to a reward (no Dakshana, credits, or
/// quota bumps). Google Play policy forbids incentivising ratings, and the
/// in-app review API deliberately does not report whether the user actually
/// reviewed — so there is nothing to reward against anyway.
class ReviewPromptService {
  ReviewPromptService._();

  static final ReviewPromptService instance = ReviewPromptService._();

  static const _shownKey = 'review_prompt_shown';

  // Let the paywall message land and the screen settle before the review card
  // appears, so the two don't fight for the screen at the same instant.
  static const _settleDelay = Duration(seconds: 1);

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final InAppReview _inAppReview = InAppReview.instance;

  bool _inFlight = false;

  /// Call when a user hits the paywall after using up their free readings.
  /// Safe to call fire-and-forget: it self-throttles to one prompt per install
  /// and never throws.
  Future<void> maybePromptAfterReadingsExhausted() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      if (await _storage.read(key: _shownKey) == 'true') return;

      await Future.delayed(_settleDelay);

      if (!await _inAppReview.isAvailable()) return;

      // Mark it shown *before* requesting. We can't observe whether the user
      // actually rated, and "one time" means one attempt — so we never want to
      // re-prompt even if this particular request gets throttled away.
      await _storage.write(key: _shownKey, value: 'true');

      await _inAppReview.requestReview();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Review prompt skipped: $e');
      }
    } finally {
      _inFlight = false;
    }
  }
}
