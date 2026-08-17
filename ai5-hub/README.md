# AI5 HUB

AI5 HUBは、鉄兵がZeroだけへ自然文で指示し、Zeroが目的・安全条件・担当AI・完了条件を判断する、ローカル優先の施工司令室です。現在はPhase 1のLocal APIとMock Routerまで実働します。

## AI5の役割

| AI | 役割 |
|---|---|
| Zero | 唯一の対話窓口、目的理解、承認判断、結果統合 |
| Codex | PC、コード、Git、テスト、施工統括 |
| Gemini | 最新情報、Google、比較、大量調査 |
| Claude | 高精度レビュー、設計監査、原因分析 |
| Manus | Web実務、販売準備、ブラウザ自律操作 |

## 実装状況

| 機能 | 状態 |
|---|---|
| LINE風Zero UI | ✅ 実装済み |
| Zero対話 | ✅ Local API + Mock |
| Router | ✅ 決定論的安全ルール |
| Local API | ✅ localhost実働 |
| Task状態・結果・ログ | ✅ JSON分離保存 |
| 承認UI | ✅ 承認待ち・承認・中止 |
| Codex Remote | ⬜ 未接続 |
| Claude Code CLI | ⬜ 未接続 |
| Gemini Chrome | ⬜ 未接続 |
| Manus Chrome | ⬜ 未接続 |
| Gmail通知 | ⬜ 未接続 |

未接続AIを実接続済みとは表示しません。Mockモードでは各カードへ「Mock接続」と表示します。

## 構成

```text
ai5-hub/
├─ index.html / styles.css / app.js  # 既存LINE風UI
├─ start.ps1                         # localhostサーバー起動
├─ test.ps1                          # 単体テスト起動
├─ shared/statuses.json              # 共通状態表示
└─ server/
   ├─ server.ps1                     # Local HTTP / API
   ├─ router/Router.ps1              # Zero Router
   ├─ adapters/MockAdapter.ps1       # 無課金Mock
   ├─ storage/Store.ps1              # task/result/log保存
   ├─ security/Security.ps1          # 入力検査・Secretマスク
   ├─ tests/                         # Router/API fixture
   ├─ data/                          # 実行時生成・Git対象外
   └─ logs/                          # 実行時生成・Git対象外
```

## 起動方法

Windows PowerShellで実行します。追加パッケージは不要です。

```powershell
cd ai5-hub
powershell -NoProfile -ExecutionPolicy Bypass -File .\start.ps1
```

ブラウザで `http://127.0.0.1:43125/` を開きます。`file://` では検査・利用しません。

## Mock起動

Mockは既定で有効です。明示する場合：

```powershell
$env:AI5_MOCK='true'
.\start.ps1
```

実AI未接続のまま `$env:AI5_MOCK='false'` にすると、AIカードは正しく「未接続」と表示されます。

## Local API

- `GET /api/health`
- `POST /api/tasks`
- `GET /api/tasks/:id`
- `POST /api/tasks/:id/approve`
- `POST /api/tasks/:id/cancel`
- `GET /api/status`

状態は `queued / planning / waiting_approval / running / reviewing / completed / failed / cancelled` です。UIでは日本語表示します。

## 環境変数

| 変数 | 既定値 | 内容 |
|---|---|---|
| `AI5_MOCK` | `true` | Mock Adapterを使用 |
| `AI5_PORT` | `43125` | 将来用。現状は起動引数 `-Port` を使用 |
| `AI5_HOST` | `127.0.0.1` | 将来用。現状は起動引数 `-HostName` を使用 |

`.env`、`.env.*`、`secrets/`、実行ログ、taskデータはGit対象外です。APIキー、Cookie、トークンをHTML・JavaScript・README・ログへ保存しないでください。

## 安全規則

- サーバーは `127.0.0.1` のみにbindし、外部公開しません。
- 書込APIは起動ごとのCSRFトークンを要求します。
- Idempotency-Keyとtask IDで二重受付を防止します。
- 公開、課金、購入、送金、削除、認証変更、第三者送信は承認待ちにします。
- `git push --force`、`git reset --hard`、無断公開、無断課金、無限再試行は実行しません。
- Mock Adapterは外部AI、Webサービス、Git、ローカルファイルを変更しません。

## テスト

```powershell
.\test.ps1
```

実施済みブラウザE2E：起動、Local API接続、メッセージ送信、Zero応答、担当表示、task生成、状態遷移、完了報告、履歴復元、承認UI、中止、360/390/412/430px表示。

## 今後のPhase

1. Phase 2: Codex RemoteでGit HEAD・branch・statusの読み取り専用試験
2. Phase 3: Claude Code CLIでREADME読み取りレビュー
3. Phase 4: Gemini Chromeで検索・質問のみ
4. Phase 5: Manus Chromeで安全なブラウザ操作のみ
5. Phase 6: Gmail完了・承認通知

詳細思想とデータ設計は [ZERO_SPEC.md](./ZERO_SPEC.md) を参照してください。
