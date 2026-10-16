# GALAXY_LOCAL_AI — Galaxy端末内ローカルAI Worker（正本）

状態：**CONDITIONAL（導入・E2E PASS、2026-10-17）**。条件の内容は §10 を参照。

## 1. 位置づけ

- `WORKER_ID = GALAXY_LOCAL_AI`、`NODE = GALAXY`、`TYPE = LOCAL_AI`。FUJITSUの `LOCAL_ROUTER`（[DAIMON_WORKER_ROUTING_SPEC.md](./DAIMON_WORKER_ROUTING_SPEC.md) §11-12）とは別identity。
- 配車本部ではない。担当範囲は要約、分類、抽出、ログ解析、オフラインChat、軽い診断（`capabilities = summarize / classify / extract / log_analysis / chat / light_diagnostic`）。
- 範囲外のTask（コード施工など）はGalaxyへ送らず、`GALAXY_LOCAL_AI → FUJITSU LOCAL_ROUTER → Claude / Codex / Gemini` の順にEscalateする。
- 既存のDAIMONアプリ、DAIMON Remote、キーボード、ホーム環境、端末設定には手を入れていない。

## 2. 実機PRE-FLIGHT（2026-10-16 22:48、固定Tool `Invoke-DaimonGalaxyPreflight.ps1` で実測）

| 項目 | 実測値 |
|---|---|
| 機種 | samsung SCG39 |
| SoC | Qualcomm SM8850（platform `canoe`） |
| RAM | 10.83 GiB（通常時の空き 3.46〜6.7 GiB、swap 12 GiB） |
| Storage空き | 163 GB（`/data`） |
| Android | 17（SDK 37）、ABI `arm64-v8a` |
| GPU / NPU | Adreno（Vulkan/EGL）、Hexagon HTP V81（`libSnpeHtpV81Stub.so`、QNN関連ライブラリあり） |
| thermal / battery | thermal_status 0、battery 34.1℃・91%・充電中 |
| 既存のLocal AI runtime | Termuxのみ導入済み |

## 3. 構成（実装済み）

```
FUJITSU bridge (ai5-hub/tools/galaxy_local_ai.py)
  └─ USB ADB ─> /data/local/tmp/daimon-llm (mode 700, shellユーザー領域、アプリ導入なし)
                 ├─ inbox/<task>.request.json + <task>.prompt.txt
                 ├─ worker/galaxy_worker.sh   (ai5-hub/galaxy-worker/galaxy_worker.sh)
                 │    ├ 秘密情報らしき語を含むTaskは推論せず SECRET_REFUSED
                 │    ├ resource guard（thermal / 電池温度 / 電池残量 / 空きRAM）
                 │    └ 必要時だけ llama-server を 127.0.0.1:8090 で起動（起動ごとのランダムAPIキー）
                 ├─ outbox/<task>.status + .response.json   ← オフラインでもここに残る
                 └─ state/heartbeat, resource, events.log
  └─ collect: outbox → <bus_root>/results + receipts（.synced印で冪等、二重書き込みなし）
```

- runtime：**llama.cpp b10536 公式 android-arm64 ビルド（CPU、6 threads）**。MITライセンス。FUJITSU LOCAL_ROUTERと同じ版。
  - 選定理由：GGUFでモデル交換が容易、端末内HTTP（OpenAI互換）で薄いAdapterから呼べる、完全オフライン、アプリ導入が不要。
  - LiteRT-LM / MLC LLM：今回は比較していない。NPU（HTP V81）を使えば省電力化の余地がある（§10）。
- 運用：`-c 2048 -np 1`、温度0、`repeat_penalty 1.15`。常駐せず、Task時にload → 処理 → unload。

## 4. モデル比較（`ai5-hub/evidence/galaxy-local-ai/GALAXY_BENCH_RESULTS.json`、9項目の自動採点）

評価項目：日本語要約、JSON/schema遵守、承認要否の分類（危険／安全）、ログ解析（日本語指示の遵守を含む）、軽い判断、五十音順、原文に忠実な要約、軽いコード理解。

| モデル | 品質 | 生成 tok/s | load | 実行後thermal | 判定 |
|---|---|---|---|---|---|
| gemma-3-1b-it Q4_K_M | 5/9 | 59.8 | 1.7s | 0 | 失格（品質） |
| Qwen3-1.7B Q4_K_M | 4/9 | 44.7 | 2.2s | 1 | 失格（品質） |
| Qwen3-4B-Instruct-2507 Q4_K_M | 6/9 | 17.1 | 3.8s | **2** | 失格（発熱。2回測定とも再現） |
| **gemma-3-4b-it Q4_K_M** | **7/9** | **14.9** | **4.2s** | 1 | **採用** |
| Phi-4-mini-instruct Q4_K_M | 4/9 | 16.4 | 3.7s | 2 | 失格（品質・日本語が弱く、原文にない内容を作る） |

