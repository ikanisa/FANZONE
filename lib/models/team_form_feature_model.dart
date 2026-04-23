class TeamFormFeatureModel {
  const TeamFormFeatureModel({
    required this.id,
    required this.matchId,
    required this.teamId,
    required this.last5Points,
    required this.last5Wins,
    required this.last5Draws,
    required this.last5Losses,
    required this.last5GoalsFor,
    required this.last5GoalsAgainst,
    required this.last5CleanSheets,
    required this.last5FailedToScore,
    required this.homeFormLast5,
    required this.awayFormLast5,
    required this.over25Last5,
    required this.bttsLast5,
  });

  final String id;
  final String matchId;
  final String teamId;
  final int last5Points;
  final int last5Wins;
  final int last5Draws;
  final int last5Losses;
  final int last5GoalsFor;
  final int last5GoalsAgainst;
  final int last5CleanSheets;
  final int last5FailedToScore;
  final int homeFormLast5;
  final int awayFormLast5;
  final int over25Last5;
  final int bttsLast5;

  factory TeamFormFeatureModel.fromJson(Map<String, dynamic> json) {
    int parseInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return TeamFormFeatureModel(
      id: json['id']?.toString() ?? '',
      matchId: json['match_id']?.toString() ?? '',
      teamId: json['team_id']?.toString() ?? '',
      last5Points: parseInt(json['last5_points']),
      last5Wins: parseInt(json['last5_wins']),
      last5Draws: parseInt(json['last5_draws']),
      last5Losses: parseInt(json['last5_losses']),
      last5GoalsFor: parseInt(json['last5_goals_for']),
      last5GoalsAgainst: parseInt(json['last5_goals_against']),
      last5CleanSheets: parseInt(json['last5_clean_sheets']),
      last5FailedToScore: parseInt(json['last5_failed_to_score']),
      homeFormLast5: parseInt(json['home_form_last5']),
      awayFormLast5: parseInt(json['away_form_last5']),
      over25Last5: parseInt(json['over25_last5']),
      bttsLast5: parseInt(json['btts_last5']),
    );
  }
}
