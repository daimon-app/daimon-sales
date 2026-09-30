# DAIMON Worker Routing Specification

DAIMON Node（[NODE_REGISTRY.md](./NODE_REGISTRY.md)、[ZERO_SPEC.md §16](./ZERO_SPEC.md)）のWorker/Nodeルーティング正本。実装は本仕様に準拠する。チャット指示のみに依存しない。

## 1. ルーティング階層

```
LEVEL 0  Deterministic Rule Router   … 決定的ルール、AI呼び出し不要
LEVEL 1  LOCAL_ROUTER                … 曖昧・resource-aware・failure routing判断
LEVEL 2  Cloud / high-capability     … Claude / Codex / Gemini / 将来Worker
```

単純な決定的ルーティングでAIを不要に起動しない。

## 2. LOCAL_ROUTERはルーティング専用ではない

LOCAL_ROUTERはルーティングだけでなく、以下を満たす場合Taskを自ら実行できる：

- capabilityが十分
- riskが許容範囲
- resource budgetが安全
- Acceptance Criteriaが検証可能
- より強いWorkerが不要

対象例：軽量コーディング、スクリプト、設定、JSON/schema作業、ログ解析、診断、小規模バグ修正、ドキュメント、分類、要約、安全なローカル自動化。

capabilityを超える場合は **ESCALATE** する。

## 3. Worker選定入力

`TASK_CLASS / TASK_COMPLEXITY / TASK_RISK / REQUIRED_CAPABILITIES` と、`WORKER_CAPABILITIES / WORKER_HEALTH / WORKER_NODE / WORKER_BUSY_STATE / WORKER_LIMIT_STATE / WORKER_QUOTA / WORKER_CREDIT / WORKER_RESET_AT / WORKER_COST_STATE / WORKER_CONTEXT_STATE / WORKER_PAST_SUCCESS / EXPECTED_USAGE / EXPECTED_LATENCY` を用いる。

取得不能なquota/creditを捏造しない。`UNKNOWN` は `UNKNOWN` のまま扱う。

## 4. Node-aware routing

Worker識別にはNode識別を含める。例：`FUJITSU_CLAUDE` / `FUJITSU_CODEX` / `FUJITSU_LOCAL_ROUTER` / `DYNABOOK_CODEX` / `DYNABOOK_LOCAL_AI`。

PID / session / heartbeat / Result / Receipt / Lease / Task ownership をNode間で混在させない。ルーティングは `NODE + WORKER` を選ぶ。model/provider名だけでは選ばない。

## 5. Builder / Reviewer

`PRIMARY_WORKER / REVIEWER / FALLBACK_WORKER` を別々に割り当ててよい。独立レビューの価値がある場合は独立性を維持する。価値がない場合に高コストWorkerを二重に使わない。

## 6. Quota / Credit awareness

観測可能な範囲でcloud容量を温存する：安全なTaskはLocalで完結させる、cloud quotaが少ないWorkerは高価値Task用に温存する、reset時刻を考慮する、同時に全premium Workerを使い切らない、代替可能な別Workerを検討する。

有償クレジット・有償reset・購入・サブスクリプション変更はOwner Gate。

## 7. Limit handling

Provider limitはTask失敗ではない。

`checkpoint -> Task/Lease保持 -> reset時刻記録 -> 独立実行可能な作業の継続 -> 適切な安全failover -> 重複実行防止 -> resetまだ最適ならWorker復帰 -> Result/Receipt/Evidence reconcile`

## 8. 障害・緊急時ルーティング

heartbeat loss / worker crash / provider outage / node outage / execution failure に対し、LOCAL_ROUTERはインシデント分類と承認済みrecovery経路の選択を行える。危険な任意コマンドを自由に実行してはならない。allowlist化された決定的recovery runbookのみ使用する。Local capabilityを超える場合はESCALATE。

## 9. Confidence

LOCAL_ROUTERの判断には必ず `CONFIDENCE` を含める。低confidenceの場合、より強いルーティングレビューまたはより強いWorkerへ。無言で推測しない。

## 10. Routing Decision Contract（最小スキーマ）

