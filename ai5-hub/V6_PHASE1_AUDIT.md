# AI5 SALES FACTORY v6 — PHASE 1監査・施工証拠

日付: 2026-08-19  
Branch: `feat/ai5-sales-factory-v6`  
基準commit: `f20e001084d10810304a6fbf56215bdac70638b1`

## 監査結論

施工前のHUBはTask Engine、Project Control、Codex Bridge、承認tokenを持っていたが、Manus/Gemini実発行、共通Return Route、実働retry/fallback、Repository単位Single-Writer、M1〜M5 dashboardが未接続だった。この状態でのLIVE 5商品投入はNO-GOと判定した。

## 不足分施工

- Task v6契約: project/product/objective/AI/support/writer/priority/source commit/output/acceptance/status/retry/parent/timestamps。
- Result v6契約: result/verdict/evidence/files/commit/tests/QA/blockers/resource/approval/next action。
- Manus/Gemini外部outboxと認証済みZero Return API。
- Manus/Gemini結果受領後のClaude独立監査とZero completion gate。
- bounded retryとClaude/Manus/Gemini/Codex fallback。
- Repository path/branch/HEAD/writer固定lock。同一対象の第二Writer拒否。
- Approval語彙拡張: 課金、契約、広告、OAuth、2FA、CAPTCHA、本人確認、SNS、DM、main merge、本番、Play、販売、秘密、不可逆操作。
- nested secret redaction、全task idempotency検索、payload conflict拒否。
- M1〜M5 Project正本とSales Factory dashboard、AI別LINE風結果表示。
- Service Worker cache削除をAI5 HUB prefixへ限定。

## M1〜M5固定対象

| ID | 商品 | Repository / branch / source commit | 初期状態 |
|---|---|---|---|
| M1 | P02 一手箱 | `daimon-app/ittebako` / `product/p02-sales-ready` / `9674f51` | TECH READY、Owner情報待ち |
| M2 | DAIMON本体 | `daimon-app/daimon-sales` / v6専用branch / `f20e001` | PROTECTED、read-only監査のみ |
| M3 | 明日の一手メモ | `daimon-app/ashita-itte-memo` / `main` / `bac5757d` | 商品境界VALIDATION |
| M4 | 瞑想タイマー | `daimon-app/daimon-meditation-timer` / `main` / `651e5830` | 音源権利・Storage gate |
| M5 | 切り替えスイッチ | `daimon-app/genba-break-switch` / `main` / `daaf6170` | 音源権利・Storage gate |

## QA

- 既存test群9/9: PASS。
- v6追加test群3/3: PASS。
- Repository Writer Lock: 同一repo/branchへの第二Writer拒否PASS。
- Zero Return: task ID不一致拒否、正常result変換PASS。
- Local API: session/health/factory取得PASS。
- Sales Factory DRY RUN: 10/10 task生成。Manus 5、Gemini 5、永続化0。
- `git diff --check`: PASS。

## LIVE gate

`PHASE 1 code → Claude独立監査 → Zero修正判定 → 全QA再実行` がPASSするまでLIVE投入しない。main merge、本番公開、SNS投稿、販売開始、課金、AAB/Play公開は未実施。
