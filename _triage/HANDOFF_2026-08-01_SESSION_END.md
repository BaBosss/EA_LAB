# HANDOFF — end of 2026-08-01, consolidated. START HERE for the next session.

> ⚠️ canonical entry is still **`PROJECT_STATE.md`** — it was corrected at the end of this session
> and is trustworthy again. This file is the **shift-change note for the whole day**: seven lanes
> ran in sequence, all CLOSED, and the individual handoffs are listed at the bottom if you need the
> long version. Read this one first; open the others only for a specific lane.

## 1. State of the repo — verified at HEAD, not remembered

| | |
|---|---|
| S2a gates (`check_s2a_attestation` · `check_coverage_transfer` · `run_s2a_gate`) | **all exit 0** |
| attestation record in force | **line 9**, bundle **`d88f795b`**, owner-signed 2026-08-01 |
| `scripts/check_state.ps1` | **CLEAN** |
| full tier | **87.8 s of 90.0 s** on the last sample — but see §4, it is intermittent |
| lanes `ACTIVE` in `docs/SESSION_LEDGER.md` | **0** |
| `--no-verify` used today | **none** |
| working tree | clean except pre-existing unrelated dirt (`.obsidian/**`, `STATUS.html`, some `_mt5_auto` CSVs, `portfolio/mris/**`) that was already dirty at session start |
| owed to the owner | **nothing** — no pending signature, no pending decision |

**Probed at HEAD, both directions** (do not re-derive, it is done):
an append to `MASTER_BACKLOG.md` **outside §2 passes** the front guard (`rc=0`); an edit **inside
§2 is refused** with `P1` naming both digests (`rc=1`).

## 2. What actually changed today, in one paragraph

`MASTER_BACKLOG.md` carried **two** whole-file byte-pins from one owner approval, and between them
they froze the busiest board in the repo: any edit either cost a signature or deadlocked the gate,
and the gate blocked its own repair. Both are gone. The post-state pin was narrowed to **§2 only**
(a new SECTION form, `F12`/`F13`/`F14`/`P4`, fail-closed), and the second pin — the stale-pin
acknowledgement, which the first fix did **not** touch — was removed by re-pointing D1's
`owner_ref` at `factory/coverage.jsonl`, the file that has actually held the canonical Coverage
bytes since the transfer executed. Two owner signatures, both shown as a full line with recomputed
digests before they were taken.

## 3. The three things worth carrying forward as knowledge

1. **Narrowing one pin does nothing if the file carries two.** Option A was a large, correct,
   well-caged change that removed **none** of the measured toll, because `F5` still compared the
   whole file. *If you re-derive this problem later: the cheap path was option 2 alone (~60 lines,
   one signature). Option A is load-bearing now only as protection for §2's generated content —
   a real goal, but a smaller and different one than the toll it was bought to fix.*
2. **A guard that reports and cannot refuse is worse than no guard.** Splitting `current_owner`
   from `owner_ref.path` left notes being derived on one and matched on the other: printed every
   run, enforceable never. Caught before landing. Any time two identity fields diverge, go find
   every consumer of the one you moved.
3. **Instrument what the guard actually reads.** The tier transcript first stamped `HEAD` and
   `.git/index` while the abort also hashes four working-tree files — it would have reported
   *"nothing moved"* against an abort saying the opposite. And under the hook it stamped
   `.git/index` while git was using a `next-index-*.lock`. Both fixed; both are the
   read-the-wrong-snapshot family appearing inside the instrument built to diagnose it.

## 4. Open work, in the order it is worth doing

1. **`ORDER-820` — the tier budget.** Six samples: `91.8 · 91.5 · 91.7 · 91.1 · 93.6 · 87.8 s`
   against an enforced `90.0 s`. **The breach is intermittent** and the driver is one suite,
   `run_contract_binding_tests.ps1`, swinging **24.9-32.1 s**. C1 is now *"why does this suite vary
   by 7 s"*, not *"what added 8.7 s"*. 🚫 Do not raise the budget to clear the red, and do not tune
   against a single run in either direction.
