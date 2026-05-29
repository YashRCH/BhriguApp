import 'partner_match_model.dart';
import 'payment_feature.dart';

class PartnerMatchFlow {
  final PartnerMatchReading? reading;
  final bool loading;
  final bool isFreshReading;
  final bool creatingFollowUp;
  final bool isRevealed;

  const PartnerMatchFlow({
    required this.reading,
    required this.loading,
    required this.isFreshReading,
    required this.creatingFollowUp,
    required this.isRevealed,
  });

  factory PartnerMatchFlow.initial() {
    return const PartnerMatchFlow(
      reading: null,
      loading: false,
      isFreshReading: false,
      creatingFollowUp: false,
      isRevealed: false,
    );
  }

  PaymentFeature get paymentFeature => PaymentFeature.partnerMatch;

  bool get hasReading => reading != null;

  bool get canFollowUp {
    return reading != null && isFreshReading && !creatingFollowUp;
  }

  PartnerMatchFlow copyWith({
    PartnerMatchReading? reading,
    bool? loading,
    bool? isFreshReading,
    bool? creatingFollowUp,
    bool? isRevealed,
  }) {
    return PartnerMatchFlow(
      reading: reading ?? this.reading,
      loading: loading ?? this.loading,
      isFreshReading: isFreshReading ?? this.isFreshReading,
      creatingFollowUp: creatingFollowUp ?? this.creatingFollowUp,
      isRevealed: isRevealed ?? this.isRevealed,
    );
  }

  PartnerMatchFlow beginReading() {
    return const PartnerMatchFlow(
      reading: null,
      loading: true,
      isFreshReading: false,
      creatingFollowUp: false,
      isRevealed: false,
    );
  }

  PartnerMatchFlow completeReading(PartnerMatchReading nextReading) {
    return PartnerMatchFlow(
      reading: nextReading,
      loading: false,
      isFreshReading: true,
      creatingFollowUp: false,
      isRevealed: true,
    );
  }

  PartnerMatchFlow loadSaved(PartnerMatchReading savedReading) {
    return PartnerMatchFlow(
      reading: savedReading,
      loading: false,
      isFreshReading: false,
      creatingFollowUp: false,
      isRevealed: true,
    );
  }

  PartnerMatchFlow reveal() {
    return copyWith(isRevealed: true);
  }

  PartnerMatchFlow withFollowUpLoading(bool loading) {
    return copyWith(creatingFollowUp: loading);
  }

  Map<String, dynamic> followUpSourceData() {
    final currentReading = reading;

    if (currentReading == null) return {};

    final scores = currentReading.scores;
    final marriage = currentReading.marriageGunaMatch;

    return {
      'user': {
        'name': currentReading.user.name,
        'dob': currentReading.user.dob.toString(),
        'timeOfBirth': currentReading.user.timeOfBirth,
        'placeOfBirth': currentReading.user.placeOfBirth,
        'latitude': currentReading.user.latitude,
        'longitude': currentReading.user.longitude,
      },
      'partner': {
        'name': currentReading.partner.name,
        'dob': currentReading.partner.dob.toString(),
        'timeOfBirth': currentReading.partner.timeOfBirth,
        'placeOfBirth': currentReading.partner.placeOfBirth,
        'latitude': currentReading.partner.latitude,
        'longitude': currentReading.partner.longitude,
        'emotionalPrompt': currentReading.partner.emotionalPrompt,
      },
      'signatures': {
        'userSunSign': currentReading.userSunSign,
        'userMoonStyle': currentReading.userMoonStyle,
        'partnerSunSign': currentReading.partnerSunSign,
        'partnerMoonStyle': currentReading.partnerMoonStyle,
      },
      'scores': {
        'overall': scores.overall,
        'emotional': scores.emotional,
        'attraction': scores.attraction,
        'communication': scores.communication,
        'stability': scores.stability,
        'karmic': scores.karmic,
      },
      'connectionType': currentReading.connectionType,
      'verdict': currentReading.verdict,
      'summary': currentReading.summary,
      'marriageGunaMatch': {
        'totalScore': marriage.totalScore,
        'maxScore': marriage.maxScore,
        'percentage': marriage.percentage,
        'level': marriage.level,
        'summary': marriage.summary,
        'items': marriage.items
            .map(
              (item) => {
                'name': item.name,
                'meaning': item.meaning,
                'score': item.score,
                'maxScore': item.maxScore,
              },
            )
            .toList(),
      },
      'createdAt': currentReading.createdAt.toIso8601String(),
      'freshReadingOnly': true,
    };
  }
}
