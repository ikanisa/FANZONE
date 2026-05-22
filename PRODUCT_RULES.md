# FANZONE Product Rules

This repo implements a sports-bar platform for venue browsing, dine-in ordering,
external payment guidance, manual payment confirmation, FET rewards, prediction
challenges, centralized venue games, team play, venue operations, and TV display.

This is not a betting, gambling, cash-out, odds, pooled-wager, or fintech-wallet
product. Entertainment mechanics are venue-engagement mechanics: free-to-play,
loyalty-points based, leaderboard based, coupon based, or reward based.

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

## FET Loyalty Points

- FET is a non-cash loyalty and rewards points ledger.
- FET is not a fiat balance, stored-value account, e-money account, or customer
  fintech wallet.
- Ledger balances must only change through ledger-backed RPCs/functions.
- No balance mutation is allowed without a ledger transaction row.
- Balances and FET amounts must never go negative.
- Cash-out, cash prizes, redemption for cash, and odds-based payouts are not
  supported.
- Any transfer-like behavior must remain authenticated, venue-safe, non-cash,
  and explicitly feature-gated.

## Prediction Challenges

- Prediction challenges are venue-linked engagement features, not paid betting
  markets.
- User-created challenges must select a venue.
- Venue-created challenges may allocate non-cash FET loyalty points from the
  venue rewards ledger.
- Customer participation must not require fiat payment, odds, cash-out, or cash
  prize eligibility.
- Existing pool/stake database terms are legacy implementation names. New
  customer-facing copy should use challenge, points entry, leaderboard, reward,
  coupon, or loyalty terminology.
- Options remain home win, draw, away win.
- Settlement credits eligible winners with non-cash loyalty points or unlocks
  venue rewards only; ineligible logical winners stay visible but uncredited.

## Games And Teams

- Game templates are centralized platform templates.
- Venues choose from approved templates; venues do not create custom game logic.
- Supported MVP games include Bar Trivia, Fan Trivia, Music Bingo, and Song Guess.
- Game sessions are linked to exactly one venue.
- Teams are created/joined inside a game session.
- Minimum two teams are required before competitive settlement.
- Highest FET loyalty score wins.
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

- Users may join challenges, games, and teams before ordering.
- FET loyalty settlement requires at least one qualifying paid order from the
  linked venue within two hours before the scheduled pool/game start.
- Joining and logical winning are allowed without an order.
- Settlement credits only eligible winners with non-cash loyalty points or venue
  rewards.

## Discovery

- Global views are discovery surfaces only.
- Challenges, games, and teams may be filtered globally, by country, or by bar.
- Every activity remains linked to a specific venue.
