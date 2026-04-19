import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/leaderboard_season_model.dart';

void main() {
  group('LeaderboardSeason', () {
    final json = {
      'id': 'season-2026-apr',
      'name': 'April 2026 Championship',
      'season_type': 'monthly',
      'competition_id': 'malta-premier',
      'starts_at': '2026-04-01T00:00:00.000Z',
      'ends_at': '2026-04-30T23:59:59.000Z',
      'status': 'active',
      'prize_pool_fet': 10000,
      'rules': {'min_predictions': 5, 'scoring': 'exact_3_result_1'},
    };

    test('fromJson parses all fields', () {
      final season = LeaderboardSeason.fromJson(json);
      expect(season.id, 'season-2026-apr');
      expect(season.name, 'April 2026 Championship');
      expect(season.seasonType, 'monthly');
      expect(season.competitionId, 'malta-premier');
      expect(season.prizePoolFet, 10000);
      expect(season.rules['min_predictions'], 5);
    });

    test('status checks', () {
      final active = LeaderboardSeason.fromJson(json);
      expect(active.isActive, true);
      expect(active.isCompleted, false);
      expect(active.isUpcoming, false);

      final upcoming = LeaderboardSeason.fromJson({
        ...json,
        'status': 'upcoming',
      });
      expect(upcoming.isUpcoming, true);

      final completed = LeaderboardSeason.fromJson({
        ...json,
        'status': 'completed',
      });
      expect(completed.isCompleted, true);
    });

    test('typeLabel returns human-readable labels', () {
      final types = {
        'monthly': 'Monthly',
        'seasonal': 'Season',
        'competition': 'Competition',
        'special_event': 'Special Event',
        'custom': 'custom',
      };
      for (final entry in types.entries) {
        final season = LeaderboardSeason.fromJson({
          ...json,
          'season_type': entry.key,
        });
        expect(season.typeLabel, entry.value);
      }
    });

    test('daysRemaining calculates correctly', () {
      final farFuture = LeaderboardSeason.fromJson({
        ...json,
        'ends_at': DateTime.now()
            .add(const Duration(days: 10))
            .toIso8601String(),
      });
      expect(farFuture.daysRemaining, greaterThanOrEqualTo(9));
    });

    test('daysRemaining returns 0 for past seasons', () {
      final past = LeaderboardSeason.fromJson({
        ...json,
        'ends_at': '2020-01-01T00:00:00.000Z',
      });
      expect(past.daysRemaining, 0);
    });

    test('defaults for optional fields', () {
      final minimal = LeaderboardSeason.fromJson({
        'id': 's1',
        'name': 'Test Season',
        'season_type': 'monthly',
        'starts_at': '2026-01-01T00:00:00.000Z',
        'ends_at': '2026-01-31T23:59:59.000Z',
      });
      expect(minimal.status, 'upcoming');
      expect(minimal.prizePoolFet, 0);
      expect(minimal.rules, isEmpty);
      expect(minimal.competitionId, isNull);
    });
  });

  group('SeasonLeaderboardEntry', () {
    final json = {
      'id': 'entry-1',
      'season_id': 'season-2026-apr',
      'user_id': 'u-abc-1234',
      'points': 45,
      'correct_predictions': 12,
      'total_predictions': 20,
      'exact_scores': 3,
      'rank': 1,
      'prize_fet': 5000,
      'display_name': 'MaltaFan42',
      'current_level': 4,
      'season_name': 'April 2026',
    };

    test('fromJson parses all fields', () {
      final entry = SeasonLeaderboardEntry.fromJson(json);
      expect(entry.id, 'entry-1');
      expect(entry.seasonId, 'season-2026-apr');
      expect(entry.points, 45);
      expect(entry.correctPredictions, 12);
      expect(entry.totalPredictions, 20);
      expect(entry.exactScores, 3);
      expect(entry.rank, 1);
      expect(entry.prizeFet, 5000);
      expect(entry.displayName, 'MaltaFan42');
    });

    test('accuracy calculation', () {
      final entry = SeasonLeaderboardEntry.fromJson(json);
      // 12/20 = 60%
      expect(entry.accuracy, 60.0);
    });

    test('accuracy returns 0 when no predictions', () {
      final empty = SeasonLeaderboardEntry.fromJson({
        ...json,
        'correct_predictions': 0,
        'total_predictions': 0,
      });
      expect(empty.accuracy, 0);
    });

    test('name returns display_name when present', () {
      final entry = SeasonLeaderboardEntry.fromJson(json);
      expect(entry.name, 'MaltaFan42');
    });

    test('name returns fallback when display_name is null', () {
      final anon = SeasonLeaderboardEntry.fromJson({
        ...json,
        'display_name': null,
      });
      expect(anon.name, startsWith('Fan #'));
    });

    test('defaults for optional fields', () {
      final minimal = SeasonLeaderboardEntry.fromJson({
        'id': 'e1',
        'season_id': 's1',
        'user_id': 'u-12345678',
      });
      expect(minimal.points, 0);
      expect(minimal.rank, isNull);
      expect(minimal.prizeFet, 0);
    });
  });
}
