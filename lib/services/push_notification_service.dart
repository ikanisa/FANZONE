import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_router.dart' show governedAppRouteForPath, router;
import '../core/config/platform_feature_access.dart';
import '../core/di/gateway_providers.dart';
import '../core/logging/app_logger.dart';
import '../core/runtime/app_runtime_state.dart';
import '../features/auth/data/auth_gateway.dart';
import '../features/settings/data/preferences_gateway.dart';
import '../providers/auth_provider.dart';
import '../widgets/common/fz_notification_toast.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.d('Background message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService(this._authGateway, this._preferencesGateway);

  final AuthGateway _authGateway;
  final NotificationSettingsGateway _preferencesGateway;
  bool _initialized = false;
  String? _currentToken;

  bool get _isFullyAuthenticated =>
      _authGateway.isAuthenticated &&
      !(_authGateway.currentUser?.isAnonymous ?? false);

  Future<void> initialize() async {
    if (!appRuntime.supabaseInitialized) return;
    if (!_isFullyAuthenticated) return;

    final messaging = FirebaseMessaging.instance;
    if (_initialized) {
      final token = _currentToken ?? await messaging.getToken();
      if (token != null) {
        _currentToken = token;
        await registerToken(token);
      }
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        AppLogger.d('Push notifications denied by user');
        return;
      }

      final token = await messaging.getToken();
      if (token != null) {
        _currentToken = token;
        await registerToken(token);
      }

      messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        unawaited(registerToken(newToken));
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }

      _initialized = true;
      AppLogger.d('Push notification service initialized');
    } catch (error) {
      AppLogger.d('Push notification init failed: $error');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.d(
      '[FANZONE] Foreground message: ${message.notification?.title ?? message.messageId}',
    );

    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return;

    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null) return;

    FzNotificationToast.show(
      context,
      title: title ?? 'FANZONE',
      message: body ?? '',
      type: _mapToastType(message.data['type']?.toString()),
      onTap: () => _navigateFromData(message.data),
    );
  }

  FzToastType _mapToastType(String? type) {
    switch (type) {
      case 'pool_update':
      case 'pool_created':
      case 'pool_reminder':
        return FzToastType.poolUpdate;
      case 'pool_settled':
      case 'pool_reward':
        return FzToastType.poolReward;
      default:
        return FzToastType.system;
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    AppLogger.d('Message tap: ${message.data}');
    _navigateFromData(message.data);
  }

  void _navigateFromData(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final matchId = data['match_id']?.toString();
    if (matchId != null && matchId.isNotEmpty) {
      router.go(governedAppRouteForPath('/match/$matchId'));
      return;
    }

    final screen = data['screen']?.toString();
    final normalizedScreen = _normalizeRoute(screen);
    if (normalizedScreen != null) {
      router.go(governedAppRouteForPath(normalizedScreen));
      return;
    }

    final type = data['type']?.toString();
    switch (type) {
      case 'pool_update':
      case 'pool_created':
      case 'pool_reminder':
      case 'pool_settled':
      case 'pool_reward':
        router.go(governedAppRouteForPath('/pools', fallback: '/pools'));
        return;
      case 'wallet_credit':
      case 'wallet_debit':
        router.go(governedAppRouteForPath('/wallet', fallback: '/wallet'));
        return;
      default:
        router.go(
          governedAppRouteForPath('/notifications', fallback: '/profile'),
        );
        return;
    }
  }

  String? _normalizeRoute(String? route) {
    if (route == null || route.trim().isEmpty) return null;

    final normalized = route.trim();
    return normalized.startsWith('/') ? normalized : null;
  }

  Future<void> registerToken(String token) async {
    if (!_isFullyAuthenticated) return;
    final userId = _authGateway.currentUser?.id;
    if (userId == null) return;

    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    try {
      await _preferencesGateway.registerDeviceToken(
        userId: userId,
        token: token,
        platform: platform,
      );
      AppLogger.d('Device token registered ($platform)');
    } catch (error) {
      AppLogger.d('Failed to register device token: $error');
    }
  }

  Future<void> unregisterCurrentToken() async {
    final token = _currentToken;
    if (token == null) return;

    try {
      await _preferencesGateway.deactivateDeviceToken(
        userId: _authGateway.currentUser?.id,
        token: token,
      );
      AppLogger.d('Device token deactivated');
    } catch (error) {
      AppLogger.d('Failed to deactivate token: $error');
    }
  }

  Future<void> ensureDefaultPreferences() async {
    if (!_isFullyAuthenticated) return;
    final userId = _authGateway.currentUser?.id;
    if (userId == null) return;

    try {
      await _preferencesGateway.ensureDefaultNotificationPreferences(userId);
    } catch (error) {
      AppLogger.d('Failed to ensure notification prefs: $error');
    }
  }

  Future<int> getUnreadCount() async {
    if (!_isFullyAuthenticated) return 0;
    final userId = _authGateway.currentUser?.id;
    if (userId == null) return 0;

    try {
      return _preferencesGateway.getUnreadNotificationCount(userId);
    } catch (error) {
      AppLogger.d('Failed to get unread count: $error');
      return 0;
    }
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService(
    ref.read(authGatewayProvider),
    ref.read(notificationSettingsGatewayProvider),
  );
});

final pushNotificationInitProvider = FutureProvider<void>((ref) async {
  if (!ref
          .watch(platformFeatureAccessProvider)
          .isVisible('notifications', surface: PlatformSurface.route) ||
      !appRuntime.supabaseInitialized) {
    return;
  }

  await appRuntime.firebaseReady;
  if (!appRuntime.firebaseInitialized) return;

  final isFullyAuthenticated = ref.watch(isFullyAuthenticatedProvider);
  final service = ref.read(pushNotificationServiceProvider);

  if (!isFullyAuthenticated) {
    await service.unregisterCurrentToken();
    return;
  }

  await service.initialize();
  await service.ensureDefaultPreferences();
});
