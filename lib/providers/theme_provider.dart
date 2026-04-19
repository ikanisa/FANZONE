import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cache/cache_service.dart';
import '../core/di/injection.dart';

/// Manages the app's ThemeMode through the unified cache service.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'themeMode';

  CacheService get _cache => getIt<CacheService>();

  @override
  ThemeMode build() {
    _loadFromCache();
    return ThemeMode.dark;
  }

  Future<void> _loadFromCache() async {
    final stored = await _cache.getString(_key);
    if (stored == null) return;

    final mode = _fromString(stored);
    if (mode != state) {
      state = mode;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _cache.setString(_key, _toString(mode));
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }

  static ThemeMode _fromString(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.dark;
    }
  }

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
