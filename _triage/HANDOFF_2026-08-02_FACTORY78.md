> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **shift-change note for lane
> `S-2026-08-02-FACTORY78`** — the Factory OS session defined by
> `_triage/PROMPT_NEXT_SESSION_FACTORY_S7_S8.md`. A note, not a queue: every forward item below
> already has a row on `AGENT_TASKBOARD.md`.

# Session end — 2026-08-02, `S-2026-08-02-FACTORY78`

The prompt asked for slice **S7** then slice **S8**. **S7 is partial and S8 is not started**, and
the reason is worth more than the two deliverables: **S7 and S8 are entangled**, and the prompt's
own framing — *"S7 is its precondition"* — is only half true.

## The finding that reorders the rest of the Factory OS plan

Slice S7's acceptance is *"zero `UNKNOWN` on Boss_14's **Operator surface**"*. `surface` is **not a
`docs/PARAM_REGISTRY.csv` column** — the generated contract `META_parameter_registry_columns` says
so in as many words: *"role / locked_value / safe_range / optimize_stage are per-hypothesis and
live in `factory/parameter_bindings.jsonl`"*.

So the chain is:

```
Operator surface  ->  ParameterBinding rows
                  ->  hypothesis_revision  ^B(1[1-8])-H[0-9]{2}-r[0-9]+$
                  ->  a Hypothesis row in factory/hypotheses.jsonl   (EMPTY today)
                  ->  module_set of LAB_CAP_* capability tokens
                  ->  ...which no .mqh in the tree defines, because the allowlist header is S8
```

**S7 cannot fully close before S8 starts, and S8's generator needs registry rows S7 produces.** The
three modules committed this session are exactly the dependencies that entanglement forced into
existence — and one of them (`architecture.py`) had to be written because `schemas.json` requires
an `architecture_digest` of every `Hypothesis` and **nothing in the tree produced one**, so the
only way to register a hypothesis was to type a digest by hand.

## What landed, with its numbers

### ✅ The owner-ratified old-`.set` policy — CLOSED (`ORDER-1020` item A3)

`_triage/factory_os/setfile.py` + `run_setfile_tests.py`. Design §11 decision 4 existed only as
prose until now.

- **5 criteria × (attack + specificity) = 10 green · 5/5 mutation probes DETECTED**
- **Measured on the real repo** — 50 template `.set` files whose build tag is certain:
  **42 `PARTIAL`** (refused loudly, missing keys named) · **8 `LOADS`** · **0 `UNKNOWN_KEY`**
- 🔴 The **unknown-key branch is `UNTESTED` on real data** — fixtures and one deliberate
  cross-build probe only. Written up as `UNTESTED`, not passed.
- Migration observed end to end on `ea_template/sets/B14_AB_on.set`: 57 kept + 59 filled + 0
  unmappable → a new full-surface file that loads; run twice, it **REFUSES** rather than
  overwriting.

<sub>⚠️ A wider heuristic scan (162 files, build tag guessed from the filename) reported 23
`UNKNOWN_KEY`. **Do not quote it** — the pattern matched standalone-EA `.set` files that belong to
no Boss build, so the checker was correctly refusing files it was wrongly given.</sub>

### ✅ Boss_14: **116 visible inputs → 38 reachable** (`ORDER-1020` item A2's precondition)

`architecture.py` · `capability.py` · `activation.py`, caged by `run_activation_tests.py`
(**7 criteria × 2 = 14 green · 7/7 mutation probes DETECTED**).

Design §5.3 targets `Operator ≤ 40`. **38** clears it, and it is *derived* — the answer to *"can
this input change anything at all under this config"* — not a list of dials someone judged
important. Under the `B14-H01` config the count is **38** again with the reason split moving
30 / 48, which is the point: it is a function of the config, not a constant.

🔴 **The cage's load-bearing criterion is A6, and it asserts in BOTH directions.** A classifier
that calls everything unreachable passes every completeness check and produces a beautifully small
Operator surface. So the SL dials must go dark at `SLMode=SL_NONE` **and come back** at `SL_ATR` /
`SL_STRUCT_DONCHIAN` (memory `inert-axis-fake-plateau`).

### ✅ `ORDER-1022` — a cage that read the ledger more narrowly than the guard it tests

Found by it failing on a healthy repo, the first commit after order numbers crossed 999.
`run_front_guard_evidence_tests` matched reserved blocks with `\b(\d{3})-(\d{3})\b` while
`check_order_collision.ps1:329` uses `(\d+)-(\d+)`. With only four-digit blocks ACTIVE the suite
found none, concluded *"no ACTIVE lane"*, took its `900-998` fallback and handed criterion **B0** a
probe id outside every reserved block. **The symptom looked like a guard refusing a legitimate
commit; the defect was the cage holding a second, narrower parser of a file the guard already
parses.** Fixed by sharing the guard's pattern verbatim.

