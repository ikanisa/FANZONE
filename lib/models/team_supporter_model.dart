import 'package:freezed_annotation/freezed_annotation.dart';

part 'team_supporter_model.freezed.dart';
part 'team_supporter_model.g.dart';

/// A user's team support/fan community membership record.
///
/// The [anonymousFanId] is the only publicly-visible identifier
/// for the supporter — never the real user_id.
@freezed
class TeamSupporterModel with _$TeamSupporterModel {
  const factory TeamSupporterModel({
    required String id,
    @JsonKey(name: 'team_id') required String teamId,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'anonymous_fan_id') required String anonymousFanId,
    @JsonKey(name: 'joined_at') required DateTime joinedAt,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
  }) = _TeamSupporterModel;

  factory TeamSupporterModel.fromJson(Map<String, dynamic> json) =>
      _$TeamSupporterModelFromJson(json);
}

/// Lightweight anonymous fan record — used in public community pages.
/// Contains only anonymous data, never personal identity.
@freezed
class AnonymousFanRecord with _$AnonymousFanRecord {
  const factory AnonymousFanRecord({
    @JsonKey(name: 'anonymous_fan_id') required String anonymousFanId,
    @JsonKey(name: 'joined_at') required DateTime joinedAt,
  }) = _AnonymousFanRecord;

  factory AnonymousFanRecord.fromJson(Map<String, dynamic> json) =>
      _$AnonymousFanRecordFromJson(json);
}
