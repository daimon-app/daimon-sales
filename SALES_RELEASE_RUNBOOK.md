# SALES RELEASE RUNBOOK

Status: CANONICAL REUSABLE RUNBOOK
Effective: 2026-08-26 JST
Owner: Zero / AI5

## 1. Purpose

This runbook turns the DAIMON MORNING Japan launch work into a reusable, quickly editable release structure for future products. It is an operational template, not a historical diary.

Goal:

`GitHub canonical -> behavioral-science design -> product QA -> release artifact -> device QA -> sales page/payment -> evidence-based creative production -> SNS accounts -> draft/upload -> Owner-only gates -> public release -> end-to-end verification -> measurement -> iteration`

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
behavioral_science:
  required: true
  domains:
    - psychology
    - behavioral_economics
    - cognitive_science
    - neuroscience
    - human_factors
    - behavioral_design
  evidence_map: "<PATH_TO_EVIDENCE_MAP>"
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

## 3. Mandatory behavioral-science design baseline

Every new app/product and every CM/marketing creative must begin with an explicit behavioral-science design pass. This is a default production requirement, not an optional late-stage decoration.

Required domains to consider where relevant:
- psychology, including applicable subfields such as cognitive, social, motivational, learning, attention, memory, emotion, habit and decision psychology
- behavioral economics and judgment/decision-making
- cognitive science
- neuroscience / neuropsychology where the evidence genuinely supports the design choice
- human factors / ergonomics / cognitive load
- behavioral design, habit formation and behavior-change research
- persuasion/communication research where ethically appropriate

“Use all” means **systematically evaluate all relevant domains and use every supported principle that improves the product/creative for its intended purpose**. It does not mean forcing every named discipline or effect into every screen, phrase or CM.

### Required workflow before implementation
1. Define target user, context, desired behavior/outcome and constraints.
2. Generate a behavioral-science evidence map.
3. Map candidate principles to concrete product/creative elements.
4. Classify each claim/design rationale by evidence strength.
5. Reject unsupported, irrelevant, manipulative or counterproductive applications.
6. Implement the strongest justified design.
7. Test actual behavior/usability/conversion and revise from evidence.

### Evidence map minimum fields
For each material design choice or marketing claim, record:
- `ELEMENT`
- `USER_PROBLEM_OR_BEHAVIOR`
- `DOMAIN`
- `PRINCIPLE_OR_MECHANISM`
- `IMPLEMENTATION`
- `EXPECTED_EFFECT`
- `EVIDENCE_SOURCE`
- `EVIDENCE_STRENGTH`
- `LIMITATIONS`
- `CLAIM_LEVEL`
- `MEASUREMENT`

### Claim levels
- `A`: strong enough for the intended factual claim, with suitable evidence
- `B`: reasonable design rationale but avoid overstating causal/clinical effects
- `C`: hypothesis to test; do not market as established fact
- `PROHIBITED`: unsupported/misleading claim; do not use

### Guardrails
- Do not use scientific terminology merely as authority decoration.
- Do not claim “scientifically proven”, “changes the brain”, “guarantees success”, clinical benefit, or other strong causal effects without evidence that supports that exact claim and context.
- Distinguish a scientifically informed design from a scientifically proven outcome.
- Do not use dark patterns, deceptive scarcity, hidden costs, coercive defaults or intentionally confusing consent.
- Optimize for durable user value, comprehension, appropriate motivation and low friction—not manipulation for its own sake.

### Product-design application
Before coding a new app or material feature, explicitly evaluate behavioral-science implications for:
- onboarding
- information architecture
- cognitive load
- choice architecture
- defaults
- friction and activation energy
- attention and salience
- motivation and self-efficacy
- habit/re-entry design
- reminders and timing
- feedback/reward
- progress representation
- error recovery
- trust and transparency
- language/framing
- accessibility and human factors
- retention without coercion

The product architecture should embody supported principles rather than adding psychology language after implementation.

### CM/marketing application
Before scripting/rendering a CM, explicitly evaluate:
- audience state/problem
- hook/attention
- product comprehension
- memory/brand recall
- framing
- loss/gain framing where appropriate
- social proof only when genuine
- ambiguity reduction
- cognitive fluency
- price/value framing without deception
- CTA friction
- repetition/frequency strategy
- sequencing across multiple creatives
- trust/credibility
- evidence limits for scientific claims

Creative production starts from this map, then moves to script/storyboard/rendering.

## 4. Release state machine

Use these states consistently:

- `CANONICAL_READY`
- `BEHAVIORAL_SCIENCE_MAP_READY`
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

## 5. Canonical-first rule

