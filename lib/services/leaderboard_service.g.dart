// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leaderboard_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userRankHash() => r'be60d8a75a5f32ebfe5d46153c41d94c94679963';

/// See also [userRank].
@ProviderFor(userRank)
final userRankProvider = AutoDisposeFutureProvider<int?>.internal(
  userRank,
  name: r'userRankProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userRankHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserRankRef = AutoDisposeFutureProviderRef<int?>;
String _$globalLeaderboardHash() => r'102476a482f213578f8b950ae9867ad2b9f23638';

/// See also [GlobalLeaderboard].
@ProviderFor(GlobalLeaderboard)
final globalLeaderboardProvider =
    AutoDisposeAsyncNotifierProvider<
      GlobalLeaderboard,
      List<Map<String, dynamic>>
    >.internal(
      GlobalLeaderboard.new,
      name: r'globalLeaderboardProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$globalLeaderboardHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$GlobalLeaderboard =
    AutoDisposeAsyncNotifier<List<Map<String, dynamic>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
