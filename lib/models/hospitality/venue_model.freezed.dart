// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'venue_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

VenueModel _$VenueModelFromJson(Map<String, dynamic> json) {
  return _VenueModel.fromJson(json);
}

/// @nodoc
mixin _$VenueModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'owner_id')
  String? get ownerId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get slug => throw _privateConstructorUsedError;
  @JsonKey(name: 'country_code')
  CountryCode get countryCode => throw _privateConstructorUsedError;
  @JsonKey(name: 'venue_type')
  VenueType get venueType => throw _privateConstructorUsedError;
  @JsonKey(name: 'currency_code')
  String get currencyCode => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'contact_email')
  String? get contactEmail => throw _privateConstructorUsedError;
  @JsonKey(name: 'contact_phone_last4')
  String? get contactPhoneLast4 => throw _privateConstructorUsedError;
  @JsonKey(name: 'website_url')
  String? get websiteUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'google_place_id')
  String? get googlePlaceId => throw _privateConstructorUsedError;
  @JsonKey(name: 'address_line1')
  String? get addressLine1 => throw _privateConstructorUsedError;
  @JsonKey(name: 'address_line2')
  String? get addressLine2 => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  String? get region => throw _privateConstructorUsedError;
  @JsonKey(name: 'postal_code')
  String? get postalCode => throw _privateConstructorUsedError;
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;
  String get timezone => throw _privateConstructorUsedError;
  @JsonKey(name: 'logo_url')
  String? get logoUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'cover_url')
  String? get coverUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_open')
  bool get isOpen => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'onboarding_status')
  OnboardingStatus get onboardingStatus => throw _privateConstructorUsedError;
  @JsonKey(name: 'revolut_link')
  String? get revolutLink => throw _privateConstructorUsedError;
  @JsonKey(name: 'momo_code')
  String? get momoCode => throw _privateConstructorUsedError;
  String? get whatsapp => throw _privateConstructorUsedError;
  @JsonKey(name: 'primary_category')
  String? get primaryCategory => throw _privateConstructorUsedError;
  double? get rating => throw _privateConstructorUsedError;
  @JsonKey(name: 'price_level')
  int? get priceLevel => throw _privateConstructorUsedError;
  @JsonKey(name: 'price_band')
  int? get priceBand => throw _privateConstructorUsedError;
  @JsonKey(name: 'hours_json')
  Map<String, dynamic>? get hoursJson => throw _privateConstructorUsedError;
  @JsonKey(name: 'photos_json')
  List<dynamic>? get photosJson => throw _privateConstructorUsedError;
  @JsonKey(name: 'features_json')
  Map<String, dynamic>? get featuresJson => throw _privateConstructorUsedError;
  @JsonKey(name: 'verified_at')
  DateTime? get verifiedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this VenueModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VenueModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VenueModelCopyWith<VenueModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VenueModelCopyWith<$Res> {
  factory $VenueModelCopyWith(
    VenueModel value,
    $Res Function(VenueModel) then,
  ) = _$VenueModelCopyWithImpl<$Res, VenueModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'owner_id') String? ownerId,
    String name,
    String? slug,
    @JsonKey(name: 'country_code') CountryCode countryCode,
    @JsonKey(name: 'venue_type') VenueType venueType,
    @JsonKey(name: 'currency_code') String currencyCode,
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
    String timezone,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'cover_url') String? coverUrl,
    @JsonKey(name: 'is_open') bool isOpen,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'onboarding_status') OnboardingStatus onboardingStatus,
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
  });
}

