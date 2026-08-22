# CM final QA

Audit date: 2026-08-22 (JST)

## Overall result

## 2026-08-22 generated safe set update

The requested 36 slots now exist under `cm-generated/`. FFprobe/remux-backed duration and dimension checks plus SHA-256 inventory are `36 PASS / 0 FAIL` in `CM_GENERATED_HASH_QA.md`. These files use only programmatic shapes and product copy and contain no audio stream or downloaded third-party media.

The WebM files are generation sources. The authoritative publication candidates are the H.264 MP4 files under `cm-final/`; `CM_MP4_FINAL_LEDGER.md` records 36/36 ffprobe machine PASS.

Independent sampled-frame inspection covered start/middle/end for every file (108 decoded frames) using the six contact sheets under `cm-qa-sheets/`. DAIMON and 切り替えスイッチ passed product name, CTA, price/status, claim, clipping and sampled ending-frame checks. The first CAD render clipped its long hook; it was regenerated with shorter copy and smaller/wrapped text, then all 12 CAD candidates passed repeat sampling. This is **sampled-frame visual PASS**, not full-frame human playback, hearing, brand approval, or platform upload PASS.

All 36 MP4s have zero audio streams. Listening is therefore `NOT APPLICABLE (NO AUDIO STREAM)`, not a claimed human hearing PASS. No file has been published.

## Legacy four-file audit snapshot

The earlier search found **0 PASS / 4 PARTIAL / 32 MISSING** before the safe set was generated. The following table remains as evidence for those legacy files, not as the current target-slot count.

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

FFmpeg/ffprobe 9.0.1 became available from the local marketing toolchain and was used for the final MP4 audit. Each final file is H.264 High, yuv420p, 30/1 fps, expected 1080×1920 or 720×1280, exact 6/15/30-second slot (within the strict script tolerance), zero audio streams, and start/middle/end decode success. Full-frame playback and actual platform upload remain UNVERIFIED.