Before work:
1. Read `MASTER.md`.
2. Read `APPROVAL_PERMISSION_MASTER.md` for approval/permission behavior.
3. Read this runbook.
4. Inspect current branch/code/evidence; do not assume old chat/ZIP state is current.
5. Record exact branch/commit/SHA for release-critical artifacts.
6. For new app/product/feature/CM work, create or update the behavioral-science evidence map before final implementation/production.

## 6. Product/release artifact lane

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

## 7. Pixel / device QA lane

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
- behavioral-science design does not create usability/accessibility regressions

Owner-only Android gates: biometric/identity/OS-protected action that automation cannot legally/technically perform.

## 8. Sales page + payment lane

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
- framing/choice architecture is clear and non-deceptive

E2E:
`SNS/profile -> sales page -> product/price -> consent -> purchase CTA -> payment boundary`

Do not create a real charge merely to repeat a previously evidenced payment E2E unless specifically required.

## 9. Creative engine

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

Every CM must start from the behavioral-science evidence map in section 3 and explicitly state which supported principles are being used and why.

For each asset record:
- CM/content ID
- hook
- target
- purpose
- behavioral-science mechanisms used
- evidence references/claim level
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

## 10. Media technical QA

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

## 11. SNS account lane

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

## 12. Platform publication lanes

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

## 13. Publish authorization

Read `APPROVAL_PERMISSION_MASTER.md`.

A Publish GO is scoped. Once the Owner explicitly grants publication for a defined product/media scope, do not ask for the same approval repeatedly unless the scope materially changes.

Normal draft/upload/QA/technical preparation is not a Publish Gate.

## 14. Post-publication proof

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

## 15. Measurement

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

Behavioral-science hypotheses must also have measurable outcomes where practical. Use actual data to retain, revise or reject design hypotheses.

## 16. Organic recognition loop

Free distribution strategy is not repeated identical spam. Use multiple angles so the same audience can recognize the brand repeatedly:

`UNKNOWN -> RECOGNIZED -> INTERESTED -> PROFILE -> SALES PAGE -> CHECKOUT -> PURCHASE`

Maintain a queue across product demo, WHY, problem, return/recovery, price, trust, brand and phrase/content series. Use actual performance to decide what to repeat/cutdown/retire.

## 17. AI5 responsibilities

- Zero: canonical specification, prioritization, integration, GitHub canonical management, behavioral-science design requirements.
- Codex: implementation, builds, upload/publish automation, QA, evidence and measurements.
- Claude: difficult technical review/implementation and rigorous claim/design review.
- Gemini: market/competitor/research/hook/data analysis and evidence discovery.
- Manus: web/sales/LP/SNS conversion review and production support.

For important behavioral-science claims, use independent review where it materially reduces error. Do not make all AIs perform identical work.

## 18. Evidence and GitHub structure

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
behavioral-science/
  EVIDENCE_MAP.md
  SOURCES.md
evidence/
  YYYY-MM-DD/
```

Project-specific repos may use existing equivalent paths; do not create duplicate structures unnecessarily.

Keep `CURRENT_RELEASE.yaml`, `CHECKPOINT.md`, `FUNNEL_STATUS.md`, `CONTENT_QUEUE.md`, and the active behavioral-science map concise and updateable. Put historical evidence in dated files. This keeps the system easy to edit without rewriting the runbook.

## 19. Failure isolation

- `WAITING_OWNER` blocks only its own lineage.
- One social platform failure does not block other platforms.
- One AI failure does not stop other AI tasks.
- Sales-page hotfix does not stop creative production unless the funnel is unsafe to expose.
- Creative production does not block already-approved publishing of a different ready asset.
- A disputed/unsupported scientific claim blocks that claim, not unrelated implementation or publishing work.

## 20. Definition of done — Japan direct sales

A direct-sales launch is complete when the required target scope is explicitly defined and all required items are measured PASS, typically:
- behavioral-science map completed for material product/creative decisions
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

## 21. Google Play reuse pipeline

This runbook is intentionally structured so the same core can feed Google Play.

Reuse:
`GitHub canonical -> behavioral-science design -> build/test -> signed artifact -> SHA/evidence -> Pixel QA -> listing assets/copy -> privacy/legal/data declarations -> console upload -> test track -> review gates -> production publish -> post-release measurement`.

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

Store listing copy and promotional assets follow the same evidence-based behavioral-science/claim rules as other marketing creatives.

Owner-only gates remain limited to genuine Google identity/consent/money/publication actions that cannot be automated.

## 22. Fast update rule

When a reusable lesson is discovered:
1. Update the smallest relevant section of this runbook.
2. Update current-state files separately; do not turn this runbook into a giant progress log.
3. Add a dated evidence record if the lesson came from an incident.
4. Commit with a focused message.
5. New tasks read the latest canonical files first.

This structure is designed so future releases can be changed by editing the control block/current-state files rather than rewriting the whole process.