## What did NOT land, in dependency order — all on `ORDER-1020`

1. **`factory/hypotheses.jsonl`** — B14-H01 / B14-H02. §8.1 supplies the causal claim and the
   falsifier and §8.6 requires the rows; `preregistration_ref` points at `ORDER-1020`, which
   carries them (**the registry must not copy them**). Every field is now computable except the
   `OwnerRef` pins, which need `commit_oid` / `blob_oid` / `raw_sha256` from git.
2. **`factory/parameter_bindings.jsonl`** — 116 rows under `B14-H01-r1`. **Only the 38 reachable
   inputs need hand-authored `role`/`surface`**; the other 78 fall out of `activation.classify()`
   as `role=INACTIVE, surface=HIDDEN`.
3. **`scripts/param_registry_check.ps1`** — the §5.4 state-table criteria, plus
   `optimize_stage != UNKNOWN` on every `surface=OPERATOR` row, plus the `Operator ≤ 40` count.
4. **`docs/PARAM_REGISTRY.csv`** — the three contract columns it lacks (`display_label`,
   `enum_name`, `precedence_owner`). The first two are mechanical.

## 🔴 Two decisions for the owner (or a follow-up order) — found, recorded, NOT acted on

Both are disagreements between the **generated contract** and the **shipped repo**, and nothing
checks the CSV against that table, which is why they could disagree at all. Changing the CSV to
match would silently change what `registry.py` and `optimize_guard` decide — which S7's own
prohibitions forbid.

| | contract says | repo ships | who reads it |
|---|---|---|---|
| `classification` | `OPERATOR / TUNING / OVERRIDE / DEAD` | `ACTIVE / INACTIVE / OVERRIDE / COMPATIBILITY` | `registry.py:136` reads `INACTIVE` **by name** |
| column names | `unit_true` · `coupled_with` | `unit` · `coupled_parameters` | §4.2 *also* requires existing columns to keep their meaning |

## Two things the build produced rather than assumed

- **A capability selector cannot belong to the capability it selects.** `LotProg` decides whether
  `LAB_CAP_LOTPROG` is on; owned by that token, turning the capability off would `const` away the
  input that decides it and the wrapper could never be configured back. Selectors are
  chassis-level by construction.
- **"enabled unless off" is not the only shape.** `Recovery` is off at exactly one value of
  `RecoveryMode`; `PriceAction` is reachable at exactly **one** value of `StackConfirm` and
  unreachable at the other four. A single `!= off` form kept a whole module's inputs visible and
  sweepable under three values that cannot run it.

## Lane hygiene — a three-way block collision, and what it says

This lane reserved **1000-1009** at 08:38, correctly derived (highest in use anywhere = `950`,
every block above it held by a CLOSED lane). A parallel `OPERATOR` lane then reserved the **same
block** at `70c43c49` and used `ORDER-1000`. `check_order_collision` caught it — but at **commit
time**, after the number had been written into ten files. Renumbered to **1020-1029**, 21
references swept.

**A reservation is true only at the instant it is committed, and nothing re-checks it between then
and first use.** Two lanes each doing the derivation correctly still collided. The `ICHIBT` lane
reports the same collision from its side.

<sub>Collateral: the renumber sweep touched three references in the parallel lane's `ORDER-1000`
row (lines 982, 1029, 1038). **Restored byte-for-byte** in `021f3729`.</sub>

## Cage state at close

- fast tier **green**, 19 suites, `0 failed` · per-path budget **22.4s of 65.0s** (42.6s headroom)
- two suites added, both measured before adding per `ORDER-673`:
  `run_setfile_tests.ps1` **0.4s** · `run_activation_tests.ps1` **0.4s** (1.3s standalone)
- **`tpl_regression` was NOT run and was NOT owed** — this lane made **zero** `ea_template/**`
  edits. The MT5 lane 1 pin was declared for S8's parity harness, which did not start; **no tester
  run happened, and no number in this handoff comes from one.**
- **No EA verdict issued.** This session produced machinery.

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| old-`.set` fail-loud + migration tool, 42 real fires | DONE |
| Boss_14 reachability 116 → 38, caged | DONE |
| cage/guard ledger-parser mismatch | ORDER-1022 |
| hypotheses.jsonl + parameter_bindings.jsonl + param_registry_check + the 3 CSV columns | ORDER-1020 |
| Thin Wrapper generator + the 7-point parity harness | ORDER-1021 |
| `classification` vocabulary and `unit_true`/`coupled_with`: contract vs shipped CSV | ORDER-1020 |
