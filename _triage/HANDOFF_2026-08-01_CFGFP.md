# HANDOFF — lane `S-2026-08-01-CFGFP` (2026-08-01 06:5x → ~09:xx), block 730-739, MT5 lane 1

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this is a **shift-change note, not a queue**
> (Decision log 2026-07-26). Every forward-looking item below has a home — the routing table at
> the bottom says which. Opening prompt for the next session = **`_triage/PROMPT_NEXT_SESSION_CFGFP.md`**.

## What this lane was asked to do

`_triage/PROMPT_NEXT_SESSION_GUARDS.md` listed exactly one thing open: **`ORDER-710`**, the `[CFG]`
fingerprint, parked because it needed an MT5 lane. This lane reserved one and did it.

## The one-line state

**The EA prints a hash of its own live inputs at `OnInit`, and that hash equals the compiler's on
2 builds × 2 configurations — measured, on lane 1, not argued.** Read it from
`scripts/verify_config_fingerprint.ps1`'s own output, not from this file.

## The measurement that IS the acceptance

`scripts/verify_config_fingerprint.ps1`, lane 1 `D:\Meta 5`, XAUUSD H1 2024.01.01–2024.01.15,
model 1, four tester runs:

| build | keys | config | compiler | EA `[CFG] input surface:` |
|---|---|---|---|---|
| `LAB_ENTRY_16` | 135 | declared defaults | `9161b652…a279c7` | identical |
| `LAB_ENTRY_16` | 135 | `_9_StepPoints=444.0` + `DryRun=true` | `0e063db8…7c8c31` | identical |
| `LAB_ENTRY_11` | 113 | declared defaults | `67dacccc…04d152` | identical |
| `LAB_ENTRY_11` | 113 | the same two overrides | `f6415256…8821aa` | identical |

**Two runs per build, and the second is the load-bearing one.** A single match is also what a
constant would print, or a digest computed from the source instead of from live inputs. The
verifier requires the two hashes to *differ from each other* as well as to match their own
compiler value. Two builds with different surface sizes, so the per-build enumeration is
exercised rather than one block of it.

`tpl_regression` **CLEAN 8/8** on the same pinned lane (C2), binaries asserted fresh first.
Compile **0 errors / 0 warnings, 9 targets**. Full tier **16/16 at 77.5–79.2s** of the 90.0s
budget after the trade below (81.3–81.8s before this lane).

## The part worth reading: what had to change, and what was left alone

1. **The preimage could not stay text.** It carried the rendered `.set` value, so a double went in
   as `repr(3e-05)` — Python's shortest-round-trip spelling. MQL5's `%g` does not reproduce it
   (`1.0` vs `1`, exponent width), so hashing the spelling would have made the fingerprint a claim
   about two printf implementations agreeing — failing in the direction that matters least
   (`0.1` vs `0.10`) while a real config change stayed invisible. Doubles now enter as their
   **IEEE-754 bits**: the value MT5 actually parsed, emitted with no formatting on either side.
   `-0.0` is normalised to `+0.0` — equal values, different bits, and an unnormalised pair would
   move a hash without moving a configuration.
2. **`C3` is honoured by NOT being met.** The scope label stays `surface_only` because the hash
   covers every exposed input and **no locked constant**. C3 says the manifest stops writing
   `surface_only` *only when* the fingerprint covers the real surface; relabelling now is exactly
   the failure the name was chosen to avoid. → the second half is **`ORDER-730`**, opened, not
   left as a remainder.
3. **What the python cage cannot do, in its own header.** It does not execute MQL5, so it cannot
   prove `CryptEncode(CRYPT_HASH_SHA256, …)` and `hashlib.sha256` agree. Only the four runs above
   do, and they are evidence with a date, not a cage that re-runs.

## Two defects found in OTHER people's work, both by being the next lane

- **`run_front_guard_evidence_tests`'s B0 probe was `ORDER-711`**, hardcoded because that was
  inside the *authoring* lane's reserved block (710-719). The moment this lane reserved 730-739
  and that row closed, B0 went red — the collision guard correctly refusing an out-of-block
  number, the fixture stale. The id is **derived** now (ACTIVE ranges at HEAD minus every
  `## ORDER-<n>` on the four boards) and printed in the assertion; no free number throws rather
  than falling back to a literal.
