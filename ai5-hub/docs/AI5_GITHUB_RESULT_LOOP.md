# AI5 GitHub Result Loop

Updated: 2026-08-19

## Purpose

GitHubをAI5のTask/Result証拠Busとして利用し、Chrome連携障害時もZeroが結果回収、再施工、Fallback、次工程発行を継続する。Realtime HUBは優先経路、GitHub Result Loopは常設Fallbackである。

## Architecture

`Zero → Task Bus → AI Queue → Result Bus → Collector → Zero Inbox → Decision → Redispatch`

永続領域は `tasks / results / locks / inbox / receipts / archive`。`receipt = task_id + result_version` によりResultを一度だけ処理する。

## Modes and decisions

- `NORMAL`: Realtime HUBとprivate GitHub Result Loopを併用。
- `GITHUB_DEGRADED`: Chrome必須Taskを強制実行せず利用可能AIへFallback。
- `PASS`: next actionがあれば専門AIへ次工程。`FAIL`: 上限内retry。`BLOCKED_BROWSER`: Manus/ClaudeへFallback。`APPROVAL_REQUIRED`: 本人停止。上限超過は`ESCALATED`。

## Task, Result, Lock

Schema正本は [`task.schema.json`](../ai5/github-bus/schemas/task.schema.json) と [`result.schema.json`](../ai5/github-bus/schemas/result.schema.json)。claim lockはproject/repository/branch/writer/task/owner/heartbeat/TTLを保持する。期限切れでもowner不一致lockを自動解除しない。

## Approval and remote safety

安全条件未証明のmain統合、本番公開、販売開始、SNS公開、DM、課金、購入、契約、広告、OAuth、2FA、CAPTCHA、本人確認、不可逆操作、秘密情報外部送信は本人承認を維持する。全回帰PASS、競合0、非force、Rollback READY、外部公開・金銭・秘密情報・重大な不可逆変更なしを実証した通常main統合はLEVEL 0で継続する。実Task本文をPublic Repositoryへpushしない。Remote Busはprivate確認済み`daimon-app/ai5-github-result-bus`だけを使用し、同期直前にもvisibilityとsecretを再検査する。公開`daimon-app/daimon-sales`はコード正本として維持し、Task/Result保存先にはしない。

## Remote restore verification

2026-08-19、Mock Task `remote-e2e-1787121967`をTask→Result→Collector→Zero Decisionまで処理し、private remoteへcommit `3a2b8dde1240ccedc92c1816a627b7cb9f6312df`としてpushした。別cloneから新規Local Busへ復元し、Task SHA-256 `872BC6A1111448FB218C6B6DFDE35E28E899298E7D251AA6D865F0857567E4AB`一致、Result `REMOTE_BUS_E2E_OK`、Decision `PASS`、秘密情報検出0件を確認した。

## Verification

`GitHubResultLoop.Tests.ps1` と `Phase3ApiE2E.Tests.ps1` がTask、claim、lock、heartbeat、Result、Collector、Inbox、idempotency、PASS next stage、FAIL retry、Browser Fallback、Approval、secret拒否、API/LINE/System統合を検査する。
