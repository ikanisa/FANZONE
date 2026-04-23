# Lean Prediction Cleanup Report

## Major Removals

Supabase:

- pool, slip, daily-challenge, outright, and market tables
- odds ingestion and screenshot extraction functions
- advanced stats, events, player stats, AI analysis, and live-state tables
- old settlement and auto-settle jobs

Flutter:

- live routing to pool and jackpot flows
- legacy match-detail tabs tied to removed data
- prediction slip dock as an active app widget
- pool creation as a live destination

Admin:

- challenge-oriented admin page
- pool-settlement framing in fixture operations
- older challenge metrics on the primary predictions page

Tests:

- stale pool/slip widget assertions
- pool-settlement integration test replaced with lean prediction-domain coverage

## Consolidations

- prediction entry now uses one service path
- result scoring now follows match completion rather than pool settlement
- import, feature generation, prediction generation, and scoring are separated into clear backend jobs

## Residual Legacy Areas

- historical git history and archived context docs still describe pre-refactor structures
- non-Flutter surfaces outside the mobile runtime may still need their own final verification pass

The Flutter runtime path is now aligned to the lean prediction contract and no longer depends on the removed football pool/challenge/community layers.
