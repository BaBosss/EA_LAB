# B16 KangarooGrid — Mechanism Characterization Final Report — 2026-08-30

Status: `COMPLETE / INDEPENDENT REVIEW PASS / READY FOR CANONICAL INTEGRATION`
Report level: `R2 MECHANISM CHARACTERIZATION`
Authority: `RESEARCH_ONLY`
Independent evidence-package review: PASS / HIGH at exact HEAD 8bd5faf8896e725b56906a2fcbffeab54649271e; material findings NONE, required repair NONE.
Working research verdict: `PARK / MECHANISM_CHARACTERIZED`; strategy/candidate verdict was not reassessed.
`MECHANISM_VALUE = STRONG` — the batch isolates repeatable depth, direction and spacing interactions, while exit/recovery value remains context-dependent.

Canonical finalization base: `e62001c5a0163c5b65790e13010b3e56bd657714`.
Build/source evidence lineage: `cf32ba8d32a8292e8f7b5ad2ef766e3442b20125`.
Build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`.
EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
Parent full tester set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`.
Model: `1`; Deposit: `USD 10,000`; Leverage: `1:100`; Optimization: `NONE`; HOLDOUT: `UNSPENT`.

## Executive answer

B16 is **not** a single universal edge plus a generic grid. Its measured behavior is a composition of fixed-direction RSI-fade entry, adverse-grid depth, source-specific spacing law, single/basket exits and overlap recovery, with material `Symbol × TF × Window` interaction.

The strongest reusable finding is that **position-engine depth, direction and spacing law are context-dependent structural variables**, not cosmetic settings. XAUUSD/H4 recovers almost all parent economics by depth 5, while XAUUSD/M15 still loses BWD at depth 5 and needs deeper parent exposure for the accepted BWD result. GBPUSD/H4 flips from a failing BUY BWD parent to a positive, low-DD SELL child across all six calendar years. FX contexts also show evidence that the fixed pip floor can mask the post-four ATR multiplier on realized paths.

Exit/recovery findings are more mixed. USDJPY/H1 improves aggregate net and native EqDD when Single TP or Basket TP is disabled, but those children collapse participation into a few long-lived episodes and selected years. XAUUSD/H4 instead becomes BWD-negative without Single TP, and its Basket-TP-off BWD cell hard-kills at 25% DD. Overlap removal is material but sign-reversing and produces one additional hard kill on XAUUSD/M15 BWD.

No result here authorizes a new default, parameter range, optimizer stage, HOLDOUT use, Candidate/DEMO/LIVE transition, deployment, trading or risk change.

## Evidence scope and prospectivity

The original matrix was committed prospectively before new tester evidence at `f5b9a2a06c13a4c5e5fe798710e00ca8e2f299f6`. The EURUSD/GBPUSD H4 extension was separately committed prospectively before its runs at `d0fac6fc7a3b35973237ad8ec5a1b1cba3ecca27`.

New execution produced **88 unique Strategy Tester reports**: 52 cells in the three-context matrix plus 36 cells in the EURUSD/GBPUSD H4 extension. Existing accepted evidence was reused instead of replayed: parent H02 cells, XAUUSD/H4 overlap-off, and depth-1/entry-only BT1/BT2/BT3 cells.

Mechanical audit result: **84/88 full-window eligible**, **4/88 confirmed hard-cage kills**, `0` unresolved suspects, `0` nonzero tester exits, exact intended EX5/build receipt, exact symbol identity and leverage `1:100` on all 88 runs. The tester log, not PF inference, confirms the four `[RISK] HARD KILL` events.

Across the nine preregistered mechanism hypotheses and five contexts, **45 context-level evaluations** resolve to `18 HYPOTHESIS_FALSIFIED`, `24 HYPOTHESIS_NOT_FALSIFIED`, and `3 UNKNOWN_MECHANICAL_INELIGIBLE`. `FALSIFIED` means the exact preregistered statement failed; it does not mean the EA concept itself failed.

