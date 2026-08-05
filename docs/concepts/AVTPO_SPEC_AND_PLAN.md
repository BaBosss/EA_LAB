# AVTPO — Master EA Spec Card + start-to-finish build plan

**Concept source:** [AMT_AVWAP_TPO_SYSTEM.md](AMT_AVWAP_TPO_SYSTEM.md) (Auction Market Theory /
AVWAP / TPO, extracted 2026-08-04).
**chain_id:** `EA_AVTPO_20260804_01`
**Author seat:** Opus. **Date:** 2026-08-04. **Status:** SPEC ONLY — nothing built, no evidence, no verdict.

> **Deviation from the skill template, stated up front:** `strategy-and-risk` emits one Master EA
> Spec Card. This work ships in two pieces — **Module A is a classifier library, not an EA** — so
> this file carries a *component contract* for Module A (§2) plus the full EA Spec Card for the
> eventual `AVTPO` (§3). Module A is built and judged **first and alone**; the EA card exists so
> the target is on paper before the first line of code, not so it gets built now.

---

## 1. Why Module A first, and what would kill it

Module A = a deterministic day-type classifier: **ROTATION / TREND / NO-TRADE**, computed from
Initial Balance + value-area geometry only.

Three reasons it goes first:

1. **It is the falsifiable half.** The entry stack (Modules B/C) is only worth building if the
   regime read carries information. Testing the gate alone is smaller, cheaper, and can actually fail.
2. **We already own hosts to test it on.** It can be run as an overlay on existing EAs, against a
   base control run — no new EA needed to get a first answer.
3. **There is a competing implementation already in the chassis.** `ea_template/core/Regime.mqh`
   is an ADX(+DI/−DI) + ATR-spike gate. Module A must be measured **against it**, not just against
   no-gate. If a structural classifier cannot beat an ADX gate, it does not deserve an EA.
   (Memory `correct-check-exists-only-its-cage-calls-it`: find the existing implementation before
   writing the second one.)

**The honest prior, from this repo's own evidence:** momentum/breakout has edge here;
mean-reversion does not (skill `strategy-and-risk` §Signal Selection; memory
`feedback-optimize-before-killing-reversion` bounds how hard that may be applied). That prior says
the ROTATION branch is the weak branch. So Module A's likely value is the **TREND** and
**NO-TRADE** outputs, and Phase 6 should build **Module C before Module B**.

**Pre-registered kill for Module A** (write this down *before* any result exists):
- classifier emits a single state for >80 % of days ⇒ **inert**, stop; or
- classification flips for >20 % of days under a ±1 h GMT-offset perturbation ⇒ **not a market
  read, an artifact of the session clock**, stop; or
- Phase 3 overlay changes no metric in any digit vs the base control ⇒ **inert**, stop
  (memory: numbers identical to base is evidence of inertness, not of safety).

---

## 2. Module A — component contract

**Vehicle:** `ea_template/core/AmtProfile.mqh` (chassis library, additive, mode 0 = inert no-op —
same shape as `Regime.mqh` so it composes with the existing cage).

### 2.1 Inputs

| Input | Default | Note |
|---|---|---|
| `_A_Enabled` | 0 | 0 = inert no-op (chassis convention) |
| `_A_BrokerGMTOffset` | *required* | **no default is permitted** — see §2.5 |
| `_A_ProfileAnchor` | `NY_OPEN` | which clock starts the "day": `BROKER_DAY \| NY_OPEN \| LONDON_OPEN` |
| `_A_TPOBracketMin` | 30 | TPO bracket size |
| `_A_ValueAreaPct` | 70 | value area |
| `_A_IBMinutes` | 60 | Initial Balance duration |
| `_A_BinMode` | `ATR_FRACTION` | row height: `ATR_FRACTION` (ATR(20,D1)/50) or `TICKS` |
| `_A_MedianLookbackDays` | 20 | for VA-width and IB-range medians |
| `_A_AcceptCloses` (K) | 2 | closes beyond a level that constitute acceptance |
| `_A_AcceptWindow` (M) | 6 | bars within which those closes must occur |
| `_A_TrendThreshold` | 2 | net imbalance evidence for TREND |
| `_A_RotThreshold` | 2 | net balance evidence for ROTATION |

