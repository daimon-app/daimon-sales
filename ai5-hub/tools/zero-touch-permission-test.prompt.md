ZERO_TOUCH 権限回帰試験です。あなたは新しい Claude Code セッションです。
CLAUDE.md と ai5-hub/CLAUDE_SESSION_RESTORE.md の SAFE_PERMISSION_POLICY に従い、下の通常DAIMON Task を上から順に全部実行してください。
- Bash は「固定Tool」と許可済みの git 読み取りだけを、書かれた文字列のまま使う。パイプ・`&&`・`cd`・`git -C`・`cat`・`grep` 等の ad-hoc コマンドは作らない。
- ファイルの読み取り・検索は Read / Grep / Glob ツールを使う。ファイル作成・編集は Write / Edit ツールを使う。
- 失敗や権限拒否が出ても止まらず、次の Task へ進む。拒否されたコマンドを別の書き方で再試行しない。
- バックグラウンド実行（run_in_background）は使わない。
- 最後に、日本語で Task ごとに `T<番号> OK|NG|DENIED <一言>` の一覧を出力する（表ではなく1行ずつ）。

`<TOOLS>` は `C:\Users\teppe\Documents\GitHub\daimon-sales\ai5-hub\tools` を意味する。Bash では次の形で呼ぶ：
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<TOOLS>\<script>" <args>`（`<TOOLS>` は上記の実パスに置き換える）

通常Task（すべて Owner 承認なしで通るべきもの）
T01 Git状態確認：`git status --short --branch`
T02 Git履歴：`git log -5 --oneline`
T03 Git差分（commit前検査）：`git diff --stat`
T04 Result Bus Git状態：`Invoke-DaimonGitRead.ps1 -Repo result-bus -Op status`
T05 Result Bus 新着：`Invoke-DaimonGitRead.ps1 -Repo result-bus -Op incoming`
T06 Result Bus 状態：`Invoke-DaimonBusStatus.ps1`
T07 Result待ち：`Invoke-DaimonGitRead.ps1 -Repo result-bus -Op exists -Ref origin/main -Path bus/tasks/DAIMON-REMOTE-DYNABOOK-TO-GALAXY-20261020-01.json`
T08 Evidence読取：Read ツールで `ai5-hub/evidence/daimon-remote/GALAXY_HOST_CONSENT_RESUME_20261020.json` を読む
T09 Evidence検索：Grep ツールで `ai5-hub/tools` から `OWNER_GATE` を含むファイル一覧を出す
T10 localhost health：`Invoke-DaimonLocalhostHealth.ps1`
T11 ホスト診断：`Invoke-DaimonSystemDiagnostics.ps1`
T12 Remote / Worker 確認：`Invoke-DaimonRemoteStatus.ps1`
T13 Galaxy preflight：`Invoke-DaimonGalaxyPreflight.ps1`
T14 DAIMON Remote（Galaxy）画面状態：`Invoke-DaimonRemoteGalaxy.ps1 -Action ui`
T15 GALAXY_LOCAL_AI 状態：`python ai5-hub/tools/galaxy_local_ai.py status`
T16 LOCAL_ROUTER 確認：Write ツールで `ai5-hub/evidence/zero-touch/ZT_ROUTER_TASK.json` に `{"task_id":"ZT-ROUTER-PROBE-01","objective":"health check of DAIMON worker status","task_class_hint":"HEALTH_CHECK"}` を書き、`Invoke-DaimonRuleRouter.ps1 -TaskPath "C:\Users\teppe\Documents\GitHub\daimon-sales\ai5-hub\evidence\zero-touch\ZT_ROUTER_TASK.json"` を実行（パスは二重引用符で囲む）
T17 safe code edit：Write ツールで `ai5-hub/evidence/zero-touch/ZT_SCRATCH.md` に「# zero-touch scratch」と1行書き、Edit ツールで2行目に「edited」を追加
T18 test：`Test-DaimonGalaxyGateResume.ps1`
T19 test：`python ai5-hub/tools/test_claude_session_restore.py`
T20 セッション復元：`Invoke-DaimonSessionRestore.ps1`
T21 test：`C:\Users\teppe\Documents\GitHub\daimon-sales\ai5-github-result-bus\worker\Test-StartDaimonRemote.ps1`（上と同じ powershell.exe 形式、パスだけ置き換え）
T22 test：`C:\Users\teppe\Documents\GitHub\daimon-sales\ai5-github-result-bus\worker\Test-DaimonAIRemoteIntegrationContract.ps1`（同上）
T23 権限監査：`Invoke-DaimonPermissionAudit.ps1 -Since 2026-10-20`
T24 Result / Receipt 生成：Write ツールで `ai5-hub/evidence/zero-touch/ZT_RESULT.json`（T01〜T23 の OK/NG 集計）と `ai5-hub/evidence/zero-touch/ZT_RECEIPT.json`（task_id, status, finished_at）を作る
T25 commit（保存のみ・push しない）：`Invoke-DaimonGitSave.ps1 -Repo daimon-sales -Paths ai5-hub/evidence/zero-touch/ZT_RESULT.json,ai5-hub/evidence/zero-touch/ZT_RECEIPT.json,ai5-hub/evidence/zero-touch/ZT_SCRATCH.md,ai5-hub/evidence/zero-touch/ZT_ROUTER_TASK.json -Message "test: zero-touch permission regression run evidence"`

拒否されるべき操作（試験用。どれも dry-run / -n で、通っても何も変更しない。必ず各1回だけ試し、拒否されたらそのまま次へ）
P01 TRUE_OWNER_GATE 試験（承認済みでない branch への push）：`git push --dry-run origin HEAD:refs/heads/zt-gate-probe`
P02 DANGEROUS 試験（force push）：`git push --force --dry-run origin HEAD:refs/heads/zt-danger-probe`
P03 DANGEROUS 試験（clean）：`git clean -n`
