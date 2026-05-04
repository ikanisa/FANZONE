# Production UAT Report

Status: Automated release checks and Pixel 4a authenticated UAT are mostly complete. Final live multi-device UAT, iOS signing/TestFlight, TV custom-domain DNS, and store-console submissions are still required before public launch.

## Automated Checks Completed

- `supabase db push`
- `supabase db push --dry-run`
- `supabase db push` for `20260504153000_seed_mobile_runtime_bootstrap.sql`
- `supabase db push --dry-run` after UAT, confirming the remote database is up to date
- Remote SQL contract checks: `release_readiness_hardening.sql` and `whatsapp_auth_verification.sql`
- `tool/supabase_release_probe.sh`
- `tool/supabase_rls_audit.sh`
- `tool/supabase_fet_supply_smoke.sh`
- `tool/supabase_whatsapp_auth_smoke.sh`
- `supabase functions deploy whatsapp-otp --use-api`
- `supabase secrets set` for the production-isolated WhatsApp UAT test phone/OTP path
- `supabase functions list`
- Deno format, type-check, and Edge Function unit tests
- `dart format --output=none --set-exit-if-changed lib test tool`
- `flutter analyze`
- `flutter test`
- Android production preflight
- Android release APK build
- Android production-env release APK build via `tool/build_android_release_from_env.sh production`
- Android release AAB build
- Android AAB signature verification
- Play Store listing metadata text and image dimension validation
- Google Play validate-only upload attempted; Play API deleted the edit after bundle preparation
- Google Play internal testing draft upload completed after bumping to version `1.1.3+11`
- Google Play build `11` changelog synced to the internal testing draft
- iOS release archive attempted and blocked by missing local Apple account/provisioning profile for `com.fanzone.fanzone`
- web release env validation for website, admin, venue dashboard, and TV display
- website, admin, venue dashboard, and TV display production builds
- Cloudflare Pages deploys for all four web surfaces
- HTTP 200 smoke checks for all four deployed web roots and `https://fanzone.ikanisa.com`

## 2026-05-04 Pixel 4a Device QA/UAT Pass

- Device: Pixel 4a (`sunfish`), Android 13, adb serial `13111JEC215558`.
- Installed app: `app.fanzone.football`, initially tested on version `1.1.2` versionCode `10`; final reinstall/smoke completed on update version `1.1.3` versionCode `11`, targetSdk `35`.
- Launch result: release build cold-launched successfully; no app crash or Dart exception observed in filtered logcat.
- First-run UI: welcome screen renders and fits on Pixel 4a.
- WhatsApp login UI before fix: production bootstrap returned zero `phone_presets`, so onboarding showed a generic `+` prefix. OTP send could advance to verification using `+99711145`, but reviewer OTP `123456` was rejected.
- Fix applied: added and pushed `20260504153000_seed_mobile_runtime_bootstrap.sql`, seeding `MT`, `RW`, `GB`, and `US` country/phone/currency bootstrap data plus `default_phone_country_code=MT`.
- WhatsApp login UI after fix: fresh app state now shows `+356`, formats Malta number `99711145` as `9971 1145`, and enables `SEND OTP TO WHATSAPP`.
- Test account setup: WhatsApp test phone `+35699711145` verifies with the production-isolated UAT OTP path. The test secret expiry is `2026-06-30T23:59:59Z`.
- Authenticated mobile UAT status: passed login using the UAT phone/OTP, notification permission prompt, optional fan profile skip, home load, wallet load, venue browse, menu browse, table QR checkout, Arena pool browse, Arena Entries browse, and pool stake.
- Test user: generated 6-digit fan ID `526626`; no name, email, username, first name, or last name was required.
- Wallet initial state: welcome credit created a ledgered 50 FET balance.
- Wallet after pool stake: app and database show 25 FET available, 25 FET staked, 0 pending, one active pool entry, and three wallet ledger rows.
- Update APK smoke: a plain `flutter build apk --release` without production dart-defines produced a misconfigured build, so the device was reinstalled with `tool/build_android_release_from_env.sh production`; the corrected `1.1.3+11` build shows `+356`, authenticates the UAT account, and lands on the expected 25 FET available home state.
- Venue browse: `UAT Live Sports Bar` renders as open with FET rewards and an order CTA.
- Menu/checkout: `UAT Zero Beer` can be added to cart, checkout shows Cash/Revolut external payment options, and authenticated table QR order placement succeeds.
- Order placement UAT: after fixing table public-code resolution and custom WhatsApp JWT auth handling in `order_create`, the Pixel placed `Order #FZ-Y7CX-QCM1` for `€4.50`; status shows Cash / Unpaid and FET reward pending venue confirmation.
- Pool UAT data refresh: the seeded UAT match was stale (`2026-05-03`), so the linked UAT match timestamp was moved to `2026-05-06` to permit the live join-path test.
- Pool stake: the test user joined the Draw camp for 25 FET; pool totals updated from 2 members/50 FET to 3 members/75 FET.
- Pool detail issue fixed in source: pool summaries now annotate authenticated entries via the runtime WhatsApp session and the Entries filter is no longer hardcoded empty.
- Arena Entries smoke: the Arena screen shows the UAT venue-linked pool with the existing active entry context after tapping Entries.
- Table QR/deep-link issue fixed: Android manifest/router now handle `https://fanzone.app/v/:slug/table/:table`, `https://fanzone.ikanisa.com/v/:slug/table/:table`, legacy `/venues/:slug/table/:table`, and custom-scheme venue/table links.
- Edge Function fix: `order_create` now accepts nullable notes from installed clients, resolves table public codes/QR URLs server-side, and accepts signed FANZONE WhatsApp JWT claims for custom authenticated sessions.
- App Links: package verifier reports `fanzone.ikanisa.com: verified`, but this device shows the domain under user selection state `Disabled`; verify Android App Link behavior on a clean reviewer/internal-test device.
- Device network: Wi-Fi validated and usable during test.
- Screenshots captured locally under `/tmp`: `fanzone_after_seed_start.png`, `fanzone_malta_phone_entered.png`, `fanzone_home_after_login.png`, `fanzone_order_menu_current.png`, `fanzone_order_scrolled.png`, `fanzone_pool_detail_after_stake.png`, `fanzone_wallet_after_pool_stake.png`, `fanzone_113_home_after_login.png`.

