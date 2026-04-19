import 'package:flutter_test/flutter_test.dart';

import 'package:fanzone/core/performance/frame_budget.dart';

void main() {
  test(
    'frame budget baseline stays within 60fps budget when samples are clean',
    () {
      final baseline = FrameBudgetBaseline.fromSamples(const [
        FrameBudgetSample(
          buildDuration: Duration(milliseconds: 5),
          rasterDuration: Duration(milliseconds: 6),
        ),
        FrameBudgetSample(
          buildDuration: Duration(milliseconds: 4),
          rasterDuration: Duration(milliseconds: 5),
        ),
        FrameBudgetSample(
          buildDuration: Duration(milliseconds: 7),
          rasterDuration: Duration(milliseconds: 6),
        ),
      ]);

      expect(baseline.sampleCount, 3);
      expect(baseline.worstBuildDuration, lessThanOrEqualTo(kFrameBuildBudget));
      expect(
        baseline.worstRasterDuration,
        lessThanOrEqualTo(kFrameRasterBudget),
      );
      expect(baseline.worstTotalDuration, lessThanOrEqualTo(kFrameTotalBudget));
      expect(baseline.withinBudget, isTrue);
      expect(baseline.summary(), contains('avgBuild='));
    },
  );

  test(
    'frame budget baseline flags jank when any frame exceeds the contract',
    () {
      final baseline = FrameBudgetBaseline.fromSamples(const [
        FrameBudgetSample(
          buildDuration: Duration(milliseconds: 6),
          rasterDuration: Duration(milliseconds: 7),
        ),
        FrameBudgetSample(
          buildDuration: Duration(milliseconds: 11),
          rasterDuration: Duration(milliseconds: 9),
        ),
      ]);

      expect(baseline.withinBudget, isFalse);
      expect(
        baseline.budgetFailures,
        containsAll(<String>['build', 'raster', 'total']),
      );
    },
  );
}
