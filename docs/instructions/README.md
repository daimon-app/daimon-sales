# DAIMON Instruction Archive

このディレクトリは、Zero / Codex / Claude / Gemini / Manus 向けに発行した設計・施工・実装・修正・監査・販売・運用指示書のGitHub正本アーカイブ。

## 目的

- チャット移動や文脈喪失が起きてもGitHubから現在地を再構築できるようにする。
- 実装時の判断根拠、対象、禁止事項、完了条件を後から追跡できるようにする。
- 同じ指示を何度も作り直さず、過去指示を再利用・差分更新できるようにする。
- AIの記憶やチャット履歴よりGitHub正本を優先する。

## 優先順位

1. GitHub正本
2. 現在の実コード・Git状態
3. チャット履歴
4. AIの記憶・推測

作業状況・現在地・前提が不明、または他チャットと食い違う場合は推測で続行しない。ユーザー確認で止まらず、対象Repositoryの `main`、最新commit、branch、diff、`MASTER.md`、`AGENTS.md`、`README`、実コードを確認して現在地を再構築する。

未commit作業がある場合は必ず保護し、既存作業を壊さない。

## 保存対象

以下を原則すべて保存する。

- 実装施工仕様指示書
- 設計施工実装指示書
- 修正仕様指示書
- 施工仕様書
- 実行指示書
- 監査指示書
- 販売施工指示書
- UI/UX修正指示書
- バグ修正指示書
- リモート運用・PC施工指示書
- AI5兄弟ルーティング/運用指示
- Git/GitHub運用指示
- 完了判定・検査条件を含む指示

## 命名規則

新規指示は原則として次の形式で保存する。

`docs/instructions/YYYY-MM-DD/<scope>-<short-title>.md`

例:

- `docs/instructions/2026-08-18/ai5-hub-mobile-completion.md`
- `docs/instructions/2026-08-18/sales-foundation-execution.md`
- `docs/instructions/2026-08-18/instruction-archive-policy.md`

## 各指示書に残す最低項目

- 発行日
- 対象Repository
- 対象branch / 基準commit
- 対象アプリ / モジュール
- 目的
- 現在地
- 実装内容
- 壊してはいけない対象
- 本人承認が必要な工程
- テスト / 検査
- 完了条件
- Git運用
- 関連commit / branch / PR

## 過去分

過去のチャットだけに存在する指示書は、全文を確認できるものは原文保存する。全文を確認できないものは勝手に再現せず、`HISTORY-RECOVERED-INDEX.md` に「確認できた事実」として索引化し、原文回収後に正式ファイルへ昇格する。

## 運用ルール

今後、Codex等に施工指示を出したときは、実装対象Repository内の本ディレクトリへ指示書も保存する。コードだけをcommitして指示書をチャットに残さない運用は禁止する。
