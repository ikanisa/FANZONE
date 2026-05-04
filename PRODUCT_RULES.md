# FANZONE Product Rules

This repo implements a sports-bar platform for venue browsing, dine-in ordering,
external payment guidance, manual payment confirmation, FET rewards, prediction
pools, centralized venue games, team play, venue operations, and TV display.

## Authentication

- Login is WhatsApp Cloud API OTP.
- Users do not need a name, email, username, first name, or last name.
- Every profile must have one immutable unique 6-digit `fan_id`.
- Existing valid `fan_id` values are preserved on profile updates.

## Ordering And Payments

- Orders are venue-linked and table-linked.
- Payment APIs are not part of MVP.
- Rwanda uses MoMo USSD/payment instructions.
- Malta/Europe uses Revolut link/payment instructions.
- Venue staff manually confirms paid orders.
- `payment_status` and service/order `status` remain separate.
- Manual paid confirmation must be auditable.

## FET

- Wallet balances must only change through ledger-backed RPCs/functions.
- No balance mutation is allowed without a ledger transaction row.
- Balances and FET amounts must never go negative.
- Cash-out is not supported.
- User transfers require authenticated users and 6-digit Fan IDs.

## Prediction Pools

- Prediction pools are always staked and venue-linked.
- User-created pools must select a venue.
- Venue-created pools use the venue FET wallet for the bar stake.
- Creator and participant stakes are required.
- Options remain home win, draw, away win.
- Settlement pays eligible winners only; ineligible logical winners stay visible
  but unpaid.

## Games And Teams

- Game templates are centralized platform templates.
- Venues choose from approved templates; venues do not create custom game logic.
- Supported MVP games include Bar Trivia, Fan Trivia, Music Bingo, and Song Guess.
- Game sessions are linked to exactly one venue.
- Teams are created/joined inside a game session.
- Minimum two teams are required before competitive settlement.
- Highest FET score wins.
- No speed bonus, fastest-answer bonus, or cross-bar/city/country competition.

## Question Logic

- Question games select exactly 20 active approved questions at session creation.
- Selected questions are persisted in `game_session_questions`.
- Questions are not randomly selected live during each round.
- A session cannot contain duplicate selected questions.
- Each team gets one answer per question.
- Only the first correct team earns FET for a question.
- Race protection must live in the database/backend, not only in UI code.

## Eligibility

- Users may join pools, games, and teams before ordering.
- FET settlement payout requires at least one qualifying paid order from the
  linked venue within two hours before the scheduled pool/game start.
- Joining and logical winning are allowed without an order.
- Settlement pays only eligible winners.

## Discovery

- Global views are discovery surfaces only.
- Pools, games, and teams may be filtered globally, by country, or by bar.
- Every activity remains linked to a specific venue.
