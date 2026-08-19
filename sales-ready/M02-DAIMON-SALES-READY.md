# M02 — DAIMON SALES READY EXECUTION

Status: ACTIVE
Owner: Zero
Date: 2026-08-19

## Mission
DAIMON本体を本人承認直前のSALES READYまで施工する。旧監査だけで商品構成を固定せず、最新4モード実装を基準に再判定する。

## Source priority
1. ユーザー最新明示指示
2. GitHub正本・最新実装
3. MASTER.md / 販売正本
4. 過去監査・旧ZIP・旧会話

## Verified starting point
- Repository: daimon-app/daimon-sales
- main latest observed: 7df7e2bb423593535dced1b7277587cd97bdc9c6
- work/night media implementation exists in e5ba2bb423593535dced1b7277587cd97bdc9c6? NO: correct implementation commit is e5ba2bbcb3127f364dac86782c0465f0095fbc66.
- MASTER.md is stale in its status prose: it still contains older v7/current-focus language despite later work/night implementation.
- AGENTS.md: not present on main at audit start.
- README.md: not present on main at audit start.
- marketing branch contains Morning-only assumptions. Those assumptions are NOT authoritative for M02 until latest four-mode product audit is complete.

## Product doctrine
DAIMON is not sold as a mere affirmation player. Core value: 「ズレる → 気付く → 戻る」. Position as a self-direction / habit-support product grounded in actual implemented behavior. No medical, psychological, financial, or guaranteed-outcome claims.

## Mandatory audit scope
- latest completed artifact
- morning / work / night / adversity
- audio, stop, navigation, back, home
- persistence/storage
- onboarding
- mobile/PWA/offline
- product positioning
- market/competitors/pricing/sales model
- LP/FAQ/privacy/terms/commercial disclosures/contact/refund
- SNS/store funnel
- sales QA and first-time-buyer final audit

## Technical gate
Any code defect discovered is recorded as TECH_FIX_REQUIRED with reproduction, expected behavior, affected file/feature, acceptance criteria, regression scope, and evidence required. Technical uncertainty must never be relabeled PASS.

## Owner approval gate
Do NOT merge main, publish production, start sales, charge money, buy services/ads, or publish SNS posts without explicit owner approval. Everything else that can be prepared safely should continue.

## Final buyer audit
Judge as a first-time buyer:
- meaning understandable within seconds
- not suspicious/misleading
- price/value coherence
- use is obvious
- four-mode value is communicated if four-mode product is selected
- post-purchase path has no dead end
- legal/contact/refund/support are complete

## Final report schema
DAIMON SALES READY REPORT
Repository:
Commit:
4 Modes:
Technical Status:
Product Position:
Price:
LP:
Legal:
Privacy:
FAQ:
SNS:
Store:
Mobile QA:
Final Audit:
Technical Fix Required:
Owner Info Required:
SALES READY:
本人承認 Required:
Next Action:
