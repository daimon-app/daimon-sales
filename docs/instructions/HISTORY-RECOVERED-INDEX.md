# DAIMON 過去指示書・施工仕様 回収索引

> 注意: これは原文全文がGitHub上で確認できていない過去指示の回収索引。内容を創作せず、現在確認できている事実だけを記録する。原文を回収できたものから個別Markdownへ昇格する。

## 2026-06

### DAIMON 現場休憩スイッチ / 基本実装・修正
- 種別: 実装施工 / 修正仕様
- 対象: 現場休憩スイッチ（後の切り替えスイッチ）
- 確認事項: PWA系実装、UI/心理設計、DAIMON思想「ズレたら戻る」
- 状態: 原文回収待ち

### DAIMON 今日の一手 / 運用仕様
- 種別: 運用指示
- 対象: 今日の一手
- 確認事項: 夜20:00に1件、1分以内の一手を出す運用へ更新
- 状態: 原文回収待ち

## 2026-07

### DAIMON 人間OS / UX心理設計ルール
- 種別: 設計指示
- 対象: DAIMON全体
- 確認事項: 心理学・行動経済学・神経科学・Human OSの観点をUX/UIに適用。継続率より「戻れたこと」を成功として扱う。
- 状態: 原文回収待ち

## 2026-08-05〜08-07

### アファメーション / 文字サイズ・中央寄せ・表示切れ修正
- 種別: 修正仕様指示書
- 対象: teppei-vision-board / affirmation系
- 確認事項: アファメーション文字拡大、中央寄せ、下部表示切れ対策、スマホ表示確認
- 状態: 原文回収待ち

### 朝モード心理実装 バッチ1
- 種別: 実装施工
- 対象: アファメーション朝モード
- 確認事項: 共通overlay構造、`.ov-title / .ov-sub / .ov-badge / .ov-affirm`、名前タグ `.self`、演出優先で文字量削減は最後
- 状態: 原文回収待ち

## 2026-08-07〜08-12

### アファメーション販売版 / 続行仕様
- 種別: 続行施工指示
- 対象: DAIMON販売版
- 確認事項: 停止中作業の再開、既存ZIP/実コード確認、朝・仕事・夜・逆境の不具合修正
- 状態: 原文回収待ち

### 逆境バージョン 全画面・ボタン被り修正
- 種別: 修正仕様指示書
- 対象: 逆境バージョン
- 確認事項: 全画面化、上部ボタン被り改善、その他UI欠陥監査
- 状態: 原文回収待ち

### 逆境バージョン バイノーラルビート修正
- 種別: バグ修正指示
- 対象: 逆境バージョン
- 確認事項: バイノーラルビート音声が出ない不具合
- 状態: 原文回収待ち

### 朝・仕事・夜 音声/UI統合修正
- 種別: 修正仕様
- 対象: DAIMON販売版
- 確認事項: 音声停止、途中戻り、ホーム、下ナビ、仕事/夜の音声不具合、朝の被り、3レイヤー表示
- 状態: 原文回収待ち

## 2026-08-13〜08-15

### GitHub正本化 / AI施工連携
- 種別: Git運用指示
- 対象: DAIMON開発全体
- 確認事項: GitHub main / MASTER.md を基準に再構築、ChatGPT↔GitHub連携、途中作業保護
- 状態: 一部ルールは現行 `docs/instructions/README.md` へ再定義済み

### Zero-Codex Bridge MVP
- 種別: 設計施工実装
- 対象: zero-codex-bridge / AI5 HUB
- 確認事項: AI5 HUB → Local API → Zero Router → HMAC署名 → Bridge → `codex exec --json` → Windows → 結果返却
- 確認済み成果: Phase 2 SUCCESS、Local API実接続、起動 `launch-ai5-hub.cmd`、localhost:43125
- 状態: 原文回収待ち

### AI5 HUB LINE風UI
- 種別: 設計施工実装
- 対象: ai5-hub
- 確認事項: Zeroへの指示を入口にAI5兄弟へルーティング、LINE風UI、スマホ利用方向
- 状態: 原文回収待ち

### AI5 HUB スマホ化 / Phase 2.5
- 種別: 設計施工実装指示書
- 対象: ai5-hub / Tailscale Serve
- 確認事項: tailnet限定HTTPS、Tailscale Serve、localhostサービスをprivate公開、実スマホHTTPS試験
- 確認済み状態: コード施工とローカル検査完了、Windows再起動/UACで実スマホ試験保留だった時点あり
- 状態: 原文回収待ち

### Zero-Codex PC遠隔運用
- 種別: PC施工 / リモート運用指示
- 対象: Windows / Codex / Chrome Remote Desktop / Wake関連
- 確認事項: PC電源、遠隔復帰、緊急用Codex、UAC、通常commit/push自動、merge/破壊操作確認
- 状態: 原文回収待ち

## 2026-08-17

### 一手箱 AI EXECUTION MVP v1
- 種別: 設計施工実装指示
- 対象: `daimon-ai-execution`
- 確認事項: 既存一手箱を新規作り直さずAI実行エンジンへ進化。思いつき→投入→AI判断→AI5/PC実行→検査→完了報告
- 確認済み成果: PWA、IndexedDB、何でも箱、題作成、振り分け、子題、実行状態、検索、大量保存、オフライン
- 確認済みHEAD: `182cf73837d06991b9b20855c9a507b589b21e89`（当時）
- 状態: 原文回収待ち

### AI5兄弟ルーティング正式化
- 種別: 運用/設計指示
- 対象: AI5全体
- 確認事項: Zero=総司令塔、Codex=PC施工司令塔、Gemini=第二施工/調査、Claude=高精度レビュー、Manus=Web実務。正式経路も定義。
- 状態: AGENTS.md等に反映済みとの報告あり。原文回収待ち

### Claude Code 緊急施工設定
- 種別: PC施工設定指示
- 対象: Claude Code 2.1.233
- 確認事項: bypassPermissions無効、通常commit/push・開発コマンド自動許可、merge/破壊操作は確認、force push/重要Windows設定変更禁止
- 状態: 原文回収待ち

## 2026-08-18

### 販売基盤 初期施工
- 種別: 販売施工 / 設計施工実装
- 対象: `daimon-sales`
- branch: `feat/marketing-foundation`
- commit: `4dd496a`
- 基準正本: `origin/main / 4f60cc5`（当時）
- 確認事項: Phase 0監査、販売LP、プライバシー/利用規約/特商法/問い合わせドラフト、プロフィール、ブランドガイド、初期投稿30本、SNS設定、CM-A〜E、Google Play掲載/審査準備
- 状態: GitHub成果物あり。原文指示書は回収待ち

### DAIMON SALES EXECUTION PLAYBOOK
- 種別: 販売施工実行正本
- 対象: `daimon-sales`
- path: `marketing/SALES-EXECUTION.md`
- main commit: `7df7e2bb423593535dced1b7277587cd97bdc9c6`
- 状態: GitHub原文あり

### 指示書GitHub保存・回収運用
- 種別: Git/文書運用指示
- 対象: DAIMON関連Repository全体
- path: `docs/instructions/2026-08-18/instruction-archive-policy.md`
- 状態: GitHub保存済み

## 今後の回収対象

優先して原文を探索する場所:

1. 各Repositoryの既存branch / commit / PR
2. ローカルの `.md` / `.txt` / `.docx` / 作業メモ
3. `MASTER.md` / `AGENTS.md` / `README`
4. Codex / Claudeが生成した施工ファイル
5. 過去チャットの完成版指示書

原文が見つかったら、この索引の該当項目に正式path・commitを追記し、個別Markdownへ昇格する。
