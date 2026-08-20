# DAIMON Android owner device QA batch

Status: every row starts `UNVERIFIED`. Do not convert to PASS without observation.
Target artifact: signed build derived from the AAB hash recorded in
`../BUILD_EVIDENCE_2026-08-20.md`.

Record device model, Android version, WebView version, build version, tester,
date and evidence location before testing.

| ID | Exact action | Expected result | Evidence | Result / severity |
|---|---|---|---|---|
| D-01 | Install the candidate through the selected test track | Install completes; launcher shows DAIMON | install screen + launcher capture | UNVERIFIED |
| D-02 | Cold-launch while online, then repeat in Airplane Mode after force-stop | Home opens both times; four modes are visible | two screen recordings | UNVERIFIED |
| D-03 | Complete Morning, Work, Night and all 20 Adversity screens | No missing image, freeze, crash or wrong mode | one recording per mode | UNVERIFIED |
| D-04 | Enable audio, enter each mode, background the app, return, press Home and Back | Audio/timers stop in background/Home and resume only by a new user action | recording + audible observation | UNVERIFIED |
| D-05 | In Adversity, toggle binaural/audio on and off using headphones at safe volume | Toggle works; no audio continues after exit/background | recording + tester note | UNVERIFIED |
| D-06 | Change audio preference, close and relaunch app | Preference persists locally | before/after captures | UNVERIFIED |
| D-07 | Install the next version over the current test version | App updates; local preference remains; four modes still work | update log + captures | UNVERIFIED |
| D-08 | Uninstall, reinstall and launch | Prior local preference/name is gone; clean Home opens | before/after captures | UNVERIFIED |
| D-09 | Tap Android Back from each mode and from Home | Mode returns to DAIMON Home; Home exits without loop/crash | recording | UNVERIFIED |
| D-10 | Rotate, lock/unlock, interrupt with a call/audio focus event and reopen | Portrait remains stable; no stuck or leaking audio | recording + note | UNVERIFIED |
| D-11 | Attempt any visible external link or file input if present | No external navigation or file chooser opens | recording | UNVERIFIED |
| D-12 | Run all modes back-to-back and inspect battery/network indicators/logs | No ANR/crash; no app network traffic | logcat/network evidence | UNVERIFIED |

Classification: crash/data loss/security bypass/wrong product = P0; broken primary
mode/audio stop/offline path = P1; cosmetic issue with safe workaround = P2.

Completion requires D-01 through D-12 evidence. Signing, Play Console and device
taps are `OWNER_PHYSICAL_ACTION_REQUIRED`; preparation and defect repair are not.

