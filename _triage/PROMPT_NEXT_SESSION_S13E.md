# OPENING PROMPT — the guard has fired for real; now finish the matrix and register it

> Written 2026-08-03 by lane `S-2026-08-03-S13D` (`ORDER-1253` parts 1-3, `ORDER-1270` · `1271` · `1272`).
> **A second lane was live the whole time this ran** (`S-2026-08-03-AUDITCOV`, the audit-only lane) and
> may still be. Check `docs/SESSION_LEDGER.md` before you touch a shared file — one commit here died on
> `cannot lock ref HEAD` mid-hook because of it.

---

## ✅ What changed, so you do not rebuild it

`check_pilot_acceptance` went **`6 PASS · 0 FAIL · 8 BLOCKED`** → **`7 PASS · 0 FAIL · 7 BLOCKED`**.
Verify, do not assume:

```bash
tools/python312/python.exe _triage/factory_os/check_pilot_acceptance.py
```

1. **§8.6 item 6 is GREEN, from committed evidence and not from the fixture suite.**
   `optimize_guard.ps1` used to print its verdicts and lose them, so *"observed refusing at least one
   real case"* could not be answered from anything in the repo. It now appends one record per
   submission to `factory/optimize_decisions.jsonl` — swept dimensions, per-dimension ALLOW/REFUSE, the
   resolver's answer **as fields**, the hypothesis revision, the lane.
2. **Two REAL submissions of the pilot's own probe are committed.** One ALLOWed (the optimizer ran on
   it), one that deliberately added `_9_MaxLevels` and was refused **before a second of tester
   wall-clock** — the same shape as design 8.4's deliberate-refusal parity case.
3. **The handler needs three things and the third is the one to keep:** the cage must be inside
   `$FAST_SUITES`, the guard must have refused a real dimension, **and** it must have allowed a real
   submission outright. A guard broken closed refuses every real case too. Case `G3` is that attack.
4. 🔴 **Running the probe for the first time showed the guard had been operating with its two
   strongest layers OFF on every wrapper sweep** — a generated-wrapper `.ini` resolves no Boss build,
   and `mt5_optimize.ps1` never declared a hypothesis revision, so the whole `ORDER-630`
   ParameterBinding resolver was never consulted and `ORDER-671`'s UNBOUND refusal had nothing to fire
   on. Fixed for the pilot caller; **still off for every other caller** → `ORDER-1270`.
5. **`run_optimize_guard_tests` 14 → 32 cases** (5.8s → 9.0s), **`run_s13_tests` 63 → 72**. The cage is
   proven able to fail: renaming one field in the PowerShell writer reddens it and names which end
   broke.

⚠️ **The full-tier time was deliberately NOT measured** and no number is claimed — an MT5 optimization
held this lane for most of the session, and a tier sample taken under that load is a number about the
load. **Measure it on a quiet lane before you trust the 24.9s of headroom the last prompt quoted.**

---

## 🔴 BOX 1 — the SAME owner decision as last time, and it now has a second reason

### 1a. `ORDER-1257` — the attestation authorising the coverage store still does not verify

```bash
powershell -File scripts/_test/run_contract_binding_tests.ps1
```

**Still RED at HEAD** (F2 stale pin + A8 bundle no longer verifies), exactly as reported. It was
reproduced at this lane's baseline and **not repaired here**: the log's `signer` is `user (Boss)` on
every line, and this seat may not transcribe a decision that was never given. Three options are
written out in `ORDER-1257`. 🚫 Do not re-pin · 🚫 do not append the acknowledgement for the owner ·
🚫 do not revert the cells. ⚠️ Whatever is chosen, `run_s2a_gate` + `check_coverage_transfer` go back
in the tier **in the same commit**.

🔴 **The new reason, and it costs the owner something to ignore:** option (a) has the owner sign an
acknowledgement naming `current_blob` of `factory/coverage.jsonl`. **The next step of `ORDER-1253`
changes that file again** (16 cells `BASELINE_RUN` → `PROBE_RUN`). Signing before that lands means
signing a blob that is stale on arrival, and sending the owner round the same loop twice.
**So `factory/coverage.jsonl` was left frozen this session on purpose** — the probe runs write to
`factory/runs/pilot/probe/`, never to the store. Either settle 1a first and then register the cells,
or register the cells first and let the owner sign once, at the end. **Pick one deliberately; do not
drift into signing in the middle.**

---

## The work, in the order the evidence forces

1. **Finish and register the probe — `ORDER-1253` acceptance 3.** 🔴 **FIRST, COUNT WHAT ACTUALLY
   FINISHED. Do not assume 16.** Fifteen cells were launched serially in the background as this
   session ended and may have been interrupted:
   ```bash
   cat factory/runs/pilot/probe/*.jsonl | tools/python312/python.exe -c "import sys,json;rs=[json.loads(l) for l in sys.stdin if l.strip()];print(len(rs),'record(s)');[print(r['cell_id'],r['arm'],'exit=%s'%r['launcher_exit_code'],'%ss'%r['elapsed_sec']) for r in rs]"
   ```
   **Measured cost: 675.5s for the first cell** (XAUUSD H1, 7 dimensions, genetic, MAIN, 20 tester
   agents), so a missing cell is ~11 minutes, not a day. Re-run any that are absent or carry
   `launcher_exit_code` other than `0`, with `scripts/pilot_probe.ps1 -Symbols X -Periods Y
   -Revisions Z`. Then teach `gen_pilot_cells.py` to derive `PROBE_RUN` from the probe records and
   `--apply`. 🚫 **The transition must come from the generator** — the store is never hand-edited —
   and 🚫 **it must not be ticked from the flat-lot arm**: `PROBE_DONE_STATES` excludes `BASELINE_RUN`
   and case `C3` asserts it.
