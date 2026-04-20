import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../logging/app_logger.dart';
import '../runtime/app_runtime_state.dart';
import '../storage/structured_cache_store.dart';

class RuntimeAuthSessionManager {
  RuntimeAuthSessionManager._();

  static final RuntimeAuthSessionManager instance =
      RuntimeAuthSessionManager._();

  static const _sessionCacheKey = 'custom_auth_session_v1';
  static const _refreshLeadTime = Duration(seconds: 45);

  final StreamController<AuthState> _authStates =
      StreamController<AuthState>.broadcast();

  SupabaseClient? _customClient;
  Session? _customSession;
  Timer? _refreshTimer;
  Completer<bool>? _refreshCompleter;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !appRuntime.supabaseInitialized) return;
    _initialized = true;

    _customClient = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
      accessToken: () async => _customSession?.accessToken,
    );

    // ignore: cancel_subscriptions
    guestClient?.auth.onAuthStateChange.listen((
      state,
    ) {
      if (_customSession != null) return;
      _emit(state.event, state.session);
    });

    await _restoreCustomSession();
  }

  SupabaseClient? get guestClient =>
      appRuntime.supabaseInitialized ? Supabase.instance.client : null;

  SupabaseClient? get activeClient =>
      _customSession != null ? _customClient : guestClient;

  Session? get customSession => _customSession;

  Session? get currentSession => _customSession ?? guestClient?.auth.currentSession;

  User? get currentUser => _customSession?.user ?? guestClient?.auth.currentUser;

  bool get hasCustomSession => _customSession != null;

  bool get hasRefreshableCustomSession =>
      _customSession != null && _hasRefreshToken(_customSession!);

  Stream<AuthState> get authStateChanges => _authStates.stream;

  Future<bool> ensureFreshSession() async {
    final session = _customSession;
    if (session == null) return false;

    if (_shouldRefreshSession(session)) {
      return refreshCustomSession();
    }

    _scheduleRefresh(session);
    return true;
  }

  Future<void> applyVerifiedSession(Map<String, dynamic> payload) async {
    final session = Session.fromJson(Map<String, dynamic>.from(payload));
    if (session == null) {
      throw const AuthException(
        'Server did not return a valid authenticated session.',
      );
    }

    final previousUserId = _customSession?.user.id;
    _customSession = session;
    await StructuredCacheStore.writeMap(_sessionCacheKey, session.toJson());

    final event = previousUserId == session.user.id
        ? AuthChangeEvent.tokenRefreshed
        : AuthChangeEvent.signedIn;
    _scheduleRefresh(session);
    _emit(event, session);
  }

  Future<bool> refreshCustomSession() async {
    final inFlight = _refreshCompleter;
    if (inFlight != null) {
      return inFlight.future;
    }

    final refreshToken = _customSession?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final client = guestClient;
    if (client == null) return false;

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final response = await client.functions.invoke(
        'whatsapp-otp',
        body: {'action': 'refresh', 'refresh_token': refreshToken},
      );
      final data = Map<String, dynamic>.from(
        response.data as Map<String, dynamic>? ?? const {},
      );
      if (data['success'] != true) {
        throw AuthException(
          data['error'] as String? ??
              'Session expired. Please sign in again.',
        );
      }

      if (_customSession?.refreshToken != refreshToken) {
        completer.complete(false);
        return completer.future;
      }

      await applyVerifiedSession(data);
      completer.complete(true);
    } catch (error) {
      AppLogger.d('Custom WhatsApp session refresh failed: $error');
      await clearCustomSession(emitEvent: true);
      completer.complete(false);
    } finally {
      _refreshCompleter = null;
    }

    return completer.future;
  }

  Future<void> logoutCustomSession() async {
    final refreshToken = _customSession?.refreshToken;
    final client = guestClient;

    if (client != null && refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await client.functions.invoke(
          'whatsapp-otp',
          body: {'action': 'logout', 'refresh_token': refreshToken},
        );
      } catch (error) {
        AppLogger.d('Custom WhatsApp session logout failed: $error');
      }
    }

    await clearCustomSession(emitEvent: true);
  }

  Future<void> clearCustomSession({required bool emitEvent}) async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _customSession = null;
    await StructuredCacheStore.delete(_sessionCacheKey);
    if (emitEvent) {
      _emit(AuthChangeEvent.signedOut, null);
    }
  }

  Future<void> _restoreCustomSession() async {
    final snapshot = await StructuredCacheStore.readMap(_sessionCacheKey);
    final raw = snapshot?.payload;
    if (raw == null) return;

    final session = Session.fromJson(raw);
    if (session == null) {
      await StructuredCacheStore.delete(_sessionCacheKey);
      return;
    }

    _customSession = session;
    if (session.isExpired) {
      final refreshed = await refreshCustomSession();
      if (!refreshed) {
        return;
      }
      return;
    }

    _scheduleRefresh(session);
    _emit(AuthChangeEvent.initialSession, session);
  }

  bool _hasRefreshToken(Session session) {
    final refreshToken = session.refreshToken;
    return refreshToken != null && refreshToken.isNotEmpty;
  }

  bool _shouldRefreshSession(Session session) {
    if (!_hasRefreshToken(session)) {
      return false;
    }

    final expiresAt = session.expiresAt;
    if (expiresAt == null) {
      return false;
    }

    final refreshAtMs = expiresAt * 1000 - _refreshLeadTime.inMilliseconds;
    return DateTime.now().millisecondsSinceEpoch >= refreshAtMs;
  }

  void _scheduleRefresh(Session session) {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    if (!_hasRefreshToken(session)) {
      return;
    }

    final expiresAt = session.expiresAt;
    if (expiresAt == null) {
      return;
    }

    final refreshInMs =
        expiresAt * 1000 -
        DateTime.now().millisecondsSinceEpoch -
        _refreshLeadTime.inMilliseconds;
    if (refreshInMs <= 0) {
      unawaited(refreshCustomSession());
      return;
    }

    final timeoutMs = refreshInMs.clamp(0, 2147483647);
    _refreshTimer = Timer(Duration(milliseconds: timeoutMs), () {
      unawaited(refreshCustomSession());
    });
  }

  void _emit(AuthChangeEvent event, Session? session) {
    _authStates.add(AuthState(event, session));
    appRuntime.notifyAuthStateChanged();
  }
}
