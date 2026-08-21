# OWNER ACTION QUEUE

Only the first item is currently actionable. Other lanes continue while it waits.

## OA-01 — Google Play account type

- Service: Google Play Console
- Current screen: Developer account creation / account type selection
- One action: choose `Personal` or `Organization`
- Zero recommendation: choose `Organization` only if DAIMON will be sold under a real continuing business/organization identity and matching D-U-N-S information can be supplied; otherwise choose `Personal` and plan for the official 12-testers/14-days closed-test gate
- Reason: the owner identity is permanent and controls verification, displayed developer information and payments profile
- Payment: developer registration fee follows after this choice
- Public information: legal/developer contact information varies by account and monetization setup
- Completion phrase: `PLAY ACCOUNT TYPE SELECTED: PERSONAL` or `PLAY ACCOUNT TYPE SELECTED: ORGANIZATION`
- Auto-resume: registration verification → app creation → signed-AAB/Listing/App Content preparation

## Later owner gates

1. Production upload-key custody/signing identity. Do not send passwords or keys in chat or Git.
2. Price model: paid download versus subscription/IAP. Repository contains no Play Billing SDK; historical ¥980 paid-app material conflicts with the new ¥2,500/month instruction.
3. Real tester recipients approval before invitations.
4. SNS login/account-creation confirmation per service.
5. Final Production rollout and SNS posts.

