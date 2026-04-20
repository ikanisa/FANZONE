/// Fan profile with XP, level, reputation, and streak tracking.
/// Maps to `public.fan_profiles` + `public.fan_levels` (migration 011).
class FanProfile {
  final String userId;
  final String? displayName;
  final int totalXp;
  final int currentLevel;
  final int reputationScore;
  final int streakDays;
  final int longestStreak;
  final DateTime? lastActiveDate;
  final FanLevel? level;

  const FanProfile({
    required this.userId,
    this.displayName,
    this.totalXp = 0,
    this.currentLevel = 1,
    this.reputationScore = 0,
    this.streakDays = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
    this.level,
  });

  factory FanProfile.fromJson(Map<String, dynamic> json) {
    return FanProfile(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      totalXp: json['total_xp'] as int? ?? 0,
      currentLevel: json['current_level'] as int? ?? 1,
      reputationScore: json['reputation_score'] as int? ?? 0,
      streakDays: json['streak_days'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      lastActiveDate: json['last_active_date'] != null
          ? DateTime.tryParse(json['last_active_date'] as String)
          : null,
    );
  }

  /// Attach resolved level data.
  FanProfile withLevel(FanLevel lvl) => FanProfile(
    userId: userId,
    displayName: displayName,
    totalXp: totalXp,
    currentLevel: currentLevel,
    reputationScore: reputationScore,
    streakDays: streakDays,
    longestStreak: longestStreak,
    lastActiveDate: lastActiveDate,
    level: lvl,
  );

  /// XP progress towards the next level (0.0 - 1.0).
  double xpProgress(List<FanLevel> allLevels) {
    final sorted = [...allLevels]..sort((a, b) => a.level.compareTo(b.level));
    final currentIdx = sorted.indexWhere((l) => l.level == currentLevel);
    if (currentIdx < 0 || currentIdx >= sorted.length - 1) return 1.0;
    final currentMin = sorted[currentIdx].minXp;
    final nextMin = sorted[currentIdx + 1].minXp;
    final range = nextMin - currentMin;
    if (range <= 0) return 1.0;
    return ((totalXp - currentMin) / range).clamp(0.0, 1.0);
  }

  /// XP remaining until next level.
  int xpToNextLevel(List<FanLevel> allLevels) {
    final sorted = [...allLevels]..sort((a, b) => a.level.compareTo(b.level));
    final currentIdx = sorted.indexWhere((l) => l.level == currentLevel);
    if (currentIdx < 0 || currentIdx >= sorted.length - 1) return 0;
    return sorted[currentIdx + 1].minXp - totalXp;
  }
}

/// Level definition with thresholds and visual metadata.
/// Maps to `public.fan_levels`.
class FanLevel {
  final int level;
  final String name;
  final String title;
  final int minXp;
  final String? iconName;
  final String? colorHex;
  final List<dynamic> perks;

  const FanLevel({
    required this.level,
    required this.name,
    required this.title,
    required this.minXp,
    this.iconName,
    this.colorHex,
    this.perks = const [],
  });

  factory FanLevel.fromJson(Map<String, dynamic> json) {
    return FanLevel(
      level: json['level'] as int,
      name: json['name'] as String,
      title: json['title'] as String,
      minXp: json['min_xp'] as int? ?? 0,
      iconName: json['icon_name'] as String?,
      colorHex: json['color_hex'] as String?,
      perks: json['perks'] as List<dynamic>? ?? const [],
    );
  }

  /// Parse hex color (e.g. '#22C55E') to a Color int.
  int get colorValue {
    if (colorHex == null || colorHex!.isEmpty) return 0xFFA8A29E;
    final hex = colorHex!.replaceFirst('#', '');
    return int.parse('FF$hex', radix: 16);
  }
}

/// Badge definition.
/// Maps to `public.fan_badges`.
class FanBadge {
  final String id;
  final String name;
  final String description;
  final String category;
  final String iconName;
  final String rarity;
  final int xpReward;
  final bool isActive;

  const FanBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.iconName,
    this.rarity = 'common',
    this.xpReward = 0,
    this.isActive = true,
  });

  factory FanBadge.fromJson(Map<String, dynamic> json) {
    return FanBadge(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'milestone',
      iconName: json['icon_name'] as String? ?? 'star',
      rarity: json['rarity'] as String? ?? 'common',
      xpReward: json['xp_reward'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  bool get isLegendary => rarity == 'legendary';
  bool get isEpic => rarity == 'epic';
  bool get isRare => rarity == 'rare';

  /// Color for rarity tier.
  int get rarityColorValue {
    switch (rarity) {
      case 'legendary':
        return 0xFFFFD700;
      case 'epic':
        return 0xFF2563EB; // Blue
      case 'rare':
        return 0xFF22D3EE; // Cyan
      default:
        return 0xFFA8A29E;
    }
  }
}

/// An earned badge with timestamp.
/// Maps to `public.fan_earned_badges`.
class EarnedBadge {
  final String id;
  final String userId;
  final String badgeId;
  final DateTime earnedAt;
  final FanBadge? badge;

  const EarnedBadge({
    required this.id,
    required this.userId,
    required this.badgeId,
    required this.earnedAt,
    this.badge,
  });

  factory EarnedBadge.fromJson(Map<String, dynamic> json) {
    return EarnedBadge(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      badgeId: json['badge_id'] as String,
      earnedAt: DateTime.parse(
        json['earned_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      badge: json['fan_badges'] != null
          ? FanBadge.fromJson(json['fan_badges'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// XP transaction log entry.
/// Maps to `public.fan_xp_log`.
class XpLogEntry {
  final String id;
  final String userId;
  final String action;
  final int xpEarned;
  final String? referenceType;
  final String? referenceId;
  final DateTime createdAt;

  const XpLogEntry({
    required this.id,
    required this.userId,
    required this.action,
    required this.xpEarned,
    this.referenceType,
    this.referenceId,
    required this.createdAt,
  });

  factory XpLogEntry.fromJson(Map<String, dynamic> json) {
    return XpLogEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      action: json['action'] as String,
      xpEarned: json['xp_earned'] as int,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  /// Human-readable action label.
  String get actionLabel {
    switch (action) {
      case 'prediction_submitted':
        return 'Submitted prediction';
      case 'prediction_correct':
        return 'Correct prediction';
      case 'pool_joined':
        return 'Joined pool';
      case 'pool_won':
        return 'Pool victory';
      case 'daily_login':
        return 'Daily login';
      case 'badge_earned':
        return 'Badge earned';
      case 'community_contribution':
        return 'Community contribution';
      default:
        return action.replaceAll('_', ' ');
    }
  }
}
