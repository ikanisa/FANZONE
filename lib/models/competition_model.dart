import 'package:freezed_annotation/freezed_annotation.dart';

part 'competition_model.freezed.dart';
part 'competition_model.g.dart';

/// Competition model — maps to Supabase `competitions` table.
@freezed
class CompetitionModel with _$CompetitionModel {
  const factory CompetitionModel({
    required String id,
    required String name,
    @JsonKey(name: 'short_name') @Default('') String shortName,
    @Default('') String country,
    @Default(1) int tier,
    @JsonKey(name: 'competition_type') String? competitionType,
    @JsonKey(name: 'is_featured') @Default(false) bool isFeatured,
    @JsonKey(name: 'is_international') @Default(false) bool isInternational,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'current_season_id') String? currentSeasonId,
    @JsonKey(name: 'current_season_label') String? currentSeasonLabel,
    @JsonKey(name: 'future_match_count') @Default(0) int futureMatchCount,
    @JsonKey(name: 'catalog_rank') int? catalogRank,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _CompetitionModel;

  const CompetitionModel._();

  factory CompetitionModel.fromJson(Map<String, dynamic> json) =>
      _$CompetitionModelFromJson(json);

  String get displayShortName {
    final value = shortName.trim();
    return value.isNotEmpty ? value : name;
  }
}
