# DAIMON Data Safety / privacy implementation draft

Date: 2026-08-20  
Scope: unsigned four-mode Android AAB produced from the current branch  
Status: `DRAFT — RECONFIRM AGAINST SIGNED UPLOAD ARTIFACT`

## Audited behavior

| Topic | Evidence-based declaration for this candidate |
|---|---|
| Network | No Android `INTERNET` permission; content is bundled locally |
| Data collected by app/operator | None identified in the audited runtime |
| Data shared with third parties | None identified |
| Accounts | None |
| Analytics / crash reporting | None |
| Ads | None |
| Billing SDK | None in the app binary |
| Location / camera / microphone / contacts / files | No permission requested |
| Local storage | `localStorage`: `daimon.audioEnabled`, `daimon.userName` |
| Backup | Android backup and data extraction disabled |
| Cleartext traffic | Disabled; no network permission |
| Delete path | Android uninstall or Clear storage removes local WebView data |

`daimon.userName` is an optional local display value if already configured. It is
not transmitted by this candidate. `daimon.audioEnabled` stores only the local
audio preference.

## Play Console draft answers

- Does the app collect or share required user data types? **No, for this audited candidate.**
- Is all user data encrypted in transit? **Not applicable: the candidate sends no user data.**
- Does the app provide account creation? **No.**
- Can users request account deletion? **Not applicable: no account exists.**

These are draft answers, not a permanent product promise. Re-audit if the signed
artifact adds billing, analytics, crash reporting, support forms, remote media,
accounts, cloud sync or any SDK/dependency.

## Privacy policy facts that must remain aligned

1. DAIMON runs its four modes from content packaged inside the app.
2. It stores the audio preference and an optional display name locally on the device.
3. The audited version does not transmit those values to DAIMON or third parties.
4. The audited version contains no ads, analytics or account system.
5. Clearing app storage or uninstalling removes locally stored app data.
6. A support channel, if published outside the app, must separately disclose how
   messages and contact details sent by the user are handled.
7. DAIMON is not medical care, diagnosis, therapy or an outcome guarantee.

## Revalidation triggers

Any of the following changes make this draft stale: manifest permission changes,
new Gradle/runtime dependency, remote URL/network access, Play Billing, analytics,
crash reporting, ads, support form, account/login, cloud sync, push notification,
camera/microphone/file access, or backup-policy change.

