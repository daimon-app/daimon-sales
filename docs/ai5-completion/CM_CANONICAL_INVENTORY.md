# CM canonical inventory

Audit date: 2026-08-22 (JST)  
Scope: files available under the current `daimon-sales` workspace. No remote fetch, Web search, upload, generation, or publication was performed.

## 2026-08-22 generated target set

After this discovery snapshot, the 36 requested slots were generated under `cm-generated/`: 3 products × 3 durations × 2 caption variants × 2 output sizes. `CM_GENERATED_HASH_QA.md` is the current file/hash/machine-QA ledger. Machine QA is 36/36 PASS; human QA and publication approval remain UNVERIFIED.

## Decision

At the time of the initial search, the statement “36 CM files exist” was not supported and only four legacy videos were found. The generated target set above now satisfies file-count/duration/dimension/hash evidence, while final rights/copy/visual approval remains open.

Canonical target:

- Master: DAIMON, 切り替えスイッチ, 大工AI CAD × 6/15/30 seconds × captioned/non-captioned = 18 files.
- X: matching 720×1280 exports = 18 files.
- Total target: 36 actual video files.

Measured status: **0/36 accepted, 4 candidate files found, 32 target slots have no candidate file, 36/36 not release-ready.**

## Actual files found

All four files are Git-tracked in the `daimon-app/daimon-sales` worktree. Duration is the Windows Shell media-property result; SHA-256 and bytes were measured directly. Resolution is present in the filename/build specification but could not be independently decoded because `ffprobe` is unavailable, so it remains unverified.

| Candidate | Bytes | Duration | SHA-256 | Evidence/status |
|---|---:|---:|---|---|
| `_product_worktrees/morning-final/marketing/cm/exports/cm-a-morning-1080x1920.mp4` | 310,531 | 00:00:07 | `123DEC2366576A5820E1F815C461DD64B44371678E5F89C4E4A943A5F1955EC9` | DAIMON Morning candidate; expressly deprecated and rights-unverified in `marketing/cm/README.md`; **DO NOT PUBLISH** |
| `_product_worktrees/morning-final/marketing/cm/exports/cm-a-teaser-1080x1920.mp4` | 190,195 | 00:00:07 | `8467C081578EEBD60CA00B001A85762BC0A2E16BAEEED2DAF78C991CA081EA6C` | DAIMON Morning teaser candidate; not a requested 6-second file; rights and full playback QA unverified |
| `_product_worktrees/morning-final/marketing/cm/exports/cm-b-product-flow-1080x1920.mp4` | 230,092 | 00:00:15 | `A49CF89019B180412458339DB35A969CB569A9F6AB2A4764C7E5A15FE7928E05` | DAIMON Morning candidate; requested duration matches 15s, but caption variant, rights, final-AAB footage, and visual/audio QA are unverified |
| `_product_worktrees/morning-final/marketing/cm/exports/cm-c-purchase-1080x1920.mp4` | 341,448 | 00:00:21 | `3D38538D1987C937E10EF0FA9E35ED3FD03E64C2D0284D76840BE73A7A450B9A` | DAIMON Morning purchase candidate; not a requested 30-second file; rights and full playback QA unverified |

## Target coverage

| Product | Master 6s cap/no-cap | Master 15s cap/no-cap | Master 30s cap/no-cap | X 6/15/30 cap/no-cap | Accepted |
|---|---|---|---|---|---:|
| DAIMON | MISSING/MISSING | CANDIDATE-UNVERIFIED/MISSING | MISSING/MISSING | all 6 MISSING | 0/12 |
| 切り替えスイッチ | MISSING/MISSING | MISSING/MISSING | MISSING/MISSING | all 6 MISSING | 0/12 |
| 大工AI CAD | MISSING/MISSING | MISSING/MISSING | MISSING/MISSING | all 6 MISSING | 0/12 |

The two 7-second and one 21-second videos are retained as noncanonical candidates, not silently rounded into 6/30-second slots.

## Source specifications found

- `_product_worktrees/morning-final/marketing/cm/scripts/cm-master.md` defines A=7s, B=15s, C=21s, D=15s switch (held), E=25s.
- `_product_worktrees/morning-final/marketing/cm/README.md` states BGM/audio absent and identifies the old `cm-a-morning` source as rights-unverified/deprecated.
- No actual CM video was found for 切り替えスイッチ or 大工AI CAD.
- No 720×1280 X export was found.

## Remaining executable work

1. Establish a signed-off asset-rights ledger before admitting any candidate.
2. Decode technical metadata with a trusted media inspector and perform complete playback QA.
3. Reconcile DAIMON copy with the current four-mode/monthly product; existing candidates are Morning-edition artifacts.
4. Generate only the missing, rights-clear target files, then hash and inventory each actual output.
