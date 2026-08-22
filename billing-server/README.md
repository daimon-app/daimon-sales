# DAIMON Billing Verification Server

Local-first purchase verification foundation. It never grants entitlement when verification is unavailable. Purchase tokens are neither logged nor persisted; ledger and audit entries use an HMAC fingerprint.

## Local Fake and API

Copy `.env.example` to `.env`, replace both secrets, then run `npm test` and `npm start`. Fake token `local-active-token` is active. Fake mode must never be deployed as production.

`POST /v1/google-play/subscriptions/verify`, bearer-authenticated body:

```json
{"purchaseToken":"opaque","productId":"daimon_monthly","packageName":"app.daimon"}
```

Never send purchase tokens through URLs, analytics, client logs or support forms.

## Production and RTDN design

`GooglePlayVerifier` signs a short-lived service-account JWT, exchanges it through the configured official token endpoint, calls `purchases.subscriptionsv2.get`, validates package/product, and normalizes expiry, acknowledgement, cancellation and revocation/refund. Missing credentials fail at startup. Credentials and access tokens are never logged.

Real-time developer notifications terminate at a separate authenticated Pub/Sub push endpoint. Validate JWT/audience, decode only subscription notifications, fetch authoritative state from Google rather than trusting notification fields, and pass it through the same idempotent verifier/ledger. Renewal, cancellation, expiry, hold, grace and revocation then converge on one state machine.

## Deploy

1. Enable the API/create a least-privilege service account only after Owner approval.
2. Keep credentials in a platform secret manager, never Git or the image.
3. Replace the process-local ledger with a transactional durable ledger having a unique token-fingerprint index, and rerun tests.
4. Build `docker build -t daimon-billing-verifier .`; deploy privately behind TLS/API gateway.
5. Configure rate limiting, retention, monitoring and two independently generated secrets.
6. Test acknowledge, renewal, cancellation, hold/grace, refund and replay with Play license testers.

## Recovery

On Google/storage failure, deny new entitlement changes, retain only last server-confirmed expiry, alert and retry with bounded backoff. Rotate compromised API/HMAC keys; HMAC rotation requires dual-key migration. Restore the encrypted ledger, replay authenticated notifications and reconcile all active fingerprints against Google. Never restore entitlement from client claims.

## Current limits

The default runtime uses an atomic durable JSON ledger with cross-process lock, stale-lock recovery and crash-safe temp-file replacement. It is a single-instance foundation; horizontal deployment should migrate the same interface to a transactional database with a unique fingerprint constraint. Google credentials, cloud deployment, Pub/Sub configuration and live purchase tests remain external/Owner gates.
