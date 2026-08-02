# HANDOFF — slice **S9** CLOSED: the recoverable, idempotent scheduler

> Lane `S-2026-08-02-S9SCHED` · `ORDER-1080` DONE · commits `15b625af` (the slice) and
> `495de787` (the wiring proof and what it cost). Design §6.5 / §3.3 = §20.8 Contract B.

---

## What exists now

| file | what it is |
|---|---|
| `_triage/factory_os/scheduler.py` | **PURE.** The monotonic transition validator (S1–S9), the resume planner, the idempotency gate, the cross-lane refusal. No clock, no process, no terminal. |
| `_triage/factory_os/run_scheduler_tests.py` | The cage. 256-resume kill matrix + 46 attacks, every one RED-first. |
| `scripts/scheduler_run.ps1` | The dispatcher. Observes, dispatches, appends. **Decides nothing.** Includes its own `-WorkerMode` re-invocation, which owns exactly one tester run. |
| `scripts/_test/run_scheduler_tests.ps1` | Fast-tier wrapper. Fails if the matrix silently shrank. |
| `factory/runs/<run_id>.jsonl` | The store. One `RunTransition` per line, append-only. `RunJournal` is derived and never written. |
| `factory/leases/<lane>.json` | Live lane state (gitignored). |

Per-attempt recovery state — `*.spawn.json`, `*.exit.json`, `*.worker.*.log` — is on disk and
**gitignored**: it must survive this machine's crash, not survive into history.

## The four acceptance criteria, and how each was shown

1. **Kill at every state.** Enumerated: every (action × phase) × 2 resume delays × 4 scenarios =
   **256 recoveries**. The roll-up **refuses to pass** unless all nine §3.3 transitions were killed
   on *both* sides of their own append. Invariants are **measured** by the stub world (`launches`,
   `max_live`, `event_appends`), not asserted from the planner's own account of itself.
2. **`COMPLETED` refused without a fresh report.** Refusal `S6` in the validator, so no future
   caller can reach `COMPLETED` by another route. Four attacks: no proof · `fresh=false` ·
   runner exit 1 · a report older than the run claiming to have written it. The dispatcher gets its
   verdict from the shared `Test-ReportIsFresh` (`run_report_freshness_tests` PART 5 confirms it).
3. **Identical re-run refused, cached evidence returned.** `execution_key_digest()` over the 15
   contract fields; six one-field probes prove a run differing only in `deposit`, `leverage`,
   `currency`, `data_fingerprint`, `lane` or `effective_config_hash` is **not** served the cache.
   **Proven live:** re-queueing the proof run's key was refused and returned
   `evd_sha256_90c1f032…`.
4. **Cross-lane refused; `LEASED` refused without a free lease.** `refuse_cross_lane()` plus the
   lease reconcile. **`LANE_BUSY` fired live** (run 002 refused while 001 held lane 1). The
   cross-lane *refusal* is proven by the cage only — a second install was not spent re-proving
   `ORDER-371`.

## The wiring proof (lane 1, `D:\Meta 5` · XAUUSD H1 · 2024.01.02–16 · Model 1)

`RUN-20260802-002`: QUEUED → LEASED → LAUNCH_INTENT → PROCESS_OBSERVED → COMPLETED →
EVIDENCE_REGISTERED. The driver was **stopped mid-flight** (`-MaxIterations 5` — nothing was
killed) while the worker held the tester. The resume found the exit sidecar, gated it, and recorded
`COMPLETED`. **One launch, zero relaunches, one event.** Evidence:
`docs/memory_control/evidence/ORDER1080/S9WIRE_002.htm`, registered through the existing utility
into the existing manifest.

## Seven defects, and which half found each

**The enumeration found three** — none reachable by a two-state sample:
1. `LAUNCH_INTENT` + nothing running + no exit record has **two causes**; both answered `LAUNCH`,
   so a dead attempt was **relaunched in place**, invisible in the manifest and unbounded by the
   attempt cap. Closed with a per-attempt **spawn marker written before the spawn**.
2. Observations were per-**run**, so attempt 2 opened while attempt 1's exit record was visible.
3. The RED probe was **inert**: the injected defect stops the loop converging, and the probe caught
   the exception and skipped its own counter check.

