import 'package:freezed_annotation/freezed_annotation.dart';

part 'featured_event_model.freezed.dart';
part 'featured_event_model.g.dart';

/// A time-bound featured event (World Cup, UCL Final, AFCON, etc.).
/// Maps to Supabase `featured_events` table.
@freezed
class FeaturedEventModel with _$FeaturedEventModel {
  const factory FeaturedEventModel({
    required String id,
    required String name,
    @JsonKey(name: 'short_name') required String shortName,
    @JsonKey(name: 'event_tag') required String eventTag,
    /// global, africa, europe, americas
    @Default('global') String region,
    @JsonKey(name: 'competition_id') String? competitionId,
    @JsonKey(name: 'start_date') required DateTime startDate,
    @JsonKey(name: 'end_date') required DateTime endDate,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'banner_color') String? bannerColor,
    String? description,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _FeaturedEventModel;

  const FeaturedEventModel._();

  factory FeaturedEventModel.fromJson(Map<String, dynamic> json) =>
      _$FeaturedEventModelFromJson(json);

  /// Whether this event is currently active (within date range).
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// Days remaining until the event starts (negative if already started).
  int get daysUntilStart => startDate.difference(DateTime.now()).inDays;

  /// Days remaining until the event ends.
  int get daysRemaining => endDate.difference(DateTime.now()).inDays;
}
