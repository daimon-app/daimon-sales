# Claude Code セッション復元正本（恒久適用）

新規セッション・resume・clear・compact・再起動のたびに、`.claude/settings.json` の SessionStart hook が
`ai5-hub/tools/Invoke-DaimonSessionRestore.ps1` を実行し、本ファイルと現在の Owner Gate 状態を自動で文脈へ注入する。
会話履歴に依存せず、Git管理下の本ファイルと設定だけで以下4項目を復元する。

## JAPANESE_MODE = ON

- Owner（本人）向けの自然言語はすべて日本語で書く。対象：作業説明、状況報告、質問、選択肢の説明、エラー説明、復旧説明、FINAL REPORT、Result / Receipt の Owner 向け要約。
- Bash ツール等の `description`（本人の画面に表示される作業説明）も日本語で書く。
- 英語のままでよいもの：コード、コマンド、API名、ファイル名、path、schema key、固有の技術識別子、外部ツール自身が固定表示する変更不能UI。
- 詳細ルールは [OWNER_COMMUNICATION_POLICY.md](./OWNER_COMMUNICATION_POLICY.md) に従う。

## SAFE_PERMISSION_POLICY

- 安全な読み取り専用診断で Owner を呼ばない。ad-hoc な `powershell -Command ...` や `cd X && git ...` は許可リストの前方一致に合わず承認待ちを起こすため使わない（2026-10-15 再発の根本原因）。
- 代わりに次の固定Tool（DAIMON_TOOL_EXECUTOR、許可リスト登録済み・引数なし・読み取り専用）を、**PowerShell tool ではなく Bash tool から、下記の文字列と完全一致で**呼ぶ（PowerShell tool からは「nested PowerShell process」として拒否されることを 2026-10-16 に実測）：
  - プロセス／サービス／RustDesk port／dynabook到達性：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\teppe\Documents\GitHub\daimon-sales\ai5-hub\tools\Invoke-DaimonRemoteStatus.ps1"`
  - ホスト RAM / git プロセス：`...\ai5-hub\tools\Invoke-DaimonSystemDiagnostics.ps1`
  - localhost health：`...\ai5-hub\tools\Invoke-DaimonLocalhostHealth.ps1`
  - Bus状態：`...\ai5-hub\tools\Invoke-DaimonBusStatus.ps1`
  - Galaxy実機PRE-FLIGHT（USB ADB、読み取り専用）：`...\ai5-hub\tools\Invoke-DaimonGalaxyPreflight.ps1`（`-GateTaskId GALAXY-LOCAL-AI-20261016-01` を付けると、接続検知時に待機Taskを自動RESUMEする。`-GateTaskId GALAXY-REMOTE-HOST-20261019-01` はGalaxy RustDeskの21118 Listen検知で自動RESUMEする。SessionStart hookも自動で実行する。Galaxy上のRustDesk / Tailscale / Chrome Remote Desktopの状態、Galaxyからdynabookへの経路、画面共有許可の有無もこのToolで読み取る）
