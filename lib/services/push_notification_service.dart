import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_router.dart' show router;
import '../config/app_config.dart';
import '../core/logging/app_logger.dart';
import '../main.dart' show supabaseInitialized;
import '../providers/auth_provider.dart';
import '../theme/colors.dart';

/// Top-level handler for background/terminated FCM messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.d('Background message: ${message.messageId}');
}

/// Push notification service — manages FCM/APNs token registration,
/// foreground message handling, and notification preferences sync.
///
/// **Firebase Setup:**
/// ✅ google-services.json placed in android/app/
/// ✅ GoogleService-Info.plist placed in ios/Runner/
/// ✅ firebase_options.dart generated via `flutterfire configure`
///
/// The service registers device tokens with the Supabase `device_tokens` table
/// and syncs notification preferences for per-user targeting.
class PushNotificationService {
  PushNotificationService(this._client);

  final SupabaseClient? _client;
  bool _initialized = false;
  String? _currentToken;

  /// Initialize push notifications.
  /// Call this after Firebase + Supabase are initialized and user is authenticated.
  Future<void> initialize() async {
    if (_initialized || !supabaseInitialized || _client == null) return;
    if (_client.auth.currentUser == null) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request permissions (iOS and Android 13+).
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

      // Get FCM token
      final token = await messaging.getToken();
      if (token != null) {
        _currentToken = token;
        await registerToken(token);
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        registerToken(newToken);
      });

      // Foreground messages — show local notification or handle silently
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Background/terminated message taps — navigate to relevant screen
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      // Check for initial message (app opened from terminated via notification)
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }

      _initialized = true;
      AppLogger.d('Push notification service initialized');
    } catch (e) {
      AppLogger.d('Push notification init failed: $e');
    }
  }

  /// Handle foreground FCM message — show an in-app banner via the root
  /// navigator's overlay so the user knows something arrived without
  /// leaving their current screen.
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.d(
      '[FANZONE] Foreground message: ${message.notification?.title ?? message.messageId}',
    );

    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return;

    // Use the root navigator's context for the SnackBar.
    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            if (body != null)
              Text(
                body,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        backgroundColor: FzColors.teal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () => _navigateFromData(message.data),
        ),
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Handle notification tap (app was in background or terminated).
  /// Parses `message.data` and navigates to the relevant screen.
  void _handleMessageTap(RemoteMessage message) {
    AppLogger.d('Message tap: ${message.data}');
    _navigateFromData(message.data);
  }

  /// Routes to the correct screen based on the push notification payload.
  ///
  /// The `auto-settle` edge function sends:
  ///   `{ screen: "/predict", match_id: "...", type: "pool_settled" }`
  ///
  /// Supported data keys:
  ///   - `pool_id` — shorthand to navigate to `/predict/pool/<pool_id>`
  ///   - `match_id` — shorthand to navigate to `/match/<match_id>`
  ///   - `screen` — a GoRouter path to navigate to directly
  ///   - Falls back to home `/` if no recognised keys are present.
  void _navigateFromData(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    // Pool deep link
    final poolId = data['pool_id']?.toString();
    if (poolId != null && poolId.isNotEmpty) {
      router.go('/predict/pool/$poolId');
      return;
    }

    // Match deep link
    final matchId = data['match_id']?.toString();
    if (matchId != null && matchId.isNotEmpty) {
      router.go('/match/$matchId');
      return;
    }

    // Direct screen path (most flexible)
    final screen = data['screen']?.toString();
    final normalizedScreen = _normalizeRoute(screen);
    if (normalizedScreen != null) {
      router.go(normalizedScreen);
      return;
    }

    // Notification types with known destinations
    final type = data['type']?.toString();
    switch (type) {
      case 'pool_settled':
      case 'pool_joined':
        router.go('/predict');
        return;
      case 'wallet_credit':
      case 'wallet_debit':
        router.go('/wallet');
        return;
      case 'daily_challenge':
        router.go('/profile/daily-challenge');
        return;
      default:
        // Fallback — open notifications list
        router.go('/profile/notifications');
        return;
    }
  }

  String? _normalizeRoute(String? route) {
    if (route == null || route.trim().isEmpty) return null;

    final normalized = route.trim();
    if (!normalized.startsWith('/')) return null;
    if (normalized.startsWith('/home/match/')) {
      return normalized.replaceFirst('/home/match/', '/match/');
    }
    if (normalized == '/home' || normalized == '/home/') {
      return '/';
    }
    return normalized;
  }

  /// Register device token with Supabase.
  Future<void> registerToken(String token) async {
    if (!supabaseInitialized || _client == null) return;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final platform = Platform.isIOS ? 'ios' : 'android';

    try {
      await _client.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': platform,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
      AppLogger.d('Device token registered ($platform)');
    } catch (e) {
      AppLogger.d('Failed to register device token: $e');
    }
  }

  /// Remove device token on logout.
  Future<void> unregisterCurrentToken() async {
    if (!supabaseInitialized || _client == null || _currentToken == null) {
      return;
    }

    final userId = _client.auth.currentUser?.id;

    try {
      final query = _client
          .from('device_tokens')
          .update({'is_active': false})
          .eq('token', _currentToken!);

      // Scope to current user to avoid deactivating another user's token
      if (userId != null) {
        await query.eq('user_id', userId);
      } else {
        await query;
      }
      AppLogger.d('Device token deactivated');
    } catch (e) {
      AppLogger.d('Failed to deactivate token: $e');
    }
  }

  /// Ensure default notification preferences exist for new users.
  Future<void> ensureDefaultPreferences() async {
    if (!supabaseInitialized || _client == null) return;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('notification_preferences')
          .upsert(
            {
              'user_id': userId,
              'goal_alerts': true,
              'pool_updates': true,
              'daily_challenge': true,
              'wallet_activity': true,
              'community_news': true,
              'marketing': false,
            },
            onConflict: 'user_id',
            ignoreDuplicates: true,
          );
    } catch (e) {
      AppLogger.d('Failed to ensure notification prefs: $e');
    }
  }

  /// Get the current notification badge count (unread notifications).
  Future<int> getUnreadCount() async {
    if (!supabaseInitialized || _client == null) return 0;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final data = await _client
          .from('notification_log')
          .select('id')
          .eq('user_id', userId)
          .isFilter('read_at', null);

      return (data as List).length;
    } catch (e) {
      AppLogger.d('Failed to get unread count: $e');
      return 0;
    }
  }
}

// ── Riverpod Providers ──

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final client = supabaseInitialized ? Supabase.instance.client : null;
  return PushNotificationService(client);
});

/// Initialize push notifications when user is authenticated.
final pushNotificationInitProvider = FutureProvider<void>((ref) async {
  if (!AppConfig.enableNotifications || !supabaseInitialized) return;

  final currentUser = ref.watch(currentUserProvider);
  final service = ref.read(pushNotificationServiceProvider);

  if (currentUser == null) {
    await service.unregisterCurrentToken();
    return;
  }

  await service.initialize();
  await service.ensureDefaultPreferences();
});

// NOTE: Unread notification count is provided by
// `unreadNotificationCountProvider` in notification_service.dart.
// Removed duplicate provider that was here previously (QA: H-11).
