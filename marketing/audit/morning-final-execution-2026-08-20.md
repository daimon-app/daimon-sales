# DAIMON MORNING final sales execution — 2026-08-20

## Source of truth

- Public sales: `daimon-app/daimon-sales`, `work/morning-final-sales` from `origin/feat/marketing-foundation@dbdc351854a31a4137288644dba5f2f12cf67e3d`
- Private Android: `daimon-app/daimon-morning-sales`, `work/morning-final-sales` from `origin/main@4a51402bce3bf13564abefc3c810a153fbc96633`
- `main`, production, Play submission, LP publication and SNS publication were not changed.

## FIXED

- Morning-only native Android source; no WORK/NIGHT sale code.
- `app.daimon.morning`, version `1.0.0` (`1`), minSdk 23, target/compileSdk 36.
- Permissions 0, no INTERNET, no WebView, no third-party runtime dependency, ads, analytics, crash SDK or billing SDK.
- Optional name/audio preference only in SharedPreferences; in-app deletion exists.
- Android TextToSpeech only. The selected device TTS engine remains outside app control.
- Clean signed release build and release lint passed on 2026-08-20.
- Current submission-candidate AAB: 15,147 bytes, SHA-256 `8AD78323F455EF0B7C360BA804F83B4D8AECF487F25283E683007D53DAF459C6`.
- Current matching APK: 17,892 bytes, SHA-256 `0E19217E2B2C35C24C599ECBB004DF9BD23362A3E158FEDDE3AEBA2C2C5F95E0`.
- AAB `jarsigner -verify` passed with expected self-signed upload-certificate warnings; APK v1/v2 signature verification passed.
- Full Git-history/current tracked sensitive-filename checks: 0. Secrets remain ignored and were not printed or committed.
- Marketing QA passed, including LP/legal link presence, Play graphics, 30 posts, UTM fields, CM dimensions/codec/fps/duration, Morning-only assertions and private artifact existence.

## Independent checks

- Claude Code 2.1.233 / logged-in Pro. Exact usage, remaining and reset values: `確認不能` from the CLI.
- Initial Claude CLI timeouts were caused by sandbox network denial. The approved external CLI path returned `CLAUDE_CONNECTION_OK`; no reinstall or plan change was needed.
- Direct private-source transmission to Claude was blocked by the security gate. Claude reviewed the public source and sanitized local evidence only, returning `CONDITIONAL` because owner/device/Console gates remain.
- Gemini and Manus Chrome routes were attempted but remain unavailable due the Codex trusted-RPC Browser-plugin error. No API key, paid API or authentication workaround was used. Google Play facts were therefore rechecked by Codex against current official Android/Play sources.

## Current official Play cross-check

- From 2026-08-31, new apps and updates must target Android 16 / API 36 or higher. This build targets 36.
- New personal developer accounts created after 2023-11-13 require a closed test with at least 12 continuously opted-in testers for 14 days before applying for production access. Actual account applicability must be confirmed in Console.
- Data safety must be completed for closed/open/production tracks even when no data is collected; a privacy policy URL is still required.
- App creation requires a support email and Play App Signing acceptance. Price/country/identity/terms/submission are owner/Console actions.

Official references:

- https://developer.android.com/google/play/requirements/target-sdk
- https://support.google.com/googleplay/android-developer/answer/14151465
- https://support.google.com/googleplay/android-developer/answer/10787469
- https://support.google.com/googleplay/android-developer/answer/9859152
- https://support.google.com/googleplay/android-developer/answer/13393723

## Remaining gates

### OWNER_INFO

- Legal seller/operator identity and required address/phone scope.
- Support email/contact route.
- Refund/cancellation terms and specialist-review scope.

### OWNER_ACTION

- Connect an owned Android device for signed APK QA and final capture.
- Store upload key/password recovery material in approved offline/password-manager custody.
- Play identity/login/agreements, app creation, Play App Signing, country/JPY 490, Data safety/IARC/target audience and submission.
- LP publication, SNS account authentication/posts and final sale start.

### EXTERNAL_WAIT

- Account-specific closed-testing requirement and, if applicable, 12 opted-in testers for 14 continuous days plus production-access review.

### NOT A CODE DEFECT

- `minSdk 23` is the current code/artifact/ledger value. The older candidate value 26 is superseded; no Play rule requires raising it.
- No ADB device was attached during this execution. Device QA is pending owner connection, not an application build failure.
- Play screenshots and CM-B/C remain staging-blocked until the matching signed APK can be captured on a physical device.

## Verdict

- Technical code blockers: 0 based on local build/lint/static/artifact checks.
- Release readiness: `CONDITIONAL` pending physical-device evidence, owner legal values, key custody and Console/external gates.
- Public release/sale: `NO-GO` until the remaining gates are completed and explicitly approved.
