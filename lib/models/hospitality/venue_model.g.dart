// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'venue_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VenueModelImpl _$$VenueModelImplFromJson(Map<String, dynamic> json) =>
    _$VenueModelImpl(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String?,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      countryCode: $enumDecode(_$CountryCodeEnumMap, json['country_code']),
      venueType: $enumDecode(_$VenueTypeEnumMap, json['venue_type']),
      currencyCode: json['currency_code'] as String,
      description: json['description'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactPhoneLast4: json['contact_phone_last4'] as String?,
      websiteUrl: json['website_url'] as String?,
      googlePlaceId: json['google_place_id'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      postalCode: json['postal_code'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      timezone: json['timezone'] as String? ?? 'Europe/Malta',
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      isOpen: json['is_open'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      onboardingStatus:
          $enumDecodeNullable(
            _$OnboardingStatusEnumMap,
            json['onboarding_status'],
          ) ??
          OnboardingStatus.draft,
      revolutLink: json['revolut_link'] as String?,
      whatsapp: json['whatsapp'] as String?,
      primaryCategory: json['primary_category'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      priceLevel: (json['price_level'] as num?)?.toInt(),
      priceBand: (json['price_band'] as num?)?.toInt(),
      hoursJson: json['hours_json'] as Map<String, dynamic>?,
      photosJson: json['photos_json'] as List<dynamic>?,
      featuresJson: json['features_json'] as Map<String, dynamic>?,
      verifiedAt: json['verified_at'] == null
          ? null
          : DateTime.parse(json['verified_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$VenueModelImplToJson(
  _$VenueModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'owner_id': instance.ownerId,
  'name': instance.name,
  'slug': instance.slug,
  'country_code': _$CountryCodeEnumMap[instance.countryCode]!,
  'venue_type': _$VenueTypeEnumMap[instance.venueType]!,
  'currency_code': instance.currencyCode,
  'description': instance.description,
  'contact_email': instance.contactEmail,
  'contact_phone_last4': instance.contactPhoneLast4,
  'website_url': instance.websiteUrl,
  'google_place_id': instance.googlePlaceId,
  'address_line1': instance.addressLine1,
  'address_line2': instance.addressLine2,
  'city': instance.city,
  'region': instance.region,
  'postal_code': instance.postalCode,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'timezone': instance.timezone,
  'logo_url': instance.logoUrl,
  'cover_url': instance.coverUrl,
  'is_open': instance.isOpen,
  'is_active': instance.isActive,
  'onboarding_status': _$OnboardingStatusEnumMap[instance.onboardingStatus]!,
  'revolut_link': instance.revolutLink,
  'whatsapp': instance.whatsapp,
  'primary_category': instance.primaryCategory,
  'rating': instance.rating,
  'price_level': instance.priceLevel,
  'price_band': instance.priceBand,
  'hours_json': instance.hoursJson,
  'photos_json': instance.photosJson,
  'features_json': instance.featuresJson,
  'verified_at': instance.verifiedAt?.toIso8601String(),
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

const _$CountryCodeEnumMap = {CountryCode.rw: 'RW', CountryCode.mt: 'MT'};

const _$VenueTypeEnumMap = {
  VenueType.bar: 'bar',
  VenueType.restaurant: 'restaurant',
  VenueType.hotel: 'hotel',
  VenueType.event: 'event',
};

const _$OnboardingStatusEnumMap = {
  OnboardingStatus.draft: 'draft',
  OnboardingStatus.profileComplete: 'profile_complete',
  OnboardingStatus.locationComplete: 'location_complete',
  OnboardingStatus.menuPending: 'menu_pending',
  OnboardingStatus.qrGenerated: 'qr_generated',
  OnboardingStatus.live: 'live',
};
