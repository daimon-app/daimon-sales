# DAIMON MORNING Edition — Google Play Listing 最終案

**用途:** `feat/marketing-foundation` の既存 `marketing/play-store/listing-copy/ja.md` を置換する原稿です。本文はMorning専用の最終AABと実機スクリーンショットが確定した場合にのみ使用します。AAB、SDK、権限、アカウント、Console設定が未受領の箇所は、意図的に **Codex input required** としています。

> Google Playのタイトルは30文字以内、短い説明は80文字（全角40文字）以内、詳しい説明は4,000文字（全角2,000文字）以内です。掲載情報は実機能を正確に表し、画像・テキストで価格や期間限定等の販促を示してはいけません。[1]

## 1. Product details

| Console field | Final copy | Status / acceptance condition |
|---|---|---|
| App name | `DAIMON MORNING Edition` | 30文字以内。Morning専用AABの初回画面・アプリ内表記と完全一致すること。 |
| Short description | `朝、呼吸と固定12枚で今日の方向を見直す約90秒のアプリ。` | 40全角文字以内の目安。最終AABの実機計測が約90秒と一致すること。 |
| App or game | App | アプリの主目的に合うカテゴリをConsoleで最終選択すること。**Codex input required:** 最終AABの機能範囲。 |
| Category | `Lifestyle` を第一候補 | 断定ではない。最終AABの主目的・Consoleの候補と照合して所有者が選択すること。 |
| Contact email | `{{SUPPORT_EMAIL}}` | 実在し、購入前後の問い合わせに応答できる窓口。所有者入力必須。 |
| Privacy policy URL | `{{PRIVACY_POLICY_URL}}` | 有効なHTTPS公開URLで、提出AAB・SDK・データ保存/送信と一致する最終文書。 |

## 2. Full description

```text
人はズレる。止まる。忘れる。
それでも、また戻ればいい。

DAIMON MORNING Editionは、朝に自分の意図と今日の方向を見直すためのAndroidアプリです。

通知を開く前に、呼吸から始めます。次に、固定された12枚の言葉と画面を順に見ます。最後の短い一声から、今日の現実へ戻ります。毎朝選ばない、一つの短い流れです。

このアプリで行うこと
・朝の呼吸導入から始める
・固定12枚の言葉と画面を順に見る
・最後の一声から、今日の行動へ戻る

このアプリが目的にしないこと
・ToDoを管理すること
・長時間の瞑想をすること
・連続記録で行動を評価すること

朝の固定フローは約90秒を想定しています。販売開始前に、最終AABの実機計測とストア掲載情報を一致させます。

DAIMON MORNING Editionは、診断、治療、医療行為、または特定の結果の保証を目的とするものではありません。
```

**Copy lock:** ストア掲載情報では、価格、割引、期間限定、ランキング、匿名の推薦、競合比較を追加しません。`広告なし`はLPとConsoleの広告申告で扱い、短い説明・詳しい説明には加えません。実装にない音声、通知、オフライン、カスタマイズ、WORK/NIGHT機能も加えません。[1]

## 3. Store asset handoff

| Asset | Required content | Source / owner | Gate |
|---|---|---|---|
| App icon | 512×512 PNG、DAIMONの正規アイコン | `play-store/icon/icon-512.png` | 権利・最終ブランド承認 |
| Feature graphic | 1024×500、価格/割引/ランキングを含めない。重要要素を中央寄せ。 | `feature-graphic/feature-graphic.png` | 最終AABの実機能と誤認なく整合 |
| Phone screenshots 1–4 | ①Morning専用ホーム ②呼吸導入 ③固定12枚の代表画面 ④最後の一声/戻る | `{{FINAL_AAB_BUILD}}` の実機 | **Codex input required:** 最終AAB、端末、画像、画面遷移。モック/AI生成画面は禁止。 |
| Optional trailer | CM-CをYouTube等で公開済みの場合のみ | 完成済みCM-C | 公開前にはURLを入力しない。 |

## 4. Console回答マッピング

この表は「何を確認してどのように回答するか」の質問票です。`暫定回答`をConsoleへ転記してはいけません。最終回答は、署名済みAAB、AndroidManifest、Gradle依存、第三者SDK、ネットワーク通信、サーバー、最終プライバシーポリシーの突合後にのみ入力します。すべての公開トラックでData safetyフォームとプライバシーポリシーが必要です。データを収集しない場合でもフォームとポリシーURLが必要です。[2]

