# Production UAT Report

Status: Release package and automated checks are complete. Final live multi-device UAT is still required before public launch.

## Automated Checks Completed

- `supabase db push --dry-run`
- `supabase db reset`
- full `supabase/tests/*.sql` verification suite
- `dart format --output=none --set-exit-if-changed lib test tool`
- `flutter analyze`
- `flutter test`
- Android production preflight
- Android release APK build
- Android release AAB build
- unsigned iOS release archive
- Apple Team ID `63STJ5N27W` configured locally for iOS signing
- web release env validation for website, admin, venue dashboard, and TV display
- website, admin, venue dashboard, and TV display production builds
- Cloudflare Pages deploys for all four web surfaces
- HTTP 200 smoke checks for deployed web roots and public privacy route

## Required Devices

- Android release build.
- iOS release archive. TestFlight IPA requires Apple account access plus a provisioning profile/certificate for `com.fanzone.fanzone`.
- Venue dashboard browser.
- TV display browser or HDMI-connected device.
- Supabase production-like project.

## User Flow

- [ ] WhatsApp OTP login.
- [ ] 6-digit FANZONE ID generated.
- [ ] Fan profile setup.
- [ ] Browse venues.
- [ ] View menu.
- [ ] Place order.
- [ ] View MoMo/Revolut/external payment instructions.
- [ ] Venue marks paid.
- [ ] User earns order FET through ledgered transaction.
- [ ] User joins prediction pool.
- [ ] User joins game.
- [ ] User creates or joins team.
- [ ] User sees eligibility state.
- [ ] Eligible winner receives settlement.
- [ ] Ineligible winner is shown but not paid.

## Venue Flow

- [ ] Venue staff login with WhatsApp OTP.
- [ ] Venue context resolves to assigned venue only.
- [ ] Manage menu item.
- [ ] Receive order.
- [ ] Mark order paid with audit note.
- [ ] Create staked prediction pool.
- [ ] Start centralized game.
- [ ] View teams and players.
- [ ] Control TV screen.
- [ ] Settle pool/game.
- [ ] Verify wallet ledger.

## TV Flow

- [ ] Open screen URL.
- [ ] Pair or open venue route.
- [ ] Show welcome.
- [ ] Show QR.
- [ ] Show active pool.
- [ ] Show game question.
- [ ] Show leaderboard.
- [ ] Show winner.
- [ ] Reconnect after refresh/network interruption.

## Backend Flow

- [ ] Wallet reconciliation.
- [ ] Ledger reconciliation.
- [ ] Eligibility window.
- [ ] 20-question sampling.
- [ ] First-correct-team race protection.
- [ ] Duplicate settlement prevention.
- [ ] RLS venue isolation.
- [ ] Realtime propagation.
