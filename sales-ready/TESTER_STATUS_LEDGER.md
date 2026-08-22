# DAIMON tester status ledger

Status: `EMPTY TEMPLATE — NO FAKE PARTICIPANTS`

Use a non-Git encrypted operational store for real rows. This file defines fields/status vocabulary only.

| Pseudonymous ID | Invite | Consent time | Device/OS | Version | Install | Core QA | Billing QA | Feedback | Fix | Last contact | Delete by |
|---|---|---|---|---|---|---|---|---|---|---|---|
| _no real records in Git_ | | | | | | | | | | | |

- Invite: `DRAFT`, `OWNER_APPROVED`, `SENT`, `OPTED_IN`, `DECLINED`, `WITHDRAWN`
- Result: `PASS`, `FAIL`, `PARTIAL`, `UNVERIFIED`, `BLOCKED`
- Severity: `P0`, `P1`, `P2`, `P3`
- Fix: `NEW`, `TRIAGED`, `IN_PROGRESS`, `FIXED_PENDING_RETEST`, `VERIFIED`, `WONT_FIX_WITH_REASON`

Daily operation checks new opt-ins, consent, delivery failures, P0/P1 reports, duplicates, retest and deletion requests. Never place participant email, identifying screenshots, purchase tokens or account IDs in Git.

