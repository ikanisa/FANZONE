import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/core/storage/structured_cache_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fanzone-cache-test-');
    await StructuredCacheStore.init(directory: tempDir.path);
  });

  tearDown(() async {
    await StructuredCacheStore.resetForTest();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('writes and reads structured list payloads', () async {
    await StructuredCacheStore.writeList('teams', [
      {'id': 'ars', 'name': 'Arsenal'},
      {'id': 'hsp', 'name': 'Hamrun Spartans'},
    ], ttl: const Duration(minutes: 10));

    final snapshot = await StructuredCacheStore.readList('teams');

    expect(snapshot, isNotNull);
    expect(snapshot!.isExpired, isFalse);
    expect(snapshot.payload, hasLength(2));
    expect(snapshot.payload.first['name'], 'Arsenal');
  });

  test('expired payloads are hidden when allowExpired is false', () async {
    await StructuredCacheStore.writeMap('market-preferences', {
      'primary_region': 'europe',
    }, ttl: const Duration(milliseconds: -1));

    final freshOnly = await StructuredCacheStore.readMap(
      'market-preferences',
      allowExpired: false,
    );
    final staleAllowed = await StructuredCacheStore.readMap(
      'market-preferences',
    );

    expect(freshOnly, isNull);
    expect(staleAllowed, isNotNull);
    expect(staleAllowed!.isExpired, isTrue);
  });

  test('background refresh scheduling deduplicates active refreshes', () async {
    var runs = 0;
    final completer = Completer<void>();

    StructuredCacheStore.scheduleRefresh('matches', () async {
      runs += 1;
      await completer.future;
    });
    StructuredCacheStore.scheduleRefresh('matches', () async {
      runs += 1;
    });

    await Future<void>.delayed(Duration.zero);
    expect(runs, 1);

    completer.complete();
    await Future<void>.delayed(Duration.zero);

    StructuredCacheStore.scheduleRefresh('matches', () async {
      runs += 1;
    });
    await Future<void>.delayed(Duration.zero);

    expect(runs, 2);
  });
}
