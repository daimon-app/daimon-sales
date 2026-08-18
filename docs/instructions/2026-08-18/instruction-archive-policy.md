# 指示書GitHub保存・回収運用指示

発行日: 2026-08-18
対象: DAIMON関連Repository / Zero / Codex / Claude / Gemini / Manus

## 目的

今後発行する実装施工仕様指示書、設計施工実装指示書、修正仕様指示書、施工仕様書、実行指示書、監査指示書、販売施工指示書などを、チャットだけに残さずGitHub正本へ継続保存する。

あわせて、過去に発行済みの指示書も可能な範囲で回収し、原文または確認可能な事実ベースの履歴としてGitHubへ集約する。

## 必須運用

1. 新しい指示書を受領したら、実装前または実装commitと同時に対象RepositoryへMarkdown保存する。
2. 保存先は原則 `docs/instructions/YYYY-MM-DD/` とする。
3. 同じ指示書の改訂は新規版として履歴を残すか、Git履歴で差分追跡できる形で更新する。
4. 指示書を保存せずコードだけcommitする運用を避ける。
5. 実装完了報告には、関連指示書path・branch・commitを含める。
6. 指示書と実コードが食い違う場合は、最新GitHub正本・実コード・Git状態を確認して差分を記録する。
7. 未commit作業は保護し、既存作業を壊さない。

## 過去分の回収

過去のチャット、ローカルMarkdown/DOCX/TXT、既存branch、commit、PR、README、MASTER、AGENTS、作業メモから指示書を探索する。

全文を確認できる場合:
- 原文を保存する。
- 日付、対象、出典commit/branchが分かればfront matterまたは冒頭に付記する。

全文を確認できない場合:
- 内容を創作しない。
- `docs/instructions/HISTORY-RECOVERED-INDEX.md` に確認できたタイトル、対象、日付、成果物、branch、commitのみ記録する。
- 原文が回収できた時点で個別Markdownへ昇格する。

## Codex施工時の追加ルール

Codexは各タスク開始時に以下を確認する。

- 対象Repository
- main
- 最新commit
- current branch
- working tree / diff
- MASTER.md
- AGENTS.md
- README
- `docs/instructions/`
- 実コード

チャットの文脈が不足してもユーザー確認で止まらず、GitHubから現在地を再構築する。

## 完了条件

- 今後の指示書保存ルールがRepository内に存在する。
- 過去分の回収索引が存在する。
- 新規指示書の保存pathが統一される。
- 実装完了報告から指示書へ辿れる。
- 指示書から関連commit/branchへ辿れる。
