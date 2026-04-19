// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wallet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WalletTransaction _$WalletTransactionFromJson(Map<String, dynamic> json) {
  return _WalletTransaction.fromJson(json);
}

/// @nodoc
mixin _$WalletTransaction {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  int get amount => throw _privateConstructorUsedError;
  String get type =>
      throw _privateConstructorUsedError; // 'earn' | 'spend' | 'transfer_sent' | 'transfer_received'
  DateTime get date => throw _privateConstructorUsedError;
  String get dateStr => throw _privateConstructorUsedError;

  /// Serializes this WalletTransaction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WalletTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WalletTransactionCopyWith<WalletTransaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WalletTransactionCopyWith<$Res> {
  factory $WalletTransactionCopyWith(
    WalletTransaction value,
    $Res Function(WalletTransaction) then,
  ) = _$WalletTransactionCopyWithImpl<$Res, WalletTransaction>;
  @useResult
  $Res call({
    String id,
    String title,
    int amount,
    String type,
    DateTime date,
    String dateStr,
  });
}

/// @nodoc
class _$WalletTransactionCopyWithImpl<$Res, $Val extends WalletTransaction>
    implements $WalletTransactionCopyWith<$Res> {
  _$WalletTransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WalletTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? amount = null,
    Object? type = null,
    Object? date = null,
    Object? dateStr = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as int,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            dateStr: null == dateStr
                ? _value.dateStr
                : dateStr // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WalletTransactionImplCopyWith<$Res>
    implements $WalletTransactionCopyWith<$Res> {
  factory _$$WalletTransactionImplCopyWith(
    _$WalletTransactionImpl value,
    $Res Function(_$WalletTransactionImpl) then,
  ) = __$$WalletTransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    int amount,
    String type,
    DateTime date,
    String dateStr,
  });
}