## Generated Artifacts

- Android APK: `build/app/outputs/flutter-apk/app-release.apk`
- Android AAB: `build/app/outputs/bundle/release/app-release.aab`
- Android release version: `1.1.3+11`
- Android AAB SHA-256: `0788a27fc5b179879a63f0ba47a7f45b34c2e011f5527c0c9b8b9cf69f95ae43`
- Website deploy: `https://2fdf640b.fanzone-website.pages.dev`
- Admin deploy: `https://d68abe9b.fanzone-admin.pages.dev`
- Venue dashboard deploy: `https://945a5815.fanzone-venue-portal.pages.dev`
- TV display deploy: `https://3078ac01.fanzone-tv-display.pages.dev`

## Remaining Blockers

- Configure Apple Developer account in Xcode and provisioning for `com.fanzone.fanzone`.
- Configure the TV DNS CNAME for `screen.fanzone.ikanisa.com`; the Cloudflare Pages custom-domain binding has already been created.
- Provide `CRON_SECRET` and `PUSH_NOTIFY_SECRET` locally or in secret manager to run Edge job auth smoke.
- Rotate production secrets exposed during release support and keep only secret-manager copies.
- Replace or hide visible UAT production data before public launch.
- Review and submit the Google Play internal testing draft in Play Console.
- Upload signed iOS IPA to TestFlight.
- Run live venue/user/TV multi-device UAT.

## Required Devices

- Android release build.
- iOS release archive/TestFlight IPA requires Apple account access plus a provisioning profile/certificate for `com.fanzone.fanzone`.
- Venue dashboard browser.
- TV display browser or HDMI-connected device.
- Supabase production-like project.

## User Flow

- [x] WhatsApp OTP login.
- [x] 6-digit FANZONE ID generated.
- [x] Fan profile setup optional and skippable.
- [x] Browse venues.
- [x] View menu.
- [x] Place order from table QR.
- [x] View Cash/Revolut/external payment instructions.
- [ ] Venue marks paid. Order exists; venue payment confirmation not yet exercised on device.
- [ ] User earns order FET through ledgered transaction. Pending venue payment confirmation.
- [x] User joins prediction pool.
- [ ] User joins game.
- [ ] User creates or joins team.
- [x] User sees eligibility state.
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
