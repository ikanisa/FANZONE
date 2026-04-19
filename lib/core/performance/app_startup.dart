import 'dart:ui' show FrameTiming;
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'frame_budget.dart';

typedef StartupTask = Future<void> Function();

const kStartupTarget = Duration(seconds: 3);

class AppStartupProfiler {
  AppStartupProfiler({Stopwatch? stopwatch})
    : _stopwatch = stopwatch ?? (Stopwatch()..start());

  final Stopwatch _stopwatch;
  final Map<String, Duration> _marks = <String, Duration>{};

  bool _frameHooksAttached = false;
  FrameBudgetSample? _firstFrameBudget;

  Duration get elapsed => _stopwatch.elapsed;
  FrameBudgetSample? get firstFrameBudget => _firstFrameBudget;

  void mark(String label) {
    _marks.putIfAbsent(label, () => _stopwatch.elapsed);
  }

  Duration? at(String label) => _marks[label];

  Map<String, Duration> get marks => Map<String, Duration>.unmodifiable(_marks);

  void attachFrameHooks(WidgetsBinding binding) {
    if (_frameHooksAttached) return;
    _frameHooksAttached = true;

    binding.addPostFrameCallback((_) => mark('first_frame_built'));

    void timingsCallback(List<FrameTiming> timings) {
      if (timings.isEmpty) return;
      _firstFrameBudget ??= FrameBudgetSample.fromTiming(timings.first);
      mark('first_frame_rasterized');
      binding.removeTimingsCallback(timingsCallback);
    }

    binding.addTimingsCallback(timingsCallback);
  }

  String summary() {
    final entries = _marks.entries.toList()
      ..sort((left, right) => left.value.compareTo(right.value));

    final timeline = entries
        .map((entry) => '${entry.key}=${entry.value.inMilliseconds}ms')
        .join(', ');
    final budgetSummary = _firstFrameBudget?.summary();
    if (timeline.isEmpty) return budgetSummary ?? '';
    if (budgetSummary == null) return timeline;
    return '$timeline, $budgetSummary';
  }
}

class AppStartupCoordinator {
  AppStartupCoordinator({
    required this.profiler,
    required this.beforeRunApp,
    required this.critical,
    required this.deferred,
  });

  final AppStartupProfiler profiler;
  final StartupTask beforeRunApp;
  final StartupTask critical;
  final StartupTask deferred;

  Future<void>? _criticalFuture;
  Future<void>? _deferredFuture;

  Future<void> prepare() async {
    await beforeRunApp();
    profiler.mark('before_run_app_ready');
  }

  void start() {
    _criticalFuture ??= _runPhase('critical_ready', critical);
    _deferredFuture ??= _runPhase('deferred_ready', deferred);
  }

  Future<void> waitForCritical() {
    _criticalFuture ??= _runPhase('critical_ready', critical);
    return _criticalFuture!;
  }

  Future<void> waitForDeferred() {
    _deferredFuture ??= _runPhase('deferred_ready', deferred);
    return _deferredFuture!;
  }

  Future<void> _runPhase(String markLabel, StartupTask task) async {
    await task();
    profiler.mark(markLabel);
  }
}
