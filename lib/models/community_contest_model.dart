/// Fan club vs fan club prediction contest.
/// Maps to `public.community_contests` (migration 013).
class CommunityContest {
  final String id;
  final String name;
  final String matchId;
  final String homeTeamId;
  final String awayTeamId;
  final String status;
  final int homeFanCount;
  final int awayFanCount;
  final double homeAccuracyAvg;
  final double awayAccuracyAvg;
  final String? winningFanClub;
  final DateTime createdAt;
  final DateTime? settledAt;

  const CommunityContest({
    required this.id,
    required this.name,
    required this.matchId,
    required this.homeTeamId,
    required this.awayTeamId,
    this.status = 'open',
    this.homeFanCount = 0,
    this.awayFanCount = 0,
    this.homeAccuracyAvg = 0,
    this.awayAccuracyAvg = 0,
    this.winningFanClub,
    required this.createdAt,
    this.settledAt,
  });

  factory CommunityContest.fromJson(Map<String, dynamic> json) {
    return CommunityContest(
      id: json['id'] as String,
      name: json['name'] as String,
      matchId: json['match_id'] as String,
      homeTeamId: json['home_team_id'] as String,
      awayTeamId: json['away_team_id'] as String,
      status: json['status'] as String? ?? 'open',
      homeFanCount: json['home_fan_count'] as int? ?? 0,
      awayFanCount: json['away_fan_count'] as int? ?? 0,
      homeAccuracyAvg: (json['home_accuracy_avg'] as num?)?.toDouble() ?? 0,
      awayAccuracyAvg: (json['away_accuracy_avg'] as num?)?.toDouble() ?? 0,
      winningFanClub: json['winning_fan_club'] as String?,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      settledAt: json['settled_at'] != null
          ? DateTime.tryParse(json['settled_at'] as String)
          : null,
    );
  }

  bool get isOpen => status == 'open';
  bool get isLocked => status == 'locked';
  bool get isSettled => status == 'settled';
  int get totalFans => homeFanCount + awayFanCount;
}

/// A user's entry in a community contest.
/// Maps to `public.community_contest_entries`.
class ContestEntry {
  final String id;
  final String contestId;
  final String userId;
  final String teamId;
  final int predictedHomeScore;
  final int predictedAwayScore;
  final double? accuracyScore;
  final DateTime createdAt;

  const ContestEntry({
    required this.id,
    required this.contestId,
    required this.userId,
    required this.teamId,
    required this.predictedHomeScore,
    required this.predictedAwayScore,
    this.accuracyScore,
    required this.createdAt,
  });

  factory ContestEntry.fromJson(Map<String, dynamic> json) {
    return ContestEntry(
      id: json['id'] as String,
      contestId: json['contest_id'] as String,
      userId: json['user_id'] as String,
      teamId: json['team_id'] as String,
      predictedHomeScore: json['predicted_home_score'] as int,
      predictedAwayScore: json['predicted_away_score'] as int,
      accuracyScore: (json['accuracy_score'] as num?)?.toDouble(),
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  /// Predicted score display (e.g. "2-1").
  String get scoreDisplay => '$predictedHomeScore - $predictedAwayScore';
}
