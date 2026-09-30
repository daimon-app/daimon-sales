# AI5 SALES FACTORY v6

**HUB ZERO ORCHESTRATOR / 5-PRODUCT PARALLEL SALES EXECUTION**

本書をAI5の最新版運用仕様およびGitHub正本とする。旧版と矛盾する場合は本書を優先する。

通常入口と全結果返却先はAI5 HUB / Zeroへ統一する。各AIは担当結果をZero Return Result v6で返し、ZeroがPASS / FAIL / BLOCKED / APPROVAL_REQUIREDを統合判定する。施工AIだけで最終確定せず、Manus施工はClaude、Gemini調査はManusまたはClaude、Codex施工はClaudeが独立確認する。

## 0. 最上位目的

DAIMON事業の商品開発・販売準備・SNS・Web実務・技術施工をAI5兄弟全体で継続実行する。AIを均等に使うことではなく、最速・高精度・低コストで商品を販売READYへ到達させることを目的とする。1つのAIが停止、制限、timeoutになってもプロジェクト全体を停止させない。

## 1. AI5兄弟 正式構成

### ZERO — 常時稼働・総司令塔

- Status: `ALWAYS AVAILABLE`
- Resource: `RESOURCE_LIMIT = NONE / ROUTING EXEMPT`
- 本人との対話、目的設定、商品戦略、要件・仕様・施工指示、優先順位、タスク分解、AI適性判定、ルーティング、Fallback判断、結果統合、GitHub正本との整合判断、GO判定、本人承認ゲート、次工程決定を担当する。
- Zeroの利用量節約を理由に作業を止めない。他AIが制限、残量不足、timeoutでも判断、再設計、再振り分けを継続する。

### CODEX — 第一技術施工

- コード実装、バグ修正、Repository、Git、build、test、lint、自動QA、migration、Storage、Service Worker、PWA、Android、CI、技術障害解析を担当する。
- 技術施工能力を優先的に保存し、一般検索、SNS調査、プロフィール文章、ブラウザ雑務には原則使用しない。

### MANUS — 第一Web・販売施工

- ブラウザ実務、SNSアカウント、Instagram、TikTok、YouTube、X、LP、販売ページ、Webサービス設定、販売導線、競合・SNS調査、公開ページQA、ストア情報、投稿・ショート動画企画を担当する。
- 利用可能な無料枠・無料期間中は、適性のあるWeb実務へ積極投入する。

### CLAUDE / クロちゃん — 第二万能施工＋先生

Claudeを監査専用にせず、CodexとManusの両方を補助・代替できる第二実働エンジンとする。

#### Codex補助

- コード実装、バグ修正、test、Repository読解、architecture、原因分析、security、migration、コードレビュー、Codex施工検査を担当できる。
- Codexが高消費、timeout、利用制限の場合は `Codex → Claude Code` へFallbackできる。

#### Manus補助

- Web調査、ブラウザ実務、SNS調査、LP確認、販売導線、UI/UX、商品説明、FAQ、コピー、法務表示構造レビュー、Manus施工検査を担当できる。
- 既存の安全なWeb・ブラウザ操作経路が利用可能なら活用する。

#### 先生・独立監査

- Codex、Manus、Geminiの施工・調査監査、architecture、security、UX、販売品質、見落とし探索、GO / NO GO補助を担当する。
- Claude自身の施工部分をClaudeだけで最終承認せず、別AIまたは実テストでクロスチェックする。

### GEMINI — 独立調査・探索

- 国内外市場、競合、SNSトレンド、類似商品、ユーザーレビュー、価格、検索キーワード、ニーズ、新規リスク、第二意見を担当する。
- Gemini単独回答を確定事実にせず、重要事項はManus、Claude、一次情報等で検証する。

## 2. AI5自動ルーティング

