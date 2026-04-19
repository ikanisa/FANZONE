# FANZONE Push Notification Setup Guide

Status: Firebase packages, app initialization, token registration, and push routing are already wired in the repo.

Estimated time: 20-30 minutes for a new Firebase and APNs production setup.

## Already implemented

| Component | Status | File |
|-----------|--------|------|
| Notification preferences table | Ready | `notification_preferences` |
| Device token registration table | Ready | `device_tokens` |
| Notification log table | Ready | `notification_log` |
| Match alert subscriptions table | Ready | `match_alert_subscriptions` |
| Push notification triggers | Ready | `20260418040000_push_notification_triggers.sql` |
| Push notification edge function | Ready | `supabase/functions/push-notify/` |
| Flutter notification service | Ready | `lib/services/notification_service.dart` |
| Flutter push service | Ready | `lib/services/push_notification_service.dart` |
| Notification preferences screen | Ready | `lib/features/profile/screens/notifications_screen.dart` |
| Auto-settle winner notification | Ready | `supabase/functions/auto-settle/index.ts` |
| Firebase bootstrap | Ready | `lib/main.dart`, `lib/firebase_options.dart` |

## Firebase project setup

### 1. Create the Firebase project

1. Open `https://console.firebase.google.com`.
2. Create the FANZONE Firebase project.
3. Enable Cloud Messaging for the project.

### 2. Register the platform apps

#### Android

1. Add an Android app in Firebase.
2. Use package name `app.fanzone.football`.
3. Download `google-services.json`.
4. Place it in `android/app/google-services.json`.

#### iOS

1. Add an iOS app in Firebase.
2. Use the bundle ID from `ios/Flutter/AppConfig.xcconfig`:
   `FANZONE_APP_BUNDLE_IDENTIFIER`.
3. Download `GoogleService-Info.plist`.
4. Place it in `ios/Runner/GoogleService-Info.plist`.

### 3. Generate FlutterFire options

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=your-firebase-project-id
```

This should generate or refresh `lib/firebase_options.dart`.

## App configuration checks

### 4. Confirm Firebase initialization

Firebase initialization already exists in `lib/main.dart`:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

Do not remove it. Push registration depends on it.

### 5. Confirm notification boot is enabled

1. Set `ENABLE_NOTIFICATIONS` to `"true"` in the active dart-define JSON file.
2. Build or run with `--dart-define-from-file=...`.
3. App startup watches `pushNotificationInitProvider` from `lib/app.dart`.
4. Signed-in users should register a token automatically.
5. Signed-out users should unregister the token automatically.

## Supabase server-side setup

### 6. Add the Firebase service account secret

In Supabase Dashboard -> Settings -> Edge Function Secrets, set:

```text
GOOGLE_SERVICE_ACCOUNT_JSON = <Firebase service account JSON>
```

To get it:

1. Open Firebase Console -> Project Settings -> Service Accounts.
2. Generate a new private key.
3. Copy the JSON contents.
4. Store it as the `GOOGLE_SERVICE_ACCOUNT_JSON` edge-function secret.

## iOS APNs setup

### 7. Configure APNs and capabilities

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Confirm Signing and Capabilities shows `Push Notifications`.
3. Confirm `Background Modes` includes `Remote notifications`.
4. Create or reuse an APNs key in Apple Developer.
5. Upload that APNs key to Firebase Console -> Project Settings -> Cloud Messaging -> iOS.

The repo now already includes:

- `Runner.entitlements` with `aps-environment`
- `Info.plist` background mode for `remote-notification`
- `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` in the Runner target

## Build and test

### 8. Run on physical devices

Push does not work in simulators. Use a real Android device and a real iPhone.

Example:

```bash
flutter run --dart-define-from-file=env/development.example.json
```

Use a real non-example JSON file for staging or production validation.

### 9. Verify token registration

Expected logs:

- `Push notification service initialized`
- `Device token registered`

Expected backend result:

- A row appears in `device_tokens`

### 10. Verify push delivery and tap routing

1. Send a test push via the `push-notify` edge function or a targeted campaign.
2. Confirm foreground delivery.
3. Confirm background delivery.
4. Confirm terminated-app delivery.
5. Tap the push and verify the app lands on the expected route:
   - `/match/:id`
   - `/predict/pools/:id`
   - `/notifications`

## What the live flow does

1. User opens the app and signs in.
2. The device token is registered in `device_tokens`.
3. User notification preferences are stored in `notification_preferences`.
4. `auto-settle` or admin-triggered flows call `push-notify`.
5. The notification is logged in `notification_log`.
6. Tapping the notification routes the user into the correct app screen.

## Verification checklist

- [ ] `android/app/google-services.json` is the intended Firebase file
- [ ] `ios/Runner/GoogleService-Info.plist` is the intended Firebase file
- [ ] `lib/firebase_options.dart` matches the current Firebase project
- [ ] `ENABLE_NOTIFICATIONS` is `true` in the active dart-define file
- [ ] Signed-in users create rows in `device_tokens`
- [ ] `GOOGLE_SERVICE_ACCOUNT_JSON` is set in Supabase edge-function secrets
- [ ] APNs key is uploaded to Firebase
- [ ] Xcode capabilities show Push Notifications and Remote notifications
- [ ] Foreground push delivery works
- [ ] Background push delivery works
- [ ] Terminated-app push delivery works
- [ ] Notification tap routing lands on the expected screen
