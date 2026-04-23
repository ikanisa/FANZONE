# Lean Prediction Architecture

## Goal

Support a free football prediction app with one clear backend contract and no betting-style complexity.

## Domain Layers

1. `competitions`
2. `seasons`
3. `teams`
4. `team_aliases`
5. `matches`
6. `standings`
7. `team_form_features`
8. `predictions_engine_outputs`
9. `user_predictions`
10. `token_rewards`

## Data Flow

```text
CSV / admin import
  -> competitions / seasons / teams / team_aliases / matches / standings
  -> team alias resolution and upsert
  -> feature refresh for relevant matches
  -> prediction generation for upcoming fixtures

User app
  -> reads app views and engine outputs
  -> writes user_predictions through submit RPC

Result entry
  -> match scores entered
  -> result_code derived
  -> pending user predictions scored
  -> token_rewards created when applicable
```

## Supabase Contract

Core tables:

- `competitions`
- `seasons`
- `teams`
- `team_aliases`
- `matches`
- `standings`
- `team_form_features`
- `predictions_engine_outputs`
- `user_predictions`
- `token_rewards`

Core views:

- `app_competitions`
- `app_competitions_ranked`
- `app_matches`
- `competition_standings`
- `match_prediction_consensus`
- `prediction_leaderboard`
- `public_leaderboard`

`matches` remains the canonical write-side table. `app_matches` is the only read-side fixture projection used by the app and admin interfaces.

Core RPCs and SQL functions:

- `submit_user_prediction`
- `refresh_team_form_features_for_match`
- `generate_prediction_engine_output`
- `generate_predictions_for_upcoming_matches`
- `score_user_predictions_for_match`
- `score_finished_matches_with_pending_predictions`
- `admin_update_match_result`
- alias and import helper functions

Runtime bootstrap tables:

- `feature_flags`
- `app_config_remote`
- `launch_moments`
- `country_region_map`
- `country_currency_map`
- `phone_presets`
- `currency_display_metadata`

The Flutter app bootstraps runtime config through `get_app_bootstrap_config`. The admin panel now reads the same runtime records and manages feature flags directly against `feature_flags`.
Phone-country selection and onboarding dial-code behavior now derive from the same bootstrap tables instead of static market lists.

## Flutter Architecture

Primary user flows:

- home feed surfaces live and upcoming fixtures
- predict hub lists upcoming fixtures and saved picks
- match detail shows engine output, consensus, recent form, and user entry
- fixtures and league hub stay read-only around competitions, teams, and standings
- wallet and rewards stay separate from prediction entry

State and data access:

- Riverpod providers remain the orchestration layer
- feature gateways map Supabase rows and RPCs into app models
- `PredictionService` owns engine output, form feature, and user prediction access
- `matchesProvider`, `competitionsProvider`, `teamsProvider`, and `standingsProvider` read only the lean Supabase views and tables

Current module map:

- `lib/features/home/`
  - lean fixture browsing from `app_matches`, `app_competitions_ranked`, and canonical `teams`
- `lib/features/fixtures/`
  - competition and date-driven fixture exploration using the same `app_matches` projection
- `lib/features/predict/`
  - prediction engine output, team form features, saved user picks, and `submit_user_prediction` entry flow
- `lib/features/leaderboard/`
  - single global leaderboard projection from `public_leaderboard`
- `lib/features/teams/`
  - canonical team profile with fixtures and competition context from `teams` and `app_matches`
- `lib/features/wallet/`
  - wallet balance, rewards, and transfers preserved as a separate subsystem
- `lib/features/profile/` and `lib/features/settings/`
  - profile shell, notifications, privacy, and account settings

Lean Flutter data path:

```text
UI screens/widgets
  -> Riverpod providers
  -> feature gateways / PredictionService
  -> Supabase views + tables

Home / Fixtures
  -> MatchListingGateway
  -> app_matches

Competitions / Standings
  -> CompetitionCatalogGateway
  -> app_competitions_ranked + competition_standings

Predict
  -> PredictionHubGateway / PredictionService
  -> app_matches + predictions_engine_outputs + team_form_features + user_predictions

Leaderboard
  -> LeaderboardGateway
  -> public_leaderboard

Wallet / Rewards
  -> WalletGateway / WalletService
  -> fet_wallets + fet_wallet_transactions + token_rewards
```

Removed Flutter legacy domains:

- fan identity
- memberships and community support/news
- social feed
- pools, jackpot, and prediction-slip betting abstractions
- seasonal contests and community leaderboard variants

## Admin Architecture

Primary admin flows:

- fixture browsing and result entry
- prediction monitoring
- lean import oversight
- runtime feature and bootstrap oversight

The admin app no longer treats pool settlement as a core operation. Fixture result entry now drives scoring of saved user picks.

Runtime settings surface:

- feature flags are read from `admin_feature_flags` and written to `feature_flags`
- `app_config_remote`, `launch_moments`, `country_region_map`, `country_currency_map`, `phone_presets`, and `currency_display_metadata` are editable from the settings surface and feed the Flutter bootstrap contract directly
- Flutter routing refreshes when runtime bootstrap changes, so DB-driven feature state is no longer trapped behind startup-only route guards
- bootstrap supporting tables stay in Supabase as the source of truth for app config, launch moments, phone presets, currency formatting, and region/currency mapping

## Non-Goals

- paid sports data warehouses
- advanced market engines
- betting or trading abstractions
- lineup, injury, event, or player-level analysis pipelines
