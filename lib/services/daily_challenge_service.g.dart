// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_challenge_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$myDailyEntryHash() => r'dc61bbfe667ed957bf68692e84cd53f6b5c7252f';

/// See also [myDailyEntry].
@ProviderFor(myDailyEntry)
final myDailyEntryProvider =
    AutoDisposeFutureProvider<DailyChallengeEntry?>.internal(
      myDailyEntry,
      name: r'myDailyEntryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$myDailyEntryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyDailyEntryRef = AutoDisposeFutureProviderRef<DailyChallengeEntry?>;
String _$dailyChallengeHistoryHash() =>
    r'1c2d88c592d1a43088768c635db61b5eb95ae05d';

/// See also [dailyChallengeHistory].
@ProviderFor(dailyChallengeHistory)
final dailyChallengeHistoryProvider =
    AutoDisposeFutureProvider<List<DailyChallengeEntry>>.internal(
      dailyChallengeHistory,
      name: r'dailyChallengeHistoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dailyChallengeHistoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DailyChallengeHistoryRef =
    AutoDisposeFutureProviderRef<List<DailyChallengeEntry>>;
String _$dailyChallengeServiceHash() =>
    r'576a827bafbc3305279d2f639480128a7a544f92';

/// See also [DailyChallengeService].
@ProviderFor(DailyChallengeService)
final dailyChallengeServiceProvider =
    AutoDisposeAsyncNotifierProvider<
      DailyChallengeService,
      DailyChallenge?
    >.internal(
      DailyChallengeService.new,
      name: r'dailyChallengeServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dailyChallengeServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DailyChallengeService = AutoDisposeAsyncNotifier<DailyChallenge?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
