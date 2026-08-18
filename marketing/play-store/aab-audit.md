# Morning sale AAB audit

Audited artifact: private Repository `daimon-app/daimon-morning-sales` HEAD `15a38def3b8b62465c3dfad8a8fe1960aa8299c9`, locally signed 2026-08-18.

- Product boundary: Morning only; no WORK/NIGHT mode identifiers or assets
- Approved applicationId: `app.daimon.morning`
- versionName / versionCode: `1.0.0` / `1`
- minSdk / targetSdk / compileSdk: `23` / `36` / `36`
- Release AAB: upload-key signed, 15,146 bytes, SHA-256 `A0DE96F91F19A3E336C6BD7E2D556D69912397BBE30F408E777E888E906343CA`; `jarsigner` verification passed
- Release APK: upload-key signed, 17,891 bytes, SHA-256 `058DC9754502653B1FEF457653921296623127CEA831B217A059E1FEDBC5D612`; v1/v2 verification passed
- Android permissions: none
- Network: none; no INTERNET permission; WebView navigation is blocked
- WebView: no
- SDKs: Android framework and TextToSpeech only; Gradle runtime dependency report is empty
- Analytics / crash reporting / ads / billing SDK: none
- Local storage: optional name and audio preference in SharedPreferences; removable in app
- Native TTS: Android TextToSpeech, optional. The app has no network permission, but processing behavior depends on the TTS engine selected on the device.

Artifact inspection: permissions 0, no INTERNET, only `app.daimon.morning.MainActivity` and generated lambdas in DEX, no WORK/NIGHT/WebView/third-party packages, release lint passed, tracked-secret scan passed.

Release blockers: physical-device QA, secure offline backup of `secrets/` plus separate password-manager custody, legal/support values, Play App Signing/Console declarations/testing/submission.
