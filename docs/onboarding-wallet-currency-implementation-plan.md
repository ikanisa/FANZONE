# FANZONE Full-Stack Implementation Plan

## Goal

Implement the requested onboarding, team-selection, Fan ID transfer, and FET display overhaul without asking users for their country, while keeping `FET` as the primary unit and computing fiat equivalents only in the backend.

## Current-State Audit

### 1. Onboarding does not support team selection yet

- The current onboarding is still a static 4-step marketing flow with no team-selection state, no skip logic, and no follow-up "Popular Teams" step.
- [lib/features/onboarding/screens/onboarding_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/onboarding/screens/onboarding_screen.dart:9)
- [lib/features/onboarding/screens/onboarding_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/onboarding/screens/onboarding_screen.dart:24)
- [lib/features/onboarding/screens/onboarding_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/onboarding/screens/onboarding_screen.dart:116)

### 2. Team search is literal, not semantic, and exposes browse lists

- Team discovery currently loads all teams, then filters client-side with `contains` on `name`, `shortName`, `country`, and `leagueName`.
- The screen explicitly renders `FEATURED` and `ALL TEAMS`, which conflicts with the requirement to avoid showing a broad team list before the user types.
- [lib/features/teams/screens/teams_discovery_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/teams/screens/teams_discovery_screen.dart:49)
- [lib/features/teams/screens/teams_discovery_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/teams/screens/teams_discovery_screen.dart:53)
- [lib/features/teams/screens/teams_discovery_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/teams/screens/teams_discovery_screen.dart:80)
- [lib/features/teams/screens/teams_discovery_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/teams/screens/teams_discovery_screen.dart:126)
- [lib/features/teams/screens/teams_discovery_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/teams/screens/teams_discovery_screen.dart:157)

### 3. Shared search infrastructure is basic `ILIKE`

- Both the Riverpod search provider and the repository implementation use `ILIKE` over a few text columns, capped at 8 teams, with no ranking, synonyms weighting, local-vs-popular scope, or autocomplete-optimized RPC.
- [lib/providers/search_provider.dart](/Volumes/PRO-G40/fanzone/lib/providers/search_provider.dart:17)
- [lib/providers/search_provider.dart](/Volumes/PRO-G40/fanzone/lib/providers/search_provider.dart:24)
- [lib/data/repositories/search_repository_impl.dart](/Volumes/PRO-G40/fanzone/lib/data/repositories/search_repository_impl.dart:21)
- [lib/data/repositories/search_repository_impl.dart](/Volumes/PRO-G40/fanzone/lib/data/repositories/search_repository_impl.dart:28)

### 4. Wallet transfer UX and backend do not match the Fan ID requirement

- The wallet UI still asks for a generic recipient and explicitly advertises phone/email transfer.
- The receive sheet still surfaces `display_name`, phone/email/user ID, not a six-digit Fan ID.
- The service comment claims support for `fan_id` or `display_name`, but the canonical production RPC only resolves `phone` or `email`.
- [lib/features/wallet/screens/wallet_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/wallet/screens/wallet_screen.dart:431)
- [lib/features/wallet/screens/wallet_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/wallet/screens/wallet_screen.dart:437)
- [lib/features/wallet/screens/wallet_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/wallet/screens/wallet_screen.dart:444)
- [lib/features/wallet/screens/wallet_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/wallet/screens/wallet_screen.dart:496)
- [lib/features/wallet/screens/wallet_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/wallet/screens/wallet_screen.dart:573)
- [lib/services/wallet_service.dart](/Volumes/PRO-G40/fanzone/lib/services/wallet_service.dart:33)
- [lib/services/wallet_service.dart](/Volumes/PRO-G40/fanzone/lib/services/wallet_service.dart:53)
- [supabase/migrations/20260418121500_p0_hardening_fixups.sql](/Volumes/PRO-G40/fanzone/supabase/migrations/20260418121500_p0_hardening_fixups.sql:508)
- [supabase/migrations/20260418121500_p0_hardening_fixups.sql](/Volumes/PRO-G40/fanzone/supabase/migrations/20260418121500_p0_hardening_fixups.sql:544)

### 5. Username/display-name assumptions are still present

- Profile still derives and displays `display_name`.
- Fan identity schema still persists `display_name`.
- Receive-FET sharing also uses `display_name`.
- This conflicts with the requirement to remove username-centric UX.
- [lib/features/profile/screens/profile_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/profile/screens/profile_screen.dart:37)
- [lib/features/profile/screens/profile_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/profile/screens/profile_screen.dart:111)
- [lib/models/fan_identity_model.dart](/Volumes/PRO-G40/fanzone/lib/models/fan_identity_model.dart:5)
- [lib/models/fan_identity_model.dart](/Volumes/PRO-G40/fanzone/lib/models/fan_identity_model.dart:29)
- [lib/features/wallet/screens/wallet_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/wallet/screens/wallet_screen.dart:496)

