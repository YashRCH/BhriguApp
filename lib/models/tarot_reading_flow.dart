import 'payment_feature.dart';
import 'tarot_card.dart';

class TarotReadingFlow {
  final List<TarotCard>? cards;
  final List<bool> revealed;
  final String reading;
  final bool readingLoading;
  final bool allRevealed;
  final bool followUpLoading;
  final bool isFreshReading;
  final bool readingStarted;

  const TarotReadingFlow({
    required this.cards,
    required this.revealed,
    required this.reading,
    required this.readingLoading,
    required this.allRevealed,
    required this.followUpLoading,
    required this.isFreshReading,
    required this.readingStarted,
  });

  factory TarotReadingFlow.initial() {
    return const TarotReadingFlow(
      cards: null,
      revealed: [false, false, false],
      reading: '',
      readingLoading: false,
      allRevealed: false,
      followUpLoading: false,
      isFreshReading: false,
      readingStarted: false,
    );
  }

  factory TarotReadingFlow.drawn(List<TarotCard> cards) {
    return TarotReadingFlow.initial().copyWith(cards: List.of(cards));
  }

  factory TarotReadingFlow.saved({
    required String reading,
    required TarotCard past,
    required TarotCard present,
    required TarotCard future,
  }) {
    return TarotReadingFlow(
      cards: [past, present, future],
      revealed: const [true, true, true],
      reading: reading,
      readingLoading: false,
      allRevealed: true,
      followUpLoading: false,
      isFreshReading: false,
      readingStarted: true,
    );
  }

  PaymentFeature get paymentFeature => PaymentFeature.tarotReading;

  bool get hasCards => cards != null;

  bool get canShare {
    return allRevealed &&
        cards != null &&
        reading.trim().isNotEmpty &&
        !readingLoading;
  }

  bool get canFollowUp {
    return isFreshReading && canShare;
  }

  bool get canReset {
    return allRevealed || readingLoading;
  }

  TarotReadingFlow copyWith({
    List<TarotCard>? cards,
    List<bool>? revealed,
    String? reading,
    bool? readingLoading,
    bool? allRevealed,
    bool? followUpLoading,
    bool? isFreshReading,
    bool? readingStarted,
  }) {
    return TarotReadingFlow(
      cards: cards ?? this.cards,
      revealed: revealed ?? this.revealed,
      reading: reading ?? this.reading,
      readingLoading: readingLoading ?? this.readingLoading,
      allRevealed: allRevealed ?? this.allRevealed,
      followUpLoading: followUpLoading ?? this.followUpLoading,
      isFreshReading: isFreshReading ?? this.isFreshReading,
      readingStarted: readingStarted ?? this.readingStarted,
    );
  }

  TarotReadingFlow withoutCards() {
    return TarotReadingFlow.initial();
  }

  TarotReadingFlow reveal(int index) {
    final nextRevealed = List<bool>.from(revealed);
    nextRevealed[index] = true;

    return copyWith(
      revealed: nextRevealed,
      allRevealed: nextRevealed.every((value) => value),
    );
  }

  TarotReadingFlow beginReading() {
    return copyWith(
      readingStarted: true,
      readingLoading: true,
      reading: '',
    );
  }

  TarotReadingFlow completeReading(String result) {
    return copyWith(
      reading: result,
      readingLoading: false,
      isFreshReading: true,
    );
  }

  TarotReadingFlow withFollowUpLoading(bool loading) {
    return copyWith(followUpLoading: loading);
  }
}
