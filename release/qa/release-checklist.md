# Release Checklist

## Code Freeze

- [ ] Product code freeze approved.
- [ ] Release branch or tag created.
- [ ] Credentials rotated after prior exposure.
- [x] Production env examples and provider-secret requirements documented.

## Backend

- [ ] Production DB backup taken.
- [x] `supabase db push --dry-run` clean.
- [ ] `supabase db push` completed if migrations pending.
- [ ] Edge Functions deployed.
- [ ] Edge Function secrets configured.
- [x] SQL verification suite passed.
- [ ] RLS audit passed.

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
- [ ] Android uploaded to internal test.
- [x] iOS unsigned archive built.
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
- [ ] Monitoring owners assigned.
- [ ] Rollback path confirmed.
