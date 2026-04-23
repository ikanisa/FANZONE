# Lean Prediction Audit Report

Date: 2026-04-22
Scope: Flutter app, admin app, Supabase schema, migrations, SQL verification, Edge Functions, and repo documentation.

## Executive Summary

The repo had grown around several overlapping prediction concepts:

- prediction pools
- slips
- daily challenges
- jackpot / global challenges
- odds-driven market tables
- advanced match satellites for events, AI analysis, and live state

Those structures created duplicated ownership across Flutter, Supabase, and admin surfaces. The backend schema was broader than the actual product need for a free football prediction app.

The refactor replaced that model with a single lean contract based on:

- competitions
- seasons
- teams
- team aliases
- matches
- standings
- derived form features
- prediction engine outputs
- user predictions
- token rewards

## Primary Problems Found

### Obsolete domain complexity

- bookmaker-style market catalogs and settlement logic remained in the schema
- pool, slip, and daily-challenge structures duplicated prediction participation
- advanced sports satellites existed without being necessary to the free-picks product

### App/backend mismatch

- Flutter still referenced retired tables and route concepts
- admin pages mixed fixture operations with pool settlement workflows
- docs still described pools, jackpots, odds, and Gemini ingestion as live paths

### Operational complexity

- scheduled jobs were tied to legacy settlement flows
- import assumptions leaned on older data sources instead of manual CSV ingestion
- test coverage still asserted legacy pool UI and slip flows

## What Was Removed

Backend removals:

- legacy prediction challenge and slip tables
- daily challenge tables
- outright and market catalog tables
- odds caches and screenshot extraction paths
- advanced match stats, player stats, events, AI analysis, and live-state satellites
- pool settlement and market settlement RPCs
- old scheduled jobs for auto-settle and global pool creation

App removals or deactivation:

- pool creation and join as live product flows
- jackpot route as a live destination
- prediction slip dock as an active widget path
- old match-detail tabs coupled to odds, events, and advanced stats

## What Was Preserved

- authentication and WhatsApp OTP flow
- wallet and reward surfaces
- leaderboards and fan/community surfaces where still compatible
- admin auth and role-gated control plane
- push notification infrastructure

## Duplication Map

Old duplication:

- user participation represented by pool entries, slip selections, daily entries, and outright entries
- match prediction presentation split across pool UI, slip UI, match detail tabs, and admin challenge screens
- multiple ingestion and settlement paths for essentially the same prediction outcome

New single-source ownership:

- match result truth lives in `matches`
- team historical position truth lives in `standings`
- derived recent-form truth lives in `team_form_features`
- engine output truth lives in `predictions_engine_outputs`
- user participation truth lives in `user_predictions`
- reward issuance truth lives in `token_rewards`

## Migration Plan Executed

1. Audit legacy tables, functions, views, routes, services, tests, and docs.
2. Build a lean schema migration that drops obsolete prediction structures and normalizes core football tables.
3. Add lean RPCs for import, feature generation, prediction generation, result scoring, and reward issuance.
4. Replace or rewrite Edge Functions around the lean contract.
5. Refactor Flutter prediction flows to `/predict` and match-detail based entry.
6. Refactor admin fixtures and predictions pages around fixtures, engine outputs, and user picks.
7. Update tests, docs, CI references, and cron jobs.

## Remaining Risk Notes

- Some historical docs and compatibility shims remain in the repo for context or non-live paths.
- Old pool-oriented models and services still exist in limited compatibility areas and should continue to be trimmed when no longer needed by tests or archived flows.
- Manual CSV ingestion still depends on operator discipline for source quality and alias resolution; import validation is intentionally lean, not warehouse-grade.

## Final Assessment

The live product contract is now lean, coherent, and maintainable. The main remaining work is continued archival cleanup of residual pre-refactor artifacts that no longer sit on the critical path.
