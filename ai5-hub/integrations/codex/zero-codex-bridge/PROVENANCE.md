# Bridge provenance

This integration preserves the tested Zero-Codex Direct Bridge from commit
`09632f5 feat: add Zero-Codex direct bridge MVP`.

Preserved behavior: official `codex exec --json`, existing Codex authentication,
queue/results/logs, task ID duplicate protection, worker lock, secret redaction,
workspace write boundary, bounded retries, and success/failed results.

Phase 2 adds the common evidence fields required by AI5 HUB and an enforced
execution timeout. Runtime data and the generated config remain Git-ignored.
