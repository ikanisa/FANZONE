// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationLogHash() => r'42a857ba879fb7052da0f2ea61402eadfe1a2fec';

/// See also [notificationLog].
@ProviderFor(notificationLog)
final notificationLogProvider =
    AutoDisposeFutureProvider<List<NotificationItem>>.internal(
      notificationLog,
      name: r'notificationLogProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationLogHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationLogRef =
    AutoDisposeFutureProviderRef<List<NotificationItem>>;
String _$unreadNotificationCountHash() =>
    r'f4ae9dcbab813bc168a6fc07895a9f337c5abae9';

/// See also [unreadNotificationCount].
@ProviderFor(unreadNotificationCount)
final unreadNotificationCountProvider = AutoDisposeFutureProvider<int>.internal(
  unreadNotificationCount,
  name: r'unreadNotificationCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$unreadNotificationCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UnreadNotificationCountRef = AutoDisposeFutureProviderRef<int>;
String _$userStatsHash() => r'a02d0af2c3a49d85523536baf38164e34d7ce01e';

/// See also [userStats].
@ProviderFor(userStats)
final userStatsProvider = AutoDisposeFutureProvider<UserStats>.internal(
  userStats,
  name: r'userStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserStatsRef = AutoDisposeFutureProviderRef<UserStats>;
String _$notificationServiceHash() =>
    r'5dc829b54981b5ec51553a735ac722c266bdb8f7';

/// See also [NotificationService].
@ProviderFor(NotificationService)
final notificationServiceProvider =
    AutoDisposeAsyncNotifierProvider<
      NotificationService,
      NotificationPreferences
    >.internal(
      NotificationService.new,
      name: r'notificationServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$NotificationService =
    AutoDisposeAsyncNotifier<NotificationPreferences>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
