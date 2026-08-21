# DAIMON Android / Google Play release pack

Date: 2026-08-20  
Candidate: four-mode DAIMON  
Status: `READY FOR OWNER DEVICE QA / SIGNING / STORE INPUT`

## Release identity

| Field | Candidate | Status |
|---|---|---|
| Product | DAIMON | FIXED |
| Package / applicationId | `app.daimon` | PROVISIONAL — confirm unused in Play Console before first upload |
| Version | `1.0.0-beta.1` (`versionCode 1`) | RELEASE CANDIDATE |
| Min / target SDK | 23 / 35 | VERIFIED IN SOURCE |
| Distribution | Google Play, Android App Bundle | CANDIDATE |
| Business model | One-time purchase, no ads | RECOMMENDED; final price is `OWNER_INPUT_REQUIRED` |
| Category | Lifestyle | CANDIDATE; select during Console entry |

Do not rename the package after the first production Play upload. If `app.daimon`
is unavailable or conflicts with an owned package, choose the replacement before
signing and rebuild/re-audit the artifact.

## Artifact evidence

- Unsigned release AAB: BUILD PASS
- SHA-256: `04DCEC86FA103200BFA77D019F95DCA6CDB71E077A660B29FE0B1EEED1427C81`
- Size: 5,283,964 bytes
- Reconciliation: the previous hash/size referred to an older unsigned build. The values above were independently matched between the current Gradle output and the delivered AAB on 2026-08-21. A signed build will have a new hash and must receive fresh evidence before upload.
- Evidence: `android/BUILD_EVIDENCE_2026-08-20.md`
- Production signing and Play upload: `OWNER_PHYSICAL_ACTION_REQUIRED`
- Installed-device behavior: `UNVERIFIED`

## Play listing draft

App name: **DAIMON**

Short description:

> 朝・仕事・夜・逆境。ズレた自分を、意図した方向へ戻す4モード習慣アプリ。

Long description:

> 人はズレる。集中が散る日も、疲れる夜も、思いどおりにいかない瞬間もある。DAIMONが重視するのは「一度もズレないこと」ではなく、気付いて戻れることです。朝・仕事・夜・逆境の4つのモードから、その瞬間に合う入口を選択。短い画面体験と音声コントロールを通して、自分が進みたい方向を思い出すための時間を作ります。DAIMONは医療、診断、治療、心理療法を提供するアプリではなく、特定の成果を保証しません。

Release notes:

> DAIMON初回リリース候補。朝・仕事・夜・逆境の4モード、音声ON/OFF、逆境モードのバイノーラル音、オフライン同梱コンテンツに対応しました。

## Store visual specification

No fake screenshots or device-pass claims may appear.

- App icon: current black/gold `D` candidate; final visual QA required.
- Feature graphic: 1024 x 500 candidate composition; DAIMON logo, “ズレたら、戻ればいい。” and four mode labels. No price or unverified claim.
- Phone screenshots: capture from the installed release candidate, portrait.
  1. Home — four modes visible
  2. Morning — intention screen
  3. Work — return-to-focus screen
  4. Night — low-stimulation screen
  5. Adversity — binaural/audio control visible
  6. Home return / simple navigation
- Screenshot captions must describe the screen, not promise an outcome.
- Tablet artwork: `UNVERIFIED / NOT REQUIRED FOR FIRST PHONE QA`.

## URLs and owner inputs

| Item | Current state |
|---|---|
| Privacy URL | `OWNER_INPUT_REQUIRED` — no public canonical URL recorded |
| Support URL | `OWNER_INPUT_REQUIRED` — no public canonical URL recorded |
| Seller/contact identity | `OWNER_INPUT_REQUIRED` |
| Final price | `OWNER_INPUT_REQUIRED` |
| Production signing key | `OWNER_PHYSICAL_ACTION_REQUIRED` |
| Play Console identity/upload | `OWNER_PHYSICAL_ACTION_REQUIRED` |

The URL fields must not be filled with guessed domains or local paths. Free
publication preparation may continue, but the published pages must contain the
same data behavior and actual seller/support information as the release artifact.

## Known limitations

- The AAB is unsigned for production and has not been installed from a Play track.
- Android device behavior, WebView speech synthesis, binaural perception and audio
  interruption behavior remain `UNVERIFIED` until the owner device batch runs.
- Android uses bundled `file:///android_asset` content and deliberately has no
  `INTERNET` permission; external links and file picking are disabled.
- The app does not preserve a mode-in-progress across process death.
- Local preferences may survive an app update but are removed by uninstall/clear
  storage; both flows require device verification.
- The current candidate has no account, cloud sync, analytics, ads, crash SDK or
  billing SDK. Adding any of these invalidates the Data Safety draft.

## Gate

Technical artifact: `PASS`  
Static release audit: `PASS`  
Device QA: `UNVERIFIED`  
Production signing: `OWNER_PHYSICAL_ACTION_REQUIRED`  
Legal/contact/price fields: `OWNER_INPUT_REQUIRED`  
Overall: `CONDITIONAL READY FOR USER APPROVAL — DEVICE/SIGNING/STORE INPUT ONLY`

