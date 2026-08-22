# DAIMON Play Console field matrix

Status: `INPUT PACKAGE READY / CONSOLE AND OWNER FIELDS PENDING`  
Evidence baseline: Android source on this branch, 2026-08-22. No Console submission has been made.

## Commercial source of truth

- Download: free
- Monetization: in-app monthly subscription
- Current intended price: JPY 2,500/month
- Product ID candidate: `daimon_monthly`
- Base plan ID candidate: `monthly-2500-jpy`
- The former JPY 980 one-time model is `DEPRECATED — NOT CURRENT`.

## Store fields

| Console field | Proposed input | Length / evidence | State / owner action |
|---|---|---|---|
| App name | DAIMON | 6 chars; `@string/app_name` | READY |
| Default language | Japanese (`ja-JP`) | Current copy is Japanese | READY |
| App category | Lifestyle | Four-mode self-direction routine; not medical care | CANDIDATE — confirm in Console |
| Short description | 朝・仕事・夜・逆境。ズレた自分を、意図した方向へ戻す4モード習慣アプリ。 | 39 Japanese chars | READY |
| Full description | 朝・仕事・夜・逆境の4つの入口から、その瞬間に合う短い時間を選ぶ習慣サポートアプリです。音声ON/OFFと逆境モードの音響を備え、主要コンテンツは端末内に同梱されています。無料でダウンロードでき、継続利用機能は月額2,500円の自動更新サブスクリプションとして提供予定です。購入前にGoogle Playに表示される価格と条件をご確認ください。DAIMONは医療、診断、治療、心理療法を提供せず、特定の成果を保証しません。 | Existing four-mode implementation and Billing 9.1.0 | READY; final visual copy QA before input |
| Release notes | DAIMON初回リリース候補。朝・仕事・夜・逆境の4モード、音声ON/OFF、逆境モードの音響、オフライン同梱コンテンツ、Google Play月額サブスクリプション導線に対応しました。 | Android/PWA source | READY |
| Package name | `app.daimon` | `android/app/build.gradle` | PROVISIONAL — confirm availability before first upload |
| Version | `1.0.0-beta.1` / code `1` | `android/app/build.gradle` | CANDIDATE |
| Min / target / compile SDK | 23 / 35 / 35 | Gradle source | VERIFIED |
| App icon | Current adaptive and legacy launcher assets | `res/mipmap*` | READY FOR VISUAL QA |
| Feature graphic | 1024×500; DAIMON logo, “ズレたら、戻ればいい。” and four mode names; no price/medical claim | Existing release pack | ASSET PRODUCTION/QA REQUIRED |
| Phone screenshots | Home, Morning, Work, Night, Adversity/audio, Home return | Must be captured from installed release candidate | OWNER DEVICE / CAPTURE REQUIRED |
| Tablet screenshots | None asserted | Tablet behavior unverified | DECISION REQUIRED after emulator/device QA |
| Ads declaration | No ads | No ads SDK/dependency found | READY; re-audit final AAB |
| App access | No account/login; core shell launches without credentials | Manifest/source | READY; subscription test track still needs licensed tester |
| Target audience | General audience; not directed to children | Product positioning; no child-specific features | CANDIDATE — Owner confirms intended audience |
| Support email | Not recorded | Do not infer identity | OWNER_INPUT_REQUIRED |
| Support URL | Not recorded | No public canonical URL | OWNER_INPUT_REQUIRED |
| Privacy URL | Not recorded | No public canonical URL | OWNER_INPUT_REQUIRED |
| Terms URL | Not recorded | No public canonical URL | OWNER_INPUT_REQUIRED |
| Countries/regions | Not selected | Commercial/legal decision | OWNER_DECISION_REQUIRED |
| Subscription | Monthly auto-renewing; intended JPY 2,500/month | Latest owner instruction | Console creation/price activation OWNER ACTION |
| Cancellation | Manage/cancel through Google Play subscriptions; access rules must match Play status | Billing model | READY COPY; verify actual entitlement behavior |
| Refund | Subject to applicable law and Google Play policy; no additional promise recorded | No final seller policy | OWNER/LEGAL REVIEW REQUIRED |
| Data Safety | See `DATA_SAFETY_CODE_MAPPING.md` | Code-derived | DRAFT READY; final artifact/Console review required |
| Content rating | See `CONTENT_RATING_ANSWER_MATRIX.md` | Code-derived | DRAFT READY; questionnaire wording must be checked in Console |

## Permission and SDK inventory

- Permission: `android.permission.INTERNET`, added for Play Billing/network use.
- SDK/runtime dependencies explicitly found: AndroidX/AppCompat tooling through the Android project, Google Play Billing Library `9.1.0`, JUnit `4.13.2` test-only.
- No ads, analytics, crash reporting, account, camera, microphone, contacts, location, or storage permission found in the inspected manifest/source.

## Production checklist

1. Confirm package and subscription identifiers in Play Console.
2. Replace all provisional URLs/contact identity with canonical Owner-approved values.
3. Use signed AAB and inspect final manifest/dependency inventory.
4. Complete device and licensed-test-purchase QA; do not call untested purchase flow PASS.
5. Confirm Data Safety, content rating, target audience, pricing, regions, tax/payment profile.
6. Owner alone performs legal agreements, identity verification, payment setup and production release.

