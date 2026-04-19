import 'package:freezed_annotation/freezed_annotation.dart';

part 'competition_model.freezed.dart';
part 'competition_model.g.dart';

/// Competition model — maps to Supabase `competitions` table.
@freezed
class CompetitionModel with _$CompetitionModel {
  const factory CompetitionModel({
    required String id,
    required String name,
    @JsonKey(name: 'short_name') required String shortName,
    required String country,
    @Default(1) int tier,
    @JsonKey(name: 'data_source') required String dataSource,
    @JsonKey(name: 'source_file') String? sourceFile,
    @Default([]) List<String> seasons,
    @JsonKey(name: 'team_count') int? teamCount,
    @JsonKey(name: 'logo_url') String? logoUrl,
    // ── Global launch fields (additive, nullable) ──
    String? region,
    @JsonKey(name: 'competition_type') String? competitionType,
    @JsonKey(name: 'is_featured') @Default(false) bool isFeatured,
    @JsonKey(name: 'event_tag') String? eventTag,
    @JsonKey(name: 'start_date') DateTime? startDate,
    @JsonKey(name: 'end_date') DateTime? endDate,
  }) = _CompetitionModel;

  factory CompetitionModel.fromJson(Map<String, dynamic> json) =>
      _$CompetitionModelFromJson(json);
}
