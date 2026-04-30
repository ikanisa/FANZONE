import 'package:freezed_annotation/freezed_annotation.dart';

part 'venue_match_stake_model.freezed.dart';
part 'venue_match_stake_model.g.dart';

enum VenueStakeStatus {
  @JsonValue('open')
  open,
  @JsonValue('settled')
  settled,
  @JsonValue('cancelled')
  cancelled,
}

@freezed
class VenueMatchStakeModel with _$VenueMatchStakeModel {
  const factory VenueMatchStakeModel({
    required String id,
    @JsonKey(name: 'venue_id') required String venueId,
    @JsonKey(name: 'match_id') required String matchId,
    @JsonKey(name: 'entry_fee_fet') required int entryFeeFet,
    @JsonKey(name: 'total_pool_fet') required int totalPoolFet,
    required VenueStakeStatus status,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _VenueMatchStakeModel;

  factory VenueMatchStakeModel.fromJson(Map<String, dynamic> json) =>
      _$VenueMatchStakeModelFromJson(json);
}
