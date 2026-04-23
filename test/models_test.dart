import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/competition_model.dart';
import 'package:fanzone/models/match_model.dart';
import 'package:fanzone/models/team_model.dart';
import 'package:fanzone/models/wallet.dart';
import 'package:intl/intl.dart';

void main() {
  group('WalletTransaction', () {
    final json = {
      'id': 't1',
      'title': 'Prediction reward',
      'amount': 50,
      'type': 'spend',
      'date': '2026-04-17T10:00:00.000Z',
      'dateStr': '17/4/2026',
    };

    test('fromJson round-trip', () {
      final tx = WalletTransaction.fromJson(json);
      expect(tx.id, 't1');
      expect(tx.title, 'Prediction reward');
      expect(tx.toJson()['amount'], 50);
    });
  });

  group('MatchModel', () {
    final json = {
      'id': 'match-1',
      'home_team': 'Test Club A',
      'away_team': 'Test Club B',
      'competition_id': 'competition-alpha',
      'season_label': '2025-26',
      'date': '2026-04-18T00:00:00.000Z',
      'status': 'upcoming',
      'data_source': 'openfootball',
    };

    test('fromJson with lean match fields', () {
      final match = MatchModel.fromJson(json);
      expect(match.id, 'match-1');
      expect(match.homeTeam, 'Test Club A');
      expect(match.awayTeam, 'Test Club B');
      expect(match.competitionId, 'competition-alpha');
      expect(match.season, '2025-26');
      expect(match.status, 'upcoming');
    });

    test('scoreDisplay returns correct format', () {
      final match = MatchModel.fromJson({
        ...json,
        'ft_home': 3,
        'ft_away': 0,
        'status': 'finished',
      });
      expect(match.scoreDisplay, '3 - 0');
    });

    test('liveStatusLabel falls back to a generic live label', () {
      final liveMatch = MatchModel.fromJson({...json, 'status': 'live'});

      expect(liveMatch.liveStatusLabel(), 'LIVE');
      expect(liveMatch.kickoffLabel, 'LIVE');
    });

    test('live minute from backend is surfaced in the status label', () {
      final liveMatch = MatchModel.fromJson({
        ...json,
        'status': 'live',
        'live_minute': 63,
      });

      expect(liveMatch.liveMinuteLabel, "63'");
      expect(liveMatch.liveStatusLabel(), "63' LIVE");
    });

    test('kickoffTimeLocalLabel converts kickoff_time to local HH:mm', () {
      final match = MatchModel.fromJson({...json, 'kickoff_time': '20:00:00'});

      final expected = DateFormat(
        'HH:mm',
      ).format(DateTime.utc(2026, 4, 18, 20).toLocal());

      expect(match.kickoffTimeLocalLabel, expected);
    });
  });

  group('CompetitionModel', () {
    final json = {
      'id': 'competition-beta',
      'name': 'Test Competition Beta',
      'short_name': 'TCB',
      'country': 'TC',
      'current_season_label': '2025/26',
      'future_match_count': 12,
    };

    test('fromJson round-trip', () {
      final comp = CompetitionModel.fromJson(json);
      expect(comp.id, 'competition-beta');
      expect(comp.displayShortName, 'TCB');
      expect(comp.currentSeasonLabel, '2025/26');
      expect(comp.futureMatchCount, 12);
      expect(comp.toJson()['short_name'], 'TCB');
    });
  });

  group('TeamModel', () {
    final json = {
      'id': 'team-1',
      'name': 'Test Club C FC',
      'short_name': 'TCC',
      'country': 'Test Country',
      'country_code': 'AA',
      'league_name': 'Test Competition Regional',
      'competition_ids': ['competition-regional'],
      'aliases': ['Test Club C'],
      'search_terms': ['Test Club C FC'],
      'logo_url': 'https://example.com/logo.png',
      'crest_url': 'https://example.com/crest.png',
      'fan_count': 250,
      'is_popular_pick': true,
      'popular_pick_rank': 4,
    };

    test('fromJson round-trip', () {
      final team = TeamModel.fromJson(json);
      expect(team.id, 'team-1');
      expect(team.shortName, 'TCC');
      expect(team.competitionIds, ['competition-regional']);
      expect(team.aliases, ['Test Club C']);
      expect(team.searchTerms, ['Test Club C FC']);
      expect(team.isPopularPick, true);
      expect(team.toJson()['crest_url'], 'https://example.com/crest.png');
    });
  });
}
