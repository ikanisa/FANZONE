/// A time-scoped leaderboard season (monthly, seasonal, competition, etc.)
/// Maps to `public.leaderboard_seasons` (migration 012).
class LeaderboardSeason {
  final String id;
  final String name;
  final String seasonType;
  final String? competitionId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final int prizePoolFet;
  final Map<String, dynamic> rules;

  const LeaderboardSeason({
    required this.id,
    required this.name,
    required this.seasonType,
    this.competitionId,
    required this.startsAt,
    required this.endsAt,
    this.status = 'upcoming',
    this.prizePoolFet = 0,
    this.rules = const {},
  });

  factory LeaderboardSeason.fromJson(Map<String, dynamic> json) {
    return LeaderboardSeason(
      id: json['id'] as String,
      name: json['name'] as String,
      seasonType: json['season_type'] as String,
      competitionId: json['competition_id'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      status: json['status'] as String? ?? 'upcoming',
      prizePoolFet: json['prize_pool_fet'] as int? ?? 0,
      rules: json['rules'] as Map<String, dynamic>? ?? const {},
    );
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isUpcoming => status == 'upcoming';

  /// Human-readable season type label.
  String get typeLabel {
    switch (seasonType) {
      case 'monthly':
        return 'Monthly';
      case 'seasonal':
        return 'Season';
      case 'competition':
        return 'Competition';
      case 'special_event':
        return 'Special Event';
      default:
        return seasonType;
    }
  }

  /// Days remaining in the season.
  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(endsAt)) return 0;
    return endsAt.difference(now).inDays;
  }
}

/// A user's entry on a seasonal leaderboard.
/// Maps to `public.leaderboard_entries` or `public.mv_season_leaderboard`.
class SeasonLeaderboardEntry {
  final String id;
  final String seasonId;
  final String userId;
  final int points;
  final int correctPredictions;
  final int totalPredictions;
  final int exactScores;
  final int? rank;
  final int prizeFet;
  final String? displayName;
  final int? currentLevel;
  final String? seasonName;

  const SeasonLeaderboardEntry({
    required this.id,
    required this.seasonId,
    required this.userId,
    this.points = 0,
    this.correctPredictions = 0,
    this.totalPredictions = 0,
    this.exactScores = 0,
    this.rank,
    this.prizeFet = 0,
    this.displayName,
    this.currentLevel,
    this.seasonName,
  });

  factory SeasonLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return SeasonLeaderboardEntry(
      id: json['id'] as String,
      seasonId: json['season_id'] as String,
      userId: json['user_id'] as String,
      points: json['points'] as int? ?? 0,
      correctPredictions: json['correct_predictions'] as int? ?? 0,
      totalPredictions: json['total_predictions'] as int? ?? 0,
      exactScores: json['exact_scores'] as int? ?? 0,
      rank: json['rank'] as int?,
      prizeFet: json['prize_fet'] as int? ?? 0,
      displayName: json['display_name'] as String?,
      currentLevel: json['current_level'] as int?,
      seasonName: json['season_name'] as String?,
    );
  }

  /// Accuracy percentage (0-100).
  double get accuracy =>
      totalPredictions > 0 ? (correctPredictions / totalPredictions) * 100 : 0;

  /// Display name with fallback.
  String get name => displayName ?? 'Fan #${userId.substring(0, 4)}';
}
