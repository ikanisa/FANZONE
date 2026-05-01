import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';
import '../storage/structured_cache_store.dart';

/// App lifecycle observer that triggers cache refresh when the app
/// returns to the foreground.
///
/// Integrates with [StructuredCacheStore] to invalidate stale entries
/// after the app has been backgrounded. This ensures users see fresh
/// match data when switching back to FANZONE.
///
/// Usage: Add as a widget observer via [AppLifecycleObserverWidget]
/// in the widget tree (typically in `app.dart`).
class AppLifecycleObserver extends WidgetsBindingObserver {
  AppLifecycleObserver({required this.ref, this.onForeground});

  final WidgetRef ref;
  final VoidCallback? onForeground;

  DateTime _lastPaused = DateTime.now();

  /// Minimum background duration before triggering a refresh.
  /// Avoids unnecessary refreshes for quick app switches.
  static const _minBackgroundDuration = Duration(seconds: 30);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _lastPaused = DateTime.now();
        break;

      case AppLifecycleState.resumed:
        final elapsed = DateTime.now().difference(_lastPaused);
        if (elapsed >= _minBackgroundDuration) {
          _onReturnToForeground(elapsed);
        }
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onReturnToForeground(Duration elapsed) {
    AppLogger.d(
      'App resumed after ${elapsed.inSeconds}s — refreshing cached data',
    );
    onForeground?.call();
  }
}

/// Widget that attaches the [AppLifecycleObserver] to the widget tree.
///
/// Place this widget near the root of the app (e.g., inside the
/// [MaterialApp.builder]) to ensure lifecycle events trigger cache
/// refreshes automatically.
class AppLifecycleObserverWidget extends ConsumerStatefulWidget {
  const AppLifecycleObserverWidget({
    super.key,
    required this.child,
    this.onForeground,
  });

  final Widget child;
  final VoidCallback? onForeground;

  @override
  ConsumerState<AppLifecycleObserverWidget> createState() =>
      _AppLifecycleObserverWidgetState();
}

class _AppLifecycleObserverWidgetState
    extends ConsumerState<AppLifecycleObserverWidget> {
  AppLifecycleObserver? _observer;

  @override
  void initState() {
    super.initState();
    _observer = AppLifecycleObserver(
      ref: ref,
      onForeground: widget.onForeground ?? _defaultForegroundRefresh,
    );
    WidgetsBinding.instance.addObserver(_observer!);
  }

  @override
  void dispose() {
    if (_observer != null) {
      WidgetsBinding.instance.removeObserver(_observer!);
    }
    super.dispose();
  }

  /// Default foreground behavior: invalidate all match/pool related
  /// Riverpod providers to trigger fresh fetches.
  void _defaultForegroundRefresh() {
    // Invalidate match-related providers so Riverpod refetches
    // This works via the auto-dispose mechanism — any active
    // widget watching these providers will get fresh data.
    ref.invalidate(matchRefreshTriggerProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Simple notifier that acts as a refresh trigger.
///
/// Screens that depend on match data should watch this via:
/// ```dart
/// ref.watch(matchRefreshTriggerProvider);
/// ```
/// When the app returns to the foreground, this provider is
/// invalidated, causing all watchers to rebuild.
final matchRefreshTriggerProvider = StateProvider.autoDispose<int>((ref) => 0);
