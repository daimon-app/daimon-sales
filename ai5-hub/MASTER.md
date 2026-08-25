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
