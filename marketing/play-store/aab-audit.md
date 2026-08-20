# Morning sale AAB audit

Audited artifact: private Repository `daimon-app/daimon-morning-sales` branch `work/morning-final-sales`, source HEAD `4a51402bce3bf13564abefc3c810a153fbc96633` (Morning implementation ancestor `15a38def3b8b62465c3dfad8a8fe1960aa8299c9`), locally rebuilt and signed 2026-08-20.

- Product boundary: Morning only; no WORK/NIGHT mode identifiers or assets
- Approved applicationId: `app.daimon.morning`
- versionName / versionCode: `1.0.0` / `1`
- minSdk / targetSdk / compileSdk: `23` / `36` / `36`
- Release AAB: upload-key signed, 15,147 bytes, SHA-256 `8AD78323F455EF0B7C360BA804F83B4D8AECF487F25283E683007D53DAF459C6`; `jarsigner -verify` passed (expected self-signed upload-certificate warnings remain)
- Release APK: upload-key signed, 17,892 bytes, SHA-256 `0E19217E2B2C35C24C599ECBB004DF9BD23362A3E158FEDDE3AEBA2C2C5F95E0`; APK Signature Scheme v1/v2 verification passed
- Android permissions: none
- Network: none; no INTERNET permission; WebView navigation is blocked
- WebView: no
- SDKs: Android framework and TextToSpeech only; Gradle runtime dependency report is empty
- Analytics / crash reporting / ads / billing SDK: none
- Local storage: optional name and audio preference in SharedPreferences; removable in app
- Native TTS: Android TextToSpeech, optional. The app has no network permission, but processing behavior depends on the TTS engine selected on the device.

Artifact inspection: permissions 0, no INTERNET, only `app.daimon.morning.MainActivity` and generated lambdas in DEX, no WORK/NIGHT/WebView/third-party packages, clean release build and release lint passed. Full Git history and current tracked sensitive-filename scans returned 0. Re-signing can change artifact bytes/hash even when tracked source is unchanged; the exact artifact above is the current submission candidate.

Release blockers: physical-device QA, secure offline backup of `secrets/` plus separate password-manager custody, legal/support values, Play App Signing/Console declarations/testing/submission.
