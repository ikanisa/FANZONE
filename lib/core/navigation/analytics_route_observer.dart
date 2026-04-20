import 'package:flutter/widgets.dart';

import '../../services/product_analytics_service.dart';

/// GoRouter-compatible navigation observer that logs screen_view events.
///
/// Add to the router via `GoRouter(observers: [AnalyticsRouteObserver()])`.
/// Automatically tracks every route push/replace without needing manual
/// `trackScreen()` calls in each screen's build method.
class AnalyticsRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _trackRoute(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _trackRoute(previousRoute);
  }

  void _trackRoute(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;

    // Normalize route name for analytics: /match/123 → match_detail
    final screenName = _normalizeRouteName(name);
    if (screenName.isNotEmpty) {
      ProductAnalytics.trackScreen(screenName);
    }
  }

  /// Convert route paths to readable analytics screen names.
  static String _normalizeRouteName(String routeName) {
    // Skip internal/system routes
    if (routeName == '/') return 'home';

    // Remove leading slash and query params
    var name = routeName.startsWith('/') ? routeName.substring(1) : routeName;
    final queryIndex = name.indexOf('?');
    if (queryIndex >= 0) name = name.substring(0, queryIndex);

    // Replace dynamic segments (UUIDs, numeric IDs) with type hints
    final segments = name.split('/');
    final normalized = segments.map((segment) {
      if (_isUuid(segment) || _isNumericId(segment)) return 'detail';
      return segment;
    }).toList();

    return normalized.join('_').replaceAll('-', '_');
  }

  static bool _isUuid(String s) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(s);

  static bool _isNumericId(String s) => s.isNotEmpty && int.tryParse(s) != null;
}
