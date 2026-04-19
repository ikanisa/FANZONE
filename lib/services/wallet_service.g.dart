// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$walletServiceHash() => r'2d6f308ea805a92d8b923a87a40cfd7f507f877a';

/// See also [WalletService].
@ProviderFor(WalletService)
final walletServiceProvider =
    AutoDisposeAsyncNotifierProvider<WalletService, int>.internal(
      WalletService.new,
      name: r'walletServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$walletServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$WalletService = AutoDisposeAsyncNotifier<int>;
String _$transactionServiceHash() =>
    r'50c6c28d7fd7fe936600a9a5256d6166c294a9f2';

/// See also [TransactionService].
@ProviderFor(TransactionService)
final transactionServiceProvider =
    AutoDisposeAsyncNotifierProvider<
      TransactionService,
      List<WalletTransaction>
    >.internal(
      TransactionService.new,
      name: r'transactionServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transactionServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TransactionService =
    AutoDisposeAsyncNotifier<List<WalletTransaction>>;
String _$fanClubServiceHash() => r'44bb441a1572e1469684cf96485fe369c8769bec';

/// See also [FanClubService].
@ProviderFor(FanClubService)
final fanClubServiceProvider =
    AutoDisposeAsyncNotifierProvider<FanClubService, List<FanClub>>.internal(
      FanClubService.new,
      name: r'fanClubServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$fanClubServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$FanClubService = AutoDisposeAsyncNotifier<List<FanClub>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
