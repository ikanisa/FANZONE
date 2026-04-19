import 'package:freezed_annotation/freezed_annotation.dart';

part 'team_model.freezed.dart';
part 'team_model.g.dart';

/// Team model — maps to Supabase `teams` table.
///
/// Extended with community, contribution, and identity fields
/// for the Teams & Fan Communities feature.
@freezed
class TeamModel with _$TeamModel {
  const factory TeamModel({
    required String id,
    required String name,
    @JsonKey(name: 'short_name') String? shortName,
    String? slug,
    String? country,
    String? description,
    @JsonKey(name: 'league_name') String? leagueName,
    @JsonKey(name: 'competition_ids') @Default([]) List<String> competitionIds,
    @Default([]) List<String> aliases,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'crest_url') String? crestUrl,
    @JsonKey(name: 'cover_image_url') String? coverImageUrl,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'is_featured') @Default(false) bool isFeatured,
    @JsonKey(name: 'fet_contributions_enabled')
    @Default(false)
    bool fetContributionsEnabled,
    @JsonKey(name: 'fiat_contributions_enabled')
    @Default(false)
    bool fiatContributionsEnabled,
    @JsonKey(name: 'fiat_contribution_mode') String? fiatContributionMode,
    @JsonKey(name: 'fiat_contribution_link') String? fiatContributionLink,
    @JsonKey(name: 'fan_count') @Default(0) int fanCount,
  }) = _TeamModel;

  factory TeamModel.fromJson(Map<String, dynamic> json) =>
      _$TeamModelFromJson(json);
}