2. **The next S2a signature — batch these onto it.** All are inside bundle members, so they cost
   nothing extra if they ride the same line: **I1** (make the abort print *which* fingerprint
   component moved) · policy `§7` row 5 *"19 green"* (is 21) · `§9` *"35 assertions"* (46) · `§1`
   *"five signatures"* (eight, history ends `d88f795b`) · `G4`'s text *"F1–F11"* (the in-force set
   is F1–F14) · `§4.2`'s *"7 records"* (8 since line 9) · the corpus file's own line-1 header still
   says *"DRAFT: not yet bound"* and cites a file that does not exist · and **state in `§4.5`** that
   once a drift is acked, the ack becomes a whole-file front-guard pin on `factory/coverage.jsonl`
   until re-acked.
3. **`ORDER-731` item 2** stays OPEN, waiting for the abort to recur — but it is now *armed*:
   `_triage/tier_runs/` holds a per-suite transcript, and the reading procedure is in
   `_triage/HANDOFF_2026-08-01_TIERINSTR.md`.
4. **`ORDER-761`** (a module should declare the paths it reads) and **`ORDER-730`** (the
   locked-constant half of design §5.6) are untouched and unchanged by today.

## 5. Traps this session paid for — do not re-enter them

- ❌ **Do not copy a `stale_pin_acknowledgement` from an older record.** For a path no D1 row pins,
  the checker never validates it and the front guard would have enforced it — reinstating the
  whole-file toll. The guard now ignores such an ack loudly; the trap is copying the shape.
- ❌ **Do not take the next attestation line from `--template` and then delete fields.** It now
  carries the in-force `expected_post_state` forward on purpose; dropping it silently unpins §2.
- ❌ **Do not "fix" a stale count by editing `S2A_ATTESTATION_POLICY.md` casually** — it is a bundle
  member; every byte costs a signature. That is why item 2 above is a batch.
- ❌ **Do not suppress the tier transcript on "a synthetic staged set"** — the hook itself passes
  `-StagedPathsFile`, so that heuristic silences the instrument exactly where it matters. `-Hook`
  does not discriminate either.
- ❌ **Do not put a raw `|` in a ledger cell**, and do not cite another lane's block number there —
  the cell is parser input as well as prose.
- ❌ **Do not run a full-tier timing measurement while another lane is open**, and do not conclude
  "no lane is running" from `git log` plus a ledger row: a lane committed 45 minutes after its own
  row said CLOSED.

## 6. Routing

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| both whole-file pins removed; §2 protection landed; two signatures spent and none pending | DONE |
| the intermittent tier budget breach, driver identified as one suite's 7 s swing | ORDER-820 |
| the tier abort itself — armed with a transcript, waiting to recur | ORDER-731 |
| I1 + the policy stale-count batch, to ride the next signature together | ORDER-731 |
| a module should DECLARE the paths it reads | ORDER-761 |
| the locked-constant half of design §5.6 | ORDER-730 |

## 7. The day's lanes, if you need the long version

`PINFIX2` (ORDER-760, the ledger-cell parser) → `PINFIX3` (option A) → `PINFIX3B` (the review that
found option A was half a fix and the gate was red) → `OPT2` (the pin follows the canonical bytes)
→ `OPT2FIX` (M1-M4) → `TIERINSTR` (the abort instrumentation) → `TIERBUDGET` (owner-stopped,
committed nothing) → `INSTRREV` (five review findings on the instrumentation) → `STATEFIX` (this
file, plus the `PROJECT_STATE` correction). Handoffs: `_triage/HANDOFF_2026-08-01_PINFIX2.md` ·
`_PINFIX3.md` (carries a correction box — the body is deliberately unedited) · `_PINFIX3B.md` ·
`_OPT2.md` · `_TIERINSTR.md`. **37 commits, every one through the real hook.**