Machine evidence: `factory/runs/b16_characterization_20260830/aggregate/`. Raw compressed reports and exact tester INIs/sidecars: `factory/runs/b16_characterization_20260830/evidence/`.

## Exact mechanics under test

Source identity is reconciled from build ref `cf32ba8d...` through canonical base `e62001c5...`: `Boss_16_KangarooGrid.mq5` SHA256 `e22f64302ea443c5bec14c22fbb4787002f1c88742b9ca30d416040affe4e8d3`; `Kangaroo.mqh` SHA256 `4c1b6388dd29a7b5d390338d0f553b7ea4d69f01a7d4b74f701434c32f5bf7c6`; `Entry_KangarooRSI.mqh` SHA256 `e0bdf36e1e9dc581fd1633d96cfee06b81bc49e2e9e73d6036c728912ca8a64f`. Relevant Git-byte diff from build source ref to current canonical base is `NONE`.

B16 uses a fixed direction per instance. BUY arms when RSI on the last closed chart bar is below `_16_RsiLow`; SELL arms above `_16_RsiHigh`. A first market entry is allowed only on the first tick of a new bar while flat. Grid adds do **not** require another RSI signal: they fire intrabar on fresh adverse price extremes.

Grid distance for the next add is `max(last-closed-bar ATR × zone multiplier, _16_MinDistPips × digit-aware pip size)`. Orders 2–4 use `_16_AtrMultFirst4=0.8`; order 5 onward uses `_16_AtrMultAfter=1.4` in the parent. Default lot behavior is flat `0.01` with `_16_LadderMult=1.0`, and the accepted parent hard cap is 10 positions.

The Kangaroo module is the single exit owner. In normal operation it evaluates: hard cage/halt first; then single-position managed ATR TP; multi-position net-dollar basket TP; dormant flatten only if explicitly enabled; overlap pair-close of newest + oldest positions; then adverse add; then a new first entry if flat/new bar. Per-order ATR SL remains protective; broker TP is not used. Full source-bound workflow: `docs/research/B16_MECHANISM_WORKFLOW.md`.

## Frozen parent contexts

| Context | MAIN PF / trades / net / EqDD | BWD PF / trades / net / EqDD |
|---|---|---|
| XAUUSD/H4 | 4.08 / 79 / +707.78 / 6.27% | 1.44 / 148 / +512.69 / 8.29% |
| USDJPY/H1 | 1.53 / 275 / +252.53 / 3.85% | 1.11 / 267 / +44.10 / 2.40% |
| XAUUSD/M15 | 1.25 / 1577 / +2643.64 / 11.88% | 1.10 / 1463 / +1002.69 / 14.86% |
| EURUSD/H4 | 6.39 / 64 / +126.54 / 1.42% | 0.25 / 51 / -553.81 / 8.46% |
| GBPUSD/H4 | 2.46 / 60 / +115.98 / 1.93% | 0.44 / 61 / -736.29 / 10.61% |

## Finding 1 — position depth is structural, but the required depth is context-specific

Accepted entry-only controls already showed different outcomes: XAUUSD/H4 entry-only MAIN `+149.08` / BWD `-32.09` (`FALSIFIED` dual-window positivity); USDJPY/H1 `+172.87 / +33.22`; XAUUSD/M15 `+213.52 / +80.64`.

Depth-cap ablations materially separate the three positive parent contexts:

| Context | Depth 2 MAIN/BWD net | Depth 4 MAIN/BWD net | Depth 5 MAIN/BWD net | Parent depth 10 MAIN/BWD net |
|---|---:|---:|---:|---:|
| XAUUSD/H4 | +54.39 / +242.08 | +667.05 / +430.67 | **+702.21 / +508.14** | +707.78 / +512.69 |
| USDJPY/H1 | +261.51 / +69.27 | +225.34 / -2.84 | **+263.54 / +44.10** | +252.53 / +44.10 |
| XAUUSD/M15 | +1640.02 / -884.24 | +1969.98 / -324.71 | +1092.69 / -254.52 | **+2643.64 / +1002.69** |

