> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **shift-change note for lane
> `S-2026-08-02-S8PARITY`** — the lane that finished slice **S8**. A note, not a queue: every
> forward item below already has a row on `AGENT_TASKBOARD.md`.

# Session end — 2026-08-02, `S-2026-08-02-S8PARITY`

**Slice S8 is CLOSED.** Both halves landed and both were measured on the pinned MT5 lane: the
`Inputs.mqh` capability-token rollout (Boss_14 only, owner-ratified per-Boss shape) and the 7-point
Parent–Variant parity harness of design §5.5. `ORDER-1021` is `DONE`.

## The numbers, and where each was read from

| | |
|---|---|
| `B14-H01-r1` | **78 const · 38 on the Inputs page · 7 unreachable but KEPT** |
| `B14-H02-r1` | 75 const · 41 on the Inputs page · 7 kept |
| compile | 9 hand-written targets **0/0** · both generated wrappers **0/0** |
| `tpl_regression` | **CLEAN 8/8**, lane 1, binaries recompiled from current source first |
| wrapper `.ex5` vs parent | **112,952 vs 178,914 bytes** — a `const` selector folds its dead branches away |
| parity, 4 cases | **0 DIFFER anywhere**; every one of the seven points exercised by a real observation in at least one case |

🔴 **The `38` was counted from the MT5 report's own `Inputs:` block — from the BINARY, not from a
table.** Every other statement about how many inputs a build exposes (the registry's, the const
plan's, this file's) is derived from source; the report is derived from the artifact that actually
attaches. That is the one measurement design §5.3's acceptance is really about, and it turned out
to be available headlessly all along.

## The parity result, and why one case had to differ

Lane 1 (`D:\Meta 5`) — the same pin `tpl_regression` compiles and measures on (`ORDER-371`) —
XAUUSD H1 2024.01.01–2024.07.01, Model 1, one full-surface `.set` handed to **both** sides.

| case | result |
|---|---|
| `must-trade` | 5/7 AGREE · 0 DIFFER (points 6+7 vacuous here) |
| `cage-fires` | 6/7 AGREE · 0 DIFFER (point 7 vacuous here) |
| `deliberate-refusal` | 3/7 AGREE + 4 N/A · 0 DIFFER · **PASS** |
| `locked-absent` | **DIFFERS BY DESIGN — the difference IS the evidence** |

