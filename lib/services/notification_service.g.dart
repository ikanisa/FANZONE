// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationLogHash() => r'3a4e6570918368b7f2e1ceb5d3b45f48c161e0b3';

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
String _$userStatsHash() => r'cd2a242879a375f1097f26fcc5d161c84c933885';

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
    r'c59a2976500568fd87c544dec0dd33019983aec4';

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
