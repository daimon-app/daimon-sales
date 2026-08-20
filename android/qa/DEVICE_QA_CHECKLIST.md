# DAIMON Android shell — device QA checklist

Static checks (`../test-readiness.ps1`) only verify source files. Everything
in this checklist requires a real device or emulator and has **not** been
run in this session (no SDK/emulator/device access here) — treat every item
as `UNVERIFIED` until someone with a device checks it off.

This is the four-mode wrapper (`app.daimon`), not the earlier Morning-only
native candidate (`app.daimon.morning`); do not reuse QA evidence from that
build for this one.

## Install / launch

- [ ] `adb install app-debug.apk` succeeds on a minSdk 23 device (Android 6.0)
      and on a current device (Android 14/15)
- [ ] Cold launch from launcher shows the DAIMON placeholder icon (dark tile,
      light circle mark — see README "Known issues" for why it is a
      placeholder, not final brand art)
- [ ] App opens directly into `index.html`'s home/mode-select screen with no
      white flash before content paints
- [ ] Status/navigation bars render `#0a0a0a` (no light-theme flash)

## Four-mode functional pass

- [ ] Morning mode: breathing intro → NAME layer (if name set) → 12 slides →
      close → return-to-reality → home, completes without error
- [ ] Morning mode with no name set: NAME layer is skipped automatically
- [ ] Work mode: full run completes, all 12 slides/images render
- [ ] Night mode: full run completes, all 12 slides/images render, pacing is
      visibly slower than Work
- [ ] Adversity mode: full run completes; binaural audio plays and responds
      to on/off + stop controls
- [ ] Back-navigation / Home affordance returns to mode select from every
      mode without crashing

## Offline behavior (the actual point of this shell)

- [ ] Enable Airplane Mode, force-stop the app, relaunch: all four modes
      still work identically (this is the real test — file:///android_asset
      has no network dependency at all)
- [ ] Confirm no network requests are attempted (e.g. via `adb logcat` or a
      proxy) — there is no INTERNET permission, so any attempt should simply
      fail silently, not crash

## WebView hardening (matches README security section)

- [ ] Tapping any element that would be an external link (if present) does
      not open Chrome/an external browser — navigation outside
      `file:///android_asset/` must be blocked in-place
- [ ] No file picker appears for any control (file chooser is intentionally
      unimplemented)
- [ ] Rotating the device is a no-op (orientation is locked portrait)
- [ ] Recent-apps thumbnail does not leak sensitive content differently than
      expected (standard WebView behavior, no explicit secure-flag requested)

## Process / lifecycle

- [ ] Home button → relaunch from recents resumes without reloading from
      scratch (state may reset since this is a plain WebView with no
      explicit state persistence — confirm this is acceptable, or file a
      follow-up if mode-in-progress should survive backgrounding)
- [ ] Backgrounding during Adversity mode audio stops/pauses audio
      appropriately (verify no audio leak after `onDestroy`)
- [ ] No ANR or crash across a full run of all four modes back-to-back

## Explicitly out of scope for this checklist

- Release signing / Play Console upload readiness — tracked in
  `../../sales-ready/DAIMON-SALES-READY-REPORT.md`, not here
- Store listing assets, privacy policy, LP consistency — tracked in
  `sales-ready/`
