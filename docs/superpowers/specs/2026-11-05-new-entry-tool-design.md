# new_entry.py - one-command additive build scaffold (design)

- **Date:** 2026-11-05 - **Status:** owner chose option C ("ตัวสร้าง build อัตโนมัติ") in chat 2026-11-05.
- **Lane:** `claude-new-entry-tool-20261105`, base `origin/master` `d4da20d7`. Tooling only: this change edits no
  file under `ea_template/core/`. Using the tool on a real port is a separate change and follows the FULL path
  of `AGENTS.md` §1.0 (shared core touched).

## Problem (measured on origin `d4da20d7`)

Adding one entry to Boss V2 touched 11 files (`8da04fc7`), five entries 26 files (`baabe23e`). About 5 are hand
edits (wrapper, `Entry_*.mqh`, `Inputs.mqh` +76 lines, `LabCore.mqh` +27 lines over ~7 sites) and 6 are generated
(`InputSurface_gen`, `LockedConstants_gen`, `PARAM_REGISTRY`, `PARAM_LINKAGE`, `wrapper_owners`, regression preset).
`PARAM_REGISTRY.csv` is rewritten by 473-537 lines per commit (line refs), so two lanes adding entries conflict.
The recipe of `baabe23e` lives only as one-off scripts (~540 lines) in `D:\EA_LAB_CONTROL\evidence\...`.

## Decision

Turn that recipe into a repo tool. Keep the existing source layout, the single `Inputs.mqh` surface parser
(`preset.parse_surface`, read by ~30 Factory OS tools) and every existing build byte-identical. Not changed:
`.set` identity, magic rules, R18 observer, `tpl_regression`, VPS binaries.

## Interface

```
python scripts/new_entry.py apply  --manifest <entry.json> [--root <worktree>] [--compile]
python scripts/new_entry.py prove  [--root <worktree>]            # neutrality proof, HEAD vs working tree
python scripts/new_entry.py selftest                              # the proof must be able to fail
```

Manifest (JSON, paths relative to the manifest): `build`, `name`, `title`, `entry_source`, `inputs_source`
(plain `input` lines, no guard pairs), `init_call`, `deinit_call`, `own_ontick`, `stack{mode,confirm,note}`,
`magic`, `preset_overlay`, optional `extra_files`.

## What `apply` does (in order, all-or-nothing)

1. Validate: build number unused, input prefix `_NN_`, names unique, ASCII only, anchors in core files unique.
2. Snapshot every file it may touch; on any failure restore them and delete created files.
3. Write wrapper, copy entry module (sha256 of each source in a provenance header), write `Inputs.mqh` blocks
   (fallback-chain guard, stack selectors, entry inputs each with its `LAB_CONST_*` guard pair and `[Pnnnnn]` tag),
   `LabCore.mqh` hooks (include, init, deinit, entry-owned OnTick), `wrapper_owners.csv` row.
4. Run the existing generators: `gen_input_surface --write`, `gen_locked_constants --write`, registry rows,
   `param_registry_fix_lines.ps1`, `gen_param_linkage.ps1`, `gen_default_preset` (overlay + `_0_Magic`), magic
   reservation through `magic.py`.
5. Run the cages and print a receipt: neutrality proof (every existing build sees byte-identical active source in
   every changed file; no existing build includes a new file), `check_input_surface_gen`, `param_registry_check`,
   `check_template_presets`, `magic verify`, `run_preset_tests`; optional isolated MetaEditor compile 0/0.

## Out of scope (refused, not guessed)

An entry that needs a new execution primitive, shared-input default change or any edit outside the five hook
sites (as builds 27/29 needed `Exec_OpenIntent`) is refused with the reason. That stays manual core work.

## Compatibility with later plug-in design (option A)

The manifest is the same information a self-registering entry folder would carry, so it can become that folder's
descriptor later without changing authors' inputs.
