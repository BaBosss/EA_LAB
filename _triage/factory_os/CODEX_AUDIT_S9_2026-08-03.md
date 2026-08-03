# Codex blind audit — Factory OS slice **S9** (recoverable, idempotent scheduler) — 2026-08-03

> Dispatched by lane `S-2026-08-03-AUDITCOV`, **pinned at `a87f7448`**, blind and read-only.
> Brief: [`CODEX_S9_AUDIT_BRIEF.md`](CODEX_S9_AUDIT_BRIEF.md), committed at `1d225d4b` **before** the
> audit ran. First independent audit of this slice's built code.
>
> Verified items were re-measured by this seat. Items Codex explicitly labelled hypotheses — because
> reproducing them needs writable temp files, a worker launch, or an MT5 run, all of which the brief
> prohibited — are kept in Part 2 **as hypotheses**, not demoted and not promoted.

**Codex's headline: C1–C4 are refuted.** Those are the slice's four acceptance criteria.

---

## Part 1 — VERIFIED

### 1.1 🟠 HIGH — the `ExecutionKey` is digest-bearing for fields the driver never sends

`scheduler.py:81` · `scripts/mt5_run.ps1` · `scripts/scheduler_run.ps1`

**Measured:**

```
EXECUTION_KEY_FIELDS = (expert, symbol, tf, from_date, to_date, model, deposit,
                        currency, leverage, set_hash, ex5_hash,
                        effective_config_hash, data_fingerprint, lane)

currency in the key?              True
scheduler_run.ps1 mentions currency?   0 hits
mt5_run.ps1:                      "Currency=USD"        <- hardcoded
mt5_run.ps1:                      [int]$Deposit = 10000 <- integer-coerced
```

`currency` is hashed into the cache identity and **is never passed to the runner**, which hardcodes
`USD`. `deposit` is contractually a *number* and hashes distinctly, and the driver coerces it to
`[int]`.

**Consequence.** A later request for `currency=EUR`, or for `deposit=10000.5`, produces a **distinct
digest** and will be answered — via `find_cached()` — with evidence actually produced under `USD` at
a rounded deposit. The key is more discriminating than the execution, which is the failure direction
that returns a *wrong* answer rather than a *slow* one.

### 1.2 🟡 MEDIUM — terminal build is in no identity

`scheduler.py:81` — **measured**: no field in `EXECUTION_KEY_FIELDS` contains `build`, and design
§6.4's data fingerprint does not carry one either.

**Consequence.** Update MT5 in place, keep lane, data fingerprint, binary and configuration, and
evidence produced under the old build is served as fresh for a request executed under the new one.
This repo already holds the measurement that makes this non-theoretical — tick history differs **14×
across installs** — and the terminal-build axis is the same class of difference, unpinned.

### 1.3 ℹ️ A correction to this project's own brief, not to the code

The S9 brief asserted **seven** refusal codes. **Measured: eight.**

```
LANE_BUSY · IDENTICAL_RERUN · CROSS_LANE · RUN_DEAD · ATTEMPTS_EXHAUSTED
MALFORMED_KEY · UNKNOWN_RUN · UNCOMPARABLE_PRIOR
```

Codex reports all eight have reachable producers and found no out-of-set refusal. **The brief was
wrong and the audit caught it** — recorded because a brief that miscounts is a brief the auditor had
to check rather than trust, and that is the behaviour worth confirming.

---

## Part 2 — Reported by Codex, **NOT independently verified**

Codex states plainly which of these it could not execute and why. That labelling is itself worth
noting: none of them is presented as measured.