/// @nodoc
class _$VenueModelCopyWithImpl<$Res, $Val extends VenueModel>
    implements $VenueModelCopyWith<$Res> {
  _$VenueModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VenueModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ownerId = freezed,
    Object? name = null,
    Object? slug = freezed,
    Object? countryCode = null,
    Object? venueType = null,
    Object? currencyCode = null,
    Object? description = freezed,
    Object? contactEmail = freezed,
    Object? contactPhoneLast4 = freezed,
    Object? websiteUrl = freezed,
    Object? googlePlaceId = freezed,
    Object? addressLine1 = freezed,
    Object? addressLine2 = freezed,
    Object? city = freezed,
    Object? region = freezed,
    Object? postalCode = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? timezone = null,
    Object? logoUrl = freezed,
    Object? coverUrl = freezed,
    Object? isOpen = null,
    Object? isActive = null,
    Object? onboardingStatus = null,
    Object? revolutLink = freezed,
    Object? momoCode = freezed,
    Object? whatsapp = freezed,
    Object? primaryCategory = freezed,
    Object? rating = freezed,
    Object? priceLevel = freezed,
    Object? priceBand = freezed,
    Object? hoursJson = freezed,
    Object? photosJson = freezed,
    Object? featuresJson = freezed,
    Object? verifiedAt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            ownerId: freezed == ownerId
                ? _value.ownerId
                : ownerId // ignore: cast_nullable_to_non_nullable
                      as String?,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            slug: freezed == slug
                ? _value.slug
                : slug // ignore: cast_nullable_to_non_nullable
                      as String?,
            countryCode: null == countryCode
                ? _value.countryCode
                : countryCode // ignore: cast_nullable_to_non_nullable
                      as CountryCode,
            venueType: null == venueType
                ? _value.venueType
                : venueType // ignore: cast_nullable_to_non_nullable
                      as VenueType,
            currencyCode: null == currencyCode
                ? _value.currencyCode
                : currencyCode // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            contactEmail: freezed == contactEmail
                ? _value.contactEmail
                : contactEmail // ignore: cast_nullable_to_non_nullable
                      as String?,
            contactPhoneLast4: freezed == contactPhoneLast4
                ? _value.contactPhoneLast4
                : contactPhoneLast4 // ignore: cast_nullable_to_non_nullable
                      as String?,
            websiteUrl: freezed == websiteUrl
                ? _value.websiteUrl
                : websiteUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            googlePlaceId: freezed == googlePlaceId
                ? _value.googlePlaceId
                : googlePlaceId // ignore: cast_nullable_to_non_nullable
                      as String?,
            addressLine1: freezed == addressLine1
                ? _value.addressLine1
                : addressLine1 // ignore: cast_nullable_to_non_nullable
                      as String?,
            addressLine2: freezed == addressLine2
                ? _value.addressLine2
                : addressLine2 // ignore: cast_nullable_to_non_nullable
                      as String?,
            city: freezed == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String?,
            region: freezed == region
                ? _value.region
                : region // ignore: cast_nullable_to_non_nullable
                      as String?,
            postalCode: freezed == postalCode
                ? _value.postalCode
                : postalCode // ignore: cast_nullable_to_non_nullable
                      as String?,
            latitude: freezed == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            longitude: freezed == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            timezone: null == timezone
                ? _value.timezone
                : timezone // ignore: cast_nullable_to_non_nullable
                      as String,
            logoUrl: freezed == logoUrl
                ? _value.logoUrl
                : logoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            coverUrl: freezed == coverUrl
                ? _value.coverUrl
                : coverUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            isOpen: null == isOpen
                ? _value.isOpen
                : isOpen // ignore: cast_nullable_to_non_nullable
                      as bool,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            onboardingStatus: null == onboardingStatus
                ? _value.onboardingStatus
                : onboardingStatus // ignore: cast_nullable_to_non_nullable
                      as OnboardingStatus,
            revolutLink: freezed == revolutLink
                ? _value.revolutLink
                : revolutLink // ignore: cast_nullable_to_non_nullable
                      as String?,
            momoCode: freezed == momoCode
                ? _value.momoCode
                : momoCode // ignore: cast_nullable_to_non_nullable
                      as String?,
            whatsapp: freezed == whatsapp
                ? _value.whatsapp
                : whatsapp // ignore: cast_nullable_to_non_nullable
                      as String?,
            primaryCategory: freezed == primaryCategory
                ? _value.primaryCategory
                : primaryCategory // ignore: cast_nullable_to_non_nullable
                      as String?,
            rating: freezed == rating
                ? _value.rating
                : rating // ignore: cast_nullable_to_non_nullable
                      as double?,
            priceLevel: freezed == priceLevel
                ? _value.priceLevel
                : priceLevel // ignore: cast_nullable_to_non_nullable
                      as int?,
            priceBand: freezed == priceBand
                ? _value.priceBand
                : priceBand // ignore: cast_nullable_to_non_nullable
                      as int?,
            hoursJson: freezed == hoursJson
                ? _value.hoursJson
                : hoursJson // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            photosJson: freezed == photosJson
                ? _value.photosJson
                : photosJson // ignore: cast_nullable_to_non_nullable
                      as List<dynamic>?,
            featuresJson: freezed == featuresJson
                ? _value.featuresJson
                : featuresJson // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            verifiedAt: freezed == verifiedAt
                ? _value.verifiedAt
                : verifiedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VenueModelImplCopyWith<$Res>
    implements $VenueModelCopyWith<$Res> {
  factory _$$VenueModelImplCopyWith(
    _$VenueModelImpl value,
    $Res Function(_$VenueModelImpl) then,
  ) = __$$VenueModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'owner_id') String? ownerId,
    String name,
    String? slug,
    @JsonKey(name: 'country_code') CountryCode countryCode,
    @JsonKey(name: 'venue_type') VenueType venueType,
    @JsonKey(name: 'currency_code') String currencyCode,
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
    String timezone,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'cover_url') String? coverUrl,
    @JsonKey(name: 'is_open') bool isOpen,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'onboarding_status') OnboardingStatus onboardingStatus,
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
  });
}

