# Morning sale AAB audit

Audited artifact: ignored private workspace `app-release.aab` built 2026-08-18.

- Product boundary: Morning only; no WORK/NIGHT mode identifiers or assets
- Provisional applicationId: `app.daimon.morning` (owner approval required before first upload)
- versionName / versionCode: `1.0.0` / `1`
- minSdk / targetSdk / compileSdk: `26` / `36` / `36`
- Release AAB: generated, unsigned, 13,524 bytes, SHA-256 `8156695EDF191069D2DF824A4FCA3AB0AEF69C388E49BAD74D61746CE8FD6BE6`
- Debug APK: generated and debug-signed, 17,969 bytes, SHA-256 `7F3F894137129E791E07DCA6532CE2BE38378F9686F56A4D5D7F835B5AD899F5`
- Android permissions: none
- Network: none; no INTERNET permission; WebView navigation is blocked
- WebView: yes, bundled offline HTML only
- SDKs: Android framework WebView and TextToSpeech only; no third-party libraries
- Analytics / crash reporting / ads / billing SDK: none
- Local storage: optional name, audio preference, onboarding-complete flag; all removable in Settings
- Native TTS: on-device Android TextToSpeech, optional, stops when app backgrounds

Release blockers: final applicationId approval, owner upload keystore/signing, physical-device QA, legal/support values, Console declarations and submission.
