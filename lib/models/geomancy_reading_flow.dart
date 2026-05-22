import 'geomancy_figure_model.dart';
import 'payment_feature.dart';

class GeomancyReadingFlow {
  final GeomancyReadingModel? reading;
  final List<int> activeLineValues;
  final bool isRevealed;
  final bool isReadingLoading;
  final bool creatingFollowUp;
  final bool isFreshReading;

  const GeomancyReadingFlow({
    required this.reading,
    required this.activeLineValues,
    required this.isRevealed,
    required this.isReadingLoading,
    required this.creatingFollowUp,
    required this.isFreshReading,
  });

  factory GeomancyReadingFlow.initial() {
    return const GeomancyReadingFlow(
      reading: null,
      activeLineValues: [],
      isRevealed: false,
      isReadingLoading: false,
      creatingFollowUp: false,
      isFreshReading: false,
    );
  }

  factory GeomancyReadingFlow.saved({
    required GeomancyReadingModel reading,
    required List<int> lineValues,
  }) {
    return GeomancyReadingFlow(
      reading: reading,
      activeLineValues: List<int>.from(lineValues),
      isRevealed: true,
      isReadingLoading: false,
      creatingFollowUp: false,
      isFreshReading: false,
    );
  }

  PaymentFeature get paymentFeature => PaymentFeature.geomancyReading;

  bool get hasReading => reading != null;

  bool get readyToReveal {
    return reading != null && !isRevealed && !isReadingLoading;
  }

  bool get canShowResult {
    return isRevealed && reading != null;
  }

  bool get canFollowUp {
    return reading != null && isRevealed && !creatingFollowUp && isFreshReading;
  }

  GeomancyReadingFlow copyWith({
    GeomancyReadingModel? reading,
    List<int>? activeLineValues,
    bool? isRevealed,
    bool? isReadingLoading,
    bool? creatingFollowUp,
    bool? isFreshReading,
  }) {
    return GeomancyReadingFlow(
      reading: reading ?? this.reading,
      activeLineValues: activeLineValues ?? this.activeLineValues,
      isRevealed: isRevealed ?? this.isRevealed,
      isReadingLoading: isReadingLoading ?? this.isReadingLoading,
      creatingFollowUp: creatingFollowUp ?? this.creatingFollowUp,
      isFreshReading: isFreshReading ?? this.isFreshReading,
    );
  }

  GeomancyReadingFlow beginReading() {
    return copyWith(isReadingLoading: true);
  }

  GeomancyReadingFlow completeReading({
    required GeomancyReadingModel reading,
    required List<int> lineValues,
  }) {
    return copyWith(
      reading: reading,
      activeLineValues: List<int>.from(lineValues),
      isReadingLoading: false,
      isFreshReading: true,
    );
  }

  GeomancyReadingFlow reveal() {
    return copyWith(isRevealed: true);
  }

  GeomancyReadingFlow withFollowUpLoading(bool loading) {
    return copyWith(creatingFollowUp: loading);
  }

  List<int> lineValuesForShare(List<int> currentLineValues) {
    return activeLineValues.isEmpty ? currentLineValues : activeLineValues;
  }

  Map<String, dynamic> followUpSourceData(List<int> currentLineValues) {
    final currentReading = reading;

    if (currentReading == null) {
      return {};
    }

    final chart = currentReading.chart;

    return {
      'answer': currentReading.answer,
      'interpretation': currentReading.interpretation,
      'lineValues': lineValuesForShare(currentLineValues),
      'judge': _figurePayload(chart.judge),
      'leftWitness': _figurePayload(chart.leftWitness),
      'rightWitness': _figurePayload(chart.rightWitness),
      'reconciler': _figurePayload(chart.reconciler),
    };
  }

  Map<String, dynamic> _figurePayload(GeomancyFigureModel figure) {
    return {
      'name': figure.name,
      'latinName': figure.latinName,
      'meaning': figure.meaning,
    };
  }
}
