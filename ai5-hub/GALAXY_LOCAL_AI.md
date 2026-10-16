# GALAXY_LOCAL_AI — Galaxy端末内ローカルAI Worker（正本・施工中）

状態：**PLANNED / PRE-FLIGHT待ち**（2026-10-16）。Galaxy実機の実測値が取得できるまで、モデル・runtimeは**選定しない**（推測禁止）。

## 1. 位置づけ

- `WORKER_ID = GALAXY_LOCAL_AI`、`NODE = GALAXY`、`TYPE = LOCAL_AI`。FUJITSUの `LOCAL_ROUTER`（[DAIMON_WORKER_ROUTING_SPEC.md](./DAIMON_WORKER_ROUTING_SPEC.md) §11-12）とは別identity。
- 配車本部ではない。Task一次分類、要約、テキスト整理、ログ解析、オフラインChat、定型処理、軽い診断を担当する。
- Acceptance Criteriaが明確で能力内の軽Taskは自分で完了してよい。それ以外は
  `GALAXY_LOCAL_AI → FUJITSU LOCAL_ROUTER → Claude / Codex / Gemini` の順にEscalateする。
- 既存のDAIMONアプリ、DAIMON Remote（RustDesk / Tailscale）、キーボード、ホーム環境には手を入れない。

## 2. 構成（予定）

```
DAIMON Result Bus ──(Task)──> GALAXY Worker Adapter ──HTTP 127.0.0.1──> Local LLM runtime (独立プロセス)
        ^                              │
        └──(Result/Receipt/Evidence)───┘   ※オフライン時は端末内outboxに保持し、復帰後に同期
```

- runtimeはDAIMONアプリへ直結しない。独立したLocal AIプロセスと、薄いWorker Adapterに分ける。
- Adapterはlocalhostだけに接続し、外部へは送信しない。モデル交換は設定1行で行える形にする。

## 3. runtime候補（実機PRE-FLIGHT後に比較して1つ選ぶ）

| runtime | ライセンス | 長所 | 懸念 |
|---|---|---|---|
| llama.cpp（`llama-server`、Termux上） | MIT | GGUFでモデル交換が容易、OpenAI互換HTTPでAdapterから呼びやすい、完全オフライン、FUJITSU LOCAL_ROUTERと同系統 | Termux導入が必要。GPU（Adreno OpenCL）は機種依存 |
| Google LiteRT-LM（AI Edge系） | Apache-2.0 | 対応SoCでGPU/NPUが効き、省電力・高速 | 対応モデル形式が限られる。Adapter連携の自由度 |
| MLC LLM | Apache-2.0 | GPU推論 | モデルごとのコンパイルが必要で、交換コストが高い |

バックグラウンド運用について正直な前提：Androidは常駐プロセスを止めることがある。そのため、常駐ではなく「Task受信時にload → 処理 → idle 5分でunload」の**オンデマンド方式**を基本とする。

## 4. モデル候補（最初から7Bは採用しない）

1.5B〜4B級を主候補とし、端末余力が十分な場合に限り7B級の量子化モデルを比較対象へ加える。ライセンスはダウンロード時にmodel cardで再確認する。

| 候補 | 規模 | ライセンス（要再確認） |
|---|---|---|
| Qwen3-1.7B（Q4_K_M） | 1.7B | Apache-2.0 |
| Gemma 3 1B / 4B（Q4） | 1B / 4B | Gemma Terms of Use |
| Qwen3-4B（Q4_K_M） | 4B | Apache-2.0 |
| Phi-4-mini-instruct（Q4） | 3.8B | MIT |
| （余力時のみ）Qwen2.5-7B-Instruct Q4_K_M | 7B | Apache-2.0（FUJITSUと同一） |

除外：Qwen2.5-3B（Qwen Research License、商用不可）。

評価項目：日本語、instruction following、JSON/schema遵守、Task分類、要約、ログ解析、軽い判断、軽いコード理解、RAM、load時間、tokens/sec、発熱、battery消費、安定性。
**最大モデルではなく、Galaxyで最も実用的な1モデル**を採用し、敗者のモデルファイルは削除して保存しない。

## 5. Resource Policy（初期値、実測後に調整）

| 条件 | 動作 |
|---|---|
| `thermal_status >= 2`（MODERATE以上）または battery温度 >= 40℃ | 推論を中止してunloadし、FUJITSUへEscalate |
| battery < 30% かつ非充電 | ローカル推論をせずEscalate |
| load後の `MemAvailable` < 1.5 GiB | そのモデルを不採用、またはunloadしてEscalate |
| idle 5分 | unload |
| 1 Taskの生成上限 | 512 tokens / 60秒（超過時はEscalate） |

## 6. Offline動作

- オフラインでも `Galaxy → GALAXY_LOCAL_AI` で軽Taskを処理できること。
- Result / Receipt / Evidenceは端末内outboxに書き、ネット復帰後にResult Busへ同期する。`idempotency_key` で重複を防ぎ、同期時に新しいTaskは作らない。

## 7. Security

- password、token、cookie、private key、MFA、credentialをLocal AIへ渡さない。Adapterの入力フィルタで、秘密情報らしき文字列を含むTaskはローカル処理せずに拒否する。
- prompt logや学習履歴に秘密情報を保存しない。prompt本文はEvidenceに残さず、ハッシュと判定結果だけを記録する。

## 8. Worker Registry項目

`WORKER_ID / NODE / TYPE / MODEL / HEALTH / CAPABILITIES / RESOURCE_STATE / OFFLINE_CAPABLE / CURRENT_TASK / HEARTBEAT`
（[NODE_REGISTRY.md](./NODE_REGISTRY.md) に登録。現在は `NOT_DEPLOYED`）

## 9. 施工順とOwner Gate

1. **PRE-FLIGHT**：固定Tool `ai5-hub/tools/Invoke-DaimonGalaxyPreflight.ps1`（読み取り専用、端末変更なし）で実測する。
   - 2026-10-16 22:25 実測：`device_state = NO_DEVICE`（GalaxyがFUJITSUにUSB接続されていない）。Tailscale `100.65.78.107:21118` も到達不可。
   - → Owner Gate `GALAXY_DEVICE_CONNECT`：GalaxyをFUJITSUにUSB接続し、画面ロックを解除する（USBデバッグは既存設定でON）。
   - 接続後は、Taskファイル `ai5-github-result-bus/bus/tasks/GALAXY-LOCAL-AI-20261016-01.json` を、`-GateTaskId` 付きのPRE-FLIGHT実行が検知して自動RESUMEする（Ownerの追加指示は不要）。
2. runtime比較 → 3. モデル比較benchmark → 4. 1モデル採用・判定（READY / CONDITIONAL / NOT_WORTH_IT） → 5. Adapter + Registry登録 → 6. E2E A〜G → 7. 正本更新。
- Termux等のアプリ導入やモデルのダウンロードは、Galaxyへ新しいソフトを入れる操作なので、PRE-FLIGHTで余力を確認してから行う。Galaxyの日常利用を明確に悪化させる場合は導入を強行しない。
