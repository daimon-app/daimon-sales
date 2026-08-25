# SALES RELEASE RUNBOOK

Status: CANONICAL REUSABLE RUNBOOK
Effective: 2026-08-26 JST
Owner: Zero / AI5

## 1. Purpose

This runbook turns the DAIMON MORNING Japan launch work into a reusable, quickly editable release structure for future products. It is an operational template, not a historical diary.

Goal:

`GitHub canonical -> product QA -> release artifact -> device QA -> sales page/payment -> creative production -> SNS accounts -> draft/upload -> Owner-only gates -> public release -> end-to-end verification -> measurement -> iteration`

Do not reconstruct this flow from chat history. Update this runbook when a reusable improvement is confirmed.

## 2. Fast-edit control block

For each product/release, edit this block first.

```yaml
product:
  name: "<PRODUCT_NAME>"
  edition: "<EDITION>"
  price: "<PRICE>"
  billing: "<ONE_TIME_OR_SUBSCRIPTION>"
  platform: "<ANDROID/PWA/etc>"
  canonical_repo: "<owner/repo>"
  canonical_branch: "<branch>"
release:
  artifact_type: "<APK/AAB/PWA/ZIP>"
  artifact_sha256: "<SHA256>"
  sales_url: "<URL>"
  payment_provider: "<PROVIDER>"
  publish_scope: "<SCOPE>"
marketing:
  lead_cm: "<CM_ID>"
  platforms: [instagram, x, youtube_shorts, tiktok]
  public_platform_target: 4
owner_gates:
  identity: true
  otp_captcha_biometric: true
  new_money: true
  unapproved_public_publish: true
  destructive_irreversible: true
```

## 3. Release state machine

Use these states consistently:

- `CANONICAL_READY`
- `PRODUCT_QA_READY`
- `ARTIFACT_READY`
- `DEVICE_QA_READY`
- `SALES_PAGE_READY`
- `PAYMENT_READY`
- `CREATIVE_READY`
- `POST_READY`
- `WAITING_OWNER` only for genuine Owner-only gates
- `LIVE`
- `FUNNEL_E2E_PASS`
- `MEASURING`
- `FIX_REQUIRED`
- `BLOCKED_<CAUSE>`

One blocked platform/task must not stop unrelated lanes.

## 4. Canonical-first rule

Before work:
1. Read `MASTER.md`.
2. Read `APPROVAL_PERMISSION_MASTER.md` for approval/permission behavior.
3. Read this runbook.
4. Inspect current branch/code/evidence; do not assume old chat/ZIP state is current.
5. Record exact branch/commit/SHA for release-critical artifacts.

## 5. Product/release artifact lane

Required evidence where applicable:
- application/package ID
- version name/code
- min/target SDK
- permissions
- build/lint/tests
- signature
- artifact SHA-256
- secret scan
- device compatibility
- rollback/recovery

Never call an artifact READY from a filename alone; hash and actual decode/install/build evidence where relevant.

## 6. Pixel / device QA lane

For Android releases, prefer AI-controlled Pixel/ADB/Operator work. Owner should not be asked to search settings or move files when AI routes exist.

Verify as applicable:
- install/launch
- UI flow
- audio
- navigation/back/home
- permissions
- offline/network behavior
- purchase/delivery/install instructions
- screenshots/video evidence

Owner-only Android gates: biometric/identity/OS-protected action that automation cannot legally/technically perform.

## 7. Sales page + payment lane

Before traffic:
- product name matches canonical
- price matches canonical
- billing model matches canonical
- Android/platform requirement visible
- Early Access/production status accurate
- refund/terms/privacy/support links present as required
- CTA text matches actual sale state
- no stale text such as `販売開始前` when sales are LIVE
- payment link valid

E2E:
`SNS/profile -> sales page -> product/price -> consent -> purchase CTA -> payment boundary`

Do not create a real charge merely to repeat a previously evidenced payment E2E unless specifically required.

## 8. Creative engine

Do not rely on one CM. Maintain a creative inventory with distinct jobs.

Reusable roles:
- Discovery
- Experience/product demo
- Brand memory
- Product/WHY
- Problem/pain
- Return/recovery message
- Price/value
- Trust
- Feature
- Phrase/content series

For each asset record:
- CM/content ID
- hook
- target
- purpose
- script
- narration/source/license
- subtitles
- CTA
- duration
- platform variants
- evidence/claim limits
- SHA-256
- technical QA
- Owner QA if genuinely required

Scientific claims must be evidence-mapped. Do not use psychology/behavioral economics/cognitive science/neuroscience merely as authority decoration.

## 9. Media technical QA

For short vertical video, record actual properties rather than assuming them. Typical DAIMON launch target used:
- 1080x1920
- vertical 9:16
- H.264
- 30fps
- AAC-LC 48kHz stereo
- full-duration decode PASS
- narration/audio present
- burned subtitles where required
- safe-zone/CTA check

Old/superseded/muted assets must be clearly prohibited from posting.

## 10. SNS account lane

Maintain one canonical account inventory. Never create duplicate accounts simply because one session is unavailable.

For each platform record:
- official handle/channel
- authenticated device/session
- profile icon/name/bio
- clickable sales route
- draft/composer state
- upload capability
- publication state
- public post URL/ID

## 11. Platform publication lanes

### Instagram
Verify:
`video -> caption/CTA -> AI/synthetic disclosure if applicable -> PUBLIC -> profile clickable link -> sales page E2E`.

### X
Verify correct official composer/account before posting. Then:
`video -> post text/CTA -> PUBLIC -> public URL -> profile/sales funnel`.

