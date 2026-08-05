# Codex blind audit — (Boss)_BasketGuard — 2026-07-27

**Verdict: do not set `InpDryRun=false`. This is a best-effort watchdog, not a hard loss bound.**

Claude's assessment of the audit: **accepted almost in full.** The findings below are recorded
because the top one is not a bug — it is the design being wrong for the goal it was written for.

---

## The finding that matters most (P0-1): floating-only accounting forgets the blow-up

The guard sums **only positions currently open**. If the loss gets realized between polls — broker
stop-out, or the guarded EA closing legs itself — the evidence disappears and the guard stays ARMED.

Worked example, balance 10,000 USC, limit 1,500:
1. Poll sees −1,490 → does nothing (correctly, it is under the limit).
2. A gap takes the basket to −4,000 before the next 5-second poll.
3. Stop-out or the EA realizes the losing legs.
4. Next poll: balance 7,000, floating −500, or nothing open at all.
5. New limit is 1,050. Decision: NONE. **State: ARMED.**

The 15% cap has already been exceeded two to three times over, and the guard has no memory of it.
It then permits the next cycle. The same hole exists without any stop-out: realize −1,400, reopen,
carry −1,200, and the guard compares −1,200 against the limit while the episode has cost −2,600.

**This is not fixable by tuning.** Bounding an episode requires tracking realized deals for the
magic, not a snapshot of what is open right now.

Second-order consequence on a shared account: Exness stop-out is **magic-blind**. A 1524 blow-up
that reaches stop-out can liquidate GoldReaper, MatchaGrid and the BRK legs — the exact outcome the
per-magic scope was chosen to avoid. The guard cannot prevent this, because the broker acts first.

## What Codex recommends instead, and Claude agrees

Give magic 1524 its **own dedicated cent account**, funded with only the amount the owner is willing
to lose outright. Then the bound is structural: it is enforced by there being no more money in the
account, not by software that has to survive disconnects, terminal stalls and weekend gaps. Nothing
running inside one MT5 terminal can promise a hard cap through those.

The guard remains useful as an **early-warning sensor** on the shared account. It must not be
described as a bound.

---

## Remaining defects, accepted as valid

| # | Defect | Status |
|---|---|---|
| P0-2 | `InpMagic` accepts any value; no check of login / server / real-account / HEDGING. A stale `.set` with `InpMagic=8001` would make it liquidate a never-touch magic. On a netting account one ticket can carry deals from several magics. | to fix |
| P0-3 | `EventSetTimer` return value ignored. If registration fails, `OnTimer` never runs and startup still prints "armed" — a completely inert guard that looks live. | to fix |
| P1-4 | Halt persistence can fail open: neither `GlobalVariableSet` nor the file write is verified, `GlobalVariablesFlush` is never called, and the error message asserts the global halt stands even when it may not. A reboot then loads ARMED after a real cut. | to fix |
| P1-5 | Position enumeration is not a stable snapshot. If a lower-index ticket closes mid-scan, an already-counted ticket shifts down and is counted twice — a false cut; the opposite mutation causes a missed one. | to fix |
| P1-6 | `g_fires++` happens before the dry-run branch, so a dry run above threshold inflates the firing count with zero close attempts. **This is false evidence that the kill path was exercised** — precisely the claim the doctrine bar exists to prevent. | to fix |
| P1-7 | Pending orders are ignored entirely (`OrdersTotal()` is never scanned). A 1524 stop order placed before the cut survives it, triggers later, and recreates exposure while the state file says HALTED. | to fix |
| P1-8 | `CTrade::PositionClose()` returning `true` does not prove execution; the retcode is only checked when it returns false. Rejections, partial fills and timeouts go unlogged. | to fix |
| P2-9 | Halt file lives in `FILE_COMMON` and its name carries login + magic but not the broker server. Another terminal on the same VPS with the same numeric login would collide. | to fix |
| P2-10 | Cent-account operator trap: an owner meaning "$100 baseline" who types `100` gets 100 USC = $1, cutting at $0.15 — 100x too early. Status file has no currency column, so `-1500.00` (−$15) can be read as −$1,500. | to fix (doc + validation) |
| P2-11 | `InpCloseRetries` unvalidated; no wall-clock deadline or `IsStopped()` in the close loop. | to fix |
| P2-12 | Pure functions accept NaN/Infinity. A NaN percentage passes every comparison and makes the guard permanently unable to cut. `BG_State(true,-1)` returns HALTED. Tests cover none of this. | to fix |

## Corrected in the source by this audit, not defects in behaviour

- The comment at the basket sum claimed "Profit + swap + commission". It sums profit + swap only.
  The claim was false. Direction of the resulting bias is **cut too late**, never too early — and on
  this Exness Standard Cent account commission is zero, so it is currently inert.

## Explicitly cleared — do not re-raise

- Cross-currency positions: no defect. MT5 converts profit and swap into account currency.
- `POSITION_MAGIC` vs `input long`: no defect. Both signed 64-bit.
- Stale-selection after a failed `PositionSelectByTicket`: does **not** close a wrong magic — both
  loops `continue` before reading magic. It can undercount, causing a missed cut.
- Percentage arithmetic on a cent account: correct, no `/100` conversion needed.
- Retry loop termination for sane positive counts: correct.
- Normal boundaries in the pure functions (equality cuts, just-under holds, invalid limits disarm,
  usage above 100% intentionally unclamped): correct.
