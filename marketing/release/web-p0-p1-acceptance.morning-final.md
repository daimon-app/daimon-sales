# DAIMON MORNING Edition — Web側 P0/P1 受入条件

**目的:** 前回のP0/P1を、Web販売施工で「閉じられる範囲」と「Codex／所有者の実体が必要な範囲」に分けます。この文書の`PASS`はWeb成果物の受入を意味し、公開・課金・審査提出の許可ではありません。

## 判定ラベル

| Label | 意味 |
|---|---|
| `WEB-CLOSABLE` | このパッケージを統合し、静的・表示・リンク試験で閉じられる。 |
| `WEB-PARTIAL` | Web側は完成させられるが、AAB・Console・本人情報・実URLなど外部実体がなければ全件閉鎖できない。 |
| `NOT-WEB-CLOSABLE` | Webだけでは閉じられない。Codex又は所有者の明示入力・証跡が必要。 |

## P0

| ID | Web側の施工範囲 | Label | 客観受入条件 | 必須input / owner |
|---|---|---|---|---|
| P0-01 Android販売物がない | LP/Listing/E2EのAAB参照位置を変数化し、実機素材の受入枠を用意する。 | NOT-WEB-CLOSABLE | なし。Web側でAABを作ることはできない。 | Codex: signed AAB、applicationId、version、target SDK、権限、SDK、QA証跡。 |
| P0-02 公開Repoに販売本体が露出 | LP・CM・SNSが`{{FINAL_AAB_BUILD}}`の成果物のみを参照する仕様にし、公開Repoに販売本体を置かない受入条件を明示する。 | WEB-PARTIAL | HTML/CM/SNSに旧PWA URL・WORK/NIGHT・公開Repo本体への導線がない。`public-repo-boundary`の人間レビュー記録がある。 | Codex/owner: 実装・画像・AABの非公開配布境界。 |
| P0-03 法務・サポート未完成 | LPに法務4リンクとsupport導線を実装し、変数化する。 | WEB-PARTIAL | 4リンクがHTTPSの最終ページへ到達し、販売者・問い合わせ・返品/キャンセル・データ方針がplaceholderなしで表示される。 | Owner/legal: 正式本文、販売者情報、support URL/SLA。 |
| P0-04 Play提出・必須宣言未完了 | Listing完成原稿、Console質問票、AAB input sheet、pre-submit checklistを用意する。 | WEB-PARTIAL | Copy、icon、feature、screenshots、privacy/support URLの準備記録があり、Console回答がAAB evidenceと逐一対応する。 | Codex/owner: Console、Data safety、IARC、country/price、test/review。 |
| P0-05 商品境界不一致 | LP、SNS、CM-B/CをMorning専用の本文で固定する。 | WEB-PARTIAL | Web出力に`WORK`、`NIGHT`、3モード、別商品が0件。商品名は一貫して`DAIMON MORNING Edition`。 | Codex: 起動直後からMorning専用のAAB。Owner: SSOT更新。 |

## P1

