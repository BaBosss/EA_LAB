# HANDOFF — lane `S-2026-08-02-SCRUT11S` · three `/scrutinize` rounds over slice S11

> ⚠️ canonical entry = [`PROJECT_STATE.md`](../PROJECT_STATE.md) · this file owns: **what three
> adversarial rounds over `ORDER-1131` found, and the one shape all six defects share — nothing
> else.**
>
> **Numbers policy:** where a suite prints a count, this file names the suite. The scenario count
> is printed by `run_s11_tests.py --list`.

## What was audited

Slice S11 as it stood at `8ac43516` — `control_center.py` · `safe_projection.py` ·
`run_s11_tests.py` · `scripts/_test/run_s11_tests.ps1` — written by this same seat hours earlier.

**Six defects across three rounds. Every one reproduced and printed by a read-only probe before
anything was touched, and every fix was written as a failing case first.** No file outside this
lane's declared list was edited.

## The rounds

| round | commit | the defect |
|---|---|---|
| 1 | `c2576b97` | an account only ONE detector knew about was **invisible on both surfaces**, so `ALL CLEAR` could render over a blind sensor with open lots; and `OK`-with-no-document **invented a headline** |
| 2 | `6ff84dca` | the roll-up that refuses untested rules **could not fail** — and was hiding three; plus a partial row list that read as a queue, and a rule text asserting a heartbeat nobody measured |
| 3 | `c9920c18` | the shape checker **silently accepted every construct it did not implement**; and the CLI a human runs held two defects because no case had ever called it |

## The one shape, three disguises

**The unhandled case rendered as the satisfied one.** Every round found it somewhere new:

- **Round 1** — `build_live` and `build` walked `system_health` and joined the rest onto it. An
  account the health detector had never seen produced *nothing*: no row, no exception, no entry in
  the masked account list. Not `UNKNOWN` — **absent**. The union fix is symmetric in both
  directions, so a detector that is *silent* about an account is itself the finding.
- **Round 2** — `R1` claimed "every placement rule was attacked by a case". It was computed after
  `main()` topped the counter up with thirteen synthetic rows, so it was green regardless. The
  probe printed what it was concealing: **10 of 13 rules** fired by the real scenarios,
  `B02`/`B05`/`B06` reached by none.
- **Round 3** — `_check_shape` implemented five constructs and fell off the end for the rest.
  `type: integer` handed an account string, `type: boolean` handed a token, an unresolved `$ref`,
  an unresolved `oneOf` — **all four: no hits**. In the one function whose entire job is checking.

Rounds 1 and 3 are the family this repo already has a memory for
(`unreadable-input-must-refuse-not-skip`). **Round 2 is new and now has its own**
(`completeness-rollup-measured-after-topup`): a completeness roll-up must read its counter
**before** any convenience fixture tops it up, and *coverage* and *reachability* must be two
roll-ups because they are two claims.

## The second lesson: where the defects were, not what they were

**Four of the six lived in code no case had ever executed.** Round 3's two came from
`control_center.main` — a name that was in `PUBLIC_API`, that `P01` checked *by name*, and that
nothing called. `WIRE3` now drives it, and it is the single case that would have caught both.

The S11 build followed the "pure module + one wiring run" pattern deliberately, and it worked as
far as it went — but the pattern only covers the wiring the wiring-case chose. **The CLI is not a
detail around the module; on this slice it was the module's only production caller, and it was
where the module's contract was actually being broken** (a `WorkReceipt` fed to `normalise_row`,
which refuses it — so the CLI would have raised on the day S14 imported its first row).

## What changed in behaviour, and what did not

- The real snapshot renders **identically before and after round 1** — 6 accounts, 6 LIVE
  exceptions — because its two detectors happen to agree on the account set today. That is what
  makes it a hole rather than a bug: **nothing on this machine would have shown it.**
- `WORK` now reports the **gap** rather than the emptiness: rendered vs discovered at any size,
  plus a second, independent check for receipts that produced no row.
- The `WIRE1` assertion that pinned today's empty `work_receipts.jsonl` was replaced by one that
  asserts the **rule** against the same document, so S14 landing data is not a false red.

## Measured at close

Suite **1.6s / 1.6s / 1.6s** over three runs (1.4s before these rounds; the 0.2s is `WIRE3`).
Full fast tier: see the ledger row — three runs, all green, inside the 120.0s budget.
`check_state.ps1` **CLEAN**.

## Not done, deliberately

No new order was opened — every finding belongs to `ORDER-1131` and landed there. No EA verdict,
no MT5 lane, no `.set`, no `factory/runs/**`, no `DEPLOYMENTS.csv`. S12 was **not started**; its
opening prompt is `_triage/PROMPT_NEXT_SESSION_S12.md`.

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| round 1: the one-sided-detector blind spot, and OK-with-no-document | ORDER-1131 (DONE) |
| round 2: the roll-up that could not fail, the partial-queue render, the unmeasured heartbeat | ORDER-1131 (DONE) |
| round 3: the shape checker's unimplemented constructs, and the undriven CLI | ORDER-1131 (DONE) |
| `dd_pct_band` still has no producer — every band reads `UNKNOWN` | ORDER-1131 (owed · **S12 must not fill it from money amounts**) |
| `WORK` still has no row-level owner — the page states the gap | ORDER-1131 (owed · closes with S14) |
| `SafeProjection` → `WIRED` once something in production builds the projection | ORDER-1131 (owed) |
| speed or displace the three suites that are ~65% of the full tier | ORDER-1130 (untouched here) |
| S12 Telegram Control Room + Morning Brief | DONE (not started — the opening prompt is written) |
