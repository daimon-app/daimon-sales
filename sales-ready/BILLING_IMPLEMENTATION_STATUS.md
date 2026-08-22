# Billing implementation status

- Model: free download + ¥2,500/month auto-renewing subscription.
- Library: Google Play Billing 9.1.0.
- Candidate IDs: configurable `daimon_monthly` / `monthly-2500-jpy`.
- Fail-closed: purchase launch is blocked until `DAIMON_BILLING_IDS_VERIFIED=true`.
- Implemented: connect, ProductDetails/base-plan selection, purchase launch, restore/query, pending, acknowledgement, entitlement event bridge.
- Explicit state vocabulary includes unknown, not-entitled, in-progress, unacknowledged, entitled, pending, grace, canceled-active, expired, refunded, network error and Play unavailable.
- Unit tests/build: PASS. Static readiness: 76 PASS / 0 WARN / 0 FAIL.
- Security: bundled `file:///android_asset/` origin only; external navigation/file chooser disabled; purchase token is not exposed to JavaScript or logs.
- Server-backed verdict: Android sends the purchase token to the configured HTTPS client endpoint and grants entitlement/acknowledges only after an authoritative ACTIVE verdict. No reusable server secret is embedded in the APK.
- Server durability: atomic single-instance ledger with restart/crash recovery and replay-safe refresh is implemented; multi-instance production requires transactional shared storage.
- Not release-PASS: deployed HTTPS endpoint, Play internal-track purchase/renew/cancel/refund evidence and final Console ID/base-plan match.
