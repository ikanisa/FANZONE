# FANZONE Flutter Review PWA

The Flutter review PWA is a browser-accessible mirror of the guest mobile app.
It uses the same Flutter router, widgets, feature modules, Riverpod providers,
theme, and Supabase gateways as the mobile app. It is not a copied web app.

## Run Locally

```bash
scripts/run_review_web.sh
```

Equivalent command:

```bash
flutter run -d chrome -t lib/main_review.dart \
  --dart-define=APP_RUNTIME_MODE=web_review \
  --dart-define=APP_ENV=staging
```

Pass staging Supabase values through your normal local env flow:

```bash
flutter run -d chrome -t lib/main_review.dart \
  --dart-define=APP_RUNTIME_MODE=web_review \
  --dart-define=APP_ENV=staging \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

## Build

```bash
scripts/build_review_web.sh
```

This runs format check, analyze, tests, and:

```bash
flutter build web --release -t lib/main_review.dart
```

## How Review Works

The shell renders the shared mobile app inside a device frame. Reviewers can:

- choose a device preset;
- see the active route;
- enter reviewer name/contact;
- enable comment mode;
- click a point on the simulated screen;
- add severity, component key, and comment text.

When Supabase is configured, comments insert into `app_review_comments`.
Without Supabase, comments fall back to local browser storage.

## Safety

Review mode blocks high-risk mobile mutations in Flutter gateways:

- WhatsApp OTP send/verify;
- account upgrade merge;
- order creation and payment submission;
- FET order spend and wallet transfer;
- pool creation, staking, invites, and social-card generation;
- game team/answer/bingo write actions.

Deploy this PWA only against staging/review configuration and protected access.
Do not expose production user data or production secrets.

## Developer Loop

1. Update shared Flutter widgets or design tokens.
2. Build mobile and review PWA from the same code.
3. Reviewer comments in the browser.
4. Developer or Codex reads the route/component/severity/comment metadata.
5. Fix shared Flutter widgets, not web-only copies.
6. Rebuild Android/iOS and review PWA.

## Limitations

The review PWA is not a replacement for physical-device UAT. Real Android/iOS
testing is still required for WhatsApp OTP, push notifications, deep links,
permissions, native storage, device performance, keyboard behavior, and any
plugin that has platform-specific behavior.
