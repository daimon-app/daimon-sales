# AI5 HUB Interactive ACK / Result Return Evidence

- Date: 2026-08-31 JST
- Runtime: `v67-26d52ca`
- Canonical HEAD: `26d52ca0060605bc011613a9bee503b9110fc583`
- Live task: `AI5-20260831-0003`
- Result: `AI5-20260831-0003-v2`
- Mode: live (`mock=false`)

## Root cause

The Android PWA had persisted an empty Project selection. `refreshProjects()` preserved the empty value, and the submit handler stopped before `POST /api/tasks`. This produced no task ID, ACK, routing, worker execution, or returned result even though non-interactive automation remained operational.

The fix restores the registered canonical `ai5-hub` Project when the stored selection is empty or invalid, persists that recovery, and advances the application and Service Worker cache generation.

## Live trace

| Hop | Status | Evidence |
| --- | --- | --- |
| HUB submit | PASS | 2026-08-31T11:04:33.2334328Z |
| Task ID generation | PASS | `AI5-20260831-0003` |
| Task / queue registration | PASS | RECEIVED at 2026-08-31T11:04:34.06295Z |
| Router receipt | PASS | PLAN / assigned `codex` |
| Worker lease / claim | PASS | CLAIMED at 2026-08-31T11:04:42.4200113Z |
| Codex receipt | PASS | execution started at 2026-08-31T11:04:42.4456815Z |
| Immediate submit ACK | PASS | POST returned the task ID in 7010 ms; frontend immediate ACK contract is covered by `InteractiveAck.Tests.ps1` |
| ACK / task publication | PASS | GitHub Result Loop task file uses the same task ID |
| Progress return | PASS | CLAIMED, planning, running timeline states |
| Final result | PASS | RESULT_RECEIVED at 2026-08-31T11:06:28.2065756Z |
| Receipt | PASS | decision PASS for result `AI5-20260831-0003-v2` |
| Result Bus save | PASS | task, result, receipt, and inbox artifacts exist |
| HUB polling contract | PASS | active task 2500 ms; LINE CHAT 5000 ms |
| HUB UI data | PASS | `/api/chat` returns Codex report, Zero decision, and GitHub result for the same task ID |
| Android visual refresh | UNVERIFIED | Tailscale HTTPS serves v67 HTML/JS and the new Service Worker; no ADB device was connected for final on-screen inspection |

## Result

Codex returned: `AI5 HUB INTERACTIVE ACK PASS — Runtime health is healthy and live.`

The Result Bus task ID, result task ID, receipt task ID, and LINE CHAT task ID all match. The former Stable `v66-4114cd9` remains available as the rollback point.

