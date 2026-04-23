import 'package:freezed_annotation/freezed_annotation.dart';

part 'team_model.freezed.dart';
part 'team_model.g.dart';

/// Team model — maps to Supabase `teams` table.
@freezed
class TeamModel with _$TeamModel {
  const factory TeamModel({
    required String id,
    required String name,
    @JsonKey(name: 'short_name') String? shortName,
    String? country,
    @JsonKey(name: 'country_code') String? countryCode,
    @JsonKey(name: 'team_type') @Default('club') String teamType,
    String? description,
    @JsonKey(name: 'league_name') String? leagueName,
    String? region,
    @JsonKey(name: 'competition_ids') @Default([]) List<String> competitionIds,
    @Default([]) List<String> aliases,
    @JsonKey(name: 'search_terms') @Default([]) List<String> searchTerms,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'crest_url') String? crestUrl,
    @JsonKey(name: 'cover_image_url') String? coverImageUrl,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'is_featured') @Default(false) bool isFeatured,
    @JsonKey(name: 'is_popular_pick') @Default(false) bool isPopularPick,
    @JsonKey(name: 'popular_pick_rank') int? popularPickRank,
    @JsonKey(name: 'fan_count') @Default(0) int fanCount,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _TeamModel;

  factory TeamModel.fromJson(Map<String, dynamic> json) =>
      _$TeamModelFromJson(json);
}
