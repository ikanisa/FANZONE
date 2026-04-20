import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/models/fan_identity_model.dart';

void main() {
  group('FanProfile', () {
    final json = {
      'user_id': 'u-abc',
      'display_name': 'MaltaFan42',
      'total_xp': 750,
      'current_level': 3,
      'reputation_score': 85,
      'streak_days': 7,
      'longest_streak': 14,
      'last_active_date': '2026-04-17',
    };

    test('fromJson parses all fields', () {
      final profile = FanProfile.fromJson(json);
      expect(profile.userId, 'u-abc');
      expect(profile.displayName, 'MaltaFan42');
      expect(profile.totalXp, 750);
      expect(profile.currentLevel, 3);
      expect(profile.reputationScore, 85);
      expect(profile.streakDays, 7);
      expect(profile.longestStreak, 14);
      expect(profile.lastActiveDate, isNotNull);
    });

    test('defaults for optional fields', () {
      final minimal = FanProfile.fromJson({'user_id': 'u-min'});
      expect(minimal.displayName, isNull);
      expect(minimal.totalXp, 0);
      expect(minimal.currentLevel, 1);
      expect(minimal.reputationScore, 0);
      expect(minimal.streakDays, 0);
      expect(minimal.level, isNull);
    });

    test('withLevel attaches level data', () {
      final profile = FanProfile.fromJson(json);
      const level = FanLevel(
        level: 3,
        name: 'Supporter',
        title: 'Dedicated Fan',
        minXp: 500,
      );
      final withLevel = profile.withLevel(level);
      expect(withLevel.level, isNotNull);
      expect(withLevel.level!.name, 'Supporter');
      expect(withLevel.userId, profile.userId); // preserved
    });

    test('xpProgress calculates correctly', () {
      final profile = FanProfile.fromJson({
        ...json,
        'total_xp': 750,
        'current_level': 2,
      });
      final levels = [
        const FanLevel(level: 1, name: 'Rookie', title: 'New Fan', minXp: 0),
        const FanLevel(level: 2, name: 'Fan', title: 'Active Fan', minXp: 500),
        const FanLevel(
          level: 3,
          name: 'Supporter',
          title: 'Dedicated',
          minXp: 1000,
        ),
      ];
      final progress = profile.xpProgress(levels);
      // 750 XP, level 2 starts at 500, level 3 starts at 1000
      // progress = (750-500) / (1000-500) = 0.5
      expect(progress, 0.5);
    });

    test('xpProgress returns 1.0 for max level', () {
      final maxLevel = FanProfile.fromJson({
        ...json,
        'current_level': 5,
        'total_xp': 5000,
      });
      final levels = [
        const FanLevel(level: 5, name: 'Legend', title: 'Legend', minXp: 3000),
      ];
      expect(maxLevel.xpProgress(levels), 1.0);
    });

    test('xpToNextLevel calculates remaining XP', () {
      final profile = FanProfile.fromJson({
        ...json,
        'total_xp': 750,
        'current_level': 2,
      });
      final levels = [
        const FanLevel(level: 2, name: 'Fan', title: 'Fan', minXp: 500),
        const FanLevel(
          level: 3,
          name: 'Supporter',
          title: 'Supporter',
          minXp: 1000,
        ),
      ];
      expect(profile.xpToNextLevel(levels), 250);
    });
  });

  group('FanLevel', () {
    test('fromJson parses all fields', () {
      final json = {
        'level': 3,
        'name': 'Supporter',
        'title': 'Dedicated Fan',
        'min_xp': 500,
        'icon_name': 'shield',
        'color_hex': '#22C55E',
        'perks': ['Custom badge', 'Priority pools'],
      };
      final level = FanLevel.fromJson(json);
      expect(level.level, 3);
      expect(level.name, 'Supporter');
      expect(level.minXp, 500);
      expect(level.iconName, 'shield');
      expect(level.colorHex, '#22C55E');
      expect(level.perks, hasLength(2));
    });

    test('colorValue parses hex correctly', () {
      const level = FanLevel(
        level: 1,
        name: 'Rookie',
        title: 'Rookie',
        minXp: 0,
        colorHex: '#FF0000',
      );
      expect(level.colorValue, 0xFFFF0000);
    });

    test('colorValue returns default for null hex', () {
      const level = FanLevel(
        level: 1,
        name: 'Rookie',
        title: 'Rookie',
        minXp: 0,
      );
      expect(level.colorValue, 0xFFA8A29E);
    });
  });

  group('FanBadge', () {
    final json = {
      'id': 'badge-1',
      'name': 'First Prediction',
      'description': 'Made your first prediction',
      'category': 'milestone',
      'icon_name': 'star',
      'rarity': 'common',
      'xp_reward': 50,
      'is_active': true,
    };

    test('fromJson parses all fields', () {
      final badge = FanBadge.fromJson(json);
      expect(badge.id, 'badge-1');
      expect(badge.name, 'First Prediction');
      expect(badge.rarity, 'common');
      expect(badge.xpReward, 50);
      expect(badge.isActive, true);
    });

    test('rarity checks', () {
      expect(
        FanBadge.fromJson({...json, 'rarity': 'legendary'}).isLegendary,
        true,
      );
      expect(FanBadge.fromJson({...json, 'rarity': 'epic'}).isEpic, true);
      expect(FanBadge.fromJson({...json, 'rarity': 'rare'}).isRare, true);
      expect(FanBadge.fromJson(json).isLegendary, false);
    });

    test('rarityColorValue returns correct colors', () {
      expect(
        FanBadge.fromJson({...json, 'rarity': 'legendary'}).rarityColorValue,
        0xFFFFD700,
      );
      expect(
        FanBadge.fromJson({...json, 'rarity': 'epic'}).rarityColorValue,
        0xFFFF7F50,
      );
      expect(
        FanBadge.fromJson({...json, 'rarity': 'rare'}).rarityColorValue,
        0xFF98FF98,
      );
      expect(FanBadge.fromJson(json).rarityColorValue, 0xFFA8A29E);
    });
  });

  group('EarnedBadge', () {
    test('fromJson with nested badge', () {
      final json = {
        'id': 'eb-1',
        'user_id': 'u-abc',
        'badge_id': 'badge-1',
        'earned_at': '2026-04-17T12:00:00.000Z',
        'fan_badges': {
          'id': 'badge-1',
          'name': 'First Prediction',
          'description': 'Made first prediction',
          'category': 'milestone',
          'icon_name': 'star',
        },
      };
      final earned = EarnedBadge.fromJson(json);
      expect(earned.id, 'eb-1');
      expect(earned.badge, isNotNull);
      expect(earned.badge!.name, 'First Prediction');
    });

    test('fromJson without nested badge', () {
      final json = {
        'id': 'eb-2',
        'user_id': 'u-abc',
        'badge_id': 'badge-2',
        'earned_at': '2026-04-17T12:00:00.000Z',
      };
      final earned = EarnedBadge.fromJson(json);
      expect(earned.badge, isNull);
    });
  });

  group('XpLogEntry', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'xp-1',
        'user_id': 'u-abc',
        'action': 'prediction_correct',
        'xp_earned': 25,
        'reference_type': 'prediction',
        'reference_id': 'pred-1',
        'created_at': '2026-04-17T12:00:00.000Z',
      };
      final entry = XpLogEntry.fromJson(json);
      expect(entry.xpEarned, 25);
      expect(entry.action, 'prediction_correct');
      expect(entry.referenceType, 'prediction');
    });

    test('actionLabel returns human-readable strings', () {
      final actions = {
        'prediction_submitted': 'Submitted prediction',
        'prediction_correct': 'Correct prediction',
        'pool_joined': 'Joined pool',
        'pool_won': 'Pool victory',
        'daily_login': 'Daily login',
        'badge_earned': 'Badge earned',
        'community_contribution': 'Community contribution',
        'custom_action': 'custom action',
      };

      for (final entry in actions.entries) {
        final xp = XpLogEntry.fromJson({
          'id': 'x1',
          'user_id': 'u1',
          'action': entry.key,
          'xp_earned': 10,
          'created_at': '2026-01-01T00:00:00.000Z',
        });
        expect(xp.actionLabel, entry.value);
      }
    });
  });
}
