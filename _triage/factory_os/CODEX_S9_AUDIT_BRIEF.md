# Codex blind audit brief — Factory OS slice **S9** (recoverable, idempotent scheduler)

> Written 2026-08-03 by lane `S-2026-08-03-AUDITCOV`. **You are the independent brain.**
>
> This slice's built code has **never been independently audited**. Nothing here tells you what any
> previous session concluded, deliberately. Attack the claims; do not restate them.

---

## 0. Read at a PINNED commit · READ-ONLY

```bash
git show a87f7448:<path>
```

Do not edit, create, stage or commit anything. Do not run any command that writes to `factory/`,
`_mt5_auto/`, or `.git/`. **Do not launch an MT5 terminal or a backtest** — this slice's driver can,
and the lane it would take is a single contended resource. The read-only python cages in §6 are
fine. Your deliverable is a report on stdout.

## 1. What you are auditing, in one sentence

The one thing a backtest runner cannot own for itself: **memory across its own death.** An
append-only transition journal, a pure `plan()` that answers *"given this manifest and these
observations, what is the single next action?"*, and a PowerShell driver that is meant to be a
switch with no decisions of its own.

**The stake.** Design §10's acceptance is *"kill at **every** state ⇒ resume re-runs zero completed
attempts, double-launches nothing, duplicates no event."* Get it wrong in one direction and two
terminals run the same cell on one lane, which corrupts the evidence every later verdict rests on.
Get it wrong in the other and a resume silently returns **cached** evidence for a configuration
that is not the one being asked about — a wrong answer that looks like a fast one.

## 2. Read these, in this order

| | |
|---|---|
| `_triage/EA_LAB_FACTORY_OS_DESIGN.md` | **§3.3** (run/recovery state machine) · **§6.5** (recoverable idempotent scheduler) · **§6.4** (lane affinity + data fingerprint) · **§10** the **S9** row |
| `_triage/factory_os/CONTRACTS.md` | `RunTransition` · `RunJournal` · `ExecutionKey` · `LaneLease` |
| `AGENTS.md` | **§3.2** — lane affinity, and why an evidence comparison across installs is refused |
| `AGENT_TASKBOARD.md` | row **`ORDER-1080`** — the order this slice was built under |

## 3. The artifacts

| file | what it decides |
|---|---|
| `_triage/factory_os/scheduler.py` | `fold()` · `validate_transition()` · `plan()` · `execution_key_digest()` · `find_cached()` · `refuse_cross_lane()` · `canonical()` / `normalize_numbers()` |
| `scripts/scheduler_run.ps1` | the driver — observes, dispatches, records. Claimed to hold **no** decisions |
| `_triage/factory_os/run_scheduler_tests.py` | the cage, including the enumerated kill-at-every-state matrix |
| `factory/runs/**` · `factory/leases/**` | the live stores |

⚠️ `scheduler.canonical()` and `scheduler.normalize_numbers()` are **imported by other slices** as
the project's only canonical serializer. A defect there is not local to S9.

## 4. The claims — refute these

| # | claim | where |
|---|---|---|
| C1 | kill at **every** state in §3.3 resumes correctly — zero completed attempts re-run, nothing double-launched, no event duplicated | `plan()` + the cage's matrix |
| C2 | `COMPLETED` is **refused without a fresh report** | `validate_transition` **S6**, `classify_outcome()` |
| C3 | an identical `(config, lane, fingerprint)` re-run is **refused** and cached evidence returned instead | `execution_key_digest()`, `find_cached()`, `queue_decision()` |
| C4 | **cross-lane comparison is refused**, and `LEASED` is refused without a free lane lease | `refuse_cross_lane()`, `lease_is_free()` |
| C5 | the store is **append-only and never rewritten** — one `RunTransition` per line; `RunJournal` is **derived** by folding and is never written | the DISK section |
| C6 | **the driver holds no decisions** — `plan()` returns a closed-set ACTION and the PowerShell side is a switch with no branch of its own, asserted by the cage so a tenth action fails a test rather than stalling a run | `ACTIONS`, `run_scheduler_tests.py` |
| C7 | every decision in the file is **pure** — nothing reads a clock (`obs['now']` is the only one), spawns a process, or touches a terminal, except the thin disk section | the whole module |
| C8 | `normalize_numbers()` collapses an integral float at **any depth**, because `10000` vs `10000.0` once produced two `ExecutionKey` digests for one deposit | `normalize_numbers()`, `execution_key_digest()` |

