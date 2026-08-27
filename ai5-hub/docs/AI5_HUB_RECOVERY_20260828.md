# AI5 HUB recovery evidence — 2026-08-28

## Measured outcome

- Local session: PASS (`127.0.0.1:43125`)
- Local health: PASS
- Private Result Bus checkout: PASS, clean clone at remote HEAD `638297f1d2d158cd919e5e3af02372e819cae1a0`
- HUB Result Bus configuration: `remote_enabled=true`, `remote_visibility=PRIVATE`
- Safe local PNG attachment: PASS, 68 bytes, HTTP 201
- Tailscale client: installed from the official Winget package, version 1.102.3
- Tailscale identity: `NeedsLogin`; no existing credential was found
- Tailscale Serve: not active; Funnel was not enabled
- Pixel route: OFFLINE
- AI5 fresh external E2E: not run because Claude API, Gemini API, Mail Manus and Pixel private route are not currently connected

## Correct status semantics

The Command Center no longer returns `PC=ONLINE` merely because the localhost HUB and Codex CLI are reachable. It returns:

- `ONLINE` only when the private remote route is verified active
- `LOCAL_ONLY` when localhost/Bridge are available but the Pixel route is unavailable
- `OFFLINE` when the local Bridge is unavailable

`pixelRoute` is reported independently. A stale task, a CLI binary, or an old Result Bus receipt does not establish a live AI.

## Blocker

The remaining boundary is Tailscale identity authentication. This is an actual identity gate, not a speculative gate. Until authentication completes and `tailscale serve status` proves a tailnet-only HTTPS route, Pixel must continue to show offline and AI5 ACTIVE 5/5 must not be claimed.

## Test evidence

- Command Center unit test: PASS
- Attachment unit test: PASS
- Local attachment HTTP E2E: PASS
- Full test suite: stopped at Phase3 GitHub Bus E2E because the test fixture expects degraded/no-remote mode while this runtime is intentionally configured to a verified private remote. Earlier unit/security suites passed.
