// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$walletServiceHash() => r'647e9040b79618db002c604b224081ca4707dc41';

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
    r'21c50cbeb092e2315adaa10e3671506256b74c30';

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
String _$fanClubServiceHash() => r'930cbdc72209906d52c286843e0984c2430dd560';

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