The wrapper (38 inputs) and the parent (116) reach an **identical `effective_config_hash**, an
identical 60-order trace, an identical 61-deal trade list and an identical end state.

**`locked-absent` is the decisive one.** Both sides got a `.set` asking for `_2_MaxHoldBars=5`. The
parent honoured it — 82 orders, 83 deals, a different hash. The wrapper could not — 60/61, hash
**byte-identical to its own must-trade run**, because the input it was asked to change does not
exist in its binary. That is design §5.5 case 3/4 (*absent from the page **and** its value provably
applied*) measured rather than asserted.

## 🔴 Five findings, in the order they cost something

**1. design §5.5's "agree on all seven" is not satisfiable by ONE run, and that is a property of
the points rather than a gap in the harness.** A clean run raises no errors, so point 7 has nothing
to compare; a run that refuses at `OnInit` places no orders, so points 2–6 have nothing to compare.
The two mandatory directions are therefore **not good practice — they are the only way all seven
get exercised, and neither direction can do it alone.** The contract is satisfied by the **case
set**, and `parity.rollup()` is what checks it: no point may DIFFER anywhere, every point must be
non-vacuous somewhere, and both directions must be present.

**2. The comparator shipped with the exact defect it exists to refuse.** `_table` accepted any row
with a non-empty cell, so the tester report's unlabelled TOTALS row
(`['', '0.00', '0.00', '0.00', '0.00', '']`) counted as a deal. The Deals list was therefore
**never empty — not even for a run that refused at `OnInit` and opened nothing** — so the vacuity
check on point 4 could not fire on a real report, ever. It passed on synthetic fixtures throughout.
Caught by the deliberate-refusal case reporting `deals AGREE` for two runs that never attached.
**That is the second reason design §5.5 demands that case, and the one nobody had written down:**
it is not only a test of the EA, it is the test that catches an extractor which cannot see zero.

**3. The design's own refusal example is not expressible on this revision.** §5.5 names
`_42_RiskPct` mis-paired with an `SLMode` that yields no distance. Under `B14-H01` **both
ingredients are compiled away** (`FirstLotMode` const `FIRSTLOT_FIXED`, `SLMode` const `SL_NONE`),
so a `.set` naming either is ignored by the wrapper and the two sides would refuse for *different*
reasons — a parity failure manufactured by the case rather than found by it. The refusal case uses
`_41_FixedLot=0`: the same `MM_ConfigValid` fail-closed seam, reached through an input **live on
the wrapper's own 38-key page**. Both sides refused with a byte-identical reason string. **The
general lesson: a refusal case must be built from the surface the wrapper still has.**

**4. Zero fires was not accepted as a pass.** `must-trade` left points 6 and 7 with nothing to
compare. Rather than write that up as agreement, `cage-fires` arms the account-DD gate at **0.3 %**
instead of the pinned 12 % so it actually trips. It fired **once on each side**, identical to the
cent: `DD 1.52% vs limit 0.30% (HWM 10007.41)`.

**5. A guard that already existed caught the new runner.** `run_report_freshness_tests` PART 5
refused `parity_run.ps1`'s first commit for reading a report without gating it — correctly, since
`mt5_run.ps1`'s own header records that *"the `.htm` exists is NOT evidence that THIS invocation
produced it"*. Now wired through `Test-ReportIsFresh` with the runner's exit code, **and
re-measured end to end afterwards** so the gate is proven not to false-refuse.

## ✅ RESOLVED SAME DAY — the owner ratified the lock

The section below was written while the decision was open. **The owner ratified locking both
switches**, so the final state of this slice is **87 const / 29 on the Inputs page / 0 kept**, and
the contradiction described below no longer exists. The wrapper `.ex5` shrank a further 2.5 KB
(112,952 → 110,382), all nine targets and both wrappers recompiled **0/0**, and **all four parity
cases were re-run against the new binaries** — same result, **0 DIFFER anywhere**.

🔴 **The `effective_config_hash` is byte-identical before and after the lock** (`8f9497b8…`),
which is the check that proves the lock changed no VALUE — both switches were already at their OFF
default — only which side of the guard pair each input compiles on. The reasoning below is kept
because the *reason* the number was 38 and not 31 is the durable part, and because it is the
argument the ratification rests on.

## The decision, as it was put to the owner

**The opening prompt's acceptance number for the Inputs page was 31. The sound answer is 38, and
the 7-input gap is not a shortfall — it is a contradiction that const-ing would have compiled into
the binary.**

`activation.classify()` answers *"is this input reachable under THIS ONE configuration"*. A
compile-time `const` claims something strictly stronger: that the input cannot matter under **any**
configuration the operator can still produce. Those coincide only when every selector the input's
gate reads is itself fixed at compile time.

`_4_DdAdaptiveOn` and `_57_DynCloseOn` are declared **`TUNABLE`** (a sweep may move them) while the
**7 dials they control are declared `INACTIVE`**. Both cannot be true: the moment the optimizer
flips the switch, the dials are live. Const-ing them would hand the optimizer one arm of a two-arm
decision and let it report the result as the decision — memory `inert-axis-fake-plateau`, made
**structural**, because the axis would be inert in the binary itself.

Both switches are on/off **mechanism** selectors, which is exactly the shape of every member of
`hypothesis_b14.LOCKED_SELECTORS` (`_MG_SelfGate` and `_50_RegimeMode` are already there, and the
file's own comment defines that list as *"the inputs that decide WHICH MECHANISM runs"*).

- **Lock them** ⇒ const set 87, Inputs page **29**, contradiction gone.
- **Leave them** ⇒ page **38**, and `optimize_guard` will `ALLOW` each switch while `REFUSE`ing
  every dial it controls — a sweep whose ON arm is frozen at factory defaults.

Either is defensible. **Only the owner may pick**, because it changes what the optimizer may sweep
on a real EA, and the prompt explicitly forbids changing strategy configuration under cover of the
rollout. The conservative branch shipped: **nothing is silently frozen.**

## Still owed on the mechanism, stated rather than implied

- **SAFETY inputs still compile as `input`, not `sinput`.** Design §5.4's state table asks for
  `sinput`, which *removes* the dimension from the optimizer rather than declining to sweep it —
  a stronger guarantee than a script refusing. Separable, and deliberately not folded in here.
- **Parity point 6 can only ever observe FAILED persistence.** `Persist.mqh` prints on error and
  never on success, and tester `GlobalVariable`s are sandboxed and destroyed at pass end, so a
  *successful* GV write is invisible to any log-derived check. What IS covered: the key **scope**
  (via point 2, which hashes `LAB_ENTRY_TAG` and `_0_Magic`) and every cage transition that prints.
  The remedy, if it is ever wanted, is a log-only success-side `[PERSIST]` line — an additive
  `core/` edit that would owe `tpl_regression` again.
- **Model 4 has not been run.** Parity asks whether two binaries agree and both sides ran Model 1;
  a grid **verdict** needs Model 4 (`CLAUDE.md` cage discipline), and no verdict is issued here.
- **The generated wrappers are still not in `deploy.ps1`'s `Boss_*.mq5` discovery.** Compiling them
  remains an explicit step; the nine-target 0/0 policy is untouched, as designed.

## Cage state at close

- `check_wrapper_gen` gains **W6/W7/W8**; `run_wrapper_gen_tests` **9 → 13 attacks**, all RED before
  their criteria existed. **W6 had to move ABOVE the generator call** — its attack also trips
  `activation.classify`, which refused first, so `check()` returned the W1 refusal alone and W6
  reported `NOT CAUGHT`. Two independent defences firing is fine; the one that names the *actual*
  omission being unable to reach the output is not.
- **W8 is the criterion worth keeping.** The registry's HIDDEN count and the wrapper's Inputs page
  are two independent statements of the same fact and nothing had ever subtracted one from the
  other. `85 HIDDEN = 78 const + 7 refused` is now a check rather than a sentence in a handoff.
- new suite `run_parity_tests.ps1`: **11 attacks + a specificity half**, measured **0.13 / 0.04 /
  0.05 s over three runs → 0.1 s** (three samples, not one — memory
  `phantom-regression-from-two-single-samples`), against the tier's 1.1 s of headroom (`ORDER-820`).
- `param_registry_check` CLEAN · `check_input_surface_gen` ACCEPTED · `check_registries` all hold ·
  `run_guard_shape_lint` both shapes hold · `check_state.ps1` CLEAN.
- **No EA verdict issued.** This session produced machinery.

## Two PowerShell traps paid for, written down where they bit

- **`$case` IS `$Case`** — PowerShell variable names are case-insensitive, so assigning the case
  table to `$case` overwrote a `[ValidateSet]` parameter with a Hashtable and the script refused
  itself on its first run.
- **`Set-Content -Encoding UTF8` writes a BOM** on 5.1, and `json.loads` refuses one. Same class as
  the UTF-16LE agent logs: the instrument has to be able to read the file before anything it says
  about the contents means anything (`prove-the-instrument-can-see-the-file`).

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| S8: the rollout, the parity harness, and the five findings | ORDER-1021 (DONE) |
| the `_4_DdAdaptiveOn` / `_57_DynCloseOn` lock decision | ORDER-1021 (owner) |
| SAFETY inputs as `sinput` (design §5.4) | ORDER-1021 (still owed) |
| a success-side `[PERSIST]` line so parity point 6 can observe a write | ORDER-1021 (still owed) |
| `classification` vocabulary and `unit_true`/`coupled_with`: contract vs shipped CSV | ORDER-1020 (unchanged, not acted on) |
| block reservation derived from order numbers instead of ACTIVE blocks | BACKLOG-D29 |