### 2.2 State (pure output struct)

```
struct AmtState {
  datetime day_start;
  bool     ib_complete;
  double   ib_high, ib_low, ib_mid, ib_range;
  double   vah, val, poc;              // developing, this session
  double   pd_vah, pd_val, pd_poc;     // prior session
  double   pd_high, pd_low;
  int      dop;                        // -6 .. +6
  int      balance_evidence;           // 0..5, count of B1..B5
  int      imbalance_evidence;         // 0..5, count of T1..T5
  int      mode;                       // -1 = TREND, 0 = NO_TRADE, +1 = ROTATION
}
```

### 2.3 The classifier (explicit, unweighted, on purpose)

Evidence counters — **no fitted weights in v1**; the thresholds are the only levers, and they stay
frozen until Phase 2 has measured the distribution.

Balance evidence (each +1 to `balance_evidence`):
- **B1** price inside IB
- **B2** developing VA width ≤ median(VA width, 20 d)
- **B3** today VA ∩ prior-day VA ≥ 60 % of today VA
- **B4** |POC − PD_POC| ≤ 0.25 × ATR(20, D1)
- **B5** IB range ≤ 0.50 × ATR(20, D1)

Imbalance evidence (each +1 to `imbalance_evidence`):
- **T1** |DOP| ≥ 4 (price outside prior-day VA / prior-day range)
- **T2** acceptance beyond an IB edge: ≥ K closes beyond within M bars
- **T3** IB range ≥ 1.00 × ATR(20, D1)
- **T4** developing VA width ≥ 1.5 × median(VA width, 20 d)
- **T5** |POC − PD_POC| > 0.50 × ATR(20, D1)

```
mode = TREND    if (imbalance − balance) ≥ _A_TrendThreshold
       ROTATION if (balance − imbalance) ≥ _A_RotThreshold
       NO_TRADE otherwise
```

**DOP** is the ladder from the source system, computed from the four nested structures
(today IB → today VA → prior-day VA → prior-day range): `0` inside IB and around prior value;
`±1…±3` progressively outside IB and today's VA; `±4…±6` beyond yesterday's VA and range.

### 2.4 Profile construction — TPO, not volume profile

Build the profile as **true TPO** (count time brackets that touched each price row), **not** as a
volume profile. Reason is not aesthetic: MT5 FX/CFD supplies **tick volume**, not traded volume, so
a volume profile would silently measure trade count. TPO is time-based and therefore immune.
Any future volume-profile variant must declare on its face that it runs on tick volume.

### 2.5 Mandatory guards (these are the parts that go wrong)

- **GMT offset must REFUSE, not default.** If `_A_BrokerGMTOffset` is absent or unreadable, the
  module must fail init loudly. It must never fall back to a guess — a wrong offset shifts *every*
  level while the backtest still looks plausible (memory `absolute-price-constant-poisons-backtests`,
  `unreadable-input-must-refuse-not-skip`).
- **Assert at init** and stamp into the log: resolved offset, anchor, session boundaries in broker
  time, bin size in points, ATR(20,D1) at init.
- **Instrument everything the classifier actually reads** — every field of `AmtState` per session,
  not a proxy, or the probe's "nothing moved" report will contradict the classifier
  (memory `instrument-what-the-guard-actually-reads`).
- **Fire counts are part of the output, always.** A state that is never emitted is `UNTESTED`,
  not "passed" (VERDICT GATE, guard/filter row).
- Any PowerShell/Python wrapper must set `PYTHONIOENCODING=utf-8`
  (memory `thai-output-kills-a-suite-inside-the-hook`).

---

## 3. Master EA Spec Card — `AVTPO` (target, not yet buildable)

