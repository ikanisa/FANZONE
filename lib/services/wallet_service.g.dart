// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$walletServiceHash() => r'1dde47df1921a09aea6648c1230678bdcbfaaf71';

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
    r'969199ab7cb5ee310c7102e5321f28b82007eedd';

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
String _$fanClubServiceHash() => r'74b99ac8bc7c57f56cc44ce6c0fac9892516cd04';

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