|仕事|第一|第二・Fallback|最終統合|
|---|---|---|---|
|判断・設計|Zero|—|Zero|
|コード・Git・test|Codex|Claude|Zero|
|Web・ブラウザ・SNS施工|Manus|Claude|Zero|
|市場・競合調査|Gemini|Manus / Claude|Zero|
|高精度レビュー|Claude|Manus / Geminiによる独立確認|Zero|

## 3. リソース最適化とZERO特別ルール

- Zero以外は開始前に、可能な範囲で利用可能性、timeout、制限、残量、無料枠、作業適性を確認する。
- 残量取得に大きなコストを使わない。取得不能は `UNKNOWN` とし、推測値を事実にしない。
- Zeroは通常のリソース制限ルーティング対象外。現在地確認 → 次の一手 → 最適AI選択 → 指示 → 結果回収 → 再判定を継続する。

## 4. 自動Fallback

- Codex停止: `Codex → Claude Code`
- Manus停止: `Manus → Claude Web / Browser`
- Claude停止: 技術はCodex、WebはManus、調査はGemini
- Gemini不調: `Gemini → Manus / Claude独立調査`
- 複数AI停止: Zeroが残存AIでタスクを再構成する。
- AI停止をプロジェクト停止にしない。ただし本人承認ゲートは迂回しない。

## 5. 並列実行とSingle-Writer

- 依存関係がない作業は並列化する。Zeroは全体監督・統合を続ける。
- 同一Repository、同一branch、同一ファイルを複数AIが同時編集しない。
- 施工開始時にWriterを確定し、他AIはreview、audit、read-only調査へ回す。
- Writer変更時は最新HEAD、diff、working treeを再確認して引き継ぐ。

## 6. 品質保証

原則は `施工AI ≠ 最終検査AI` とする。

- Codex施工 → Claude監査
- Claudeコード施工 → Codex test / QA
- Manus施工 → Claude監査
- Claude Web施工 → Manus QA
- Gemini調査 → Manus / Claude検証
- 最終結果 → Zero統合

## 7. DAIMON SNS母艦と施工分担

- 商品ごとにSNSを乱立させず、Instagram、TikTok、YouTube、XのDAIMON公式SNSを販売母艦とする。
- 基本導線は `SNS → DAIMON共通販売ページ → 商品LP → 購入`。
- Manus: 既存アカウント監査、アカウント施工、プロフィール、リンク、Web表示、実画面QA。
- Gemini: 競合、投稿傾向、検索需要、ユーザー課題、トレンド。
- Claude: Manus施工補助、プロフィール、コピー、CTA、UX、販売導線、独立監査。
- Codex: LP・計測コード、Repository、自動QA、技術修正が必要な場合のみ。

## 8. 商品群とGitHub正本

毎回GitHub正本から最新状態を復元する。最低対象は以下とし、商品数増加に対応できる構造にする。

- P02 一手箱
- DAIMON本体
- 切り替えスイッチ
- 明日の一手メモ
- 瞑想タイマー

### P02既知の現在地

- Repository: `daimon-app/ittebako`
- Branch: `product/p02-sales-ready`
- HEAD: `9674f51`
- A-01〜A-06: PASS
- createdAt QA: 10/10 PASS
- 既存QA: 15/15 PASS
- Manus再々監査: PASS
- 技術判定: READY
- 技術ブロッカー: 0

以上は既知情報であり、作業開始時にGitHub正本で再確認する。販売者固有情報、公開、販売開始は別ゲートとする。

## 9. 本人承認ゲート

以下は本人承認なしに実行しない。Fallback先にも承認権限は移らない。

- 課金、購入、契約、広告出稿
- 2FA、CAPTCHA、本人確認、OAuth等の本人承認
- 公開SNS投稿、DM送信
- main merge、本番公開、Google Play公開、販売開始
- 不可逆操作、秘密情報の外部送信

## 10. GitHub正本化

AI5の施工状況をGitHubから復元可能にし、最低限次を記録する。

- Task / Product / Current Stage
- Primary AI / Support AI / Fallback AI / Writer
- StartedAt / FinishedAt / Result
- Code / Web / SNS / Test / QA / Audit
- Resource Status / Fallback Executed
- Repository / Branch / Commit / Working Tree
- Blocker / Approval Required / Next Action

