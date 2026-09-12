# B16 USDJPY/H1 R4 Episode-Unit Sampling Sensitivity — Preregistration

Status: `PREREGISTERED / RESEARCH_ONLY / ZERO_NEW_MT5 / NOT_EXECUTED`
Hypothesis ID: `HYP-Q09R2-B16-EPISODEUNIT-01`
Preregistration base: `37b672736972b26d2bfc4b04b1052d9821e47db4`
Authority: offline inference-method diagnostic only. It is not a Candidate Monte Carlo gate, ruin estimate, sample-floor policy, KINT resolution, strategy verdict or risk/default decision.

## Question and one logical change
Question: does treating individual closed tickets as independent resampling units understate uncertainty relative to preserving each reconstructed flat-to-flat inventory episode intact?
The sole comparison changes the bootstrap unit: individual realized ticket cashflow versus whole flat-to-flat episode cashflow.
The economic ledger, source reports, full-window total-net statistic, percentile interval definition, number of replications and random seed remain frozen.
No EA mechanics, tester model, Home, window, trade path or cost field changes.

## Frozen parent and evidence lineage
- Family/reference: Boss16 KangarooGrid, USDJPY/H1 BUY, RSI 14/30, `B16-R4-r1`.
- Accepted runtime head: `dcb5dd1dfd9b3df68a270985272b13fc5fee0890`.
- Installation lineage: `D:\Meta 5` / `MT5-lane1`.
- Set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`.
- EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
- Build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`.
- MAIN: 2023-01-01..2025-12-31; BWD: 2020-01-01..2022-12-31; HOLDOUT remains `UNSPENT`.
## Frozen source reports
The diagnostic consumes exactly these tracked report bytes and must refuse on any mismatch:
- M1 MAIN: `a329cc1fed28a98926ef38a07c05750c31d1f47dfd568dd31ac95d38fae64aa0`.
- M1 BWD: `327e6c9be6ea8569275c7c9a066043ce22e6e6ce1e9590b5cb4b3714cc98bc2a`.
- M4 MAIN: `03c00a3fe1c61b43aa6d613418dd0973908c83a628ca0c101902fcf2d9984117`.
- M4 BWD: `7561815ec2fa094176fa1b324a723c96a16dac8f22e74e2411d1503ab0ba85ed`.
Accepted integrity owner: `factory/runs/b16_r4_20260902/usdjpy_buy_h1/evidence_integrity.json`.
Episode reconstruction reference: `scripts/research/b16_h03/parse_h02_reports.py`; its flat/nonflat transitions must reconcile the accepted report before sampling.

## Frozen bootstrap design
Analyze each of the four reports independently; never pool Model1 with Model4 or MAIN with BWD.
Ticket arm: with N realized closed tickets, draw N ticket cashflows with replacement and sum them.
Episode arm: with K complete flat-to-flat episodes, draw K entire episode cashflows with replacement and sum them.
Cashflow unit is source `Profit + Swap + Commission`; no post-hoc swap adjustment belongs in this hypothesis.
Replications: exactly `5000` per arm per report. Deterministic random seed: exactly `20260912`, reinitialized identically for each arm/report.
Report the observed total, N, K, episode-size distribution, bootstrap median, 2.5th percentile, 97.5th percentile and central-95% interval width for each arm.
Percentiles use the implementation language's deterministic linear percentile interpolation and must be documented in the result artifact.

## Falsifier and limitations
The directional claim `TICKET_SAMPLING_UNDERSTATES_UNCERTAINTY` is supported only if episode-sampled central-95% width is strictly greater than ticket-sampled width in both MAIN and BWD within each tester model.
Any equal, narrower or mixed window/model outcome closes as `MIXED_OR_NOT_SUPPORTED`; no favorable model may be selected.
Invalid episode reconstruction, unsupported non-trading rows, source-hash mismatch, native-net mismatch or incomplete final-flat accounting is `BLOCKED_EVIDENCE`, not strategy failure.
The result is descriptive method sensitivity only: no p-value, effective sample floor, native EqDD reconstruction, margin/ruin probability, stateful price-path Monte Carlo or independence claim is allowed.

## Direct consumer / stop rule
Direct consumer: future B16 robustness-method design, specifically whether later simulation must preserve flat-to-flat episodes rather than shuffle tickets.
One four-report offline comparison only. Do not optimize block size, seed, replication count, percentile level or grouping after seeing results; do not change KINT/Grade, retune the EA, rerun MT5 or spend HOLDOUT.
