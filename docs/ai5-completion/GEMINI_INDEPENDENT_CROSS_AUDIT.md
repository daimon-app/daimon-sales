# Gemini independent cross-audit — CM / Play / Data Safety / Content Rating / SNS

Audit date: 2026-08-22 (JST)  
Scope: current local code and documentation plus official first-party requirements. No external posting, Console submission, purchase, or publication was performed.

## Executive result

| Area | Decision |
|---|---|
| 36 CM MP4 candidates | 36/36 existence/hash/ffprobe PASS; 36/36 start/mid/end sampled-frame visual PASS after one CAD clipping repair |
| Audio | 36/36 zero audio streams; listening `N/A`, not hearing PASS |
| Rights | Programmatic shapes and project-authored copy only; no third-party media detected. Owner brand/public-copy authorization remains |
| DAIMON price/copy | New CM uses `月額2,500円｜公開準備中`; legacy Morning marketing still contains 490円買い切り and must remain deprecated/not published |
| Billing | Billing Library 9.1.0 matches current official integration example, but commit `214bc39` grants/acknowledges on-device without secure-backend verification: release blocker until server integration is the entitlement authority |
| Data Safety | Existing old “no INTERNET/no Billing” answers are stale for the Billing build. Final mapping must include Billing/INTERNET and any verification-server purchase-token flow |
| Content Rating | Purchase/in-app purchase must be answered from actual Billing behavior; old “no purchases inside app” statement is stale |
| SNS/platform | MP4 master is suitable as a vertical candidate for Instagram/YouTube; X-specific 720×1280 MP4 is within X web limits. TikTok/Facebook/Threads upload acceptance remains unverified by live upload |

## CM evidence and sampled visual review

- Final path: `docs/ai5-completion/cm-final/` (36 H.264 MP4 files).
- Machine ledger: `CM_MP4_FINAL_LEDGER.md`; raw evidence: `cm-machine-audit.json`.
- Frame evidence: `cm-qa-frames/` (108 JPEGs) and six `cm-qa-sheets/*.png` contact sheets.
- Every file was decoded at approximately 0.5 seconds, midpoint and 0.5 seconds before end.
- Product names, main hook, benefit/status, CTA, caption/no-caption distinction, progress/ending state and outer-frame clipping were checked on all 108 samples.
- DAIMON: `月額2,500円｜公開準備中`; no medical/result guarantee or fake testimonial.
- 切り替えスイッチ: `0円・無料公開β｜準備中`; no paid-price claim or guaranteed alarm/push behavior.
- CAD: `FIELD-001 実証参加者を募集中` and `FIELD VALIDATION｜準備中`; no fabricated FIELD result. Initial clipped hook was repaired to `割付と材料拾いを、現場で検証。` and re-sampled.
- Content is placed approximately within horizontal 8–92% and vertical 12–92%. Sample frames show no file-edge clipping. Platform UI-overlay safety and upload recompression remain live-platform `UNVERIFIED`.
- Frame sampling does not prove every intervening frame. Full continuous human playback remains a pre-publication checklist item.

## Technical/media compatibility

FFprobe 9.0.1 reports all 36 final files as H.264 High, yuv420p, 30 fps, expected dimensions, exact target duration and zero audio streams.

- Instagram official Help says Reels accept 1.91:1 through 9:16 and require at least 30 fps and 720px resolution. Both 1080×1920 and 720×1280 MP4 sets meet those measured numeric gates: <https://www.facebook.com/help/1038071743007909>.
- YouTube official Help classifies square/vertical videos up to three minutes as Shorts; all candidates are vertical and at most 30 seconds: <https://support.google.com/youtube/answer/15424877>.
- X official web-upload limits include maximum vertical 1200×1900, aspect ratio 1:2.39–2.39:1 and maximum 40 fps. Use the dedicated 720×1280 X files; do not use 1080×1920 masters on X because 1920 exceeds the stated vertical height limit: <https://help.x.com/en/using-x/x-videos>.
- X Media Studio documents MP4/MOV with H.264 and up to 60 fps for that interface: <https://help.x.com/en/using-x/media-studio-faqs>.
- No official live upload was performed. TikTok, Facebook Reels and Threads acceptance is `UNVERIFIED`; do not infer it from another Meta product.

## Billing and Play consistency

Commit `214bc399fcd9afb9eb6cb4a9a7661ce61c25c00f` contains Billing 9.1.0, configurable BuildConfig product/base-plan IDs, INTERNET permission and subscription purchase/query/acknowledge logic. It currently treats a matching locally returned `PURCHASED` item as entitled and acknowledges it on-device.

Official Android guidance says to verify a purchase on a secure backend before granting entitlement, grant only for `PURCHASED`, handle `PENDING`, and preferably acknowledge subscriptions on the backend. Purchase tokens should be sent to the backend and checked for uniqueness/replay: <https://developer.android.com/google/play/billing/integrate>, <https://developer.android.com/google/play/billing/security>, <https://developer.android.com/google/play/billing/backend>.

Therefore:

1. Billing Library version: PASS against current official example (`9.1.0`).
2. Product/base-plan mismatch: fail-closed selection exists, but Console values remain unverified.
3. Server-authoritative verification/replay protection: FAIL in inspected commit; release blocker.
4. Lifecycle synchronization (grace, hold, pause, expiry, refund/void): incomplete in inspected client; backend/RTDN work remains. Official lifecycle reference: <https://developer.android.com/google/play/billing/lifecycle/subscriptions>.

## Data Safety / privacy

Google requires all published apps to complete Data Safety and to account for data handled by included SDKs: <https://support.google.com/googleplay/android-developer/answer/10787469>.

The old Morning documents claiming no INTERNET, no Billing SDK and no purchase in-app are not valid evidence for the current Billing build. At minimum the final code mapping must resolve:

- Google Play Billing SDK and INTERNET permission.
- Purchase history/product/entitlement data accessed on device.
- Purchase token, package name/product ID, account binding and audit data sent to the planned verification backend.
- Whether Google Play is treated as a service provider and whether any data is shared beyond service-provider processing.
- TLS, retention, deletion/support route, diagnostic logs and RTDN/Cloud logging.

Until the verification server and privacy text are frozen, Data Safety is `PARTIAL / DO NOT SUBMIT`, not “no collection” PASS.

## Content Rating and store/SNS copy

- Content Rating must disclose in-app purchases because the current app launches a subscription purchase flow. `_product_worktrees/morning-final/marketing/play-store/console-answer-map.md` says “no purchases inside the app” and is stale.
- No inspected CM contains violence, sex, gambling, drugs, UGC, user-to-user exchange, location claim, medical claim or guaranteed health/business outcome.
- DAIMON CM states the current monthly price and prelaunch state. It does not claim a trial, discount, cancellation/refund outcome, or release date.
- Legacy Morning LP/social/CM copy still contains `490円・買い切り`; it must be marked deprecated or replaced before any public use. New monthly CM must not be paired with those old captions.
- Google Play warns store assets must accurately reflect implemented functionality: <https://support.google.com/googleplay/android-developer/answer/15191715>.

## Final gate

CM technical/sampled-visual gate: **CONDITIONAL PASS**. Remaining owner/live gates are continuous human playback, brand/copy authorization and real platform upload/recompression checks. Billing/Data Safety/Content Rating gate: **FAIL/PARTIAL** until server-authoritative verification and current-code mappings replace the stale Morning/no-purchase declarations. No production release or social posting is authorized by this audit.
