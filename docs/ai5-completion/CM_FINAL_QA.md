# CM final QA

Audit date: 2026-08-22 (JST)

## Overall result

**0 PASS / 4 PARTIAL / 32 MISSING within the requested 36-file target.** This is not a final visual/audio QA pass. Hash, byte size, Git tracking, and Windows Shell duration were verified for four candidates. Full-frame playback, decoded resolution/FPS, audio inspection, safe areas, subtitle accuracy, ending frame, and claims review remain unverified.

## Candidate QA

| File | Existence/hash | Duration | Resolution/FPS | Full visual review | Audio review | Copy/claims | Rights | Result |
|---|---|---|---|---|---|---|---|---|
| `cm-a-morning-1080x1920.mp4` | PASS | 7s PASS | UNVERIFIED | UNVERIFIED | UNVERIFIED | Obsolete Morning/product-price context risk | FAIL | BLOCKED |
| `cm-a-teaser-1080x1920.mp4` | PASS | 7s PASS | UNVERIFIED | UNVERIFIED | UNVERIFIED | Morning-edition vs four-mode/monthly alignment unverified | UNVERIFIED | PARTIAL |
| `cm-b-product-flow-1080x1920.mp4` | PASS | 15s PASS | UNVERIFIED | UNVERIFIED | UNVERIFIED | Current product/price/final-AAB alignment unverified | UNVERIFIED | PARTIAL |
| `cm-c-purchase-1080x1920.mp4` | PASS | 21s PASS | UNVERIFIED | UNVERIFIED | UNVERIFIED | Current product/price/final-AAB alignment unverified | UNVERIFIED | PARTIAL |

## Required final checklist per actual file

- Full playback without decode errors; exact duration, width, height, aspect ratio, FPS, video/audio codecs.
- Silence or audio track intent; loudness, clipping, missing narration, synchronization.
- Subtitle spelling, timing, legibility, safe area, no crop at platform UI overlays.
- Correct logo, product name, CTA, current price/plan, and ending frame.
- No nonexistent functionality, medical claim, guaranteed outcome, fake review/user/sales, or unverified field result.
- BGM, narration, font, image, video, screen-recording and logo rights all `RIGHTS_VERIFIED`.
- Master and 720×1280 X adaptation traced to the same approved source/version.

## Evidence limitation

`ffprobe` was not available in this environment. Windows Shell reported durations only and did not expose width/height/FPS. Filename suffixes such as `1080x1920` are not measurements. No human full-playback evidence was produced in this audit; therefore machine existence/hash checks cannot be promoted to release QA PASS.

