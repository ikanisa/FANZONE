import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/di/gateway_providers.dart';
import '../core/supabase/supabase_connection.dart';
import '../features/settings/data/preferences_gateway.dart';
import '../models/notification_model.dart';
import '../providers/auth_provider.dart' show authStateProvider;

part 'notification_service.g.dart';

@riverpod
class NotificationService extends _$NotificationService {
  NotificationSettingsGateway get _gateway =>
      ref.read(notificationSettingsGatewayProvider);
  SupabaseConnection get _connection => SupabaseConnectionImpl();
  String? get _currentUserId => _connection.currentUser?.id;

  @override
  FutureOr<NotificationPreferences> build() async {
    ref.watch(authStateProvider);

    final userId = _currentUserId;
    if (userId == null) return const NotificationPreferences();

    return _gateway.getNotificationPreferences(userId);
  }

  Future<void> updatePreferences(NotificationPreferences prefs) async {
    final userId = _currentUserId;
    if (userId == null) return;

    final previous = state;

    try {
      await _gateway.saveNotificationPreferences(userId, prefs);
      state = AsyncValue.data(prefs);
    } catch (error, stack) {
      state = previous;
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;

    await _gateway.registerDeviceToken(
      userId: userId,
      token: token,
      platform: platform,
    );
  }

  Future<void> deactivateDeviceToken(String token) async {
    await _gateway.deactivateDeviceToken(userId: _currentUserId, token: token);
  }

  Future<void> markAsRead(String notificationId) async {
    await _gateway.markNotificationAsRead(notificationId);
    ref.invalidate(notificationLogProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> markAllRead() async {
    final userId = _currentUserId;
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
      userId: _currentUserId,
      matchId: matchId,
      enabled: enabled,
    );
    ref.invalidate(matchAlertEnabledProvider(matchId));
  }
}

@riverpod
FutureOr<List<NotificationItem>> notificationLog(Ref ref) async {
  ref.watch(authStateProvider);

  final userId = SupabaseConnectionImpl().currentUser?.id;
  if (userId == null) return const [];

  return ref
      .read(notificationSettingsGatewayProvider)
      .getNotificationLog(userId);
}

@riverpod
FutureOr<int> unreadNotificationCount(Ref ref) async {
  final notifications = await ref.watch(notificationLogProvider.future);
  return notifications.where((item) => item.readAt == null).length;
}

final matchAlertEnabledProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, matchId) async {
      ref.watch(authStateProvider);
      return ref
          .read(notificationSettingsGatewayProvider)
          .isMatchAlertEnabled(
            userId: SupabaseConnectionImpl().currentUser?.id,
            matchId: matchId,
          );
    });

@riverpod
FutureOr<UserStats> userStats(Ref ref) async {
  ref.watch(authStateProvider);

  final userId = SupabaseConnectionImpl().currentUser?.id;
  if (userId == null) return const UserStats();

  return ref.read(notificationSettingsGatewayProvider).getUserStats(userId);
}