### 6. FET display is hardcoded across the app, with no fiat-equivalent formatter

- Wallet, profile, top bar, prediction slip, rewards, and admin all render raw FET amounts directly.
- There is no shared formatter that can output `FET 500 (€5)` or `FET 1,000 (RWF 14,000)`.
- No `guessUserCurrency` or equivalent utility exists in the app code.
- [lib/features/wallet/screens/wallet_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/wallet/screens/wallet_screen.dart:75)
- [lib/features/wallet/screens/wallet_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/wallet/screens/wallet_screen.dart:285)
- [lib/features/profile/screens/profile_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/profile/screens/profile_screen.dart:233)
- [lib/widgets/navigation/app_shell.dart](/Volumes/PRO-G40/fanzone/lib/widgets/navigation/app_shell.dart:204)
- [lib/features/predict/widgets/prediction_slip_dock.dart](/Volumes/PRO-G40/fanzone/lib/features/predict/widgets/prediction_slip_dock.dart:233)
- [lib/features/predict/widgets/prediction_slip_dock.dart](/Volumes/PRO-G40/fanzone/lib/features/predict/widgets/prediction_slip_dock.dart:314)
- [lib/features/predict/screens/predict_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/predict/screens/predict_screen.dart:698)
- [lib/features/predict/screens/predict_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/predict/screens/predict_screen.dart:873)
- [lib/features/rewards/screens/rewards_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/rewards/screens/rewards_screen.dart:176)
- [lib/features/rewards/screens/rewards_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/rewards/screens/rewards_screen.dart:221)
- [lib/features/rewards/screens/rewards_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/rewards/screens/rewards_screen.dart:250)
- [lib/features/rewards/screens/rewards_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/rewards/screens/rewards_screen.dart:336)
- [lib/features/rewards/screens/rewards_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/rewards/screens/rewards_screen.dart:441)
- [admin/src/lib/formatters.ts](/Volumes/PRO-G40/fanzone/admin/src/lib/formatters.ts:11)

### 7. Team schema is not yet rich enough for locality and currency inference

- `teams` currently has `country`, `aliases`, `is_featured`, and media fields, but nothing that explicitly models `locality`, `market`, `currency`, `popularity bucket`, or inference confidence.
- That means local-team inference is possible only by hand-rolled heuristics today.
- [lib/models/team_model.dart](/Volumes/PRO-G40/fanzone/lib/models/team_model.dart:12)
- [lib/models/team_model.dart](/Volumes/PRO-G40/fanzone/lib/models/team_model.dart:17)
- [lib/models/team_model.dart](/Volumes/PRO-G40/fanzone/lib/models/team_model.dart:21)
- [lib/models/team_model.dart](/Volumes/PRO-G40/fanzone/lib/models/team_model.dart:25)
- [supabase/migrations/005_teams_and_fan_communities.sql](/Volumes/PRO-G40/fanzone/supabase/migrations/005_teams_and_fan_communities.sql:13)
- [supabase/migrations/005_teams_and_fan_communities.sql](/Volumes/PRO-G40/fanzone/supabase/migrations/005_teams_and_fan_communities.sql:19)

### 8. Onboarding completion is a single boolean, so the new flow cannot be resumed safely

- Splash only checks `onboarding_complete`.
- There is no persisted onboarding state for step progress, skipped local team, selected popular team, or settings re-entry.
- [lib/features/auth/screens/splash_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/auth/screens/splash_screen.dart:66)
- [lib/features/auth/screens/splash_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/auth/screens/splash_screen.dart:70)

## Target Product Shape

### Onboarding

1. Replace the current final onboarding section with a dedicated screen titled `Favorite Team`.
2. Subtitle copy:
`FANZONE is local, add your local favorite team`.
3. Primary interaction:
`Search your local favorite team`.
4. Behavior:
- No team list before typing.
- As soon as typing begins, return a capped semantic list of max 10 relevant teams.
- After selection, hide the list and render only `Your Selection`.
- Primary CTA is `SKIP THIS STEP` until a local team is selected, then it becomes `CONTINUE`.
5. Add a new onboarding screen after that:
- Title `Popular Teams`
- Subtitle `Choose your favorite`
- 20 top European teams in a 5-column crest grid
- Search prompt `Didn't find your favorite team? Search more`
- Same capped semantic search behavior
- CTA rules: `SKIP FOR NOW` or `COMPLETE SETUP`
6. Both steps must be reachable later from settings/profile.

