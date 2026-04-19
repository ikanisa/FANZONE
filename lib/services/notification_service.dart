import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/di/injection.dart';
import '../features/settings/data/preferences_gateway.dart';
import '../models/notification_model.dart';
import '../providers/auth_provider.dart';

part 'notification_service.g.dart';

@riverpod
class NotificationService extends _$NotificationService {
  PreferencesGateway get _gateway => getIt<PreferencesGateway>();

  @override
  FutureOr<NotificationPreferences> build() async {
    ref.watch(authStateProvider);

    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return const NotificationPreferences();

    return _gateway.getNotificationPreferences(userId);
  }

  Future<void> updatePreferences(NotificationPreferences prefs) async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;

    await _gateway.saveNotificationPreferences(userId, prefs);
    state = AsyncValue.data(prefs);
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;

    await _gateway.registerDeviceToken(
      userId: userId,
      token: token,
      platform: platform,
    );
  }

  Future<void> deactivateDeviceToken(String token) async {
    await _gateway.deactivateDeviceToken(
      userId: ref.read(authServiceProvider).currentUser?.id,
      token: token,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    await _gateway.markNotificationAsRead(notificationId);
    ref.invalidate(notificationLogProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> markAllRead() async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;

    await _gateway.markAllNotificationsRead(userId);
    ref.invalidate(notificationLogProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> setMatchAlerts({
    required String matchId,
    required bool enabled,
  }) async {
    await _gateway.setMatchAlertEnabled(
      userId: ref.read(authServiceProvider).currentUser?.id,
      matchId: matchId,
      enabled: enabled,
    );
    ref.invalidate(matchAlertEnabledProvider(matchId));
  }
}

@riverpod
FutureOr<List<NotificationItem>> notificationLog(Ref ref) async {
  ref.watch(authStateProvider);

  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return const [];

  return getIt<PreferencesGateway>().getNotificationLog(userId);
}

@riverpod
FutureOr<int> unreadNotificationCount(Ref ref) async {
  final notifications = await ref.watch(notificationLogProvider.future);
  return notifications.where((item) => item.readAt == null).length;
}

final matchAlertEnabledProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, matchId) async {
      ref.watch(authStateProvider);
      return getIt<PreferencesGateway>().isMatchAlertEnabled(
        userId: ref.read(authServiceProvider).currentUser?.id,
        matchId: matchId,
      );
    });

@riverpod
FutureOr<UserStats> userStats(Ref ref) async {
  ref.watch(authStateProvider);

  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return const UserStats();

  return getIt<PreferencesGateway>().getUserStats(userId);
}
