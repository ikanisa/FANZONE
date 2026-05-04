# QA Checklist

Run these checks before release candidates.

## Flutter

- `dart format lib test`
- `flutter analyze`
- `flutter test`
- Smoke test WhatsApp OTP login, onboarding, venue browsing, menu, checkout,
  payment handoff, order tracking, pools, wallet, and profile.
- Verify typography uses centralized design-system tokens on touched screens.

## Venue Portal And TV Display

- `npm run typecheck --workspaces --if-present`
- `npm run lint --workspaces --if-present`
- `npm run build --workspaces --if-present`
- Verify venue staff cannot view another venue's orders, wallet, pools, games,
  teams, or screen state.
- Verify TV display is venue-linked, QR is readable, and realtime updates cleanly.

## Supabase

- Run SQL contract tests in `supabase/tests`.
- Run Deno function tests with required permissions, for example:
  `deno test --allow-env --config deno.json supabase/functions/_shared/*.ts supabase/functions/whatsapp-otp/index_test.ts`
- Confirm RLS is enabled on wallet, order, pool, game, team, and screen tables.
- Confirm release migrations include wallet transfer grant hardening.

## Critical Product Flows

- WhatsApp OTP does not require user names.
- New users receive unique immutable 6-digit Fan IDs.
- MoMo/Revolut payment guidance does not call payment provider APIs.
- Manual mark-paid updates `payment_status` only and writes audit/payment events.
- FET spend, transfer, stake, reward, and payout create ledger rows.
- Pool settlement pays only eligible winners.
- Game sessions persist exactly 20 approved questions.
- First correct answer is race-safe and only one team receives the question reward.