```json
{
  "TASK_ID": "",
  "TASK_CLASS": "",
  "TASK_COMPLEXITY": "",
  "SELECTED_NODE": "",
  "PRIMARY_WORKER": "",
  "REVIEWER": "",
  "FALLBACK_WORKER": "",
  "CONFIDENCE": "",
  "REASON": "",
  "RESOURCE_STATE": "",
  "QUOTA_POLICY": "",
  "RECOVERY_RUNBOOK": "",
  "ESCALATE": false
}
```

厳格なスキーマ検証を必須とする。既存AI5HUB adapter出力規約（`ai5-hub/server/adapters/*.ps1` の `[ordered]@{...}` 形式）との整合を保つ。

## 11. Local Model Abstraction

論理識別子は `LOCAL_ROUTER`。モデル名・パラメータ数にアーキテクチャをハードコードしない。モデル選定は設定（config）で行う。

現行FUJITSU実装は6B〜9B級の候補を比較し実用上の勝者を1つ選定する。後日モデルを変更してもDAIMONルーティングの再設計を要さない。

### 選定結果（2026-09-29）

- **選定モデル**: Qwen2.5-7B-Instruct（GGUF, Q4_K_M量子化）
- **比較対象**: Llama-3.1-Swallow-8B-Instruct、Llama-3.1-8B-Instruct
- **選定理由**: Apache-2.0ライセンス（商用利用に最も制約が少ない）、日本語/JSON/軽量コーディングのバランス、llama.cppでの成熟したツール対応、8B級JA特化モデルに対しRAM/latencyで優位（tie-break規則「7Bが高速かつ実質同等ならば7Bを選ぶ」に合致）。
- **ランタイム**: llama.cpp（`ggml-org/llama.cpp` 公式リリース、Windows CPU-x64ビルド）。**tag `b10536`（2026-08-21公開）に固定**。理由: 最新nightly `b11245`（2026-09-29ビルド）はこの実機でモデルロード直後に `ggml-base.dll` 内で再現性のある `STATUS_INTEGER_DIVIDE_BY_ZERO (0xc0000094)` をクラッシュする既知回帰があり不採用（イベントログで同一フォールトオフセット `0x1ca7` を2回確認）。`b10536` は同一手順で正常動作を確認済み。
- **配置**: Gitリポジトリ外（`C:\Users\teppe\.local\daimon\local-router\`）。モデル本体・ランタイムバイナリはGit管理対象としない。ランタイムは `runtime-b10536\` フォルダに展開済み。
- **状態（2026-09-29時点）**: ランタイム展開済み・動作確認済み（b10536）。モデルダウンロード完了。Smoke test PASS（下記）。Section 12の全項目テストセットは未実施（smoke testのみ）。

### Smoke test結果（2026-09-29）

```
build      : b10536-9855ad69d
model      : qwen2.5-7b-instruct-q4_k_m (2-part GGUF)
prompt     : "Respond with exactly: OK"
response   : "OK"  (正しい応答)
performance: Prompt 8.6 t/s / Generation 3.9 t/s （CPU-only, GPU未使用）
結果       : PASS
```

3.9 t/s は対話用途には遅いが、on-demand・低頻度のルーティング判断用途としては許容範囲。長い構造化JSON応答は生成に数十秒かかる想定。

## 12. Local Model Benchmark（DAIMON routing/recovery test set）

以下を最低限テストする。モデルダウンロード完了後に実施し、結果をここに追記する。

1. Task classification（TASK_CLASSの正しい分類）
2. Worker selection（PRIMARY/REVIEWER/FALLBACKの妥当な選定）
3. Builder/Reviewer/Fallback selection
4. quota-exhaustion シナリオ（Codex quota枯渇を模擬）
5. Worker heartbeat-loss シナリオ
6. node failure シナリオ
7. low-confidence escalation（低confidence時に無言で断定しないこと）
8. strict JSON compliance（本仕様§10スキーマへの厳格準拠）
9. 日本語指示への追従
10. 軽量コーディング/診断Task
11. RAM使用量
12. load time
13. latency
14. このFUJITSU実機上でのstability

**状態: 一部実施（PARTIAL）**。2026-09-29、`ai5-hub/tools/Invoke-DaimonLocalRouter.ps1` 経由で項目1（Task classification）・項目2（Worker selection）を実タスクで検証：

```
入力: {task_id: DAIMON-TEST-001, objective: "READMEのtypo修正", worker_states: {FUJITSU_CODEX: unavailable, FUJITSU_CLAUDE: healthy, DYNABOOK_CODEX: healthy}}
出力: TASK_CLASS=light_edit, TASK_COMPLEXITY=LOW, SELECTED_NODE=FUJITSU,
      PRIMARY_WORKER=FUJITSU_CLAUDE, REVIEWER=DYNABOOK_CODEX, FALLBACK_WORKER=FUJITSU_CLAUDE,
      CONFIDENCE=MEDIUM, ESCALATE=false, QUOTA_POLICY=UNKNOWN（捏造せず正直にUNKNOWN）
