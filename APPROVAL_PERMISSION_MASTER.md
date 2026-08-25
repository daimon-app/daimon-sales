# AI5 / Codex Approval & Permission Master

Status: CANONICAL OWNER POLICY
Effective: 2026-08-26 JST
Repository: `daimon-app/daimon-sales`

## 1. Purpose

This document is the canonical policy for Owner approvals, permissions, continuation prompts, Codex command approvals, AI5 Owner Gates, and automatic execution. New chats, tasks, recovery flows, and Codex work must consult this policy rather than reconstructing approval rules from conversation history.

Priority remains: Owner's latest explicit instruction > this policy > other repository documentation > old conversations/evidence.

## 2. Default rule: normal technical work does not require Owner interruption

For ordinary reversible technical work that AI/Codex can safely execute within the authorized project scope:

- OWNER APPROVAL = NOT REQUIRED
- OWNER PERMISSION = NOT REQUIRED
- OWNER CONTINUE CONFIRMATION = NOT REQUIRED

Treat all of the following as Owner interruptions and avoid them for ordinary technical work: approval requests, permission requests, `Approve`, `Command approval`, `Approve for session`, `一度だけ許可`, continuation confirmation, execution confirmation, and access confirmation.

AI5/Codex should decide and continue automatically where the platform actually permits automation.

## 3. Normally AUTO_APPROVED / AUTO_PERMITTED

### Files and code
- Read project/repository files.
- Create/edit files within authorized project/workspace scope.
- Safe cleanup of generated/temporary files.
- Source/config changes that are reversible and within task scope.

### Development and terminal
- Build, test, lint, debug and dependency/package inspection.
- Project scripts and ordinary local commands.
- PowerShell/shell commands used for normal project work.

### Git and private GitHub
- `status`, `diff`, `fetch`, `pull`.
- Create/switch working branches.
- Commit approved-scope technical changes.
- Push to private GitHub within the authorized branch/scope.
- Read private repository metadata and evidence.

### AI5 infrastructure
- AI5 HUB operations.
- Result Bus read/write.
- Task dispatch and result recovery.
- Artifact Return, evidence generation, retry/recovery and AUTO_RESUME where acceptance criteria permit it.

### External AI work
- Ordinary task dispatch/result retrieval for Claude, Gemini and Manus using already-authorized routes.
- Read-only audits and cross-checks.

### Browser/network
- Navigation and ordinary operations in an already-authenticated session.
- Approved HTTPS destinations and localhost used by the project.
- Non-public drafts, safe upload/download and QA.

### Android / Pixel / ADB
Ordinary reversible QA and control operations are auto-permitted when the platform permits them, including verified `adb.exe` use such as:
- `adb shell input`
- `adb shell am`
- `adb shell dumpsys`
- read-only settings/package inspection
- safe project-scoped push/pull
- screenshots/evidence

Do not ask the Owner to approve routine ADB operations merely because they execute through a terminal.

### Sales preparation
- Draft creation and editing.
- Caption/metadata preparation.
- Upload preparation and private preview.
- Sales-page inspection and analytics inspection.
- QA and audits.

## 4. Owner Gates that remain

Owner interruption is reserved for operations where the Owner's identity, money, legal intent, public-release intent, or irreversible choice is intrinsically required.

### Identity
- Identity verification.
- OTP.
- CAPTCHA.
- Biometric authentication.

### Money
- New payment/purchase.
- New paid subscription or spend increase.
- Payment confirmation that creates a new financial commitment.

### Publication
- Public SNS/Store/production publication when no matching Owner Publish GO has already been granted.
- If the Owner has explicitly granted Publish GO for a defined scope, do not request the same approval again for that same scope unless the scope materially changes.

### High consequence
- Destructive or irreversible actions outside an already-approved reversible recovery plan.
- Legal consent requiring the Owner's personal assent.
- Entry/provision of a new secret that only the Owner can supply.

## 5. Owner Gate batching and isolation

- Batch genuine Owner Gates where practical instead of interrupting repeatedly.
- A `WAITING_OWNER` task blocks only its own lineage; unrelated tasks continue.
- Do not use “念のため”, technical uncertainty, or routine privilege boundaries as reasons to create an Owner Gate. First use safe alternatives, existing authorization, trusted workspace, allowlists/reusable permissions, or another automated route.

## 6. Critical distinction: AI5 policy vs Codex Desktop Command approval

AI5 Owner Gate policy and Codex Desktop/runtime `Command approval` are separate layers.

Observed Codex Desktop UI includes:
- `Approve`
- `Approve for session`
- `Decline`

