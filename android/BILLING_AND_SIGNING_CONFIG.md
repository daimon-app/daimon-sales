# Billing and upload-signing configuration

Billing identifiers are candidates until Play Console confirms them. Production purchase UI stays fail-closed unless all three are supplied:

- `DAIMON_BILLING_PRODUCT_ID`
- `DAIMON_BILLING_BASE_PLAN_ID`
- `DAIMON_BILLING_IDS_VERIFIED=true`

Authoritative verification also remains fail-closed until both are supplied:

- `DAIMON_BILLING_VERIFICATION_URL=https://.../v1/client/subscriptions/verify`
- `DAIMON_BILLING_SERVER_VERIFIED=true`

The app does not embed the server's internal API key. It grants entitlement and acknowledges a purchase only after the HTTPS service returns `ACTIVE`.

Upload signing is enabled only when all four process environment values exist; a partial set fails configuration:

- `DAIMON_UPLOAD_STORE_FILE`
- `DAIMON_UPLOAD_STORE_PASSWORD`
- `DAIMON_UPLOAD_KEY_ALIAS`
- `DAIMON_UPLOAD_KEY_PASSWORD`

Key material and passwords must remain outside every Git worktree. Only certificate fingerprints and artifact hashes belong in release evidence.