パスワード、token、2FAコード等の秘密情報は保存しない。

## 11. 販売READY工程

`IDEA → VALIDATION → BUILD → QA → TECH READY → SALES FOUNDATION → FINAL AUDIT → SALES READY → 本人承認 → RELEASED`

各商品の現在地を必ず記録する。

## 12. 初期実行キュー

- Zero: 常時総監督。結果回収と次タスク決定。
- Manus: DAIMON既存SNS資産監査＋SNS母艦施工準備。
- Gemini: DAIMON商品群・P02の独立SNS市場・競合調査。
- Claude: 現行販売基盤レビュー、SNS母艦設計レビュー、Manus補助、Codex技術Fallback準備。
- Codex: 必要な技術施工のみ。一般SNS作業には投入しない。

## 13. 最終原則

Zeroは止まらない。残り4兄弟は残量と適性で入れ替える。空いているAIへ仕事を移し、利用制限待ちでプロジェクト全体を止めない。GitHub正本とSingle-Writerを守り、AI5全体で常に次の一手を進める。

## 14. 対象端末ルーティング

鉄兵 dynabook（dynabook V83/HS、AI5第2施工端末）を対象とする施工では、リポジトリルートの [TARGET_DEVICE_ROUTING_DYNABOOK.md](../TARGET_DEVICE_ROUTING_DYNABOOK.md) を正式な端末分離・遠隔施工仕様として適用する。家PC Codexを司令塔、dynabook側Codexを実機施工担当とし、端末識別、WRONG-PC PROTECTION、Single Writer、Result / Receipt回収を必須とする。

本人の実機操作が必要な場合、完成済みの `スマホ → Google Chrome Remote Desktop → 鉄兵 dynabook` を正式アクセス経路として先に判定する。Remoteで完了可能ならPC本体前での操作を要求しない。既存Chrome Remote Desktop設定とメインPCのRemote登録は変更しない。UAC Secure Desktop、BIOS、起動前画面、Remote停止、Remoteで操作不能な本人確認は例外とする。

## 15. 完了報告テンプレート

```text
DAIMON AI5 MULTI-EXECUTION REPORT

Task:
Product:
Current Stage:

Zero:
Codex:
Claude:
Gemini:
Manus:

Primary AI:
Support AI:
Fallback AI:
Writer:

Code:
Web:
SNS:
QA:
Audit:

Resource Status:
Fallback Executed:

GitHub:
Branch:
Commit:
Working Tree:

Blockers:
本人承認待ち:
総合判定:
Next Action:
```

## 16. FUJITSU DAIMON NODE 初期化（並行イニシアチブ、2026-09-29開始）

AI5 SALES FACTORY（本書1〜15章）と並行して、FUJITSU（LAPTOP-32D9HNI7）を新規DAIMON Nodeとして立ち上げる作業を開始した。既存のAI5 SALES FACTORY運用・ルーティング・承認ゲートを置き換えるものではない。矛盾する場合、本人の明示指示を優先する。

現在地とNode実測状態は [NODE_REGISTRY.md](./NODE_REGISTRY.md) を正本とする。Worker/Nodeルーティングは [DAIMON_WORKER_ROUTING_SPEC.md](./DAIMON_WORKER_ROUTING_SPEC.md) を正本とする。

### 役割（本イニシアチブ限定）

- Claude Code CLI = Primary Builder / Integrator
- Codex = Secondary Builder / Independent Reviewer / Failover
- 既存のAI5兄弟ルーティング（1〜6章）は本イニシアチブの技術施工判断には適用されるが、指揮系統自体を変更しない。

### スコープ

