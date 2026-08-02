# Codex blind audit brief — Factory OS slices **S7** and **S8** (generator half)

> Written 2026-08-02 by lane `S-2026-08-02-SCRUT78B`, after three `/scrutinize` rounds by the
> author. **You are the independent brain.** Do not read the author's own review conclusions as
> settled — they are listed at the end precisely so you can attack them, not so you can skip them.
>
> Design §10 assigns S7 and S8 to **"Claude writes · Codex audits"**. This is that audit.

---

## 0. What you are auditing, in one sentence

Boss_14's **116 visible EA inputs** were reduced to a **derived** Operator surface of **18**, by a
chain that decides — per hypothesis — which inputs can change anything, which become `const`, and
which the optimizer may sweep; plus a generator that emits a Thin Wrapper from those same
declarations.

**The stake is not tidiness.** This chain decides what a compiled trading binary contains and what
an optimizer is allowed to sweep. A wrong "unreachable" makes a live dial a `const` at its default.
A wrong "reachable" hands the optimizer a dimension that cannot move the result — the inert-axis
fake plateau this repo has already been fooled by.

## 1. Read these, in this order

| | |
|---|---|
| `_triage/EA_LAB_FACTORY_OS_DESIGN.md` | **§5.2–5.6** (wrapper, allowlist, state table, parity, fingerprint) · **§3.1–3.2** (lifecycle) · **§8.1–8.6** (the pilot and its checklist) |
| `_triage/factory_os/CONTRACTS.md` | `Hypothesis` · `ParameterBinding` · `OwnerRef` · `META_parameter_registry_columns` · `META_parity_cases` |
| `CLAUDE.md` | the **VERDICT GATE**, especially the ENGINE-EDGE five cage conditions and the guard clause (*a guard reported without a fire count is `UNTESTED`*) |
| `AGENT_TASKBOARD.md` | rows **`ORDER-1020`** (S7) · **`ORDER-1021`** (S8) · **`ORDER-1030`** · **`ORDER-1031`** |

## 2. The artifacts

**New modules** (all under `_triage/factory_os/`)

| file | what it decides |
|---|---|
| `architecture.py` | the 16-hex `architecture_digest` every `Hypothesis` requires — nothing produced one before |
| `capability.py` | which `LAB_CAP_*` modules a pinned config enables; also `module_version` and `stability` |
| `activation.py` | **per-input reachability** for `LAB_ENTRY_14`, encoding `docs/PARAM_REGISTRY.csv`'s `active_when` prose as predicates |
| `hypothesis_b14.py` | the two hypotheses as DATA: pinned config, locked selectors, and the per-parameter role/surface/stage/range decisions |
| `gen_registry_rows.py` | joins decided + derived → `factory/hypotheses.jsonl` and `factory/parameter_bindings.jsonl` |
| `gen_wrapper.py` | the Thin Wrapper + its allowlist header |
| `setfile.py` | the ratified old-`.set` policy: fail-loud reader + migration tool |
| `check_param_surface.py` | design §5.4 state table, criteria **P1–P6** |
| `check_wrapper_gen.py` | the generated wrappers, criteria **W1–W5** |

**Suites:** `run_activation_tests.py` (8 criteria × attack+specificity + 8 mutation probes) ·
`run_param_surface_tests.py` (9 attacks + 2 message criteria) · `run_wrapper_gen_tests.py` (9
attacks) · `run_setfile_tests.py` (5 × 2 + 5 mutation probes).

**Modified:** `preset.py` (`Surface` now carries its enum table) · `registry.py`
(`canonical_build_tag`) · `run_schema_fixtures.py` (live rows batched + chunked) ·
`scripts/param_registry_check.ps1` (now runs the state table) · `scripts/_test/run_registry_tests.ps1`.

**Data:** `factory/hypotheses.jsonl` (2 rows) · `factory/parameter_bindings.jsonl` (232 rows) ·
`ea_template/generated/**` (2 wrappers + 2 allowlists).

## 3. The measured claims — refute these

Each is a claim the author believes. Your job is to find the input, state or path that breaks it.

| # | claim | where it is asserted |
|---|---|---|
| C1 | Boss_14's 116 inputs reduce to **38 reachable**, and to **31 visible / 18 OPERATOR** under `B14-H01-r1` | `activation.classify` + `gen_registry_rows.binding_rows` |
| C2 | **zero** OPERATOR rows carry `optimize_stage=UNKNOWN` | `check_param_surface` **P3** |
| C3 | the stored rows are exactly what the generator produces from this snapshot | **P5** |
| C4 | the wrapper contains **zero logic** and regenerates **byte-identically**; it compiles **0/0** | **W1/W2**, and a real MetaEditor run |
| C5 | one configuration in **two spellings** (`RecoveryMode=80` vs `REC_NONE`) gives one digest, one token set, one reachability answer | `run_activation_tests` **A8** |
| C6 | an old `.set` **fails loudly**: 42 real fires on 50 template files | `run_setfile_tests`, and a census |
| C7 | an `engine_edge` hypothesis cannot register with a cap that does not cap | `gen_registry_rows.LOSS_CAPS` |