### YouTube Shorts
Known reusable failure mode: local MP4 handoff/file permission can block after channel auth and upload UI are already PASS.

Recovery order:
1. verified local file path + SHA
2. Studio file input
3. supported browser/file upload automation
4. Windows file picker automation
5. safe simple staging path
6. drag/drop only if safely automatable
7. genuine Owner OS-protected gate only as last resort

After upload:
`processing -> title/description/CTA -> disclosure -> playback QA -> PUBLIC -> sales route`.

Do not repeat a failed transport path indefinitely; record `FAILED/UNSUPPORTED` and move to the next safe route.

### TikTok
Prefer an already-authenticated session/device. If Pixel is logged in and USB/Operator/ADB are available, test that route before requiring a separate PC login.

`session -> official account -> file handoff -> caption/hashtags/CTA -> disclosure -> preview -> PUBLIC -> playback/funnel`.

Owner login/OTP/CAPTCHA/biometric is isolated to TikTok; other lanes continue.

## 12. Publish authorization

Read `APPROVAL_PERMISSION_MASTER.md`.

A Publish GO is scoped. Once the Owner explicitly grants publication for a defined product/media scope, do not ask for the same approval repeatedly unless the scope materially changes.

Normal draft/upload/QA/technical preparation is not a Publish Gate.

## 13. Post-publication proof

A button click is not PASS. For every published post capture:
- platform
- official account
- public URL/post ID
- JST publication time
- asset ID + SHA
- visibility = PUBLIC
- actual playback/video/audio/subtitles
- caption/CTA
- sales route

Only then mark `LIVE = PASS`.

## 14. Measurement

Never invent unavailable metrics and never treat `null` as zero.

Track when available:
- views
- 2/3-second hold
- completion/retention
- likes/comments/shares/saves
- profile visits
- sales-link clicks
- LP visits
- checkout starts
- paid purchases
- refunds
- install/delivery success
- support requests

Link metrics to platform + post ID + CM/content ID.

## 15. Organic recognition loop

Free distribution strategy is not repeated identical spam. Use multiple angles so the same audience can recognize the brand repeatedly:

`UNKNOWN -> RECOGNIZED -> INTERESTED -> PROFILE -> SALES PAGE -> CHECKOUT -> PURCHASE`

Maintain a queue across product demo, WHY, problem, return/recovery, price, trust, brand and phrase/content series. Use actual performance to decide what to repeat/cutdown/retire.

## 16. AI5 responsibilities

- Zero: canonical specification, prioritization, integration, GitHub canonical management.
- Codex: implementation, builds, upload/publish automation, QA, evidence and measurements.
- Claude: difficult technical review/implementation and claim-quality review.
- Gemini: market/competitor/research/hook/data analysis.
- Manus: web/sales/LP/SNS conversion review and production support.

Do not make all AIs perform identical work. Cross-check only where independence adds value.

## 17. Evidence and GitHub structure

Prefer stable paths that are easy to update:

```text
MASTER.md
APPROVAL_PERMISSION_MASTER.md
SALES_RELEASE_RUNBOOK.md
release/
  CURRENT_RELEASE.yaml
  CHECKPOINT.md
sales/
  FUNNEL_STATUS.md
marketing/
  CONTENT_QUEUE.md
  media-evidence.json
  claims/
evidence/
  YYYY-MM-DD/
```

Project-specific repos may use existing equivalent paths; do not create duplicate structures unnecessarily.

Keep `CURRENT_RELEASE.yaml`, `CHECKPOINT.md`, `FUNNEL_STATUS.md`, and `CONTENT_QUEUE.md` short and overwrite/update them as current-state documents. Put historical evidence in dated files. This keeps the system easy to edit without rewriting the runbook.

## 18. Failure isolation

- `WAITING_OWNER` blocks only its own lineage.
- One social platform failure does not block other platforms.
- One AI failure does not stop other AI tasks.
- Sales-page hotfix does not stop creative production unless the funnel is unsafe to expose.
- Creative production does not block already-approved publishing of a different ready asset.

## 19. Definition of done — Japan direct sales

A direct-sales launch is complete when the required target scope is explicitly defined and all required items are measured PASS, typically:
- product/release artifact ready
- device QA pass
- sales page current and production
- payment funnel pass
- required SNS platforms live
- public post playback pass
- profile/post sales routes pass
- measurement started
- evidence committed/pushed

Do not declare completion merely because files or drafts exist.

## 20. Google Play reuse pipeline

This runbook is intentionally structured so the same core can feed Google Play.

Reuse:
`GitHub canonical -> build/test -> signed artifact -> SHA/evidence -> Pixel QA -> listing assets/copy -> privacy/legal/data declarations -> console upload -> test track -> review gates -> production publish -> post-release measurement`.

Google Play-specific additions:
- signed AAB
- application ID/versionCode/versionName
- Play Console app configuration
- Store Listing assets/text
- App Content/Data safety declarations
- privacy policy URL
- testing-track requirements
- review/status handling
- staged/production release

Owner-only gates remain limited to genuine Google identity/consent/money/publication actions that cannot be automated.

## 21. Fast update rule

When a reusable lesson is discovered:
1. Update the smallest relevant section of this runbook.
2. Update current-state files separately; do not turn this runbook into a giant progress log.
3. Add a dated evidence record if the lesson came from an incident.
4. Commit with a focused message.
5. New tasks read the latest canonical files first.

This structure is designed so future releases can be changed by editing the control block/current-state files rather than rewriting the whole process.
