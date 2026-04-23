import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/models/prediction_engine_output_model.dart';
import 'package:fanzone/models/team_form_feature_model.dart';
import 'package:fanzone/models/user_prediction_model.dart';
import 'package:fanzone/providers/crowd_prediction_provider.dart';

void main() {
  group('lean prediction domain', () {
    test('engine derives the top result code from the strongest score', () {
      final engine = PredictionEngineOutputModel(
        id: 'engine_1',
        matchId: 'match_1',
        modelVersion: 'simple_form_v1',
        homeWinScore: 0.58,
        drawScore: 0.22,
        awayWinScore: 0.20,
        over25Score: 0.63,
        bttsScore: 0.57,
        predictedHomeGoals: 2,
        predictedAwayGoals: 1,
        confidenceLabel: 'medium',
        generatedAt: DateTime(2026, 4, 19, 12),
      );

      expect(engine.topResultCode, 'H');
    });

    test('user prediction exposes a scoreline label when goals are present', () {
      final prediction = UserPredictionModel(
        id: 'prediction_1',
        userId: 'user_1',
        matchId: 'match_1',
        predictedResultCode: 'D',
        predictedOver25: false,
        predictedBtts: true,
        predictedHomeGoals: 1,
        predictedAwayGoals: 1,
        pointsAwarded: 0,
        rewardStatus: 'pending',
        createdAt: DateTime(2026, 4, 19, 10),
        updatedAt: DateTime(2026, 4, 19, 10),
      );

      expect(prediction.scorelineLabel, '1 - 1');
    });

    test('crowd prediction normalizes rounding drift back to 100', () {
      const crowd = CrowdPrediction(home: 33, draw: 33, away: 35, total: 101);

      expect(crowd.normalized, (33, 33, 34));
    });

    test('team form features parse manual import rows cleanly', () {
      final feature = TeamFormFeatureModel.fromJson({
        'id': 'form_home',
        'match_id': 'match_1',
        'team_id': 'team_1',
        'last5_points': 11,
        'last5_wins': 3,
        'last5_draws': 2,
        'last5_losses': 0,
        'last5_goals_for': 8,
        'last5_goals_against': 3,
        'last5_clean_sheets': 2,
        'last5_failed_to_score': 0,
        'home_form_last5': 10,
        'away_form_last5': 1,
        'over25_last5': 3,
        'btts_last5': 2,
      });

      expect(feature.teamId, 'team_1');
      expect(feature.last5Points, 11);
      expect(feature.over25Last5, 3);
    });
  });
}
