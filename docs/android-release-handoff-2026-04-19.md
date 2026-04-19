# FANZONE Android Release Handoff — 2026-04-19

## Final production artifacts

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

## Build identity

- App name: `FANZONE`
- Application ID: `app.fanzone.football`
- Launch activity: `app.fanzone.football/com.fanzone.fanzone.MainActivity`
- Version name: `1.1.0`
- Version code: `6`
- Min SDK: `24`
- Target SDK: `35`

## Artifact hashes

- APK SHA-256: `26b73aba7be1d95d387fa351c8e098e5cff8f2c38989a42cd537bb7e9cc62e9c`
- AAB SHA-256: `1e265b4e4a0eb177adff89763bb4c86416ecefa4bcc0a356e438200e3c7d66c5`

## Commands used

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter test test/screen_widgets_test.dart
./tool/build_android_release_from_env.sh production
./tool/build_android_aab_from_env.sh production
```

## Device validation completed

- Release APK built successfully.
- Release AAB built successfully.
- APK installed successfully on physical Android device `13111JEC215558`.
- Main activity resolves correctly.
- App process started successfully in release mode.
- No immediate fatal startup crash pattern observed in logcat.

## Android packaging checks completed

- Release signing path is enforced for `APP_ENV=production`.
- Production Firebase/FCM wiring is present.
- Android manifest label is `FANZONE`.
- Launcher icon mipmaps are present in all Android density buckets.
- Notification icon resource exists at `@drawable/ic_notification`.
- Splash screen uses `@drawable/launch_background` in both light and dark themes.
- Runtime permissions packaged in the release APK:
  - `android.permission.INTERNET`
  - `android.permission.ACCESS_NETWORK_STATE`
  - `android.permission.WAKE_LOCK`
  - `android.permission.POST_NOTIFICATIONS`
  - `com.google.android.c2dm.permission.RECEIVE`

## UAT install command

```bash
adb install -r -g build/app/outputs/flutter-apk/app-release.apk
```

## Recommended UAT smoke flow

1. Launch the app and confirm splash-to-home startup is stable.
2. Verify onboarding and WhatsApp OTP flow.
3. Verify home, fixtures, match detail, predict, wallet, profile, and social hub.
4. Verify notifications permission prompt behavior on Android 13+.
5. Verify deep links for `https://fanzone.mt/pool/...` and `fanzone://pool`.
6. Verify production Supabase data loads correctly in release mode.

## Google Play next steps

- Upload `build/app/outputs/bundle/release/app-release.aab` to Internal testing first.
- Complete Play App Signing enrollment if not already configured.
- Complete Play Console App content declarations, including Data safety.
- Upload final screenshots, feature graphic, and store listing copy.
- Provide reviewer app-access instructions for WhatsApp OTP login.
- Prepare release notes for Internal and Closed testing tracks.

