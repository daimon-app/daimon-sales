# Claude Code release audit（2026-08-18）

Read-only監査。Claude Code 2.1.233 / logged-in Pro。使用量・残量・resetは公式CLIから取得不能。

## FIXED

- signed artifactとsourceの`app.daimon.morning`、compile/target API 36が一致。
- packaged manifest permissions 0、runtime dependencyなし。
- upload鍵・password・AAB/APKは`.gitignore`対象。
- Morning 12枚本文にWORK/NIGHTや商品名挿入なし。
- TTS engine依存説明はアプリ、AAB監査、LPで一致。
- CM-C 21秒はREADME、master、詳細台本、release gateで一致。
- AAB/APK SHA-256はローカルartifactと監査台帳で一致。

## 技術未解決

- 現行Play画像とCM-B/Cは旧WebView staging UI由来で、signed native build由来ではない。実機接続後に全差替えが必要。
- 重複WebView staging sourceは正本混同を避けるため、削除せずignored quarantineへ隔離する。
- private Git履歴のsecret scanはCodex側で別途実施する。

## 本人・外部・法務ゲート

- signed APKの物理実機QA。
- 販売者情報、support、返品・返金条件。
- Play Console登録、Paid/Japan/JPY 490、Data safety/IARC/対象年齢、closed testing。
- LP公開、Play提出、SNS実投稿。

