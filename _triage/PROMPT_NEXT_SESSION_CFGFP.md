# Next-session prompt — `ORDER-710` is closed and scrutinized; three orders are open behind it

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **the opening prompt for the next
> session on the Factory OS track**. Written 2026-08-01, end of lane `S-2026-08-01-CFGFP`
> (including its two `/scrutinize` rounds). The previous opener
> (`_triage/PROMPT_NEXT_SESSION_GUARDS.md`) is spent — its only open item was `ORDER-710`.
> Paste the block below as the first message of the new session.

---

```
Batch closed 2026-08-01: ORDER-710 ([CFG] input-surface fingerprint). The EA hashes its own live
inputs at OnInit and the digest MATCHES the compiler's -- 2 builds x 2 configurations, four tester
runs on lane 1, re-verified byte-identical after the scrutinize changes. tpl_regression CLEAN 8/8
twice. HEAD = <run git log --oneline -1> · full tier 16/16 at 80.9-83.2s of the 90.0s budget.

Read in this order:
  PROJECT_STATE.md  §2 top entry (what the batch found, including what /scrutinize found in it)
                    + §3 (decision log, unchanged this batch)
  _triage/HANDOFF_2026-08-01_CFGFP.md  (the shift note -- the four measured hashes, why the
      preimage had to stop being text, the two defects found in OTHER lanes' work, and the
      "live traps" section, which is the part that saves time)
  docs/GUARD_SHAPES.md  (still the pre-flight for writing OR REPAIRING any guard)
  AGENT_TASKBOARD.md -- grep '## ORDER-710' for the evidence, then 730 / 731 / 732 for what is left

What is actually open (checked before writing this, not assumed):
  1. ORDER-730 -- the LOCKED CONSTANTS half of design 5.6. The fingerprint covers every input the
     build exposes and no compiled-in constant, and BOTH sides label that honestly
     (fingerprint_scope = surface_only; preset.SCOPE_SURFACE_ONLY is the named constant, and
     check_input_surface_gen G3 holds the MQL5 #define to it). preset._constant_scope() already
     renames the scope to surface+constants when it has constants, so what is missing is WHAT the
     constants are and how the EA enumerates them. Needs an MT5 lane if ea_template/core/ changes.
  2. ORDER-731 -- an attested blob pin is checked against HEAD:, so the commit that breaks it is
     never refused. Consequence you must know BEFORE you edit anything:
     🔴 MASTER_BACKLOG.md IS EFFECTIVELY FROZEN. Appending one dormant row turned F11/F5 and
     check_coverage_transfer's A8 red -- AFTER the commit landed -- and the repair commit was then
     refused by the same guard, because it reads HEAD and HEAD held the wrong blob. It took an
     owner-approved --no-verify to restore. Do not append to that file; open an ORDER instead.
     Item 2 of the same order: a tier abort that fired in 2 of 8 manual full-tier runs
     ("HEAD or the git index changed while this check was running"). One instance is explained (a
     concurrent lane committed); the other recurred with NO lane open, so something inside the
     tier itself touches .git/index. The detectors are right; the cause is not settled.
  3. ORDER-732 -- the undeclared-reference sweep cannot see a path referenced by an IMPORTED
     module, so ea_template/core/ConfigFingerprint.mqh had to be declared by hand (the fifth
     hand-widening of this trigger). C1 is to MEASURE the cost of widening before changing it;
     C3 explicitly allows "we chose not to, here is the number".
  4. Five NON-front-guard PowerShell checkers still print in L3's suspension list every run --
     read the live line, don't trust this one:
     `tools/python312/python.exe _triage/factory_os/run_guard_shape_lint.py`. Not run by the hook
     before the tier, so migrating them is a new order, not a continuation.
  5. The 4 items in _triage/USER_DECISIONS_PENDING.md -- owed to the owner, untouched, pending.

Rules that still hold (restated because they are still true):
  - Reserve a lane in docs/SESSION_LEDGER.md and COMMIT the reservation before anything. Parse
    `## ORDER-<n>` from all four board files yourself -- the ledger's foot-of-file summary is
    stale for the tenth time (BACKLOG-D29). Write the derivation as PROSE: a regex with a
    character class in that cell makes the collision guard read the class as a second reserved
    range. That happened to this lane.
  - CLOSE THE LANE ROW IN YOUR LAST COMMIT, NOT BEFORE. RULE 2 enforces reserved blocks only for
    ACTIVE rows; with none it prints "NOTE: no ACTIVE lane ..." and passes.
  - `git add` the paths BEFORE `git commit -- <paths>`. run_front_guard_evidence_tests copies the
    REAL .git/index for its child guards, so a partial commit's own temp index is invisible to it
    and same-commit destinations read as missing. This refused a commit today.
  - Budgets are ENFORCED: 65s per-path / 90s full tier. ~7-9s of full-tier headroom. A new cage
    DISPLACES something -- this lane traded PART 4b's sixteen self-selection probes down to three
    to pay for its own additions, and said so in the commit.
  - Anything GENERATED must be regenerated in the same commit as its source, and a guard must read
    BOTH at ONE snapshot. ea_template/core/InputSurface_gen.mqh is generated:
    `tools\python312\python.exe _triage/factory_os/gen_input_surface.py --write`
  - core.autocrlf is true here: the blob is LF, the worktree CRLF, so a file is not byte-equal to
    itself across snapshots. Fold newlines and SAY you folded them.
  - Do NOT read a shared doc with utf-8-sig and write it back without the BOM. That silently
    stripped docs/SESSION_LEDGER.md's BOM today; PS 5.1 reads a BOM-less file as ANSI and that
    file is Thai.
  - MT5 tester logs are UTF-16LE and live under ...\Roaming\MetaQuotes\Tester\<id>\
    Agent-127.0.0.1-30NN\logs\, NOT the terminal data folder.
  - Never git add -A. Commit path-limited. Never git stash to compare revisions --
    `git show HEAD:path > scratchpad/` instead.
  - Codex quota is out. Fable = /fable-advisor only, never batch labour.
  - factory/universe.jsonl must not be created until the owner re-attests D1.

