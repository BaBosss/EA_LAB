# OPENING PROMPT — the swap premise is refuted, and two questions are with the owner

> Written 2026-08-04 by lane `S-2026-08-04-SWAPPROBE` (block `1390-1399`), after two `/scrutinize`
> rounds over this chat's own work. Read `_triage/PROMPT_NEXT_SESSION_S13J.md` and `_S13I.md` for
> what `S13H` and `S13G` did. ⚠️ Several lanes were ACTIVE throughout — **read the ledger first**.

## What is now measured

**`ORDER-1350` step 1 is done, on the pinned lane, with both probes dated**
(`factory/runs/pilot/swap_probe/swap_probe_20260804.jsonl`):

| probe | result |
|---|---|
| spec | `BTCUSD` is **still `INTEREST_CURRENT`**, `swap_long` −14.31 %/yr, contract 1.0 |
| charge | one 0.01-lot BUY held **70 days** → tester charged **`Swap = −20.21`** |

🔴 So the half of the 2026-07-26 measurement that said *"net == price-only P&L to the cent"* is
**false on this build today**. The mode half still holds. Every `financing_deducted` figure on a
BTCUSD record therefore sits on top of a charge that already happened.

✅ **And the tester's own profit factor already contains it** — measured, not assumed: on
`H02/BTCUSD/H4` the deal `Profit` column is identical to the cent across two days while `Swap` moves
`+15.28`, and the aggregates move `+4.18` / `+11.10`, summing to exactly that.

## The work, in order

1. **`ORDER-1370`** — apply the answer to **every arm at once**. Today `baseline` (12) and
   `selected-verification` (10) carry a deduction and `flat-lot-probe` (10) and `probe-escalated` (6)
   carry none, so the falsifier compares across the split. Then §8.6 item 10 goes green **by
   reading**, no checker edit (case `F1` proves that path).
2. **`ORDER-1350` steps 2-3** — what happens to every record already carrying
   `financing_deducted.applied = true`, and the same question for ETHUSD.
3. **`ORDER-1330` items 1-2** — the fingerprint's missing component is the **symbol specification in
   force at run time**. 🚫 Do not hash it in without the migration decision.
4. `ORDER-1255` (needs a lane that owns `schemas.json`) · `ORDER-1256` items 12 + 14 (item 14 needs
   MT5) · `ORDER-1302` (owner) · `ORDER-1301` · `ORDER-1300` · `1270` / `1271` / `1274`.

## 👤 With the owner

- **How far down do we widen the grids** (`ORDER-1302`) — 23 of 32 boundary hits are at the LOW edge.
- **The 49-trade participation question** (`ORDER-1254`) — ⚠️ its number moves: the tester reports
  `B14-H02-r1/BTCUSD/H4` BWD Model 4 at **1.44**, and **1.20** was that figure with the financing
  deducted a second time. 🚫 Nothing is restated until `ORDER-1370` lands.

## What the two /scrutinize rounds changed, so it is not re-derived

- **"5 of 8 cells differ by swap alone" was wrong** — the recount is **3 swap-only · 3 where deal
  time/price also moved · 2 where the deal count changed**. ⚠️ And the trap in reading the second
  group as a changed price series: `_2_BasketTP_BalPct` closes on a percentage of **balance**, so a
  changed swap moves the exit tick. Consistent with one cause; **not demonstrated**.
- **"−14.67 → −14.31 is a second confirmation of `ORDER-1330`" does not hold** — the 2026-07-26
  reading does not name its install, and BTC data differs across installs. The deal-list diff is
  still the only demonstrated confirmation.
- **Both probes ran with no `-SetFile`** (`NOSETFILE` warning). Pin a `.set` before quoting them for
  anything beyond *"the charge is non-zero"*.
- 🔴 **A prohibition that could not fire.** Item 11's *"without re-running a completed attempt"* sat
  below the `if not killed: continue` filter, so it only ever ran on journals that had been killed —
  while its own comment said otherwise. Case `S3` could not catch it because `S3`'s fixture contains
  a kill. Fixed; `S7` is a journal with no kill and it goes red. **90 cases, 0 failed.**
- ⚠️ **A commit was rejected by its own tier** because a concurrent lane moved HEAD mid-run, and by
  then the shared working tree had been read by theirs: **this lane's `AGENT_TASKBOARD.md` edits are
  committed under `5ac83527` / `1464a94f`.** Content intact, provenance wrong, **not rewritten**.

## Baseline

`check_state.ps1` CLEAN · `run_s13_tests` **90 cases, 0 failed** · `check_pilot_acceptance`
**8 PASS · 1 FAIL · 5 BLOCKED (1 awaiting evidence, 4 checker-not-implemented)**. The full 29-suite
tier was **not** measured cleanly here — one run aborted with `HEAD MOVED DURING THIS RUN`. 🚫 Do not
quote a tier number from this session.

**Re-derive your order block from BOTH tests.** At close: highest `## ORDER-<n>` = **1370**; highest
block reserved = **1390-1399**. Blocks moved three times today between a handoff being written and read.

## Do NOT do in this session

- 🚫 Add the deduction to the probe arms before `ORDER-1370` decides the direction · 🚫 quote a
  financing-adjusted BTCUSD number · 🚫 restate any PF from the swap finding · 🚫 quote a **Model-1**
  PF as a quality number · 🚫 issue a verdict for any cell from automation.
- 🚫 Quote the −14.31 vs −14.67 difference as evidence a rate moved · 🚫 quote either probe beyond
  "the charge is non-zero" without pinning a `.set` first.
- 🚫 Set a participation floor or a grid-widening floor without the owner · 🚫 widen any `safe_range`
  · 🚫 book the 14 BOUNDARY re-runs · 🚫 hash the symbol spec into `data_fingerprint` without the
  migration decision.
- 🚫 Raise `$FullTierBudgetSeconds` · 🚫 hand-edit any generated store under `factory/` · 🚫 touch
  `AGENTS.md` · `PROJECT_STATE.md` · `s2a_attestations.jsonl` · any `check_s2a_attestation.py:BUNDLE`
  member · any `.set` migration · any magic renumber.

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| both probes dated; the "not charged" premise is refuted on this build | ORDER-1350 |
| what happens to records already carrying applied=true, and ETHUSD | ORDER-1350 |
| the arm split, and applying the answer to every arm at once | ORDER-1370 |
| the fingerprint's missing component is the symbol spec | ORDER-1330 |
| item 11's prohibition hoisted above the kill filter; S7 added | ORDER-1256 |
| 👤 how far down to widen the grids | ORDER-1302 → **owner** |
| 👤 a BWD pass on 49 trades over three years | ORDER-1254 → **owner** |
| not started: acceptance (1) is a schema entity another lane holds | ORDER-1255 |
| PF 1,126 on 5.38 of realised loss | ORDER-1301 |
| 🔴 amend §6.2 to say which floor governs which step | ORDER-1300 |
| the guard layers still off for every non-pilot caller | ORDER-1270 / 1271 |
| the fine half of the §6.2 ladder | ORDER-1274 |

Open with: **"อ่านไฟล์นี้ — เริ่มที่ ORDER-1370 · จองบล็อกใหม่ก่อน derive เองจากทั้ง 2 test"**
