# FANZONE — Google Play Store Listing

## App Identity

- **App name**: FANZONE
- **Package name**: `app.fanzone.football`
- **Current release version**: `1.1.0 (6)`
- **Default language**: English (United States)
- **Category**: Sports
- **Tags**: Football, Predictions, Fan Engagement, Fantasy Sports

---

## Short Description (max 80 chars)

``` 
Free football picks and FET wallet rewards. Play. Predict. Climb.
```

---

## Full Description (max 4000 chars)

```
FANZONE is a lean football prediction app built around free picks, selected competitions, and the FANZONE FET wallet.

🏟️ FREE PICKS & TOKEN REWARDS
Make free football predictions, save your picks, and climb the leaderboard. Correct picks can earn FET (Fan Engagement Tokens) inside the app wallet.

⚽ FIXTURES, RESULTS, AND STANDINGS
Follow selected teams and competitions with clean match pages, standings, and prediction guidance built from historical form.

🏆 LEADERBOARDS & WALLET
Track your record on the leaderboard, receive FET rewards when applicable, and manage transfers directly from your wallet.

💚 MALTA-FIRST, GLOBAL AMBITION
Built for the Maltese football community and designed to scale. FANZONE brings Mediterranean passion to digital fan engagement.

KEY FEATURES:
• Free football picks across selected competitions
• Simple prediction engine powered by historical form
• Fixtures, standings, and lean match detail screens
• Leaderboard tracking for prediction performance
• FET wallet — earn and transfer tokens
• Anonymous fan identities for privacy-aware wallet transfers
• Clean, fast, mobile-first design

FANZONE is free to download and use. In-app tokens (FET) are earned through engagement and cannot be purchased with real money.
```

---

## Screenshots Required

Google Play requires at minimum:
- **2 phone screenshots** (16:9 or 9:16, min 320px, max 3840px)
- Recommended: 4–8 screenshots showing key flows:
  1. Home screen with live matches
  2. Match detail / prediction screen
  3. Prediction hub
  4. Leaderboard
  5. Team profile
  6. Wallet / FET balance
  7. Settings / profile
  8. Onboarding

---

## Content Rating

Google Play content rating questionnaire answers:

| Question | Answer |
|----------|--------|
| Does the app contain user-generated content? | Yes (predictions only) |
| Does the app share user location? | No |
| Does the app allow users to interact? | Limited (predictions and wallet transfer identifiers) |
| Does the app contain violence? | No |
| Does the app contain sexual content? | No |
| Does the app contain controlled substances? | No |
| Does the app allow gambling or real-money wagering? | No (FET tokens are not real currency) |
| Does the app contain profanity? | No |

**Expected rating**: PEGI 12 / Everyone 10+

---

## Privacy Policy

**Required URL**: `https://fanzone.ikanisa.com/privacy`  
(or Firebase Hosting alternative until domain is configured)

See `docs/privacy-policy.md` for the full text.

---

## Contact Details

- **Developer name**: IKANISA
- **Email**: info@ikanisa.com
- **Website**: https://fanzone.ikanisa.com
- **Phone**: (optional)

---

## App Access

If reviewers need login credentials to test the app:
- The app supports WhatsApp OTP authentication only
- Dedicated reviewer/test phone number: `+35699711145`
- Dedicated reviewer/test OTP: `123456`
- Reviewer steps: enter `+35699711145`, tap `SEND OTP`, then enter `123456`
- Provide a short note that core browsing flows also load for guest access where available

---

## Target Audience & Data Safety

### Target Audience
- **Target age group**: 13 and above
- **Not designed for children under 13**

### Data Safety Declaration

| Data Type | Collected? | Shared? | Purpose |
|-----------|-----------|---------|---------|
| Phone number | Yes | No | Authentication |
| Device identifiers | Yes | No | Push notifications (FCM token) |
| App interactions | Yes | No | Product operation, rankings, and support |
| Crash logs | Yes | No | Stability and incident monitoring through FANZONE's Supabase-operated telemetry backend |
| In-app purchases | No | No | N/A (no real-money purchases) |
| Location | No | No | N/A |
| Photos/Videos | No | No | N/A |

### Data Deletion
Users can request account deletion via Settings → Request Account Deletion.

---

## Release Track Strategy

| Track | Purpose |
|-------|---------|
| Internal testing | Team QA (up to 100 testers, instant publish) |
| Closed testing | Beta testers (up to 2000, requires review) |
| Open testing | Public beta (unlimited, requires review) |
| Production | Public release |

**Recommended**: Start with **Internal testing** to validate the end-to-end flow, then promote to Closed testing before Production.

## Submission Package

- **Upload artifact**: `build/app/outputs/bundle/release/app-release.aab`
- **Do not upload for Play distribution**: `build/app/outputs/flutter-apk/app-release.apk`
- **Release handoff reference**: [android-release-handoff-2026-04-19.md](/Volumes/PRO-G40/FANZONE/docs/android-release-handoff-2026-04-19.md:1)