## 4. Where the author thinks it is weakest — start here

1. **`activation.py`'s table is HAND-ENCODED from prose.** 116 entries, each transcribing an
   `active_when` cell. A single wrong gate silently moves an input between `const` and dial. Nothing
   cross-checks the encoding against the code the prose describes. **Spot-check the gates against
   `ea_template/core/*.mqh` directly** — especially `_33_AdaptiveON` (claimed to matter under
   `EXIT_ATR_TP` as well as `SL_ATR`), the `_2_Partial*` chain, and `_9_Step*`.
2. **`LOCKED_SELECTORS` is a judgement, not a derivation.** Ten inputs are called "mechanism
   selectors" and become `const`. Is `_14_Direction` really a dial and not a selector? Is
   `StackConfirm` really architecture?
3. **`safe_range` values are pre-registered starting grids, not measured.** They are the author's
   numbers. Do any of them exclude the region a sweep would actually want?
4. **The ENGINE-EDGE ceilings** (`_32_SL_BalPct ≤ 15.0`, `RC_AcctDDLimitPct ≤ 12.0`) are read out
   of `CLAUDE.md`. Is `RC_AcctDDLimitPct = 12.0` the right reading of a **demo-kill** bar, or is it
   conflating a judge criterion with an EA-side halt?
5. **`module_version` is the chassis version (`2.00`) for every module.** Honest, but it means two
   different `Recovery.mqh` revisions share a `module_version`. Does design §3.2's
   `EXPERIMENTAL → CERTIFIABLE` transition survive that?

## 5. Known limits the author states rather than hides — confirm or refute each

- **`check_param_surface` P5 compares INDEX stores against a WORKTREE generator** (python imports
  from disk). It now *detects* the mixed vintage and says `CANNOT BE PERFORMED`. **The same shape
  exists in `check_input_surface_gen.py` (ORDER-710/730) and is NOT fixed there.** Is the detection
  sufficient, or does the real fix (executing the generator from the index) have to land?
- **`check_param_surface` does not drive `optimize_guard`.** That half is in
  `run_registry_tests.ps1`. Is the split honest, or is there a claim nothing tests?
- **The 7-point parity contract (§5.5) is NOT implemented.** No behavioural claim about the
  generated wrapper exists. Does any file imply one?
- **`_32_SL_Money` has no enforced ceiling** (absolute money). Can an `engine_edge` hypothesis use
  it to satisfy the cage while the other two caps stay at 0?
- **The unknown-key branch of the `.set` reader is `UNTESTED` on real data** — 0 of 50 template
  files carry one. Written up as `UNTESTED`, not passed. Agree?

## 6. What the author already found and fixed — attack the FIXES, not the bugs

These are listed so you do not spend time re-finding them. **A fix is a new claim; audit it.**

| round | defect | fix |
|---|---|---|
| 1 | one configuration had **two spellings**; every consumer compared raw strings. Same architecture → two digests; `RecoveryMode=80` enabled `LAB_CAP_RECOVERY` **at its OFF value** | canonicalise through `preset.render_value`, which REFUSES an unknown symbol; `Surface` carries the enum table |
| 1 | the migration CLI filled defaults **symbolically** into a `.set` the terminal parses numerically | render defaults to `.set` form |
| 2 | **P5 excluded the whole `OwnerRef`** → a `definition_ref` pointing at the wrong FILE was invisible | exclude only `commit_oid`/`blob_oid`/`raw_sha256` |
| 2 | **W2 accepted any `#include`** → logic by reference | allowed set derived from what the generator emits |
| 2 | both `Hypothesis` rows said `status: DRAFT` while their wrappers existed | new **W5**, which also re-measures §3.1's precondition |
| 3 | a **stale `.pyc`** served a mutated decision table after the source was restored (same size, same second) and baked a decision nobody made into the canonical store — **P5 could not see it, because it regenerates through the same import** | re-execute the table from its own text and compare against the import |
| 3 | the ENGINE-EDGE cage checked a cap was **reachable**, never its **number**; `_32_SL_BalPct = 9999` passed | per-cap ratified ceilings; `_2_MaxHoldBars` removed as a **time** stop |

## 7. How to reproduce everything

```bash
tools/python312/python.exe _triage/factory_os/run_activation_tests.py --mutate
```
```bash
tools/python312/python.exe _triage/factory_os/run_param_surface_tests.py
```
```bash
tools/python312/python.exe _triage/factory_os/run_wrapper_gen_tests.py
```
```bash
powershell -NoProfile -File scripts/param_registry_check.ps1
```

`scripts/_test/run_fast_cages.ps1` runs the whole tier. `check_state.ps1` must stay CLEAN.

## 8. What a finding must contain

`file:line` · the **input or state** that exposes it · the consequence in terms of *what the binary
does* or *what the optimizer is allowed to sweep* · and, where you can, a **command that
reproduces it**. A finding that cannot be reproduced is a hypothesis — say so, and it is still
worth filing.

**Do not propose the parity harness** — it is `ORDER-1021`'s remaining work and is already specified.
