# DAIMON Node Registry

正本。各Nodeの実測状態のみ記録する。未検証項目は `UNVERIFIED` とし、推測で `READY` にしない。

## FUJITSU (laptop-32d9hni7)

| フィールド | 値 |
|---|---|
| NODE_ID | `laptop-32d9hni7` |
| DISPLAY_NAME | 富士通 |
| HOSTNAME | LAPTOP-32D9HNI7 |
| MODEL | FUJITSU FMVAXD3BZ |
| ROLE | PRIMARY候補（未昇格） |
| RAM | 約15.69GiB |
| GPU | Intel UHD Graphics 630（専用VRAMなし） |
| TAILSCALE | RUNNING（100.72.31.31、tailnet: teppei.tn.nt@） |
| AI5_HUB | ONLINE（v67-26d52ca、port 43125） |
| CODEX_CLI | インストール済み・認証済み（"Logged in using ChatGPT"、codex-cli 0.155.0-alpha.16） |
| CODEX_EXECUTION_WORKER | **UNVERIFIED** — general-consumer-runtimeはNO_EXECUTION_PRODUCERでfail-closed。この経路はGLOBAL_PROFIT_ENGINE/JAPAN_DIGITAL_EXPORT_ENGINE専用の別系統（profit-engine task bus）であり、DAIMON Node用の汎用実行経路ではない。DAIMON Node用のTask実行経路は未実装。 |
| DAIMON_AI | **NOT_DEPLOYED** — 本仕様に対応する実装はまだ存在しない |
| DAIMON_REMOTE | **PASS（Galaxy→FUJITSU, Chrome Remote Desktop）+ RustDesk Host構築完了（2026-10-01）** — FUJITSU側にRustDesk 1.4.9+67を公式配布元からインストール、Owner承認のUAC昇格経由で`direct-server=Y`/`direct-access-port=21118`/permanent password設定完了。RustDesk ID=`509490385`、port 21118 Listen確認済み、service Running/Automatic。dynabook側（既存稼働中）との対称構成。Chrome Remote DesktopはEMERGENCY_FALLBACKとして現状維持。次段階: FUJITSU⇄dynabook RustDesk実接続E2E。 |
| LOCAL_ROUTER | **PARTIAL** — ランタイム(llama.cpp b10536)+モデル(Qwen2.5-7B-Instruct Q4_K_M)配置・smoke test PASS済み。DAIMON adapter/ルーティング統合は未実装。詳細は [DAIMON_WORKER_ROUTING_SPEC.md](./DAIMON_WORKER_ROUTING_SPEC.md) §11-12。 |
| GIT_PROCESS_ANOMALY | 2026-09-29調査時点で再現せず。ベースライン: git.exe 2プロセス（Claude Code自身のstatus polling由来）、空きRAM約3.64GiB。過去の約851プロセス／約7.49GiB異常は再現不可、原因は既知の30秒ポーリング2系統（general-consumer, zero-bridge）のgit呼び出しにタイムアウト保護がないことによる一過性の可能性が高いが未確定。 |
| LAST_VERIFIED | 2026-09-29 (Claude Code session) |

## DYNABOOK (desktop-p3q429h)

| フィールド | 値 |
|---|---|
| NODE_ID | `desktop-p3q429h` |
| HOSTNAME | DESKTOP-P3Q429H |
| ROLE | SECONDARY / MOBILE / FAILOVER |
| CODEX_EXECUTION_WORKER | **PASS（実機実証済み、2026-09-30）** — `DAIMON-DYNABOOK-DISPATCH-TEST-20260930-01`他をclaim→実行→Result/Receipt/Evidence返却まで実機確認（詳細は[DAIMON_WORKER_ROUTING_SPEC.md](./DAIMON_WORKER_ROUTING_SPEC.md)「FUJITSU⇄DYNABOOK 実dispatch E2E」） |
| TAILSCALE | RUNNING、ただし **`daimon.sales.jp@`テナント**（FUJITSU側は`teppei.tn.nt@`テナント）— 別tailnetのため相互に見えなかった。dynabook IP: 100.110.32.108 |
| RUSTDESK | **稼働中**（2026-09-30実測）— service_state=Running, start_type=Auto, process_count=4, port 21118 listening, direct_server=Y, verification_method=use-permanent-password |
| CHROME_REMOTE_DESKTOP | RUNNING（EMERGENCY_FALLBACK扱い、process_count=2） |
| AI5_DEVICE_WORKER | **Enabled・Running**（2026-09-30実測、last_run=18:08:27）。2026-09-12時点でDisabledだった状態からOwner側で復旧済み。 |
| GITHUB_BUS_CHANNEL | `daimon-app/ai5-github-result-bus`（`device_id: teppei-dynabook-v83hs`）。2026-09-30時点で**稼働確認済み**（休眠状態は解消）。 |
| LAST_VERIFIED | 2026-09-30（FUJITSU側からGitHub Result Bus経由で実データ独立検証済み） |

