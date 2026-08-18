# DAIMON MORNING Edition 販売基盤

正本は `MASTER-MARKETING.md`、実行ルールは `SALES-EXECUTION.md`。本READMEは起動と検査の入口だけを提供する。

## LPプレビュー

Repositoryルートの `preview-marketing.cmd` をダブルクリックする。`http://127.0.0.1:4173/` を既定ブラウザで開き、ウィンドウを閉じるかCtrl+Cで停止する。Loopback限定で外部公開しない。

## CM-A

`cm/README.md` に従って初回だけFFmpegをRepositoryローカルへ取得し、`cm/build/build-cm-a.ps1` で再生成する。

## 自動検査

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File marketing/test-marketing.ps1`

## 公開前残作業

- 正式な事業者・問い合わせ情報と法務ページ最終確認
- 確定実機スクリーンショット
- Play Consoleの価格・国・Data safety・IARC入力
- SNS本人認証とハンドル確定
- LP公開、審査提出、販売開始の本人承認
