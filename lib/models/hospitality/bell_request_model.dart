import 'package:freezed_annotation/freezed_annotation.dart';

part 'bell_request_model.freezed.dart';
part 'bell_request_model.g.dart';

/// Maps to `public.bell_requests`.
@freezed
class BellRequestModel with _$BellRequestModel {
  const factory BellRequestModel({
    required String id,
    @JsonKey(name: 'venue_id') required String venueId,
    @JsonKey(name: 'table_id') required String tableId,
    @JsonKey(name: 'user_id') required String userId,
    String? message,
    @JsonKey(name: 'acknowledged_at') DateTime? acknowledgedAt,
    @JsonKey(name: 'acknowledged_by') String? acknowledgedBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _BellRequestModel;

  const BellRequestModel._();

  factory BellRequestModel.fromJson(Map<String, dynamic> json) =>
      _$BellRequestModelFromJson(json);

  bool get isAcknowledged => acknowledgedAt != null;

  Duration? get waitDuration {
    final created = createdAt;
    if (created == null) return null;
    return DateTime.now().difference(created);
  }
}
