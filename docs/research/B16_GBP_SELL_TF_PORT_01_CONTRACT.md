# B16 GBPUSD SELL Timeframe Portability — Step 5 Contract

Status: `PREREGISTRATION / RESEARCH_ONLY / NO OPTIMIZATION`
Hypothesis ID: `HYP-B16-GBP-SELL-TFPORT-01`
Conveyor stage: `5 — LEAD CONFIRMATION / PORTABILITY`
Base SHA: `b27b6bbdbef76a3076ba5058a8c43f4f1627f2af`
Runtime: `MT5-lane2` / `D:\Meta 5b` / serial Model-1 only.

## Direct consumer

Determine whether the reviewed GBPUSD/H4 SELL direction asymmetry is H4-local or repeats on adjacent GBPUSD H1/M15 before any Step-6 optimization-range contract is considered.

Accepted evidence is reused, not rediscovered: B16 mechanism characterization is canonical/reviewed; exact H4 SELL child is positive MAIN+BWD and positive in every calendar year 2020–2025. Full evidence owner: `docs/research/B16_MECHANISM_CHARACTERIZATION_REPORT_20260830.md`.

## Frozen child

Use the tracked `SELL_DIRECTION` child byte-for-byte. The sole parent→child logical change remains `_16_Direction=1 -> 2`; this Step-5 experiment makes **no additional parameter change**.

Exact set: `factory/runs/b16_step5_20260830/gbp_sell_tfport01/B16_GBP_SELL_TFPORT_01.set`
SHA256: `c0e7cfad84236b798dece5b5106d271c708553fb220af370dba913d8610105de`
Surface: FULL 173/173 inputs.

Build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`; EX5 SHA256 `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
Source bytes from accepted build ref `cf32ba8d32a8292e8f7b5ad2ef766e3442b20125` to this base show no relevant B16/core change.
## Frozen evidence matrix

Exactly four new cells:
- GBPUSD H1 MAIN `2023.01.01..2025.12.31`;
- GBPUSD H1 BWD `2020.01.01..2022.12.31`;
- GBPUSD M15 MAIN `2023.01.01..2025.12.31`;
- GBPUSD M15 BWD `2020.01.01..2022.12.31`.

All cells: Model `1`, Optimization `0`, Forward `0`, deposit `USD 10,000`, leverage `1:100`, exact symbol `GBPUSD`, exact same Meta5b install lineage. HOLDOUT `2026H1` is forbidden and remains UNSPENT.

## Prospective hypothesis and classification

Primary statement: the exact frozen GBPUSD SELL child retains aggregate positive full-window net in MAIN and BWD on at least one adjacent timeframe, showing that the H4 finding is not strictly H4-local.

After mechanical acceptance classify without changing the rule:
- `PORTABLE_MULTI_TF`: both H1 and M15 have net > 0 in both MAIN and BWD;
- `PORTABLE_ONE_ADJACENT_TF`: exactly one of H1/M15 has net > 0 in both MAIN and BWD;
- `H4_LOCAL`: neither adjacent timeframe has net > 0 in both windows;
- `UNKNOWN_MECHANICAL`: an ineligible/mechanical cell prevents the required comparison.

Primary hypothesis is falsified only by `H4_LOCAL`. `UNKNOWN_MECHANICAL` is not strategy evidence.

Year splits, cycle/exposure, DD, participation and concentration are mandatory secondary evidence and may limit interpretation even when aggregate portability is observed; they do not change the preregistered primary classification after results are visible.
## Mechanical acceptance

Each cell must have: tester exit `0`; fresh report generated after run start; exact symbol/TF/date/model; exact set hash; accepted receipt/EX5 identity; leverage sidecar `1:100 MATCH`; no unresolved truncation; and direct tester-log inspection for any hard-cage event when eligibility is suspect.

A mechanically accepted loss is preserved as strategy evidence and is never replayed because it lost. One bounded harness repair is allowed only if no valid MT5 strategy evidence was produced.

## Budget / loop breaker

Four new cells only. No new symbol, timeframe, parameter, range or optimizer run may be added inside this contract. Same unresolved mechanical question twice => `UNKNOWN_MECHANICAL / BLOCKED`. Stop expansion after the four-cell result package.

## Authority ceiling

This contract grants no Step-6 range semantics, optimizer authority, H04, HOLDOUT, Candidate, DEMO/LIVE, deployment/runtime attachment, trading, risk/default change, KINT resolution or Grade mapping. A positive portability result only supplies evidence to decide whether a **separate prospective Step-6 Optimization Contract** has a direct consumer.
