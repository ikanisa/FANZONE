# Platform Control Refactor

## Current-State Audit

- Mobile already had a Supabase bootstrap contract, but it only exposed flat `feature_flags`, launch moments, and runtime config. Route gating existed for a few screens, while navigation and home composition were still mostly hardcoded.
- Website was operating from a separate runtime path. Navigation, homepage composition, and route availability were hardcoded in React components, with no shared platform bootstrap and no persistent feature-config fallback.
- Admin had low-level settings for feature flags and runtime config, but no channel-aware feature registry, no homepage/content-block control plane, and no single operational surface for app/web rollout.
- Backend had durable RPCs and business logic, but shared feature state was not centrally modeled as platform modules. Sensitive actions like prediction submission and wallet transfer were callable independently of channel-aware rollout state.

## Target Architecture

- `platform_features`, `platform_feature_rules`, `platform_feature_channels`, and `platform_content_blocks` now define the managed product model.
- `get_app_bootstrap_config` is extended into a shared bootstrap contract for mobile and web:
  - legacy `feature_flags` remain for backward compatibility
  - channel-aware `platform_features` are included for routing, nav, and home logic
  - `platform_content_blocks` are included for admin-managed home composition
- Backend enforcement is centralized through:
  - `resolve_platform_feature(...)`
  - `assert_platform_feature_available(...)`
  - `request_platform_channel()`
- Admin now has a dedicated Platform Control surface for:
  - feature registry metadata
  - app/web channel states
  - nav/home placement
  - content blocks
  - audit trail inspection
- Mobile and website both read the same feature registry and adapt nav, home composition, route fallback, and action availability from that shared source.

## Rollout Notes

1. Apply the new Supabase migration and verify the new views/functions using the Supabase SQL verification files.
2. Open Admin → Platform Control and validate seeded feature/channel defaults before broader rollout.
3. Confirm bootstrap payloads on both channels include:
   - `platform_features`
   - `platform_content_blocks`
   - legacy `feature_flags`
4. Test operational toggles in this order:
   - disable website leaderboard only
   - disable mobile predictions only
   - hide wallet from navigation while keeping it operational
   - disable notifications and verify route/action fallback
5. After validation, migrate more remaining feature entry points from legacy per-screen checks onto the shared platform registry helpers.

## Notes

- This refactor is additive. Existing production-oriented flows are preserved where possible.
- Legacy `feature_flags` remain as a compatibility layer, but the intended control plane is the platform feature registry.
- Admin audit history is reused rather than duplicated; platform-control changes are written into the existing admin audit system and exposed through a dedicated filtered view.
