# Billing Server Status

## Delivered

- Node 22 HTTP service, Docker packaging and environment-only configuration
- Authenticated endpoint with strict identity validation
- Explicit fail-closed production adapter and local Fake integration
- Entitlement state normalization
- HMAC token fingerprint; raw token excluded from audit/ledger
- Durable atomic single-instance ledger, restart recovery, idempotency, cross-identity replay rejection, timeout and bounded retry
- Per-client fixed-window rate limiting with fail-closed HTTP 429
- API, official adapter, RTDN, deployment and recovery documentation

## Production gate

Not deployed. The subscriptions v2 adapter is Fake-tested. Before horizontal production, migrate the atomic file ledger to transactional shared storage; provision Google/Cloud credentials with Owner approval, configure authenticated Pub/Sub, stage with license testers, and complete security/load review.

The foundation intentionally denies entitlement whenever authoritative verification cannot complete.
