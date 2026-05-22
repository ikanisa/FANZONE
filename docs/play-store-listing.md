# FANZONE — Google Play Store Listing

## App Identity

- **App name**: FANZONE
- **Package name**: `app.fanzone.football`
- **Current release version**: `1.1.0 (6)`
- **Default language**: English (United States)
- **Category**: Sports
- **Tags**: Football, Sports Bars, Fan Engagement, Venue Ordering

---

## Short Description (max 80 chars)

``` 
Sports-bar match pools, venue ordering, and FET wallet rewards.
```

---

## Full Description (max 4000 chars)

```
FANZONE is a sports-bar entertainment app built around venue ordering, curated football match pools, and the FANZONE FET wallet.

SPORTS-BAR MATCH POOLS
Join FET match pools for curated fixtures at participating bars, fan zones, lounges, and hospitality venues.

VENUE MENU & ORDERING
Choose a venue in the app, browse the bar menu, place an order, and earn FET where the venue has enabled rewards.

FET WALLET
Earn FET from welcome rewards, qualifying orders, creator invite rewards, and settled pool wins. Use FET on venue orders where allowed by the venue.

GLOBAL FOOTBALL MOMENTS
Built for sports bars and fan zones across Africa, Europe, the UK, North America, and World Cup markets.

KEY FEATURES:
* In-app venue entry, bar menu browsing, and ordering
* Curated football fixtures and official match pools
* Venue, country, and global pool scopes
* FET wallet for rewards, staking, and eligible venue redemption
* Shareable pool links and social cards
* Anonymous fan identities for privacy-aware participation
* Clean, fast, mobile-first design

FANZONE is free to download and use. Payments happen off-platform through the venue's supported methods such as USSD, cash guidance, or Revolut links. FET tokens are not real currency and cannot be purchased in the app.
```

---

## Screenshots Required

Google Play requires at minimum:
- **2 phone screenshots** (16:9 or 9:16, min 320px, max 3840px)
- Recommended: 4–8 screenshots showing key flows:
  1. Home screen with live matches
  2. Venue menu / in-app ordering
  3. Match pool detail
  4. Pool discovery
  5. Team profile
  6. Wallet / FET balance
  7. Settings / profile
  8. Onboarding

---

## Content Rating

Google Play content rating questionnaire answers:

| Question | Answer |
|----------|--------|
| Does the app contain user-generated content? | Yes (match pool participation and venue order notes where enabled) |
| Does the app share user location? | No |
| Does the app allow users to interact? | Limited (match pools, share links, and wallet transfer identifiers) |
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
