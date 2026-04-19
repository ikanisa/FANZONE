/// Player-level match statistics.
/// Maps to `public.match_player_stats` (migration 009).
class MatchPlayerStats {
  final String id;
  final String matchId;
  final String? teamId;
  final String playerName;
  final int? playerNumber;
  final String? position;
  final int minutesPlayed;
  final int goals;
  final int assists;
  final int yellowCards;
  final int redCards;
  final int shots;
  final int shotsOnTarget;
  final int passesCompleted;
  final double? passAccuracy;
  final double? rating;
  final bool isStarter;
  final int? substitutedInMinute;
  final int? substitutedOutMinute;

  const MatchPlayerStats({
    required this.id,
    required this.matchId,
    this.teamId,
    required this.playerName,
    this.playerNumber,
    this.position,
    this.minutesPlayed = 0,
    this.goals = 0,
    this.assists = 0,
    this.yellowCards = 0,
    this.redCards = 0,
    this.shots = 0,
    this.shotsOnTarget = 0,
    this.passesCompleted = 0,
    this.passAccuracy,
    this.rating,
    this.isStarter = true,
    this.substitutedInMinute,
    this.substitutedOutMinute,
  });

  factory MatchPlayerStats.fromJson(Map<String, dynamic> json) {
    return MatchPlayerStats(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      teamId: json['team_id'] as String?,
      playerName: json['player_name'] as String,
      playerNumber: json['player_number'] as int?,
      position: json['position'] as String?,
      minutesPlayed: json['minutes_played'] as int? ?? 0,
      goals: json['goals'] as int? ?? 0,
      assists: json['assists'] as int? ?? 0,
      yellowCards: json['yellow_cards'] as int? ?? 0,
      redCards: json['red_cards'] as int? ?? 0,
      shots: json['shots'] as int? ?? 0,
      shotsOnTarget: json['shots_on_target'] as int? ?? 0,
      passesCompleted: json['passes_completed'] as int? ?? 0,
      passAccuracy: (json['pass_accuracy'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      isStarter: json['is_starter'] as bool? ?? true,
      substitutedInMinute: json['substituted_in_minute'] as int?,
      substitutedOutMinute: json['substituted_out_minute'] as int?,
    );
  }

  /// Formatted position label.
  String get positionLabel {
    switch (position) {
      case 'GK':
        return 'Goalkeeper';
      case 'DEF':
        return 'Defender';
      case 'MID':
        return 'Midfielder';
      case 'FWD':
        return 'Forward';
      default:
        return position ?? 'Unknown';
    }
  }

  /// Whether the player had goal contributions.
  bool get hasContributions => goals > 0 || assists > 0;
}
