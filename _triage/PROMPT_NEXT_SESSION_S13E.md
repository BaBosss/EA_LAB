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

## ✅ BOX 1 IS CLOSED — the owner ratified four decisions in-session. Do not re-ask.

Recorded in **`PROJECT_STATE.md` §3** (the canonical home for a ratified rule) before any of them was
acted on. Read them there; the operative summary:

1. **`ORDER-1257` → option (b): replace the instrument.** An approval must not pin the bytes of the
   thing it authorises. Do **not** ask the owner to sign an acknowledgement.
2. **Sequencing, ratified in the same message: register the 16 probe cells FIRST, then close 1a once,
   at the end.** This is why `factory/coverage.jsonl` was left frozen — signing while the file is
   still moving sends the owner round the same loop twice.
3. **The repository is PRIVATE** (owner-stated). No lane probed the remote; do not probe it.
4. **`ORDER-1262` → accepted risk, recorded, not rewritten, not notified.** A rewrite is not free
   here: blob and commit oids are pinned inside `OwnerRef`s, so rewriting downstream of `cc40731c`
   invalidates every pin in the attestation system at once. 🚫 This does **not** license leaving new
   secrets in git, and `ORDER-1261`'s repair of the `B1` secret cage is unaffected and still owed.

🔴 **ROUTING CHANGE, made after this prompt was first written — do NOT build the 1a fix here.**
The corrections lane took it: `ORDER-1269` **#1** is *"change the pin instrument"*, which is the same
work as `ORDER-1257` option (b), and the S2 audit reframed it usefully — it is a **granularity
mismatch** (the pin covers a whole store that is *designed to grow*, while what the owner approved
was a migration and a section), not merely a self-invalidating pin. **Two lanes building one
replacement is worse than neither building it.**

⚠️ **Ordering between the two lanes, and it matters:** `gen_pilot_cells.py --apply` (step 1 below)
moves `factory/coverage.jsonl` — the very file the new instrument has to pin. **Apply FIRST, then let
the corrections lane design against a file that has stopped moving.** That is the owner's ratified
register-then-close sequencing, now spread across two lanes instead of one.

`run_s2a_gate` + `check_coverage_transfer` stay hand-run until that lands, and **return to the tier in
the same commit as the fix** — added while red they block every commit in the repo.

### 1a. `ORDER-1257` — what is still red (context only; the fix belongs to `ORDER-1269` #1)

```bash
powershell -File scripts/_test/run_contract_binding_tests.ps1
```

**Still RED at HEAD** (F2 stale pin + A8 bundle no longer verifies), reproduced at this lane's
baseline. 🚫 Do not re-pin with `gen_s2a_migration.py` — D1 is inside its own bundle, so regenerating
it moves `bundle_sha256`: a signature to repair a signature, which is the loop `ORDER-614` rev 2 was
written to end. 🚫 Do not append the acknowledgement (option **a** was not the one chosen). 🚫 Do not
revert the cells.

⚠️ **The trap the replacement has to survive** is the same one that has now caught this repo six
times: whatever new instrument is chosen, ask *"does approving this pin the bytes of something the
approved work is expected to change?"* before building it. `ORDER-614` rev 2 solved the sibling case
(a checker inside its own bundle) by moving implementations OUT of the bundle — read what it did
before designing something new.

---

## The work, in the order the evidence forces

