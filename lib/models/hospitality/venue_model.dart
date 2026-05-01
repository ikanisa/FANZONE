import 'package:freezed_annotation/freezed_annotation.dart';

part 'venue_model.freezed.dart';
part 'venue_model.g.dart';

/// Venue types supported by the hospitality platform.
enum VenueType {
  @JsonValue('bar')
  bar,
  @JsonValue('restaurant')
  restaurant,
  @JsonValue('hotel')
  hotel,
  @JsonValue('event')
  event;

  String get label {
    switch (this) {
      case VenueType.bar:
        return 'Bar';
      case VenueType.restaurant:
        return 'Restaurant';
      case VenueType.hotel:
        return 'Hotel';
      case VenueType.event:
        return 'Event';
    }
  }
}

/// Onboarding status for venue setup wizard.
enum OnboardingStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('profile_complete')
  profileComplete,
  @JsonValue('location_complete')
  locationComplete,
  @JsonValue('menu_pending')
  menuPending,
  @JsonValue('qr_generated')
  qrGenerated,
  @JsonValue('live')
  live,
}

/// Country codes supported by the platform.
enum CountryCode {
  @JsonValue('RW')
  rw,
  @JsonValue('MT')
  mt;

  String get label {
    switch (this) {
      case CountryCode.rw:
        return 'Rwanda';
      case CountryCode.mt:
        return 'Malta';
    }
  }

  String get currencyCode {
    switch (this) {
      case CountryCode.rw:
        return 'RWF';
      case CountryCode.mt:
        return 'EUR';
    }
  }
}

/// Maps to `public.venues` table.
@freezed
class VenueModel with _$VenueModel {
  const factory VenueModel({
    required String id,
    @JsonKey(name: 'owner_id') String? ownerId,
    required String name,
    String? slug,
    @JsonKey(name: 'country_code') required CountryCode countryCode,
    @JsonKey(name: 'venue_type') required VenueType venueType,
    @JsonKey(name: 'currency_code') required String currencyCode,
    String? description,
    @JsonKey(name: 'contact_email') String? contactEmail,
    @JsonKey(name: 'contact_phone_last4') String? contactPhoneLast4,
    @JsonKey(name: 'website_url') String? websiteUrl,
    @JsonKey(name: 'google_place_id') String? googlePlaceId,
    @JsonKey(name: 'address_line1') String? addressLine1,
    @JsonKey(name: 'address_line2') String? addressLine2,
    String? city,
    String? region,
    @JsonKey(name: 'postal_code') String? postalCode,
    double? latitude,
    double? longitude,
    @Default('Europe/Malta') String timezone,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'cover_url') String? coverUrl,
    @JsonKey(name: 'is_open') @Default(false) bool isOpen,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'onboarding_status')
    @Default(OnboardingStatus.draft)
    OnboardingStatus onboardingStatus,
    @JsonKey(name: 'revolut_link') String? revolutLink,
    @JsonKey(name: 'momo_code') String? momoCode,
    String? whatsapp,
    @JsonKey(name: 'primary_category') String? primaryCategory,
    double? rating,
    @JsonKey(name: 'price_level') int? priceLevel,
    @JsonKey(name: 'price_band') int? priceBand,
    @JsonKey(name: 'hours_json') Map<String, dynamic>? hoursJson,
    @JsonKey(name: 'photos_json') List<dynamic>? photosJson,
    @JsonKey(name: 'features_json') Map<String, dynamic>? featuresJson,
    @JsonKey(name: 'verified_at') DateTime? verifiedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _VenueModel;

  const VenueModel._();

  factory VenueModel.fromJson(Map<String, dynamic> json) =>
      _$VenueModelFromJson(json);

  /// Whether the venue has completed onboarding and is live.
  bool get isLive => onboardingStatus == OnboardingStatus.live;

  /// Full address string for display.
  String get fullAddress {
    final parts = [
      addressLine1,
      addressLine2,
      city,
      region,
      postalCode,
    ].where((p) => p != null && p.trim().isNotEmpty).toList();
    return parts.join(', ');
  }
}