/// @nodoc
class __$$WalletTransactionImplCopyWithImpl<$Res>
    extends _$WalletTransactionCopyWithImpl<$Res, _$WalletTransactionImpl>
    implements _$$WalletTransactionImplCopyWith<$Res> {
  __$$WalletTransactionImplCopyWithImpl(
    _$WalletTransactionImpl _value,
    $Res Function(_$WalletTransactionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WalletTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? amount = null,
    Object? type = null,
    Object? date = null,
    Object? dateStr = null,
  }) {
    return _then(
      _$WalletTransactionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as int,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        dateStr: null == dateStr
            ? _value.dateStr
            : dateStr // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WalletTransactionImpl implements _WalletTransaction {
  const _$WalletTransactionImpl({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    required this.dateStr,
  });

  factory _$WalletTransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$WalletTransactionImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final int amount;
  @override
  final String type;
  // 'earn' | 'spend' | 'transfer_sent' | 'transfer_received'
  @override
  final DateTime date;
  @override
  final String dateStr;

  @override
  String toString() {
    return 'WalletTransaction(id: $id, title: $title, amount: $amount, type: $type, date: $date, dateStr: $dateStr)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WalletTransactionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.dateStr, dateStr) || other.dateStr == dateStr));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, title, amount, type, date, dateStr);

  /// Create a copy of WalletTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WalletTransactionImplCopyWith<_$WalletTransactionImpl> get copyWith =>
      __$$WalletTransactionImplCopyWithImpl<_$WalletTransactionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WalletTransactionImplToJson(this);
  }
}

abstract class _WalletTransaction implements WalletTransaction {
  const factory _WalletTransaction({
    required final String id,
    required final String title,
    required final int amount,
    required final String type,
    required final DateTime date,
    required final String dateStr,
  }) = _$WalletTransactionImpl;

  factory _WalletTransaction.fromJson(Map<String, dynamic> json) =
      _$WalletTransactionImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  int get amount;
  @override
  String get type; // 'earn' | 'spend' | 'transfer_sent' | 'transfer_received'
  @override
  DateTime get date;
  @override
  String get dateStr;

  /// Create a copy of WalletTransaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WalletTransactionImplCopyWith<_$WalletTransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FanClub _$FanClubFromJson(Map<String, dynamic> json) {
  return _FanClub.fromJson(json);
}

/// @nodoc
mixin _$FanClub {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get members => throw _privateConstructorUsedError;
  int get totalPool => throw _privateConstructorUsedError;
  String get crest => throw _privateConstructorUsedError;
  String get league => throw _privateConstructorUsedError;
  int get rank => throw _privateConstructorUsedError;

  /// Serializes this FanClub to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FanClub
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FanClubCopyWith<FanClub> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FanClubCopyWith<$Res> {
  factory $FanClubCopyWith(FanClub value, $Res Function(FanClub) then) =
      _$FanClubCopyWithImpl<$Res, FanClub>;
  @useResult
  $Res call({
    String id,
    String name,
    int members,
    int totalPool,
    String crest,
    String league,
    int rank,
  });
}

/// @nodoc
class _$FanClubCopyWithImpl<$Res, $Val extends FanClub>
    implements $FanClubCopyWith<$Res> {
  _$FanClubCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FanClub
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? members = null,
    Object? totalPool = null,
    Object? crest = null,
    Object? league = null,
    Object? rank = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            members: null == members
                ? _value.members
                : members // ignore: cast_nullable_to_non_nullable
                      as int,
            totalPool: null == totalPool
                ? _value.totalPool
                : totalPool // ignore: cast_nullable_to_non_nullable
                      as int,
            crest: null == crest
                ? _value.crest
                : crest // ignore: cast_nullable_to_non_nullable
                      as String,
            league: null == league
                ? _value.league
                : league // ignore: cast_nullable_to_non_nullable
                      as String,
            rank: null == rank
                ? _value.rank
                : rank // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FanClubImplCopyWith<$Res> implements $FanClubCopyWith<$Res> {
  factory _$$FanClubImplCopyWith(
    _$FanClubImpl value,
    $Res Function(_$FanClubImpl) then,
  ) = __$$FanClubImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    int members,
    int totalPool,
    String crest,
    String league,
    int rank,
  });
}

/// @nodoc
class __$$FanClubImplCopyWithImpl<$Res>
    extends _$FanClubCopyWithImpl<$Res, _$FanClubImpl>
    implements _$$FanClubImplCopyWith<$Res> {
  __$$FanClubImplCopyWithImpl(
    _$FanClubImpl _value,
    $Res Function(_$FanClubImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FanClub
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? members = null,
    Object? totalPool = null,
    Object? crest = null,
    Object? league = null,
    Object? rank = null,
  }) {
    return _then(
      _$FanClubImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        members: null == members
            ? _value.members
            : members // ignore: cast_nullable_to_non_nullable
                  as int,
        totalPool: null == totalPool
            ? _value.totalPool
            : totalPool // ignore: cast_nullable_to_non_nullable
                  as int,
        crest: null == crest
            ? _value.crest
            : crest // ignore: cast_nullable_to_non_nullable
                  as String,
        league: null == league
            ? _value.league
            : league // ignore: cast_nullable_to_non_nullable
                  as String,
        rank: null == rank
            ? _value.rank
            : rank // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FanClubImpl implements _FanClub {
  const _$FanClubImpl({
    required this.id,
    required this.name,
    required this.members,
    required this.totalPool,
    required this.crest,
    required this.league,
    required this.rank,
  });

  factory _$FanClubImpl.fromJson(Map<String, dynamic> json) =>
      _$$FanClubImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final int members;
  @override
  final int totalPool;
  @override
  final String crest;
  @override
  final String league;
  @override
  final int rank;

  @override
  String toString() {
    return 'FanClub(id: $id, name: $name, members: $members, totalPool: $totalPool, crest: $crest, league: $league, rank: $rank)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FanClubImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.members, members) || other.members == members) &&
            (identical(other.totalPool, totalPool) ||
                other.totalPool == totalPool) &&
            (identical(other.crest, crest) || other.crest == crest) &&
            (identical(other.league, league) || other.league == league) &&
            (identical(other.rank, rank) || other.rank == rank));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    members,
    totalPool,
    crest,
    league,
    rank,
  );

  /// Create a copy of FanClub
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FanClubImplCopyWith<_$FanClubImpl> get copyWith =>
      __$$FanClubImplCopyWithImpl<_$FanClubImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FanClubImplToJson(this);
  }
}

abstract class _FanClub implements FanClub {
  const factory _FanClub({
    required final String id,
    required final String name,
    required final int members,
    required final int totalPool,
    required final String crest,
    required final String league,
    required final int rank,
  }) = _$FanClubImpl;

  factory _FanClub.fromJson(Map<String, dynamic> json) = _$FanClubImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  int get members;
  @override
  int get totalPool;
  @override
  String get crest;
  @override
  String get league;
  @override
  int get rank;

  /// Create a copy of FanClub
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FanClubImplCopyWith<_$FanClubImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
