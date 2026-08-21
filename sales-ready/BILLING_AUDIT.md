# BILLING AUDIT

Status: `OWNER DECISION REQUIRED`

- Android dependencies contain no Google Play Billing Library.
- No `BillingClient`, purchase acknowledgement, entitlement, restore, subscription, renewal, expiry, hold or resubscribe implementation exists.
- Manifest has no INTERNET permission; the release is an offline bundled WebView shell.
- Existing sales material describes a recommended ¥980 one-time paid-app price. The latest instruction says ¥2,500/month. These are different product models and must not be mixed.
- A one-time paid download configured in Play Console does not require in-app Billing SDK. A monthly subscription/digital entitlement does require a compliant purchase and entitlement design.

Do not create a subscription product ID or advertise ¥2,500/month until Zero/Owner selects the model. If subscription is selected, technical implementation, server-verification decision, privacy/data-safety reconciliation and Billing QA become mandatory.