### Transfers

1. Public transfer identifier is a six-digit `Fan ID`.
2. Send flow accepts numbers only, max 6 digits.
3. Transfer CTA stays disabled until exactly 6 digits are entered.
4. Sending to your own Fan ID must hard-fail with a clear error.
5. Success and history language should read `Fan #123456`.

### FET display

1. Base peg is fixed:
`100 FET = 1 EUR`.
2. UI always shows FET first.
3. Fiat equivalent is secondary:
`FET 500 (€5)` or `FET 1,000 (RWF 14,000)`.
4. Conversion is computed in the backend.
5. Currency is inferred from user activity, especially selected teams.
6. The app never asks the user for country.

## Proposed Full-Stack Design

## Workstream A: Team data and search infrastructure

### A1. Extend `teams`

Add the following columns:

- `search_terms text[] not null default '{}'`
- `search_vector tsvector`
- `country_code text`
- `market_code text`
- `continent_code text`
- `currency_code text`
- `team_scope text not null default 'global'`
- `is_local_discoverable boolean not null default true`
- `is_popular_pick boolean not null default false`
- `popular_pick_rank integer`
- `popularity_score numeric`

Rationale:

- `country` alone is not enough to infer currency cleanly.
- Popular-team curation needs durable backend ordering.
- Semantic search needs synonyms and ranked text search.

### A2. Search index and RPC

Create:

- `GIN` index on `search_vector`
- `GIN` trigram index on `name`, `short_name`, and aliases/search terms
- RPC `search_teams_semantic(p_query text, p_mode text, p_limit int default 10, p_selected_team_ids text[] default '{}')`

RPC response shape:

- `id`
- `name`
- `short_name`
- `country_code`
- `market_code`
- `currency_code`
- `crest_url`
- `is_popular_pick`
- `popular_pick_rank`
- `semantic_score`
- `match_reason`

Modes:

- `local`
- `popular`
- `global`

Ranking inputs:

- exact prefix match
- trigram similarity
- full-text rank
- alias hit
- market/popularity boost
- prior onboarding selection suppression

### A3. Seed data

Prepare two explicit seed groups:

- `Local/localizable teams`
  Include Malta, Rwanda, Nigeria, Kenya, and other intended local markets plus aliases.
- `Popular Teams`
  Seed the exact top 20 European clubs used on the curated grid and assign `popular_pick_rank`.

This is where African teams such as `APR FC`, `Kiyovu Sports`, `Enyimba`, and `Gor Mahia` should be formalized instead of being treated as an ad hoc simulation.

## Workstream B: User preference and inference model

### B1. New table: `user_team_preferences`

Columns:

- `id uuid primary key`
- `user_id uuid not null`
- `team_id text not null`
- `selection_type text not null`
- `source text not null`
- `position smallint`
- `is_active boolean not null default true`
- `selected_at timestamptz not null default now()`
- `metadata jsonb not null default '{}'`

`selection_type` values:

- `local`
- `popular`
- `followed`

`source` values:

- `onboarding`
- `settings`
- `profile`
- `team_profile`

### B2. New table: `user_currency_profiles`

Columns:

- `user_id uuid primary key`
- `currency_code text not null`
- `country_code text`
- `inference_source text not null`
- `source_team_id text`
- `confidence numeric not null`
- `last_recomputed_at timestamptz not null default now()`
- `metadata jsonb not null default '{}'`

This becomes the backend-owned source of truth for display currency.

### B3. Inference utility

Implement `guess_user_currency(p_user_id uuid)` as a SQL or PL/pgSQL function that:

1. Looks at `user_team_preferences` in priority order:
- local
- popular
- followed/supporting
2. Maps the strongest team signal to `currency_code`.
3. Falls back to prior inferred currency if recent.
4. Falls back to `EUR` if no signal exists.

Never expose "what country are you in?" in the UI.

## Workstream C: Fan ID rollout

### C1. Canonical Fan ID

Add to `fan_profiles`:

- `fan_id char(6) unique`

Generation rules:

- numeric only
- unique
- immutable once assigned
- assigned automatically on first profile creation

Do not use `display_name` as a transfer identifier.

### C2. Transfer RPC rewrite

Replace the current lookup logic in `public.transfer_fet` so it resolves:

1. exact `fan_id`
2. optionally legacy phone/email only for backward compatibility, behind a server-side flag

Required validation:

- recipient identifier must be exactly 6 digits for app traffic
- sender cannot transfer to own `fan_id`
- sender wallet must be available
- recipient wallet auto-creates if needed

