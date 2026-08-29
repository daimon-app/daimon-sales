# AI5 HUB 日本語司令盤・承認・アカウント確認 QA Evidence

- Branch: `feat/ai5-hub-ja-owner-command-center`
- Base: Stable HUB v56 commit `4e0401e534f74be339d40f20ea23b880faed9126`
- Stable Runtime activation: 未実施
- main / Production / DAIMON: 変更なし

## 実装確認

- 5AIカード: 日本語名、実状態、現在作業、Project、開始、最新結果、次作業、停止理由、鮮度。
- 不明・未接続・古い状態を正常または作業中として偽装しない。
- 利益データ未照合時は数値を作らず「未確認」。
- LEVEL 0: 自動承認、無音、Evidence保存、Task継続。
- LEVEL 1: AI5 HUB承認、単回Token、Receipt、Task自動再開。
- LEVEL 2: 金銭・本人確認等の代理承認を拒否。
- Approval Scope: 完全一致だけ再利用。分類不能はLEVEL 1へFail Closed。
- Account Evidence: `VERIFIED_BY_AI5` / `WRONG_ACCOUNT` / `UNRESOLVED`。不明は当該媒体だけ保留し、Owner Gateにしない。

## テスト

- AI5 HUB全既存テスト: PASS
- Approval Policy追加テスト: PASS
- LEVEL 1 API承認 → Receipt → 自動再開: PASS
- LEVEL 2 API代理承認拒否: PASS
- Push/VAPID、通知重複防止: PASS
- Approval通知時刻・Batch: PASS
- Autonomous Loop: PASS
- Single Writer / Project Control / Result Bus: PASS
- JavaScript構文: PASS
- `git diff --check`: PASS

## Mobile QA

- Candidate RuntimeをMock mode・隔離Data Root・port 43129で一時起動。
- Chrome viewport: 412 x 915。
- 5AIカード表示: 5/5。
- 日本語状態、未接続、最終更新、本人確認、利益未確認: 表示PASS。
- `innerWidth=412`, `documentElement.scrollWidth=412`, `body.scrollWidth=412`。
- AI5 HUB由来JavaScript error: 0。
- 候補RuntimeはQA後に停止。Stable Runtimeには影響なし。

## 未実施

- Stable Runtime controlled activation。
- Pixel実端末でのPush通知音・Service Worker更新・実承認タップ。
- 実決済データを使う利益表示。
- 実SNSアカウントでの投稿（外部公開のため本branch QA対象外）。