```yaml
spec_card_version: "3.0"
chain_id: "EA_AVTPO_20260804_01"
chassis: BossV2                       # entry/basket module on ea_template; MM/SL/cage/Persist from chassis
identity:
  ea_name: "AVTPO"
  symbol: "XAUUSD"                    # primary home; BTCUSD M30 + EURUSD as cohort tests
  timeframe: "M5"                     # M15 as the first alternate

strategy:
  trade_style: "INTRADAY"
  entry:
    indicator: "AmtProfile (Module A) + EMA8/21 cross + MFI(7,hlc3) + OBV"
    condition: >
      Module A must be TREND or ROTATION (NO_TRADE blocks all entries).
      TREND  (Module C): acceptance beyond IB edge or prior-day VA edge
        (>=K closes beyond within M bars) AND OBV slope agrees AND MFI on the same side of 50
        -> enter on the RETEST of the broken level, EMA8/21 aligned, close-confirmed.
      ROTATION (Module B): level tagged (VAH/VAL/IBH/IBL) and NOT accepted
        (<=K closes beyond within M bars) -> EMA8/21 cross back through, close-confirmed.
        Veto if MFI is on the wrong side of 50 or OBV slope agrees with the breakout.
  distance:
    mode: "FIXED"
    min_dist_pips: 0                  # single position; no grid spacing in this design
  lot_sizing:
    mode: "FIXED"                     # no escalation, ever, in this EA
    base_lot: 0.01
  take_profit:
    mode: "STRUCTURE"                 # next structural reference, not a fixed R
    scope: "SINGLE"
    # TREND : TP1 = next naked level / single-print zone, TP2 = IBR L1 (100%) -> L2 (200%)
    # ROTATION: TP1 = POC or session AVWAP, TP2 = opposite VA edge
    # partial at TP1, remainder to TP2, move to breakeven after TP1
  stop_loss:
    mode: "STRUCTURE"
    max_sl_pips: 250                  # hard ceiling regardless of structure distance
    # TREND : back inside the broken level + buffer
    # ROTATION: beyond the tagged level + buffer (or beyond IBR L1)

recovery:
  hedging:
    enabled: false                    # deliberate: no hedge, no grid, no recovery leg

risk:
  risk_level: "L1"                    # single position, fixed SL
  risk_per_trade_pct: 0.5
  max_drawdown_target_percent: 12.0
  max_positions: 1
  max_total_lot: 0.10
  daily_loss_limit_pct: 3.0
  emergency_exit_dd_pct: 25.0

session_cage:
  trade_windows: ["ASIA", "LONDON", "NY"]   # per-symbol, broker time, offset pinned in .set
  max_trades_per_session_per_symbol: 2
  flat_at_session_end: true
  no_entry_before_ib_complete: true
```

**Notes required by the skill's rules:**
- `risk_level: L1` — single position, fixed SL. No grid, no martingale, no hedge. Nothing here
  approaches L4/L5, so no user risk acceptance is required and code generation is permitted.
- Hard caps `max_total_lot`, `max_positions`, `emergency_exit_dd_pct` are all present.
- Account type: hedging not required (no hedge legs).
- `chassis: BossV2` — the standing default; no standalone justification needed.

---

## 4. Build plan, start to finish

Each phase states its deliverable, its cage, and a **pre-registered** acceptance number.
Acceptance criteria are committed **before** the run that measures them
(memory `falsifier-satisfied-by-unexercised-mechanism`).

### Phase 0 — persist the concept ✅ done 2026-08-04
`docs/concepts/AMT_AVWAP_TPO_SYSTEM.md` + this file, committed.

### Phase 1 — Module A library + pure cage
- **Deliverable:** `ea_template/core/AmtProfile.mqh`; `scripts/_test/run_amt_profile_tests.ps1`.
- **Cage:** hand-computed fixtures — a synthetic session where VAH/VAL/POC/IB/DOP are known by
  construction, one fixture per output field.
- **Accept:**
  - every field of `AmtState` covered by ≥1 fixture with a hand-computed expected value;
  - ≥3 **SPECIFICITY** cases: a session that must classify TREND, one that must classify ROTATION,
    one that must classify NO_TRADE (memory `gate-specificity-not-just-sensitivity`);
  - the cage is **proven able to fail**: mutate one constant, show it goes red, revert.
