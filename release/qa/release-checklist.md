# Release Checklist

## Code Freeze

- [ ] Product code freeze approved.
- [ ] Release branch or tag created.
- [ ] Credentials rotated after prior exposure.
- [x] Production env examples and provider-secret requirements documented.

## Backend

- [ ] Production DB backup taken.
- [x] `supabase db push --dry-run` clean.
- [x] `supabase db push` completed if migrations pending.
- [x] Edge Functions deployed.
- [ ] Edge Function secrets configured.
- [x] Supabase release probe passed.
- [x] RLS audit passed.
- [x] FET supply smoke passed.
- [x] WhatsApp auth smoke passed.
- [ ] Edge job auth smoke passed with `CRON_SECRET` and `PUSH_NOTIFY_SECRET`.

## Web

- [x] Website build passed.
- [x] Admin build passed.
- [x] Venue dashboard build passed.
- [x] TV display build passed.
- [x] Cloudflare Pages deploys completed.
- [ ] Deep route refresh works.

## Mobile

- [x] `flutter analyze` passed.
- [x] `flutter test` passed.
- [x] Android AAB built and signed.
- [x] Android AAB signature verified locally.
- [x] Play metadata text/image dimensions validated locally.
- [ ] Play validate-only upload completed without API edit error.
- [x] Android uploaded to internal test draft.
- [x] Android build `11` changelog synced to Play.
- [ ] Android internal test draft reviewed/submitted in Play Console.
- [ ] iOS archive built.
- [ ] iOS signed archive and IPA exported with Apple Team ID `63STJ5N27W`.
- [ ] iOS uploaded to TestFlight.

## Store Submission

- [ ] Play Store metadata entered.
- [ ] Play Data safety completed.
- [ ] App Store metadata entered.
- [ ] App Store privacy labels completed.
- [ ] Reviewer OTP configured.
- [ ] Privacy policy URL live.
- [ ] Terms URL live.

## Launch

- [ ] Pilot venue configured.
- [ ] Venue staff trained.
- [ ] TV screen tested on venue hardware.
- [x] `screen.fanzone.ikanisa.com` Cloudflare Pages custom-domain binding created.
- [ ] `screen.fanzone.ikanisa.com` DNS CNAME configured.
- [ ] Monitoring owners assigned.
- [ ] Rollback path confirmed.
