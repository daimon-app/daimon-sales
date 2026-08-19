# DAIMON M02 — TECH_FIX_REQUIRED

Date: 2026-08-19
Status: P0/P1 RELEASE GATE

## P0-01 Four-mode truth mismatch
Observed evidence:
- `manifest.json` on main describes **朝・仕事・夜の3モード**.
- `sw.js` v9 precaches work/night media; no adversity asset pack is declared.
- commit history contains work/night completion evidence but no identifiable adversity/逆境 completion commit.

Required result:
DAIMON must not be advertised as a four-mode product until adversity mode is present in the release candidate and passes the same navigation/audio/mobile/offline acceptance criteria as the other modes.

Acceptance criteria:
1. Home visibly exposes 朝 / 仕事 / 夜 / 逆境.
2. 逆境 opens without placeholder/dead end.
3. 逆境 content fits portrait mobile without clipping or overlap.
4. Audio/binaural behavior matches the approved product specification and has a working stop action.
5. Back and Home always recover from the mode.
6. Offline reload after one successful online load works for all required assets.
7. Manifest/product copy and store/LP claims exactly match the implemented mode count.
8. Evidence: Android screenshots + screen recording + test log.

## P0-02 Release-candidate device QA
No four-mode signed Android release candidate has verified device evidence in the inspected source. Existing marketing release gate also leaves signed APK device QA incomplete.

Acceptance criteria:
- install/update launch PASS
- portrait layout PASS
- 朝/仕事/夜/逆境 full run PASS
- audio ON/OFF/stop PASS
- Back/Home PASS
- app background/foreground PASS
- offline restart PASS
- local persistence PASS
- no console-blocking runtime error

## P0-03 Legal/support identity injection
Public release must not contain placeholders for seller/support identity where legally or operationally required.

Acceptance criteria:
- seller/operator identity finalized
- support contact finalized
- commercial disclosure finalized
- refund/cancellation wording finalized and consistent with store policy
- same information reflected in app/LP/store where applicable

## P1-01 Onboarding verification
Current inspected evidence is insufficient to certify four-mode onboarding.

Acceptance criteria:
First launch explains, without marketing exaggeration:
- what DAIMON is
- core flow: ズレる → 気付く → 戻る
- what each mode is for
- audio control
- saved local settings/data, if any
- support/privacy access
The user must reach a first useful mode in <= 3 deliberate taps after onboarding.

## P1-02 Persistence inventory
Confirmed from implementation diff: audio-enabled preference is stored in `localStorage` (`daimon.audioEnabled`). All other persisted fields must be inventoried rather than assumed.

Acceptance criteria:
- enumerate every localStorage / IndexedDB / cookie key
- explain purpose and deletion path
- privacy/Data safety answers match actual behavior
- corrupt/missing storage fails safely

## P1-03 Navigation contract
Work/night share the mode engine, but release QA must explicitly certify Back/Home behavior from every layer.

Acceptance criteria:
- Back never exits into a broken layer
- Home always cancels current audio and returns to stable Home
- repeated taps/swipes cannot create overlapping audio
- mode completion returns predictably

## P1-04 Offline completeness
Service worker currently precaches shell plus work/night images and tolerates individual cache-add failures. A failed cache entry can therefore remain hidden until offline use.

Acceptance criteria:
- automated asset existence test before build
- first online load then airplane-mode full mode test
- required missing cache asset is a test failure, not silently ignored
- adversity assets included when four-mode release is selected

## P1-05 Product metadata synchronization
`MASTER.md`, `manifest.json`, marketing SSOT, store copy and release build must report the same product edition/mode count/price.

Do not release while Morning-only, three-mode and four-mode truths coexist.