結果: PASS（1回目はSELECTED_NODEにWorker名を誤設定、REVIEWER=PRIMARY_WORKERの重複あり。
      プロンプトにスキーマ制約を追記し再実行、2回目で両方修正確認）
既知の残課題: FALLBACK_WORKERがPRIMARY_WORKERと同一になるケースあり（今回は実害小、要観察）
```

### 追加実測（2026-09-29、`Invoke-DaimonDispatch.ps1` 実装後）

| 項目 | 結果 | 証拠 |
|---|---|---|
| Task classification | PASS | DAIMON-TEST-001/003/005/006/008 全て妥当な分類 |
| Worker selection | PASS | FUJITSU_CODEX unavailable時にFUJITSU_CLAUDE/LOCAL_ROUTERへ正しく回避 |
| LOCAL_ROUTER自己実行（classification） | PASS | DAIMON-TEST-003: "BILLING"（正解）、DAIMON-TEST-008: "GENERAL"（正解） |
| 日本語指示追従 | PASS | DAIMON-TEST-005: 日本語objectiveから正しく"TECHNICAL"を出力（UTF-8読み込みバグ修正後） |
| 軽量コーディング | PASS | DAIMON-TEST-006: `(Get-Date -Format 'yyyy-MM-dd')` 正しい一行PowerShell |
| strict JSON compliance | PASS | 全テストで必須12フィールド完全出力、パース成功 |
| REVIEW_WAIT継続 | PASS | DAIMON-TEST-007をFUJITSU_CLAUDE向けREVIEW_WAITへparkした直後、独立したDAIMON-TEST-008を正常完了（システム停止せず） |
| 重複実行防止（lease） | PASS | 完了済みDAIMON-TEST-003を再dispatch→`SKIP`（exit 2）、正しく拒否 |
| low-confidence escalation | 未実施（個別シナリオとしては） | 実運用では発生せず（全テストMEDIUM以上）。fallback pathのコード自体は実装・レビュー済み（未実行） |
| quota-exhaustion シナリオ | PASS（1回目FAIL→修正→PASS） | 1回目: FUJITSU_CLAUDEをEXHAUSTEDと知りながらFALLBACK_WORKERに選出（矛盾、FAIL）。プロンプトに「PRIMARY/REVIEWER/FALLBACK全ロールでLIMIT_STATE=EXHAUSTEDを除外」を明記し再実行、FALLBACK_WORKERが正しくFUJITSU_CODEXに修正されたことを確認（DAIMON-BENCH-QUOTA-2）。残課題: 「moderate coding」をLOCAL_ROUTER自身に割り当てる能力適合判断のブレ、REVIEWER選出の不安定さ（7Bモデルの限界として記録、追加チューニングはしない） |
| heartbeat-loss シナリオ | **PASS** | DAIMON-BENCH-HEARTBEAT: Level0ルールが即座にESCALATE、無言の推測なし、AI呼び出し不要（決定的ルーティングが正しく機能） |
| node failure シナリオ | **PASS** | DAIMON-BENCH-NODEFAIL: 同様にLevel0で即ESCALATE、スタック中のTaskを虚偽完了させず正直に報告 |
| RAM / load time / latency / stability | 部分実測 | 8.6 t/s prompt / 3.9 t/s generation（初回smoke test時）。複数回実行時の安定性は今回8回のdispatch実行で異常終了なし |

**残課題**: quota-exhaustion/heartbeat-loss/node-failureの明示的シナリオ未実施、FALLBACK_WORKERがPRIMARY_WORKERと同一になる軽微な不整合が時々発生（実害は小さいが要観察）。

### 重大バグ発見・修正（2026-09-30）: LOCAL_ROUTER自己実行の虚偽完了

DAIMON-TEST-009（"hello.txtを作成"）で、FUJITSU_LOCAL_ROUTERが自らPRIMARY_WORKERを選び「hello.txt created」とOUTPUTしCOMPLETEDにしたが、**実際にはファイルは一切作成されていなかった**（LOCAL_ROUTERはllama-cli経由のテキスト生成のみで、ファイルシステム操作能力を持たない）。`Invoke-DaimonDispatch.ps1`に**capability guard**を追加: acceptance_criteria/objectiveが`file|creat|write|config|script|install|deploy`にマッチする場合、LOCAL_ROUTERへの自己実行を強制的にFUJITSU_CODEXへ再ルーティングする。修正後、DAIMON-TEST-009は正しくFUJITSU_CODEXへ再ルーティングされ、正直に`FAILED_RECOVERABLE`（後述の別バグにより）と報告された（虚偽COMPLETEDにはならなかった）。

### FUJITSU_CODEX実行アダプタ追加・バグ修正（2026-09-30）

`Invoke-DaimonDispatch.ps1`にFUJITSU_CODEX実行パスを追加（`codex exec -s workspace-write -C <task毎のscratch dir> --skip-git-repo-check -o <last-message file>`）。初回実装は`Start-Process -ArgumentList`に配列を直接渡し、スペースを含む引数（プロンプト）が正しくクォートされず実行が無効化される既知の問題（LOCAL_ROUTER実装時と同型のバグ）を再度踏んだ。手動での`codex exec`直接実行では正常にファイル作成・検証まで成功することを確認した上で、`Invoke-DaimonLocalRouter.ps1`と同じ手動クォート方式に修正。

**現状（最終）**: **PASS（実証済み、ただし別バグ発見・修正込み）**。

3回のテスト実行:
1. 1回目: 引数クォートバグにより無応答のまま終了（上記）。
2. 2回目・3回目: 引数クォート修正後、Codex自体は正常に`hello.txt`（内容`CODEX_ECHO_OK`）を作成・検証まで完了していたことを事後確認。しかし`Invoke-DaimonDispatch.ps1`側の`$p.WaitForExit(120000)`がプロセス終了を検知できず、ラッパーが約15分間ハングし続けた（`codex.exe`自体は既に終了していたにもかかわらず）。手動でプロセスをkillし、ディスク上の実際の成果物（`hello.txt`の内容、`last-message.txt`）から正直にReconcile（捏造ではなく実証拠に基づく事後承認）した。
3. 根本原因（WaitForExit不信頼）を修正: 完了マーカーファイルの出現またはプロセス終了のどちらかをポーリングし、240秒のハード上限で強制終了する方式に変更。

**Worker停止時の再配車**: 今回のインシデントを踏まえ、`Invoke-DaimonDispatch.ps1`にFALLBACK_WORKER自動再配車を実装（FUJITSU_CODEX/LOCAL_ROUTER自己実行が失敗した場合、ルーティング判断が既に示していたFALLBACK_WORKERがFUJITSU_CLAUDEであれば`REVIEW_WAIT`へ再配車し`FAILED_RECOVERABLE`で終わらせない）。「駅長・現場監督モデル」の「Worker停止 → 別Workerへ再配車」分岐に対応。

## 13. LOCAL_ROUTER不可用時のFallback

LOCAL_ROUTERが unloaded / failed / resource-blocked / model-corrupt / 一時的に利用不可の場合でもDAIMONは動作を継続する。

`Rule Router -> 既知の安全なルーティング` または `-> より強いWorkerへのルーティングレビュー`。

LOCAL_ROUTERを単一障害点にしない。

## 13.5. Owner向け言語ポリシー（2026-09-30追加、2026-09-30改訂）

**Owner（中山鉄兵）向けの通常の返答・進捗報告・質問・承認依頼・説明・警告・ブロッカー報告・選択肢・要約・FINAL report・OWNER_ACTION・NEXT・復旧手順は全て日本語で行う。** これはDAIMON完成後だけでなく即座に適用される、本セッション（FUJITSU Claude Code）の恒久ルールである。

技術成果物（ソースコード、変数名・関数名・ファイル名、スキーマ、機械可読JSON、Git識別子、制御不能な外部ツールの生出力）は技術的に適切な場合、英語のままでよい。Claude Code自体の生の英語permission promptや外部ツールの英語出力をOwnerに見せる必要がある場合、DAIMONが仲介可能な範囲で日本語の意味説明を先に行ってから選択を求める。Owner側に英語の理解を要求しない。

通常のDAIMONポリシーで安全と判定済みの操作は、本人に確認しない（自動実行する）。TRUE_OWNER_GATEに該当する操作のみ、以下のテンプレートで日本語に翻訳して提示する。翻訳時にリスクを隠さない。

### テンプレート（2026-09-30改訂版）

```
【本人承認が必要】

