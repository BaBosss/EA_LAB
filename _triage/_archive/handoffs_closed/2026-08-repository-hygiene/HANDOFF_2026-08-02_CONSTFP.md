> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **shift-change note for lane
> `S-2026-08-02-CONSTFP`** — the two solo items routed out of
> `_triage/HANDOFF_2026-08-01_TEMPLATE.md`. A note, not a queue: every forward item below already
> has a row on `AGENT_TASKBOARD.md`.

# Session end — 2026-08-02, `S-2026-08-02-CONSTFP`

The user asked to continue the handed-off work. Of the previous handoff's five routed items, three
need the user at a terminal (`ORDER-510` STEP 2/3, `ORDER-941`) or are their own piece of tester
work (`ORDER-950`). This lane took the two it marked solo.

## 1. `ORDER-730` — **DONE**, all three acceptance criteria met and measured

The `[CFG]` fingerprint now covers the locked constants as well as the input surface, so
`fingerprint_scope` moved `surface_only` → **`surface+constants`** on both sides in one commit —
because it is now true, which is the condition `ORDER-710` set when it deliberately left the label
narrow.

- **C1 derived, not listed.** A locked constant = a `#define` carrying a value that reaches the
  build, where "reaches the build" is decided by evaluating the preprocessor over the include
  closure. Exemption list is empty because both halves are mechanical. Build 17 gets 24 constants,
  every other build 23.
- **C2** one commit (`ec085d69`) for both sides.
- **C3 measured on lane 1:** 4 tester runs, 2 builds × 2 configurations, EA digest == compiler
  digest every time and A≠B on both builds · `tpl_regression` **CLEAN 8/8** · compile **0/0 on 9
  targets**.
- Cage `run_input_surface_tests.py`: **9 criteria** (was 6), attack + specificity each, **all 9
  mutation-DETECTED**.

Three things the build found rather than assumed are recorded on the board row — the closure
starting at the wrong file, an inherited `#else` prohibition that was false outside `Inputs.mqh`,
and G5's "enumerated" signal matching a define the emitter always writes. Also recorded: this order
took the fast tier to **62.5s of its 65.0s enforced budget** and then paid it back to **24.9s**
(`37a936c6`) by memoising reads within one `check()` call — 917 git reads → 38.

## 2. `ORDER-761` — **NOT built, and deliberately so.** C1 is measured and it reopens the premise

C2 of that order says: *if the widened sweep lands near 66 declarations again, it has not solved
anything and should be closed the way `ORDER-732` was.* Measured: **102 new declarations** across
the six real suites (179 counting the runner, which is a measurement artifact). Not near 66 —
**above** it.

The order's premise is that declaring is cheaper than guessing because a text scan over-counts.
The measurement says the over-counting was never where the cost was: the import closure is wide (32
modules for one suite) and modules genuinely read most of the repo paths they name.

**So the next session's first task on this order is a DECISION, not a build:** is 102 more
declarations — each widening the pathspec and pulling suites onto more commits, against a 90.0s
tier budget — worth buying over the five hand-widenings it replaces? The full table, and an
explicit statement of what the proxy measurement can and cannot claim, is on the `ORDER-761` row.
**Do not start the build before that is answered**; discovering the number halfway through is how
it becomes sunk cost.

## Still needing the user (unchanged from the previous handoff)

- **`ORDER-510` STEP 2/3** — an F3 census per terminal, 4 accounts unchecked, 3 of them real money.
  Run `scripts/check_persist_legacy.ps1` against a real export **before** any binary is copied.
  Start with `415573666`, the one DEMO account still unchecked.
- **`ORDER-941`** — one Inputs-tab read per chart for `990066`/`990067`/`990068`/`990069`
  (`_06_AllowLive`, `_06_Magic` first). Ask for **one log export covering all four**, not four
  screenshots.
- ~~**`ORDER-950`** — guard G4 has still never been observed firing; route 1 is the cheap one.~~
  ✅ **route 1 done 2026-08-02** (`S-2026-08-02-SCRUT730`): `SYMBOL_TRADE_STOPS_LEVEL=1 point`
  (minDist 0.01) vs a smallest buffered SL distance of 0.919 = **91.86×**, so the
  minimum-distance branch is unreachable at the shipped buffer and `sl_invalid=0` is explained.
  Still `UNTESTED` — it explains one of four branches, and an explanation is not a sighting.
  Routes 2 (BWD window) and 3 (synthetic probe) remain open on the row if a sighting is wanted.

## Addendum — `ORDER-730` after three `/scrutinize` rounds (2026-08-02, `S-2026-08-02-SCRUT730`)

**12 further defects, only one in the hash itself.** Cage 9 → 10 criteria; the generated file
regenerates **byte-identical** after all twelve, so no tester re-run was owed — every one was in
the guarding, and the four tester runs would have looked the same with all twelve still present.
The two worth carrying forward as patterns:

- **A criterion cannot check the generator that produces the file it reads.** G4 compares the
  committed file against the generator's output, so an edit *in the generator* moves both and
  stays green — deleting `+ CFG_ConstPreimage()` produced **zero problems everywhere** while the
  EA would have hashed half the preimage under a full label. Any generated artifact needs at
  least one criterion that reads it **as text**.
- **Patterns that reject commented-out code must be written that way deliberately.** G2's include
  check anchored at the `#` and rejected a commented-out directive; its call check did not, and
  commenting out every call was ACCEPTED.

Full detail on the `ORDER-730` row.

## Verification run this session

`check_state.ps1` CLEAN. Every commit passed the full pre-commit hook, **no `--no-verify`**.
`tpl_regression` CLEAN 8/8 on the pinned lane 1 after the `ea_template/core/**` edits, with the
binaries asserted fresh. Compile 0 errors / 0 warnings on all 9 targets.

## What did NOT happen

No VPS touched. No `Boss_*.ex5` copied to any chart. No GlobalVariable read or written on a real
terminal. No `.set` changed. No EA verdict issued. No S2a bundle member, `MASTER_BACKLOG.md`,
`s2a_attestations.jsonl`, `AGENTS.md` or `PROJECT_STATE.md` touched. No `REVIEWED` written.

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| decide whether the `GUARDED_INPUTS` mechanism is worth 102 declarations, then build or close | ORDER-761 |
| `ORDER-510` STEP 2/3 (adopt-once per magic, needs terminals + owner) | ORDER-510 |
| guard G4: routes 2/3 if an actual SIGHTING is wanted (route 1 done, envelope measured) | ORDER-950 |
| four IchiADX legs silent/thin, needs user's Inputs-tab read | ORDER-941 |
| `ORDER-730` locked-constant fingerprint, C1+C2+C3 | DONE |
