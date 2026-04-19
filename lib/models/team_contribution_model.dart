import 'package:freezed_annotation/freezed_annotation.dart';

part 'team_contribution_model.freezed.dart';
part 'team_contribution_model.g.dart';

/// A FET or fiat contribution to a team.
@freezed
class TeamContributionModel with _$TeamContributionModel {
  const factory TeamContributionModel({
    required String id,
    @JsonKey(name: 'team_id') required String teamId,
    @JsonKey(name: 'contribution_type') required String contributionType,
    @JsonKey(name: 'amount_fet') int? amountFet,
    @JsonKey(name: 'amount_money') double? amountMoney,
    @JsonKey(name: 'currency_code') String? currencyCode,
    required String status,
    String? provider,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _TeamContributionModel;

  factory TeamContributionModel.fromJson(Map<String, dynamic> json) =>
      _$TeamContributionModelFromJson(json);
}

/// Aggregated community stats for a team (from the team_community_stats view).
@freezed
class TeamCommunityStats with _$TeamCommunityStats {
  const factory TeamCommunityStats({
    @JsonKey(name: 'team_id') required String teamId,
    @JsonKey(name: 'team_name') required String teamName,
    @JsonKey(name: 'fan_count') @Default(0) int fanCount,
    @JsonKey(name: 'total_fet_contributed') @Default(0) int totalFetContributed,
    @JsonKey(name: 'contribution_count') @Default(0) int contributionCount,
    @JsonKey(name: 'supporters_last_30d') @Default(0) int supportersLast30d,
  }) = _TeamCommunityStats;

  factory TeamCommunityStats.fromJson(Map<String, dynamic> json) =>
      _$TeamCommunityStatsFromJson(json);
}
