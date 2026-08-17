# AI5 HUB Mobile setup

## 採用方式

Tailscale Serveを使用します。AI5 HUBはpublic internetへ公開せず、本人のtailnetに認証されたWindows PCとスマホだけがアクセスできます。Tailscaleがprivate network、device identity、ACL、MagicDNS、HTTPS証明書を提供します。

公開経路は `Smartphone → Tailscale private HTTPS → Tailscale Serve → http://127.0.0.1:43125` です。43125のlisten先はlocalhostのままです。

## 現在必要な本人操作

このPCはWindows Installerの再起動待ち状態です。既存作業を守るためCodexは自動再起動していません。

1. 進行中作業を保存してWindowsを再起動する。
2. Codexへ「Phase 2.5を再開」と伝える。
3. Codexが公式Tailscaleをインストールする。
4. 表示されたTailscaleログイン画面で本人アカウントを選ぶ。
5. iPhone/Androidへ公式Tailscaleアプリを入れ、同じアカウントでログインする。

OAuth、2FA、端末追加は本人操作が必要です。Cookie、認証token、セッション情報をCodexへ渡さないでください。

## PC通常起動

`launch-ai5-hub.cmd`をダブルクリックします。Tailscale設定後はAI5 HUBとprivate HTTPS Serveをまとめて起動します。

自動起動を設定する場合はTailscale疎通確認後にCodexが`install-autostart.ps1`を実行します。Task Schedulerへ現在ユーザーのログイン時タスクを1件だけ登録し、多重起動を検査します。

## スマホ通常起動

Tailscale接続中に、`tailscale serve status`で表示される`https://<PC名>.<tailnet>.ts.net/`を開きます。初回だけAI5 HUBの「ログイン」を押します。その後、ブラウザの「ホーム画面に追加」を選びます。

- iPhone: Safariの共有メニュー → ホーム画面に追加
- Android: Chromeメニュー → アプリをインストール、またはホーム画面に追加

## 公開しないもの

Bridge、queue、results、logs、runtime、secret、config、PowerShell、filesystem、任意shell endpointは公開しません。利用可能APIはhealth、session、logout、tasks、result、approve、reject/cancelだけです。
