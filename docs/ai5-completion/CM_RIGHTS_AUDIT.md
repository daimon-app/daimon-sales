# CM rights audit

Audit date: 2026-08-22 (JST)

## Release decision

**FAIL / BLOCK PUBLICATION.** No inspected video has a complete evidence chain for every visual, screen recording, logo, font, narration, music, and other audio element. Absence of a recorded third-party asset is not proof of rights.

## 2026-08-22 programmatic replacement set

The 36 new MP4 candidates under `cm-final/` do not incorporate the four legacy videos or any downloaded image, footage, music, narration, or third-party logo. Their only rendered inputs are programmatic gradients/circles/progress bars and project-authored product copy in `cm-tools/generate-safe-cm.mjs`; ffprobe verifies zero audio streams. Technical asset provenance is therefore `PROGRAMMATIC-ONLY / NO THIRD-PARTY MEDIA DETECTED`.

This does not establish trademark ownership or approve public advertising. Final DAIMON/切り替えスイッチ/大工AI CAD brand authorization and public-copy approval remain Owner gates. The legacy four-file decision below remains unchanged.

## Candidate assessment

| File | Rights status | Evidence |
|---|---|---|
| `cm-a-morning-1080x1920.mp4` | `RIGHTS_UNVERIFIED — DO NOT PUBLISH` | `_product_worktrees/morning-final/marketing/cm/README.md` explicitly says it and `build-cm-a.ps1` contain an old PWA image with unconfirmed rights and prohibits publication/re-generation. |
| `cm-a-teaser-1080x1920.mp4` | UNVERIFIED | No per-asset creator/source/license ledger was found for the rendered output. |
| `cm-b-product-flow-1080x1920.mp4` | UNVERIFIED | Script requires final-AAB footage and a verified asset-rights ledger; evidence of both conditions was not found. |
| `cm-c-purchase-1080x1920.mp4` | UNVERIFIED | Same unresolved final-AAB-footage and rights-ledger gate as CM-B. |

## Rights categories

| Category | Evidence found | Decision |
|---|---|---|
| App screen recordings | Static source assets/build scripts exist; final-AAB provenance is not demonstrated per file | UNVERIFIED |
| Logo/brand | DAIMON assets exist, but owner/approved commercial-use evidence is not linked per output | UNVERIFIED |
| Fonts | Render/build files do not provide a per-output font license record | UNVERIFIED |
| BGM | Specifications state BGMなし | PARTIAL: must confirm by playback/stream inspection |
| Narration/audio | Specifications state audioなし for current exports | PARTIAL: must confirm by stream inspection/listening |
| Images/backgrounds | One old PWA image is explicitly rights-unverified; the other files have no complete source/license chain | FAIL/UNVERIFIED |

## Admission rule

A file may move to `RIGHTS_VERIFIED` only when its ledger records creator/source, license or ownership basis, commercial/social/store/advertising scope, modification permission, attribution requirement, evidence location, and approver/date for every incorporated asset. Generated replacements must use newly created or independently licensed material; lack of provenance cannot be cured by renaming the file.

No file was deleted, regenerated, uploaded, or published during this audit.
