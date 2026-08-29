# AI5 HUB FULL AUTONOMOUS LINE LOOP

Updated: 2026-08-19

## Purpose

AI5 LINE CHATを本人の統合入口とし、ZeroによるTask分解、専門AI Result、Zero Inbox、Codex最終技術監査、REWORK / REDISPATCH / CONTINUE / WAITING_APPROVAL / BLOCKED / COMPLETEを本人の中間コピペなしで循環させる。

## Result contract

全AI Resultは`taskId / agent / status / summary / actions / evidence / tests / changedFiles / issues / recommendation / needsRework / needsApproval`を保持する。LINEには短い要約だけを表示し、debug、token、秘密情報、長大stdoutは出さない。

## Completion and guard

成功Resultを受けても即完了せず、Zeroが`COMPLETE_CANDIDATE`を発行し、CodexがResult、必要test、失敗証跡、Single Writer、承認残件を技術監査する。両方PASSした場合だけ`COMPLETE`とする。`attemptCount / sameFailureCount / redispatchCount / dailyExecutionCount`を永続化し、同一失敗3回、最大cycle、最大attempt、日次上限で`BLOCKED`へ移行する。

## Persistence and recovery

Local Taskはprivate `daimon-app/ai5-github-result-bus`へTask / Result / Decision / Receipt / Loop Stateとして同期する。起動時はprivate visibilityとsecret scanを再検証してからremoteを復元する。Local Taskが消失しても、未完Remote Taskだけを復元し、Zero Safety Layerで再評価する。同一ResultはResult versionとreceiptでTimelineへ1回だけ表示する。

## Verified E2E

Mock Task `AI5-20260819-0001`を実Local APIへ投入し、`PLAN → agent COMPLETE → COMPLETE_CANDIDATE → Codex COMPLETE → Zero COMPLETE`、Zero Decision `PASS`、private pushを確認した。Private HEAD `845a0cfb2f311d864bee6ef689695cac2ba37979`を別cloneし、新規RuntimeのLINE Timelineへ同一Resultが1件だけ復元された。さらにTask `line-contract-1787139478`で全12 Result fieldとLoop Stateをprivate HEAD `9f14d03547d49460af56fcb651bd1416c67089c8`へpushし、別cloneで一致、秘密情報0件、公開remote漏えい0件を確認した。