For XAUUSD/H4, depth 5 reproduces almost all parent net while lowering EqDD from `6.27%/8.29%` to `4.30%/7.59%`. This is a strong structural result, **not** a recommendation to set depth 5; no optimization/neighbor contract exists.

For XAUUSD/M15, every cap through depth 5 remains BWD-negative despite lower exposure. The accepted full-depth parent is BWD-positive `+1002.69`; therefore positions deeper than five are causally important to the accepted parent BWD outcome. Year evidence remains heterogeneous: depth-5 BWD is `+483.74` in 2020, `-145.00` in 2021 and `-593.26` in 2022.

USDJPY/H1 is non-monotonic: depth 2 and depth 5 stay positive in both windows, while depth 4 narrowly turns BWD negative `-2.84`. The mechanism is therefore not a simple "more depth = more edge" curve.
EURUSD/H4 and GBPUSD/H4 are different again: their BUY parents already fail BWD. Depth 2 reduces the BWD losses to `-41.37` and `-341.47` respectively, but depth 4/5 does not rescue dual-window positivity. Deeper exposure is therefore not a generic cure for the cross-window portability failure of these FX H4 BUY parents.

Exposure reconstruction supports the depth interpretation. XAUUSD/H4 depth-5 reaches the configured cap in both windows and multi-entry cycles contribute `77.43%` MAIN / `86.42%` BWD of gross profit. XAUUSD/M15 depth-5 reaches cap 5 and multi-entry gross-profit shares rise to `92.75% / 95.66%`. These are source-supported flat-to-flat cycle diagnostics, not inferred exit labels.

Mechanism assessment: **Position Engine / Depth = STRONG**. Reusable lesson: the economic contribution of deep recovery exposure must be characterized per Symbol×TF; a universal max-depth choice is not supported.

## Finding 2 — direction asymmetry is real and symbol-specific

The SELL-direction intervention changes only `_16_Direction: 1 -> 2`; entry remains the same fixed-direction RSI fade architecture.

The standout extension result is GBPUSD/H4. Its BUY parent is `+115.98 / -736.29` MAIN/BWD with EqDD `1.93% / 10.61%`. The SELL child is **`+283.20 / +268.97` with EqDD `1.72% / 1.27%`**. Every calendar year is positive: 2023 `+79.53`, 2024 `+84.46`, 2025 `+119.21`, 2020 `+173.13`, 2021 `+58.45`, 2022 `+37.39`.

This does not generalize automatically. EURUSD/H4 SELL is negative in both windows (`-52.14 / -214.92`); USDJPY/H1 SELL is also negative (`-488.21 / -182.33`). XAUUSD/H4 SELL remains positive (`+157.21 / +729.19`) but MAIN EqDD rises to `14.61%`, so it does not dominate its BUY parent trade-off.

XAUUSD/M15 SELL is more severe: both MAIN and BWD hit the hard 25% cage and are full-window ineligible. Pre-kill PF/net are preserved as event evidence but are excluded from full-window falsifier comparison.
Mechanism assessment: **Direction = STRONG**. Reusable lesson: B16's fixed-direction fade must be treated as a first-class strategy component; symbol portability cannot be evaluated from BUY-only evidence.

## Finding 3 — spacing law explains part of cross-symbol behavior

Source law is `max(ATR × multiplier, fixed-pip floor)`. Two one-change tests isolate its components: `PIPFLOOR_OFF` removes the 150-pip floor; `DEEP_SPACING_EQUAL` changes the post-four multiplier from `1.4` to `0.8` while preserving depth 10.

