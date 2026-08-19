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
- M1〜M5とSNS母艦のProject正本、Sales Factory dashboard、AI別LINE風結果表示。
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
- Sales Factory DRY RUN（初期5商品）: 10/10 task生成。Manus 5、Gemini 5、永続化0。
- SNS母艦を追加し、LIVE時は合計12 task（Manus 6、Gemini 6）を独立outboxへ発行する構成。公開操作は禁止。
- `git diff --check`: PASS。

## 独立監査状態

- Claude Code CLI: `2.1.233`、ログイン済みProを確認。
- 正確な残り利用枠: 公式CLIから取得不可。
- 読み取り専用監査を2回試行したが、1回目は120秒timeout、2回目は`ConnectionRefused`で結果未回収。
- 自己監査だけでPhase 2を開始しないため、独立監査は`TIMEOUT / NOT PASSED`として扱う。
- 追加独立コード監査: `FAIL`。false PASS、lock lifecycle、Result spoof、送信前mask、typed approval、正本復元・証拠保存をPhase 2 blockerとして修正ループへ投入。
- 修正ループ2: Codex直接PASS除去、施工AI≠監査AI、担当AI一致、受入条件別outcome、明示PASS tests/QA、検証可能evidence形式、typed capability、GET/初回response token発行除去、dirty lock拒否、外部送信前mask、Source snapshot、runtime evidence exportを実装。全15 test PASS。
- 残存Phase 2 gate: 外部Claude/Gemini接続復旧、M1〜M5のremote GitHub正本復元、AI別署名Return、lock crash recovery、専用evidence branchへのsanitized commit。
- 修正ループ3: remote branch/commit/doc本文/file inventory/snapshot hash、one-time AI Return token、実在evidence resolver、受入条件identity照合、Codex worker lock解放、非完了stale lockのRECOVERY_REQUIRED化を実装。全16 test PASS。
- 現在の外部接続: Claude最小疎通timeout、Chrome Browser runtimeはtrusted path error。Manus/Gemini Bridgeを実測できないためPhase 2 LIVEは引き続きNO-GO。

## LIVE gate

`PHASE 1 code → Claude独立監査 → Zero修正判定 → 全QA再実行` がPASSするまでLIVE投入しない。現時点のPhase 2判定は`NO-GO（独立監査未完）`。main merge、本番公開、SNS投稿、販売開始、課金、AAB/Play公開は未実施。