/// @nodoc
class __$$VenueModelImplCopyWithImpl<$Res>
    extends _$VenueModelCopyWithImpl<$Res, _$VenueModelImpl>
    implements _$$VenueModelImplCopyWith<$Res> {
  __$$VenueModelImplCopyWithImpl(
    _$VenueModelImpl _value,
    $Res Function(_$VenueModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VenueModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ownerId = freezed,
    Object? name = null,
    Object? slug = freezed,
    Object? countryCode = null,
    Object? venueType = null,
    Object? currencyCode = null,
    Object? description = freezed,
    Object? contactEmail = freezed,
    Object? contactPhoneLast4 = freezed,
    Object? websiteUrl = freezed,
    Object? googlePlaceId = freezed,
    Object? addressLine1 = freezed,
    Object? addressLine2 = freezed,
    Object? city = freezed,
    Object? region = freezed,
    Object? postalCode = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? timezone = null,
    Object? logoUrl = freezed,
    Object? coverUrl = freezed,
    Object? isOpen = null,
    Object? isActive = null,
    Object? onboardingStatus = null,
    Object? revolutLink = freezed,
    Object? momoCode = freezed,
    Object? whatsapp = freezed,
    Object? primaryCategory = freezed,
    Object? rating = freezed,
    Object? priceLevel = freezed,
    Object? priceBand = freezed,
    Object? hoursJson = freezed,
    Object? photosJson = freezed,
    Object? featuresJson = freezed,
    Object? verifiedAt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$VenueModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        ownerId: freezed == ownerId
            ? _value.ownerId
            : ownerId // ignore: cast_nullable_to_non_nullable
                  as String?,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        slug: freezed == slug
            ? _value.slug
            : slug // ignore: cast_nullable_to_non_nullable
                  as String?,
        countryCode: null == countryCode
            ? _value.countryCode
            : countryCode // ignore: cast_nullable_to_non_nullable
                  as CountryCode,
        venueType: null == venueType
            ? _value.venueType
            : venueType // ignore: cast_nullable_to_non_nullable
                  as VenueType,
        currencyCode: null == currencyCode
            ? _value.currencyCode
            : currencyCode // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        contactEmail: freezed == contactEmail
            ? _value.contactEmail
            : contactEmail // ignore: cast_nullable_to_non_nullable
                  as String?,
        contactPhoneLast4: freezed == contactPhoneLast4
            ? _value.contactPhoneLast4
            : contactPhoneLast4 // ignore: cast_nullable_to_non_nullable
                  as String?,
        websiteUrl: freezed == websiteUrl
            ? _value.websiteUrl
            : websiteUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        googlePlaceId: freezed == googlePlaceId
            ? _value.googlePlaceId
            : googlePlaceId // ignore: cast_nullable_to_non_nullable
                  as String?,
        addressLine1: freezed == addressLine1
            ? _value.addressLine1
            : addressLine1 // ignore: cast_nullable_to_non_nullable
                  as String?,
        addressLine2: freezed == addressLine2
            ? _value.addressLine2
            : addressLine2 // ignore: cast_nullable_to_non_nullable
                  as String?,
        city: freezed == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String?,
        region: freezed == region
            ? _value.region
            : region // ignore: cast_nullable_to_non_nullable
                  as String?,
        postalCode: freezed == postalCode
            ? _value.postalCode
            : postalCode // ignore: cast_nullable_to_non_nullable
                  as String?,
        latitude: freezed == latitude
            ? _value.latitude
            : latitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        longitude: freezed == longitude
            ? _value.longitude
            : longitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        timezone: null == timezone
            ? _value.timezone
            : timezone // ignore: cast_nullable_to_non_nullable
                  as String,
        logoUrl: freezed == logoUrl
            ? _value.logoUrl
            : logoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverUrl: freezed == coverUrl
            ? _value.coverUrl
            : coverUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        isOpen: null == isOpen
            ? _value.isOpen
            : isOpen // ignore: cast_nullable_to_non_nullable
                  as bool,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        onboardingStatus: null == onboardingStatus
            ? _value.onboardingStatus
            : onboardingStatus // ignore: cast_nullable_to_non_nullable
                  as OnboardingStatus,
        revolutLink: freezed == revolutLink
            ? _value.revolutLink
            : revolutLink // ignore: cast_nullable_to_non_nullable
                  as String?,
        momoCode: freezed == momoCode
            ? _value.momoCode
            : momoCode // ignore: cast_nullable_to_non_nullable
                  as String?,
        whatsapp: freezed == whatsapp
            ? _value.whatsapp
            : whatsapp // ignore: cast_nullable_to_non_nullable
                  as String?,
        primaryCategory: freezed == primaryCategory
            ? _value.primaryCategory
            : primaryCategory // ignore: cast_nullable_to_non_nullable
                  as String?,
        rating: freezed == rating
            ? _value.rating
            : rating // ignore: cast_nullable_to_non_nullable
                  as double?,
        priceLevel: freezed == priceLevel
            ? _value.priceLevel
            : priceLevel // ignore: cast_nullable_to_non_nullable
                  as int?,
        priceBand: freezed == priceBand
            ? _value.priceBand
            : priceBand // ignore: cast_nullable_to_non_nullable
                  as int?,
        hoursJson: freezed == hoursJson
            ? _value._hoursJson
            : hoursJson // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        photosJson: freezed == photosJson
            ? _value._photosJson
            : photosJson // ignore: cast_nullable_to_non_nullable
                  as List<dynamic>?,
        featuresJson: freezed == featuresJson
            ? _value._featuresJson
            : featuresJson // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        verifiedAt: freezed == verifiedAt
            ? _value.verifiedAt
            : verifiedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VenueModelImpl extends _VenueModel {
  const _$VenueModelImpl({
    required this.id,
    @JsonKey(name: 'owner_id') this.ownerId,
    required this.name,
    this.slug,
    @JsonKey(name: 'country_code') required this.countryCode,
    @JsonKey(name: 'venue_type') required this.venueType,
    @JsonKey(name: 'currency_code') required this.currencyCode,
    this.description,
    @JsonKey(name: 'contact_email') this.contactEmail,
    @JsonKey(name: 'contact_phone_last4') this.contactPhoneLast4,
    @JsonKey(name: 'website_url') this.websiteUrl,
    @JsonKey(name: 'google_place_id') this.googlePlaceId,
    @JsonKey(name: 'address_line1') this.addressLine1,
    @JsonKey(name: 'address_line2') this.addressLine2,
    this.city,
    this.region,
    @JsonKey(name: 'postal_code') this.postalCode,
    this.latitude,
    this.longitude,
    this.timezone = 'Europe/Malta',
    @JsonKey(name: 'logo_url') this.logoUrl,
    @JsonKey(name: 'cover_url') this.coverUrl,
    @JsonKey(name: 'is_open') this.isOpen = false,
    @JsonKey(name: 'is_active') this.isActive = true,
    @JsonKey(name: 'onboarding_status')
    this.onboardingStatus = OnboardingStatus.draft,
    @JsonKey(name: 'revolut_link') this.revolutLink,
    @JsonKey(name: 'momo_code') this.momoCode,
    this.whatsapp,
    @JsonKey(name: 'primary_category') this.primaryCategory,
    this.rating,
    @JsonKey(name: 'price_level') this.priceLevel,
    @JsonKey(name: 'price_band') this.priceBand,
    @JsonKey(name: 'hours_json') final Map<String, dynamic>? hoursJson,
    @JsonKey(name: 'photos_json') final List<dynamic>? photosJson,
    @JsonKey(name: 'features_json') final Map<String, dynamic>? featuresJson,
    @JsonKey(name: 'verified_at') this.verifiedAt,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'updated_at') this.updatedAt,
  }) : _hoursJson = hoursJson,
       _photosJson = photosJson,
       _featuresJson = featuresJson,
       super._();

  factory _$VenueModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$VenueModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'owner_id')
  final String? ownerId;
  @override
  final String name;
  @override
  final String? slug;
  @override
  @JsonKey(name: 'country_code')
  final CountryCode countryCode;
  @override
  @JsonKey(name: 'venue_type')
  final VenueType venueType;
  @override
  @JsonKey(name: 'currency_code')
  final String currencyCode;
  @override
  final String? description;
  @override
  @JsonKey(name: 'contact_email')
  final String? contactEmail;
  @override
  @JsonKey(name: 'contact_phone_last4')
  final String? contactPhoneLast4;
  @override
  @JsonKey(name: 'website_url')
  final String? websiteUrl;
  @override
  @JsonKey(name: 'google_place_id')
  final String? googlePlaceId;
  @override
  @JsonKey(name: 'address_line1')
  final String? addressLine1;
  @override
  @JsonKey(name: 'address_line2')
  final String? addressLine2;
  @override
  final String? city;
  @override
  final String? region;
  @override
  @JsonKey(name: 'postal_code')
  final String? postalCode;
  @override
  final double? latitude;
  @override
  final double? longitude;
  @override
  @JsonKey()
  final String timezone;
  @override
  @JsonKey(name: 'logo_url')
  final String? logoUrl;
  @override
  @JsonKey(name: 'cover_url')
  final String? coverUrl;
  @override
  @JsonKey(name: 'is_open')
  final bool isOpen;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'onboarding_status')
  final OnboardingStatus onboardingStatus;
  @override
  @JsonKey(name: 'revolut_link')
  final String? revolutLink;
  @override
  @JsonKey(name: 'momo_code')
  final String? momoCode;
  @override
  final String? whatsapp;
  @override
  @JsonKey(name: 'primary_category')
  final String? primaryCategory;
  @override
  final double? rating;
  @override
  @JsonKey(name: 'price_level')
  final int? priceLevel;
  @override
  @JsonKey(name: 'price_band')
  final int? priceBand;
  final Map<String, dynamic>? _hoursJson;
  @override
  @JsonKey(name: 'hours_json')
  Map<String, dynamic>? get hoursJson {
    final value = _hoursJson;
    if (value == null) return null;
    if (_hoursJson is EqualUnmodifiableMapView) return _hoursJson;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final List<dynamic>? _photosJson;
  @override
  @JsonKey(name: 'photos_json')
  List<dynamic>? get photosJson {
    final value = _photosJson;
    if (value == null) return null;
    if (_photosJson is EqualUnmodifiableListView) return _photosJson;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final Map<String, dynamic>? _featuresJson;
  @override
  @JsonKey(name: 'features_json')
  Map<String, dynamic>? get featuresJson {
    final value = _featuresJson;
    if (value == null) return null;
    if (_featuresJson is EqualUnmodifiableMapView) return _featuresJson;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(name: 'verified_at')
  final DateTime? verifiedAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'VenueModel(id: $id, ownerId: $ownerId, name: $name, slug: $slug, countryCode: $countryCode, venueType: $venueType, currencyCode: $currencyCode, description: $description, contactEmail: $contactEmail, contactPhoneLast4: $contactPhoneLast4, websiteUrl: $websiteUrl, googlePlaceId: $googlePlaceId, addressLine1: $addressLine1, addressLine2: $addressLine2, city: $city, region: $region, postalCode: $postalCode, latitude: $latitude, longitude: $longitude, timezone: $timezone, logoUrl: $logoUrl, coverUrl: $coverUrl, isOpen: $isOpen, isActive: $isActive, onboardingStatus: $onboardingStatus, revolutLink: $revolutLink, momoCode: $momoCode, whatsapp: $whatsapp, primaryCategory: $primaryCategory, rating: $rating, priceLevel: $priceLevel, priceBand: $priceBand, hoursJson: $hoursJson, photosJson: $photosJson, featuresJson: $featuresJson, verifiedAt: $verifiedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VenueModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.countryCode, countryCode) ||
                other.countryCode == countryCode) &&
            (identical(other.venueType, venueType) ||
                other.venueType == venueType) &&
            (identical(other.currencyCode, currencyCode) ||
                other.currencyCode == currencyCode) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.contactEmail, contactEmail) ||
                other.contactEmail == contactEmail) &&
            (identical(other.contactPhoneLast4, contactPhoneLast4) ||
                other.contactPhoneLast4 == contactPhoneLast4) &&
            (identical(other.websiteUrl, websiteUrl) ||
                other.websiteUrl == websiteUrl) &&
            (identical(other.googlePlaceId, googlePlaceId) ||
                other.googlePlaceId == googlePlaceId) &&
            (identical(other.addressLine1, addressLine1) ||
                other.addressLine1 == addressLine1) &&
            (identical(other.addressLine2, addressLine2) ||
                other.addressLine2 == addressLine2) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.region, region) || other.region == region) &&
            (identical(other.postalCode, postalCode) ||
                other.postalCode == postalCode) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.isOpen, isOpen) || other.isOpen == isOpen) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.onboardingStatus, onboardingStatus) ||
                other.onboardingStatus == onboardingStatus) &&
            (identical(other.revolutLink, revolutLink) ||
                other.revolutLink == revolutLink) &&
            (identical(other.momoCode, momoCode) ||
                other.momoCode == momoCode) &&
            (identical(other.whatsapp, whatsapp) ||
                other.whatsapp == whatsapp) &&
            (identical(other.primaryCategory, primaryCategory) ||
                other.primaryCategory == primaryCategory) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.priceLevel, priceLevel) ||
                other.priceLevel == priceLevel) &&
            (identical(other.priceBand, priceBand) ||
                other.priceBand == priceBand) &&
            const DeepCollectionEquality().equals(
              other._hoursJson,
              _hoursJson,
            ) &&
            const DeepCollectionEquality().equals(
              other._photosJson,
              _photosJson,
            ) &&
            const DeepCollectionEquality().equals(
              other._featuresJson,
              _featuresJson,
            ) &&
            (identical(other.verifiedAt, verifiedAt) ||
                other.verifiedAt == verifiedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    ownerId,
    name,
    slug,
    countryCode,
    venueType,
    currencyCode,
    description,
    contactEmail,
    contactPhoneLast4,
    websiteUrl,
    googlePlaceId,
    addressLine1,
    addressLine2,
    city,
    region,
    postalCode,
    latitude,
    longitude,
    timezone,
    logoUrl,
    coverUrl,
    isOpen,
    isActive,
    onboardingStatus,
    revolutLink,
    momoCode,
    whatsapp,
    primaryCategory,
    rating,
    priceLevel,
    priceBand,
    const DeepCollectionEquality().hash(_hoursJson),
    const DeepCollectionEquality().hash(_photosJson),
    const DeepCollectionEquality().hash(_featuresJson),
    verifiedAt,
    createdAt,
    updatedAt,
  ]);

  /// Create a copy of VenueModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VenueModelImplCopyWith<_$VenueModelImpl> get copyWith =>
      __$$VenueModelImplCopyWithImpl<_$VenueModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VenueModelImplToJson(this);
  }
}

