# DAIMON MORNING Edition 販売基盤

正本は `MASTER-MARKETING.md`、実行ルールは `SALES-EXECUTION.md`。本READMEは起動と検査の入口だけを提供する。

Manus初回独立監査はNO-GO。公開・販売は `release-gates.md` の全項目が実証されるまで行わない。LPの公開状態とGoogle Play URLは `lp/release-config.js` だけで切り替える。

## LPプレビュー

Repositoryルートの `preview-marketing.cmd` をダブルクリックする。`http://127.0.0.1:4173/` を既定ブラウザで開き、ウィンドウを閉じるかCtrl+Cで停止する。Loopback限定で外部公開しない。

## CM-A

`cm/README.md` に従って初回だけFFmpegをRepositoryローカルへ取得し、`cm/build/build-cm-a.ps1` で再生成する。

## 自動検査

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File marketing/test-marketing.ps1`

正規LP URL確定後のUTM実リンク生成:

`powershell.exe -NoProfile -File marketing/analytics/generate-links.ps1 -BaseUrl https://確定LP.example`

## 公開前残作業

- 正式な事業者・問い合わせ情報と法務ページ最終確認
- 確定実機スクリーンショット
- Play Consoleの価格・国・Data safety・IARC入力
- SNS本人認証とハンドル確定
- LP公開、審査提出、販売開始の本人承認
