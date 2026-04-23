# Lean Prediction Engine

## Purpose

Generate simple, explainable football prediction outputs from historical match data and recent form.

## Outputs

- home win score
- draw score
- away win score
- over 2.5 score
- BTTS score
- optional predicted scoreline
- confidence label

## Input Signals

- last five match points
- last five wins / draws / losses
- goals scored and conceded trend
- clean sheets
- failed-to-score count
- home form split
- away form split
- recent over 2.5 frequency
- recent BTTS frequency
- standings position and points context when available

## Design Principles

- simple over complex
- deterministic and explainable
- cheap to recompute
- no paid-data dependency
- no ML platform requirement

## Current Pipeline

1. Import match and standings history.
2. Build `team_form_features` for the relevant upcoming match.
3. Score home, draw, away from recent form balance and context.
4. Score over 2.5 and BTTS from recent goal patterns.
5. Estimate an optional scoreline from goal tendencies.
6. Persist a single row in `predictions_engine_outputs`.

## Confidence Labels

Confidence is intentionally coarse:

- `low`
- `medium`
- `high`

It is not a promise of accuracy. It is a presentation aid for the app.

## Evolution Path

If the product later needs more depth, evolve from inside the same contract:

- broaden the window to last 10 matches where useful
- add lightweight head-to-head only if it improves signal
- weight competition-specific form differently
- add offline model experiments without changing the app contract

Do not evolve toward an odds engine or a bookmaker-style market framework.
