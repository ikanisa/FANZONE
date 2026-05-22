# Flutter Client Production Readiness - 2026-05-21

Surface: Flutter client app (`lib/`, `android/`, `ios/`)

## Status

NO-GO for full mobile public launch today.

The Flutter codebase passes local source gates, but mobile release readiness is
not complete because the current machine could not regenerate fresh Android
release artifacts, the attached Android device is not authorized for a new
physical-device smoke, and iOS still lacks signed IPA/TestFlight evidence.

Android remains the stronger release surface because historical signed artifacts
exist and verify, but the May 21 go-live pass did not produce a fresh APK/AAB.
iOS remains blocked for App Store/TestFlight until signed archive, IPA export,
physical iPhone install, push, and TestFlight evidence are attached.

## Validation Evidence

Commands run:

```bash
flutter --version
flutter pub get
tool/flutter_analyze_release.sh
flutter test --reporter expanded
tool/mobile_release_static_audit.sh
flutter devices
tool/build_android_release_from_env.sh production
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
node tool/validate_critical_uat_signoff.mjs release/qa/critical-user-flow-uat.json
node tool/validate_ios_testflight_evidence.mjs release/ios/testflight-readiness.json
```

Passing local gates:

- Flutter `3.38.9`, Dart `3.10.8`.
- `flutter pub get` completed; 61 packages report newer versions outside the
  current dependency constraints.
- Release analyzer gate passed with no warning/error diagnostics.
- `flutter test --reporter expanded` passed: 244 tests.
- `tool/mobile_release_static_audit.sh` passed.
- iOS production config files exist:
  - `ios/Flutter/AppConfig.xcconfig`
  - `ios/Runner/GoogleService-Info.plist`
- iOS config values verified:
  - bundle ID `com.fanzone.fanzone`
  - Apple Team ID `63STJ5N27W`
  - APNs environment `production`
  - Firebase plist bundle ID `com.fanzone.fanzone`

## Android Artifact State

Existing artifacts from the earlier release pass are still present:

| Artifact | Timestamp | SHA-256 |
| --- | --- | --- |
| `build/app/outputs/flutter-apk/app-release.apk` | 2026-05-18 00:29:32 | `fcccb0ed949ed4ab8d5ba7b6d4776ad49fdcab154db31949fd72a5e8de88dd55` |
| `build/app/outputs/bundle/release/app-release.aab` | 2026-05-18 00:15:16 | `c403f29c0ee40e80859ddfa7a9d23602b4e09ff47009001a9acb8efe20dda094` |

`jarsigner -verify` returned status `0` for the existing AAB. The signer
certificate is `CN=FANZONE, OU=Mobile, O=FANZONE, L=Valletta, ST=Malta, C=MT`
and expires on `2053-09-02`.

Fresh May 21 Android regeneration did not complete:

- `tool/build_android_release_from_env.sh production` reached Gradle
  `assembleRelease` and Flutter asset tree-shaking.
- The build then stalled twice with no CPU progress and no updated APK/AAB
  timestamp.
- Gradle daemons were stopped between attempts.
- The stale May 18 artifacts remain in place; they must not be treated as fresh
  May 21 build output.

## Device UAT State

`flutter devices` reports macOS and Chrome only as usable targets.

The attached Android device `13111JEC215558` is present over USB but
unauthorized, so a fresh physical-device smoke could not be run in this pass.
The iPhone wireless target also reports a Developer Mode/local-network
connection error.

## iOS State

XcodeBuildMCP was configured against:

```text
ios/Runner.xcworkspace
Runner
iPhone 17 simulator
```

The simulator build exceeded the MCP 120-second timeout. The underlying
`xcodebuild` process continued and created a `Runner.app` directory under
`build/ios/xcodebuildmcp-derived/Build/Products/Debug-iphonesimulator`, but it
was not a usable app bundle in this pass because the directory had no readable
`Info.plist` when checked. This is inconclusive/failed simulator compile
evidence, not a release pass.

The TestFlight validator correctly remains red because signed archive, IPA,
physical iPhone install, push, TestFlight upload, review metadata, owner
signoff, and launch approval are not complete.

## Blocking Items

- Regenerate fresh Android APK and AAB from `env/production.json` on a clean
  Android build environment, then hash and verify the outputs.
- Re-authorize the Pixel/Android device and rerun installed-app smoke for
  launch, WhatsApp OTP, home, venue, menu/order, wallet, pool, and deep link.
- Complete critical UAT signoff in `release/qa/critical-user-flow-uat.json`.
- Produce signed iOS Release archive and IPA.
- Install the signed iOS build on a physical iPhone.
- Verify iOS push permission, delivery, and notification-tap routing.
- Upload to App Store Connect/TestFlight and attach evidence.
- Complete App Review metadata, privacy labels, support URL, privacy URL, and
  terms URL evidence.

## Decision

The Flutter client is source-ready but not release-ready.

Use the passing analyzer/test/static-audit result as code-quality evidence.
Do not proceed to public mobile launch until fresh Android artifacts, physical
device smoke, signed iOS/TestFlight evidence, and signed critical UAT are green.
