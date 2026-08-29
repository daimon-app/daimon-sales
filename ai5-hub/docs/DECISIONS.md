# AI5 Decision Log

## 2026-08-19 — GitHub Result Loop

- Realtime HUBを優先し、GitHub Result Loopを常設Fallbackとする。
- 既存Task Engine、Project Control、Single Writer、Approval Gateを再利用する。
- Result receiptを`task_id + result_version`とし二重再施工を防止する。
- Chrome障害は`GITHUB_DEGRADED`とし、コード/GitはCodex、BrowserはManus/ClaudeへFallbackする。
- remote syncはprivate確認済みremoteだけ許可し、Public remoteへ実Task・Resultを保存しない。
- 本人承認ゲートはZeroやFallback AIでも迂回しない。
- Remote Busは専用private `daimon-app/ai5-github-result-bus`へ分離し、公開DAIMON remoteにはTask/Resultを保存しない。
- Remote同期前にGitHub visibilityと保存対象のsecret scanを毎回実施し、確認不能または検出時はfail closedとする。

## 2026-08-19 — FULL AUTONOMOUS LINE LOOP

- AIの成功返答を完成判定にせず、Zero `COMPLETE_CANDIDATE`後にCodex技術監査を必須化する。
- 全AI Resultを共通Contractへ正規化し、LINEは本人向け短文、詳細証拠はTask/Result Busへ分離する。
- 同一失敗3回・最大attempt/cycle・日次実行上限をLoop Guardとする。
- 未完Loopはprivate Result Busから復元するが、実行前にZero Safety Layerで再評価する。
