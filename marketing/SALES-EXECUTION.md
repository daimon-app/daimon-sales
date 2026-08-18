# DAIMON SALES — EXECUTION PLAYBOOK

> Codex / AI5施工用の実行正本。
> 販売・SNS・CM・LP・Google Play準備を行うときは、ルート `MASTER.md` と `marketing/MASTER-MARKETING.md` を先に読み、本ファイルに従って施工する。

## 0. 開始命令

この指示を受領したら、まずGitHub正本を自動確認する。

確認対象:
- main
- 最新commit
- branch
- diff
- `MASTER.md`
- `marketing/MASTER-MARKETING.md`
- README / AGENTS が存在する場合はそれら
- 現行実コード
- 既存販売資産
- 既存SNS
- 既存メール
- Google Play状況

未commit作業がある場合は保護する。
マーケティング施工はアプリ本体と競合しない別branch / worktree / `marketing/` 配下へ分離する。
本人承認不要の工程は質問で止まらず連続施工する。

## 1. 最優先ルール

1. GitHub正本を基準に現在地を再構築する。
2. アプリ本体を壊さない。
3. DAIMON販売版の朝モード完成を妨げない。
4. 無料でできる工程は無料で進める。
5. 有料広告、有料SaaS、有料認証、有料素材、有料AIサービスを本人承認なしで使わない。
6. 本人認証・OAuth・2FA・CAPTCHA・課金・購入・契約・公開確定だけ停止する。
7. それ以外は自動施工を継続する。
8. 途中経過だけで完了扱いにしない。
9. 完了証拠（ファイル、URL、スクリーンショット、検査結果）を残す。

## 2. 販売対象

### DAIMON販売版
- 朝
- 仕事
- 夜
- 朝を完成・固定後、仕事・夜へ横展開する。

### DAIMON 切り替えスイッチ
- 別アプリ。
- 同時販売候補。
- 現時点では販売導線の受け口のみ先行準備。

## 3. 販売導線

SNS認知 → LP理解 → 実画面/思想で信頼 → Google Play購入 → 継続利用 → シリーズ相互送客。

## 4. 無料SNS施工対象

### 最優先
- TikTok
- Instagram
- YouTube Shorts

### 次点
- Threads
- X
- Facebook Page
- Pinterest Business

### 条件確認後
- LinkedIn
- Reddit / Reddit Pro

### 共通施工物
- ブランド名: DAIMON
- ハンドル候補
- プロフィール画像
- ヘッダー/カバー
- 80字プロフィール
- 150字プロフィール
- 300字プロフィール
- 販売LPリンク
- 固定投稿
- 初期投稿セット

本人認証が必要な場面だけ、
`サービス名 / 今いる画面 / 本人がする1操作 / 完了後に自動再開する工程`
を短く報告して停止する。

## 5. CM制作

### CM-A
- 6〜8秒
- スクロール停止
- コピー候補: 「ズレたら、戻ればいい。」

### CM-B
- 15秒
- 問題提起3秒 → DAIMON体験8秒 → CTA4秒

### CM-C
- 30秒
- 朝/仕事/夜 → 3構成メッセージ → ブランド思想 → CTA

### CM-D
- 15秒
- 切り替えスイッチ予告

### CM-E
- 20〜30秒
- ブランド思想
- コピー候補: 「続けるためではなく、戻るため。」

### 共通仕様
- 9:16 / 1080×1920をマスター
- 必要に応じて1:1 / 4:5 / 16:9
- 字幕必須
- 無音でも意味が通る
- 冒頭1〜2秒で問題提起
- 実画面を主役にする
- BGMなし版必須
- 音源は商用利用可能なものだけ
- 最後にDAIMONとCTA
- 動画生成AIが無くてもFFmpeg、実画面キャプチャ、画像、字幕、ズーム、フェード等で制作する
- 台本だけで完了にしない。制作環境で可能なら実動画ファイルまで出力する

## 6. 初期投稿30本

- 問題提起: 6
- 使い方: 6
- 思想: 6
- 画面デモ: 6
- 開発ストーリー: 3
- 商品導線: 3

### 再利用ルール
- 縦動画 → TikTok / Reels / Shorts / Facebook Reels
- 冒頭コピー → Threads / X
- 動画フレーム → Instagramカルーセル / Pinterest Pin
- 30秒台本 → YouTube説明 / LP FAQ / 長文投稿

媒体ごとにゼロから作り直さない。

## 7. LP施工

無料ホスティング優先。GitHub Pagesが利用できる場合は優先候補。

