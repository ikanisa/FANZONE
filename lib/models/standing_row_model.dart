class StandingRowModel {
  const StandingRowModel({
    required this.competitionId,
    required this.season,
    required this.teamId,
    required this.teamName,
    required this.position,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
  });

  final String competitionId;
  final String season;
  final String? teamId;
  final String teamName;
  final int position;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;

  factory StandingRowModel.fromJson(Map<String, dynamic> json) {
    return StandingRowModel(
      competitionId: json['competition_id'] as String,
      season: json['season'] as String? ?? '',
      teamId: json['team_id'] as String?,
      teamName: json['team_name'] as String? ?? 'Team',
      position: (json['position'] as num?)?.toInt() ?? 0,
      played: (json['played'] as num?)?.toInt() ?? 0,
      won: (json['won'] as num?)?.toInt() ?? 0,
      drawn: (json['drawn'] as num?)?.toInt() ?? 0,
      lost: (json['lost'] as num?)?.toInt() ?? 0,
      goalsFor: (json['goals_for'] as num?)?.toInt() ?? 0,
      goalsAgainst: (json['goals_against'] as num?)?.toInt() ?? 0,
      goalDifference: (json['goal_difference'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}
