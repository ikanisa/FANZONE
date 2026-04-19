# FANZONE UI/UX Realignment Implementation Plan

Date: 2026-04-18

Related report:
- [ui-ux-gap-analysis-vs-original-reference-2026-04-18.md](/Volumes/PRO-G40/FANZONE/docs/ui-ux-gap-analysis-vs-original-reference-2026-04-18.md)

## Goal

Realign the current Flutter app with the original FANZONE product model:

- prediction-first
- pools and challenges first-class
- fan club and supporter community first-class
- Fan ID / fan registry visible and usable
- FET wallet-native
- live scores and stats demoted to supporting information

This plan assumes the current codebase remains Flutter and that existing backend/service work is reused rather than replaced.

## Target Product Hierarchy

The product should communicate this order of importance:

1. Predict and pool
2. Fan clubs, memberships, and supporter communities
3. Fan ID and identity
4. FET wallet and rewards
5. Match information and live scores

## Target Navigation Model

Recommended primary mobile tabs:

1. `Home`
2. `Predict`
3. `Clubs`
4. `Wallet`
5. `Profile`

Supporting destinations, not primary tabs:

- `Scores`
- `Fixtures`
- `Leaderboard`
- `Rewards`
- `Notifications`
- `Settings`

Reasoning:
- this is the smallest change that restores the original product truth
- it keeps wallet first-class
- it creates a first-class home for membership and community
- it demotes score browsing without removing it

## Delivery Strategy

Implement in four phases. Phase 1 and 2 are mandatory before any visual polish pass. The current problem is information architecture, not theme fidelity.

## Phase 1: Shell and Information Architecture Reset

Objective:
- make the app feel like a prediction/community product before adding missing screens

Primary changes:
- replace the current bottom nav labels and branch order
- stop using `Scores` as the root product label
- move score-heavy browsing into secondary destinations
- make wallet a primary destination instead of a profile child
- create a first-class `Clubs` branch for memberships/community

Target files:
- [lib/app_router.dart](/Volumes/PRO-G40/FANZONE/lib/app_router.dart)
- [lib/widgets/navigation/app_shell.dart](/Volumes/PRO-G40/FANZONE/lib/widgets/navigation/app_shell.dart)
- [lib/features/profile/screens/profile_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/profile/screens/profile_screen.dart)

Implementation steps:
- rename the `/` branch from score-led home to a hub-led home
- convert `/fixtures` and `/following` from primary shell branches into subroutes reachable from home or clubs
- promote wallet from `/profile/wallet` to `/wallet`
- add a new `/clubs` branch
- keep old routes temporarily with redirects to avoid breaking deep links

Acceptance criteria:
- bottom nav no longer says `Scores | Fixtures | Following | Predict | Profile`
- a new user can understand prediction, clubs, wallet, and identity from the shell alone
- scores can still be accessed, but do not define the app

## Phase 2: Core Prediction Flow Realignment

Objective:
- restore prediction and pools as the dominant matchday action

Primary changes:
- rebuild home as a matchday hub instead of a live-score console
- make prediction the default action on match detail
- remove semantic conflict between free prediction and stake-required pool flows

Target files:
- [lib/features/home/screens/home_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/home/screens/home_screen.dart)
- [lib/features/home/screens/match_detail_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/home/screens/match_detail_screen.dart)
- [lib/features/predict/screens/predict_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/predict/screens/predict_screen.dart)
- [lib/widgets/predict/prediction_slip_dock.dart](/Volumes/PRO-G40/FANZONE/lib/widgets/predict/prediction_slip_dock.dart)
- [lib/services/prediction_slip_service.dart](/Volumes/PRO-G40/FANZONE/lib/services/prediction_slip_service.dart)
- [lib/features/pools/screens/pool_detail_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/pools/screens/pool_detail_screen.dart)

Implementation steps:
- rework home header from `SCORES` to a matchday hub message centered on picks, pools, challenges, and FET
- place upcoming prediction opportunities above live-result browsing
- reorder match detail tabs so `Predict` is first and default
- split prediction flows into:
  - free prediction slip
  - pool stake flow
- do not require stake for free prediction submission
- reserve stake input for pool/jackpot/community contest contexts only

Acceptance criteria:
- first screen impression is about predicting, joining, and earning
- match detail opens with prediction as the primary tab
- users can make a free prediction without entering a stake
- pool flows still support FET stakes where intended

## Phase 3: Clubs, Membership, Social, and Fan ID

Objective:
- restore the club/community/identity layer that was central in the original reference

Primary changes:
- add a dedicated clubs hub
- add a dedicated Fan ID screen
- add a dedicated social/fan zone surface
- integrate existing team community services into first-class UX

Target files to create or expand:
- `lib/features/community/screens/clubs_hub_screen.dart`
- `lib/features/community/screens/membership_hub_screen.dart`
- `lib/features/social/screens/social_hub_screen.dart`
- `lib/features/identity/screens/fan_id_screen.dart`
- [lib/features/teams/screens/team_profile_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/teams/screens/team_profile_screen.dart)
- [lib/providers/fan_identity_provider.dart](/Volumes/PRO-G40/FANZONE/lib/providers/fan_identity_provider.dart)
- [lib/services/team_community_service.dart](/Volumes/PRO-G40/FANZONE/lib/services/team_community_service.dart)

