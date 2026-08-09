# OPENING PROMPT — slice **S9**: the recoverable, idempotent scheduler (design §6.5 / §20.8 Contract B)

> Written 2026-08-02 by lane `S-2026-08-02-SCRUT8P`, after three `/scrutinize` rounds over the
> completed S8. **This session does NOT need a long MT5 hold** — the scheduler wraps the runner,
> and its acceptance is kill-and-resume behaviour, which is provable with short cheap tester runs
> (a 2-week window smoke costs ~30 s). Reserve lane 1 for the handful of proof runs; the design
> forbids touching tester safety, so nothing here competes with a real optimize.

---

## Where things stand

**S1–S8 are ALL CLOSED.** The chain now runs: schemas → ownership (`OwnerRef`) → registries +
`ParameterBinding` resolver → preset compiler + `[CFG] effective_config_hash` (surface **and**
locked constants) → Operator/Research surface (S7) → Thin Wrapper generator + `Inputs.mqh`
capability-token rollout + the 7-point parity harness (S8, `ORDER-1021` DONE).

Numbers you can lean on: `B14-H01-r1` = **87 const / 29 on the Inputs page / 0 contradictions**
(the 29 was counted from the MT5 report's own `Inputs:` block — from the binary) ·
`tpl_regression` CLEAN 8/8 · four parity cases, **0 DIFFER anywhere**, the case set satisfies
design §5.5 · `_4_DdAdaptiveOn`/`_57_DynCloseOn` are LOCKED (owner-ratified 2026-08-02) and the
`effective_config_hash` was byte-identical across that lock, proving it moved no value.

**Three audit rounds hardened S8 after it closed** — read their commits before building on it:
- `651d68be` parity point 5 (end-state) could not fail; now reads the `end of test` deals.
- `f07499f7` point 2 is now **triangular** (wrapper == parent == **compiler's** `expected_hash`) —
  a `.set` that silently fails to apply on BOTH sides can no longer pass.
- `dda6783a` **W9**: a brute-force sweep proving no const-ed gate can be opened by any assignment
  of the live selectors. The strongest cage in the suite, and the model for how S9's recovery
  claims should be proven: **enumerate the states, do not sample them.**

## What S9 is (design §10 row, verbatim obligations)

A **wrapper around the existing runner** (`mt5_run.ps1` / `mt5_optimize.ps1`) — NOT a replacement:
lane-aware, fail-visible, resume manifest. Design §3.3's state machine:

```
QUEUED → LEASED(lane) → RUNNING → {COMPLETED | FAILED | ABANDONED} → EVIDENCE_REGISTERED
```

**Acceptance cage (all four, and the first is the whole slice):**
1. **Kill at EVERY state in §3.3 ⇒ resume re-runs zero completed attempts, double-launches
   nothing, duplicates no event.** Every state, enumerated — the W9 lesson. A kill test that
   samples two of five states is a claim about the other three wearing a pass.
2. `COMPLETED` is **refused** without a fresh report — reuse `Test-ReportIsFresh`
   (`scripts/lib/report_freshness.ps1`). Its PART 5 sweep will refuse any caller that parses a
   report ungated; `parity_run.ps1` paid that toll on its first commit, plan for it.
3. Re-running an identical (config, lane, data fingerprint) is **refused** except after an
   execution/tester error (decision 18) — cached evidence is returned instead. Idempotent, not
   merely restartable.
4. **Cross-lane comparison refused** (`ORDER-371`: numbers do not transfer across installs), and
   `LEASED` is refused without a free lane lease for that specific install.

**Prohibitions (design §10):** no process kill · no `-Force` · no change to tester safety.

## Before you start — verify, do not assume

- **Re-derive your order block from BOTH tests**: parse `## ORDER-<n>` out of all four board files
  (highest in use as of this writing = **1050**) **and** check every ACTIVE lane's reserved block
  in `docs/SESSION_LEDGER.md` — a reserved-but-unused block is invisible to the number test, and
  that produced two collisions on 2026-08-02 alone. As of this writing the next free block is
  **1080-1089** (`1070-1079` = `SCRUT8P`). Commit the reservation before using a number.
- **Baseline green first:** `check_param_surface.py --worktree` · `check_wrapper_gen.py
  --worktree` · `run_parity_tests.py` · `run_wrapper_gen_tests.py` — all currently CLEAN; if any
  is not, someone else moved the tree, stop and look.
- **Delete `_triage/factory_os/__pycache__`** before the first generator run (the S7/S8 `.pyc`
  lesson: a stale bytecode once baked a decision nobody made into the canonical store).
- `git log --oneline -15` — parallel lanes committed between this lane's commits twice today.

## Build guidance the last two lanes paid for

- **Wrap, never replace.** `mt5_run.ps1` already owns lane-guarding, leverage assertion, the
  input-cache warning and truncation checks. The scheduler ADDS a manifest and a resume loop
  around it. If you find yourself copying any of its logic out, stop — that copy is where the
  drift will live.
- **The manifest is the store; the store is append-only per attempt** (decision 65: attempt `k+1`
  inherits the Run id, every attempt kept). Model it like `factory/*.jsonl` — schema first,
  negative fixtures second (S3's pattern), writer third.
- **Every acceptance criterion gets a cage that is RED first**, and `run_guard_shape_lint`'s `L0`
  will demand registration — it has demanded it on first run seven consecutive times; assume it
  will again.
- **Measure a new suite three times before registering it in the fast tier** (memory
  `phantom-regression-from-two-single-samples`). The tier had 62 s of headroom on the last commit
  of `SCRUT8P`, but `ORDER-820` is still open on the full tier's budget.
- **The kill-matrix cage should be pure-python against a stub runner** — the parity cage's
  pattern: the judge is PURE, the tester work lives in one runner script, so the cage costs
  milliseconds and needs no lane. Real tester runs prove the WIRING once; the state machine is
  proven by enumeration.
- **PowerShell traps already paid for** (do not pay twice): `$case` IS `$Case` (names are
  case-insensitive — a local overwrote a `[ValidateSet]` parameter) · `Set-Content -Encoding
  UTF8` writes a BOM that `json.loads` refuses (read with `utf-8-sig`) · MT5 logs are UTF-16LE.

## Do NOT do in this session

- 🚫 Replace or edit `mt5_run.ps1` / `mt5_optimize.ps1` beyond what a wrapper needs (and if a seam
  is genuinely missing, add the smallest hook and re-run `run_report_freshness_tests` — its PART 3
  sweep watches every script under `scripts/`).
- 🚫 Any process kill, any `-Force`, any tester-safety change (design §10 prohibitions, verbatim).
- 🚫 Convert a second Boss, bulk-migrate `.set` files, or issue any EA verdict.
- 🚫 Touch the S2a bundle · `MASTER_BACKLOG.md` §2 · `s2a_attestations.jsonl` · `AGENTS.md`.
- 🚫 Start S10 (Candidate identity) — it depends on S9's evidence registration existing.

## Definition of done

The §3.3 state machine implemented as a wrapper + manifest · **the kill-at-every-state matrix
enumerated and green, with each state's kill observed (not asserted)** · fresh-report gate wired
and its refusal observed · identical-config re-run refused with cached evidence returned ·
cross-lane comparison refused · every new cage RED-first and registered · ledger `CLOSED`,
`check_state.ps1` CLEAN, handoff in `_triage/`. **Or an honest partial with the numbers measured
and the exact next step.**

<sub>Codex audit: `_triage/factory_os/CODEX_S7_S8_AUDIT_BRIEF.md` (with its 2026-08-02 addendum)
may run in parallel with this session — it is read-only over S7/S8 and does not need the MT5 lane.
If its findings arrive mid-session, judge them against `ORDER-1021`'s record before acting; S9
builds beside that work, not on top of its unaudited parts.</sub>

Open with: **"อ่านไฟล์นี้ แล้วเริ่ม S9 — recoverable scheduler ตาม design §6.5/§3.3"**