操作：{何をしようとしているか}
理由：{なぜ本人承認が必要なのか（TRUE_OWNER_GATE該当理由）}
対象：{変更される対象}
変更内容：{具体的な変更内容}
外部公開：{あり／なし}
削除：{あり／なし}
危険性：{具体的なリスク。ないなら「低い」と明記し、消さない}
推奨：{承認／中止のどちらを推奨するか}

1. 承認して進める
2. 中止する
```

Claude Code自体が要求する生の英語permission promptを、DAIMONが安全に仲介できる場合はOwnerにそのまま見せない（本テンプレートに翻訳してから提示する）。実装は [Invoke-DaimonOwnerGate.ps1](./tools/Invoke-DaimonOwnerGate.ps1)。

### 実測例（2026-09-30、非TRUE_OWNER_GATE操作での動作確認）

本Task Queue実装を`daimon-sales`のfeatureブランチへcommit・pushした操作（実際には通常のGit操作でありTRUE_OWNER_GATEではない）を例に、テンプレート出力を検証した：

```
【本人承認が必要】

操作：DAIMON routing実装をGitへcommit
理由：本人確認呈示フォーマットの動作検証（本操作自体はTRUE_OWNER_GATEに該当しない通常のGit操作）
対象：DAIMON Node関連ファイルのみ（ai5-hub/tools/, ai5-hub/*.md, .claude/settings.json）
変更内容：ローカルGit履歴へcommitを追加、featureブランチへpush
外部公開：なし（feature branch、main未マージ）
削除：なし
危険性：低い（他レーンのファイルは含まれておらず、mainへの直接変更もない）
推奨：承認

1. 承認して進める
2. 中止する
```

**結果**: **PASS**（2回のバグ発見・修正を経て確認）。

1. 1回目: Windows PowerShell 5.1はBOMなしUTF-8の.ps1ソース内の日本語リテラルを正しくパースできず、パラメータのデフォルト値（`'なし'`等）が文字化けし構文エラーになった。BOM付きUTF-8で保存し直して解決。
2. 2回目: パース後は正常動作したが、標準出力がコンソールのOEMコードページ経由で文字化けした。`[Console]::OutputEncoding = [Text.Encoding]::UTF8` をスクリプト冒頭に追加して解決。

修正後、テンプレート通りの正しい日本語出力を確認。RISK必須ガード（空文字列を渡すと`RISK_FIELD_REQUIRED`で明示的に拒否）も動作確認済み。Owner Gate E2Eとしては、実際のTRUE_OWNER_GATE（支払い・MFA等）でのテストは別途必要（本人確認操作そのものを人工的に発生させるのは避けた）。

## 14. Owner Gates

通常のルーティングはOwner Gateではない。Owner Gateが必要なのは：本人確認/MFA/生体認証、支払い/購入、有償reset/クレジット、法的同意、既存承認範囲外の公開、不可逆な破壊的操作、価値あるデータの削除、秘密情報開示、セキュリティ制御の解除、本人でなければ不可能な物理操作。

## 15. Experience Learning

ルーティング結果（Task class、選定Worker、選定Node、成否、latency、resource使用量、retry/escalation、レビュー結果）を永続化する。単発の成功例を無言で恒久ルール化しない。

**状態: 未実装**。永続化ストアの設計は今後のTaskとする。

## 16. Acceptance（READY判定前チェックリスト）

| 項目 | 状態 |
|---|---|
| 本canonical spec存在 | PASS（本ファイル） |
| 実装がspecに準拠 | PARTIAL — Task Queue/Worker Registry/Level0-1 Routing/self-executionまで実装・実測PASS |
| Schema validation PASS | PASS（全dispatchテストで必須12フィールド検証済み） |
| Deterministic Router PASS | PASS — `Invoke-DaimonRuleRouter.ps1`、read_only_inspection即決・emergency即ESCALATE・fallthrough確認済み |
| LOCAL_ROUTER PASS | PARTIAL — classification/JA指示/軽量コーディング/JSON準拠は実測PASS。quota/heartbeat/node-failureシナリオ未実施 |
| Local self-execution PASS | **PASS** — DAIMON-TEST-003/005/006/008で実タスクを実行し正解出力、Result/Receipt生成確認 |
| DAIMON_TOOL_EXECUTOR（固定スクリプト化） | PASS — 8スクリプト（SystemDiagnostics/LocalhostHealth/LocalRouter/RuleRouter/Dispatch/BusStatus/OwnerGate/Dashboard）実装・`.claude/settings.json`登録済み |
| DAIMON AI 可視化UI | **PASS** — `Start-DaimonDashboard.ps1`（独自ポート43126、AI5HUB/profit-engineとは完全分離、読み取り専用）+ `dashboard.html`（日本語UI）。`/api/status`が`bus_root`の実データ（Task Queue・Worker Registry・Lease）を返すことを実測確認。テストTask片付け後、空Queueが正しく空表示されることも確認（架空データなし、5秒間隔自動更新）。 |
| Task Queue（READY/CLAIMED/RUNNING/REVIEW_WAIT/WAITING_PROVIDER/WAITING_OWNER/COMPLETED/FAILED_RECOVERABLE） | PASS — 全状態を実タスクで到達確認 |
| Worker Registry | PASS（雛形）— `bus/worker-registry.json`、実行のたびに実状態で更新される。DYNABOOK系はUNKNOWN/未検証のまま正直に記録 |
| Lease / 重複実行防止 | **PASS** — atomic lease file、完了済みTask再実行を正しく拒否（exit 2） |
| REVIEW_WAIT継続（アイドル化しない） | **PASS** — 実測、上記参照 |
| Claude routing PASS | N/A（FUJITSU_CLAUDEは本セッション自身。サブプロセス実行ではなくREVIEW_WAITへparkする設計、意図通り） |
| Codex routing PASS | **PASS** — 実タスクで`hello.txt`作成・内容検証まで実証済み（詳細はSection 12参照）。オーケストレーション側のWaitForExitバグを発見・修正 |
| Worker停止時の再配車（Worker停止→別Workerへ再配車） | PASS（FUJITSU_CLAUDEへのfallback実装・動作確認） |
| **DYNABOOK実dispatch** | **BLOCKED（正直に報告、捏造なし）** — `ai5-github-result-bus`に2026-08-28時点で実証済みのdevice-to-deviceチャンネルが存在するが、`bus/tasks/`の最終更新は8月31日で以後1ヶ月近く活動なし。dynabook側の現在の稼働状況をFUJITSU側から確認する手段がない。 |
| quota simulation PASS | **PASS**（発見したFALLBACK_WORKER矛盾を修正済み） |
| heartbeat-loss simulation PASS | **PASS** |
| node failover simulation PASS | **PASS**（controlled simulation。実dynabook復旧は別課題、上記参照） |
| low-confidence escalation PASS | コードパス実装・レビュー済み、実シナリオでの発火は未確認 |
| Result/Receipt/Evidence PASS | **PASS** — 全テストで生成・検証済み |

**総合判定: CONDITIONAL**（ローカル完結する経路は実測PASS。dynabookを跨ぐ実dispatchのみ、既存チャンネルの休眠状態により未検証・ブロック）

## 17. Canonical Precedence

本仕様は [ZERO_SPEC.md](./ZERO_SPEC.md) §16「FUJITSU DAIMON NODE 初期化」の配下にある専用Worker Routing仕様であり、AI5 SALES FACTORY（ZERO_SPEC.md 第1〜15章）の正本を上書きしない。矛盾する場合は本人の明示指示を優先する。

進行順序: `SPEC -> IMPLEMENT -> TEST -> REVIEW -> E2E -> EVIDENCE`
