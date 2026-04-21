// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_challenge_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$myDailyEntryHash() => r'7665b7cba2bfabf89f7ed9adb92213eb198adf6c';

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
    r'faf8b862fd03dcecb0d191a0268a860240f0197b';

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
    r'68f92e8b750b4b8afba651c76169b737f54d697b';

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
