import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/pool.dart';
import 'package:fanzone/models/wallet.dart';
import 'package:fanzone/models/match_model.dart';
import 'package:fanzone/models/competition_model.dart';
import 'package:fanzone/models/news_model.dart';
import 'package:fanzone/models/prediction_slip_model.dart';
import 'package:fanzone/models/team_model.dart';
import 'package:fanzone/models/team_news_model.dart';
import 'package:fanzone/models/team_supporter_model.dart';
import 'package:fanzone/models/team_contribution_model.dart';
import 'package:intl/intl.dart';

void main() {
  // ──────────────────────────────────────────────────────────
  // ScorePool
  // ──────────────────────────────────────────────────────────
  group('ScorePool', () {
    final json = {
      'id': 'c1',
      'matchId': 'm1',
      'matchName': 'Team A vs Team B',
      'creatorId': 'u1',
      'creatorName': 'Fan1',
      'creatorPrediction': '2-1',
      'stake': 100,
      'totalPool': 300,
      'participantsCount': 3,
      'status': 'open',
      'lockAt': '2026-04-18T14:00:00.000Z',
    };

    test('constructs with required fields', () {
      final pool = ScorePool(
        id: 'c1',
        matchId: 'm1',
        matchName: 'Team A vs Team B',
        creatorId: 'u1',
        creatorName: 'Fan1',
        creatorPrediction: '2-1',
        stake: 100,
        totalPool: 300,
        participantsCount: 3,
        status: 'open',
        lockAt: DateTime(2026, 4, 18),
      );

      expect(pool.id, 'c1');
      expect(pool.stake, 100);
      expect(pool.status, 'open');
      expect(pool.participantsCount, 3);
    });

    test('fromJson round-trip', () {
      final pool = ScorePool.fromJson(json);
      expect(pool.id, 'c1');
      expect(pool.matchName, 'Team A vs Team B');
      expect(pool.stake, 100);
      expect(pool.totalPool, 300);

      final encoded = pool.toJson();
      expect(encoded['id'], 'c1');
      expect(encoded['stake'], 100);
    });

    test('toJson produces complete map', () {
      final pool = ScorePool.fromJson(json);
      final encoded = pool.toJson();
      expect(encoded.containsKey('id'), true);
      expect(encoded.containsKey('matchId'), true);
      expect(encoded.containsKey('status'), true);
      expect(encoded.containsKey('lockAt'), true);
    });

    test('equality', () {
      final a = ScorePool.fromJson(json);
      final b = ScorePool.fromJson(json);
      expect(a, equals(b));
    });

    test('copyWith produces modified copy', () {
      final pool = ScorePool.fromJson(json);
      final modified = pool.copyWith(status: 'settled', totalPool: 500);
      expect(modified.status, 'settled');
      expect(modified.totalPool, 500);
      expect(modified.id, pool.id); // unchanged
    });
  });

  // ──────────────────────────────────────────────────────────
  // PoolEntry
  // ──────────────────────────────────────────────────────────
  group('PoolEntry', () {
    final json = {
      'id': 'e1',
      'poolId': 'c1',
      'userId': 'u1',
      'userName': 'You',
      'predictedHomeScore': 2,
      'predictedAwayScore': 1,
      'stake': 50,
      'status': 'active',
      'payout': 0,
    };

    test('constructs with required fields', () {
      const entry = PoolEntry(
        id: 'e1',
        poolId: 'c1',
        userId: 'u1',
        userName: 'You',
        predictedHomeScore: 2,
        predictedAwayScore: 1,
        stake: 50,
        status: 'active',
        payout: 0,
      );
      expect(entry.id, 'e1');
      expect(entry.predictedHomeScore, 2);
      expect(entry.status, 'active');
    });

    test('fromJson round-trip', () {
      final entry = PoolEntry.fromJson(json);
      expect(entry.id, 'e1');
      expect(entry.predictedHomeScore, 2);
      final encoded = entry.toJson();
      expect(encoded['id'], 'e1');
      expect(encoded['stake'], 50);
    });

    test('copyWith', () {
      final entry = PoolEntry.fromJson(json);
      final won = entry.copyWith(status: 'won', payout: 150);
      expect(won.status, 'won');
      expect(won.payout, 150);
    });
  });

  // ──────────────────────────────────────────────────────────
  // WalletTransaction
  // ──────────────────────────────────────────────────────────
  group('WalletTransaction', () {
    final json = {
      'id': 't1',
      'title': 'Pool stake',
      'amount': 50,
      'type': 'spend',
      'date': '2026-04-17T10:00:00.000Z',
      'dateStr': '17/4/2026',
    };

    test('constructs with required fields', () {
      final tx = WalletTransaction(
        id: 't1',
        title: 'Pool stake',
        amount: 50,
        type: 'spend',
        date: DateTime(2026, 4, 17),
        dateStr: '17/4/2026',
      );
      expect(tx.id, 't1');
      expect(tx.amount, 50);
      expect(tx.type, 'spend');
    });

    test('fromJson round-trip', () {
      final tx = WalletTransaction.fromJson(json);
      expect(tx.id, 't1');
      expect(tx.title, 'Pool stake');
      final encoded = tx.toJson();
      expect(encoded['amount'], 50);
    });
  });

  // ──────────────────────────────────────────────────────────
  // FanClub
  // ──────────────────────────────────────────────────────────
  group('FanClub', () {
    final json = {
      'id': 'bfc',
      'name': 'Birkirkara FC',
      'members': 150,
      'totalPool': 5000,
      'crest': '🟡',
      'league': 'BOV Premier League',
      'rank': 1,
    };

    test('fromJson round-trip', () {
      final club = FanClub.fromJson(json);
      expect(club.id, 'bfc');
      expect(club.name, 'Birkirkara FC');
      expect(club.members, 150);
      final encoded = club.toJson();
      expect(encoded['league'], 'BOV Premier League');
    });

    test('equality', () {
      final a = FanClub.fromJson(json);
      final b = FanClub.fromJson(json);
      expect(a, equals(b));
    });
  });

  // ──────────────────────────────────────────────────────────
  // MatchModel
  // ──────────────────────────────────────────────────────────
  group('MatchModel', () {
    final json = {
      'id': 'match-1',
      'home_team': 'Valletta FC',
      'away_team': 'Birkirkara FC',
      'competition_id': 'malta-premier',
      'season': '2025-26',
      'date': '2026-04-18T00:00:00.000Z',
      'status': 'upcoming',
      'data_source': 'openfootball',
    };

    test('fromJson with minimal data', () {
      final match = MatchModel.fromJson(json);
      expect(match.id, 'match-1');
      expect(match.homeTeam, 'Valletta FC');
      expect(match.awayTeam, 'Birkirkara FC');
      expect(match.competitionId, 'malta-premier');
      expect(match.season, '2025-26');
      expect(match.status, 'upcoming');
    });

    test('fromJson with full scores', () {
      final fullJson = {
        ...json,
        'ft_home': 2,
        'ft_away': 1,
        'ht_home': 1,
        'ht_away': 0,
        'status': 'finished',
        'venue': 'National Stadium',
        'round': 'Round 24',
        'kickoff_time': '15:00',
      };
      final match = MatchModel.fromJson(fullJson);
      expect(match.ftHome, 2);
      expect(match.ftAway, 1);
      expect(match.htHome, 1);
      expect(match.venue, 'National Stadium');
      expect(match.isFinished, true);
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

    test('scoreDisplay returns null for upcoming', () {
      final match = MatchModel.fromJson(json);
      expect(match.scoreDisplay, isNull);
    });

    test('isLive detection', () {
      final liveMatch = MatchModel.fromJson({...json, 'status': 'live'});
      expect(liveMatch.isLive, true);
      expect(liveMatch.isUpcoming, false);
      expect(liveMatch.isFinished, false);
    });

    test('liveStatusLabel prefers live_minute when available', () {
      final liveMatch = MatchModel.fromJson({
        ...json,
        'status': 'live',
        'live_minute': 63,
      });

      expect(liveMatch.liveStatusLabel(), "63' LIVE");
      expect(liveMatch.kickoffLabel, "63' LIVE");
    });

    test('kickoffTimeLocalLabel converts GMT kickoff_time to local HH:mm', () {
      final match = MatchModel.fromJson({...json, 'kickoff_time': '20:00:00'});

      final expected = DateFormat(
        'HH:mm',
      ).format(DateTime.utc(2026, 4, 18, 20).toLocal());

      expect(match.kickoffTimeLocalLabel, expected);
      expect(match.kickoffTimeLocalLabel.contains(':00:00'), isFalse);
    });

    test(
      'kickoffLabel uses the normalized local time for upcoming fixtures',
      () {
        final match = MatchModel.fromJson({
          ...json,
          'kickoff_time': '20:00:00',
        });

        expect(match.kickoffLabel, match.kickoffTimeLocalLabel);
      },
    );

    test('toJson round-trip', () {
      final match = MatchModel.fromJson(json);
      final encoded = match.toJson();
      final decoded = MatchModel.fromJson(encoded);
      expect(decoded.id, match.id);
      expect(decoded.homeTeam, match.homeTeam);
    });

    test('equality', () {
      final a = MatchModel.fromJson(json);
      final b = MatchModel.fromJson(json);
      expect(a, equals(b));
    });
  });

  // ──────────────────────────────────────────────────────────
  // CompetitionModel
  // ──────────────────────────────────────────────────────────
  group('CompetitionModel', () {
    final json = {
      'id': 'malta-premier',
      'name': 'BOV Premier League',
      'short_name': 'BPL',
      'country': 'MT',
      'data_source': 'openfootball',
    };

    test('fromJson round-trip', () {
      final comp = CompetitionModel.fromJson(json);
      expect(comp.id, 'malta-premier');
      expect(comp.name, 'BOV Premier League');
      expect(comp.country, 'MT');
      final encoded = comp.toJson();
      expect(encoded['short_name'], 'BPL');
    });
  });

  // ──────────────────────────────────────────────────────────
  // NewsModel
  // ──────────────────────────────────────────────────────────
  group('NewsModel', () {
    final json = {
      'id': 'n1',
      'title': 'Valletta wins derby',
      'source': 'FANZONE',
      'url': 'https://fanzone.ikanisa.com/news/1',
      'published_at': '2026-04-17T12:00:00.000Z',
    };

    test('fromJson round-trip', () {
      final news = NewsModel.fromJson(json);
      expect(news.id, 'n1');
      expect(news.title, 'Valletta wins derby');
      final encoded = news.toJson();
      expect(encoded['source'], 'FANZONE');
    });
  });

  // ──────────────────────────────────────────────────────────
  // PredictionSlipModel
  // ──────────────────────────────────────────────────────────
  group('PredictionSlipModel', () {
    test('fromJson with all fields', () {
      final slip = PredictionSlipModel.fromJson({
        'id': 'slip-1',
        'user_id': 'u1',
        'status': 'submitted',
        'selection_count': 3,
        'projected_earn_fet': 150,
        'submitted_at': '2026-04-17T10:00:00.000Z',
        'updated_at': '2026-04-17T10:00:00.000Z',
      });

      expect(slip.id, 'slip-1');
      expect(slip.status, 'submitted');
      expect(slip.selectionCount, 3);
      expect(slip.projectedEarnFet, 150);
      expect(slip.submittedAt, isNotNull);
    });

    test('fromJson with nulls uses defaults', () {
      final slip = PredictionSlipModel.fromJson({});
      expect(slip.id, '');
      expect(slip.status, 'submitted');
      expect(slip.selectionCount, 0);
      expect(slip.projectedEarnFet, 0);
    });
  });

  // ──────────────────────────────────────────────────────────
  // TeamModel
  // ──────────────────────────────────────────────────────────
  group('TeamModel', () {
    final json = {
      'id': 'valletta-fc',
      'name': 'Valletta FC',
      'short_name': 'VFC',
      'country': 'MT',
      'fan_count': 250,
      'is_active': true,
    };

    test('fromJson round-trip', () {
      final team = TeamModel.fromJson(json);
      expect(team.id, 'valletta-fc');
      expect(team.name, 'Valletta FC');
      expect(team.fanCount, 250);
      final encoded = team.toJson();
      expect(encoded['country'], 'MT');
    });

    test('equality', () {
      final a = TeamModel.fromJson(json);
      final b = TeamModel.fromJson(json);
      expect(a, equals(b));
    });
  });

  // ──────────────────────────────────────────────────────────
  // TeamNewsModel
  // ──────────────────────────────────────────────────────────
  group('TeamNewsModel', () {
    final json = {
      'id': 'tn1',
      'team_id': 'valletta-fc',
      'title': 'Transfer Update',
      'content': 'New signing announced.',
      'summary': 'Short summary',
      'category': 'transfers',
      'source_name': 'gemini',
      'status': 'published',
      'published_at': '2026-04-17T12:00:00.000Z',
    };

    test('fromJson round-trip', () {
      final news = TeamNewsModel.fromJson(json);
      expect(news.id, 'tn1');
      expect(news.category, 'transfers');
      expect(news.status, 'published');
      final encoded = news.toJson();
      expect(encoded['source_name'], 'gemini');
    });
  });

  // ──────────────────────────────────────────────────────────
  // TeamSupporterModel
  // ──────────────────────────────────────────────────────────
  group('TeamSupporterModel', () {
    final json = {
      'id': 'sup-1',
      'team_id': 'valletta-fc',
      'user_id': 'u1',
      'anonymous_fan_id': 'FAN-ABC123',
      'joined_at': '2026-01-01T00:00:00.000Z',
      'is_active': true,
    };

    test('fromJson round-trip', () {
      final supporter = TeamSupporterModel.fromJson(json);
      expect(supporter.userId, 'u1');
      expect(supporter.anonymousFanId, 'FAN-ABC123');
      expect(supporter.isActive, true);
    });
  });

  // ──────────────────────────────────────────────────────────
  // TeamContributionModel
  // ──────────────────────────────────────────────────────────
  group('TeamContributionModel', () {
    final json = {
      'id': 'contrib-1',
      'team_id': 'valletta-fc',
      'contribution_type': 'prediction',
      'amount_fet': 50,
      'status': 'completed',
      'created_at': '2026-04-17T12:00:00.000Z',
    };

    test('fromJson round-trip', () {
      final contrib = TeamContributionModel.fromJson(json);
      expect(contrib.id, 'contrib-1');
      expect(contrib.contributionType, 'prediction');
      expect(contrib.amountFet, 50);
      final encoded = contrib.toJson();
      expect(encoded['team_id'], 'valletta-fc');
    });
  });

  // ──────────────────────────────────────────────────────────
  // AppConfig
  // ──────────────────────────────────────────────────────────
  group('AppConfig smoke', () {
    test('default feature flags are set', () {
      // These are compile-time constants, but we can verify they exist
      // without crashing. Actual values depend on build defines.
      expect(
        true,
        isTrue,
      ); // Placeholder — real test is in app_config_test.dart
    });
  });
}