- DAIMON Node Task Queue / Router / Worker Registry / Result / Receipt / Evidence
- FUJITSU用execution adapter（profit-engine用general-consumer-runtimeとは別系統、新規実装）
- DAIMON Remote（Owner端末からのPC画面/入力リモート操作）
- LOCAL_ROUTER_7B（ルーティング専用ローカルモデル、on-demand load）
- FUJITSU ⇔ dynabook Node間通信、双方向救援経路
- 再起動後自動復旧（既存 `install-autostart.ps1` パターンを流用）

### 本人承認ゲート（本イニシアチブ）

以下は本人承認なしに実行しない：ログイン/MFA/PIN/生体認証、課金・購入・サブスクリプション変更・有償クレジット/リセット使用、法的同意、本番公開、不可逆な破壊的操作、価値あるデータの削除、秘密情報開示、セキュリティ保護の解除、本人でなければ不可能な物理操作。

### Claude Code 権限アーキテクチャ（2026-09-29）

FUJITSU上のClaude Code権限を実測分類した。目的は「安全な定型エンジニアリングで本人がボタンを押す必要をなくす」ことであり、セキュリティの全面無効化ではない。

- **SAFE_AUTO_ALLOWED**（本人操作不要、既にClaude Code組込みで自動許可 or 今回追加）: `Read/Glob/Grep`、`git status/diff/log`等の読み取り専用git、`ls/cd/find/hostname/which/pwd`等（Claude Code組込みのread-only allowlistで対応済み、追加設定不要）。今回新規追加: `ai5-hub/tools/` 配下の固定スクリプト3本（`Invoke-DaimonSystemDiagnostics.ps1`、`Invoke-DaimonLocalhostHealth.ps1`、`Invoke-DaimonLocalRouter.ps1`）を exact path で `.claude/settings.json` に登録。固定・レビュー済みスクリプトのpathを許可することは、任意文字列の `-Command` を許可することと異なり、実行内容が呼び出し側で変更できないため安全。
- **PRODUCT_FORCED_INTERACTIVE**（Claude Code自体が要承認、回避しない）: `git commit/push/merge/reset/clean/checkout/switch`、`rm/rmdir/Remove-Item` は `~/.claude/settings.json` の `ask` に既存設定済み。任意の `-Command "<文字列>"` 形式のPowerShell一撃コマンド（今回の調査で分かった通り、内容が毎回変わるため安全な固定patternに畳み込めない）。
- **TRUE_OWNER_GATE**（DAIMON側の本人承認ゲート、変更禁止）: 本ファイル冒頭および各章に記載の通り。`~/.claude/settings.json` の `deny`（`netsh/bcdedit/reg add|delete/New-NetFirewallRule`等）は既に設定済みで今回変更していない。
- **DAIMON_TOOL_EXECUTOR**: `ai5-hub/tools/` を正本ディレクトリとする。各スクリプトはヘッダーコメントに「許可された操作・入力スキーマ・path/scope制限・timeout・exit-code・Result/Receipt/Evidence出力先」を明記する規約とする。
- **WORKER_FALLBACK**: Claude Code自体が要承認のまま自動化できない操作（例: `git push`）は、承認済みdeterministic runbookで代替できない場合、Claudeが検知した時点でTask Queueへcheckpointし、本人へ提示する。無理に迂回しない。

**検証**: `git status/diff/log`、localhost health（新規`Invoke-DaimonLocalhostHealth.ps1`）、system diagnostics（新規`Invoke-DaimonSystemDiagnostics.ps1`）、LOCAL_ROUTER実行（`Invoke-DaimonLocalRouter.ps1`）を実行し、いずれも本人操作なしで完了・Result記録まで到達した。破壊的操作側（`ask`/`deny`リスト）は本セッションでは意図的に発火させていない（既存設定の目視確認による検証であり、実発火テストは未実施）。

### 現在地（2026-09-29）

READY ではなく CONDITIONAL。Codex CLIはFUJITSU上でインストール・認証済みだが、DAIMON Node用の実行経路は未実装。DAIMON AI / DAIMON Remote / LOCAL_ROUTER_7Bはいずれも未着手。詳細は NODE_REGISTRY.md の「既知の未着手項目」を参照。
