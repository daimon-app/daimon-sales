# AI5販売直前クロスチェック（2026-08-18）

## Manus Web実査

- 対象: public HEAD `83c06a10ec740f245cfab1a73234e5ef170d30aa`
- 実行前/後表示: `今回は Manus が負担します—クレジットは消費されません`
- 結論: signed AAB、実機、法務/support、Console、公開URL/E2Eが未確定のためNO-GO。
- `@daimonapp`はTikTok/Xで既存利用を確認し不採用。`@daimon_app`は公開不在を観測した媒体があるが、取得可能とは断定しない。
- 新規個人Playアカウントのclosed testing要件はConsoleのアカウント状態で最終確認する。

## Gemini Google公式要件クロスチェック

- targetSdk 36は2026-08-31以降の新規提出・更新要件に適合する設計値。
- 2023-11-13以降に作成された新規個人デベロッパーアカウントでは、production access前に12名以上・14日間連続opt-inのclosed testingが適用され得る。実適用はConsoleで確認する。
- 新規アプリはAABとPlay App Signingを使用する。
- 実AABに広告が無いためAdsはNo案、認証制限が無いためApp accessは全機能利用可能案。最終AAB/Consoleで確定する。
- Data safetyは端末外収集・共有No案。ただしsigned AABの依存関係・通信・Console解析との一致確認を受入条件とする。
- 日本のみ・JPY 490・Paidを初期案とし、支払いプロファイル、税、地域価格は本人/Consoleゲート。

公式確認先:

- https://developer.android.com/google/play/requirements/target-sdk
- https://support.google.com/googleplay/android-developer/answer/14151465
- https://support.google.com/googleplay/android-developer/answer/9842756
- https://support.google.com/googleplay/android-developer/answer/10787469
- https://support.google.com/googleplay/android-developer/answer/9859455
- https://support.google.com/googleplay/android-developer/answer/113468

## 監査分類

- 技術未解決: signed AAB artifact監査、実機QA、最終実機screens/CM差替え、外部E2E。
- 本人承認待ち: Console本人認証、Paid/Japan/JPY 490、Data safety/IARC/target audience最終回答、公開・提出・投稿。
- 外部条件待ち: アカウントに適用されるclosed testing/production access。
- 法務情報待ち: 販売者、責任者、住所、電話、support、返品・返金条件。
- FIXED: Morning-only source、API 36、権限/通信/広告/解析/課金SDKなし、LP prelaunch CTA、UTM、公開候補CM-C 21秒SSOT。

