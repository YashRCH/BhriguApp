# Production Release Checklist

## Default Launch Path

- Use internal testing first.
- If there are no real production users yet, release production to 100% after internal testing passes.
- Use a staged rollout later when real users, paid traffic, or paid subscriptions exist.

## App Bundle Command

Build the Play Console artifact from a clean working state:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release `
  --dart-define=ENABLE_APP_CHECK=true `
  --dart-define=ENABLE_CRASHLYTICS=true `
  --dart-define=MONETIZATION_MODE=off `
  --dart-define=REVENUECAT_ANDROID_API_KEY=<android_public_sdk_key>
```

For the internal testing track where licensed tester accounts are already added and you want enforcement enabled, use:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release `
  --dart-define=ENABLE_APP_CHECK=true `
  --dart-define=ENABLE_CRASHLYTICS=true `
  --dart-define=MONETIZATION_MODE=enforce `
  --dart-define=REVENUECAT_ANDROID_API_KEY=<android_public_sdk_key>
```

Upload:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Firebase Functions Switches

Before deploying payment-ready Functions, set both RevenueCat secrets:

```powershell
npx.cmd --yes firebase-tools functions:secrets:set REVENUECAT_WEBHOOK_AUTH --project astrology-guru-app
npx.cmd --yes firebase-tools functions:secrets:set REVENUECAT_SECRET_API_KEY --project astrology-guru-app
```

Use the webhook auth secret in the RevenueCat webhook Authorization header.
Use a RevenueCat secret API key, not the Android public SDK key, for
`REVENUECAT_SECRET_API_KEY`.

Keep App Check callable enforcement off until internal test builds are confirmed to send valid App Check tokens:

```text
APP_CHECK_ENFORCEMENT_ENABLED=false
MONETIZATION_ENFORCEMENT_MODE=off
```

For strict internal testing after the uploaded build is installed from the Play internal testing track and App Check metrics show valid requests, deploy Functions with:

```text
APP_CHECK_ENFORCEMENT_ENABLED=true
MONETIZATION_ENFORCEMENT_MODE=enforce
```

When monetization is ready but before charging users, deploy with audit mode:

```text
MONETIZATION_ENFORCEMENT_MODE=audit
```

When RevenueCat products, webhook secret, entitlement sync, and paywalls are verified, deploy with:

```text
MONETIZATION_ENFORCEMENT_MODE=enforce
```

## Play Console Test Setup

- Add tester emails to the internal testing track.
- Add the same tester emails under Play Console license testing.
- Make sure testers install from the internal testing Play Store opt-in link, not a sideloaded APK.
- Use tester Google accounts that are also signed into Google Play on the device.
- Configure Play Billing products and RevenueCat offerings before testing paid gates.
- Confirm RevenueCat webhook secret is deployed as `REVENUECAT_WEBHOOK_AUTH`.
- Confirm RevenueCat server API key is deployed as `REVENUECAT_SECRET_API_KEY`
  so Restore/Refresh can securely sync purchases even if webhook delivery is delayed.
- Confirm App Check uses Play Integrity for the release/internal build.

## Verification

- `flutter analyze`
- `flutter test`
- Internal testing install from the exact uploaded AAB/APK track.
- Sign up with email and verify email delivery copy.
- Sign in with Google.
- Complete onboarding with inline birth date/time pickers.
- Trigger one chat, tarot, geomancy, and compatibility reading.
- Confirm Circle connection, Circle compatibility, Circle daily energy, and Circle follow-ups stay free.
- Confirm manual standalone match is allowed for monthly Plus and yearly Plus testers.
- Confirm monthly Plus shows manual matches unlocked and yearly Plus displays unlimited.
- Confirm free testers are blocked from gated AI features when `MONETIZATION_ENFORCEMENT_MODE=enforce`.
- Confirm Crashlytics receives a test crash only from a release/internal build.
- Confirm App Check metrics show valid requests before enabling enforcement.
- Confirm RevenueCat webhook or secure server sync writes entitlements and Dakshana wallet credits before enabling monetization enforcement.