必須構成:
1. ファーストビュー
2. 問題: 人はズレる
3. 答え: 戻ればいい
4. 朝・仕事・夜の説明
5. 実画面GIF / 動画 / スクリーンショット
6. ①メイン / ②補助 / ③一声
7. DAIMON思想
8. CTA
9. FAQ
10. プライバシーポリシー
11. 利用規約
12. 特商法表示
13. 問い合わせ
14. SNSリンク
15. 切り替えスイッチ導線

公開前CTAは「近日公開」。公開後にGoogle Play購入へ切替可能にする。

## 8. Google Play準備

準備対象:
- 商品名
- 短い説明
- 長い説明
- アイコン
- フィーチャーグラフィック
- スクリーンショット
- プライバシーポリシー
- データセーフティ
- 価格
- サポート
- 審査回答テンプレート
- 実機QA

Play Console登録、課金、契約、公開確定は本人承認工程として分離する。

## 9. 計測

各SNSからLPへのリンクは識別可能にする。

最低記録:
- 投稿日
- 媒体
- テーマ
- 再生数
- 表示数
- プロフィール遷移
- LP流入
- Google Play遷移
- 購入

主KPI:
- LP流入
- Google Play遷移
- 購入

週次では「伸びた上位3本」「反応なし3本」だけ比較する。

## 10. Repository構成

```text
marketing/
  MASTER-MARKETING.md
  SALES-EXECUTION.md
  brand/
    logo/
    icons/
    banners/
    profile-copy/
  lp/
  cm/
    scripts/
    masters/
    exports/
    subtitles/
    thumbnails/
  social/
    tiktok/
    instagram/
    youtube/
    threads/
    x/
    facebook/
    pinterest/
    linkedin/
    reddit/
  play-store/
    listing-copy/
    screenshots/
    feature-graphic/
    policy/
  analytics/
    content-ledger.csv
    utm-rules.md
  launch/
    checklist.md
    launch-day.md
    post-launch.md
```

## 11. AI5兄弟ルーティング

- Zero: 総司令塔・目的・ブランド思想・最終判断
- Codex: PC施工司令塔・GitHub・実装・成果統合・自動ルーティング
- Gemini: 市場調査・競合調査・SNS調査・販売キーワード・検索需要
- Claude: CM台本・販売コピー・LPレビュー・高精度監査
- Manus: Web実務・SNSアカウント作成補助・LP/販売ページ確認・ブラウザ作業

必要に応じてCodexが自動振り分けする。

## 12. 施工Phase

### Phase 0 — 正本監査
GitHub、main、最新commit、branch、diff、MASTER、現行コード、既存販売資産、SNS、メール、Google Play状況を確認。

### Phase 1 — ブランド基盤
ロゴ、プロフィール、バナー、ハンドル候補、説明文。

### Phase 2 — LP
無料LP、近日公開CTA、規約、プライバシー、問い合わせ。

### Phase 3 — SNS
無料アカウント、プロフィール、初期設定。本人認証のみ待機。

### Phase 4 — CM
6〜8秒、15秒、30秒、切り替えスイッチ予告、ブランド思想。

### Phase 5 — 投稿在庫
初期30本。

### Phase 6 — Google Play
商品ページ、説明、画像、審査準備。

### Phase 7 — 発売前QA
全リンク、スマホ表示、LP、SNS、Play導線、動画、スクリーンショット。

### Phase 8 — 発売
固定投稿、SNS告知、LP CTA切替。

### Phase 9 — 発売後
無料運用データ回収、勝ち投稿再利用、弱い投稿停止。

## 13. 現在の開発優先順位

1. 朝
2. 朝固定
3. 仕事
4. 仕事固定
5. 夜
6. 夜固定
7. 全体QA

イヤホン仕様は保留。
新機能を足さない。

マーケティング施工は別作業領域で並行してよいが、アプリ本体の朝施工を妨げない。

## 14. 完了条件

販売基盤完成条件:
- 販売LP
- TikTok
- Instagram
- YouTube
- Threads
- X
- Facebook
- Pinterest
- 必要に応じLinkedIn
- 必要に応じReddit
- 共通ブランド素材
- プロフィール文
- CM最低3種
- 初期投稿30本
- 固定投稿
- Google Play販売素材
- プライバシーポリシー
- 利用規約
- 特商法表示
- 問い合わせ
- UTM / 計測設計
- 発売日チェックリスト
- 発売後運用テンプレート

無料でできる工程は全て完成させる。
本人認証・有料登録・公開確定のみ本人承認待ちとして一覧化する。

## 15. 最終報告フォーマット

必ず以下をまとめる:
- GitHub branch
- commit
- 変更ファイル
- 完成物
- 公開URL
- 作成SNS
- 作成CM
- 作成投稿数
- 残本人承認
- 残課金事項
- 残問題