2. **`ORDER-1272` — nothing runs `gen_pilot_cells.py --check`.** One grep proves it. Fix it *before*
   step 1's `--apply`, or the store's only guarantee stays a sentence in a commit message. Measure
   its cost against the tier budget first.
3. **`ORDER-1254` — BWD 2020–2022 (a HARD gate for ENGINE-EDGE), then Model 4.** After step 1, because
   BWD judges the configuration the probe selected. 🚫 **BWD is never a search surface** (design 6.2).
   Everything measured so far is Model 1, so **nothing produced yet is verdict-grade**.
4. **`ORDER-1270` / `1271`** — the guard layers that are still off for every non-pilot caller, and the
   enumeration of every path by which a parameter value gets selected.
5. **`ORDER-1255`** the parity result manifest · **`ORDER-1256`** the last four stubs ·
   **`ORDER-1251`** `check_r3`'s verdict scan is an equality test that prose walks past.

🚫 **Still: no verdict from automation.** Design §10 stops this slice at `EVIDENCE_COMPLETE`, and the
probe XMLs are a search surface, not a result. Picking a configuration out of one is design 6.2's
plateau-center procedure **with a trade floor**, it happens after all 16 exist and after BWD, and it
is a human's.

## Baseline before you touch anything

- `run_fast_cages.ps1 -Hook` **on a quiet lane** · `run_s13_tests.ps1` (72) · `run_optimize_guard_tests.ps1`
  (32) · `run_schema_cages.ps1` · `run_s2a_gate.py` · `check_state.ps1` · **and the hand-run wrapper
  above, which is expected RED until BOX 1a is settled.**
- **Re-derive your order block from BOTH tests.** Highest in use anywhere at the time of writing =
  **1272**; the highest reserved block ends at **1279** → **1280-1289** is next. **Commit the
  reservation before using a number.** `1190-1199` was reserved and never used — leave it as buffer.
- `git log --oneline -15`, and read `docs/SESSION_LEDGER.md` for lanes still `ACTIVE`.

## Traps this lane paid for (the new ones)

- **`@array` splatting in PowerShell passes elements POSITIONALLY.** `@('-Expert', $x, '-Symbol', $y)`
  bound the literal string `'-Expert'` to `-Expert` and by the seventh slot handed `-Model` the string
  `"-FromDate"`. It was caught only because the target refused to bind — **had the shifted values been
  type-compatible it would have run a different cell than the record claimed.** Use a hashtable.
- **A launcher that never started was written into the evidence record as `exit=0`**, because
  `$LASTEXITCODE` was stale from an earlier call and a PowerShell binding failure is not a native exit
  code. Clear it before each launch and record "never ran" as its own value.
- **`$ErrorActionPreference = 'Stop'` plus a child that writes to stderr aborts the whole suite** as a
  `NativeCommandError`. PART 2 of the optimize-guard cage killed itself that way on its first run.
- **A negative case must assert the REASON, not the non-zero exit** — otherwise a typo in the
  invocation is indistinguishable from the refusal you are testing for.
- **Two writers, one shared worktree, and the hook takes ~30s:** a commit can pass every cage and then
  die on `cannot lock ref HEAD`. Re-check what the other lane touched before re-staging; do not assume
  your working tree is still yours.

## Do NOT do in this session

- 🚫 Issue any EA verdict from automation · 🚫 tick §8.6 item 7 from the flat-lot probe · 🚫 read a PF
  out of a probe XML to choose a parameter · 🚫 delete an `UNIMPLEMENTED` entry without implementing it.
- 🚫 Raise `$FullTierBudgetSeconds` · 🚫 edit a cage to make its own FAIL go away · 🚫 wire the
  acceptance checker to re-read `_mt5_auto/reports/**`.
- 🚫 Compare results across MT5 installs (item 9 FAILs on it) · 🚫 quote a crypto number with financing
  not deducted · 🚫 search on BWD.
- 🚫 Edit `_triage/EA_LAB_FACTORY_OS_DESIGN.md` §8.6 · 🚫 edit `MASTER_BACKLOG.md` §2 without an owner
  re-attestation in the same commit · 🚫 write to `_triage/factory_os/s2a_attestations.jsonl`.
- 🚫 Touch `AGENTS.md` · `PROJECT_STATE.md` · any `.set` migration · any magic allocate/renumber/retire.
- 🚫 Pick up the audit lane's findings (`ORDER-1260` · `1261` · `1262` and whatever S9/S3/S6/S11/S2
  return) **in the same session that builds** — the owner split build, audit and repair three ways.

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| decision log + real ALLOW/REFUSE records + §8.6 item 6 green | ORDER-1253 — parts 1-3 DONE, acceptance 3 outstanding |
| 16/16 cells to `PROBE_RUN`, generated not hand-edited | ORDER-1253 |
| the guard's build + ParameterBinding layers are off for every non-pilot caller | ORDER-1270 |
| enumerate every path by which a parameter value is SELECTED, and which leave a record | ORDER-1271 |
| 🔴 nothing on the commit path runs `gen_pilot_cells.py --check` | ORDER-1272 |
| BWD 2020-22 as a HARD gate, then Model 4 | ORDER-1254 |
| the parity result manifest, owned by `parity.py`; §8.6 items 3-4 | ORDER-1255 |
| the last four stubs — §8.6 items 10, 11, 12, 14 | ORDER-1256 |
| `check_r3`'s verdict-value scan is an equality test, so prose walks past it | ORDER-1251 |
| 🔴 the attestation pinning `factory/coverage.jsonl` still does not verify | ORDER-1257 |

Open with: **"อ่านไฟล์นี้ แล้วเริ่มได้เลย — นับ probe cell ที่เสร็จจริงก่อน แล้วค่อยเดินตามลำดับ"**
