# Phase 3 execution record

GitHubの現在実装と最新の明示的決定を技術正本とする。NotebookLMは資料検索と過去判断の根拠抽出だけに使い、コード状態を断定しない。

## NotebookLM connection decision (2026-08-18)

- 個人向けNotebookLMに一般提供された公式自動化APIは確認できなかった。
- 公式APIはGemini Notebook Enterprise Previewで、Cloud設定と専用ライセンスが必要なため追加料金0円のPhase 3では採用しない。
- 既存Googleログイン済みChromeから接続できることを確認した。Cookie、token、保存認証情報は取得しない。
- Adapterはread-only固定、出典必須、GitHub照合必須とする。
- NotebookLM内にAI5 HUBノートブックは未作成。作成と資料追加はGoogle側への書込みのため、本人承認後に行う。

公式資料:

- https://support.google.com/notebooklm/answer/16164461
- https://support.google.com/notebooklm/answer/16337734
- https://docs.cloud.google.com/gemini/enterprise/notebooklm-enterprise/docs/api-notebooks

## Implemented

- Zero事前承認判定とHUB表示
- 既存one-time approval tokenによるHUB内承認
- NotebookLM read-only I/Fと出典検証
- 過去資料系のZero Router判定
- NotebookLM後のGitHub正本照合child task
- Field Mode task属性（既定ON）

## Not yet verified

- AI5専用NotebookLM知識庫の出典付き実問答
- NotebookLMからHUBへの実結果返却
- Phase 3 Android/iPhone統合E2E

未確認項目はSUCCESS扱いしない。
