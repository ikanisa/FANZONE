import 'dart:ui' show FrameTiming;

const kFrameBuildBudget = Duration(milliseconds: 8);
const kFrameRasterBudget = Duration(milliseconds: 8);
const kFrameTotalBudget = Duration(milliseconds: 16);

class FrameBudgetSample {
  const FrameBudgetSample({
    required this.buildDuration,
    required this.rasterDuration,
  });

  factory FrameBudgetSample.fromTiming(FrameTiming timing) {
    return FrameBudgetSample(
      buildDuration: timing.buildDuration,
      rasterDuration: timing.rasterDuration,
    );
  }

  final Duration buildDuration;
  final Duration rasterDuration;

  Duration get totalDuration => buildDuration + rasterDuration;

  bool get meetsBuildBudget => buildDuration <= kFrameBuildBudget;
  bool get meetsRasterBudget => rasterDuration <= kFrameRasterBudget;
  bool get meetsTotalBudget => totalDuration <= kFrameTotalBudget;

  bool get withinBudget =>
      meetsBuildBudget && meetsRasterBudget && meetsTotalBudget;

  String summary() {
    return 'build=${buildDuration.inMilliseconds}ms, '
        'raster=${rasterDuration.inMilliseconds}ms, '
        'total=${totalDuration.inMilliseconds}ms';
  }
}

class FrameBudgetBaseline {
  const FrameBudgetBaseline({
    required this.sampleCount,
    required this.averageBuildDuration,
    required this.averageRasterDuration,
    required this.averageTotalDuration,
    required this.worstBuildDuration,
    required this.worstRasterDuration,
    required this.worstTotalDuration,
  });

  factory FrameBudgetBaseline.fromSamples(Iterable<FrameBudgetSample> samples) {
    final values = samples.toList(growable: false);
    if (values.isEmpty) {
      return const FrameBudgetBaseline(
        sampleCount: 0,
        averageBuildDuration: Duration.zero,
        averageRasterDuration: Duration.zero,
        averageTotalDuration: Duration.zero,
        worstBuildDuration: Duration.zero,
        worstRasterDuration: Duration.zero,
        worstTotalDuration: Duration.zero,
      );
    }

    return FrameBudgetBaseline(
      sampleCount: values.length,
      averageBuildDuration: _average(
        values.map((sample) => sample.buildDuration),
      ),
      averageRasterDuration: _average(
        values.map((sample) => sample.rasterDuration),
      ),
      averageTotalDuration: _average(
        values.map((sample) => sample.totalDuration),
      ),
      worstBuildDuration: _max(values.map((sample) => sample.buildDuration)),
      worstRasterDuration: _max(values.map((sample) => sample.rasterDuration)),
      worstTotalDuration: _max(values.map((sample) => sample.totalDuration)),
    );
  }

  final int sampleCount;
  final Duration averageBuildDuration;
  final Duration averageRasterDuration;
  final Duration averageTotalDuration;
  final Duration worstBuildDuration;
  final Duration worstRasterDuration;
  final Duration worstTotalDuration;

  bool get withinBudget =>
      worstBuildDuration <= kFrameBuildBudget &&
      worstRasterDuration <= kFrameRasterBudget &&
      worstTotalDuration <= kFrameTotalBudget;

  List<String> get budgetFailures {
    final failures = <String>[];
    if (worstBuildDuration > kFrameBuildBudget) failures.add('build');
    if (worstRasterDuration > kFrameRasterBudget) failures.add('raster');
    if (worstTotalDuration > kFrameTotalBudget) failures.add('total');
    return failures;
  }

  String summary() {
    return 'frames=$sampleCount, '
        'avgBuild=${averageBuildDuration.inMilliseconds}ms, '
        'avgRaster=${averageRasterDuration.inMilliseconds}ms, '
        'avgTotal=${averageTotalDuration.inMilliseconds}ms, '
        'worstBuild=${worstBuildDuration.inMilliseconds}ms, '
        'worstRaster=${worstRasterDuration.inMilliseconds}ms, '
        'worstTotal=${worstTotalDuration.inMilliseconds}ms';
  }
}

Duration _average(Iterable<Duration> values) {
  final list = values.toList(growable: false);
  if (list.isEmpty) return Duration.zero;
  final totalMicros = list.fold<int>(
    0,
    (sum, value) => sum + value.inMicroseconds,
  );
  return Duration(microseconds: totalMicros ~/ list.length);
}

Duration _max(Iterable<Duration> values) {
  final list = values.toList(growable: false);
  if (list.isEmpty) return Duration.zero;

  var current = list.first;
  for (final value in list.skip(1)) {
    if (value > current) current = value;
  }
  return current;
}