- 7B級は比較対象外とした。Q4で約4.7 GBあり、実測の通常空きRAM 3.46 GiBを超えるため。
- 選定ルール：`quality*10 + min(tok/s, 20)/4 - peak_rss_gib`。失格条件は、load失敗、thermal≥2、電池≥40℃、実行後の空きRAM<1.5 GiB、5 tok/s未満、品質70%未満。
- 採点の不具合（設問文の繰り返しで合格、英語回答で合格など）を一度修正し、全候補を測り直している。
- 敗者モデルのファイルは、選定証拠が確定した後にPCキャッシュから削除済み。Galaxy上に残っているのは採用モデルのみ。
- 採用モデル：`gemma-3-4b-it-Q4_K_M.gguf`、SHA-256 `04a43a22e8d2003deda5acc262f68ec1005fa76c735a9962a8c77042a74a7d19`、2.49 GB。ライセンスはGemma Terms of Use（商用利用は可能だが、禁止用途ポリシーに従う）。

## 5. 実運用時のresource実測（E2E `GALAXY_E2E_20261017-053822.json`）

- 端末が回収できない匿名メモリ（RssAnon）：**2.57 GiB**。ファイル分（mmap、OSが回収可能なキャッシュ）：約2.3 GiB。
- モデルload中のGalaxy空きRAM：**3.95 GiB**。unload後は約6.7 GiBへ戻る。
- 発熱：4Bモデルの連続ベンチ中で、電池温度は最大31.4℃、thermal_statusは最大1（採用モデル）。
- 電池：試験中はUSB給電していたため、正確な消費量は未測定。給電中でも、約30分の連続ベンチで残量が98%から96%へ下がった。

## 6. Resource Policy（`galaxy_worker.sh` で強制。envでは厳しくする方向にしか変更できない）

| 条件 | 動作 |
|---|---|
| thermal_status ≥ 2 | 推論せずunloadし、`ESCALATE / RESOURCE_GUARD_THERMAL` |
| 電池温度 ≥ 40.0℃ | 同上（`RESOURCE_GUARD_BATTERY_TEMP`） |
| 非給電かつ電池 < 30% | 同上（`RESOURCE_GUARD_BATTERY_LOW`） |
| 空きRAM < 1.5 GiB | 同上（`RESOURCE_GUARD_MEMORY`） |

## 7. Security

- Galaxy上の作業領域は mode 700 で、llama-serverは `127.0.0.1` だけで待ち受け、起動ごとにランダムなAPIキーを付ける。これにより、端末内の他アプリやブラウザのページからは呼べない。
- password / token / cookie / private key / MFA / credential などの語を含むTaskは、モデルへ渡さず `SECRET_REFUSED` とし、AIには回さずWAITING_OWNERへ送る。
- prompt本文を学習に使うことはなく、ログにも残さない。Resultには出力とresource値だけを記録する（`secret_recorded=false`）。

## 8. E2E結果（2026-10-17 05:38、`ai5-hub/evidence/galaxy-local-ai/GALAXY_E2E_20261017-053822.json`）

| | 内容 | 結果 |
|---|---|---|
| A | DAIMON → GALAXY_LOCAL_AI → 日本語Task → Result/Receipt | PASS |
| B | Wi-Fi／モバイルデータOFFで端末内処理 → 正答（ログ解析）→ 通信状態を元どおりに復旧 | PASS |
| C | 範囲外Task（コード施工）→ FUJITSU LOCAL_ROUTERへEscalate、秘密情報らしき語を含むTask → 推論拒否 | PASS |
| D | 通信復旧後にResult同期、2回目の同期では新規0件・重複0件 | PASS |
| E | resource guard作動 → 推論拒否・unload・Escalate | PASS |
| F | `<bus_root>/worker-registry.json` への登録（DAIMONダッシュボードのWorkers表示の元データ） | PASS |
| G | 実イベント `<bus_root>/events/galaxy_local_ai.jsonl`（「実施工を見る」に統合できる形式） | PASS |

## 9. 固定Tool（夜間ZERO-TOUCH）

通常操作はすべて `python ai5-hub/tools/galaxy_local_ai.py <status|bench-next|select|deploy|e2e|stop|logs|cleanup-losers>` で行う。`.claude/settings.json` にはサブコマンドごとに完全一致で登録している。新規セッションでGALAXY_LOCAL_AI施工を31.3分連続実行し、通常のPermission要求は0件、固定Tool以外のコマンドは0件だった（`ai5-hub/evidence/night-zero-touch/`）。

## 10. 判定：CONDITIONAL（理由と残課題）

1. **Galaxy単独での常時運用は未完成。** 現在の起動・同期は、FUJITSUからUSB ADB経由で行っている。GalaxyだけでTaskを受け取ってResult Busへ同期するには、Termux上の常駐Adapterとネットワーク同期が必要になり、Galaxy上へのGitHub認証情報の配置（Owner Gate）が伴う。
2. **モデルの弱点。** 範囲外の作業（五十音順、短い計算の出力）や、「安全な作業にも承認が要る」と答える保守的な誤りがある。後者は安全側の誤りなので許容する。範囲外の作業はEscalateで扱う。
3. **NPU（HTP V81）は未使用。** 省電力化の余地として、LiteRT-LM / QNN系runtimeの比較を次の段階で行う。
4. **Escalate先の判断品質。** LOCAL_ROUTER（7B）が、コード施工Taskを自分で処理すると判断した（`ESCALATE=false`）。経路は動作しているが、LOCAL_ROUTER側の判断品質は別Taskとして改善する。
5. **電池消費量は未測定。** 給電なしの測定が必要（日中、本人がGalaxyを使っていない時間帯に実施する）。