**Running it once for real found four more, all in the dispatcher** — the planner was right every
time, which is the only reason they were legible:
4. `Start-Process -ArgumentList` joins with spaces and quotes nothing → `D:\Meta 5` split in two,
   the worker died before its sidecar, three attempts went `RECONCILE_ORPHAN(KILLED)`.
5. **A finished run never gave the lane back.** Run 001 held lane 1 for the four hours to expiry.
   New planner action `RELEASE_LEASE` — in the *planner*, because "am I finished and is this lease
   mine" is exactly the question that grows a second state machine in a driver. Written expired,
   never deleted.
6. **Decision 18 names two categories, not two enum members** — see the owner note below.
7. The evidence step could not report its own refusal, for three separate reasons: wrong parameter
   names, a media type outside the schema enum, and a message that **guessed** a cause it had not
   checked. The event utility prints through `[Console]::Out.WriteLine`, which **bypasses every
   PowerShell stream** — worse than the Write-Host/stream-6 trap, since `2>&1 6>&1` misses it too.
   It is capturable only as a child process.

## ⚠️ Owed to the owner — one interpretation, one open field

**(a) The decision-18 mapping.** Read as the literal pair (`TESTER_ERROR`, `TERMINAL_ERROR`), a
machine crash gives `FAILED(KILLED)` and that configuration can **never be queued again**. The
decision's own remedy is the tell: *"otherwise return the cached evidence"* cannot apply where there
is no evidence. The mapping now in code:

| category | classes |
|---|---|
| tester error | `TESTER_ERROR` |
| execution error | `TERMINAL_ERROR` · `TIMEOUT` · `KILLED` · `LEASE_LOST` |
| neither (stays blocked) | `CONFIG_REJECTED` — a fact about the configuration |

Overrule it and only `RETRYABLE_FOR_NEW_RUN` changes.

**(b) `ExecutionKey.ini_hash` is not knowable when the key is needed.** The ini is written *by the
runner*, but the key is what gates whether the run may happen at all — the same shape `schemas.json`
already fixed one level up when it removed `pid` from the lease. For the proof it was seeded from a
canonical rendering of the same fields. Either an **ExecutionKey builder** renders the ini itself
(moving that responsibility out of `mt5_run.ps1`), or the field is redefined. **S10 depends on this
being settled**, because a Candidate pins the run it came from.

## Next session — S10, and what to check first

- **Baseline green:** `run_scheduler_tests.py` · `check_param_surface.py --worktree` ·
  `check_wrapper_gen.py --worktree` · `run_parity_tests.py` · `run_guard_shape_lint.py`.
- **Delete `_triage/factory_os/__pycache__`** before any generator run (the S7/S8 `.pyc` lesson).
- **Re-derive the order block from BOTH tests** — every `## ORDER-<n>` in all four board files *and*
  every reserved block in `docs/SESSION_LEDGER.md`. Highest reserved as of this writing: `1080-1089`.
- Settle **(b)** above before building S10's Candidate identity.
- The scheduler's `EVIDENCE_REGISTERED` step needs a **committed** artifact
  (`_mt5_auto/reports/` is gitignored, `.gitignore:70`). Point `-EvidencePath` at the committed copy.
  A run that stalls there is not stuck: re-invoking the driver resumes at `REGISTER_EVIDENCE`, which
  is what the manifest is for.

**Not done in this session, deliberately:** no EA verdict · no B1 row · no `.set` migrated · no
second Boss converted · no S10 started · `mt5_run.ps1` and `mt5_optimize.ps1` untouched.

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| S9: the scheduler, its cage, the dispatcher, and the seven defects | ORDER-1080 (DONE) |
| the decision-18 category mapping (an interpretation of a user-owned decision) | ORDER-1080 (owner) |
| `ExecutionKey.ini_hash` is not knowable when the key is needed | ORDER-1080 (owner) — **S10 is blocked on it** |
| cross-lane comparison proven by the cage only, never on a second install | ORDER-1080 (accepted: `ORDER-371` already measured it) |
| `EVIDENCE_REGISTERED` needs a committed artifact, so a report under `_mt5_auto/reports/` can never register | ORDER-1080 (DONE — `-EvidencePath` points at the committed copy) |
| S10 Candidate identity + append-only Deployment attestation | design §10 S10 row (not started) |
