# DAIMON four-mode Android foundation

This project bundles the canonical four-mode PWA into the APK/AAB at build time and loads it from `file:///android_asset/index.html`. It does not reuse the Morning-only binary or applicationId.

## Identity

- applicationId candidate: `app.daimon`
- versionCode: `1`
- versionName: `1.0.0-beta.1`
- final Play identity: not published and still subject to the final release decision

## Offline and security

- `INTERNET` is used only by Google Play Billing; product media stays bundled/offline
- subscription IDs are supplied through Gradle properties/environment and remain fail-closed until `DAIMON_BILLING_IDS_VERIFIED=true`
- no external navigation
- no file chooser
- JavaScript and DOM storage enabled for the existing app
- generic filesystem, content, universal file-URL and mixed-content access disabled
- backup and cleartext traffic disabled
- PWA Service Worker does not run under `file://`; offline behavior comes from bundling every required asset in the artifact

## Build

Use JDK 17, Android SDK 35 and Gradle 8.9:

```text
gradlew.bat clean bundleRelease
```

Expected unsigned artifact: `app/build/outputs/bundle/release/app-release.aab`.

Production signing, Play upload and physical-device QA remain `UNVERIFIED`. No signing key or secret belongs in this repository.
