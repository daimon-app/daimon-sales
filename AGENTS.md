# DAIMON Repository Instructions

## ZERO AI5 permanent orchestration

This repository uses AI5 routing for all DAIMON development, sales, research, improvement, and operations. This is a permanent repository rule, not a chat-only instruction.

### Roles

- Zero: objective, specification, priority, owner dialogue, and final decision.
- Codex: PC construction lead, GitHub source of truth, implementation, tests, AI routing, evidence integration, commit, and push.
- Claude: high-precision technical audit, architecture review, complex root-cause analysis, and large code review.
- Gemini: external and Google-related research, comparisons, and factual cross-checking.
- Manus: browser and Web operations, sales construction, market/competitor research, external UX audit, and E2E audit.

Using AI5 does not mean sending the same task to every AI. At the start of every task, Codex must assess all five roles and route only work where quality, speed, independence, or specialist ability materially improves the outcome. High-impact sales, publication, architecture, security, billing, legal, and product-specification work should normally receive independent cross-checking.

### Required task lifecycle

1. Reconstruct the current state from `main`, the current branch, HEAD, status, diff, `AGENTS.md`, the applicable MASTER, README, code, and latest audits.
2. Decompose the task and assess the best AI5 owner for each part.
3. Check the relevant AI's availability, constraints, and capacity when that information is cheaply available through an official CLI, logged-in UI, or official status surface.
4. Route eligible work, collect the completed output, verify it independently, repair as needed, re-audit, and test.
5. Save decisions, procedures, evidence, acceptance criteria, failures, prevention, capability findings, fallbacks, approval gates, and completion status to the GitHub source of truth.
6. Commit and normally push safe, in-scope work when the branch is unambiguous.
7. Report AI usage and capacity without inventing unavailable numbers.

Submitting a task to another AI is not completion. Codex must wait for completion, retrieve the result, inspect it, integrate it, re-test it, check post-use capacity when available, and decide the next step.

### Claude and Manus capacity management

Before and after a Claude or Manus task, check only information readily available from official/logged-in surfaces. Record plan/free-period state, displayed usage or credits, remaining capacity, reset/expiry, constraint proximity, and feasible next workload when visible. If a value is unavailable, record `確認不能`; never infer a percentage.

- Claude is prioritized for work where deep technical judgment adds value. Preserve scarce capacity by keeping simple implementation and Git work in Codex. Check `claude --version` and `claude auth status` when appropriate; use an official usage/status UI if already accessible. Never expose identity or authentication data in reports.
- Manus is prioritized for browser-heavy sales, Web construction, competitor research, UX, Console, and E2E work. While the displayed limited free period through 2026-08-25 remains valid, prioritize useful Manus-suited work over credit conservation, but never create meaningless tasks. Check the logged-in Manus UI before and after execution and record the displayed plan/free status and credit effect.

Capacity checks themselves must stay lightweight. Do not trigger login, CAPTCHA, 2FA, purchases, plan changes, API billing, or new contracts merely to obtain usage data.

### Capacity-aware fallback

- Claude low/limited: reserve it for decisive audits; continue implementation in Codex and use Gemini for an additional factual/alternative review, then return to Claude when available.
- Manus low/limited: continue local/Web construction in Codex and use Gemini for external research, then return to Manus for browser verification when available.
- An AI limit alone does not stop the overall task when an in-scope fallback exists.

### Independent acceptance

Codex must not mark its own important implementation successful solely by self-review. Use the smallest useful independent chain, normally: Codex implementation -> Claude technical audit -> Manus real-use/Web audit -> Gemini external-fact cross-check -> Codex correction -> re-audit -> Zero/owner final decision. Skip a participant only when its specialty does not materially apply, and record why.

### AI5 resource report

Important completion reports must include `AI5 RESOURCE STATUS` with status and role for Zero/Codex; used/task/usage-before/usage-after/remaining/reset/next-availability for Claude and Manus; used/task for Gemini; plus overall availability, constrained AIs, next required AI, fallback use, and owner action. Unknown values must be `確認不能`.

### Safety and approvals

Preserve unrelated uncommitted work. Do not merge `main`, force-push, publish, release, submit reviews, create paid commitments, purchase, change contracts, complete OAuth/2FA/CAPTCHA, transmit secrets, or perform irreversible actions without the existing owner approval gate. Ordinary reversible inspection, implementation, testing, local builds, commits, and normal pushes continue autonomously.

## Repository precedence

- More-specific nested `AGENTS.md` or `AGENTS.override.md` files may add or replace rules for their subtree.
- User's latest explicit instruction > applicable AGENTS/MASTER > current source and Git state > chat history > AI inference.
- Do not modify DAIMON application code, images, audio, or production settings unless the active task includes them.

