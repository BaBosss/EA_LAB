# Next-session prompt — `ORDER-710` is closed; what the Factory OS track still owes

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **the opening prompt for the next
> session on the Factory OS track**. Written 2026-08-01, end of lane `S-2026-08-01-CFGFP`.
> The previous opener (`_triage/PROMPT_NEXT_SESSION_GUARDS.md`) is spent — its only open item was
> `ORDER-710`. Paste the block below as the first message of the new session.

---

```
Batch closed 2026-08-01: ORDER-710 ([CFG] input-surface fingerprint). The EA now hashes its own
live inputs at OnInit and the digest MATCHES the compiler's -- 2 builds x 2 configurations, four
tester runs on lane 1. tpl_regression CLEAN 8/8. HEAD = <run git log --oneline -1> ·
full tier 16/16 at 77.5-79.2s of the 90.0s budget.

Read in this order:
  PROJECT_STATE.md  §2 top entry (what the batch found) + §3 (decision log, unchanged this batch)
  _triage/HANDOFF_2026-08-01_CFGFP.md  (the shift note -- the four measured hashes, why the
      preimage had to stop being text, and the two defects found in OTHER lanes' work; the
      "live traps" section is the part that saves time)
  docs/GUARD_SHAPES.md  (still the pre-flight for writing OR REPAIRING any guard)
  AGENT_TASKBOARD.md -- grep '## ORDER-710' for the evidence and '## ORDER-730' for what is left

What is actually open on this track (checked before writing this, not assumed):
  1. ORDER-730 -- the LOCKED CONSTANTS half of design 5.6. The fingerprint covers every input the
     build exposes and no compiled-in constant, and both sides label that honestly
     (fingerprint_scope = surface_only, in the manifest, the .set header, and the preimage
     itself). preset.py's _constant_scope() already accepts constants and renames the scope to
     surface+constants when it has them, so what is missing is WHAT the constants are and how the
     EA enumerates them. Needs an MT5 lane if anything under ea_template/core/ changes.
  2. BACKLOG-D33 -- check_s2a_migration aborted once in four full-tier runs with its own
     concurrency detector ("HEAD or the git index changed while this check was running").
     Green standalone, green on the other three. The abort is CORRECT; the trigger is unknown.
     Wake condition: it fires a second time, or it fires inside a real `git commit`.
  3. Five NON-front-guard PowerShell checkers still print in L3's suspension list every run --
     read the live line, don't trust this one:
     `tools/python312/python.exe _triage/factory_os/run_guard_shape_lint.py`. They are NOT run by
     the hook before the tier, so migrating them is a new order, not a continuation.
  4. The 4 items in _triage/USER_DECISIONS_PENDING.md (Core Universe v1 membership ·
     AGENTS.md §2 writer surface · the account|magic §0.5-vs-global contradiction · the
     ~10,000-combination budget) -- owed to the owner, untouched, still pending.

A parallel lane may be running. S-2026-08-01-OPERATE (block 740-749) was ACTIVE when this was
written. Re-read docs/SESSION_LEDGER.md rather than assuming you are alone.

Rules that still hold (restated because they are still true):
  - Reserve a lane in docs/SESSION_LEDGER.md and COMMIT the reservation before anything.
    Parse `## ORDER-<n>` from all four board files yourself -- do not trust the ledger's
    foot-of-file summary bullets (stale for the tenth time as of this writing, BACKLOG-D29).
    Write the derivation as PROSE: quoting a regex with a character class in that cell makes the
    collision guard read the class as a second reserved range. That happened to this lane.
  - CLOSE THE LANE ROW IN YOUR LAST COMMIT, NOT BEFORE. check_order_collision RULE 2 reads the
    ledger from HEAD and enforces reserved blocks only for ACTIVE rows; with none it prints
    "NOTE: no ACTIVE lane ... reserved-block and owned-path rules skipped" and passes.
  - Budgets are enforced: 65s per-path / 90s full tier. Over budget = the commit is REFUSED.
    ~11s of full-tier headroom. A new cage DISPLACES something -- this lane traded PART 4b's
    sixteen self-selection probes down to three to pay for its own additions, and said so.
  - A repair is writing a guard: run docs/GUARD_SHAPES.md's pre-flight on it too (shape 5).
  - Never git add -A. Commit path-limited. Never git stash to compare revisions --
    `git show HEAD:path > scratchpad/` instead (this lane used exactly that to measure the
    pre-fix suite-selection behaviour).
  - Anything GENERATED must be regenerated in the same commit as its source, and a guard must
    read BOTH at ONE snapshot. ea_template/core/InputSurface_gen.mqh is generated:
    `tools\python312\python.exe _triage/factory_os/gen_input_surface.py --write`.
  - core.autocrlf is true here: the blob is LF and the worktree is CRLF, so a file is not
    byte-equal to itself across snapshots. Fold newlines and SAY that you folded them.
  - MT5 tester logs are UTF-16LE and live under ...\Roaming\MetaQuotes\Tester\<id>\
    Agent-127.0.0.1-30NN\logs\, NOT the terminal data folder. Reading them as UTF-8 finds zero
    matches and looks exactly like "the EA printed nothing".
  - Codex quota is out. Fable = /fable-advisor only, never batch labour.
  - factory/universe.jsonl must not be created until the owner re-attests D1.

Owed to the owner, do not decide these:
  the 4 items in _triage/USER_DECISIONS_PENDING.md listed above.
```

---

## What this batch proved that the next session should not re-derive

| fact | evidence |
|---|---|
| a fingerprint over rendered TEXT cannot cross a language boundary | `repr(3e-05)` is Python's shortest-round-trip spelling and MQL5's `%g` is the C library's; they disagree on `1.0` vs `1` and on exponent width, so the hash would have been a claim about two printf implementations |
| one matching run does not prove two implementations agree | a constant, or a digest computed from the source rather than from live inputs, produces exactly that; the verifier requires two configurations to match their own compiler value AND to differ from each other |
| a fixture's validity is an assumption about somebody else's table | B0's probe id was `ORDER-711` because that was inside the *authoring* lane's block; it went red the moment the next lane reserved a different one. Second instance of the same shape in two batches |
| "implicitly guards itself" was true of the TRIGGER and false of the SELECTION | staging a suite's own file ran the tier and skipped that suite -- visible in commit `2aae5241`'s own hook output, not reconstructed |
| a criterion can be honoured by NOT being met | `C3` says stop writing `surface_only` *only when* the fingerprint covers the real surface; it does not, so the label stays and the remainder became `ORDER-730` |
