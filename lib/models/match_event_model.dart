/// Match timeline event (goal, card, substitution, etc.)
/// Maps to `public.match_events` (migration 009).
class MatchEventModel {
  final String id;
  final String matchId;
  final int minute;
  final String eventType;
  final String? teamId;
  final String? playerName;
  final String? assistPlayerName;
  final String? description;
  final Map<String, dynamic> metadata;

  const MatchEventModel({
    required this.id,
    required this.matchId,
    required this.minute,
    required this.eventType,
    this.teamId,
    this.playerName,
    this.assistPlayerName,
    this.description,
    this.metadata = const {},
  });

  factory MatchEventModel.fromJson(Map<String, dynamic> json) {
    return MatchEventModel(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      minute: json['minute'] as int,
      eventType: json['event_type'] as String,
      teamId: json['team_id'] as String?,
      playerName: json['player_name'] as String?,
      assistPlayerName: json['assist_player_name'] as String?,
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  bool get isGoal =>
      eventType == 'goal' ||
      eventType == 'own_goal' ||
      eventType == 'penalty_scored';

  bool get isCard =>
      eventType == 'yellow_card' || eventType == 'red_card';

  bool get isSubstitution => eventType == 'substitution';

  /// Human-readable event label.
  String get label {
    switch (eventType) {
      case 'goal':
        return 'Goal';
      case 'own_goal':
        return 'Own Goal';
      case 'penalty_scored':
        return 'Penalty';
      case 'penalty_missed':
        return 'Penalty Missed';
      case 'yellow_card':
        return 'Yellow Card';
      case 'red_card':
        return 'Red Card';
      case 'substitution':
        return 'Substitution';
      case 'var_decision':
        return 'VAR Decision';
      case 'kick_off':
        return 'Kick Off';
      case 'half_time':
        return 'Half Time';
      case 'full_time':
        return 'Full Time';
      default:
        return eventType;
    }
  }
}
