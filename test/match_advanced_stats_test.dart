import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/match_advanced_stats_model.dart';

void main() {
  group('MatchAdvancedStats', () {
    final json = {
      'id': 'stats-1',
      'match_id': 'match-42',
      'home_xg': 1.85,
      'away_xg': 0.72,
      'home_possession': 62,
      'away_possession': 38,
      'home_shots': 14,
      'away_shots': 7,
      'home_shots_on_target': 6,
      'away_shots_on_target': 2,
      'home_corners': 8,
      'away_corners': 3,
      'home_fouls': 10,
      'away_fouls': 14,
      'home_yellow_cards': 2,
      'away_yellow_cards': 3,
      'home_red_cards': 0,
      'away_red_cards': 1,
      'data_source': 'gemini_grounded',
      'refreshed_at': '2026-04-18T14:30:00.000Z',
    };

    test('fromJson parses all fields', () {
      final stats = MatchAdvancedStats.fromJson(json);
      expect(stats.id, 'stats-1');
      expect(stats.matchId, 'match-42');
      expect(stats.homeXg, 1.85);
      expect(stats.awayXg, 0.72);
      expect(stats.homePossession, 62);
      expect(stats.awayPossession, 38);
      expect(stats.homeShots, 14);
      expect(stats.awayShots, 7);
      expect(stats.homeShotsOnTarget, 6);
      expect(stats.awayShotsOnTarget, 2);
      expect(stats.homeCorners, 8);
      expect(stats.awayCorners, 3);
      expect(stats.homeFouls, 10);
      expect(stats.awayFouls, 14);
      expect(stats.homeYellowCards, 2);
      expect(stats.awayYellowCards, 3);
      expect(stats.homeRedCards, 0);
      expect(stats.awayRedCards, 1);
      expect(stats.dataSource, 'gemini_grounded');
      expect(stats.refreshedAt, isNotNull);
    });

    test('hasData returns true when stats populated', () {
      final stats = MatchAdvancedStats.fromJson(json);
      expect(stats.hasData, true);
    });

    test('hasData returns false when empty stats', () {
      final empty = MatchAdvancedStats.fromJson({
        'id': 'stats-empty',
        'match_id': 'match-empty',
      });
      expect(empty.hasData, false);
      expect(empty.homeXg, isNull);
      expect(empty.homePossession, isNull);
      expect(empty.homeShots, 0);
    });

    test('defaults for numeric fields', () {
      final minimal = MatchAdvancedStats.fromJson({
        'id': 'stats-min',
        'match_id': 'match-min',
      });
      expect(minimal.homeShots, 0);
      expect(minimal.awayShots, 0);
      expect(minimal.homeCorners, 0);
      expect(minimal.homeYellowCards, 0);
      expect(minimal.homeRedCards, 0);
      expect(minimal.dataSource, 'gemini_grounded');
      expect(minimal.refreshedAt, isNull);
    });

    test('xG values as doubles', () {
      final stats = MatchAdvancedStats.fromJson({
        'id': 'x',
        'match_id': 'm',
        'home_xg': 2,
        'away_xg': 0,
      });
      expect(stats.homeXg, 2.0);
      expect(stats.awayXg, 0.0);
      expect(stats.hasData, true);
    });
  });
}
