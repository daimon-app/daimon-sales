# AI5 HUB 詳細設計仕様書 — ゼロ向け

## 1. 指令と目的

中山鉄兵本人は、常にゼロとの単一トーク窓口から指示する。ゼロは目的・優先順位・完了条件を整理し、CodexをPC側施工司令塔として必要なAIだけへ振り分け、検証済み結果を統合して本人へ返す。

本システムは5つのAIを並べたチャットではない。ゼロを唯一の入口とするAI施工オーケストレーション基盤である。

## 2. 成功条件

1. 本人が依頼先AIを選ばなくてよい。
2. ゼロとの会話だけで依頼、進捗、承認、結果受領が完結する。
3. CodexがPC、コード、Git/GitHub、Windows、結果回収を統括する。
4. 専門AIは品質・速度が上がる場合だけ呼ばれる。
5. 認証情報を保存せず、課金・重大操作を本人承認なしに行わない。
6. AIの失敗、利用制限、未検証事項を隠さない。

## 3. AI5兄弟の責務

|主体|責務|代表トリガー|正式経路|
|---|---|---|---|
|ゼロ / ChatGPT|本人対話、目的設定、優先順位、最終報告|全依頼の入口|Codex Remote|
|Codex|PC施工、実装、Git、テスト、ルーティング、統合|通常施工、ローカル作業|Codex実行環境|
|Gemini / Antigravity|最新情報、Google系、マルチモーダル、大量資料、別解|調査・独立検証|ログイン済みChrome + Gemini Web|
|Claude Code|高精度レビュー、設計監査、難解な原因分析|重要変更・深層レビュー|Claude Code CLI|
|Manus|Web実務、販売導線、競合調査、長時間作業|Web中心の自律作業|ログイン済みChrome + Manus Web|

## 4. 標準フロー

1. 本人がゼロへ自然文で指示する。
2. ゼロが `objective`、`priority`、`done_when`、`constraints` を抽出する。
3. Codexが環境、Git、既存作業、安全条件を確認する。
4. ルーターが担当AIと実行順序を決める。
5. 各アダプターが実行し、イベントとして進捗・成果を返す。
6. Codexが差分、テスト、一次情報を検証して統合する。
7. ゼロが本人へ結果、残問題、本人判断事項を報告する。

## 5. ルーティング規則

- 通常施工はCodex単独で行う。
- 最新情報、Google関連、画像・動画、大量資料、別解はGeminiへ送る。
- 難しいレビュー、設計監査、バグ原因分析はClaudeへ送る。
- Web操作、販売前監査、競合調査、長時間Web作業はManusへ送る。
- 重要設計・重大変更はGeminiとClaudeへ独立検証させ、Codexが統合する。
- 同じ仕事を機械的に全員へ複製しない。
- 同一ファイルを複数AIが同時編集しない。担当範囲かブランチを分ける。

## 6. 状態モデル

ジョブは `draft → planned → running → verifying → completed` を基本とする。例外は `approval_required`、`blocked`、`failed`、`cancelled`。

各サブタスクは `queued / running / succeeded / failed / skipped` を持ち、担当AI、時刻、利用経路、成果物、検証結果を記録する。

## 7. 承認ゲート

次は必ず `approval_required` で停止する。

- 新規課金、購入、契約、プラン変更、追加クレジット
- OAuth、2FA、CAPTCHA、PIN、パスワードなど本人認証
- 重要データ削除など回復困難な操作
- 本番、販売、一般公開など重大な対外操作
- アカウントやセキュリティへ重大な影響がある変更

承認要求には「必要な本人操作」「画面の押す場所」「承認後に再開する処理」を含める。利用可能なら件名を `[AI承認待ち]` で始めたGmail自己通知を送る。秘密情報は通知へ含めない。

## 8. データ設計

- `Conversation`: id, title, created_at, updated_at, status
- `Message`: id, conversation_id, author, body, created_at, visibility, attachments
- `Job`: id, conversation_id, objective, priority, done_when, constraints, status
- `Task`: id, job_id, assignee, instruction, depends_on, status, result_ref, error
- `Approval`: id, job_id, type, summary, instructions, status, requested_at, resolved_at
- `Event`: id, job_id, type, actor, payload, created_at

Cookie、セッション、PIN、パスワード、OTP、秘密鍵は保存対象外とする。

## 9. アーキテクチャ

