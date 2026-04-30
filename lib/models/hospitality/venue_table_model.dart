import 'package:freezed_annotation/freezed_annotation.dart';

part 'venue_table_model.freezed.dart';
part 'venue_table_model.g.dart';

/// Maps to `public.tables` table (physical tables inside venues).
@freezed
class VenueTableModel with _$VenueTableModel {
  const factory VenueTableModel({
    required String id,
    @JsonKey(name: 'venue_id') required String venueId,
    @JsonKey(name: 'table_number') required String tableNumber,
    @JsonKey(name: 'qr_code_url') String? qrCodeUrl,
    @JsonKey(name: 'deep_link_uri') String? deepLinkUri,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _VenueTableModel;

  const VenueTableModel._();

  factory VenueTableModel.fromJson(Map<String, dynamic> json) =>
      _$VenueTableModelFromJson(json);

  /// Display label for UI (e.g., "Table 3").
  String get displayLabel => 'Table $tableNumber';
}
