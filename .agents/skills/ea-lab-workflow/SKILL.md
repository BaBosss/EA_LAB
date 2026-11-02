---
name: ea-lab-workflow
description: Start, resume, hand off or take over EA_LAB work identically across ChatGPT, Codex, Gemini/Antigravity and Claude, using the canonical boot router, the Lane Registry and Core Seat Protocol v8.
---

# EA_LAB workflow (same for every provider)

This skill is a procedure summary. The canonical owners are `START_HERE.md`, `AGENTS.md`, `PROJECT_STATE.md`,
`docs/workflows/CORE_SEAT_PROTOCOL_V8_20261102.md` and the VERDICT GATE in `CLAUDE.md`. Where this skill
differs from them, they win.

## Start
1. **Pin one canonical SHA.** Record one exact `origin/master` SHA and read every policy file from that SHA
   (`git show <SHA>:<path>`). Fetch only when the session permits Git mutation.
2. **Read in order:** `START_HERE.md`, `PROJECT_STATE.md`, `AGENTS.md`, then the exact assigned task.
3. **Confirm your assignment.** It comes from the owner or an approved contract, and names a role: author,
   reviewer, batch or seat. Without it you are `ROLE_UNVERIFIED_READ_ONLY`.

## Write
4. **Claim a lane.** Use `scripts/lane_registry.ps1 -Command Claim`, with a worktree cut from `origin/master` and
   explicit allowed and critical paths. The registry refuses overlapping writers; treat a refusal as a stop, not as
   something to route around.
5. **Run the gates.** Use the repository's own gates (pre-commit check_state and fast-cages; compile and
   `tpl_regression` for core). A fresh worktree may need `Assert-PortablePython -Provision` first (`START_HERE.md`
   §9).
6. **Report in five dimensions:** execution, evidence, acceptance, integration and runtime. Any dimension may be
   `UNKNOWN` or `NOT_APPLICABLE`. Never write just "done".

## Review and integrate
7. **Review.** The reviewer is never the author. It freezes the exact head and writes a new record; it never edits
   an earlier verdict. The different-family gates in `docs/PIPELINE.md` rows 3 and 9 still apply.
8. **Integrate.** Only the Seat integrates into `origin/master`, by fast-forward, and then verifies the remote SHA.

## Interruption / quota loss / takeover (protocol §A1/§A4/§A4a)
- **The agent that stops:**
  - commits only if its contract and gates permit, and otherwise preserves its WIP;
  - pushes a lane branch only if the contract permits;
  - never pushes canonical.
- **The successor:**
  - may read first;
  - before writing, proves the exact source SHA, the contract and lease, that no in-flight job is running on the
    same slice, and the accepted evidence it relies on.
  - A handoff file is information, not authorization.
- **Batch runs:** automatic batch resume is unavailable on canonical until R4 is integrated. A new state
  directory bypasses nothing.

## Never
- Reset, clean, stash or force-push.
- Write in the primary checkout `D:\EA_LAB`.
- Treat TEMP or a chat as evidence custody.
- Print secrets.
- Attach, promote or change real-money state. That is owner-only.
