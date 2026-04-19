import '../cache/cache_service.dart';
import '../di/injection.dart';

abstract final class PreferencesJsonStore {
  static CacheService get _cache => getIt<CacheService>();

  static Future<Map<String, dynamic>?> readMap(
    String key, {
    String? debugLabel,
  }) {
    return _cache.getJsonMap(key, debugLabel: debugLabel);
  }

  static Future<List<Map<String, dynamic>>> readList(
    String key, {
    String? debugLabel,
  }) {
    return _cache.getJsonList(key, debugLabel: debugLabel);
  }

  static Future<void> write(String key, Object value) {
    return _cache.setJson(key, value);
  }
}
