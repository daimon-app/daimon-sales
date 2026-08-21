# AI AUTO APPROVAL SPEC

AI5 HUB routes every requested action through a five-class risk decision before dispatch.

`TECHNICAL_AUTO` covers reversible, non-public, non-financial, non-identity workspace work. It proceeds through the existing Single Writer executor, tests, Codex/Zero double judgement, bounded repair loop and evidence log without asking the owner to interpret technical details.

`OWNER_MONEY`, `OWNER_PUBLISH`, `OWNER_IDENTITY` and `OWNER_IRREVERSIBLE` stop at an Owner Gate. Approval tokens remain one-time and approval automatically resumes the Worker. CAPTCHA and identity checks are never bypassed.

Every decision records the request, classification, risk flags, executor, verifier, tests, timestamp, commit and rollback information.

