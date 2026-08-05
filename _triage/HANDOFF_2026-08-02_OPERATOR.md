> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **shift-change note for lane
> `S-2026-08-02-OPERATOR`** — the session where the owner did the terminal work. A note, not a
> queue: every forward item has a row on `AGENT_TASKBOARD.md`.

# Session end — 2026-08-02, `S-2026-08-02-OPERATOR`

The owner went to the VPS, took an F3 census, read four Inputs tabs, exported the account's 8-day
Expert log, and ratified one decision. All three items from
`_triage/PROMPT_NEXT_SESSION_OPERATOR.md` moved. **No deployment, `.set`, binary or verdict was
touched.**

## 1. `ORDER-510` STEP 2 — 1 of 4 accounts censused, and the result is pointed

**`415573666` (DEMO): NOT SAFE TO UPDATE, by exactly one magic.**
`Boss_990208_rc_peak_eq = 60027.15` (written 2026-07-28 13:08) is the only legacy key; 13 of the
account's 14 inventory magics are clear by absence.

🔴 **`990208` is `Boss_14` GBPJPY — the leg queued for real money.** Of fourteen magics, the one
carrying pre-132 state is the one whose next step was a promotion.

🟢 The **foreign-state** branch is not indicated here: equity ≈58,721 against a stored peak of
60,027.15 is a peak slightly *above* equity (≈2.2% DD) — what a genuine high-water mark looks like,
not the `10136.29`-against-99,944 shape STEP 3 is about. **Adopt-once (§6) is the route.**

**The checker's fire count moved 0 → 1**, so it is no longer `UNTESTED` against a live terminal.

**STEP 2 COMPLETE (all four censused 2026-08-02).** `159475669` · `159503454` · `141049900` all
came back EMPTY — so of the whole fleet exactly ONE magic blocks the upgrade: `990208`. 🔴 And
`141049900` is an **MT4** terminal, where these MQL5-written GVs cannot exist at all — it was never
in scope, and the checklist sent the owner to look anyway. **Next: STEP 3 + the adopt-once run for
`990208`, which needs the owner present.**

## 2. `ORDER-941` — all three suspected causes refuted; the gap is an instrument, not a fault

- **`AllowLive=false` refuted by construction** — `(EXP)_IchiADX_Naked_rev00` is a *standalone* EA,
  not a Boss-template build. Its whole surface is 14 inputs and **`_06_AllowLive` / `_06_Magic` do
  not exist on it**. The order asked the owner to read two fields that were not there, inherited
  from the `990025` precedent without checking the two EAs share a chassis.
- **Wrong magic refuted; configs byte-exact** — 14 of 14 inputs match the locked `_vps_deploy`
  `.set` on all four legs; magics distinct and matching `DEPLOYMENTS.csv`.
- **Init failure refuted** — the EA's only four `Print()` calls are failure paths; none in 8 days.
- 🔴 **What is left cannot be settled by reading.** With no `Print()` on any success path, silence
  is what a healthy running leg looks like *and* what a stopped one looks like. Confirmed the log
  can see the terminal (10 other EAs log; every Boss EA printed `[INIT]` at the 08:42:01 re-init on
  08-02 while IchiADX printed nothing — consistent with both readings).

⇒ **`ORDER-1000`** opened: heartbeat + per-reason counters + the `unaccounted` self-check, the
`ORDER-432` finding-6 shape already proven on this exact problem. **Fresh counters answer the next
16 days, not the last ones** — `ORDER-941` does not close on them.

### 🔴 Then the owner asked the question the order should have opened with

*"Have you run all four over the same window to see whether any trade comes out?"* No. Everything
above argues about whether the legs are **executing**; nothing asked whether the **signal fires at
all**. One tester run per leg, no terminal needed, and it settles what the log cannot.

Four runs, lane 1, locked `.set` verbatim, `2026.07.16 → 2026.08.02`, Model 1, quality 100%:
`990066` **0** · `990067` **0** · `990068` **4 deals** · `990069` **0** — against live `0/0/1/0`.

**The backtest reproduces the live pattern leg for leg.** *"Three legs silent together is not
thinness"* — the sentence the whole order rests on — **is refuted by measurement**. The legs were
not prevented from trading; there was nothing to trade. **The defect is the `~1.05/wk` expectation
(`ORDER-942`), not the attach.**

Caveat kept with the number: the tester resolved these symbols on the **ThinkMarkets** feed while
live is **Exness `m`** — enough to move a marginal signal by a bar, not enough to move 2.4 trades to
zero.

## 3. `ORDER-761` — CLOSED without being built, owner-ratified

Dies on its own **C2** (*"if it lands near 66 again it has not solved anything"*): measured **102**.
The premise — declaring beats guessing because a text scan over-counts — does not survive it. This
closes **one proposed mechanism, not the problem**; a sixth hand-widening should be recorded against
the row as evidence the cost is accumulating.

## Verification

`check_state.ps1` CLEAN. Every commit through the full pre-commit hook, no `--no-verify`. MT5
lane 1 was taken only for the four ORDER-941 backtests (lane `S-2026-08-02-ICHIBT`); every other piece
of evidence came from the owner’s terminal.

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| STEP 3 (the peak-equity anomaly) + adopt-once for `990208` — the last owner-present step | ORDER-510 |
| add the heartbeat + per-reason counters to `(EXP)_IchiADX_Naked_rev00` | ORDER-1000 |
| ORDER-941 silent-vs-thin: ANSWERED by backtest (signal quiet, not blocked); row closes with ORDER-942 | ORDER-941 |
| the `~1.05/wk` expectation the backtest just contradicted | ORDER-942 |
| `ORDER-761` mechanism | DONE |