## 5. Where to aim

1. **C1 is the claim most likely to be *narrower than it sounds*.** The matrix enumerates kills at
   states. Does it enumerate kills at the **transitions between** them — after the process is
   spawned but before `LAUNCH_INTENT` is written, after the report lands but before `COMPLETED`,
   after the lease is acquired but before it is recorded? Those are the windows a crash actually
   lands in. Which of them are covered, and which are asserted?
2. **`LEGACY_DROPPED_KEY_FIELDS = ('ini_hash',)`.** A field was removed from the execution key.
   Two runs that differ only in a dropped field now share a digest and C3 will serve one as the
   other's cache. Is that sound, and is the reason for the drop written down anywhere checkable?
3. **`find_cached()` is the dangerous direction.** Enumerate everything that can differ between two
   runs and *not* move `execution_key_digest`. Data fingerprint, lane, terminal build, `.set`
   contents, deposit currency, leverage, tick model. Design §6.4 pins lane affinity — is the lane
   actually **in** the key, or only checked separately by `refuse_cross_lane()`?
4. **Lease reconciliation under a lost lease.** `LEASE_LOST` is in `RETRYABLE_FOR_NEW_RUN` but not
   in `RETRYABLE_IN_RUN`. Construct the sequence where a lease is lost, adopted by a second run,
   and then the first process — still alive — writes. What stops it?
5. **`MAX_ATTEMPTS = 3` and `ATTEMPTS_EXHAUSTED`.** Is the counter derived from the folded journal,
   or from a field that a resume can reset? A retry counter that resets on resume is not a limit.
6. **`SUCCESSORS` as the whole ordering rule.** Does `validate_transition` enforce it against the
   **folded tail**, or against the last physical line? A journal with out-of-order `at` timestamps,
   a duplicate line, or a partially-written final line are all reachable after a kill.
7. **C5's append-only claim.** `attestation.py` and `magic.py` make the same claim by the same
   argument — *the absence of a function that could break it.* Verify it here independently:
   is there any path, including the CLI and any caller, that opens a manifest for anything but
   append?
8. **C7's purity.** Grep for what the docstring says is absent. A prior round already corrected an
   overstatement in this same paragraph, so treat the paragraph as a claim, not as documentation.
9. **C6's "no branch of its own".** Read `scripts/scheduler_run.ps1` against `ACTIONS`. Does the
   switch have a `default`, and if so what does it do? A default that logs and continues is a
   decision. Does the assertion that binds the two actually parse the PowerShell, or does it match
   a comment?
10. **Refusal codes as evidence.** `REFUSAL_CODES` has seven entries. For each, construct the input
    that produces it. Any code that cannot be produced is dead vocabulary — and any refusal path
    that returns a code *not* in the set is worse.

## 6. How to reproduce

```bash
tools/python312/python.exe _triage/factory_os/run_scheduler_tests.py
```
```bash
tools/python312/python.exe _triage/factory_os/scheduler.py --self-test
```

⚠️ Two suites unrelated to S9 (`run_s2a_gate` F2, `check_coverage_transfer` A8) are **known red at
this pin** for a reason already recorded elsewhere. Not your finding.

## 7. What a finding must contain

`file:line` · the **kill point, call order or input** that exposes it · the consequence stated as
either *what gets double-run* or *what stale evidence gets served as fresh* · and a reproducing
command where you can produce one. Label an unreproduced finding a hypothesis and file it anyway.

Rank by severity, and keep **"this double-runs"** separate from **"this serves the wrong cache"**.