For EURUSD/H4, GBPUSD/H4 and USDJPY/H1, `DEEP_SPACING_EQUAL` produces **headline metrics identical to the parent in both windows**. Exposure proves the deep branch is reachable in relevant cells: maximum depths reach 6/8 on EUR/GBP BWD and 7/5 on USDJPY MAIN/BWD. The exact no-op realized output is therefore consistent with the fixed pip floor masking the multiplier change on the decisions that mattered; it is not proof that the floor exceeds ATR×1.4 on every possible tick.

`PIPFLOOR_OFF` is not inert on those FX contexts. USDJPY/H1 jumps from parent net `+252.53/+44.10` to `+1263.49/+523.95`, but EqDD also rises from `3.85%/2.40%` to `6.40%/6.76%`, so the preregistered beneficial-floor hypothesis is not falsified. EURUSD/H4 and GBPUSD/H4 also change materially when the floor is removed.

XAUUSD/H4 shows the opposite realized signature: removing the pip floor produces exact parent headline metrics, while equalizing deep ATR spacing changes results substantially (BWD net falls from `+512.69` to `+63.25`, EqDD rises from `8.29%` to `12.73%`). The accepted XAUUSD/H4 path is therefore governed differently from the three FX contexts.

XAUUSD/M15 is sensitive to both spacing interventions. Neither produces a clean dominance over parent, reinforcing that spacing and depth interact with path/regime rather than acting as separable universal knobs.

Mechanism assessment: **Spacing architecture = STRONG**. Reusable lesson: absolute pip floors can dominate or mask ATR-zone parameters depending on symbol scale and realized path; cross-symbol parameter portability must verify which branch of `max()` is actually binding.

## Finding 4 — exit/recovery value is context-dependent, not monotonic

### Single-position TP

USDJPY/H1 is the only context that falsifies the preregistered claim that the active Single TP is beneficial to the parent trade-off. With `_16_TpSingleAtrMult=0`, MAIN becomes `+276.74 / EqDD 1.21%` and BWD `+229.74 / 1.50%`, versus parent `+252.53 / 3.85%` and `+44.10 / 2.40%`.

That apparent improvement comes with severe participation collapse: MAIN closes only 3 trades in 2023, 0 in 2024 and 1 in 2025; BWD closes 13 in 2020, 0 in 2021 and 2 in 2022. The result is therefore a strong mechanism clue but a weak standalone strategy-quality argument.

XAUUSD/H4 moves the opposite way across windows: Single-TP-off MAIN rises to `+1952.33`, but BWD falls to `-399.24`. XAUUSD/M15 remains barely positive BWD `+16.21` while EqDD rises to `17.95%`. EURUSD/GBPUSD H4 also remain BWD-negative. Overall Single TP contribution is **UNCLEAR** across the family.

### Multi-position basket TP

USDJPY/H1 also falsifies the beneficial Basket-TP hypothesis: Basket-TP-off yields `+477.20 / +445.38` with EqDD `2.36% / 2.03%`, better than parent on both preregistered dimensions. But participation collapses even further: no 2024/2021 closures and only 2 MAIN-2025 / 5 BWD-2022 closed trades.

The opposite risk appears on XAUUSD/H4: Basket-TP-off BWD reaches a confirmed hard kill at `25.00%` DD on market time `2022-07-13 15:41:40`; that pair is mechanically ineligible for a full-window benefit verdict. XAUUSD/M15 Basket-TP-off is BWD-negative `-990.88` with EqDD `20.50%`.

Mechanism assessment: **Basket TP = UNCLEAR**. The USDJPY aggregate result is interesting but cannot be promoted without addressing the participation/holding-duration consequence already visible in the same evidence.

### Overlap pair-close

No mechanically eligible context meets the preregistered criterion for proving overlap harmful/dispensable across both windows. XAUUSD/H4 remains the clearest sign reversal: removing overlap changes MAIN from `+707.78 / 6.27%` to `-924.01 / 22.28%`, while BWD improves from `+512.69 / 8.29%` to `+890.51 / 7.70%`.

