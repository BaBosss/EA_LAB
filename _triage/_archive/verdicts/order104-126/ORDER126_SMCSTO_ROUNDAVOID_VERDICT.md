# ORDER-126 — SMCxSTO SL-rescue via ATR round-number avoidance — VERDICT

**Claude/Opus 2026-07-19: NO LIFT → keep 991070 as-is. Idea #3 (round-number SL avoidance) closed for SMCxSTO.**

## What was built
Additive lever on `(EXP)_EmaStoRev` (magic-agnostic test copy): `_09_RoundAvoidPips` (default 0=OFF,
byte-identical) + `_09_RoundStepPips` (50-pip grid). When the ATR-based SL lands within N pips of a round
level, widen it past the stop-hunt cluster (further from entry, never tighter). mql-review PASS, compile 0/0.
**Neutrality verified:** RA=0 reproduces the demo config exactly (EURUSD H1 Model-1 MAIN 1.50/136t).

## Test — SL fan (2.4/3.0/3.6 ×ATR) × round-avoid (0/5/10/15 pip), EURUSD H1 both-window

**Model 1** (all RA levels): the SL axis is ALREADY a plateau at RA=0 — sl2.4 1.05/1.03 · sl3.0 1.50/1.24 ·
sl3.6 1.49/1.09 (all ≥1.0). Round-avoid ON mildly DOWNGRADES the center (sl3.0: 1.50→1.42→1.43). No help.

**Model 4** (the deciding measure — SMCxSTO has fill-sensitive BE-move logic; the deployed 991070 was
validated on M4):
| config | MAIN | BWD |
|---|---|---|
| RA0 sl2.4 (SL−20%, fragile edge) | **0.94** | **0.99** |
| RA10 sl2.4 (round-avoid ON) | **0.90** | 1.14 |
| RA0 sl3.0 (center = deployed) | 1.39 | ~1.24 (demo-validated) |

## Findings
1. **The SL-fragility is REAL and Model-4-specific.** M1 said the SL−20% edge is fine (1.05/1.03); M4 says
   it's a cliff (0.94/0.99) — reproduces Lane C exactly. The M1→M4 sign-region shift confirms SMCxSTO is
   genuinely **fill-sensitive** → validates the Model-4-mandatory-on-model-switch-cliff rule. (Never judge
   this EA's SL robustness on Model 1.)
2. **Round-number avoidance does NOT fix it.** At the fragile edge (sl2.4 M4), round-avoid ON makes MAIN
   *worse* (0.94→0.90). The failure mode is fill/BE-move sensitivity at a tight SL, **not** round-number
   stop-hunting — idea #3 targets the wrong mechanism.
3. **Deployed config (SL=3.0, center) is robust** on M4 (1.39 MAIN) — the fragility is only at the −20%
   edge, which is not what's deployed. 991070 stays fine as-is; you just can't tighten its SL.

## Disposition
- **Keep demo 991070 (SL=3.0) as-is.** No swap. QuantCorner idea #3 (round-number/stop-hunt avoidance) =
  closed for SMCxSTO (wrong failure mode).
- The `_09_RoundAvoid*` lever stays in the EA (default OFF, byte-identical) as a reusable additive — available
  for any EA whose losses genuinely cluster at round numbers, but not this one.
- Next build-on for SMCxSTO edge = a different HOME (TF/symbol), not SL tuning (matches Lane C conclusion).
- Evidence: `_mt5_auto/ORDER126_SL_ROUNDAVOID.csv` (M1 fan) · `_mt5_auto/ORDER126_M4.csv` (M4 decisive).
