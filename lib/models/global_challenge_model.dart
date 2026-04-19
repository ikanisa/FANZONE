import 'package:freezed_annotation/freezed_annotation.dart';

part 'global_challenge_model.freezed.dart';
part 'global_challenge_model.g.dart';

/// Event-scoped prediction challenge (World Cup Jackpot, UCL Final Challenge, etc.).
/// Maps to Supabase `global_challenges` table.
@freezed
class GlobalChallengeModel with _$GlobalChallengeModel {
  const factory GlobalChallengeModel({
    required String id,
    @JsonKey(name: 'event_tag') required String eventTag,
    required String name,
    String? description,
    @JsonKey(name: 'match_ids') @Default([]) List<String> matchIds,
    @JsonKey(name: 'entry_fee_fet') @Default(0) int entryFeeFet,
    @JsonKey(name: 'prize_pool_fet') @Default(0) int prizePoolFet,
    @JsonKey(name: 'max_participants') int? maxParticipants,
    @JsonKey(name: 'current_participants') @Default(0) int currentParticipants,
    /// global, africa, europe, americas
    @Default('global') String region,
    @Default('open') String status,
    @JsonKey(name: 'start_at') DateTime? startAt,
    @JsonKey(name: 'end_at') DateTime? endAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _GlobalChallengeModel;

  const GlobalChallengeModel._();

  factory GlobalChallengeModel.fromJson(Map<String, dynamic> json) =>
      _$GlobalChallengeModelFromJson(json);

  bool get isOpen => status == 'open';
  bool get isFull =>
      maxParticipants != null && currentParticipants >= maxParticipants!;
}