USDJPY/H1, EURUSD/H4 and GBPUSD/H4 show smaller MAIN improvements but worse BWD net and/or DD after overlap removal. XAUUSD/M15 overlap-off BWD hits the hard cage at `25.01%` on `2022-09-15 07:54:40`, making that pair `UNKNOWN_MECHANICAL_INELIGIBLE` for the full-window falsifier.

Mechanism assessment: **Overlap recovery = UNCLEAR but material**. It can materially reduce or worsen realized risk depending on path/window; one unconditional sign is unsupported.

## Hard-cage evidence

Four cells produced tester-log-confirmed hard kills around the active 25% risk-cage threshold:

| Cell | Market time | DD at hard kill | Full-window use |
|---|---|---:|---|
| BasketTP-off XAUUSD/H4 BWD | 2022-07-13 15:41:40 | 25.00% | INELIGIBLE |
| Overlap-off XAUUSD/M15 BWD | 2022-09-15 07:54:40 | 25.01% | INELIGIBLE |
| SELL XAUUSD/M15 MAIN | 2025-02-11 03:13:40 | 25.08% | INELIGIBLE |
| SELL XAUUSD/M15 BWD | 2020-08-07 01:20:40 | 25.18% | INELIGIBLE |

The truncation sidecar initially flagged three of these; the fourth had an idle tail below the generic threshold. Direct tester-log mapping found all four. This is a harness lesson: for cage-capable strategies, log-confirmed kill events outrank idle-tail heuristics when establishing full-window eligibility.

A working cage is not evidence that the underlying configuration is safe. Here the cage events are strategy/risk evidence showing which counterfactuals reached the configured protection boundary.

## Cross-context mechanism map

| Context | Strongest supported interpretation | Important counter-evidence / boundary |
|---|---|---|
| XAUUSD/H4 | Position engine is material; depth 4–5 captures most accepted parent economics; post-four ATR widening matters | Entry-only BWD fails; Single TP and overlap show window sign reversals; Basket-TP-off BWD hard-kills |
| USDJPY/H1 | Entry component survives alone; depth 2/5 remain positive; current Single TP and Basket TP are falsified as beneficial by the preregistered trade-off rule | Exit-off children have severe participation collapse; SELL fails; pip-floor removal raises DD despite higher net |
| XAUUSD/M15 | Full deep engine is critical to accepted BWD; multi-entry GP share is very high | Depth 1–5 cannot reproduce BWD; SELL hard-kills both windows; overlap-off BWD hard-kills |
| EURUSD/H4 | Fixed pip floor materially affects realized behavior; deep ATR multiplier change is headline-inert | BUY parent already fails BWD; depth changes do not rescue; SELL also fails |
| GBPUSD/H4 | Direction is decisive: SELL converts failing BUY BWD into positive low-DD MAIN+BWD across all six years | BUY depth/exit changes do not rescue consistently; no Candidate/optimization authority follows |

## Mechanism-value assessment

| Component | R2 assessment | Evidence basis |
|---|---|---|
| Position engine / max depth | **STRONG** | Prospective depth 1/2/4/5 controls plus parent depth 10 separate context-specific depth requirements |
| Direction | **STRONG** | Same engine with fixed BUY→SELL change produces opposite portability outcomes by symbol; GBPUSD/H4 SELL is positive every year |
| Spacing law | **STRONG** | Source-bound `max(ATR×mult,pip floor)` interventions reveal different binding behavior across FX/XAU contexts |
| Single TP | **UNCLEAR** | USDJPY trade-off improves when disabled, but other contexts degrade/sign-reverse and participation can collapse |
| Basket TP | **UNCLEAR** | USDJPY improves on aggregate trade-off, while XAUUSD/H4 removal hard-kills BWD and XAUUSD/M15 BWD deteriorates |
| Overlap recovery | **UNCLEAR / MATERIAL** | Large sign reversals and one hard-kill; no mechanically eligible context proves universal dispensability |

