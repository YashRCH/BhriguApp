import 'package:cloud_firestore/cloud_firestore.dart';

class GeomancyFigureModel {
  final String name;
  final String latinName;
  final List<int> pattern;
  final String element;
  final String planet;
  final String answerType;
  final String meaning;

  const GeomancyFigureModel({
    required this.name,
    required this.latinName,
    required this.pattern,
    required this.element,
    required this.planet,
    required this.answerType,
    required this.meaning,
  });

  String get key => pattern.join();

  Map<String, dynamic> toJson() => {
        'name': name,
        'latinName': latinName,
        'pattern': pattern,
        'element': element,
        'planet': planet,
        'answerType': answerType,
        'meaning': meaning,
      };

  factory GeomancyFigureModel.fromJson(Map<String, dynamic> json) {
    return GeomancyFigureModel(
      name: json['name'] as String? ?? '',
      latinName: json['latinName'] as String? ?? '',
      pattern: (json['pattern'] as List? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      element: json['element'] as String? ?? '',
      planet: json['planet'] as String? ?? '',
      answerType: json['answerType'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
    );
  }
}

class GeomancyChartModel {
  final List<GeomancyFigureModel> mothers;
  final List<GeomancyFigureModel> daughters;
  final List<GeomancyFigureModel> nieces;
  final GeomancyFigureModel leftWitness;
  final GeomancyFigureModel rightWitness;
  final GeomancyFigureModel judge;
  final GeomancyFigureModel reconciler;

  const GeomancyChartModel({
    required this.mothers,
    required this.daughters,
    required this.nieces,
    required this.leftWitness,
    required this.rightWitness,
    required this.judge,
    required this.reconciler,
  });

  Map<String, dynamic> toJson() => {
        'mothers': mothers.map((e) => e.toJson()).toList(),
        'daughters': daughters.map((e) => e.toJson()).toList(),
        'nieces': nieces.map((e) => e.toJson()).toList(),
        'leftWitness': leftWitness.toJson(),
        'rightWitness': rightWitness.toJson(),
        'judge': judge.toJson(),
        'reconciler': reconciler.toJson(),
      };

  factory GeomancyChartModel.fromJson(Map<String, dynamic> json) {
    return GeomancyChartModel(
      mothers: ((json['mothers'] as List?) ?? [])
          .map(
            (e) => GeomancyFigureModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      daughters: ((json['daughters'] as List?) ?? [])
          .map(
            (e) => GeomancyFigureModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      nieces: ((json['nieces'] as List?) ?? [])
          .map(
            (e) => GeomancyFigureModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      leftWitness: GeomancyFigureModel.fromJson(
        Map<String, dynamic>.from(json['leftWitness'] as Map? ?? {}),
      ),
      rightWitness: GeomancyFigureModel.fromJson(
        Map<String, dynamic>.from(json['rightWitness'] as Map? ?? {}),
      ),
      judge: GeomancyFigureModel.fromJson(
        Map<String, dynamic>.from(json['judge'] as Map? ?? {}),
      ),
      reconciler: GeomancyFigureModel.fromJson(
        Map<String, dynamic>.from(json['reconciler'] as Map? ?? {}),
      ),
    );
  }
}

class GeomancyReadingModel {
  final String question;
  final GeomancyChartModel chart;
  final String answer;
  final String interpretation;

  const GeomancyReadingModel({
    required this.question,
    required this.chart,
    required this.answer,
    required this.interpretation,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'chart': chart.toJson(),
        'answer': answer,
        'interpretation': interpretation,
      };

  factory GeomancyReadingModel.fromJson(Map<String, dynamic> json) {
    return GeomancyReadingModel(
      question: json['question'] as String? ?? '',
      chart: GeomancyChartModel.fromJson(
        Map<String, dynamic>.from(json['chart'] as Map? ?? {}),
      ),
      answer: json['answer'] as String? ?? '',
      interpretation: json['interpretation'] as String? ?? '',
    );
  }
}

class GeomancySavedReading {
  final String id;
  final GeomancyReadingModel reading;
  final List<int> lineValues;
  final DateTime createdAt;

  const GeomancySavedReading({
    required this.id,
    required this.reading,
    required this.lineValues,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': reading.question,
      'chart': reading.chart.toJson(),
      'answer': reading.answer,
      'interpretation': reading.interpretation,
      'lineValues': lineValues,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory GeomancySavedReading.fromJson({
    required String id,
    required Map<String, dynamic> json,
  }) {
    return GeomancySavedReading(
      id: id,
      reading: GeomancyReadingModel.fromJson(json),
      lineValues: (json['lineValues'] as List? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      createdAt: _dateFromValue(json['createdAt']),
    );
  }

  static DateTime _dateFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }
}