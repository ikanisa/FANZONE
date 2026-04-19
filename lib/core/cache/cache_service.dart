abstract class CacheService {
  Future<String?> getString(String key);

  Future<bool?> getBool(String key);

  Future<List<String>> getStringList(String key);

  Future<Map<String, dynamic>?> getJsonMap(String key, {String? debugLabel});

  Future<List<Map<String, dynamic>>> getJsonList(
    String key, {
    String? debugLabel,
  });

  Future<void> setString(String key, String value);

  Future<void> setBool(String key, bool value);

  Future<void> setStringList(String key, List<String> value);

  Future<void> setJson(String key, Object value);

  Future<void> remove(String key);
}