Writing `AUTO_APPROVED` in GitHub does **not** by itself disable a Codex Desktop/runtime prompt. `Approve for session` is session-scoped and must not be reported as persistent authorization.

Therefore any recurring Codex Desktop command prompt must be diagnosed at its actual runtime source. Do not repeatedly rewrite this policy as a substitute for fixing runtime configuration.

## 7. Runtime permission / Permission Box rule

Where Codex Desktop/runtime officially supports persistent or reusable authorization, prefer scoped persistent authorization for normal technical work. Inspect the installed runtime for real supported mechanisms such as trusted workspace, executable/command allowlist, persistent/reusable permission, approval mode, sandbox configuration, filesystem scope, or network scope. Do not invent configuration names.

Priority candidates for trusted normal execution include the verified absolute executables/workspaces used by:
- PowerShell/pwsh
- Git
- GitHub CLI
- verified Android SDK `adb.exe`
- build/test tools
- AI5 project workspaces
- Result Bus/HUB workspaces
- approved localhost/private GitHub routes

Prefer a safe executable/command-family/workspace scope over a brittle one-command string when the product supports it. Do not open unrestricted OS-wide wildcards merely to suppress prompts.

## 8. Platform-enforced prompts

If Codex Desktop, Windows, Android, or an external service provides no supported way to remove a required prompt, classify it:

`UNAVOIDABLE_PLATFORM_GATE`

Do not claim that GitHub policy removed it. Do not repeatedly perform the same failed policy rewrite. Instead minimize interruptions using supported session approval, batching, trusted scopes, or safe alternate routes.

## 9. No fake PASS

None of the following alone proves approval/permission automation works:
- Updating Markdown/JSON.
- Writing `AUTO_APPROVED`.
- Creating an allowlist file.
- Committing/pushing this policy.
- Creating a scope token.

A runtime fix is PASS only after the Owner-facing prompt count is actually measured and reduced for the relevant workflow.

## 10. Required runtime verification

For a safe representative workflow, measure before and after:

PowerShell -> project file edit -> test -> Git diff -> commit -> private push -> ADB -> browser operation -> Result Bus write.

Record:
- `APPROVAL_PROMPTS_BEFORE`
- `PERMISSION_PROMPTS_BEFORE`
- `OWNER_ACTIONS_BEFORE`
- `APPROVAL_PROMPTS_AFTER`
- `PERMISSION_PROMPTS_AFTER`
- `OWNER_ACTIONS_AFTER`

Target for ordinary technical work: zero approval/permission prompts, or the minimum technically supported by the installed platform.

Repeat after Codex Desktop restart and in a new task. If prompts return after restart, persistent permission is not PASS.

## 11. Recovery / new chat rule

At the start of a new Codex/AI5 task or when context is unclear:
1. Read repository `MASTER.md`.
2. Read this `APPROVAL_PERMISSION_MASTER.md` before asking the Owner for routine approval/permission.
3. Inspect the actual prompt source before changing policy.
4. Preserve genuine Owner Gates in section 4.
5. Do not restart the approval-policy discussion from old chat memory.

## 12. Incident lessons made canonical

- AI5 Approval Policy alone did not eliminate Codex Desktop `Command approval` prompts.
- A routine YouTube/Pixel task using `adb.exe shell input text ...` was observed being blocked by Codex Desktop command approval; routine reversible ADB is intended to be auto-permitted where runtime capabilities allow it.
- `Approve for session` is not persistent authorization.
- The Owner's standing policy is that ordinary technical work should not request approval, permission, or continuation confirmation.
- Platform-enforced prompts and AI5 Owner Gates must be classified separately.
- If the same prompt recurs, diagnose its runtime source; do not create another duplicate policy document.

## 13. Status vocabulary

Use:
- `PASS`: actually executed and measured.
- `FAIL`: executed and failed.
- `PARTIAL`: some prompt classes removed, others remain.
- `UNSUPPORTED`: installed product/runtime has no supported persistent mechanism.
- `UNAVOIDABLE_PLATFORM_GATE`: Owner/platform action is technically mandatory.
- `NOT_VERIFIED`: not yet measured.

## 14. Completion condition

This canonical policy is complete as a specification when committed to GitHub. Runtime no-prompt operation is a separate implementation gate and must not be inferred from this document.

Runtime target:

`CODEX_NORMAL_TECHNICAL_APPROVAL_PROMPTS = 0`

`CODEX_NORMAL_TECHNICAL_PERMISSION_PROMPTS = 0`

subject only to documented `UNAVOIDABLE_PLATFORM_GATE`s.
