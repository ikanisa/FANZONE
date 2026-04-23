import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/notification_model.dart';

void main() {
  group('NotificationItem', () {
    final json = {
      'id': 'n1',
      'type': 'prediction_reward',
      'title': '🎉 You won!',
      'body': 'Your prediction for Valletta vs Birkirkara was correct!',
      'data': {'match_id': 'm1', 'screen': '/predict'},
      'sent_at': '2026-04-18T14:00:00.000Z',
      'read_at': null,
    };

    test('fromJson parses all fields', () {
      final notif = NotificationItem.fromJson(json);
      expect(notif.id, 'n1');
      expect(notif.type, 'prediction_reward');
      expect(notif.title, '🎉 You won!');
      expect(notif.body, contains('Valletta'));
      expect(notif.data['match_id'], 'm1');
      expect(notif.readAt, isNull);
    });

    test('fromJson with readAt', () {
      final readJson = {...json, 'read_at': '2026-04-18T15:00:00.000Z'};
      final notif = NotificationItem.fromJson(readJson);
      expect(notif.readAt, isNotNull);
    });

    test('defaults for body and data', () {
      final minimal = NotificationItem.fromJson({
        'id': 'n2',
        'type': 'goal_alert',
        'title': 'Goal!',
        'sent_at': '2026-04-18T14:00:00.000Z',
      });
      expect(minimal.body, '');
      expect(minimal.data, isEmpty);
    });

    test('toJson round-trip', () {
      final notif = NotificationItem.fromJson(json);
      final encoded = notif.toJson();
      final decoded = NotificationItem.fromJson(encoded);
      expect(decoded.id, notif.id);
      expect(decoded.type, notif.type);
    });

    test('equality', () {
      final a = NotificationItem.fromJson(json);
      final b = NotificationItem.fromJson(json);
      expect(a, equals(b));
    });

    test('copyWith marks as read', () {
      final notif = NotificationItem.fromJson(json);
      final read = notif.copyWith(readAt: DateTime(2026, 4, 18, 15));
      expect(read.readAt, isNotNull);
      expect(read.id, notif.id);
    });
  });

  group('NotificationPreferences', () {
    test('defaults are sensible', () {
      const prefs = NotificationPreferences();
      expect(prefs.goalAlerts, true);
      expect(prefs.predictionUpdates, true);
      expect(prefs.rewardUpdates, true);
      expect(prefs.marketing, false); // marketing OFF by default
    });

    test('fromJson round-trip', () {
      final json = {
        'goal_alerts': false,
        'prediction_updates': true,
        'reward_updates': false,
        'marketing': true,
      };
      final prefs = NotificationPreferences.fromJson(json);
      expect(prefs.goalAlerts, false);
      expect(prefs.rewardUpdates, false);
      expect(prefs.marketing, true);
      final encoded = prefs.toJson();
      expect(encoded['goal_alerts'], false);
    });

    test('copyWith toggles individual preferences', () {
      const prefs = NotificationPreferences();
      final updated = prefs.copyWith(goalAlerts: false, marketing: true);
      expect(updated.goalAlerts, false);
      expect(updated.marketing, true);
      expect(updated.predictionUpdates, true); // unchanged
    });
  });

  group('UserStats', () {
    test('defaults are all zero', () {
      const stats = UserStats();
      expect(stats.predictionStreak, 0);
      expect(stats.longestStreak, 0);
      expect(stats.totalPredictions, 0);
      expect(stats.correctPredictions, 0);
      expect(stats.totalFetEarned, 0);
      expect(stats.totalFetSpent, 0);
    });

    test('fromJson round-trip', () {
      final json = {
        'prediction_streak': 5,
        'longest_streak': 12,
        'total_predictions': 30,
        'correct_predictions': 3,
        'total_fet_earned': 2500,
        'total_fet_spent': 1200,
      };
      final stats = UserStats.fromJson(json);
      expect(stats.predictionStreak, 5);
      expect(stats.longestStreak, 12);
      expect(stats.correctPredictions, 3);
      expect(stats.totalFetEarned, 2500);
      final encoded = stats.toJson();
      expect(encoded['correct_predictions'], 3);
    });

    test('equality', () {
      const a = UserStats(predictionStreak: 5, totalFetEarned: 100);
      const b = UserStats(predictionStreak: 5, totalFetEarned: 100);
      expect(a, equals(b));
    });
  });
}
