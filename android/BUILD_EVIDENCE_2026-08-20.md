# DAIMON four-mode Android build evidence

- Date: 2026-08-20
- applicationId candidate: `app.daimon`
- version: `1.0.0-beta.1` (`versionCode 1`)
- toolchain: JDK 17 / Gradle 8.9 / AGP 8.7.3 / compile and target SDK 35
- command: `gradlew.bat clean bundleRelease`
- result: `BUILD SUCCESSFUL` (42 tasks)
- artifact: `android/app/build/outputs/bundle/release/app-release.aab`
- size: `5,284,054 bytes`
- SHA-256: `C97AF8C8E281E8793619FC693B3705C29CE30936C3DB5D958482BBDC883F9AE6`
- signature: unsigned (`jarsigner`: jar is unsigned)
- static readiness: 74 PASS / 0 WARN / 0 FAIL
- lifecycle repair: background stops app audio and JavaScript timers; WebView is detached before destruction; Android Back returns an active mode to Home
- bundled inspection: `index.html`, `manifest.json`, `sw.js`, Android manifest, DEX, 12 Work images and 12 Night images present
- PWA icons: repaired from the verified DAIMON sales icon; 192px and 512px files now have valid PNG signatures

Production signing, Play upload, installed-device behavior, WebView asset loading, offline restart and binaural audio remain `UNVERIFIED`. No signing key or password is committed.
