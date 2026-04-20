import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/core/cache/stale_while_revalidate.dart';
import 'package:fanzone/core/storage/structured_cache_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fanzone-swr-test-');
    await StructuredCacheStore.init(directory: tempDir.path);
  });

  tearDown(() async {
    await StructuredCacheStore.resetForTest();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('StaleWhileRevalidateCache.list', () {
    test('cache miss — fetches from network and caches result', () async {
      var fetchCount = 0;
      final result = await StaleWhileRevalidateCache.list(
        cacheKey: 'matches:2026-04-19:2026-04-19',
        ttl: const Duration(minutes: 5),
        fetch: () async {
          fetchCount++;
          return [
            {'id': 'm1', 'homeTeam': 'Liverpool', 'awayTeam': 'Arsenal'},
            {'id': 'm2', 'homeTeam': 'Chelsea', 'awayTeam': 'Spurs'},
          ];
        },
      );

      expect(result, hasLength(2));
      expect(result[0]['homeTeam'], 'Liverpool');
      expect(fetchCount, 1);

      // Verify it was cached
      final snapshot = await StructuredCacheStore.readList(
        'matches:2026-04-19:2026-04-19',
        allowExpired: false,
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.payload, hasLength(2));
    });

    test(
      'cache hit (fresh) — returns cached data without network call',
      () async {
        // Pre-populate cache
        await StructuredCacheStore.writeList('matches:2026-04-20:2026-04-20', [
          {'id': 'm3', 'homeTeam': 'Man City', 'awayTeam': 'Newcastle'},
        ], ttl: const Duration(minutes: 10));

        var fetchCount = 0;
        final result = await StaleWhileRevalidateCache.list(
          cacheKey: 'matches:2026-04-20:2026-04-20',
          ttl: const Duration(minutes: 10),
          fetch: () async {
            fetchCount++;
            return [
              {'id': 'fresh', 'homeTeam': 'SHOULD_NOT_APPEAR'},
            ];
          },
        );

        expect(result, hasLength(1));
        expect(result[0]['homeTeam'], 'Man City');
        expect(fetchCount, 0, reason: 'Should not fetch when cache is fresh');
      },
    );

    test(
      'cache hit (stale) — returns stale data and schedules background refresh',
      () async {
        // Write already-expired data
        await StructuredCacheStore.writeList(
          'matches:stale:stale',
          [
            {'id': 'm_stale', 'homeTeam': 'OldData'},
          ],
          ttl: const Duration(milliseconds: -1), // Already expired
        );

        var fetchCalled = false;
        final completer = Completer<List<Map<String, dynamic>>>();

        final result = await StaleWhileRevalidateCache.list(
          cacheKey: 'matches:stale:stale',
          ttl: const Duration(minutes: 5),
          fetch: () {
            fetchCalled = true;
            return completer.future;
          },
        );

        // Should return stale data immediately
        expect(result, hasLength(1));
        expect(result[0]['homeTeam'], 'OldData');
        expect(fetchCalled, isTrue, reason: 'Background refresh should start');

        // Complete the background fetch
        completer.complete([
          {'id': 'm_fresh', 'homeTeam': 'FreshData'},
        ]);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // The cache should now have fresh data
        final freshSnapshot = await StructuredCacheStore.readList(
          'matches:stale:stale',
          allowExpired: false,
        );
        expect(freshSnapshot, isNotNull);
        expect(freshSnapshot!.payload[0]['homeTeam'], 'FreshData');
      },
    );

    test('cache miss + fetch error — rethrows', () async {
      expect(
        () => StaleWhileRevalidateCache.list(
          cacheKey: 'matches:error:error',
          ttl: const Duration(minutes: 5),
          fetch: () async => throw Exception('Network down'),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('StaleWhileRevalidateCache.map', () {
    test('cache miss — fetches and caches single map', () async {
      final result = await StaleWhileRevalidateCache.map(
        cacheKey: 'match-detail:m1',
        ttl: const Duration(minutes: 5),
        fetch: () async => {'id': 'm1', 'status': 'live', 'minute': 65},
      );

      expect(result, isNotNull);
      expect(result!['status'], 'live');

      final cached = await StructuredCacheStore.readMap('match-detail:m1');
      expect(cached, isNotNull);
      expect(cached!.payload['minute'], 65);
    });

    test('cache hit (fresh) — returns cached map without fetch', () async {
      await StructuredCacheStore.writeMap('match-detail:m2', {
        'id': 'm2',
        'status': 'HT',
      }, ttl: const Duration(hours: 1));

      var fetched = false;
      final result = await StaleWhileRevalidateCache.map(
        cacheKey: 'match-detail:m2',
        ttl: const Duration(hours: 1),
        fetch: () async {
          fetched = true;
          return {'id': 'm2', 'status': 'SHOULD_NOT_APPEAR'};
        },
      );

      expect(result!['status'], 'HT');
      expect(fetched, isFalse);
    });

    test('null fetch result — does not cache null', () async {
      final result = await StaleWhileRevalidateCache.map(
        cacheKey: 'match-detail:null',
        ttl: const Duration(minutes: 5),
        fetch: () async => null,
      );

      expect(result, isNull);

      final cached = await StructuredCacheStore.readMap('match-detail:null');
      expect(cached, isNull, reason: 'Should not cache null results');
    });
  });

  group('StaleWhileRevalidateCache.prefetchAdjacent', () {
    test('prefetches keys that are not already cached', () async {
      // Pre-populate one key
      await StructuredCacheStore.writeList('matches:yesterday:yesterday', [
        {'id': 'existing'},
      ], ttl: const Duration(hours: 1));

      final fetchedKeys = <String>[];
      StaleWhileRevalidateCache.prefetchAdjacent(
        cacheKeys: ['matches:yesterday:yesterday', 'matches:tomorrow:tomorrow'],
        ttl: const Duration(minutes: 5),
        fetch: (key) async {
          fetchedKeys.add(key);
          return [
            {'id': 'prefetched', 'key': key},
          ];
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should only fetch tomorrow (yesterday is already cached and fresh)
      expect(fetchedKeys, ['matches:tomorrow:tomorrow']);

      // Tomorrow should now be cached
      final tomorrowCache = await StructuredCacheStore.readList(
        'matches:tomorrow:tomorrow',
      );
      expect(tomorrowCache, isNotNull);
      expect(tomorrowCache!.payload[0]['id'], 'prefetched');
    });
  });
}
