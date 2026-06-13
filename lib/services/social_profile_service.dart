import 'package:cloud_functions/cloud_functions.dart';

import '../constants/firebase_constants.dart';
import '../models/social_connection_model.dart';

class SocialProfileService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );

  Future<PublicAstrologyProfile> createOrUpdatePublicProfile({
    required String username,
    Map<String, dynamic>? onboardingUserData,
  }) async {
    final callable = _functions.httpsCallable('createOrUpdatePublicProfile');
    final payload = <String, dynamic>{'username': username};

    if (onboardingUserData != null) {
      payload['onboardingUserData'] = onboardingUserData;
    }

    final result = await callable.call(payload);
    final data = Map<String, dynamic>.from(result.data as Map);

    return PublicAstrologyProfile.fromMap(
      Map<String, dynamic>.from(data['profile'] as Map),
    );
  }

  Future<List<PublicAstrologyProfile>> searchPublicProfiles(
    String username,
  ) async {
    final query = username.trim();
    if (query.isEmpty) return [];

    final callable = _functions.httpsCallable('searchPublicProfiles');
    final result = await callable.call({'username': query});
    final data = Map<String, dynamic>.from(result.data as Map);
    final profiles = (data['profiles'] as List?) ?? const [];

    return profiles
        .whereType<Map>()
        .map(
          (profile) => PublicAstrologyProfile.fromMap(
            Map<String, dynamic>.from(profile),
          ),
        )
        .toList(growable: false);
  }
}
