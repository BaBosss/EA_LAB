# CODEX TASK — ORDER-105 (Contract D) PRE-BUILD DESIGN REVIEW (rework0)

You are an independent peer engineer reviewing an implementation ORDER **before any code is built**, in repo **D:\EA_LAB** (Windows, PowerShell 5.1 via `powershell.exe`, plus git-bash). Use plain, neutral engineering language throughout (frame everything as correctness/robustness/consistency verification).

**Do NOT write any implementation code, do NOT commit, amend, reset, rebase, or push anything, and do NOT edit any file except the single deliverable file named below.** The shared working tree may contain unrelated concurrent edits from other sessions — expected; ignore and preserve them.

## Why this review exists

For the previous order in this workstream (ORDER-103), a design review before build caught 8 real gaps (5 of which would have made the build unsound) at a fraction of the cost of catching them after. This is the same step for ORDER-105. Your job: find every way this order, as written, would produce a wrong, unsound, or unbuildable implementation — and every decision it leaves open that the builder would have to guess.

## What to read (in this order)

1. `AGENT_TASKBOARD.md` — block `## ORDER-105` (the order under review; near end of file).
2. Design source of truth: `git show 4eb839d:_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md` — **§20.8 "Contract D — MVP-1-lite events", §20.7 "Artifact ownership and write contracts"** (the JSONL append-utility requirements paragraph at the end of §20.7 is binding), and the MVP-1 event-type/field spec at lines 274-300 of that file. Also skim §20.3 locked operating defaults, §20.5 (decisions delegated to Claude/Codex under orders), §20.9 (review checklist).
3. `docs/memory_control/CONTRACT_D_HANDOFF.md` — operational context, iron rules, and out-of-scope list.
4. Existing enforcement machinery this must coexist with: `scripts/check_taskboard_archive.ps1`, `scripts/check_precommit_staged.ps1`, `.githooks/pre-commit` (protected-set of 5 files; a new event-log file is NOT in that set — think about whether it needs analogous protection or explicitly not, and what the order says).
5. Existing negTest style: `scripts/_test/run_order103_negative_tests.ps1` (temp-repo pattern, try/finally cleanup).

## Review dimensions (cover all; add your own)

1. **Buildability / completeness** — Can a builder implement this order without guessing? Enumerate every unpinned decision: JSONL file location + naming (monthly rotation scheme), event ID format + uniqueness scope, experiment ID format, hash algorithm + encoding for the EA/source/set/data/tester hashes, actor/role vocabulary, timestamp format + timezone, chain-link semantics (what exactly does `prior event` point to — event ID? hash? both?), what "idempotency" keys on (full-event hash? event ID?), lock mechanism that actually works on Windows PS 5.1 (file-based lock? `[System.IO.File]::Open` exclusive? retry policy?), atomic-append mechanics on NTFS, schema definition format (where does the schema live, how is it versioned), manifest file location/format, and what `RESULT_LINKED`/`REVIEW_LINKED`/`DECISION_LINKED` carry vs `RESULT_ATTACHED`/`REVIEW_RECORDED`/`DECISION_SIGNED` (the order lists both families — is that a contradiction or a layering? §20.7 mandates the *_LINKED family; say which the schema should contain and why).
2. **Acceptance-test soundness** — For each of the 7 numeric acceptance criteria in the order: is it machine-checkable as written, is it sufficient, and what failure mode does it miss? Specifically scrutinize: does the concurrent-write test as specified actually force lock contention on Windows (or can it trivially pass with serialized writers)? Is "byte-identical after rejected append" testable without a race window? Does the corrupt-line criterion conflict with append-only correction (utility refuses appends until amendment — but the amendment itself is an append; is that a deadlock as specified)? What negTests are missing entirely (e.g. rotation-boundary event chains spanning two monthly files, crash-mid-append recovery, clock skew / same-timestamp events, duplicate experiment IDs, schema-version migration)?
3. **Ownership / §20.7 compliance** — Could an implementation that satisfies this order still create a second source of truth (e.g. by storing verdict-like strings in `reason`, or storing enough metadata that a reader could reconstruct verdicts without the canonical owner)? Is the "occurrence metadata + hashes + references only" rule enforceable by schema (field whitelist + length limits?) or only by convention? The order should make it schema-enforced — does it?
4. **Interaction with existing machinery** — The repo has a fail-closed pre-commit hook over a 5-file protected set and an append-chain validator for the archive. Does adding a new append-only JSONL (tracked? untracked?) interact with `check_state.ps1 -Strict`, the hook, or `-Generate` artifacts? Should the event log be git-tracked (giving free tamper-evidence via the existing philosophy) or runtime-only? What does the order say, and is it right? Monthly rotation vs git history: any conflict?
5. **Rollback & failure realism** — Is the rollback path ("disable append utility, rebuild from canonical refs") actually executable given the design? What happens to in-flight experiments mid-rollback? Is tombstone semantics specified enough to implement?
6. **Scope creep check (§20.9 #1 + #5)** — Does the order stay a bounded, self-contained order (one build, acceptance, rollback), referencing only §20-sanctioned requirements? Flag anything it imports beyond §20, and anything from §20.8 Contract D it silently drops.

## Deliverable

Write your full review to a NEW file: `docs/memory_control/CODEX_ORDER105_DESIGNREVIEW.md`. Structure: (a) summary table of findings, each tagged BLOCKER / MAJOR / MINOR with a one-line fix; (b) detailed findings with the exact order/spec text they refer to; (c) a "decisions the builder needs pinned" list with your single recommended value for each (the lead engineer will approve/override — recommend, do not defer); (d) the missing-negTest list. End with exactly one line:

`DESIGN VERDICT: BUILD-READY` — if the order can be built as written with no blocking gaps,
or `DESIGN VERDICT: NEEDS-CHANGES(<n>)` — where n = count of BLOCKER+MAJOR findings.
