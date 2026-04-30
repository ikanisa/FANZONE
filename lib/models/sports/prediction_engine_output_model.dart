class PredictionEngineOutputModel {
  const PredictionEngineOutputModel({
    required this.id,
    required this.matchId,
    required this.modelVersion,
    required this.homeWinScore,
    required this.drawScore,
    required this.awayWinScore,
    required this.over25Score,
    required this.bttsScore,
    required this.predictedHomeGoals,
    required this.predictedAwayGoals,
    required this.confidenceLabel,
    required this.generatedAt,
  });

  final String id;
  final String matchId;
  final String modelVersion;
  final double homeWinScore;
  final double drawScore;
  final double awayWinScore;
  final double over25Score;
  final double bttsScore;
  final int? predictedHomeGoals;
  final int? predictedAwayGoals;
  final String confidenceLabel;
  final DateTime generatedAt;

  String get topResultCode {
    if (homeWinScore >= drawScore && homeWinScore >= awayWinScore) {
      return 'H';
    }
    if (awayWinScore >= homeWinScore && awayWinScore >= drawScore) {
      return 'A';
    }
    return 'D';
  }

  factory PredictionEngineOutputModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(Object? value, [double fallback = 0]) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return PredictionEngineOutputModel(
      id: json['id']?.toString() ?? '',
      matchId: json['match_id']?.toString() ?? '',
      modelVersion: json['model_version']?.toString() ?? 'simple_form_v1',
      homeWinScore: parseDouble(json['home_win_score'], 0.3333),
      drawScore: parseDouble(json['draw_score'], 0.3333),
      awayWinScore: parseDouble(json['away_win_score'], 0.3333),
      over25Score: parseDouble(json['over25_score'], 0.5),
      bttsScore: parseDouble(json['btts_score'], 0.5),
      predictedHomeGoals: (json['predicted_home_goals'] as num?)?.toInt(),
      predictedAwayGoals: (json['predicted_away_goals'] as num?)?.toInt(),
      confidenceLabel: json['confidence_label']?.toString() ?? 'low',
      generatedAt:
          DateTime.tryParse(json['generated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
