# PREBUILD MARKET GATE

Status: CANONICAL — MUST RUN BEFORE BUILD
Effective: 2026-08-26 JST
Owner: Zero / AI5

## 1. Hard rule

新しいアプリ、商品、大規模機能、販売施策の本制作を開始する前に、AI5は必ずこのGateを実行する。

順序は固定：

`READ ALL CANONICAL/HISTORICAL EVIDENCE -> MARKET RESEARCH -> SALES PROBABILITY -> SALES RANGE FORECAST -> PROFIT FORECAST -> RISKS -> GO/CONDITIONAL/NO-GO -> BUILD`

過去の正本・調査・販売結果・失敗・顧客反応を読まずに、新しい調査や制作を開始しない。

## 2. Read-before-work requirement

作業開始時に、対象repo/projectで利用可能な以下を先に読む：
- `MASTER.md`
- `AI5_PROFIT_MISSION.md`
- `SALES_RELEASE_RUNBOOK.md`
- `APPROVAL_PERMISSION_MASTER.md`
- `PREBUILD_MARKET_GATE.md`
- behavioral-science Evidence/Library
- 過去の市場調査
- 過去の競合調査
- 過去の価格調査
- 過去の販売予測
- 実販売結果
- CM/SNS実測
- funnel metrics
- checkout/purchase/refund data
- customer feedback/support/objections
- 過去の GO / NO-GO / Decision Log
- 関連商品の失敗Evidence

同じ調査を理由なくゼロから繰り返さない。古い情報は古いと明記し、必要部分だけ最新化する。

## 3. Mandatory market research

最低限調査：
- target customer
- problem intensity/frequency/urgency
- willingness to pay
- current alternatives
- competitor pricing
- competitor reviews/complaints
- demand signals
- reachable audience/channels
- differentiation
- purchase objections
- product trust requirements
- expected support burden
- market/legal/platform constraints
- organic distribution potential
- paid distribution economics if relevant

## 4. Sales probability estimate

制作前に必ず `SELLABILITY PROBABILITY` を推定する。

単一の偽精密な数字だけを出さず、根拠と不確実性を併記する。

Required output:

```text
SELLABILITY PROBABILITY:
LOW = __%
BASE = __%
HIGH = __%
CONFIDENCE = LOW / MEDIUM / HIGH
```

この確率は「必ず売れる確率」ではなく、定義した期間・価格・流入条件で最低限の販売成功基準を達成する推定確率とする。

成功基準自体を明記すること。

## 5. Mandatory sales-volume forecast

制作前に「どれくらい売れそうか」を必ず予測する。

最低3シナリオ：

```text
FORECAST WINDOW = 7 / 30 / 90 days or product-appropriate periods
PRICE =

LOW:
traffic =
conversion =
orders =
revenue =
estimated variable cost =
estimated profit =

BASE:
traffic =
conversion =
orders =
revenue =
estimated variable cost =
estimated profit =

HIGH:
traffic =
conversion =
orders =
revenue =
estimated variable cost =
estimated profit =
```

流入量・CVR・価格・コストを分離する。売上だけを根拠なく置かない。

過去の自社実測がある場合は最優先で使用する。ない場合は市場Evidenceと明示した仮定から算出し、予測を実績として扱わない。

## 6. Comparable-data priority

予測Evidenceの優先順位：
1. 同一商品の実販売データ
2. 自社の類似商品の実販売データ
3. 自社のSNS/LP/checkout実測
4. 直接競合の観測可能データ
5. 高品質な市場/一次資料
6. コミュニティ/レビュー等の需要シグナル
7. 仮定

上位Evidenceがあるのに下位の一般論で置き換えない。

## 7. Forecast calibration

販売開始後、予測と実績を比較する。

Record:
- forecast orders vs actual
- forecast traffic vs actual
- forecast CVR vs actual
- forecast revenue/profit vs actual
- forecast error
- cause of error

AI5は予測誤差を蓄積し、次の商品予測を補正する。

目的は「毎回強気な数字を出す」ことではなく、商品を重ねるほど予測精度を上げること。

## 8. Prebuild scorecard

制作前に100点で採点する。例：
- Problem / demand: 20
- Willingness to pay: 15
- Differentiation: 10
- Reachability/distribution: 15
- Gross-margin potential: 10
- Build speed/cost: 10
- Evidence strength: 10
- Reuse/scalability: 10

プロジェクト特性に応じて配点変更可。ただし変更理由を残す。

## 9. Decision gate

Final:
- `GO`: Evidenceと期待値が十分。制作開始。
- `CONDITIONAL_GO`: 小さいMVP/検証だけ開始。条件達成前に大型投資しない。
- `NO_GO`: 現条件では制作しない。商品/市場/価格/訴求を変更して再評価。

AI5は「既に思いついたから」「作り始めたから」をGO理由にしない。

## 10. Profit-first calculation

売上予測だけでなく利益を見る：

`EXPECTED PROFIT = EXPECTED REVENUE - BUILD COST - AI/API COST - HOSTING - PAYMENT FEES - DISTRIBUTION COST - EXPECTED SUPPORT/REFUND COST`

Owner時間も可能な限りコスト/制約として扱う。

## 11. Behavioral-science precheck

制作前に、顧客の購入障壁と行動ファネルを仮説化する：

`EXPOSURE -> ATTENTION -> COMPREHENSION -> TRUST/MOTIVATION -> PROFILE/LP -> CHECKOUT -> PURCHASE -> USE/RETENTION`

各ボトルネックに対して、心理学・行動経済学・認知科学・脳神経科学等からEvidenceのある設計候補を選ぶ。

内部説明はOwner/AI5用。顧客向けへ自動転載しない。

## 12. Required prebuild report

本制作開始前に最低限以下を出す：

```text
PRODUCT =
TARGET CUSTOMER =
PROBLEM =
PRICE CANDIDATE =

HISTORY/CANONICAL READ = PASS / FAIL
PRIOR SALES DATA USED =
MARKET EVIDENCE =
COMPETITOR EVIDENCE =

SELLABILITY PROBABILITY:
LOW =
BASE =
HIGH =
CONFIDENCE =
SUCCESS DEFINITION =

7D SALES FORECAST = LOW / BASE / HIGH
30D SALES FORECAST = LOW / BASE / HIGH
90D SALES FORECAST = LOW / BASE / HIGH

EXPECTED PROFIT = LOW / BASE / HIGH
PREBUILD SCORE = __/100
TOP RISKS =
CHEAPEST VALIDATION =

DECISION = GO / CONDITIONAL_GO / NO_GO
```

## 13. Start-work prohibition

`HISTORY/CANONICAL READ = PASS` と prebuild report が無い状態で、大規模な本制作へ進まない。

ただし調査、read-only監査、最小プロトタイプ、需要検証はこのGateを完成させるために実行してよい。

## 14. Standing directive

AI5は毎回、過去の知識を捨ててゼロから始めない。

**過去Evidenceを読む -> 現在の市場で更新 -> 売れる可能性と販売数を予測 -> 最小コストで精査 -> 十分な期待値があるものだけ制作 -> 実績で予測モデルを改善**

この循環を全商品で積み上げる。
