// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_news_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TeamNewsModel _$TeamNewsModelFromJson(Map<String, dynamic> json) {
  return _TeamNewsModel.fromJson(json);
}

/// @nodoc
mixin _$TeamNewsModel {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'team_id')
  String get teamId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get summary => throw _privateConstructorUsedError;
  String? get content => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  @JsonKey(name: 'source_url')
  String? get sourceUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'source_name')
  String? get sourceName => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String? get imageUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'published_at')
  DateTime? get publishedAt => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_ai_curated')
  bool get isAiCurated => throw _privateConstructorUsedError;
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this TeamNewsModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TeamNewsModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeamNewsModelCopyWith<TeamNewsModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeamNewsModelCopyWith<$Res> {
  factory $TeamNewsModelCopyWith(
    TeamNewsModel value,
    $Res Function(TeamNewsModel) then,
  ) = _$TeamNewsModelCopyWithImpl<$Res, TeamNewsModel>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    String title,
    String? summary,
    String? content,
    String category,
    @JsonKey(name: 'source_url') String? sourceUrl,
    @JsonKey(name: 'source_name') String? sourceName,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'published_at') DateTime? publishedAt,
    String status,
    @JsonKey(name: 'is_ai_curated') bool isAiCurated,
    Map<String, dynamic> metadata,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class _$TeamNewsModelCopyWithImpl<$Res, $Val extends TeamNewsModel>
    implements $TeamNewsModelCopyWith<$Res> {
  _$TeamNewsModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TeamNewsModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? title = null,
    Object? summary = freezed,
    Object? content = freezed,
    Object? category = null,
    Object? sourceUrl = freezed,
    Object? sourceName = freezed,
    Object? imageUrl = freezed,
    Object? publishedAt = freezed,
    Object? status = null,
    Object? isAiCurated = null,
    Object? metadata = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            teamId: null == teamId
                ? _value.teamId
                : teamId // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            summary: freezed == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                      as String?,
            content: freezed == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String?,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String,
            sourceUrl: freezed == sourceUrl
                ? _value.sourceUrl
                : sourceUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            sourceName: freezed == sourceName
                ? _value.sourceName
                : sourceName // ignore: cast_nullable_to_non_nullable
                      as String?,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            publishedAt: freezed == publishedAt
                ? _value.publishedAt
                : publishedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            isAiCurated: null == isAiCurated
                ? _value.isAiCurated
                : isAiCurated // ignore: cast_nullable_to_non_nullable
                      as bool,
            metadata: null == metadata
                ? _value.metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TeamNewsModelImplCopyWith<$Res>
    implements $TeamNewsModelCopyWith<$Res> {
  factory _$$TeamNewsModelImplCopyWith(
    _$TeamNewsModelImpl value,
    $Res Function(_$TeamNewsModelImpl) then,
  ) = __$$TeamNewsModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'team_id') String teamId,
    String title,
    String? summary,
    String? content,
    String category,
    @JsonKey(name: 'source_url') String? sourceUrl,
    @JsonKey(name: 'source_name') String? sourceName,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'published_at') DateTime? publishedAt,
    String status,
    @JsonKey(name: 'is_ai_curated') bool isAiCurated,
    Map<String, dynamic> metadata,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class __$$TeamNewsModelImplCopyWithImpl<$Res>
    extends _$TeamNewsModelCopyWithImpl<$Res, _$TeamNewsModelImpl>
    implements _$$TeamNewsModelImplCopyWith<$Res> {
  __$$TeamNewsModelImplCopyWithImpl(
    _$TeamNewsModelImpl _value,
    $Res Function(_$TeamNewsModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TeamNewsModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? teamId = null,
    Object? title = null,
    Object? summary = freezed,
    Object? content = freezed,
    Object? category = null,
    Object? sourceUrl = freezed,
    Object? sourceName = freezed,
    Object? imageUrl = freezed,
    Object? publishedAt = freezed,
    Object? status = null,
    Object? isAiCurated = null,
    Object? metadata = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$TeamNewsModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        summary: freezed == summary
            ? _value.summary
            : summary // ignore: cast_nullable_to_non_nullable
                  as String?,
        content: freezed == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String?,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceUrl: freezed == sourceUrl
            ? _value.sourceUrl
            : sourceUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        sourceName: freezed == sourceName
            ? _value.sourceName
            : sourceName // ignore: cast_nullable_to_non_nullable
                  as String?,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        publishedAt: freezed == publishedAt
            ? _value.publishedAt
            : publishedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        isAiCurated: null == isAiCurated
            ? _value.isAiCurated
            : isAiCurated // ignore: cast_nullable_to_non_nullable
                  as bool,
        metadata: null == metadata
            ? _value._metadata
            : metadata // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TeamNewsModelImpl implements _TeamNewsModel {
  const _$TeamNewsModelImpl({
    required this.id,
    @JsonKey(name: 'team_id') required this.teamId,
    required this.title,
    this.summary,
    this.content,
    this.category = 'general',
    @JsonKey(name: 'source_url') this.sourceUrl,
    @JsonKey(name: 'source_name') this.sourceName,
    @JsonKey(name: 'image_url') this.imageUrl,
    @JsonKey(name: 'published_at') this.publishedAt,
    required this.status,
    @JsonKey(name: 'is_ai_curated') this.isAiCurated = true,
    final Map<String, dynamic> metadata = const {},
    @JsonKey(name: 'created_at') this.createdAt,
  }) : _metadata = metadata;

  factory _$TeamNewsModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$TeamNewsModelImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'team_id')
  final String teamId;
  @override
  final String title;
  @override
  final String? summary;
  @override
  final String? content;
  @override
  @JsonKey()
  final String category;
  @override
  @JsonKey(name: 'source_url')
  final String? sourceUrl;
  @override
  @JsonKey(name: 'source_name')
  final String? sourceName;
  @override
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @override
  @JsonKey(name: 'published_at')
  final DateTime? publishedAt;
  @override
  final String status;
  @override
  @JsonKey(name: 'is_ai_curated')
  final bool isAiCurated;
  final Map<String, dynamic> _metadata;
  @override
  @JsonKey()
  Map<String, dynamic> get metadata {
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_metadata);
  }

  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'TeamNewsModel(id: $id, teamId: $teamId, title: $title, summary: $summary, content: $content, category: $category, sourceUrl: $sourceUrl, sourceName: $sourceName, imageUrl: $imageUrl, publishedAt: $publishedAt, status: $status, isAiCurated: $isAiCurated, metadata: $metadata, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeamNewsModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.sourceUrl, sourceUrl) ||
                other.sourceUrl == sourceUrl) &&
            (identical(other.sourceName, sourceName) ||
                other.sourceName == sourceName) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.isAiCurated, isAiCurated) ||
                other.isAiCurated == isAiCurated) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    teamId,
    title,
    summary,
    content,
    category,
    sourceUrl,
    sourceName,
    imageUrl,
    publishedAt,
    status,
    isAiCurated,
    const DeepCollectionEquality().hash(_metadata),
    createdAt,
  );

  /// Create a copy of TeamNewsModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeamNewsModelImplCopyWith<_$TeamNewsModelImpl> get copyWith =>
      __$$TeamNewsModelImplCopyWithImpl<_$TeamNewsModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TeamNewsModelImplToJson(this);
  }
}

