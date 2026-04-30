import 'dart:async';

import 'package:app_links/app_links.dart';

import '../app_router.dart' show governedAppRouteForPath, router;
import '../core/logging/app_logger.dart';
import '../core/runtime/app_runtime_state.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();
  static const _host = 'fanzone.ikanisa.com';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      _queueOrNavigate(initialUri);
    } catch (error) {
      AppLogger.d('Failed to resolve initial deep link: $error');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      _queueOrNavigate,
      onError: (Object error) {
        AppLogger.d('Deep link stream error: $error');
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }

  void _queueOrNavigate(Uri? uri) {
    final route = _routeFromUri(uri);
    if (route == null) return;

    if (appRuntime.isAppInteractive) {
      router.go(route);
      return;
    }

    appRuntime.queuePendingAppRoute(route);
  }

  String? _routeFromUri(Uri? uri) {
    if (uri == null) return null;

    switch (uri.scheme.toLowerCase()) {
      case 'https':
      case 'http':
        if (uri.host.toLowerCase() != _host) {
          return null;
        }
        return _governedRoute(uri);
      case 'fanzone':
        final host = uri.host.trim();
        final pathSuffix = uri.path == '/' ? '' : uri.path;
        final path = host.isEmpty
            ? (uri.path.startsWith('/') ? uri.path : '/${uri.path}')
            : '/$host$pathSuffix';
        return _governedRoute(uri.replace(path: path));
      default:
        return null;
    }
  }

  String? _governedRoute(Uri uri) {
    final path = uri.path.trim();
    if (path.isEmpty || path == '/') {
      return null;
    }
    return governedAppRouteForPath(uri.toString());
  }
}
