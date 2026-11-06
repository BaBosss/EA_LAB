# new_entry.py - add a Boss V2 entry with one command

Tool: `scripts/new_entry.py` - tests: `scripts/_test/test_new_entry.py` - design: `docs/superpowers/specs/2026-11-05-new-entry-tool-design.md`.

## When to use it

An **entry-only** port: the entry module defines `EntrySignal Entry_Evaluate()` (and optionally `*_Init`,
`*_Deinit`, an entry-owned `*_OnTick`), and every shared setting it needs already exists in the chassis.
Anything else (a new execution primitive such as `Exec_OpenIntent` for builds 27/29, a changed shared default, an edit
to `Execution.mqh` / `Stack.mqh` / `ExitManager.mqh`) is manual core work and goes through the FULL path of
`AGENTS.md` §1.0. Adding an entry to the shared core files is itself a FULL-path change: get the owner's OK before
pushing, the tool does not replace it.

## Steps

1. Cut a lane worktree from `origin/master`, claim a Registry lane (paths as an in-process array, never `"a,b"`),
   provision Python: `. .\scripts\use_python.ps1; Assert-PortablePython -Provision`. The worktree must be clean.
2. Take the build number from `factory/magic_allocations.jsonl` (never from a local numbering) and the magic
   `99<NN>01` unless the allocation says otherwise.
3. Write the three source files (anywhere, e.g. the evidence folder):
   - `Entry_<Name>.mqh` - the entry module, ASCII only.
   - `inputs.mqh` - plain lines only, each `input <type> _<NN>_<Name> = <default>; // label`, optional `input group "..."`.
     No `#ifdef`, no guard pairs (the tool writes the `LAB_CONST_*` pairs and the `[Pnnnnn]` tags).
   - `manifest.json`:

```json
{
  "build": 30, "name": "DonchianPullback", "title": "Donchian breakout + EMA pullback",
  "entry_source": "Entry_DonchianPullback.mqh", "inputs_source": "inputs.mqh",
  "init_call": "DonchianPullback_Init()", "deinit_call": "DonchianPullback_Deinit()", "own_ontick": null,
  "stack": {"mode": "STACK_SINGLE", "confirm": "CONF_DISTANCE", "note": "single order per signal"},
  "magic": 993001, "preset_overlay": {"_30_Lookback": 25},
  "provenance": "ported from <source>; sha256 recorded automatically"
}
```

4. `python scripts/new_entry.py apply --manifest manifest.json` (compiles by default; `--no-compile` to skip)
5. Read the receipt, review `git diff`, commit (the tool never commits), then the normal review and push steps.

## What the tool does and proves

Writes the wrapper, copies the entry module (with the sha256 of each source), inserts only `#ifdef LAB_ENTRY_<NN>`
gated blocks into `Inputs.mqh` and `LabCore.mqh`, adds the `wrapper_owners.csv` row, reserves the magic through
`magic.py`, regenerates `InputSurface_gen.mqh`, `LockedConstants_gen.mqh`, `PARAM_REGISTRY.csv` (rows + all line
citations) and `PARAM_LINKAGE.md`, and builds the regression defaults preset. Then it runs:

| Check | Meaning |
|---|---|
| neutrality proof (structural) | only the tool's managed paths changed; in each of the four core files, removing the inserted `#ifdef LAB_ENTRY_<new>` blocks and the fallback-chain wrap gives HEAD back byte for byte (blank lines and the tool's marker comments aside); the new tag and the new file names appear nowhere in the HEAD tree; HEAD has no `__LINE__` and the changed files have no line continuation. Such a block is skipped whole by every existing build whatever macros or includes are in play. A second, informational layer (annotated-condition model) must agree. It is **not** a compiler-equivalence claim: the authoritative gates remain `tpl_regression -DeclaredCoreDelta`, per-build compile 0/0 and the parity run |
| `check_input_surface_gen`, `param_registry_check`, `magic verify`, `run_preset_tests` | the existing cages |
| `check_template_presets --only` | the new build's preset covers its surface (family-wide run is red at HEAD for Boss_14/16, unrelated) |
| MetaEditor compile (default on; `--metaeditor <path>` if not `D:\Meta 5`) | 0 errors / 0 warnings in an isolated copy |

Any failure restores every touched file and removes every created file (`--keep-on-fail` keeps them for debugging).
Output is deterministic: reset and re-run gives a byte-identical diff.

## Limits to know

- `tpl_regression -DeclaredCoreDelta` and the parity run (R3) are **not** part of the tool; run them as the process
  requires. The proof here is static (preprocessor), not a tester run.
- Each apply shifts line citations in `PARAM_REGISTRY.csv` (hundreds of lines change). Two lanes adding entries will
  conflict there: land one, rebase the other, re-run `apply` on the clean rebased tree.
- `prove` can be run alone at any time (`python scripts/new_entry.py prove`); `selftest` shows the proof can fail.
- The tool inserts after fixed anchors in `Inputs.mqh` / `LabCore.mqh`. If those lines are ever edited, `apply`
  refuses ("anchor not found exactly once") instead of guessing; update the anchors in the tool and its tests.
