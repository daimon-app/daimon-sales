# AI5 Artifact Return

## Current evidence

- Claude reported `ai5-p0.zip`, but no file object, file ID, local attachment, private GitHub object or Result Bus artifact was delivered.
- `CHAT_ARTIFACT_TRANSPORT = NOT_WIRED`.
- The reported 46/46 and 20 concurrency repetitions remain `UNVERIFIED` until Codex receives and reruns the bytes.

## Canonical return path

`AI OUTPUT → ARTIFACT MANIFEST → RESULT BUS or private GitHub → CODEX VERIFY → AI5 HUB`

Every artifact requires Task ID, Correlation ID, Artifact ID, filename, byte count, SHA-256, media type, source agent and return route. Registration is create-only on the composite identity and SHA-256, so repeated delivery cannot trigger duplicate construction.

ZIP intake verifies declared size and SHA-256 before registration, rejects absolute paths and traversal entries, enforces entry/uncompressed-size/ratio limits, and stores a receipt separately from the immutable bytes. Clean extraction and product-specific tests occur only after intake PASS.

Secrets, dedicated addresses and credentials must not be embedded in manifests or evidence. Chat text is never accepted as proof that artifact bytes were delivered.
