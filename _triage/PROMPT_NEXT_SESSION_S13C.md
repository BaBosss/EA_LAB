# OPENING PROMPT — the pilot ran; now make the evidence countable

> Written 2026-08-03 by lanes `S-2026-08-03-S13RUN` (`ORDER-1230`) and `S-2026-08-03-S13SIZE`
> (`ORDER-1240`). The pilot matrix has been **run twice** — once at the inert sizing, once at a
> sizing where the mechanism actually executes — and reviewed in three `/scrutinize` rounds.
> **Two owner decisions are already made and recorded here. Two items are blocked on things only
> the owner can settle, and they are the first thing below.**

---

## 🔴 BOX 1 — TWO THINGS NEED THE OWNER. Nothing else in this file is blocked.

### 1a. How does `MetricRef` represent an **undefined** profit factor?

`schemas.json` `MetricRef` requires `pf` as a `number`. USDJPY H1 has **99 trades, 99 winners,
`gross_loss = 0`** — PF has no denominator. `CoverageCell` sets `unevaluatedProperties: false` and
offers no field to explain a missing metric, so that cell can only be stored as a silently empty
`metrics: []`. Writing `pf: 0` is not an option: the tester prints `0` there and `ORDER-1230` already
had to fix exactly that inversion once, where the best win rate in the matrix rendered as the worst
result in it.

**Until this is answered, the 16 pilot cells cannot be registered in `factory/coverage.jsonl`,** and
§8.6 item 7 stays `BLOCKED` for want of a cell entity. Options are a nullable `pf` plus a required
reason, a `pf_state` enum, or storing gross_profit/gross_loss and deriving. **Do not pick one
silently — it is a schema change.**

### 1b. The fast-tier displacement the owner ratified is refused by a cage, correctly

The owner chose *"move `run_contract_binding_tests` out of the fast tier"* over raising the 120.0s
budget. **It was attempted and reverted.** The cage refuses it:

```
[FAIL] E staging a registry store selects the suite where ajv validates live rows
```

`run_schema_fixtures.py` — which ajv-validates every live row of `factory/*.jsonl` — runs **inside
that wrapper**, along with `gen_design_contracts --check`, the S4 snapshot python and the S5 registry
python. A blind audit already caught this hole once and a dedicated case exists to stop it reopening.
Displacing the wrapper means staging `factory/hypotheses.jsonl` no longer validates it, and making
the cage green would mean editing the guard to accept the hole.

**The real fix is to split the wrapper** — cheap contract/schema checks stay in the tier, the
expensive part leaves. That is a new order. Note the per-path budget was never the problem: 46.2s
fits inside 90.0s comfortably, so the displacement fixes a number that only manifests on a **full**
run while removing protection from targeted runs that were already inside budget. **The budget stays
pinned at 120.0s and must not be raised.**

---

## Where things stand — verify, do not assume

```bash
tools/python312/python.exe _triage/factory_os/check_pilot_acceptance.py
```

Still **`4 PASS · 0 FAIL · 10 BLOCKED`**, unchanged by both lanes and *deliberately so*: the evidence
now exists and the checkers that would read it still do not. `EVIDENCE_COMPLETE` remains
**UNREACHABLE** until the stubs are implemented.

- **Baseline green first:** `run_fast_cages.ps1 -Hook` (27 suites) · `run_s13_tests.ps1` (47) ·
  `run_s2a_gate.py` · `run_schema_fixtures.py` · `check_schema_structure.py` ·
  `gen_design_contracts.py --check` · `check_state.ps1`.
- ⚠️ The **full** tier measures **124.4–137.3s** against the pinned **120.0s** — a real breach whose
  magnitude drifts (four runs). It does **not** block ordinary commits: the hook passes
  `-StagedPathsFile`, so a normal commit runs a subset under the 90.0s per-path budget.
- **Delete `_triage/factory_os/__pycache__`** before the first generator run — but **do not measure
  the tier immediately after**, or you are timing a cold Python cache (that mistake is already made
  and recorded).
- **Re-derive your order block from BOTH tests.** Highest in use anywhere = **1240**; highest
  reserved block ends at **1249** → **1250-1259** is next. **Commit the reservation before using a
  number.** `1190-1199` was reserved and never used — leave it as buffer.
- `git log --oneline -15`.

## What is already done, so you do not redo it

1. **MT5 lane declared** — `D:\Meta 5` (primary/roaming). `BTCUSD` is pinned to it **for life**
   (§8.3: tick history differs **14×** across installs). Every record carries the lane.
2. **Parity PASSES at the case-set level** — 4 cases, 8 passes, `=== THE CASE SET SATISFIES design
   5.5 ===`. ⚠️ `must-trade` and `cage-fires` **exit 1 and that is not a failure**: no single case can
   exercise all seven points. `--rollup` is the contract. Evidence in `factory/parity/`.
3. **16/16 cells run, twice.** At the build-default lot **all 16 flat-lot probes were
   `UNTESTED-INERT`** — `_41_FixedLot=0.01` on a 0.01-step broker quantizes the LOG-power progression
   away, so both arms were the same EA and H01's falsifier was satisfied by a mechanism that never
   executed.
4. **First lot resolved MECHANICALLY to 0.03** by a criterion committed *before* the sweep, which
   never reads a PF: *the smallest grid value at which the probe returns `EXERCISED`*. Negative
   control at 0.01 reproduces INERT; positive anchor at 0.10.
5. **The falsifier comparison is now single-variable.** It used to compare a **wrapper** baseline
   against a **parent** flat-lot arm — two variables, one attribution. A third parent-side arm fixes
   it, and the re-run shows `baseline == probe-escalated` on **all 16 cells, digit for digit**, so
   wrapper ≡ parent is now *measured* across the matrix rather than assumed from one parity cell.

