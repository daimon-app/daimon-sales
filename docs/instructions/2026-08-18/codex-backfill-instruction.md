# CODEX — 過去指示書GitHub回収施工指示

発行日: 2026-08-18
対象: Codex / DAIMON関連ローカルRepository

## 目的

過去にZeroやユーザーからCodexへ渡された実装施工仕様指示書・設計施工実装指示書・修正仕様指示書・施工仕様書・実行指示書・監査指示書等を、可能な範囲でGitHubへ回収する。

## 開始時

各対象Repositoryで以下を確認する。

- `git status -sb`
- `git branch --show-current`
- `git log --oneline --decorate -n 30`
- `git remote -v`
- `MASTER.md`
- `AGENTS.md`
- `README*`
- `docs/`
- `marketing/`
- 未追跡ファイル

未commit作業がある場合は絶対に消さない。stash/reset/checkout/clean等を勝手に行わない。

## 探索対象

ローカルで以下を読み取り専用検索する。

- `*.md`
- `*.txt`
- `*.docx`
- `*.json`
- `*.log`
- `*SPEC*`
- `*INSTRUCTION*`
- `*施工*`
- `*仕様*`
- `*指示*`
- `*設計*`
- `*修正*`
- `*EXECUTION*`
- `*PLAYBOOK*`

Git履歴では、過去branch・commit・削除済みファイルも確認する。

## 保存方針

全文が確認できる指示書:
- 原文を改変せずMarkdown化または原ファイルのまま保存する。
- 保存先は `docs/instructions/YYYY-MM-DD/`。
- 元ファイル、元commit、元branchが分かれば冒頭に記録する。

全文が確認できない指示:
- 創作して補完しない。
- `docs/instructions/HISTORY-RECOVERED-INDEX.md` に事実だけ追記する。

## Repository跨ぎ

指示書は原則、その施工対象Repositoryに保存する。

複数Repositoryを跨ぐAI5共通運用指示は、まず `daimon-sales/docs/instructions/` に中央索引を置き、各対象Repositoryにも必要な正本または参照を置く。

## Git運用

- mainへ直接大量投入しない。
- 未commit作業があるRepositoryでは既存作業を保護する。
- 指示書回収専用branchを使用する。
- 既存機能コードは変更しない。
- 回収作業だけを独立commitする。
- 通常pushまでは実行してよい。
- mergeは本人承認対象。

## 完了報告

最低限以下を報告する。

1. 調査したRepository一覧
2. 回収した原文指示書数
3. 索引化のみの指示数
4. 保存path一覧
5. branch
6. commit
7. push結果
8. 未回収の候補
9. 未commit作業を壊していない証拠

## 完了条件

「今後分を保存する仕組み」と「過去分の回収結果」がGitHub上で追跡可能になっていること。