Owed to the owner, do not decide these:
  the 4 items in _triage/USER_DECISIONS_PENDING.md.
```

---

## What this batch proved that the next session should not re-derive

| fact | evidence |
|---|---|
| a fingerprint over rendered TEXT cannot cross a language boundary | `repr(3e-05)` is Python's shortest-round-trip spelling and MQL5's `%g` is the C library's; they disagree on `1.0` vs `1` and on exponent width. Doubles go in as IEEE-754 bits now |
| one matching run does not prove two implementations agree | a constant, or a digest computed from the source rather than live inputs, produces exactly that; the verifier requires two configurations to match their own compiler value AND to differ from each other |
| a criterion can be honoured by NOT being met | `C3` says stop writing `surface_only` *only when* the fingerprint covers the real surface; it does not, so the label stays and the remainder became `ORDER-730` |
| a fixture's validity is an assumption about somebody else's table | B0's probe id was `ORDER-711` because that was inside the *authoring* lane's block; it went red the moment the next lane reserved a different one — second instance of this shape in two batches |
| "implicitly guards itself" was true of the TRIGGER and false of the SELECTION | staging a suite's own file ran the tier and skipped that suite — visible in commit `2aae5241`'s own hook output |
| the file holding half a cross-language contract can be guarded by nothing | `ConfigFingerprint.mqh` was in neither `$SUITE_GUARDS` nor the pathspec; `-ExportSelection` printed *"1 staged path(s) matched NO suite"* and the pathspec matched it not at all. Declaring it is not enough on its own — a criterion (`G3`) now READS it, so the declaration is load-bearing |
| an explanation that fits one instance is not a cause | the tier abort was written up as "another lane committed" — true for instance 1, and it recurred with no lane open. 2 of 8 runs, cause not settled |
