# DAIMON four-mode Android release build evidence

- Date/time: 2026-08-21 15:33 JST
- Source branch: `sales/cm-assets-20260821`
- Source base: `product/daimon-four-mode-ready` / `be6d1a5`
- applicationId: `app.daimon`
- version: `1.0.0-beta.1` (`versionCode 1`)
- toolchain: Eclipse Temurin JDK 17.0.20 / Gradle 8.9 / AGP 8.7.3 / Android Platform 35
- command: `gradlew.bat clean bundleRelease`
- result: `BUILD SUCCESSFUL` (42 tasks; 41 executed, 1 up-to-date)
- artifact: `android/app/build/outputs/bundle/release/app-release.aab`
- exported checkpoint artifact: `outputs/DAIMON-1.0.0-beta.1-unsigned.aab`
- size: `5,283,964 bytes`
- SHA-256: `04DCEC86FA103200BFA77D019F95DCA6CDB71E077A660B29FE0B1EEED1427C81`
- signature verification: `jar is unsigned`
- release audit: 24 PASS / 0 WARN / 0 FAIL
- Play pack audit: 10 PASS / 0 FAIL
- Android static readiness: 74 PASS / 0 WARN / 0 FAIL

## Toolchain recovery

- Installed Eclipse Temurin JDK 17 through the official winget package.
- Downloaded Google Android command-line tools `15859902` from the official Android Developers distribution.
- Verified command-line-tools SHA-256: `90AE805D20434428BFFCB699C290860F19BB5F66A67E6B330067E3DE801FB04A`.
- Installed Android Platform 35, Build Tools 35.0.0, automatically required Build Tools 34.0.0, and Platform Tools into a workspace-local SDK.

## Owner gate

The AAB is a reproducible unsigned release candidate, not a production-upload artifact. Production signing identity, key custody, signed-AAB verification, Play upload, installed-device behavior, offline restart, screenshots/recording and final release remain `OWNER ACTION REQUIRED / UNVERIFIED`. No key, password or credential was created or committed.

