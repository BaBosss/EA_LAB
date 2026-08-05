# ORDER-215 part 2 — interim finding: two of five MatchaGrid reports are degenerate, and the surviving evidence never shows the cut-loss firing

**Status: not a final verdict.** This is what recon into "should we re-measure PF first" turned up
before any new backtest was run. It changes the order of work for the reason ORDER-222 (NuiIndy)
changed it: **the safety property is the thing in question, not the PF.**

Seat: Opus, 2026-07-26. No backtest run in this pass — everything below comes from re-reading five
existing `.htm` reports already on disk. No live account touched.

---

## 1. Two of the five cited reports are built on degenerate tick data

| report | window | Bars | Ticks | ticks/bar | PF | eqDD |
|---|---|---|---|---|---|---|
| `MG_CHFJPY_OOS_corr` | 2020.01–2023.01 | 74,778 | 4,399,319 | **58.8** | 2.08 | 23.75% |
| `MG_CHFJPY_IS_lot01` | 2023.01–2026.06 | 84,763 | 5,045,839 | **59.5** | 1.97 | 18.01% |
| `QWEN_MG_IS` | 2023.01–2025.01 | **12,073** | **47,229** | **3.9** | **0.17** | **89.12%** |
| `QWEN_MG_OOS` | 2025.01–2026.06 | 35,038 | 137,217 | **3.9** | 2.15 | 22.78% |

M15 over 2 years should be roughly 50,000 bars. `QWEN_MG_IS` has **12,073** — about a quarter of a
full history — with a tick density 15x thinner than the two healthy reports. This is the same
signature as the known degenerate-tick-generation failure mode (`mt5-no-disk-space-is-memory-ceiling`
memory note): the tester silently produced a partial/thin dataset rather than erroring.

**Both `QWEN_MG_IS` (PF 0.17, DD 89.12%) and `QWEN_MG_OOS` (PF 2.15) must be discarded** — not because
one is unflattering and the other isn't, but because both share the same 3.9 ticks/bar signature that
the two trustworthy reports don't. Discarding only the bad-looking one and keeping the good-looking one
sharing the identical defect would be worse than trusting neither.

**What survives:** `MG_CHFJPY_OOS_corr` (2020–2023, PF 2.08, the number the scorecard has been citing)
and `MG_CHFJPY_IS_lot01` (2023–2026.06, PF 1.97) — both healthy tick density, both **the same input set**
(confirmed identical `Inp*` values across all five reports, including `InpMagicNumber=20240001`, the
live magic). 3.4 combined years of trustworthy data, still all at Model 1 (see ORDER-215's existing
Model-4 gap — unchanged by this finding).

## 2. On the trustworthy data, the cut-loss never demonstrably fires

Grouped every `out` deal by identical timestamp across both healthy reports and summed profit per
cluster, looking for the signature ORDER-222 used to prove NuiIndy's switch fires (a basket closing
together for a clean percentage of the balance):

- 3 clusters of 3+ simultaneous closes with negative sum, over the full 3.4 years: −4.12, −8.17, −16.40
  net on 23–31 trades each. That is ordinary grid churn (some legs losing while the basket nets
  positive), not a cut event.
- One forced end-of-test liquidation per report (same artefact ORDER-222 flagged in the NuiIndy
  control arm).
- **No cluster resembling a clean percentage cut against `InpCutLossPercent=10` or
  `InpCutLossFixed=50` anywhere in 3.4 years of healthy data.**

The live config runs with **`InpCutLossMode=0`** in every report checked, including the ones citing the
scorecard's headline number. Recon already flagged that this input's meaning is undocumented anywhere
in the repo (closed-source `.ex5`, no `.mq5`). Two readings are both consistent with what's observed:

- **(a) mode 0 disables the cut entirely** — in which case "bounded grid + hard SL", the entire reason
  MatchaGrid is not filed as uncapped-ruin, is not a property of the config that is actually deployed.
- **(b) mode 0 is a real mode whose trigger condition this data simply never reached** — the same
  situation NuiIndy's `CutLoss=30` was in before ORDER-222 deliberately raised risk until it fired.

**This recon cannot distinguish (a) from (b), and does not try to.** Doing so needs the same technique
as ORDER-222: hold everything else fixed, deliberately increase the size/risk of a probe run (this EA's
lever is `InpLotStart`/`InpStepAddLot`, analogous to NuiIndy's `Lot_Divided`) until the historical data
would produce a deep drawdown, and watch whether a cut event appears. That is the next concrete step,
not a conclusion — it has NOT been run.

## 3. What is provisionally known now, stated at the confidence it deserves

- The linear-add lot ladder (`InpStepAddLot=0.01` every `InpStepEveryOrders=5`, not geometric) is
  measurably safer than NuiIndy's `Multiple3^order_count` escalation — but "safer than a martingale"
  is not the same claim as "has a working stop", and this recon has not verified the latter.
- The scorecard's 2.08 is unaffected by the degenerate-data finding (it was already sourced from the
  healthy `MG_CHFJPY_OOS_corr`, per the ORDER-215 part-1 downgrade note) but is now **also** unsupported
  by any live-config evidence that the cut-loss functions, which the part-1 downgrade did not know to
  ask.
- This is not yet DEAD-STRUCTURAL. That verdict requires the probe in §2 to come back negative — i.e.
  a deliberately deep-drawdown run showing no cut event at all, the same bar ORDER-222 used.

## 4. Recommended next step (not executed this pass)

Run the equivalent of `scripts/order222_cutloss_probe.ps1` against MatchaGrid: hold `InpGridPoints`,
`InpProfitTarget`, `InpStepEveryOrders` fixed, walk `InpStepAddLot` (or `InpLotStart`) up on the healthy
2020–2023 window until equity drawdown would exceed both `InpCutLossPercent=10` and a plausible
`InpCutLossFixed=50` trigger many times over, and check whether the deal log shows anything resembling
a basket-level cut. If nothing fires even under deliberately manufactured stress, that answers whether
`InpCutLossMode=0` means "off" — and would mean MatchaGrid, like NuiIndy pre-ORDER-222, has been
carrying an unverified safety claim on real money. This should happen **before** the Model-4 funnel from
ORDER-215's existing spec, for the same reason: measuring PF on a config whose safety claim is unproven
spends expensive M4 compute on the wrong question first.