| # | Sev | Claim | why unverified |
|---|---|---|---|
| 2.1 | 🔴 | **Two identical concurrent queues both succeed.** Runs A and B, different run ids, same `ExecutionKey`, both call `load_all_runs()` before either writes `QUEUED`; both append to their own manifest. After A completes, `plan()` never rechecks `find_cached()`, so B runs the identical configuration again. `scheduler.py:1060-1075` | needs writable temp manifests. **The cage tests only the same run id twice, sequentially** — which is the weaker case |
| 2.2 | 🔴 | **Two drivers can launch the same attempt.** Both read the same `LAUNCH_INTENT` tail, both see no marker/process, both get `LAUNCH` — and `LAUNCH` **appends no transition**, so nothing can arbitrate. The read→validate→append path has no lock or CAS. `scheduler.py:982-989` · `scheduler_run.ps1:225-240,294-335` | would launch workers/MT5. The cage uses one serial `World` |
| 2.3 | 🔴 | **The null-PID marker window mistakes a live worker for a dead one.** Kill between `Start-Process` succeeding (`scheduler_run.ps1:330`) and the marker being rewritten with its PID (`:332`): the survivor is invisible, resume records `KILLED` and opens attempt 2 while attempt 1 can still launch. | **the brief prohibited exactly this kill.** Codex notes the cage *cannot* stop inside this interval and models "marker present" as "child necessarily dead" — i.e. the gap the S9 brief predicted under aim-point #1 (kills *between* states, not *at* them) |
| 2.4 | 🟠 | **A completed attempt is rerun when its exit sidecar is missing.** `mt5_run.ps1` returned and the fresh report exists, but the worker dies before writing the sidecar (`scheduler_run.ps1:127-128`); freshness is only evaluated when the sidecar exists, so resume records `FAILED(KILLED)` and retries. | not executed. **The cage creates report freshness and the exit record atomically, so this state is unrepresentable in it** |
| 2.5 | 🟠 | **No machine-wide Model-4 exclusion and no 5c refusal.** Only per-lane lease files exist; two Model-4 keys on different lanes, or Model 4 on lane 5c, are both accepted. Design §6.4 asks for the machine freeze guard. | MT5 reproduction prohibited |
| 2.6 | 🔴 | **The `ExecutionKey` is not bound to what the driver executes** — beyond 1.1: queue key A then invoke the driver with a different `KeyFile`/`SetFile` B (no manifest-key or file-hash comparison); omit `SetFile` and the runner *warns* and uses terminal-cache config B while the manifest claims A's `set_hash`; set `key.lane=5b` while the driver's terminal/data dir stays on lane 1. | execution prohibited. **1.1 is the sub-case of this that was measurable statically, and it held** |
| 2.7 | 🟠 | **`COMPLETED` accepts the caller's own freshness assertion, including exit 3.** A `COMPLETED` line with `fresh=true`, `runner_exit=0`, a nonexistent path and a forged `run_start` is accepted; the validator never binds `run_start` to that attempt's `launch_intent_at` nor checks the report exists. `runner_exit=3` is accepted although `classify_outcome()` correctly calls exit 3 `CONFIG_REJECTED`. | this seat attempted it and the probe **CANNOT-BUILD** (`fold()` input shape) — that is a failure of my probe, not a refutation. **The highest-value item to settle next**, because unlike the rest it is purely in-process and needs no lane |

---

## Part 3 — Executed checks

| | |
|---|---|
| `scheduler.py --self-test` | passed |
| `run_scheduler_tests.py` | every reached check green, then **aborted at `tempfile.mkdtemp()`** — the auditor's read-only sandbox had no writable temp dir. **No final suite verdict was produced**, and this file does not claim one |
| pin integrity | Codex verified the scheduler, driver, cage, schema, contract and design files have **no diff between `a87f7448` and HEAD**, so its working-tree reads matched the pin |
| this seat | `scratchpad/verify_s9_s3.py` — 1.1, 1.2, 1.3 measured |

---

## Part 4 — What this changes about the slice's own acceptance

Design §10's S9 row: *"kill at **every** state ⇒ resume re-runs zero completed attempts,
double-launches nothing, duplicates no event; lane-lock test; cross-lane comparison refused."*

The audit's answer is that the criteria hold **against the cage**, and the cage's coverage is the
finding. 2.3 and 2.4 both come down to the same shape: **the cage cannot represent the state the
defect lives in** — it cannot stop inside the launch window, and it writes report-freshness and the
exit record atomically. A kill-at-every-state matrix that can only stop *at* states, never *between*
them, is not measuring what the acceptance says.

That is a claim about test coverage, and it is the one an independent reader was most likely to see
and an author least likely to.
