class MatchOddsModel {
  const MatchOddsModel({
    required this.matchId,
    required this.homeMultiplier,
    required this.drawMultiplier,
    required this.awayMultiplier,
    required this.provider,
    this.refreshedAt,
  });

  final String matchId;
  final double homeMultiplier;
  final double drawMultiplier;
  final double awayMultiplier;
  final String provider;
  final DateTime? refreshedAt;

  factory MatchOddsModel.fromJson(Map<String, dynamic> json) {
    return MatchOddsModel(
      matchId: json['match_id'] as String? ?? '',
      homeMultiplier: (json['home_multiplier'] as num?)?.toDouble() ?? 0,
      drawMultiplier: (json['draw_multiplier'] as num?)?.toDouble() ?? 0,
      awayMultiplier: (json['away_multiplier'] as num?)?.toDouble() ?? 0,
      provider: json['provider'] as String? ?? 'unknown',
      refreshedAt: json['refreshed_at'] != null
          ? DateTime.tryParse(json['refreshed_at'].toString())
          : null,
    );
  }

  double? multiplierForSelection(String selection) {
    switch (selection) {
      case '1':
        return homeMultiplier > 0 ? homeMultiplier : null;
      case 'X':
        return drawMultiplier > 0 ? drawMultiplier : null;
      case '2':
        return awayMultiplier > 0 ? awayMultiplier : null;
      default:
        return null;
    }
  }
}
