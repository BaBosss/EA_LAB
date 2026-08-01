# HANDOFF — lane `S-2026-08-01-TIERINSTR` (2026-08-01), block 820-829, no MT5 lane

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this is a **shift-change note, not a queue**
> (Decision log 2026-07-26). Every forward-looking item has a home — the routing table at the
> bottom says which. This is the LAST lane of a long 2026-08-01; read the state block first.

## State of the repo at close — read this before anything

| | |
|---|---|
| S2a gate (`check_s2a_attestation` · `check_coverage_transfer` · `run_s2a_gate`) | **all exit 0** |
| attestation record in force | **line 9**, bundle **`d88f795b`**, owner-signed 2026-08-01 |
| `ORDER-731` | items 1 · option A · option 2 · M1-M4 · item 2 instrumentation = **DONE**; item 2 itself stays OPEN (waiting for the abort to recur) |
| full tier | **RED — 91.1-93.6 s against the enforced 90.0 s.** Deliberate: `ORDER-820` opened rather than the number raised. Per-path selection (65 s budget) is what gates ordinary commits, and it passes. |
| lanes ACTIVE | none |
| working tree | clean except pre-existing unrelated dirt (`.obsidian/**`, `STATUS.html`, some `_mt5_auto` CSVs, `portfolio/mris/**`) that was dirty at session start |

**Nothing is owed to the owner right now.** No signature is pending, no `--no-verify` was used all
day, and no bundle member is dirty.

## What this lane did

`ORDER-731` item 2's instrumentation, so the **next** tier abort is diagnosable instead of being
re-argued. `run_fast_cages.ps1` now writes a per-run JSONL transcript to `_triage/tier_runs/`
(gitignored, newest 40 kept) stamping — **after every suite, not just at the ends** — `.git/HEAD`,
the resolved ref, `.git/index`'s (mtime, length), and the **CRLF-folded sha256 of the four
working-tree files the abort's own fingerprint hashes**. On a suite failure it appends a
`failure-dump` capturing, at the moment of detection, whether `.git/index.lock` exists, which git
processes are alive, the reflog tail, and whether HEAD moved.

**Four defects in the instrumentation were found by running and reading it, all fixed here:** a
BOM on line 1 that would break `json.loads`; nested tier invocations writing 6 spurious
transcripts per real run; the child-marker env var leaking out of the script so a second run in
one shell silently wrote nothing; and — the one that mattered — **stamping only HEAD and the index
while the abort also hashes four working-tree files**, which would have produced a transcript
saying *"nothing moved"* against an abort saying the opposite. Misleading, not merely silent.

**Not done, deliberately: I1** (make the abort print *which* fingerprint component moved). It
edits `check_s2a_migration.py`, a **bundle member**, so it rides the next signature with the
stale-count batch instead of spending one of its own.

## How to use the transcript when the abort next fires

1. `_triage/tier_runs/` — take the newest file. It is JSONL, no BOM, one line per suite.
2. Find the `failure-dump` line. `index_lock_present` and `live_git_processes` are the two fields
   that separate *a concurrent writer* from *something inside the tier* — the question 2026-08-01
   could not answer.
3. Walk backwards through `after-suite` lines and diff `head` / `ref` / `inputs` between
   consecutive stamps. **The first field that differs names both what moved and the suite it moved
   under.** `index_ticks`/`index_len` are a proxy and may move without the abort firing — treat a
   change there alone as a lead, not a verdict; `inputs` is exact.

## Do not do these

- ❌ Do not raise the full-tier budget to clear the red. `ORDER-820` C1 requires the **+8.7 s** in
  `run_contract_binding_tests.ps1` to be attributed first; `ORDER-673` already paid for the version
  of that file where the budget was advisory and breached for days with nothing happening.
- ❌ Do not quote a run the tier aborted as a pass or a fail — unchanged rule.
- ❌ Do not edit any S2a bundle member without budgeting a signature (current digest `d88f795b`).
  The stale-count batch and I1 are queued to ride the next one together.
- ❌ Do not commit `_triage/tier_runs/` — it is gitignored on purpose. The findings go on the board;
  the breadcrumbs stay local.

## Routing — every forward-looking item has a home

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| the item-2 instrumentation (I2 transcript · I3 failure dump · the four fingerprint inputs) | DONE |
| `ORDER-731` item 2 itself — still OPEN, waiting for the abort to recur; the wake condition and the reading procedure are on the row | ORDER-731 |
| **I1** (the abort names which fingerprint component moved) + the policy stale-count batch — both bundle members, both ride the NEXT signature together | ORDER-731 |
| the full tier over its enforced budget, with the +8.7 s in `contract_binding` unattributed | ORDER-820 |
| a module should DECLARE the paths it reads | ORDER-761 |
| the locked-constant half of design §5.6 | ORDER-730 |

## Other lanes

None `ACTIVE`. Today's chain, in order: `PINFIX2` → `PINFIX3` (option A) → `PINFIX3B` (the review
that found option A was half a fix) → `OPT2` (the pin follows the canonical bytes) → `OPT2FIX`
(M1-M4) → this lane. Each has its own handoff; `PINFIX3`'s carries a correction box rather than a
rewrite, on purpose.
