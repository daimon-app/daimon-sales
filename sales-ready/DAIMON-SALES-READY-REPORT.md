# DAIMON SALES READY REPORT

Date: 2026-08-19
Branch: `zero/daimon-sales-ready-m02`
Release state: PRE-APPROVAL / TECH FIX REQUIRED

Repository: `daimon-app/daimon-sales`

Commit baseline audited: `main` latest observed `7df7e2bb423593535dced1b7277587cd97bdc9c6`

M02 sales branch commits:
- `0acf4fb41570e9c21374ba47259082931139ae41` execution source
- `251e54e32681ff2229b126353e0ca7a0c56a5df6` technical gates
- `0138bd6dad34b7a50616f097ab8c02a9f91830be` commercial pack

## 4 Modes
- Morning: implemented baseline exists.
- Work: implementation/media completion evidence exists in `e5ba2bbcb3127f364dac86782c0465f0095fbc66`.
- Night: implementation/media completion evidence exists in `e5ba2bbcb3127f364dac86782c0465f0095fbc66`.
- Adversity: **UNVERIFIED / P0**. No release evidence found sufficient to certify this as an implemented current main mode.

Current `manifest.json` describes a three-mode 朝・仕事・夜 product. Four-mode advertising is therefore blocked until implementation truth is unified.

## Technical Status
CONDITIONAL / TECH_FIX_REQUIRED.

Confirmed positive evidence:
- PWA manifest exists, standalone portrait configuration.
- service worker v9 exists.
- work/night image packs are in the SW shell.
- work/night implementation commit added audio toggle/stop and speech-synthesis path.
- `daimon.audioEnabled` persistence exists in localStorage in implementation diff.

Not certified:
- complete adversity mode
- signed four-mode Android RC
- four-mode device QA
- full persistence inventory
- four-mode onboarding
- all-layer Back/Home regression test
- complete offline four-mode test

## Product Position
**DAIMON — ズレたら、戻ればいい。**

Category: self-direction / habit reset support.
Core: 「ズレる → 気付く → 戻る」.
Not positioned as medical treatment, psychotherapy, diagnosis, success guarantee, wealth guarantee, or a generic affirmation audio player.

## Price
Recommended M02 launch: **¥980 one-time / Android / no ads**.

Reason: current release value is primarily a finite on-device experience. Subscription `¥2,500/month` is deferred until real recurring service value exists.

## LP
Buyer-facing copy, mode explanation, FAQ direction and CTA rules are prepared in `sales-ready/SALES_READY_PACK.md`.

Existing `feat/marketing-foundation` has a working Morning-only LP asset set, but it cannot be promoted as M02 truth without rebuilding its product copy around the actual final release candidate.

Pre-publication CTA: 販売準備中.
Post-approval CTA: Google Playで購入.

## Legal
Existing Morning-only branch contains draft Terms / Privacy / commercial disclosure / Contact pages. They are not final because owner identity and the actual final product/price remain unresolved.

Japan online-sales disclosure must match actual price and cancellation/return conditions. No placeholder is a release PASS.

## Privacy
NOT FINAL.

Rule established: derive Privacy + Google Play Data safety from release artifact network/storage/SDK inventory. Do not claim "no collection" without audit evidence.

Known persisted setting: `daimon.audioEnabled` localStorage.

## FAQ
Prepared in `sales-ready/SALES_READY_PACK.md` covering:
- product category
- four-mode purpose
- continuity philosophy
- non-medical scope
- no guaranteed outcomes
- ads
- price
- storage/privacy
- refunds

## SNS
Existing marketing branch already has channel setup, pinned post and 30-post inventory. M02 reuse is allowed only after replacing Morning-only claims with final release truth.

Primary M02 copy: **ズレたら、戻ればいい。**
No public posting without owner approval.

## Store
Existing marketing branch contains Play Store audit/checklist/console-answer-map/assets for the Morning edition.
M02 store listing draft is prepared in `sales-ready/SALES_READY_PACK.md`.

Google Play current rules allow paid-app country/region pricing through Play Console; final price entry is an owner approval action.

## Mobile QA
NOT PASS.
Existing release gate itself records signed APK device QA as incomplete. Four-mode signed RC QA is mandatory P0.

Required evidence:
- install/update launch
- all modes full run
- audio control
- Back/Home
- background/foreground
- offline restart
- persistence
- screenshots + recording + test log

## Final Audit
### First-time buyer view
- Meaning in seconds: PASS at copy/design level.
- Suspicion/overclaim risk: PASS if non-medical/no-guarantee wording retained.
- Price coherence: PASS for ¥980 recommendation.
- How to use: CONDITIONAL, onboarding needs release verification.
- Four-mode value: COPY PASS / IMPLEMENTATION FAIL until adversity is certified.
- Post-purchase navigation: CONDITIONAL, device QA pending.
- Legal/contact: FAIL until owner fields finalized.

## Technical Fix Required
YES.
Primary tracker: GitHub Issue #3.
Specification: `sales-ready/TECH_FIX_REQUIRED.md`.

## Owner Info Required
Only facts Zero cannot truthfully invent:
- official seller/business display name
- responsible operator display if applicable
- required address/phone handling
- support email/contact route
- target sale countries
- final acceptance of ¥980 one-time price
- final refund/cancellation commercial policy after store/legal alignment

## SALES READY
**NO — currently PRE-SALES-READY.**

This is not a marketing-content gap. Remaining blockers are release-truth/technical proof plus owner/legal identity fields.

## 本人承認 Required
At final gate only:
- final selling identity/contact/legal facts
- final price
- target countries
- main merge
- Play Console submission/publish
- production LP publish/CTA switch
- sales start
- SNS public posts
- paid services/ads if ever used

## Next Action
1. Resolve Issue #3 and create one four-mode signed release candidate.
2. Run device/offline/persistence/onboarding/navigation QA.
3. Regenerate Privacy/Data safety from the artifact.
4. Replace Morning-only marketing truth with final release truth.
5. Insert owner legal/contact facts.
6. Run final buyer audit.
7. Stop at owner approval immediately before main merge/publication/sale.
