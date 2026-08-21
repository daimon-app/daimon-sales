# APPROVAL POLICY

| Class | AI action | Owner notification |
|---|---|---|
| `TECHNICAL_AUTO` | inspect, edit, test, build, normal commit/push, retry and verify | none |
| `OWNER_MONEY` | stop before payment or contract confirmation | MONEY |
| `OWNER_PUBLISH` | stop before public release, post or advertising | PUBLISH |
| `OWNER_IDENTITY` | stop for CAPTCHA, explicit 2FA, identity documents or personal assent | CRITICAL |
| `OWNER_IRREVERSIBLE` | stop before unrecoverable deletion or history rewrite | CRITICAL |

Ambiguous work defaults to `TECHNICAL_AUTO` only when it is reversible, workspace-scoped and has no external, money, public, identity or destructive effect. “Publish preparation” and drafts are technical; executing public release is not.

