# Platform Feature Management Implementation

## Architecture Audit

- Supabase already contained a first-pass platform registry:
  - `platform_features`
  - `platform_feature_rules`
  - `platform_feature_channels`
  - `platform_content_blocks`
  - `resolve_platform_feature(...)`
  - `assert_platform_feature_available(...)`
  - `get_app_bootstrap_config(...)`
- Flutter was partially integrated with the registry for primary navigation and home composition, but several secondary entry points still used hardcoded routes and action buttons.
- Website bootstrap consumption already existed, but profile shortcuts, league actions, alias redirects, and some back links still bypassed the registry and could expose disabled features.
- Admin already had a Platform Control surface, but writes were still browser-side table mutations rather than RPC-only admin operations.
- Backend feature enforcement existed for some RPCs, but role-aware evaluation and stricter source-of-truth separation between legacy runtime flags and platform-managed modules still needed hardening.

## Target Architecture

- Supabase is the source of truth for feature state, channel state, schedule windows, dependencies, visibility, and admin-managed content blocks.
- Frontend bootstrap consumers on Flutter and website use the same payload:
  - `platform_features`
  - `platform_content_blocks`
  - `platform_config_version`
  - legacy `feature_flags` for non-platform runtime flags only
- All frontend entry points route through a single feature-access layer per channel:
  - visibility checks for nav, home, and route rendering
  - route resolution for managed entry points
  - action-availability checks for guarded operations
- Backend enforcement remains centralized in Supabase functions and RPC guards rather than component-specific conditionals.
- Admin writes go through `admin_upsert_platform_feature(jsonb)` and `admin_upsert_platform_content_block(jsonb)` so direct table writes are not exposed to authenticated browser clients.

## Implemented Changes

- Added Supabase control-plane hardening in:
  - `supabase/migrations/20260423143000_platform_feature_management_controls.sql`
  - `supabase/migrations/20260423150000_feature_flag_source_of_truth_cleanup.sql`
- Extended Supabase feature evaluation with:
  - role extraction from JWT/admin records
  - role restriction evaluation
  - config version hashing
  - RPC-only admin upserts for feature and content block management
- Refactored admin Platform Control to submit normalized JSON payloads through RPCs and added payload normalization tests.
- Refactored Flutter runtime access so it:
  - uses a single `PlatformFeatureAccess` source of truth
  - keeps a safe empty state until remote config is available instead of fabricating managed modules locally
  - removes disabled secondary entry points from fixtures, league hub, profile, and shell chrome
  - uses central action guards before prediction, wallet, and notification mutations
- Refactored website runtime access so it:
  - waits for a real Supabase bootstrap snapshot before rendering managed routes
  - does not synthesize registry or content defaults when bootstrap data is unavailable
  - centralizes route resolution through platform helpers
  - removes disabled feature shortcuts from profile, league hub, nav aliases, and managed back links
  - keeps action helpers aligned with registry availability
- Added verification coverage for:
  - new Supabase helper functions and RPCs
  - direct-write grant regressions on platform registry tables
  - Flutter feature-access fallback and visibility behavior
  - website feature-access fallback and filtering behavior

## Rollout Notes

1. Apply Supabase migrations in order and run the SQL verification scripts under `supabase/tests`.
2. Validate seeded `route_key` values in admin before exposing route changes broadly.
3. Confirm app and website bootstrap payloads carry the same `platform_config_version`.
4. Smoke-test these admin changes end to end:
   - disable website leaderboard only
   - disable mobile predictions only
   - hide wallet from navigation while keeping it operational
   - disable notifications and verify route fallback plus RPC blocking
5. Keep legacy `feature_flags` for non-platform runtime toggles only. New product-module exposure should go through Platform Control.

## Assumptions

- `route_key` values in Platform Control are expected to map to routes the current app and website actually implement.
- Website “predictions” resolves to the fixtures/match-detail flow rather than a dedicated `/predict` page.
- Privacy and some utility pages remain first-party app surfaces, but their entry points now resolve through the managed profile/fixtures routes where applicable.
