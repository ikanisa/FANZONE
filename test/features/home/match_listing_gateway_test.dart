import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/features/home/data/match_listing_gateway.dart';
import 'package:fanzone/models/sports/match_model.dart';

void main() {
  group('normalizeSupabaseMatchRow', () {
    test('maps LiveScore World Cup rows into the Flutter match model', () {
      final normalized = normalizeSupabaseMatchRow({
        'id': '1417909',
        'competition_id': 'fifa_world_cup',
        'competition_name': 'World Cup 2026',
        'season_id': 'fifa_world_cup_2026',
        'stage': 'Group A',
        'matchday_or_round': '1',
        'date': '2026-06-11T19:00:00.000Z',
        'local_time': '19:00:00',
        'home_team': 'Mexico',
        'away_team': 'South Africa',
        'match_status': 'FT',
        'live_home_score': 2,
        'live_away_score': 1,
        'live_minute': 90,
        'source_name': 'livescore_world_cup_2026',
        'source_url':
            'https://www.livescore.com/en/football/international/world-cup-2026/mexico-vs-south-africa/1417909/',
        'home_crest_url':
            'https://storage.livescore.com/images/team/high/mex.png',
        'away_crest_url':
            'https://storage.livescore.com/images/team/high/rsa.png',
      });

      final match = MatchModel.fromJson(normalized);

      expect(match.competitionId, 'fifa_world_cup');
      expect(match.seasonId, 'fifa_world_cup_2026');
      expect(match.status, 'final');
      expect(match.ftHome, 2);
      expect(match.ftAway, 1);
      expect(match.kickoffTime, '19:00:00');
      expect(match.sourceLabel, 'LiveScore');
      expect(match.homeLogoUrl, contains('mex.png'));
      expect(match.awayLogoUrl, contains('rsa.png'));
    });

    test('normalizes LiveScore live status aliases', () {
      expect(normalizeMatchStatus('1H'), 'live');
      expect(normalizeMatchStatus('IP'), 'live');
      expect(normalizeMatchStatus('NS'), 'scheduled');
      expect(normalizeMatchStatus('AET'), 'final');
    });
  });
}