Return payload should include:

- `recipient_fan_id`
- `amount_fet`
- `sender_balance_after`

### C3. Transaction titles

Standardize titles:

- `Transfer to Fan #882190`
- `Transfer from Fan #910243`

This should be encoded at write time in `fet_wallet_transactions.title`.

## Workstream D: Currency and FET display layer

### D1. Exchange-rate storage

Create `fet_exchange_rates`:

- `currency_code text primary key`
- `eur_to_currency numeric not null`
- `currency_symbol text`
- `display_locale text`
- `updated_at timestamptz not null default now()`

Because the peg is fixed:

- `fet_amount / 100 = eur_amount`
- `eur_amount * eur_to_currency = local_amount`

### D2. Backend formatter contract

Create RPC or edge function:

- `format_fet_display(p_user_id uuid, p_amount_fet bigint)`

Return:

- `amount_fet`
- `primary_label`
- `currency_code`
- `fiat_amount`
- `fiat_label`
- `combined_label`

Example:

- `primary_label = FET 1,000`
- `fiat_label = RWF 14,000`
- `combined_label = FET 1,000 (RWF 14,000)`

### D3. Shared client formatter

Create one Flutter formatter wrapper that consumes the backend currency profile and exchange data, then reuse it everywhere.

Required replacement targets:

- top-bar FET pill
- profile balance card
- wallet balance card
- wallet transfer ledger rows
- prediction slip potential returns
- pool stake displays
- rewards balances and redemption confirmations
- team contribution dialogs

Admin should also adopt the same pattern where user-facing amounts appear.

## Workstream E: Onboarding UI rebuild

### E1. State model

Introduce a dedicated onboarding state object:

- `current_step`
- `local_team_id`
- `popular_team_id`
- `local_step_skipped`
- `popular_step_skipped`
- `completed_at`

Persist this locally and sync important parts remotely after auth.

### E2. Step 4: `Favorite Team`

Replace current "Ready" step with:

- Title: `Favorite Team`
- Subtitle: `FANZONE is local, add your local favorite team`
- Search field label: `Search your local favorite team`
- Helper copy beneath field: `Start typing to find your team`
- Empty state before typing: no list shown
- After typing: show max 10 results instantly
- After selection: collapse results and render `Your Selection`
- CTA:
  - no selection: `SKIP THIS STEP`
  - selected: `CONTINUE`

### E3. Step 5: `Popular Teams`

Create a new screen:

- Title: `Popular Teams`
- Subtitle: `Choose your favorite`
- 20-team crest grid
- 5 items per row
- Search prompt: `Didn't find your favorite team? Search more`
- Search list capped at 10
- CTA:
  - none selected: `SKIP FOR NOW`
  - selected: `COMPLETE SETUP`

### E4. Settings/Profile re-entry

Add entry points in settings/profile:

- `Favorite Team`
- `Popular Teams`
- `Change Fan ID sharing preferences`

Users must be able to set or revise skipped choices later.

## Workstream F: Flutter integration plan

### Files to replace or heavily refactor

- [lib/features/onboarding/screens/onboarding_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/onboarding/screens/onboarding_screen.dart:17)
- [lib/features/teams/screens/teams_discovery_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/teams/screens/teams_discovery_screen.dart:13)
- [lib/providers/search_provider.dart](/Volumes/PRO-G40/fanzone/lib/providers/search_provider.dart:9)
- [lib/services/wallet_service.dart](/Volumes/PRO-G40/fanzone/lib/services/wallet_service.dart:10)
- [lib/features/wallet/screens/wallet_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/wallet/screens/wallet_screen.dart:18)
- [lib/features/profile/screens/profile_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/profile/screens/profile_screen.dart:17)
- [lib/widgets/navigation/app_shell.dart](/Volumes/PRO-G40/fanzone/lib/widgets/navigation/app_shell.dart:20)
- [lib/features/predict/widgets/prediction_slip_dock.dart](/Volumes/PRO-G40/fanzone/lib/features/predict/widgets/prediction_slip_dock.dart:233)
- [lib/features/predict/screens/predict_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/predict/screens/predict_screen.dart:698)
- [lib/features/rewards/screens/rewards_screen.dart](/Volumes/PRO-G40/fanzone/lib/features/rewards/screens/rewards_screen.dart:165)

### New Flutter modules recommended

