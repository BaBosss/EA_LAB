# B16 USDJPY/H1 R4 Swap-Credit Accounting Dependence — Preregistration

Status: `PREREGISTERED / RESEARCH_ONLY / ZERO_NEW_MT5 / NOT_EXECUTED`
Hypothesis ID: `HYP-Q09R2-B16-SWAPCREDIT-01`
Preregistration base: `37b672736972b26d2bfc4b04b1052d9821e47db4`
Authority: offline accounting diagnostic only. No EA/core change, MT5 run, optimization, HOLDOUT, Candidate/Grade/KINT, risk/default, runtime, deployment or trading authority.

## Question and one logical change
Question: does the accepted B16 USDJPY/H1 BUY 14/30 R4 realized ledger remain positive after removing only positive swap credits?
The sole transformation is `adjusted_deal_net = reported_deal_net - max(reported_swap, 0)`.
Negative swap debits, commission, price profit, volume, timestamps, deal ordering and the realized trading path remain unchanged.
This is an accounting attribution on an immutable realized path, not a zero-swap runtime counterfactual and not evidence about another broker's swap schedule.

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
Existing parser reference: `scripts/research/b16_h03/parse_h02_reports.py`; do not execute `analyze_r4.py` because it writes accepted R4 evidence outputs.

## Required calculation and outputs
For each report independently, reconcile parsed closed-deal native net to the accepted report net before attribution.
Report: native net, signed swap total, positive-swap-credit total, negative-swap-debit total, adjusted full-window net, adjustment amount and sign.
Also report the same accounting attribution by calendar year and by the existing flat-to-flat episode reconstruction; preserve unchanged ticket/episode counts and holding/concentration descriptors.
Do not recalculate or relabel native EqDD from adjusted cashflows. Native EqDD remains source evidence and the adjusted series is not a reconstructed equity path.
No report, model or year may be selected or excluded after seeing the adjustment.

## Falsifier and disposition
The claim `CREDIT_INDEPENDENT_POSITIVE_NET` is falsified if adjusted full-window net is `<= 0` in any of the four frozen reports.
If all four adjusted full-window nets remain `> 0`, classify only `CREDIT_INDEPENDENT_POSITIVE_NET_NOT_FALSIFIED_ON_RECORDED_LEDGER`.
If every report has zero positive swap credits, close as `NO_CREDIT_DEPENDENCE_IN_RECORDED_LEDGER` because the transform is inert.
Any source-hash mismatch, native-net reconciliation failure, unsupported balance/non-trading row, malformed deal table or incomplete final accounting is `BLOCKED_EVIDENCE`, never strategy failure.

## Direct consumer / stop rule
Direct consumer: B16 robustness triage before spending tester or broker-portability effort.
One deterministic four-report offline pass only. Stop after the four frozen reports; no swap-grid search, changed broker economics, EA exit change, risk reset, retune, MT5 rerun or HOLDOUT use follows automatically.
