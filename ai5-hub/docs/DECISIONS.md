# AI5 Decision Log

## 2026-08-19 — GitHub Result Loop

- Realtime HUBを優先し、GitHub Result Loopを常設Fallbackとする。
- 既存Task Engine、Project Control、Single Writer、Approval Gateを再利用する。
- Result receiptを`task_id + result_version`とし二重再施工を防止する。
- Chrome障害は`GITHUB_DEGRADED`とし、コード/GitはCodex、BrowserはManus/ClaudeへFallbackする。
- remote syncはprivate確認済みremoteだけ許可し、Public remoteへ実Task・Resultを保存しない。
- 本人承認ゲートはZeroやFallback AIでも迂回しない。