| Console section / question | 収集する客観証拠 | 最終回答のルール | 現在の扱い |
|---|---|---|---|
| **Ads**: アプリに広告は含まれるか | 最終AAB、広告SDK一覧、WebView/remote config、画面録画 | 広告SDK・広告表示がなければ`No`。一つでも含むなら`Yes`。LPの文言では決めない。 | **Codex input required** |
| **App access**: 機能の一部/全部が制限されているか | 起動からMorning完走までの実機録画、ログイン/課金/招待/地域/権限依存の一覧 | 制限がなければ`All functionality is available without special access`。制限があれば審査員用の正確な手順・認証情報をConsoleに入力する。 | **Codex input required** |
| **Target audience** | 最終コンテンツ、アイコン、スクリーンショット、販売方針 | 子ども向けの画像・文言を使わない。対象年齢層は所有者が実際の対象に従って選択する。 | Owner decision required |
| **Content rating (IARC)** | 最終AAB、全画面、説明、広告有無、ユーザー生成コンテンツ有無 | 質問を一問ずつ実態に沿って回答する。`medical`を避けるために虚偽回答しない。 | **Codex input required** + owner Console input |
| **Data safety: data collected or shared?** | AndroidManifest、permissions、SDK/ライブラリSBOM、通信先、サーバー、ログ、クラッシュ報告、課金、保存データ | SDKを含め全データフローを申告。収集/共有がなければ`No`を選び、ポリシーURLを入力する。 | **Codex input required** |
| **Data safety: encryption / deletion** | 通信仕様、保存仕様、アカウント有無、削除UI/サポート手順、privacy policy | HTTPS等の実態に基づき回答。削除手段があると回答するなら、ユーザーが実際に使える導線を用意する。 | **Codex input required** + support owner input |
| **Privacy policy** | 公開HTTPS URL、AABデータフロー、削除・問い合わせ・改定日 | 実態と一致し、一般閲覧可能な最終文書を指定する。ドラフト／placeholderは禁止。 | Owner/legal input required |
| **Countries / regions** | 販売方針、サポート可能地域、価格表、法務文書 | `Japan`を第一候補とするが、国選択は所有者の最終判断。未サポート国を有効化しない。 | Owner decision required |
| **Price** | Consoleの国別価格、販売方針 | 日本を販売国にする場合は490円を設定する。価格はListing本文・画像には書かない。 | Owner Console input required |
| **Testing / production access** | アカウント種別、closed test人数/期間、テスター記録、フィードバック、AAB | 2023-11-13以降作成の個人アカウントなら、12人以上が14日連続でopt-inしたclosed test後にproduction accessを申請する。[3] | Owner Console input required |
| **Review / release** | Pre-launch report、Console errors=0、Data safety/IARC、screenshots、法務、support、AAB | 管理対象公開を推奨。P0/P1 gateが全件閉鎖されるまで審査提出/公開しない。 | Human approval required |

## 5. Codex input required sheet

| Key | Codex must return | Used by |
|---|---|---|
| `ANDROID_APPLICATION_ID` | 最終package/applicationId | Play URL、App access、Console |
| `AAB_VERSION_CODE` / `AAB_VERSION_NAME` | 最終versionCode/versionName | release checklist |
| `TARGET_SDK` / `MIN_SDK` | 最終SDK値 | Console / technical QA |
| `PERMISSIONS` | AndroidManifestの全permission | Data safety / app access |
| `SDK_INVENTORY` | 直接・推移依存を含む全SDKと用途 | Data safety / ads |
| `NETWORK_DESTINATIONS` | 通信先、用途、送信データ、暗号化 | Data safety / privacy |
| `LOCAL_DATA_MAP` | 端末保存データ、削除方法、保持期間 | privacy / support |
| `AUTH_OR_PAYWALL` | ログイン・課金・招待・地域制限の有無 | app access |
| `MORNING_FLOW_MEASURED_SECONDS` | 最終AABの実測値 | LP / Listingの`約90秒`確認 |
| `FINAL_SCREENSHOTS` | 4〜8枚の実機キャプチャと端末情報 | LP / Play assets |

## 6. Pre-submit checklist

| Gate | Acceptance condition | Owner |
|---|---|---|
| Listing consistency | app name、short/full、screenshots、CM、LPがMorning専用AABと一致 | Codex + web owner |
| Legal/support | privacy/terms/legal/contactが最終化され、有効URL・実窓口がある | Owner / legal reviewer |
| Data safety | SDK、権限、通信、保存をAABと突合し、フォーム・privacyと一致 | Codex + owner |
| Content / target | IARC、target audience、ads、app accessをConsoleで実態に即して回答 | Owner + Codex input |
| Assets | icon/feature/screenshotsの権利・解像度・実機能一致を確認 | Design/web owner |
| Test / review | アカウント種別の必要テスト、Pre-launch report、Console error 0、managed publishing設定を確認 | Owner |
| Approval | `release-gates.md`のP0/P1該当項目に証跡と人間承認がある | Owner |

## References

[1] [Google Play — ストアの掲載情報に関するおすすめの方法](https://support.google.com/googleplay/android-developer/answer/13393723?hl=ja)  
[2] [Google Play — データ セーフティ セクションの情報を提供する](https://support.google.com/googleplay/android-developer/answer/10787469?hl=ja)  
[3] [Google Play — 新しい個人用デベロッパー アカウント向けのアプリテスト要件](https://support.google.com/googleplay/android-developer/answer/14151465?hl=ja)  
[4] [Google Play — アプリを作成して設定する](https://support.google.com/googleplay/android-developer/answer/9859152?hl=ja)
