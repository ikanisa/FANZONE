import 'dart:async';

import '../logging/app_logger.dart';
import '../storage/structured_cache_store.dart';

/// Stale-while-revalidate cache pattern for gateway queries.
///
/// Returns cached data immediately if available (even if expired via TTL),
/// then triggers a background refresh. If no cache exists, falls through
/// to the fresh fetch.
///
/// Usage:
/// ```dart
/// final matches = await staleWhileRevalidate<List<Map<String, dynamic>>>(
///   cacheKey: 'matches_2026-04-19',
///   ttl: const Duration(minutes: 5),
///   fetch: () => supabase.from('matches').select().eq('date', '2026-04-19'),
///   fromCache: (snapshot) => snapshot.payload,
///   toCache: (data) => data,
/// );
/// ```
abstract final class StaleWhileRevalidateCache {
  /// Attempts to read from [StructuredCacheStore] first.
  ///
  /// - **Cache hit + fresh**: returns cached data, no network request.
  /// - **Cache hit + stale**: returns cached data immediately,
  ///   schedules background refresh via [fetch] + [toCache].
  /// - **Cache miss**: calls [fetch] directly, caches result via [toCache].
  static Future<List<Map<String, dynamic>>> list({
    required String cacheKey,
    required Duration ttl,
    required Future<List<Map<String, dynamic>>> Function() fetch,
  }) async {
    // Try reading from cache
    final snapshot = await StructuredCacheStore.readList(
      cacheKey,
      allowExpired: true,
    );

    if (snapshot != null) {
      if (snapshot.isExpired) {
        // Stale: return immediately, refresh in background
        StructuredCacheStore.scheduleRefresh(cacheKey, () async {
          final fresh = await fetch();
          await StructuredCacheStore.writeList(cacheKey, fresh, ttl: ttl);
        }, debugLabel: 'SWR:$cacheKey');
      }
      return snapshot.payload;
    }

    // Cache miss: fetch fresh data
    try {
      final freshData = await fetch();
      unawaited(StructuredCacheStore.writeList(cacheKey, freshData, ttl: ttl));
      return freshData;
    } catch (error) {
      AppLogger.d('SWR cache miss + fetch failed for $cacheKey: $error');
      rethrow;
    }
  }

  /// Same as [list] but for single map payloads.
  static Future<Map<String, dynamic>?> map({
    required String cacheKey,
    required Duration ttl,
    required Future<Map<String, dynamic>?> Function() fetch,
  }) async {
    final snapshot = await StructuredCacheStore.readMap(
      cacheKey,
      allowExpired: true,
    );

    if (snapshot != null) {
      if (snapshot.isExpired) {
        StructuredCacheStore.scheduleRefresh(cacheKey, () async {
          final fresh = await fetch();
          if (fresh != null) {
            await StructuredCacheStore.writeMap(cacheKey, fresh, ttl: ttl);
          }
        }, debugLabel: 'SWR:$cacheKey');
      }
      return snapshot.payload;
    }

    try {
      final freshData = await fetch();
      if (freshData != null) {
        unawaited(StructuredCacheStore.writeMap(cacheKey, freshData, ttl: ttl));
      }
      return freshData;
    } catch (error) {
      AppLogger.d('SWR cache miss + fetch failed for $cacheKey: $error');
      rethrow;
    }
  }

  /// Pre-fetches adjacent cache keys in the background.
  ///
  /// Used for date-ribbon pre-caching: when user views Day X,
  /// pre-fetch Day X-1 and Day X+1 invisibly.
  static void prefetchAdjacent({
    required List<String> cacheKeys,
    required Duration ttl,
    required Future<List<Map<String, dynamic>>> Function(String key) fetch,
  }) {
    for (final key in cacheKeys) {
      StructuredCacheStore.scheduleRefresh(key, () async {
        final existing = await StructuredCacheStore.readList(
          key,
          allowExpired: false,
        );
        if (existing != null) return; // Already fresh
        final data = await fetch(key);
        await StructuredCacheStore.writeList(key, data, ttl: ttl);
      }, debugLabel: 'Prefetch:$key');
    }
  }
}