abstract class _TeamNewsModel implements TeamNewsModel {
  const factory _TeamNewsModel({
    required final String id,
    @JsonKey(name: 'team_id') required final String teamId,
    required final String title,
    final String? summary,
    final String? content,
    final String category,
    @JsonKey(name: 'source_url') final String? sourceUrl,
    @JsonKey(name: 'source_name') final String? sourceName,
    @JsonKey(name: 'image_url') final String? imageUrl,
    @JsonKey(name: 'published_at') final DateTime? publishedAt,
    required final String status,
    @JsonKey(name: 'is_ai_curated') final bool isAiCurated,
    final Map<String, dynamic> metadata,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
  }) = _$TeamNewsModelImpl;

  factory _TeamNewsModel.fromJson(Map<String, dynamic> json) =
      _$TeamNewsModelImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'team_id')
  String get teamId;
  @override
  String get title;
  @override
  String? get summary;
  @override
  String? get content;
  @override
  String get category;
  @override
  @JsonKey(name: 'source_url')
  String? get sourceUrl;
  @override
  @JsonKey(name: 'source_name')
  String? get sourceName;
  @override
  @JsonKey(name: 'image_url')
  String? get imageUrl;
  @override
  @JsonKey(name: 'published_at')
  DateTime? get publishedAt;
  @override
  String get status;
  @override
  @JsonKey(name: 'is_ai_curated')
  bool get isAiCurated;
  @override
  Map<String, dynamic> get metadata;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of TeamNewsModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeamNewsModelImplCopyWith<_$TeamNewsModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
