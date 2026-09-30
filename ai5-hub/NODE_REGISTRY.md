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
| DAIMON_REMOTE | **PASS** — 既存Chrome Remote Desktopを再利用（新規ソフト導入なし）。Galaxy→FUJITSU実接続、Owner本人により2026-09-30にLIVE確認済み。 |
| LOCAL_ROUTER | **PARTIAL** — ランタイム(llama.cpp b10536)+モデル(Qwen2.5-7B-Instruct Q4_K_M)配置・smoke test PASS済み。DAIMON adapter/ルーティング統合は未実装。詳細は [DAIMON_WORKER_ROUTING_SPEC.md](./DAIMON_WORKER_ROUTING_SPEC.md) §11-12。 |
| GIT_PROCESS_ANOMALY | 2026-09-29調査時点で再現せず。ベースライン: git.exe 2プロセス（Claude Code自身のstatus polling由来）、空きRAM約3.64GiB。過去の約851プロセス／約7.49GiB異常は再現不可、原因は既知の30秒ポーリング2系統（general-consumer, zero-bridge）のgit呼び出しにタイムアウト保護がないことによる一過性の可能性が高いが未確定。 |
| LAST_VERIFIED | 2026-09-29 (Claude Code session) |

## DYNABOOK (desktop-p3q429h)

| フィールド | 値 |
|---|---|
| NODE_ID | `desktop-p3q429h` |
| HOSTNAME | DESKTOP-P3Q429H |
| ROLE | SECONDARY / MOBILE / FAILOVER |
| CODEX_EXECUTION_WORKER | PROVEN（Owner確認済み。詳細な実測ログはFUJITSU側から未取得） |
| TAILSCALE | **未確認** — 2026-09-29時点でFUJITSU側から見えるtailnet（teppei.tn.nt@）に本ノードは出現しなかった。FUJITSU⇔dynabook連携を組む前に要確認。 |
| GITHUB_BUS_CHANNEL | `daimon-app/ai5-github-result-bus`（`device_id: teppei-dynabook-v83hs`, `AI5_SECONDARY_EXECUTION_DEVICE`, controller=`main-fmv-laptop-32d9hni7`=本FUJITSU機）に2026-08-28時点で実証済みのdevice-to-device failoverが存在。ただし`bus/tasks/`の最終更新は2026-08-31で、以後約1ヶ月間活動なし（休眠状態）。dynabook側に現在アクティブなpollerが存在するか、FUJITSU側からは確認不能。 |
| LAST_VERIFIED | 未取得（FUJITSU側からの直接調査不可、Owner/dynabook側報告に基づく） |

## Tailnet 実測（2026-09-29, FUJITSU視点）

```
100.72.31.31   laptop-32d9hni7  teppei.tn.nt@  windows  online
100.72.10.64   iphone-12        teppei.tn.nt@  iOS      -
100.115.36.81  pixel-10a        teppei.tn.nt@  android  offline (last seen 1d ago)
100.86.34.48   z-fold8-ultra    teppei.tn.nt@  android  offline (last seen 3d ago)
```

dynabookはこのtailnetに現れていない。DAIMON Remote / PC-to-PC bidirectional recoveryをTailscale経由で構築する場合、dynabook側のTailscale参加状況を先に確認する必要がある。

## 実装済み（2026-09-29時点）

- DAIMON Node用Task Queue / Level0-1 Router / Worker Registry / Result / Receipt / Evidence — `ai5-hub/tools/`配下、実タスクでPASS確認済み（詳細: [DAIMON_WORKER_ROUTING_SPEC.md](./DAIMON_WORKER_ROUTING_SPEC.md)）
- LOCAL_ROUTER（Qwen2.5-7B-Instruct, llama.cpp b10536）— ルーティング判断・自己実行の両方で実測PASS
- lease/重複実行防止、REVIEW_WAIT継続（Worker Aが待機してもQueue全体は止まらない）

## 既知の未着手項目（2026-09-29時点）

- FUJITSU用Codex execution adapter（profit-engine用general-consumer-runtimeとは別に新規実装が必要、未着手）
- DAIMON Remote（Galaxyからの画面/入力操作）
- FUJITSU ⇔ dynabook の実dispatch — 既存GitHubチャンネルは休眠中、dynabook側の稼働確認が先決（Owner判断待ち）
- 再起動後の自動復旧チェーン（AI5 HUBのinstall-autostart.ps1パターンは既存・流用可能、DAIMON Node側は未接続）
