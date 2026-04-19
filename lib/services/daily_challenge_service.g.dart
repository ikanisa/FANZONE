// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_challenge_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$myDailyEntryHash() => r'277258a147964ee48f1817db45ec6cfb0c29490a';

/// Provider for the user's entry in today's challenge.
///
/// Copied from [myDailyEntry].
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
    r'f16db0191426523e410a34763f5e15dad8452aa3';

/// Provider for user's daily challenge history (last 30 days).
///
/// Copied from [dailyChallengeHistory].
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
    r'04c098aab32c86e93affe3fe1bd21708df8df28d';

/// Service for daily free prediction challenges.
///
/// Copied from [DailyChallengeService].
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