| ID | Web側の施工範囲 | Label | 客観受入条件 | 必須input / owner |
|---|---|---|---|---|
| P1-01 LP CTA | `release-config.template.js` / `release.js`を提供。prelaunch/liveを一箇所で切替。 | WEB-CLOSABLE | prelaunch時: 全`data-release-link`が`#release`、Play URL空、`aria-disabled=true`。live時: valid Play URLのみを許可し、LP/CTAコピーが切替。 | Owner: 承認済みPlay URLをlive時だけ入力。 |
| P1-02 実画面の販売証拠 | LP4枚スロット、Play asset仕様、CMの実機画面条件を提供。 | WEB-PARTIAL | 4枚の実機画像がMorning専用最終AABから取得され、ホーム/呼吸/12枚/終了を示す。alt/キャプション/Play screenshotsと一致。 | Codex: final AABとscreenshots。 |
| P1-03 feature graphic | 既存PNGを利用可能。Listing規則を明記。 | WEB-CLOSABLE | 1024×500、価格・割引・ランキングなし、権利確認、重要要素中心寄せ、実機能と非誤認。 | Owner: asset rights sign-off。 |
| P1-04 CM理解不足 | CM-B/C秒単位絵コンテ、字幕、safe area、CTA仕様を提供。 | WEB-PARTIAL | 実MP4が台本に一致し、実機AAB画面のみを使用。無音・safe area・Morning-only検証にPASS。 | Codex/media: 最終AAB画面と実MP4。 |
| P1-05 SNS範囲逸脱/リンク不足 | 30投稿、profile、固定投稿、UTM contentをMorning-onlyで提供。 | WEB-PARTIAL | 原稿・caption・映像にWORK/NIGHT・未実装機能が0件。URL registryが全content IDを生成。 | Owner: 実handle/実LP URL、アカウント承認。 |
| P1-06 固定文言/音声/非医療説明 | Hero、FAQ、Listing、CMの範囲文を提供。 | WEB-PARTIAL | LP/Listingが朝・呼吸・固定12枚・約90秒・音声は最終AABに従う・非医療を一致表示。 | Codex: 12枚、音声、実測秒数。Owner: copy lock。 |
| P1-07 素材権利 | 利用素材に`verified`を必須とする受入を定義。 | NOT-WEB-CLOSABLE | なし。台帳があるだけでは不可。 | Owner: 原契約、作成者、利用範囲、証憑。 |
| P1-08 E2E/計測 | URL registry、UTM taxonomy、staging checklist、evidence logを提供。 | WEB-PARTIAL | `profile/pinned/p01-p30/cm-a/cm-b/cm-c`の実URLを生成し、E2E-01〜12が証跡付きPASS。 | Owner/Codex: staging URL、Play mock/test、support、AAB。 |
| P1-09 購入後説明/支援 | LP support sectionとE2Eのアプリ内導線検査を提供。 | WEB-PARTIAL | LPとアプリ内双方からprivacy/terms/support/削除方法へ到達でき、最終窓口に接続。 | Codex: アプリ内リンク、削除機能。Owner: support実体。 |
| P1-10 自動QA不足 | 静的検査に追加すべき項目を仕様化する。 | WEB-PARTIAL | release QAがplaceholder、CTA、4画面、4法務リンク、UTM全ID、Morning-only語句、CM、E2E evidence、AAB inputを検査する。 | Codex: CI/PowerShell実装。Owner: 手動gate承認。 |

## Web統合後の静的検査仕様

| Test ID | 検査 | PASS条件 |
|---|---|---|
| WEB-01 | LP Hero text | `朝`、`呼吸`、`固定12枚`、`約90秒`、`Android`、`490円`、`買い切り`、`広告なし`がHero内に存在。 |
| WEB-02 | Morning-only vocabulary | LP、Listing、SNS、CM-B/Cから`WORK`、`NIGHT`、`切り替えスイッチ`、`3モード`を検出しない。 |
| WEB-03 | Release config | defaultが`prelaunch`、Play URLが空、live用URLは正規表現・approval recordを要する。 |
| WEB-04 | Screenshots | `morning-01-home.png`〜`morning-04-return.png`が存在し、各画像のmanifestにAAB build IDがある。 |
| WEB-05 | Legal / support | 4リンクがある。最終公開前には各URLが200/有効HTMLで、placeholder tokenが0件。 |
| WEB-06 | UTM | 5媒体×`profile/pinned/p01-p30/cm-a/cm-b/cm-c`の必要URLを生成可能。utm_source / medium / campaign / contentが規約通り。 |
| WEB-07 | Video spec | CM-B/CのMP4が9:16、1080×1920、30fpsで、Morning-only実機画面のみ。 |
| WEB-08 | Copy consistency | LP、Listing、SNS、CMの商品名・朝の流れ・価格/広告条件・非医療表現が一致。 |

## 公開禁止条件

次のどれか一つでも当てはまる場合、Webファイルが完成していても`state: "live"`に変更してはいけません。

| Blocker | 理由 |
|---|---|
| AAB / applicationId / SDK / data map未受領 | Listing、Data safety、App access、screenshotsを正確に確定できない。 |
| 商品境界未確定または実アプリにWORK/NIGHTが残る | Morning専用の販売説明が誤認になる。 |
| 法務4ページ・supportがドラフト又はplaceholder | 購入後の説明責任を満たさない。 |
| 素材が`block-release` | 商用利用権を証明できない。 |
| ConsoleのData safety/IARC/ads/target audience/countries/priceが未回答 | Play提出準備が未完了。 |
| E2E evidenceにFAIL/BLOCKEDが残る | SNSから購入後supportまでの導線が証明されない。 |