abstract class _VenueModel extends VenueModel {
  const factory _VenueModel({
    required final String id,
    @JsonKey(name: 'owner_id') final String? ownerId,
    required final String name,
    final String? slug,
    @JsonKey(name: 'country_code') required final CountryCode countryCode,
    @JsonKey(name: 'venue_type') required final VenueType venueType,
    @JsonKey(name: 'currency_code') required final String currencyCode,
    final String? description,
    @JsonKey(name: 'contact_email') final String? contactEmail,
    @JsonKey(name: 'contact_phone_last4') final String? contactPhoneLast4,
    @JsonKey(name: 'website_url') final String? websiteUrl,
    @JsonKey(name: 'google_place_id') final String? googlePlaceId,
    @JsonKey(name: 'address_line1') final String? addressLine1,
    @JsonKey(name: 'address_line2') final String? addressLine2,
    final String? city,
    final String? region,
    @JsonKey(name: 'postal_code') final String? postalCode,
    final double? latitude,
    final double? longitude,
    final String timezone,
    @JsonKey(name: 'logo_url') final String? logoUrl,
    @JsonKey(name: 'cover_url') final String? coverUrl,
    @JsonKey(name: 'is_open') final bool isOpen,
    @JsonKey(name: 'is_active') final bool isActive,
    @JsonKey(name: 'onboarding_status') final OnboardingStatus onboardingStatus,
    @JsonKey(name: 'revolut_link') final String? revolutLink,
    @JsonKey(name: 'momo_code') final String? momoCode,
    final String? whatsapp,
    @JsonKey(name: 'primary_category') final String? primaryCategory,
    final double? rating,
    @JsonKey(name: 'price_level') final int? priceLevel,
    @JsonKey(name: 'price_band') final int? priceBand,
    @JsonKey(name: 'hours_json') final Map<String, dynamic>? hoursJson,
    @JsonKey(name: 'photos_json') final List<dynamic>? photosJson,
    @JsonKey(name: 'features_json') final Map<String, dynamic>? featuresJson,
    @JsonKey(name: 'verified_at') final DateTime? verifiedAt,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'updated_at') final DateTime? updatedAt,
  }) = _$VenueModelImpl;
  const _VenueModel._() : super._();

  factory _VenueModel.fromJson(Map<String, dynamic> json) =
      _$VenueModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'owner_id')
  String? get ownerId;
  @override
  String get name;
  @override
  String? get slug;
  @override
  @JsonKey(name: 'country_code')
  CountryCode get countryCode;
  @override
  @JsonKey(name: 'venue_type')
  VenueType get venueType;
  @override
  @JsonKey(name: 'currency_code')
  String get currencyCode;
  @override
  String? get description;
  @override
  @JsonKey(name: 'contact_email')
  String? get contactEmail;
  @override
  @JsonKey(name: 'contact_phone_last4')
  String? get contactPhoneLast4;
  @override
  @JsonKey(name: 'website_url')
  String? get websiteUrl;
  @override
  @JsonKey(name: 'google_place_id')
  String? get googlePlaceId;
  @override
  @JsonKey(name: 'address_line1')
  String? get addressLine1;
  @override
  @JsonKey(name: 'address_line2')
  String? get addressLine2;
  @override
  String? get city;
  @override
  String? get region;
  @override
  @JsonKey(name: 'postal_code')
  String? get postalCode;
  @override
  double? get latitude;
  @override
  double? get longitude;
  @override
  String get timezone;
  @override
  @JsonKey(name: 'logo_url')
  String? get logoUrl;
  @override
  @JsonKey(name: 'cover_url')
  String? get coverUrl;
  @override
  @JsonKey(name: 'is_open')
  bool get isOpen;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'onboarding_status')
  OnboardingStatus get onboardingStatus;
  @override
  @JsonKey(name: 'revolut_link')
  String? get revolutLink;
  @override
  @JsonKey(name: 'momo_code')
  String? get momoCode;
  @override
  String? get whatsapp;
  @override
  @JsonKey(name: 'primary_category')
  String? get primaryCategory;
  @override
  double? get rating;
  @override
  @JsonKey(name: 'price_level')
  int? get priceLevel;
  @override
  @JsonKey(name: 'price_band')
  int? get priceBand;
  @override
  @JsonKey(name: 'hours_json')
  Map<String, dynamic>? get hoursJson;
  @override
  @JsonKey(name: 'photos_json')
  List<dynamic>? get photosJson;
  @override
  @JsonKey(name: 'features_json')
  Map<String, dynamic>? get featuresJson;
  @override
  @JsonKey(name: 'verified_at')
  DateTime? get verifiedAt;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of VenueModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VenueModelImplCopyWith<_$VenueModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