- `lib/features/onboarding/models/onboarding_preference_state.dart`
- `lib/features/onboarding/providers/onboarding_preferences_provider.dart`
- `lib/features/onboarding/widgets/semantic_team_search_field.dart`
- `lib/features/onboarding/widgets/team_search_results_list.dart`
- `lib/features/onboarding/widgets/popular_team_grid.dart`
- `lib/core/formatting/fet_display_formatter.dart`
- `lib/core/models/fet_display_value.dart`
- `lib/core/providers/currency_profile_provider.dart`
- `lib/features/wallet/widgets/fan_id_transfer_sheet.dart`

## Workstream G: Admin and ops support

### Admin requirements

- CRUD support for `is_popular_pick` and `popular_pick_rank`
- tools to edit team aliases/search terms
- visibility into inferred currency profile per user
- visibility into Fan ID

### Admin files likely impacted

- `admin/src/types/index.ts`
- `admin/src/features/users/*`
- `admin/src/features/wallets/*`
- `admin/src/lib/formatters.ts`

## Delivery Phases

### Phase 1: Backend primitives

1. Team schema enrichment
2. `user_team_preferences`
3. `user_currency_profiles`
4. `fet_exchange_rates`
5. `fan_profiles.fan_id`
6. `search_teams_semantic`
7. `guess_user_currency`
8. `transfer_fet` rewrite

### Phase 2: Onboarding UI

1. Replace step 4
2. Add step 5
3. Persist onboarding progress
4. Write selected teams to `user_team_preferences`
5. Recompute currency profile after selection

### Phase 3: Wallet and profile

1. Fan ID send/receive flow
2. Transaction-title migration
3. Shared FET display formatter
4. Remove username-first language

### Phase 4: Product-wide FET display migration

1. Profile
2. Wallet
3. Top bar
4. Prediction slip
5. Pools/challenges
6. Rewards
7. Team contribution surfaces

### Phase 5: Admin support and cleanup

1. Admin currency visibility
2. Admin team curation
3. Legacy identifier fallback removal
4. Data backfill jobs

## Data Migration Plan

### Existing users

1. Generate `fan_id` for all current `fan_profiles`.
2. Backfill `user_team_preferences` from:
- `team_supporters`
- `user_followed_teams`
3. Infer initial `user_currency_profiles` from the strongest team signal.
4. Default to `EUR` when no signal exists.

### Existing transactions

Backfill transfer titles where possible:

- sender side: `Transfer to Fan #xxxxxx`
- recipient side: `Transfer from Fan #xxxxxx`

If the original recipient cannot be resolved historically, keep the old title but do not expose legacy identifier prompts in new UI.

## Testing Plan

### Backend

- RPC tests for `search_teams_semantic`
- RPC tests for `guess_user_currency`
- RPC tests for `transfer_fet`
- migration tests for `fan_id` uniqueness
- rate-limit tests
- self-transfer rejection tests

### Flutter

- onboarding step navigation
- skip behavior on local and popular screens
- search result cap at 10
- selection collapse into `Your Selection`
- Fan ID input numeric-only behavior
- disabled transfer CTA until 6 digits
- self-transfer error rendering
- FET display formatting snapshots

### Manual QA

- Malta team -> EUR
- Arsenal/Chelsea -> GBP
- APR/Kiyovu -> RWF
- Nigerian team -> NGN
- local step skipped + later edit from settings
- popular step skipped + later edit from profile

## Risks

### 1. "Semantic search" without explicit embeddings

The current stack is already Postgres/Supabase. The fastest stable implementation is weighted full-text + trigram + aliases. That is usually enough for this product requirement and avoids adding vector infrastructure immediately.

### 2. Country inference ambiguity

Users can support non-local clubs. The model must therefore prefer:

1. local-team onboarding choice
2. local-market team follows
3. strongest repeated activity
4. popular-team fallback

This should be stored with a confidence score, not recomputed ad hoc in every screen.

### 3. Display-name removal vs community identity

Display names may still be useful internally for admin or optional profile presentation, but transfer and onboarding should not depend on them. The public identifier should be `Fan ID`.

## Recommended Execution Order

1. Backend schema and RPCs
2. Team data seeding and ranking
3. Onboarding rebuild
4. Fan ID transfer rewrite
5. Shared FET display formatter
6. Screen-by-screen amount migration
7. Admin tooling

## Definition of Done

- Onboarding includes `Favorite Team` and `Popular Teams` with skip paths.
- Team search is capped, responsive, and semantic enough to rank by relevance.
- No onboarding screen shows a generic all-teams list before typing.
- Transfers are Fan-ID-first and six-digit validated.
- Self-transfer is blocked in UI and backend.
- All major user-facing balances/transactions show `FET X (LOCAL Y)`.
- Currency is inferred from team/activity data without asking country.
- Users can revisit skipped team steps from settings/profile.
