# AI5 LEARNINGS INDEX

Status: CANONICAL COMPACT INDEX / ROUTER
Effective: 2026-08-26 JST
Purpose: 最小token/creditで過去学習を再利用する入口

## READ THIS FIRST

新TaskではこのINDEXを最初に読む。全履歴全文ロードは禁止。

次に `AI5_OPERATING_SYSTEM.md` と対象商品の `MASTER.md` を読み、今回に必要なEvidenceだけ取得する。

## Canonical router

| Need | Read |
|---|---|
| 全体運用 | `AI5_OPERATING_SYSTEM.md` |
| 利益・億規模戦略 | `AI5_PROFIT_MISSION.md` |
| 制作前市場調査・販売数予測 | `PREBUILD_MARKET_GATE.md` |
| 販売・CM・SNS・Google Play工程 | `SALES_RELEASE_RUNBOOK.md` |
| 承認・許可 | `APPROVAL_PERMISSION_MASTER.md` |
| 売れる心理/行動設計 | `behavioral-science/SALES_EFFECT_LIBRARY.md` |
| 現在の商品仕様 | `MASTER.md` |

## Compressed reusable learnings

### L-001 — Canonical before chat history
- Chat断絶/新Task時に推測で続けない。
- GitHub正本を入口にする。
- ただし全Evidence全文ロードではなくINDEX→必要箇所。

### L-002 — Credit-efficient retrieval
- 全履歴を毎回読むとtoken/credit/time浪費。
- INDEX→関連正本→関連Evidence→不足時だけ深掘り。
- 同じ調査を無条件再実施しない。

### L-003 — Sellability before build
- 商品制作前に需要、WTP、競合、価格、到達可能性を調査。
- Sellability probabilityと7/30/90日Low/Base/High販売数・利益を予測。
- 実販売後に予測誤差を記録して次回補正。

### L-004 — Evidence ladder
`THEORY_ONLY -> MARKET_SIGNAL -> INTENT_SIGNAL -> CHECKOUT_SIGNAL -> PAID_SIGNAL -> REPEATED_PAID_SIGNAL -> PROFITABLE_SIGNAL -> SCALABLE_SIGNAL`

上位Evidenceを優先。

### L-005 — Behavioral-science-first
- アプリ/CM/LP等は制作前に心理学、行動経済学、認知科学、脳神経科学等を関連性/Evidenceに応じて検討。
- 根拠のないscience decorationは禁止。

### L-006 — Internal explanation after build
- 完成後、何の心理/科学をなぜ使い、顧客がどう行動し、どう販売につながるかをOwner/AI5内部向けに説明。
- 顧客向けへ自動転載禁止。

### L-007 — Learn actual sales effects
- 一般論ではなく自社データを蓄積。
- `CANDIDATE -> TESTED -> REPLICATED -> DEFAULT_PATTERN`。

### L-008 — Multi-creative recognition
- 1CMだけで終わらない。
- Discovery/WHY/problem/experience/price/trust/brand/phrase等の複数角度で認知→理解→購入へ。

### L-009 — Funnel must actually work
- CM再生数だけでは販売にならない。
- SNS/profile→sales page→price/terms→CTA→payment boundaryを実機E2E。
- stale/pre-launch文言をLIVE販売に残さない。

### L-010 — Platform failure isolation
- 1媒体BLOCKEDで他媒体/CM/LPを止めない。
- WAITING_OWNERはそのTask lineageだけ。

### L-011 — Owner gates
- 通常技術施工はapproval/permission不要が原則。
- identity/OTP/CAPTCHA/biometric/new money/unapproved publish/irreversible/legal consent/new secretを中心にOwner Gate。
- Codex Desktop Command approvalはAI5 policyと別layer。

### L-012 — Reuse before rebuild
- OSS、既存module、既存sales pipeline、CM template、Evidenceを優先再利用。
- 1商品目の苦労を2商品目のコスト削減資産にする。

### L-013 — Profit over vanity
- 最上位はnet profit/cash/return on capital-time。
- viewsだけで成功判定しない。

### L-014 — Scale evidence
- 小さく売って利益/需要を確認。
- 勝った商品・CM・導線へ資金集中。
- sunk costで弱い案を維持しない。

### L-015 — Google Play reuse
- Direct salesで固めたGitHub→build→artifact→Pixel QA→listing→publish→measurementの型をPlayへ転用。

## Product learning records

今後、各商品について以下だけを短く追記する。詳細はEvidenceへlink。

```text
PRODUCT:
DATE:
PRICE:
FORECAST_30D_LOW_BASE_HIGH:
ACTUAL_30D:
FORECAST_ERROR:
BEST_CHANNEL:
BEST_CREATIVE:
BEST_HOOK:
BEST_BEHAVIORAL_PATTERN:
FUNNEL_CVR:
PURCHASES:
REFUNDS:
NET_PROFIT:
TOP_OBJECTION:
TOP_FAILURE:
TOP_LEARNING:
EVIDENCE_PATH:
```

## Update rule

新しい学習が出たら：
1. 詳細Evidenceは既存の適切な場所へ保存。
2. このINDEXには再利用価値が高い要点だけ1〜5行で追加。
3. 重複learningは統合。
4. 古くなったものは `SUPERSEDED` として最新へlink。
5. INDEX自体を巨大レポート化しない。

## Context-ready rule

新Task開始時の最低条件：
- INDEX read = PASS
- OS read = PASS
- relevant MASTER read = PASS
- relevant evidence selected = PASS

これで `CONTEXT_READY`。

「全履歴全文read」は不要。
