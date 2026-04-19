import 'package:flutter_test/flutter_test.dart';
import 'package:fanzone/core/performance/app_startup.dart';

void main() {
  test('critical startup work stays within the app budget', () async {
    final profiler = AppStartupProfiler(stopwatch: Stopwatch()..start());
    final coordinator = AppStartupCoordinator(
      profiler: profiler,
      beforeRunApp: () async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      },
      critical: () async {
        await Future<void>.delayed(const Duration(milliseconds: 850));
      },
      deferred: () async {
        await Future<void>.delayed(const Duration(seconds: 4));
      },
    );

    final stopwatch = Stopwatch()..start();
    await coordinator.prepare();
    coordinator.start();
    await coordinator.waitForCritical();

    expect(stopwatch.elapsed, lessThan(kStartupTarget));
    expect(profiler.at('before_run_app_ready'), isNotNull);
    expect(profiler.at('critical_ready'), isNotNull);
    expect(profiler.at('deferred_ready'), isNull);
  });

  test('startup profiler summary includes captured marks', () async {
    final profiler = AppStartupProfiler(stopwatch: Stopwatch()..start());

    profiler.mark('bindings_ready');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    profiler.mark('critical_ready');

    final summary = profiler.summary();
    expect(summary, contains('bindings_ready='));
    expect(summary, contains('critical_ready='));
  });
}
