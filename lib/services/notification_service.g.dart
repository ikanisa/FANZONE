// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationLogHash() => r'5a4092ae762a1c269bbb7e13f77832156b88efff';

/// Provider for notification log (recent notifications).
///
/// Copied from [notificationLog].
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
    r'da142c6408456d4f23e3815166d35b7bbb0de516';

/// Provider for unread notification count.
///
/// Copied from [unreadNotificationCount].
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
String _$userStatsHash() => r'984a3c01d13a6bc73d8d50f5ea7c79b0cd442f23';

/// Provider for user stats (prediction streaks, etc.).
///
/// Copied from [userStats].
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
    r'f1d9077941de1703f4fa77906f55957abf1b4d85';

/// Service for managing device tokens, notification preferences, and notification log.
///
/// Copied from [NotificationService].
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
