# AI5 HUB

AI5 HUBは、鉄兵がZeroだけへ自然文で指示し、Zeroが目的・安全条件・担当AI・完了条件を判断するローカル施工司令室です。Phase 2では、既存LINE風UIと実証済みZero-Codex Bridgeを統合し、公式Codex CLIによるPC施工と結果返却まで実働します。

Phase 2.5のスマホ実働化コードは施工済みです。PWA、Tailscale Serve向け本人認証、8時間セッション、one-time承認token、offline表示、自動起動スクリプトを追加しました。現在のPCはWindows Installerの再起動待ち状態のため、Tailscale本体の導入・OAuth・実機試験のみ保留です。詳細は [MOBILE_SETUP.md](./MOBILE_SETUP.md) を参照してください。

## 実装状況

| 機能 | 状態 |
|---|---|
| LINE風Zero UI | ✅ 実装済み |
| Zero対話・Router | ✅ Local API実働 |
| Task状態・結果・ログ | ✅ JSON分離保存 |
| 承認UI | ✅ 承認・中止 |
| Zero-Codex Bridge | ✅ Phase 1資産を統合 |
| Codex Remote | ✅ 公式 `codex exec --json` 実接続 |
| PWA / スマホUI | ✅ 実装・4幅検査済み |
| Tailscale private HTTPS | 🚧 PC再起動・本人OAuth待ち |
| Mobile session / logout | ✅ 実装・擬似identity検査済み |
| One-time承認token | ✅ 期限・再利用拒否 |
| Claude Code CLI | ⬜ 未接続 |
| Gemini Chrome | ⬜ 未接続 |
| Manus Chrome | ⬜ 未接続 |
| Gmail通知 | ⬜ 未接続 |

未接続AIを接続済みとは表示しません。

## 構成

```text
ai5-hub/
├─ index.html / styles.css / app.js      # 既存LINE風UI
├─ launch-ai5-hub.cmd                    # 通常起動（ダブルクリック）
├─ start.ps1 / start-mobile.ps1 / test.ps1
├─ manifest.webmanifest / service-worker.js / icons/
├─ install-autostart.ps1                 # ログイン時自動起動
├─ integrations/codex/zero-codex-bridge # commit 09632f5由来Bridge
└─ server/
   ├─ server.ps1                         # localhost API
   ├─ router/Router.ps1                  # Zero Router
   ├─ task-service/CodexService.ps1      # 署名・投入・Worker起動
   ├─ task-service/CodexWorker.ps1       # Bridge実行・結果同期
   ├─ adapters/MockAdapter.ps1
   ├─ storage/Store.ps1
   ├─ security/Security.ps1
   ├─ data/ / logs/ / runtime/           # Git対象外
   └─ tests/
```

経路は `AI5 HUB UI → Local API → Zero Router → signed inbox → Zero-Codex Bridge → codex exec --json → Windows → result → UI` です。

## 起動方法

通常は `launch-ai5-hub.cmd` をダブルクリックします。Tailscale設定済みならprivate HTTPS Serveも起動します。サーバーは引き続き `127.0.0.1:43125` だけで待受け、ルーターのポート開放は不要です。

開発時は次でも起動できます。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start.ps1
```

既定はCodex実接続です。外部AIを消費しないUI試験だけを行う場合：

```powershell
$env:AI5_MOCK='true'
.\start.ps1
```

## Local API

- `GET /api/health`
- `GET /api/status`
- `POST /api/tasks`
- `GET /api/tasks/:id`
- `GET /api/tasks/:id/result`
- `POST /api/tasks/:id/approve`
- `POST /api/tasks/:id/cancel`

状態は `queued / planning / waiting_approval / running / reviewing / completed / failed / cancelled`。会話、task、execution、resultは分離保存し、ブラウザ再読込後も復元します。

## 認証・安全規則

- サーバーは `127.0.0.1` のみにbindし、外部公開しません。
- UI書込は起動ごとのCSRFトークンを要求します。
- スマホ経路はTailscale端末identityとtailnet ACLで匿名アクセスを拒否します。
- remote sessionは8時間。cookieはSecure、HttpOnly、SameSite=Strictです。
- logout時はサーバー側sessionを無効化します。
- dangerous task承認tokenはtask ID紐付け、5分期限、SHA-256保存、一度だけ利用可能です。
- Local APIからBridgeへの投入は、実行時生成する256-bit HMAC shared secretで署名します。
- secretは `server/runtime/bridge.secret` にのみ置き、Git・UI・ログへ出しません。
- task ID、Idempotency-Key、Bridge queue、worker lockの各層で二重実行を防ぎます。
- Codex書込先はBridge専用workspaceに限定し、追加許可先は設定で明示します。
- 実行タイムアウトは既定600秒、自動retryは既定0回です。無限待機・無限再送しません。
- Secretらしき入力とログはマスクし、APIキーやCookieを保存しません。
- 公開、課金、送金、購入、大量削除、認証変更、第三者送信、破壊的Git操作は承認境界で停止します。
- `git push --force`、`git reset --hard`、無断main変更、無断公開・課金は実行しません。

設定例は `integrations/codex/zero-codex-bridge/config.example.json`。実設定、queue、results、logs、runtimeはGit対象外です。

## テスト

```powershell
.\test.ps1
```

Phase 2受け入れ実績（2026-08-17）：

| TEST | 結果 |
|---|---|
| A UI/API→Codexファイル作成 | ✅ `AI5_CODEX_LIVE_OK`、17 bytes、改行なし |
| B Codexファイル読取 | ✅ 完全一致をHUBへ返却 |
| C 存在しないファイル | ✅ HUBを落とさずfailed、理由・retryable・本人操作を保存 |
| D 同一task_id | ✅ 二重施工なし、attemptCount 1 |
| E 不正認証 | ✅ CSRF 403、HMAC改ざん検査通過 |
| F Bridge停止 | ✅ bridge_unavailable、HUBは稼働継続 |
| G 施工中の再読込 | ✅ running状態を復元 |
| H 完了後の再読込 | ✅ 結果を会話履歴へ復元 |

ブラウザE2EではCodex接続表示、状態遷移、技術詳細、360/390/412/430pxの横あふれなしも確認済みです。

Phase 2.5検査では、既存Codex実施工、匿名401、擬似Tailscale identity login、Secure session、logout、通信断後の結果保持、Bridge停止、PC offline UX、duplicate、CSRF、HMAC改ざん、dangerous task停止、one-time承認、4種類のスマホ幅を確認済みです。private HTTPS実機、Android/iPhoneホーム画面追加はTailscale導入後に実施します。

## 環境変数

| 変数 | 既定値 | 内容 |
|---|---|---|
| `AI5_MOCK` | `false` | `true` でMock Adapter |
| `AI5_BRIDGE_DISABLED` | `false` | `true` で停止故障試験 |
| `CODEX_EXECUTABLE` | 自動検出 | 公式Codex CLIの明示パス |

## 今後のPhase

1. Claude Code CLIの読み取りレビュー接続
2. Gemini Chromeの検索・質問接続
3. Manus Chromeの安全なブラウザ操作接続
4. Gmail完了・承認通知

詳細思想は [ZERO_SPEC.md](./ZERO_SPEC.md)、Bridge継承元は [PROVENANCE.md](./integrations/codex/zero-codex-bridge/PROVENANCE.md) を参照してください。
