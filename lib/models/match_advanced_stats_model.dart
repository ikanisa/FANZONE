/// Advanced match-level statistics (xG, possession, shots, cards, etc.)
/// Maps to `public.match_advanced_stats` (migration 009).
class MatchAdvancedStats {
  final String id;
  final String matchId;
  final double? homeXg;
  final double? awayXg;
  final int? homePossession;
  final int? awayPossession;
  final int homeShots;
  final int awayShots;
  final int homeShotsOnTarget;
  final int awayShotsOnTarget;
  final int homeCorners;
  final int awayCorners;
  final int homeFouls;
  final int awayFouls;
  final int homeYellowCards;
  final int awayYellowCards;
  final int homeRedCards;
  final int awayRedCards;
  final String dataSource;
  final DateTime? refreshedAt;

  const MatchAdvancedStats({
    required this.id,
    required this.matchId,
    this.homeXg,
    this.awayXg,
    this.homePossession,
    this.awayPossession,
    this.homeShots = 0,
    this.awayShots = 0,
    this.homeShotsOnTarget = 0,
    this.awayShotsOnTarget = 0,
    this.homeCorners = 0,
    this.awayCorners = 0,
    this.homeFouls = 0,
    this.awayFouls = 0,
    this.homeYellowCards = 0,
    this.awayYellowCards = 0,
    this.homeRedCards = 0,
    this.awayRedCards = 0,
    this.dataSource = 'gemini_grounded',
    this.refreshedAt,
  });

  factory MatchAdvancedStats.fromJson(Map<String, dynamic> json) {
    return MatchAdvancedStats(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      homeXg: (json['home_xg'] as num?)?.toDouble(),
      awayXg: (json['away_xg'] as num?)?.toDouble(),
      homePossession: json['home_possession'] as int?,
      awayPossession: json['away_possession'] as int?,
      homeShots: json['home_shots'] as int? ?? 0,
      awayShots: json['away_shots'] as int? ?? 0,
      homeShotsOnTarget: json['home_shots_on_target'] as int? ?? 0,
      awayShotsOnTarget: json['away_shots_on_target'] as int? ?? 0,
      homeCorners: json['home_corners'] as int? ?? 0,
      awayCorners: json['away_corners'] as int? ?? 0,
      homeFouls: json['home_fouls'] as int? ?? 0,
      awayFouls: json['away_fouls'] as int? ?? 0,
      homeYellowCards: json['home_yellow_cards'] as int? ?? 0,
      awayYellowCards: json['away_yellow_cards'] as int? ?? 0,
      homeRedCards: json['home_red_cards'] as int? ?? 0,
      awayRedCards: json['away_red_cards'] as int? ?? 0,
      dataSource: json['data_source'] as String? ?? 'gemini_grounded',
      refreshedAt: json['refreshed_at'] != null
          ? DateTime.tryParse(json['refreshed_at'] as String)
          : null,
    );
  }

  /// Whether any meaningful stats have been populated.
  bool get hasData =>
      homeXg != null ||
      homePossession != null ||
      homeShots > 0 ||
      awayShots > 0;
}