## Tailnet 実測（2026-09-30、両視点）

FUJITSU視点（`teppei.tn.nt@`テナント）:
```
100.72.31.31   laptop-32d9hni7  teppei.tn.nt@    windows  online
100.72.10.64   iphone-12        teppei.tn.nt@    iOS      -
100.115.36.81  pixel-10a        teppei.tn.nt@    android  offline
100.86.34.48   z-fold8-ultra    teppei.tn.nt@    android  offline
```

dynabook視点（`daimon.sales.jp@`テナント、READ-ONLY調査Task経由で実測）:
```
100.110.32.108  desktop-p3q429h  daimon.sales.jp@  windows  -
100.72.33.24    pixel-10a        daimon.sales.jp@  android  -
100.65.78.107   z-fold8-ultra    daimon.sales.jp@  android  active（direct接続、Galaxy Z Fold実機と判断）
```

**重要**: FUJITSUとdynabookは異なるTailscaleテナントに所属しているため直接は見えない。pixel-10a/z-fold8-ultraは両テナントに別IPで登場しており、複数テナント参加が可能な構成。DAIMON RemoteをRustDesk+Tailscaleで統合する場合、テナント統一または双方tailnet参加が必要。

## 実装済み（2026-09-29時点）

- DAIMON Node用Task Queue / Level0-1 Router / Worker Registry / Result / Receipt / Evidence — `ai5-hub/tools/`配下、実タスクでPASS確認済み（詳細: [DAIMON_WORKER_ROUTING_SPEC.md](./DAIMON_WORKER_ROUTING_SPEC.md)）
- LOCAL_ROUTER（Qwen2.5-7B-Instruct, llama.cpp b10536）— ルーティング判断・自己実行の両方で実測PASS
- lease/重複実行防止、REVIEW_WAIT継続（Worker Aが待機してもQueue全体は止まらない）

## 実装済み（2026-09-30追加）

- FUJITSU用Codex execution adapter（`Invoke-DaimonDispatch.ps1`内、profit-engineとは別系統）— 実タスクでファイル作成・検証までPASS
- DAIMON AI可視化UI（`Start-DaimonDashboard.ps1`、独自ポート43126、日本語UI、Tailscale経由でも閲覧可）
- Owner向け日本語ポリシー・Owner Gateテンプレート（Codex/Claude/将来Worker共通契約として正本化）
- FUJITSU ⇔ dynabook 実dispatch E2E（GitHub Result Bus経由、独立検証済みPASS）
- Galaxy → FUJITSU DAIMON Remote（Chrome Remote Desktop経由、実機LIVE確認済み）

## 既知の未着手項目（2026-09-30時点）

- DAIMON RemoteのRustDesk統合（dynabook側の既存RustDesk正本を基準にFUJITSU側を同一tailnetへ接続。Owner指示待ち、推測導入はしない）
- Galaxy → FUJITSU DAIMON AI経由のTask投入E2E（ダッシュボードは読み取り専用、投入UI/APIは未実装）
- Galaxy → dynabook DAIMON Remote/AI経路の実機E2E
- 再起動後の自動復旧チェーン（AI5 HUBのinstall-autostart.ps1パターンは既存・流用可能、DAIMON Node側は未接続）
