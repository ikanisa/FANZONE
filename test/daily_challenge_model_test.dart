import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/daily_challenge_model.dart';

void main() {
  group('DailyChallenge', () {
    final json = {
      'id': 'dc-1',
      'date': '2026-04-18T00:00:00.000Z',
      'matchId': 'match-42',
      'matchName': 'Valletta vs Birkirkara',
      'title': 'Malta Derby Day',
      'description': 'Predict the final score!',
      'rewardFet': 50,
      'bonusExactFet': 200,
      'status': 'active',
      'officialHomeScore': null,
      'officialAwayScore': null,
      'totalEntries': 25,
      'totalWinners': 0,
    };

    test('fromJson parses all required fields', () {
      final challenge = DailyChallenge.fromJson(json);
      expect(challenge.id, 'dc-1');
      expect(challenge.matchId, 'match-42');
      expect(challenge.matchName, 'Valletta vs Birkirkara');
      expect(challenge.title, 'Malta Derby Day');
      expect(challenge.rewardFet, 50);
      expect(challenge.bonusExactFet, 200);
      expect(challenge.status, 'active');
      expect(challenge.totalEntries, 25);
      expect(challenge.totalWinners, 0);
    });

    test('fromJson handles null optional scores', () {
      final challenge = DailyChallenge.fromJson(json);
      expect(challenge.officialHomeScore, isNull);
      expect(challenge.officialAwayScore, isNull);
    });

    test('fromJson parses official scores when present', () {
      final settledJson = {
        ...json,
        'status': 'settled',
        'officialHomeScore': 2,
        'officialAwayScore': 1,
        'totalWinners': 5,
      };
      final challenge = DailyChallenge.fromJson(settledJson);
      expect(challenge.officialHomeScore, 2);
      expect(challenge.officialAwayScore, 1);
      expect(challenge.totalWinners, 5);
    });

    test('toJson round-trip preserves data', () {
      final challenge = DailyChallenge.fromJson(json);
      final encoded = challenge.toJson();
      final decoded = DailyChallenge.fromJson(encoded);
      expect(decoded.id, challenge.id);
      expect(decoded.matchName, challenge.matchName);
      expect(decoded.rewardFet, challenge.rewardFet);
    });

    test('equality on identical data', () {
      final a = DailyChallenge.fromJson(json);
      final b = DailyChallenge.fromJson(json);
      expect(a, equals(b));
    });

    test('copyWith modifies selected fields', () {
      final challenge = DailyChallenge.fromJson(json);
      final settled = challenge.copyWith(
        status: 'settled',
        officialHomeScore: 1,
        officialAwayScore: 0,
        totalWinners: 3,
      );
      expect(settled.status, 'settled');
      expect(settled.officialHomeScore, 1);
      expect(settled.id, challenge.id); // unchanged
    });

    test('defaults for totalEntries and totalWinners', () {
      final minimal = DailyChallenge.fromJson({
        'id': 'dc-min',
        'date': '2026-01-01T00:00:00.000Z',
        'matchId': 'm1',
        'matchName': 'A vs B',
        'title': 'Test',
        'rewardFet': 10,
        'bonusExactFet': 50,
        'status': 'active',
      });
      expect(minimal.totalEntries, 0);
      expect(minimal.totalWinners, 0);
      expect(minimal.description, '');
    });
  });

  group('DailyChallengeEntry', () {
    final json = {
      'id': 'entry-1',
      'challengeId': 'dc-1',
      'userId': 'user-abc',
      'predictedHomeScore': 2,
      'predictedAwayScore': 1,
      'result': 'pending',
      'payoutFet': 0,
      'submittedAt': '2026-04-18T10:30:00.000Z',
    };

    test('fromJson parses all fields', () {
      final entry = DailyChallengeEntry.fromJson(json);
      expect(entry.id, 'entry-1');
      expect(entry.challengeId, 'dc-1');
      expect(entry.userId, 'user-abc');
      expect(entry.predictedHomeScore, 2);
      expect(entry.predictedAwayScore, 1);
      expect(entry.result, 'pending');
      expect(entry.payoutFet, 0);
      expect(entry.submittedAt, isNotNull);
    });

    test('result values', () {
      for (final result in ['pending', 'correct_result', 'exact_score', 'wrong']) {
        final entry = DailyChallengeEntry.fromJson({...json, 'result': result});
        expect(entry.result, result);
      }
    });

    test('fromJson with null submittedAt', () {
      final entry = DailyChallengeEntry.fromJson({
        ...json,
        'submittedAt': null,
      });
      expect(entry.submittedAt, isNull);
    });

    test('toJson round-trip', () {
      final entry = DailyChallengeEntry.fromJson(json);
      final encoded = entry.toJson();
      final decoded = DailyChallengeEntry.fromJson(encoded);
      expect(decoded.id, entry.id);
      expect(decoded.predictedHomeScore, entry.predictedHomeScore);
    });

    test('copyWith for payout', () {
      final entry = DailyChallengeEntry.fromJson(json);
      final won = entry.copyWith(result: 'exact_score', payoutFet: 200);
      expect(won.result, 'exact_score');
      expect(won.payoutFet, 200);
      expect(won.userId, entry.userId);
    });

    test('equality', () {
      final a = DailyChallengeEntry.fromJson(json);
      final b = DailyChallengeEntry.fromJson(json);
      expect(a, equals(b));
    });
  });
}
