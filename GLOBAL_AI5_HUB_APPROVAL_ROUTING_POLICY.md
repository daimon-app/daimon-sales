# Global AI5 HUB Approval Routing Policy

Version: 2026-09-01  
Scope: all Codex chats, projects, execution instances, AI5 HUB, Result Bus workers, revenue, development and sales lanes.

## Canonical route

When an operation genuinely requires Owner approval, Codex must create an `AI5_HUB_APPROVAL_TASK` instead of ending a chat with an approval question:

`CODEX -> AI5 HUB -> OWNER SMARTPHONE -> APPROVE / REJECT -> RESULT BUS -> CODEX AUTO RESUME`

Standing approval is checked first. Routine reversible work already inside approved product, channel, organic distribution, QA, cost ¥0, and sales scope is `PRE_AUTHORIZED` and must not create an approval task.

Each approval task contains task ID, project, action, reason, exact scope, public/private state, cost, reversibility, risk, changes, non-changes, priority, expiry where relevant, and Approve/Reject controls. Secrets, OTP, passwords, biometrics, recovery codes, and payment credentials never enter the task or Result Bus.

## Isolation and continuation

The affected task becomes `WAIT_AI5_HUB_APPROVAL`; `GLOBAL_STATE` remains `EXECUTING`. Approval, rejection, expiry, or a human-only action blocks only that task lineage. The watchdog claims the next unblocked task, especially during the 08:00–18:00 JST business window. Approval waiting is not a global stop.

Approve writes an idempotent decision receipt and returns the task to `READY -> CLAIMED` without another confirmation. Reject writes a receipt, marks only that task `REJECTED`, and claims the next safe task. An identical task/action/scope/cost/risk reuses the prior valid approval and may not request approval twice.

## Human-only action

OTP, CAPTCHA, KYC, biometric or identity verification, password entry, legal personal attestation, and real-spend confirmation use `OWNER_ACTION_REQUIRED`. The HUB shows one minimal action: what, where, how many times, expected time, why it is required, and what AI resumes afterward. Other tasks continue.

## Evidence

The lifecycle is recorded as `TASK_CREATED`, `HUB_DELIVERED`, `OWNER_DECISION`, `RESULT_RECEIVED`, `DECISION_PARSED`, `CODEX_RESUMED`, and `EXECUTION_COMPLETE`. Decision records carry task, decision, timestamp, exact scope, Owner action if any, receipt, scope hash, and idempotency key. Expired approval is never executed.

Only a security incident, material data-loss risk, real-money-loss risk, irreversible production damage risk, or major legal/safety risk may trigger a global safety stop.
