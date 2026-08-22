# DAIMON Data Safety code mapping

Status: `CODE-DERIVED DRAFT — FINAL AAB AND SERVER RE-AUDIT REQUIRED`

The older `DATA_SAFETY_DRAFT_2026-08-20.md` predates Billing and its statements “no INTERNET permission / no Billing SDK” are deprecated.

| Data / behavior | Collected | Shared | Required | Purpose | Code evidence / uncertainty |
|---|---:|---:|---|---|---|
| Purchase history / subscription status | Yes, processed through Google Play | With Google Play as purchase provider | Required for paid entitlement | App functionality, fraud prevention, account management by Play | Billing `9.1.0`; `DaimonBilling.java` queries purchases and acknowledges tokens. Console/server behavior not yet live-audited. |
| Purchase token | Processed in app memory by Billing SDK | Google Play | Required for purchase lifecycle | Verify/acknowledge purchase | `getPurchaseToken()` passed to `acknowledgePurchase`; no app log/display found. A future verification server changes collection mapping. |
| Optional display name | Local only in inspected PWA | No evidence of transmission | Optional | App personalization | `localStorage` key `daimon.userName`; final bundled assets must be re-scanned. |
| Audio preference | Local only | No | Optional | App settings | `localStorage` key `daimon.audioEnabled`. |
| Device identifiers | No direct app access found | Billing/Play may process service identifiers under Google terms | N/A to app code | Billing service operation | No custom identifier API found; SDK disclosure must reflect Play Billing documentation/current Console wording. |
| Diagnostics / crash data | No app SDK found | No app-controlled sharing found | No | N/A | No analytics/crash dependency found. Google Play platform reporting is separate. |
| Account/contact/location/camera/mic/files/contacts | No | No | No | N/A | No corresponding permissions or APIs found. |

## Transport, storage and retention

- `INTERNET` is declared. Cleartext is disabled and network security configuration is present.
- Product media is bundled under `file:///android_asset/`; navigation outside that origin is blocked by `WebViewClient`.
- Android backup and data extraction are disabled.
- Local preferences remain until clear storage/uninstall. No operator-controlled retention period exists for them.
- Purchase records are governed by Google Play. Operator-side server retention is `UNVERIFIED` because the production verification server is not evidenced here.
- No in-app DAIMON account or account-deletion path exists. Purchase/subscription management is through Google Play.

## Privacy policy alignment requirements

The published policy must disclose Google Play Billing, purchase/status processing, local display name/audio preference, no ads/analytics in this candidate, uninstall/clear-data behavior, support-contact handling, and that DAIMON is not medical care. If server verification, RTDN, analytics, crash reporting, support forms, accounts or cloud sync are added, this mapping must be redone before submission.

## Console answer boundary

Do not answer “no data collected” solely from the old draft. Final answers depend on current Google definitions for purchase history and whether a verification server stores tokens/status. `OWNER/CONSOLE REVIEW REQUIRED` after final artifact and backend architecture are fixed.