- **Known limit to state in the write-up:** a pure cage proves only the pure half
  (memory `pure-cage-proves-only-the-pure-half`). Phase 2 is not optional.

### Phase 2 — measurement probe (trades nothing)
- **Deliverable:** `(EXP)_AMT_Probe.mq5` — an EA that opens no positions and writes one CSV row per
  session containing every `AmtState` field + the resolved session clock.
- **Runs:** XAUUSD M5 over **MAIN 2023.01–2025.12** and **BWD 2020–2022**; BTCUSD M30 as a second read.
- **Accept (pre-registered):**
  - NO_TRADE share between **10 % and 60 %** of sessions — 0 % or >80 % means inert or broken;
  - no single state exceeds **80 %** of sessions;
  - **±1 h GMT-offset perturbation flips ≤20 % of sessions** — this is the anchor-robustness test,
    and failing it kills the module (§1);
  - fire counts reported for every one of B1–B5 and T1–T5; **any evidence flag that never fires is
    reported as `UNTESTED`**, not quietly dropped.

### Phase 3 — overlay A/B on existing hosts (base control mandatory)
- **Hosts:** `PivotBreakout_XAU` (992017, strongest current CANDIDATE per memory
  `wave1-xau-eas-built`) and one grid host — memory `regime-gate-grids-not-breakouts` predicts the
  gate helps grids, not breakouts, so running both is the discriminating test, not a courtesy.
- **Arms:** (a) entries allowed only in TREND; (b) entries allowed in anything except NO_TRADE.
- **Accept (pre-registered):** both-window PF improves vs the base control **AND** the filter fired
  ≥ 20 times in each window **AND** trade count does not collapse (state trade count and drawdown
  next to every PF — memory `bar-cleared-by-non-participation`).
- **Mandatory in the write-up:** how many times the filter fired + the path of the base control run
  (VERDICT GATE, guard/filter row).

### Phase 4 — head-to-head vs the existing ADX gate
- Same host, same windows, three arms: no gate · `Regime.mqh` (ADX) · `AmtProfile.mqh`.
- **Accept:** Module A ≥ the ADX gate on both-window PF at comparable participation.
  If it loses, that is the answer — record it and stop. A second implementation that does not beat
  the first is a liability, not an asset.

### Phase 5 — decision gate
- **Passes** ⇒ `EDGE_CATALOG` entry as a reusable lever + proceed to Phase 6.
- **Inert / loses** ⇒ written down as inert, with numbers, in `EDGE_CATALOG`. It does not die
  silently, and it does not get quietly retried under a new name.
- Either way: scorecard/registry rows per the VERDICT GATE Row-X checklist.

### Phase 6 — the EA itself (only if Phase 5 passes)
- **Module C (TREND) first, Module B (ROTATION) second** — the repo's own evidence says reversion is
  the weak class, so the strong branch gets built and tested before the weak one.
- BossV2 chassis; spec = §3 above; then the full LADDER from skill `backtest-optimize-rigor`.
- **Model-4 is mandatory for this EA, not conditional.** Every entry fires at an exact structural
  level (VAH, IB edge, AVWAP). That is the tight-level fill-fiction class — a Model-2 pass would be
  worth nothing (memory precedent: grid under Model-2 manufactured a fake plateau, PF 3–4 → M4 0.61).
- Then: VERDICT GATE decision tree → MAIN ≥1.2 hard / BWD ≥1.0 soft → plateau .set → holdout →
  MC → correlation vs cohort → DEMO.

---

## 5. Out of scope, stated so it does not creep back in

- The source trader's cash-flow ritual (withdraw the day's profit, restart from a small base) —
  personal money policy, not EA logic.
- Discretionary reads he uses that have no data source in MT5: footprint, bookmap, order blocks,
  retail-vs-institutional inference, AB=CD counts.
- News-time judgement. If a news filter is ever added it needs its own control run and fire count.

---

```
NEXT STEP:
Forward this Spec Card to the mql-code-generator skill.
```
(For Module A only — `ea_template/core/AmtProfile.mqh` per §2. The `AVTPO` EA card in §3 must not
be forwarded until Phase 5 passes.)
