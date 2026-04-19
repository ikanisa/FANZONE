# Performance Baseline — 2026-04-19

This baseline defines the minimum engineering contract FANZONE should hold while the product is still stabilizing against the reference experience in `/Users/jeanbosco/Downloads/FANZONE/src`.

## Enforced budgets

- Critical startup readiness: `<= 3s`
- First-frame build budget: `<= 8ms`
- First-frame raster budget: `<= 8ms`
- Total frame budget: `<= 16ms` at 60fps

## Instrumentation

- Startup timing is tracked in [lib/main.dart](/Volumes/PRO-G40/FANZONE/lib/main.dart:32) through `AppStartupProfiler` and `AppStartupCoordinator`.
- First-frame build/raster timing is normalized through [lib/core/performance/frame_budget.dart](/Volumes/PRO-G40/FANZONE/lib/core/performance/frame_budget.dart:1).
- Budget tests live in:
  - [test/startup_budget_test.dart](/Volumes/PRO-G40/FANZONE/test/startup_budget_test.dart:1)
  - [test/frame_budget_test.dart](/Volumes/PRO-G40/FANZONE/test/frame_budget_test.dart:1)

## Current gap

The repo still has unrelated compile and DI breakage outside these paths, so this baseline is currently a code-level performance contract plus targeted automated checks, not a clean device-measured release benchmark yet.
