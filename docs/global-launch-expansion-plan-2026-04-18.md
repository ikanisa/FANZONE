# FANZONE Global Launch Expansion Plan

## Strategic Reset
FANZONE is now positioned as a global football prediction and fan-community product rather than a Malta-first launch. The product needs one architecture that serves Africa, Europe, and North America without splitting the app into regional forks.

This implementation keeps the current prediction-first shell, clubs/membership/Fan ID/wallet model, and existing Supabase-backed content plane. The upgrade is additive:

- explicit market preference state instead of Malta-biased inference only
- region-aware home, discovery, and onboarding
- event-driven momentum around the 2026 football cycle
- reusable launch/event metadata for product and admin operations
- no rewrite of routes, core services, wallet, or prediction flows

## Live Football Calendar Anchors
- FIFA World Cup 26 opening match: **11 June 2026** in Mexico City, with the final on **19 July 2026** in New York New Jersey. Source: FIFA match schedule and tournament guide
  - https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026/articles/fifa-world-cup-26-match-schedule-revealed
  - https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026/articles/fifa-world-cup-2026-hosts-cities-dates-usa-mexico-canada
- UEFA Champions League Final 2026: **30 May 2026** at Puskás Aréna, Budapest. Source: UEFA
  - https://www.uefa.com/uefachampionsleague/news/029a-1df98e9a78ca-1acaca3c53b0-1000--2026-uefa-champions-league-final-puskas-arena/

These dates materially change the product hierarchy. The app must work in the run-in period before those dates, not only during the competitions themselves.

## Implemented Additive Upgrades
### Backend and data plane
- Added `public.user_market_preferences` with user-owned RLS for:
  - `primary_region`
  - `selected_regions`
  - `focus_event_tags`
  - `favorite_competition_ids`
  - World Cup / Champions League follow flags
- Extended `featured_events` and `global_challenges` with:
  - `priority_score`
  - `audience_regions`
  - CTA metadata on featured events
  - `slug` on global challenges for stable seeded upserts
- Extended admin-facing content tables with launch metadata:
  - `content_banners.audience_regions`, `event_tag`, `priority_score`
  - `campaigns.audience_regions`, `event_tag`
  - `partners.audience_regions`
  - `rewards.audience_regions`
- Seeded additive event momentum rows for:
  - `road-to-world-cup-2026`
  - `worldcup2026`
  - `ucl-final-2026`
  - `africa-fan-momentum-2026`
  - `north-america-host-cities-2026`
- Seeded additive open global challenges for the same launch cycle.

Migration:
- [20260418203000_global_launch_market_preferences_and_event_momentum.sql](/Volumes/PRO-G40/FANZONE/supabase/migrations/20260418203000_global_launch_market_preferences_and_event_momentum.sql)

### User preference and personalization layer
- Added a typed market-preference model and persistence service:
  - [user_market_preferences_model.dart](/Volumes/PRO-G40/FANZONE/lib/models/user_market_preferences_model.dart)
  - [market_preferences_service.dart](/Volumes/PRO-G40/FANZONE/lib/services/market_preferences_service.dart)
  - [market_preferences_provider.dart](/Volumes/PRO-G40/FANZONE/lib/providers/market_preferences_provider.dart)
- Region resolution now prefers explicit market preference and only falls back to inferred favorite-team geography.
- North America is now treated as its own market target instead of generic “Americas”.

### Onboarding
- Expanded onboarding from 5 steps to 7 steps:
  - welcome
  - product loop
  - FET utility
  - market focus
  - event focus
  - home club
  - global clubs
- Replaced Europe-only “popular teams” framing with region-aware global club selection.
- On completion, onboarding now saves both team preferences and market/event preferences.

Files:
- [onboarding_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/onboarding/screens/onboarding_screen.dart)
- [onboarding_provider.dart](/Volumes/PRO-G40/FANZONE/lib/features/onboarding/providers/onboarding_provider.dart)

### Home, predict, clubs, discovery, wallet
- Home now includes:
  - a launch strategy summary
  - region-aware momentum prioritisation
  - seeded global challenge surfacing above standard pool cards
- Predict now includes a 2026 momentum block above its existing tabs.
- Clubs now reflects global supporter momentum in the hub framing.
- Discovery now supports:
  - `For You`
  - `Global`
  - `Africa`
  - `Europe`
  - `North America`
- Wallet now frames FET as cross-market infrastructure for prediction, club support, Fan ID transfers, and region-aware redemption utility.

Files:
- [matchday_hub_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/home/screens/matchday_hub_screen.dart)
- [predict_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/predict/screens/predict_screen.dart)
- [clubs_hub_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/community/screens/clubs_hub_screen.dart)
- [teams_discovery_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/teams/screens/teams_discovery_screen.dart)
- [wallet_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/wallet/screens/wallet_screen.dart)

### Settings and control
- Added a dedicated Market Preferences screen so the launch behavior is editable after onboarding.
- Added production feature flags for:
  - featured events
  - global challenges
  - region discovery

Files:
- [market_preferences_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/settings/screens/market_preferences_screen.dart)
- [settings_screen.dart](/Volumes/PRO-G40/FANZONE/lib/features/settings/screens/settings_screen.dart)
- [app_router.dart](/Volumes/PRO-G40/FANZONE/lib/app_router.dart)
- [env/production.json](/Volumes/PRO-G40/FANZONE/env/production.json)

## Product Implications
### Competition hierarchy
- Prediction remains the primary product verb.
- Event windows now sit above ordinary fixture chronology when the football calendar justifies it.
- Scores remain available, but they no longer define the launch story.

### Regional relevance without fragmentation
- One app shell remains in place.
- User-selected market focus changes ranking and entry points only.
- Global and local moments can coexist in the same home feed.

### Commercial readiness
- World Cup lead-up is treated as a habit-building and user-acquisition phase.
- UEFA Champions League final is treated as a Europe-heavy conversion spike.
- Africa and North America get dedicated community and challenge visibility rather than being inferred indirectly from club search alone.

### Admin and operations
- Admin-managed banner, campaign, reward, and partner records can now be targeted by region and event.
- Event and challenge seeding now supports a repeatable launch-ops workflow for future tournaments without changing the app architecture again.

## Remaining Follow-Through
- Apply the new migration to the target Supabase project.
- Seed or update competition records with real `competition_id` links where desired.
- Add admin UI support for the new regional/event metadata fields if the internal tooling needs editing surfaces for them.
- Run device-level visual QA on small mobile screens against the new onboarding and market-preference flows.
