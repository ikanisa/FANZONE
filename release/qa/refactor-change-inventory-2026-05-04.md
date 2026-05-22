# Refactor Change Inventory - 2026-05-04

Purpose: separate the current audit/refactor slice from unrelated dirty working-tree changes before additional release work.

## Bucket A - Audit/refactor slice

These files belong to the repository audit, design-system alignment, Supabase hardening, and release-readiness work.

### Flutter design system

- `lib/design_system/design_system.dart`
- `lib/design_system/tokens/app_colors.dart`
- `lib/design_system/tokens/app_spacing.dart`
- `lib/design_system/tokens/app_radii.dart`
- `lib/design_system/tokens/app_shadows.dart`
- `lib/design_system/typography/app_typography.dart`
- `lib/design_system/components/app_badge.dart`
- `lib/design_system/components/app_button.dart`
- `lib/design_system/components/app_card.dart`
- `lib/design_system/components/app_chip.dart`
- `lib/design_system/components/app_countdown.dart`
- `lib/design_system/components/app_eligibility_badge.dart`
- `lib/design_system/components/app_empty_state.dart`
- `lib/design_system/components/app_error_state.dart`
- `lib/design_system/components/app_fet_badge.dart`
- `lib/design_system/components/app_loading_state.dart`
- `lib/design_system/components/app_metric_card.dart`
- `lib/design_system/components/app_section_header.dart`
- `lib/design_system/components/app_status_pill.dart`

### Flutter shared UI alignment

- `lib/core/errors/app_error_boundary.dart`
- `lib/features/onboarding/widgets/onboarding_step_chrome.dart`
- `lib/widgets/common/fz_badge.dart`
- `lib/widgets/common/fz_offline_banner.dart`
- `lib/widgets/common/state_view.dart`
- `lib/widgets/navigation/app_shell.dart`
- `test/design_tokens_test.dart`
- `test/goldens/design_system_components.dark.png`

### Supabase hardening and release audit

- `supabase/migrations/20260504100000_wallet_transfer_grant_hardening.sql`
- `supabase/migrations/20260504140000_db_lint_cleanup.sql`
- `supabase/tests/release_readiness_hardening.sql`

Notes:
- `supabase/tests/release_readiness_hardening.sql` also had active changes outside this slice. Review its complete diff before staging.
- `20260504140000_db_lint_cleanup.sql` includes lint cleanup plus explicit `anon` revoke hardening for sensitive RPCs.

### Practical docs

- `PRODUCT_RULES.md`
- `FET_LEDGER.md`
- `QA_CHECKLIST.md`
- `release/qa/refactor-change-inventory-2026-05-04.md`

## Bucket B - Touched during validation, review before staging

These files were touched to keep analyzer/tests green, but the surrounding files or directories were already untracked or mixed with broader work.

- `lib/features/games/data/games_repository.dart`
- `lib/features/games/screens/games_screen.dart`
- `lib/features/games/screens/game_detail_screen.dart`

Reason: `lib/features/games/` is untracked as a directory in the current working tree. The analyzer includes it, so fixes were needed, but the full directory should be reviewed as a unit before staging.

## Bucket C - Related release/backend work from another slice

These files appear release-related and were applied/validated locally, but they were not created as part of the design-system/Supabase lint-hardening slice.

- `.env.example`
- `.env.production.example`
- `.env.staging.example`
- `apps/admin/.env.example`
- `apps/tv-display/.env.example`
- `apps/venue-portal/.env.example`
- `apps/website/.env.example`
- `supabase/.env.example`
- `docs/release/deployment-readme.md`
- `release/android/feature-graphic/.gitkeep`
- `release/android/screenshots/.gitkeep`
- `release/ios/screenshots/.gitkeep`
- `release/qa/final-production-readiness-report.md`
- `supabase/migrations/20260504120000_auth_foundation_hardening.sql`
- `supabase/migrations/20260504130000_user_payment_submission.sql`
- `supabase/migrations/20260504133000_game_user_flow_and_settlement.sql`
- `tool/validate_release_env.sh`

Recommendation: review as a separate release-readiness commit or PR section.

## Bucket D - Unrelated or pre-existing dirty files