## The work, in the order the design forces

1. **Answer BOX 1a**, then register the 16 cells and close §8.6 item 7's "no cell entity" blocker.
2. **The decision-13 optimize probe.** *This is what item 7 actually means* — the flat-lot probe that
   has been run is H01's **falsifier arm**, not the optimize probe. **Item 7 must not be ticked from
   what exists today.** `optimize_guard` must be observed **refusing a real pilot sweep** for item 6
   (a guard with zero fires is `UNTESTED`).
3. **BWD 2020–2022.** For the ENGINE-EDGE class BWD is a **HARD** gate, not the usual soft one.
4. **Model 4.** Everything so far is Model 1 — a pulse-finding pass. `CLAUDE.md` makes Model 4
   mandatory for ENGINE-EDGE, so **nothing produced yet is verdict-grade.**
5. **The parity result manifest** (§8.6 items 3–4). `.gitignore:70` ignores `_mt5_auto/reports/`, so
   the committed manifests name reports that are **not in the repo** — `--rollup` reproduces only on
   the machine that ran it. Do **not** wire the checker to re-read those directories; the schema
   belongs to `parity.py`, with the checker driving `parity.verdict_for_case`.
6. **Teach the remaining stubs to read what now exists**, deleting each `UNIMPLEMENTED` entry as you go.

## Read the numbers correctly, or you will reach the opposite conclusion

- **`UNDEF` is not 0.** No losing trades ⇒ no denominator. The tester prints `0`; that is the single
  most invertible number in the table.
- **PF excludes what the tester force-closed at the window end.** Under `SL_NONE` a basket closes only
  in profit, so an unresolved one is carried and never enters the ratio (`USDJPY H4` H02 carries
  **−850.33**). Every row prints its `carried` figure — use it.
- **`EXERCISED` ≠ `COMPARABLE`.** The lever can move while the criterion still has nothing to read.
- **Participation differs between arms.** XAUUSD H1 is 23 escalated trades against 100 flat-lot. A PF
  compared across different trade counts is not like-for-like.
- **DD moved to 15–17 %** at 0.03 against 1.5–11 % at 0.01, i.e. it is pressing on
  `RC_AcctDDLimitPct=12.0`.
- **`BTCUSD H4` PF 346.08** at the old sizing (79 winners, one −4.82 loss) is *a number wanting an
  explanation*, not an edge.
- **Crypto financing is deducted post-hoc and the PF is NOT financing-adjusted** — recomputing it
  needs the per-position gross split.

## Traps this chain paid for

- **Your output can kill your own suite.** §8.6's wording carries `§` and `≤`; a child of the hook
  gets an ANSI pipe and the first such glyph raises `UnicodeEncodeError` → `exit -1 SUITE THREW` with
  the cause swallowed. Every python-invoking wrapper needs `$env:PYTHONIOENCODING = 'utf-8'`.
- **`(... | Where-Object {...})[0]` returns a `[char]` when exactly one line matches.** Wrap in `@()`.
  Same for `.Count`, which is `$null` on a single result. Both hit this chain.
- **`{2,>8}` is not .NET format syntax** — it throws *after* every tester run is already paid for.
- **A negative case that short-circuits before the rule under test proves nothing.**
- **Adding one `check_*.py` costs two more edits**: `run_guard_shape_lint`'s `L1_FILES` **and**
  `CATEGORY`, plus every transitive import named by `run_guard_trigger_tests` PART 4b.
- **Every attack needs its control.** The inertness detector ships with a run proving it returns
  `EXERCISED`; without it, "it says INERT" is indistinguishable from "it always says INERT".

## Do NOT do in this session

- 🚫 Issue any EA verdict from automation — design §10 stops this slice at `EVIDENCE_COMPLETE`.
- 🚫 Tick §8.6 item 7 from the flat-lot probe · 🚫 delete an `UNIMPLEMENTED` entry without implementing it.
- 🚫 Raise `$FullTierBudgetSeconds` · 🚫 edit a cage to make its own FAIL go away (BOX 1b).
- 🚫 Pick a first lot by which value gives the better PF — the criterion is mechanical and committed.
- 🚫 Compare results across MT5 installs · 🚫 quote a crypto number with financing not deducted.
- 🚫 Edit `_triage/EA_LAB_FACTORY_OS_DESIGN.md` §8.6 — it is the spec the checker is judged against.
- 🚫 Touch `MASTER_BACKLOG.md` §2 (outside an owner-approved `gen_coverage --apply`) · `AGENTS.md` ·
  `PROJECT_STATE.md` · any `.set` migration · any magic allocate/renumber/retire.

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| Pilot matrix run end-to-end; parity passes; flat-lot probes inert at 0.01 | ORDER-1230 — DONE |
| First lot resolved to 0.03; falsifier de-confounded; 3 `/scrutinize` rounds | ORDER-1240 — DONE |
| How `MetricRef` represents an undefined PF, then register the 16 cells | BOX 1a — owner decision, then a new order in 1250-1259 |
| Split `run_contract_binding_tests` so the cheap schema cages stay in the fast tier | BOX 1b — new order in 1250-1259 |
| decision-13 optimize probe + `optimize_guard` observed refusing a real sweep | new order in 1250-1259 (this is what §8.6 item 7 means) |
| BWD 2020-22 (HARD gate for ENGINE-EDGE) and Model 4 | new order in 1250-1259 |
| Parity result manifest owned by `parity.py`; wire §8.6 items 3-4 | new order in 1250-1259 |

Open with: **"อ่านไฟล์นี้ แล้วเริ่ม — ตอบ BOX 1a ก่อน แล้วเดินตามลำดับงาน"**
