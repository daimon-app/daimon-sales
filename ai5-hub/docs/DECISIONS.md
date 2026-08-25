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

## 2026-08-25 — Mail Manus Primary

- 実測済みGmail→Mail Manus→private GitHub→reply回収をManus Primaryとする。
- 状態は `CREATED → MAIL_QUEUED → MAIL_SENT → MANUS_RECEIVED → MANUS_TASK_CREATED → EXECUTING → RESULT_RETURNED → RESULT_VERIFIED → COMPLETED` の単調遷移とする。
- `AI5_TASK_ID + CORRELATION_ID` が送信済みなら再送しない。API応答不明時もSent mailboxとResult Busを照合してからretryする。
- Gmail実ヘッダーがDAIMON公式Fromを採用しない場合は `UNSUPPORTED` とし、承認済みOwner Gmail fallbackを使用する。Primary化を停止しない。
- 専用宛先、password、OTP、token、private key等はGitHub、Result Bus、Evidence、logへ保存しない。
- APP/WEB GUI経路は削除せずrollback用Fallbackとして維持する。

## 2026-08-25 — Claude/Gemini API nodes and durable auto-resume

- Closed-loop必須ノードをClaude/Gemini chatから claude_api / gemini_apiへ変更する。chatは独立監査・Fallbackとして保持する。
- 未配線、Owner認証待ち、Owner課金待ち、技術blockをそれぞれ NOT_WIRED / WAITING_OWNER_AUTH / WAITING_OWNER_MONEY / BLOCKED として分離する。
- TASK_ID + CORRELATION_ID のcreate-only永続claimとProject Single Writer leaseを使用する。lease失効時のみcrash recoveryし、3 attemptで停止する。
- Resultは同一Task/Correlationにつきcreate-onlyで受理し、二重受信を破棄する。
- credential値は検査・出力・保存せず、存在確認だけを行う。新規発行はOwner Auth、課金確定はOwner Money Gateとする。

## 2026-08-25 — Artifact Return

- ChatGPT/Claude chat本文だけではArtifact deliveryをPASSにしない。
- Task ID、Correlation ID、Artifact ID、SHA-256、byte countを含むmanifestと実bytesをResult Bus/private GitHubへ返す。
- composite identity + SHA-256のcreate-only receiptで同一Artifactの二重登録・二重施工を拒否する。
- ZIPはhash固定後、path traversal、entry count、uncompressed size、compression ratioを検査し、clean extract後にCodexが独立testする。
- 現在のClaude `ai5-p0.zip` はbytes未到達のため `CHAT_ARTIFACT_TRANSPORT = NOT_WIRED`、46/46は `UNVERIFIED`。
