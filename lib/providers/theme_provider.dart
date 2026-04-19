import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cache/cache_service.dart';
import '../core/di/gateway_providers.dart';

/// Keeps the runtime pinned to the source-of-truth dark theme.
///
/// The reference design does not define a separate light visual system, so the
/// app clamps all theme requests back to dark until a light-mode reference
/// exists.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'themeMode';

  CacheService get _cache => ref.read(cacheServiceProvider);

  @override
  ThemeMode build() => ThemeMode.dark;

  Future<void> setMode(ThemeMode mode) async {
    state = ThemeMode.dark;
    await _cache.setString(_key, _toString(ThemeMode.dark));
  }

  Future<void> toggle() => setMode(ThemeMode.dark);

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