Overall `MECHANISM_VALUE = STRONG` describes the **information value and separability of the mechanism findings**, not a production-quality grade.

## Exposure, participation and concentration

Cycle/exposure diagnostics come from the accepted H03 flat-to-nonflat-to-flat parser applied without semantic changes, with one explicit overlay: the parser's legacy `configured_orders_per_side_cap=10` field is replaced for interpretation by the exact variant cap `2/4/5/10`. Raw parser fields remain preserved.

Multi-entry gross-profit contribution remains large in many successful children. Examples: XAUUSD/H4 depth-5 `77.43% MAIN / 86.42% BWD`; XAUUSD/M15 depth-5 `92.75% / 95.66%`; GBPUSD/H4 SELL `70.96% / 58.94%`. The GBP SELL result therefore does not mean the position engine becomes irrelevant; it means the direction signal and engine interact more favorably on that context.

The USDJPY/H1 exit-off results illustrate why participation must accompany PF/net/DD. SingleTP-off and BasketTP-off can hold positions through most of a year and close only a few tickets; their aggregate improvements are not equivalent to a broadly distributed independent-trade edge.

Native MT5 EqDD remains the authoritative drawdown metric in every parent/child comparison. Closed-deal balance curves and underwater series in the visual pack are explicitly labelled proxies because the HTML table does not expose a native intratrade equity time series suitable for exact reconstruction.

## Visual pack

All visuals are `VISUAL_ONLY_NO_AUTHORITY` and are reproducible from committed aggregate/raw evidence under `factory/runs/b16_characterization_20260830/final_report/`:

- `r2_mechanism_verdict_matrix.svg` — 9 mechanisms × 5 contexts falsifier matrix.
- `r2_depth_ladder_net.svg` — depth 1/2/4/5/10 net ladder for the three contexts with accepted entry-only controls.
- `r2_direction_comparison.svg` — BUY parent vs SELL child.
- `r2_spacing_comparison.svg` — parent vs pip-floor-off / equal deep spacing.
- `r2_exit_comparison.svg` — parent vs SingleTP/BasketTP/Overlap disabled.
- `r2_selected_year_distribution.svg` — selected yearly net distribution.
- `r2_gbp_sell_balance_proxy.svg` and `r2_gbp_sell_underwater_proxy.svg`.
- `r2_usdjpy_exit_balance_proxy.svg` and `r2_depth_underwater_proxy.svg`.
- `r2_exposure_selected.svg`, `r2_cage_kills.svg`, `r2_falsifier_counts.svg`.
- `b16_mechanism_workflow.svg` plus the source-bound D1 workflow document.

## Robustness state / what was NOT run

- Model 1: `RUN` for this milestone.
- Model 4: `NOT RUN / BT0 remains separately blocked by canonical runtime-policy conflict`; no Model-4 claim is created here.
- Optimization / sensitivity lattice: `NOT RUN / NONE`.
- HOLDOUT 2026H1: `UNSPENT`.
- Monte Carlo: `NOT RUN`.
- Broker/execution portability beyond the accepted ThinkMarkets tester lineage: `NOT RUN`.
- Formal regime classifier/timeline for B16: `NOT RUN`.
- Candidate/DEMO/LIVE forward test: `NOT AUTHORIZED`.

## Assessment axes

- Working `VERDICT`: `PARK / RESEARCH_ONLY` — mechanism characterization is complete; candidate quality is not established.
- `QUALITY_GRADE = UNRATIFIED` — no authoritative A/B/C/D mapping is invented.
- `EVIDENCE_CONFIDENCE = UNRATIFIED` — exact evidence is strong for this R2 question, but canonical grade mapping remains unresolved.
- `BUILD_POTENTIAL = HIGH` as a **research interpretation only**: there are multiple isolated mechanisms with direct follow-up value, especially direction and spacing. This is not promotion authority.
- `KINT-001`: unchanged / OPEN.

## Known unknowns