```text
Mobile / Desktop PWA
        │ WebSocket / HTTPS
AI5 HUB Local API
        ├─ Conversation Store
        ├─ Job Orchestrator
        ├─ Policy & Approval Gate
        ├─ Event / Audit Log
        └─ Adapter Layer
             ├─ Codex Remote
             ├─ Claude Code CLI
             ├─ Gemini Chrome
             ├─ Manus Chrome
             └─ Gmail notification
```

アダプターは共通の `healthCheck()`, `checkQuota()`, `run(task)`, `cancel(taskId)`, `collect(taskId)` を実装する。正確な利用残量を取得できない場合は `unknown` とし、推測値を表示しない。

## 10. API草案

- `POST /api/conversations` — 案件ルーム作成
- `GET /api/conversations/:id/messages` — 履歴取得
- `POST /api/conversations/:id/messages` — ゼロへ指示
- `GET /api/jobs/:id` — 統合状態取得
- `GET /api/jobs/:id/events` — 進捗イベント配信
- `POST /api/approvals/:id/approve` — 本人承認
- `POST /api/approvals/:id/reject` — 拒否
- `GET /api/agents/health` — 接続状態確認

書き込みAPIにはローカル認証、CSRF対策、操作ごとの権限検査を必須とする。

## 11. UI要件

- 初期画面はゼロとのトーク。AI選択を要求しない。
- ゼロが選んだ担当AIをメッセージ下のチップで表示する。
- 施工状況、担当AI、検証状態、承認待ちを右ペインに表示する。
- 個別AIログは詳細画面で閲覧可能だが、通常会話には流さない。
- スマホではトーク優先、施工状況はドロワー表示とする。
- エラーは担当、経路、原因、再試行可否を表示する。

## 12. セキュリティ

- 初期版はlocalhost限定。LAN・外部公開は本人が明示した場合だけ有効化する。
- 認証済み公式CLI、公式連携、既存ログインを優先する。
- Cookie抽出、セッション盗用、認証回避は禁止する。
- UI入力を任意シェル文字列へ直結しない。
- ログからトークン、秘密鍵、個人情報をマスキングする。
- 外部送信、削除、公開、課金関連操作は監査ログへ記録する。

## 13. 障害時動作

- AIが利用不能なら、Codex単独または安全な代替へ縮退する。
- 認証切れは本人操作を具体的に案内し、解除後にジョブを再開する。
- タイムアウト時は冪等キーで重複実行を防ぐ。
- ブラウザ画面が想定外なら送信・クリックを止めて再観測する。
- 追加料金が必要なら自動切替せず停止する。

## 14. 実装フェーズ

### Phase 0 — 今回実装

LINE風ゼロトーク、ローカルルーター、AI状態、施工フロー、承認待ち枠、ブラウザ履歴を持つ静的MVP。

### Phase 1 — ローカル基盤

ローカルAPI、SQLite、イベント配信、ジョブ状態機械、監査ログ、単体テスト。

### Phase 2 — Codex接続

Codex Remoteとの正式なジョブ投入、結果回収、再開処理。

### Phase 3 — 専門AI接続

Claude Code CLI、Gemini Chrome、Manus Chromeを順に接続し、実行前後の利用状態確認を実装。

### Phase 4 — 通知と安定化

Gmail自己通知、E2Eテスト、障害復旧、バックアップ、ログ秘匿化、PWA化。

## 15. 受け入れ試験

1. 「販売ページを調査して改善」でCodex + Manusが選ばれる。
2. 「この設計を厳密にレビュー」でCodex + Claudeが選ばれる。
3. 「Googleの最新仕様を調べて」でCodex + Geminiが選ばれる。
4. 軽微なコード修正ではCodexだけが選ばれる。
5. 課金、公開、削除、本人認証を含む依頼は承認前に停止する。
6. AI障害時に結果を捏造せず、代替経路または失敗を表示する。
7. 再読み込み後も会話とジョブ状態を復元する。
8. PIN、パスワード、Cookie、トークンが保存データとログに存在しない。

## 16. ゼロへの最終施工指示

本人の指示を受けたら、まず完了条件を内部で明確化する。本人判断が不要な安全・可逆・非課金作業はCodexへ渡して自動継続する。専門AIは品質・速度・専門性が実際に上がる場合だけ使う。全成果をCodexが検証し、本人には「実施内容、各AIの使用、利用量の確認範囲、Git/テスト、残問題、本人判断事項」をゼロから報告する。