Implementation steps:
- build `Clubs` as the umbrella destination for:
  - my clubs
  - team communities
  - supporter registry
  - club leaderboard
  - membership card and tier
- add a first-class Fan ID screen with:
  - Fan ID visibility
  - supporter registry explanation
  - privacy and anonymity explanation
  - copy/share/receive flows
- build social hub around:
  - friends
  - club fan zone
  - challenge invites
  - community chat and rankings
- refactor team profile so community and support are framed as fan-club participation, not just generic team browsing

Acceptance criteria:
- a user can discover clubs, membership, social, and Fan ID without drilling through profile utility links
- Fan ID has a dedicated screen, not only a profile pill
- team community feels like a product pillar rather than a hidden add-on

## Phase 4: Wallet, Rewards, and Product Consistency

Objective:
- make wallet experience match the original FANZONE economy model

Primary changes:
- restore wallet framing around supporter economy, not only account balance
- connect wallet more clearly to clubs, rewards, and Fan ID transfers
- finish consistency pass across onboarding, profile, and rewards

Target files:
- [lib/features/wallet/screens/wallet_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/wallet/screens/wallet_screen.dart)
- [lib/features/rewards/screens/rewards_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/rewards/screens/rewards_screen.dart)
- [lib/features/onboarding/screens/onboarding_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/onboarding/screens/onboarding_screen.dart)
- [lib/features/profile/screens/profile_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/profile/screens/profile_screen.dart)
- [lib/config/app_config.dart](/Volumes/PRO-G40/FANZONE/lib/config/app_config.dart)
- [env/production.example.json](/Volumes/PRO-G40/FANZONE/env/production.example.json)

Implementation steps:
- update wallet hero and education blocks to explain:
  - personal balance
  - club contribution/support
  - Fan ID transfers
  - rewards and redemption
- connect rewards and marketplace language back to fan participation
- update onboarding so product story is prediction, clubs, identity, wallet first
- review feature flags so production defaults do not suppress membership while enabling adjacent surfaces

Acceptance criteria:
- wallet reads as a FANZONE economy product, not a generic balance page
- onboarding and profile tell the same product story as the home screen
- production feature flags reflect intended product priorities

## Recommended Route Map

Primary routes:

- `/`
- `/predict`
- `/clubs`
- `/wallet`
- `/profile`

Secondary routes:

- `/scores`
- `/scores/match/:matchId`
- `/scores/league/:leagueId`
- `/scores/team/:teamId`
- `/fixtures`
- `/clubs/fan-id`
- `/clubs/social`
- `/clubs/membership`
- `/leaderboard`
- `/rewards`

Migration note:
- keep compatibility redirects from old routes during rollout
- remove deprecated routes only after analytics confirm safe migration

## Module Ownership

Workstream A: IA and routing
- `lib/app_router.dart`
- `lib/widgets/navigation/app_shell.dart`

Workstream B: home and prediction
- `lib/features/home`
- `lib/features/predict`
- `lib/features/pools`
- `lib/widgets/predict`

Workstream C: clubs and identity
- `lib/features/community`
- `lib/features/social`
- `lib/features/identity`
- `lib/features/teams`

Workstream D: wallet and consistency
- `lib/features/wallet`
- `lib/features/rewards`
- `lib/features/profile`
- `lib/features/onboarding`

## Implementation Order

Recommended execution sequence:

1. Phase 1 shell and route reset
2. Phase 2 prediction flow correction
3. Phase 3 clubs and Fan ID buildout
4. Phase 4 wallet and messaging consistency
5. full visual QA against original reference

Do not start with cosmetic polish. The current primary defect is structural.

## Rollout Risks

Risk:
- moving tab structure can break deep links and user muscle memory

Mitigation:
- preserve route redirects
- keep analytics on branch usage before and after rollout

Risk:
- free prediction and stake-based pools may currently share too much logic

Mitigation:
- split domain model intentionally instead of patching UI copy only

Risk:
- membership and social features may be partially implemented in backend only

Mitigation:
- start with read-focused hubs and progressive enhancement
- expose existing data first, then add authoring and richer interactions

## Definition of Done

The realignment is complete when all of the following are true:

- the shell communicates prediction, clubs, wallet, and identity before scores
- home is a matchday hub, not a scoreboard
- match detail defaults to prediction
- Fan ID has a dedicated first-class experience
- clubs and membership have a first-class destination
- wallet clearly reflects FET, clubs, and rewards together
- live score remains available, but is no longer the product identity

## Recommended First Build Slice

If implementation starts immediately, the best first slice is:

1. change bottom nav and routing
2. rebuild home header and section order
3. move `Predict` to the first match-detail tab
4. split free prediction from stake-based pool submission
5. promote wallet to a primary route

That slice will correct the product signal fastest, even before the full clubs/social/Fan ID surfaces are complete.