1. Ordinary MT5 report history does not name which B16 discretionary exit branch closed each ticket; causal exit attribution relies on one-change counterfactuals.
2. Native intratrade equity/underwater series is unavailable from the report tables; closed-deal proxies do not replace native EqDD.
3. The exact holding-time consequence of USDJPY exit-off variants is visible indirectly through sparse closures/active-time concentration but has not been converted into a separately preregistered acceptance criterion.
4. GBPUSD/H4 SELL has not been tested as a SELL configuration on adjacent GBPUSD timeframes under this contract.
5. No stable optimization region exists because optimization was intentionally not opened.
6. HOLDOUT remains protected and cannot be used to choose among these mechanism children.

## Next research routing — proposals only, not auto-opened

**Highest-information next child:** `HYP-B16-GBP-SELL-TFPORT-01` — keep the exact SELL child configuration frozen and observe GBPUSD `H1` and `M15` on the same MAIN/BWD windows. This is a context-portability test, not a parameter sweep. The direct consumer is whether the strong GBPUSD/H4 direction asymmetry is H4-specific or a reusable GBP direction mechanism. A future contract must freeze its falsifier before any tester launch.

**Read-only follow-up:** quantify cycle/holding-duration and concentration consequences of USDJPY/H1 `SINGLETP_OFF` and `BASKETTP_OFF` versus parent before considering any exit redesign. Existing evidence already warns that aggregate net/DD improvements coexist with very sparse yearly closures; no new MT5 run is required for this diagnostic.

**Parked boundary question:** XAUUSD/M15 suggests deeper-than-5 exposure is required for the accepted BWD outcome, but immediately trying depth 6/7/8/9 would become an optimizer-like search. Do not open that sequence without a separately justified structural boundary contract and loop breaker.

**Instrumentation question:** if future research needs to prove when `_16_MinDistPips` versus ATR spacing binds, add deterministic observation/instrumentation under a separate contract rather than infer every historical trigger from missing ATR snapshots.

## Decision and authority ceiling

This milestone is **ACCEPTED BY AUTHOR AS EVIDENCE-COMPLETE, pending independent exact-head review**. It closes the bounded B16 mechanism-characterization expansion: no more symbols, depths or adaptive parameter values are added inside this batch.

The report grants **no** H04 unlock, optimization, HOLDOUT use, Candidate selection, DEMO/LIVE transition, deployment, trading, runtime attach/detach, risk/default change, KINT resolution, Grade mapping or owner attestation.

Canonical integration/push is intentionally delegated to a separate lane. That lane must re-fetch current `origin/master`, preserve unrelated work, reconcile this reviewed head, rerun impacted deterministic checks if canonical moved, and only then perform an eligible normal fast-forward push.

## Traceability

Primary preregistration: `docs/research/B16_MECHANISM_CHARACTERIZATION_CONTRACT.md`.
EUR/GBP extension preregistration: `factory/runs/b16_characterization_20260830/extension_eurgbp_h4/EXTENSION_CONTRACT.md`.
Execution manifests: `execution_manifest.csv` and `extension_eurgbp_h4/execution_manifest.csv`.
Mechanical acceptance: `aggregate/mechanical_acceptance.json`.
Pair falsifiers: `aggregate/pair_falsifier_summary.csv`.
Cell metrics: `aggregate/cell_summary.csv`.
Cycle/exposure: `aggregate/cycle_exposure_summary.csv`.
Year distribution: `aggregate/year_split.csv`.
Hard-kill mapping: `aggregate/cage_kill_evidence.json`.
Source reconciliation: `aggregate/source_byte_reconciliation_final.txt`.
Final machine summary and visuals: `factory/runs/b16_characterization_20260830/final_report/`.

Every measured statement in this report is sourced from those exact artifacts or the accepted parent/BT1/BT2/BT3 evidence named in the contracts. Interpretations are explicitly separated from measured evidence. Unsupported mechanics remain `UNKNOWN` rather than inferred.
