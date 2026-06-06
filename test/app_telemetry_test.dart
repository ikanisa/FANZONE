import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/core/logging/app_logger.dart';
import 'package:fanzone/core/storage/structured_cache_store.dart';
import 'package:fanzone/services/app_telemetry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DebugPrintCallback originalDebugPrint;
  late List<String> debugMessages;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fanzone-telemetry-test-');
    await StructuredCacheStore.init(directory: tempDir.path);
    debugMessages = <String>[];
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      debugMessages.add(message ?? '');
    };
  });

  tearDown(() async {
    debugPrint = originalDebugPrint;
    await StructuredCacheStore.resetForTest();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('logger redacts backend payloads and secret-looking values', () {
    const jwt =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIn0.'
        'abcdefghijklmno1234567890';
    final sanitized = AppLogger.sanitizeForLog(
      'PostgrestException(message: failed row uses service_role secret=abc123) '
      '${'sbp_'}abcdefghijklmnopqrstuvwxyz123456 '
      '${'postgresql:'}//postgres:password@db.example.supabase.co:5432/postgres '
      'Authorization: Bearer $jwt',
    );

    expect(sanitized, contains('[backend-error]'));
    expect(sanitized, contains('Authorization: Bearer [redacted]'));
    expect(sanitized, isNot(contains('PostgrestException')));
    expect(sanitized, isNot(contains('service_role')));
    expect(sanitized, isNot(contains('sbp_')));
    expect(sanitized, isNot(contains('postgresql://')));
    expect(sanitized, isNot(contains(jwt)));
  });

  test('telemetry stores and prints redacted exception payloads', () async {
    const queueCacheKey = 'app_runtime_telemetry_queue_v2';

    await AppTelemetry.captureException(
      StateError(
        'PostgrestException(message: failed row includes service_role debug text)',
      ),
      StackTrace.current,
      reason: 'order_place_failed',
    );

    final snapshot = await StructuredCacheStore.readList(queueCacheKey);
    final event = snapshot!.payload.single;
    final logOutput = debugMessages.join('\n');

    expect(event['message'], contains('[backend-error]'));
    expect(logOutput, contains('[backend-error]'));
    expect(event['message'], isNot(contains('PostgrestException')));
    expect(event['message'], isNot(contains('service_role')));
    expect(logOutput, isNot(contains('PostgrestException')));
    expect(logOutput, isNot(contains('service_role')));
  });
}