These tracked files are modified but were not part of the current audit/refactor slice. Do not stage them with Bucket A without reviewing ownership and intent.

- `.github/workflows/secret-regex-scan.yml`
- `.gitignore`
- `apps/venue-portal/src/features/target/TargetPages.tsx`
- `apps/venue-portal/src/services/venueOperations.ts`
- `apps/website/canonical-source-manifest.json`
- `apps/website/src/components/Pools.tsx`
- `apps/website/src/services/api.ts`
- `docs/free-account-release.md`
- `lib/app_router.dart`
- `lib/features/ordering/data/order_gateway.dart`
- `lib/features/ordering/providers/order_provider.dart`
- `lib/features/ordering/screens/order_success_screen.dart`
- `lib/features/ordering/screens/order_tracking_screen.dart`
- `lib/features/pools/data/pools_repository.dart`
- `lib/features/pools/screens/pool_detail_screen.dart`
- `lib/features/pools/screens/pools_screen.dart`
- `packages/core/src/types.ts`
- `release/qa/production-uat-report.md`
- `release/qa/release-checklist.md`
- `release/tv/tv-screen-deployment-notes.md`
- `release/web/deployment-notes.md`
- `supabase/functions/_shared/audit.ts`
- `supabase/functions/_shared/gemini.ts`
- `supabase/functions/_shared/http.ts`
- `supabase/functions/_shared/logger.ts`
- `supabase/functions/_shared/mod.ts`
- `supabase/functions/_shared/types.ts`
- `supabase/functions/admin_approve_onboarding/index.ts`
- `supabase/functions/admin_user_management/index.ts`
- `supabase/functions/approve_claim/index.ts`
- `supabase/functions/bar_onboarding_submit/index.ts`
- `supabase/functions/bar_search/index.ts`
- `supabase/functions/menu_ocr_parse/index.ts`
- `supabase/functions/order_create/index.ts`
- `supabase/functions/order_mark_paid/index.ts`
- `supabase/functions/push-notify/payload.ts`
- `supabase/functions/submit_claim/index.ts`
- `supabase/functions/venue_claim/index.ts`
- `supabase/functions/whatsapp-otp/index.ts`
- `supabase/functions/whatsapp-otp/index_test.ts`
- `supabase/tests/whatsapp_auth_verification.sql`
- `test/order_model_test.dart`
- `tool/supabase_release_probe.sh`
- `tool/validate_web_release_env.sh`

## Suggested staging groups

Use these groups only after reviewing the mixed files noted above.

### Group 1 - Design system and shared UI

- `lib/design_system/`
- `lib/core/errors/app_error_boundary.dart`
- `lib/features/onboarding/widgets/onboarding_step_chrome.dart`
- `lib/widgets/common/fz_badge.dart`
- `lib/widgets/common/fz_offline_banner.dart`
- `lib/widgets/common/state_view.dart`
- `lib/widgets/navigation/app_shell.dart`
- `test/design_tokens_test.dart`
- `test/goldens/design_system_components.dark.png`

### Group 2 - Supabase hardening

- `supabase/migrations/20260504100000_wallet_transfer_grant_hardening.sql`
- `supabase/migrations/20260504140000_db_lint_cleanup.sql`
- `supabase/tests/release_readiness_hardening.sql`

### Group 3 - Practical docs

- `PRODUCT_RULES.md`
- `FET_LEDGER.md`
- `QA_CHECKLIST.md`
- `release/qa/refactor-change-inventory-2026-05-04.md`

## Last verified checks

- `flutter analyze`: passed
- `flutter test --reporter compact`: passed, 224 tests
- `deno test --allow-env --config deno.json supabase/functions/_shared/*.ts supabase/functions/whatsapp-otp/index_test.ts`: passed, 21 tests
- `npm run typecheck --workspaces --if-present`: passed
- `npm run lint --workspaces --if-present`: passed
- `npm run build --workspaces --if-present`: passed
- `supabase migration up --local`: passed
- `supabase db lint --local`: passed
- `psql ... supabase/tests/release_readiness_hardening.sql`: passed
- `psql ... supabase/tests/rls_hardening_audit.sql`: passed