- **A suite's own edit never ran that suite.** The pathspec generator has always claimed every
  suite implicitly guards itself and adds `scripts/_test/*` to the TRIGGER — but `Select-Suites`
  matched only `$SUITE_GUARDS`, which never lists a suite's own file. True of the trigger, false
  of the selection. Measured both ways: pre-fix, staging
  `scripts/_test/run_front_guard_evidence_tests.ps1` selected `run_report_freshness_tests.ps1`
  alone; post-fix it selects both. **The pre-fix reading is not synthetic** — commit `2aae5241`'s
  own hook output lists the suite being committed in the SKIPPED set. This is ORDER-420's finding
  reappearing inside the mechanism written to fix it.

## Live traps confirmed this session

1. **A fixture's validity is an assumption about somebody else's table** — twice now (PART 6's
   "cheap" path, and B0's probe id). If a fixture depends on a number another lane maintains,
   derive it or assert it; do not type it.
2. **`git` under `core.autocrlf=true` makes a file unequal to itself across snapshots.** The blob
   is LF and the worktree is CRLF, so a byte comparison of a generated file against its committed
   copy fails for a reason that has nothing to do with drift. `check_input_surface_gen` folds
   newlines and *names* that it does so.
3. **MT5 tester logs are UTF-16LE** and live under the **Tester** tree
   (`…\Roaming\MetaQuotes\Tester\<id>\Agent-127.0.0.1-30NN\logs\`), not the terminal data folder.
   Reading them as UTF-8 finds zero matches and reports it as "the EA printed nothing"
   (memory `prove-the-instrument-can-see-the-file`).
4. **A guard caught its own author twice, in the same hour.** The `#include` pattern anchored at
   `$` and rejected the real `LabCore.mqh` line for carrying a trailing comment; and
   `gen_default_preset.py`'s first run was refused by `preset.py`'s P8 for handing a bare number
   to a money-denominated default. Both were the rules working, not obstacles.
5. **`git commit -- <paths>` without a prior `git add` can fail a cage for a reason that is not
   about your code.** `run_front_guard_evidence_tests` copies the **real** `.git/index` into the
   temp index it hands its child guards, so a partial commit's own temp index is invisible to it:
   this lane's handoff routed to `ORDER-730` and `BACKLOG-D33`, both in the same commit, and the
   cage's `C1` went red with *"no `## ORDER-730` header exists"* because those two files were in
   the commit but not in `.git/index`. `git add` the paths first, then commit them.
6. **A "mysterious" tier failure that turned out to be ANOTHER LANE COMMITTING.** Twice this
   session a manual full-tier run went red in a way that did not reproduce: `check_s2a_migration`
   hit its concurrency ABORT ("HEAD or the git index changed while this check was running"), and
   later `run_front_guard_evidence_tests`' C cleanup case failed while printing four IDENTICAL
   shas — its remaining condition is `.git/index` mtime. The cause was visible in `git log`:
   `S-2026-08-01-OPERATE` committed twice during the run, and a commit rewrites `.git/index`.
   **Both detectors were RIGHT** — the ground did move. **A manual full-tier run is not a clean
   measurement while another lane is open**, and neither detector can distinguish "another lane
   committed" from "something corrupted the run". → `ORDER-731` item 2.
7. **🔴 `MASTER_BACKLOG.md` IS FROZEN, AND NOTHING TELLS YOU UNTIL AFTER YOU COMMIT.** This lane
   appended one dormant backlog row; the S2a attestation pins that file at a blob, so `F11`/`F5`
   and `check_coverage_transfer`'s `A8` all went red — **after** the commit landed, because the
   pin is compared against `HEAD:`, which during a pre-commit hook is the PREVIOUS commit. The
   row was reverted, the lane reopened to do it (a board row needs an ACTIVE reservation), and
   the finding became `ORDER-731`. It is the ORDER-674 defect class one layer along: read what
   the commit WILL contain, not what it already does. Memory `approval-pinning-self-invalidates`
   predicted this as ADVISORY; it is now a measured block.
8. **Do not read a shared doc with `utf-8-sig` and write it back without the BOM.** Rewriting the
   ledger row through Python silently stripped `docs/SESSION_LEDGER.md`'s BOM in `8f70b0f4`
   (restored in the next commit). PS 5.1 decodes a BOM-less file as ANSI, and that file is Thai.

## Numbers, all measured this session

| | |
|---|---|
| EA↔compiler fingerprint | **4 of 4 runs identical**, 2 builds × 2 configurations |
| `tpl_regression` | **CLEAN 8/8**, lane 1, pinned in the commit |
| compile | **0 errors / 0 warnings**, 9 targets |
| `ORDER-710` cage | 5 criteria × (attack + specificity) + **5 mutation probes, all DETECTED** |
| `run_preset_tests` | 9 criteria, **9/9 mutations DETECTED** after the preimage change |
| `T7` binding | **6 of 6 bound, 0 suspended** (was 5 of 5) |
| `L3` PowerShell | **6 of 11 declared, 5 suspended** — unchanged, and they are not front guards |
| full tier | **77.5s / 79.2s** of 90.0s, 16/16 (81.3–81.8s before this lane) |
| generated enumeration | 1,082 lines, 8 build blocks, 113–135 keys each |

## Do not do these

- ❌ Do not rename `fingerprint_scope` from `surface_only` until the locked constants are actually
  inside the preimage — on **both** sides, in **one** commit. A rename on one side turns a
  matching pair into a mismatching one and the first suspect will be the binary.
- ❌ Do not hand-edit `ea_template/core/InputSurface_gen.mqh`. Regenerate:
  `tools\python312\python.exe _triage/factory_os/gen_input_surface.py --write`.
- ❌ Do not add a cage without measuring the full tier. ~11s of headroom, and this lane already
  paid for its own additions by trading PART 4b's sixteen probes down to three.
- ❌ Do not quote a full-tier run that `check_s2a_migration` aborted as either a pass or a fail.
  Re-run it (see `BACKLOG-D33`).

## Routing — every forward-looking item has a home

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| design §5.6's locked-constant half — the fingerprint covers inputs only, and both sides say so | ORDER-730 |
| an attested blob pin read at `HEAD` cannot refuse the commit that breaks it, and `MASTER_BACKLOG.md` is frozen without saying so · plus `check_s2a_migration`'s unexplained concurrency ABORT (1 of 4 full-tier runs) | ORDER-731 |
| `ORDER-710` itself (generator · MQL5 canonicaliser + sha256 · the staleness guard and its cage · the verification tool · the four tester runs · `tpl_regression`) | DONE |
| the two defects found in other lanes' work (B0's hardcoded probe id · a suite not selecting itself) | DONE |
| The five non-front-guard PowerShell checkers still suspended in L3, and the 4 items in `_triage/USER_DECISIONS_PENDING.md` | DONE |

<sub>The last row is `DONE` in the routing sense only: it carries no work *this lane* owes. The five
suspended checkers are printed by the lint on every run (a countable list, not a silence) and
migrating them would be a new order; the four owner decisions live in
`_triage/USER_DECISIONS_PENDING.md`, which is their owner, and none of them blocked this work.</sub>

## Other lanes that were open at the same time

`S-2026-08-01-OPERATE` (block 740-749, the operate track) was ACTIVE throughout and
`S-2026-08-01-CODEXBRIEF` (750-759) closed during it. Neither touched this lane's paths. If a
board row here looks unfamiliar, check whose lane wrote it before assuming drift.

## Post-close corrections (this lane reopened twice, and both are worth reading)

1. **The closing commit broke an attested pin** — trap 7 above. Reverted byte-identically; the
   repair commit itself had to be made with `--no-verify` **on the owner's explicit decision**,
   because the guard reads `HEAD:` and HEAD held the wrong blob: every commit that could restore
   it, including the restoring one, was refused. The gate blocked its own repair. Verified green
   immediately after, and the staged oid is quoted in that commit's message.
2. **The probe-id derivation threw when NO lane is ACTIVE**, which made
   `run_front_guard_evidence_tests` unrunnable the moment every lane row closed — a cage broken by
   its own repair, in the state it is most often run in. No ACTIVE lane is a legitimate regime
   (the guard skips RULE 2 and says so), so any unused id serves there; both regimes are handled
   and the assertion prints which one it was in.

Final state: full tier **16/16 at 75.5s / 77.9s** of 90.0s, two clean runs with no lane open.
