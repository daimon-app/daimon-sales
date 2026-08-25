# AI5 HUB Canonical Route Summary

The normative operating specification is [ZERO_SPEC.md](./ZERO_SPEC.md). The approval boundary is [APPROVAL_POLICY.md](./APPROVAL_POLICY.md), Result Bus operation is [docs/AI5_GITHUB_RESULT_LOOP.md](./docs/AI5_GITHUB_RESULT_LOOP.md), and architectural decisions are [docs/DECISIONS.md](./docs/DECISIONS.md).

## Manus

- Primary: `MAIL_MANUS`
- Secondary: verified and authenticated direct/API route only
- Fallback: preserved Manus APP, then WEB
- Identity: `AI5_TASK_ID + CORRELATION_ID + MAIL_MESSAGE_ID + MAIL_THREAD_ID + MANUS_TASK_ID`
- A task at `MAIL_QUEUED` or later is never resent without sent-mail and Result Bus reconciliation.
- `MANUS ACTIVE` requires dispatch, Manus task creation, execution, result generation and verified recovery.
- Dedicated Mail Manus addresses and all secrets are local configuration only.

Rollback is route selection back to APP/WEB; the legacy adapter remains intact.

## ZERO closed loop

Required path: ZERO → AI5 HUB → ROUTER → CODEX / CLAUDE API / GEMINI API / MAIL MANUS → RESULT BUS → ZERO.

Claude chat and Gemini chat are audit/fallback tools and are not required nodes for AI5_ZERO_ONLY_OPERATION_READY. The API nodes use the common ZERO Task/Result schemas. Current truth states are PASS, FAIL, NOT_WIRED, WAITING_OWNER_AUTH, WAITING_OWNER_MONEY, and BLOCKED; no internal substitute may promote an external node to PASS.

Every execution uses an atomic persistent claim keyed by TASK_ID + CORRELATION_ID, a project Single Writer lease, a maximum of three attempts, crash lease recovery, and create-only Result acceptance.
