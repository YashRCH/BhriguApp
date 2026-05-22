enum PaymentFeature {
  tarotReading,
  geomancyReading,
  partnerMatch,
  bhriguChat,
}

extension PaymentFeatureIds on PaymentFeature {
  String get productId {
    switch (this) {
      case PaymentFeature.tarotReading:
        return 'bhrigu.tarot.reading';
      case PaymentFeature.geomancyReading:
        return 'bhrigu.geomancy.reading';
      case PaymentFeature.partnerMatch:
        return 'bhrigu.partner.match';
      case PaymentFeature.bhriguChat:
        return 'bhrigu.chat.session';
    }
  }

  String get entitlementId {
    switch (this) {
      case PaymentFeature.tarotReading:
        return 'tarot_reading';
      case PaymentFeature.geomancyReading:
        return 'geomancy_reading';
      case PaymentFeature.partnerMatch:
        return 'partner_match';
      case PaymentFeature.bhriguChat:
        return 'bhrigu_chat';
    }
  }
}