1. **Finish and register the probe — `ORDER-1253` acceptance 3.** 🔴 **FIRST, COUNT WHAT ACTUALLY
   FINISHED. Do not assume 16.** Fifteen cells were launched serially in the background as this
   session ended and may have been interrupted:
   ```bash
   cat factory/runs/pilot/probe/*.jsonl | tools/python312/python.exe -c "import sys,json;rs=[json.loads(l) for l in sys.stdin if l.strip()];print(len(rs),'record(s)');[print(r['cell_id'],r['arm'],'exit=%s'%r['launcher_exit_code'],'%ss'%r['elapsed_sec']) for r in rs]"
   ```
   **Measured costs: 675.5s / 910s / 735.5s / 1192.2s** for the four XAUUSD cells (7 dimensions on
   H01, **10 on H02**, genetic, MAIN, 20 tester agents), so a missing cell is 11–20 minutes, not a
   day. Re-run any that are absent or carry `launcher_exit_code` other than `0` **or
   `xml_present: false`**, with `scripts/pilot_probe.ps1 -Symbols X -Periods Y -Revisions Z`
   (**one value each — the script now refuses a comma, see the traps**).
   🔴 **Two rows in that store are not cells and you must not count them:** the
   `deliberate-refusal` arm (`exit=3`, which is 8.6 item 6's evidence, not item 7's), and one row
   whose `cell_id` is `B14-H01-r1/EURUSD,USDJPY,BTCUSD/H1,H4` — a bogus run kept deliberately as
   the evidence that the guard-rail was missing. Six H01 cells (EURUSD · USDJPY · BTCUSD × H1 · H4)
   were **queued behind the running batch** as this session ended; if that queue did not survive,
   they are the six to run.
   ✅ **`ORDER-1273` is the SELECTION criterion and it is already pre-registered — execute it,
   do not rewrite it.** Every constant is pinned in the order (trade floor `Trades` H1≥100/H4≥60 ·
   plateau set = top 10 % by `Result` · per-dimension median snapped to grid · BOUNDARY expands the
   grid · the selected config is RE-RUN once before it goes to `ORDER-1254`). It was committed
   before any surface was read, which is the only thing that makes it a criterion. `ORDER-1274`
   holds the fine half of the §6.2 ladder, queued with its measured cost.
   ✅ **The generator already does the transition — you do not build it, you run it.**
   `gen_pilot_cells.py --check` reports `N of 16 cell(s) at PROBE_RUN`, names every probe row it
   does **not** count, and exits 1 on drift. When the matrix is complete, `--apply`.
   **The four steps that finish this slice, in order — nothing else is owed:**
   ```bash
   powershell -NoProfile -File scripts/pilot_probe.ps1 -Revisions B14-H01-r1 -Symbols BTCUSD -Periods H4
   ```
   (…one invocation per missing cell — **one value per flag**), then
   ```bash
   tools/python312/python.exe scripts/pilot_probe_verify_xml.py
   ```
   then `gen_pilot_cells.py --check` until it reads **16 of 16**, then `--apply`, then measure the
   full tier on a quiet lane and close the ledger row.
   ⚠️ **`pilot_probe_verify_xml.py` must run after ANY new probe run** — it is what records the pass
   count, and a cell without one is held back by name rather than registered with `trial_count: 0`.
   ⚠️ **The bar is `xml_present: true` AND a pass count > 0**, not `launcher_exit_code == 0` — the launcher exited 0 on a
   missing XML until today, so an old record cannot demonstrate its probe produced anything. Records
   written before the field existed are covered by `scripts/pilot_probe_verify_xml.py`, which
   measures the artefact and keeps the measurement as **its own** labelled evidence rather than
   editing the record. **Run it after any run whose record lacks the field**, then `--check` again.
   🚫 The transition must come from the generator — the store is never hand-edited — and 🚫 it must
   not be ticked from the flat-lot arm: `PROBE_DONE_STATES` excludes `BASELINE_RUN`, case `C3`
   asserts it, and the probe store is a different directory entirely.
2. **`ORDER-1272` — nothing runs `gen_pilot_cells.py --check`.** One grep proves it. 🔴 **`--apply`
   FIRST, then wire it in.** `--check` is red right now *and correctly so* (6 of 16 probed, store
   still says none), so wiring it into the tier before the store catches up blocks every commit in
   the repo. Measure its cost against the tier budget, and ship the control that proves it reddens
   on a one-character edit to a committed cell.
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

- **`powershell -File x.ps1 -Symbols A,B,C` delivers ONE element `"A,B,C"`** to a `[string[]]`
  parameter — the comma is never parsed. It produced a single "cell" named after three symbols, ran
  14.4s, and **the six real cells were never attempted while the batch reported success.** The trap
  was already documented in `run_optimize_guard_tests.ps1`, four directories away, and I walked into
  it anyway. `pilot_probe.ps1` refuses a comma now; use `-Command`, or one value per invocation.
- 🔴 **`mt5_optimize.ps1` printed `NO XML` and exited 0** — a launcher whose only product is an
  optimizer XML reporting success with no XML, for as long as the script has existed. It exits **4**
  now, so `optimize_loop.ps1` · `run_batch.ps1` · `qwen_batch_runner.ps1` will see failures where
  they saw successes. **That is the correction, not a regression** — each was accepting "no
  optimization happened" as a completed pass. Expect it and do not soften it back.
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
| `check_r3`'s verdict-value scan is an equality test, so prose walks past it | ORDER-1251 — **DONE** |
| 🔴 the attestation pinning `factory/coverage.jsonl` still does not verify | ORDER-1257 → **handed to the corrections lane as `ORDER-1269` #1; apply the cells FIRST** |

Open with: **"อ่านไฟล์นี้ แล้วเริ่มได้เลย — นับ probe cell ที่เสร็จจริงก่อน แล้วค่อยเดินตามลำดับ"**