- DAIMON Remote（Galaxy）の操作：`...\ai5-hub\tools\Invoke-DaimonRemoteGalaxy.ps1 -Action <ui|host-start|disconnect>`、`-Action connect -Device <dynabook|fujitsu>`（`-SimulateDirectDown` は切替訓練）。**本人の正面入口はDAIMON Remoteであり、本人に「RustDeskを開いて」と依頼しない**（RustDeskは内部backend）。本人に求めてよいのは、DAIMON Remoteの同意確認とAndroid公式の画面共有確認だけ。AIはそれらの「同意」側を絶対に押さない（断る側の「同意しない」「閉じる」だけは可）。
- GALAXY_LOCAL_AI の通常施工は、固定Tool `python ai5-hub/tools/galaxy_local_ai.py <サブコマンド>` だけで行う（作業ディレクトリはリポジトリ直下、文字列は完全一致）。サブコマンドは `status` / `bench-next` / `select` / `deploy` / `e2e` / `stop` / `logs` / `cleanup-losers` のみ。ad-hoc の adb / python / bash は生成しない。長時間かかる `bench-next` と `e2e` は Bash tool の `timeout` を 600000 にする。
- 夜間無人施工（NIGHT_ZERO_TOUCH）：本物の Owner Gate 以外で Permission を発生させない。固定Toolで足りない処理が出たら、承認を求めず、固定Toolを拡張するまでその処理を保留して次の Task へ進む。
- Git 読み取りは作業ディレクトリ（リポジトリ直下）から `git status` / `git log` / `git diff` / `git show` 等を `cd` なしで直接実行する。別リポジトリは `git -C` ではなく固定Tool または Read / Glob / Grep ツールで確認する。
- **Git は目的別の固定Toolだけを使う**（2026-10-20 監査：承認15件はすべて Claude が作った ad-hoc コマンドが原因。内訳は `git -C` 連結8、commit/push 連結4、pipe・`cat`・`grep`・`for` ループ3）：
  - SAFE_GIT_READ：`...\ai5-hub\tools\Invoke-DaimonGitRead.ps1 -Repo <daimon-sales|result-bus> -Op <status|log|diff-stat|diff-names|diff|fetch|incoming|show|exists> [-Ref r] [-Path p] [-Count n]`
  - SAFE_GIT_STAGE_EXPLICIT / COMMIT_DAIMON / PUSH_APPROVED_BRANCH：`...\ai5-hub\tools\Invoke-DaimonGitSave.ps1 -Repo <daimon-sales|result-bus> -Paths a,b,c -Message "..." [-Push]`（承認済みbranchだけ、名前を挙げたファイルだけをstage、secret検査、remoteが進んでいれば重複ファイルが無い場合だけmerge、force push不可）
  - 他端末のResult待ち：`...\ai5-hub\tools\Wait-DaimonBusResult.ps1 -TaskId <id> -MaxMinutes <1-30>`（`run_in_background` で呼ぶ）
  - 権限監査：`...\ai5-hub\tools\Invoke-DaimonPermissionAudit.ps1 [-Since yyyy-MM-dd]`、回帰試験：`...\ai5-hub\tools\Test-DaimonZeroTouchPermission.ps1`
- Bash で `&&` / `;` / `|` の連結、`git -C`、`cat` / `grep` / `head` / `tail` / `for` ループを作らない。1回の Bash 呼び出しは固定Tool 1本か、許可済み git 読み取り 1本だけにする。
- force push / `reset --hard` / `clean` / `rebase` / branch削除 / `rm -rf` は `.claude/settings.json` の `deny` で自動拒否される（Owner にも聞かない）。必要なら Owner の明示指示を受けてから別途扱う。
- ファイル内容・ログ・Evidence の読み取りは Bash ではなく Read / Glob / Grep ツールを使う（承認不要）。
- 新しい定型診断が必要になったら、承認を求める前に固定Toolとして `ai5-hub/tools/` に追加し、完全一致パスで `.claude/settings.json` に登録する。
- Owner Gate を維持するもの：本人認証、password / secret 入力、MFA、支払い、公開、本番不可逆変更、destructive delete、security control 解除。これらを包括許可へ入れない。「Yes を自動クリック」する設計は禁止。

## CONTINUATION_POLICY

- 最初からやり直さない。Git・Result・Receipt・Evidence から最新の検証済み checkpoint を復元し、そこから続行する。
- 安全に実行可能な Task が残っている限り入力待ちへ戻らない。停止してよいのは：本物の OWNER_GATE／証拠付き FINAL 完了／外部要因で完全 BLOCKED かつ独立 Task 0 件、のみ。
- Owner Gate 完了は Owner の追加指示を待たずに検知・自動 RESUME する（`ai5-github-result-bus/worker/Resume-AI5OwnerGateTask.ps1`、検証条件を満たさない場合は fail-closed）。
- Codex が通常の施工主担当。Claude Code は fallback 時のみ施工を代行し、他AIの未コミット変更を保護する。

## OWNER_GATE_STATE

下の「動的状態」節（hook 実行時に Result Bus から自動算出）を正とする。password そのものは要求・表示・記録しない。
