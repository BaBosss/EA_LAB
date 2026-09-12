# B16 R4 episode-unit sampling sensitivity results

Status: `EXECUTED / RESEARCH_ONLY / ZERO_NEW_MT5 / AUTHOR_RESULT`

Classification: `TICKET_SAMPLING_UNDERSTATES_UNCERTAINTY`.
Episode-sampled central-95% interval width is strictly greater than ticket-sampled
width in MAIN and BWD within both tester models. This satisfies the frozen
directional falsifier across all four separate reports. Integration/review is
separate from this bounded author result; no push is authorized by this task.

## Identity and frozen question

- Hypothesis: `HYP-Q09R2-B16-EPISODEUNIT-01`.
- Author base HEAD: `e3254868d482096a009e38c81c80ebae96a64207`.
- Author branch: `codex/b16-episodeunit-20260912`; device: `BaBoss`.
- Preregistration: [frozen contract](B16_USDJPY_H1_R4_EPISODEUNIT_PREREG_20260912.md),
  SHA256 `c6c8ea5afbdb7e6aeac967ac289153d3900691987e2bc53c10f79569307eba70`.
- Parent: Boss16 KangarooGrid, `B16-R4-r1`, USDJPY/H1 BUY, RSI 14/30.
- Accepted runtime HEAD: `dcb5dd1dfd9b3df68a270985272b13fc5fee0890`.
- All source numbers: `MT5-lane1`, installation `D:\Meta 5`.
- MAIN: 2023-01-01..2025-12-31; BWD: 2020-01-01..2022-12-31.
- Source models: `M1_M1_OHLC_RESEARCH` and `M4_REAL_TICK_FIDELITY`.
- Set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`.
- EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.
- Build receipt: `br-4fa94d22907b446ebc721d524bdfa5d1`.
- HOLDOUT: `UNSPENT`; new Model1/Model4 cells: `0/0`; optimization: `NOT RUN`.

The sole experimental change is the sampling unit: realized exit-deal ticket
cashflow versus the whole complete flat-to-flat episode cashflow. Entry, grid,
lot/exposure, exits, risk, prices, costs, model and windows remain those of the
[accepted R4 result](B16_USDJPY_H1_R4_EXECUTION_FIDELITY_RESULTS.md).
This offline method diagnostic adds no strategy-mechanic, year/regime, exposure,
or native drawdown measurements; their accepted evidence remains with R4.

## Evidence and method

Machine-readable output:
[result.json](../../factory/runs/b16_r4_offline_20260912/episodeunit/result.json),
SHA256 `819e45aa266ea77691332aeb82470e3cd379c17be26d2b1982cf46dac585f271`.
Decimal values are JSON strings, preserving exact source arithmetic and quantiles.

Every report is independently SHA256 checked before inference. The parser,
preregistration, accepted summary, integrity record and receipts also have fixed
hash checks. Full relative paths and expected/observed hashes are in the output.

| Cell | Canonical source report SHA256 |
|---|---|
| M1_MAIN | `a329cc1fed28a98926ef38a07c05750c31d1f47dfd568dd31ac95d38fae64aa0` |
| M1_BWD | `327e6c9be6ea8569275c7c9a066043ce22e6e6ce1e9590b5cb4b3714cc98bc2a` |
| M4_MAIN | `03c00a3fe1c61b43aa6d613418dd0973908c83a628ca0c101902fcf2d9984117` |
| M4_BWD | `7561815ec2fa094176fa1b324a723c96a16dac8f22e74e2411d1503ab0ba85ed` |

Reports reside at `factory/runs/b16_r4_20260902/usdjpy_buy_h1/runtime/<CELL>/report.htm`.
Supporting identities:

- `evidence_integrity.json`: `9fc2c651ddb34689a6ffccfb8f904ec6aec57f7b373f555b08687faa764354d4`.
- `evidence_summary.json`: `e260a42c959cd637f8556ab4e873953defaf55d381931316238bbd08e0e23faa`.
- `run_receipts.jsonl`: `f6add2ccb287949d7640d90960014e07370f8990783fd2d8b542cbbdffcbfdce`.
- Reference `scripts/research/b16_h03/parse_h02_reports.py`:
  `c2aa0995705ed63a9c2ae1b0bbb982f2375bd2da3ae9c8bff35e2ad01a005b5e`.

Reconstruction uses the accepted parser's FIFO inventory transitions with exact
decimal volumes. A ticket means one realized `out` deal, including a partial
close. An episode begins when flat inventory becomes nonflat and ends only when
inventory returns exactly to zero. Episode size below counts exit deals, not
peak positions or grid levels. Tests compare every episode's complete deal-ID
membership, exit count and cashflow with the accepted parser on all four reports.

All four ledgers reconcile exactly:
`sum(Profit + Swap + Commission) = ticket sum = episode sum = native Total Net Profit
= final balance - initial deposit`. Component/footer totals, every running
balance, gross P/L, deal/trade counts, and accepted N/K/net also agree. The only
supported non-trading rows are the single initial deposit and exact totals footer
(plus its empty trailing row). Entry cashflow must be zero in each component.
Unknown rows, open-final inventory, over-closes, noncanonical ordering, altered
hashes and accounting mismatches refuse as `BLOCKED_EVIDENCE` before any sampling.

Each arm/report uses exactly **5000 replications**. Ticket replications draw N
tickets; episode replications draw K complete episodes, with replacement.
Every draw hashes UTF-8 `20260912|<CELL>|<ARM>|<replication>|<draw>` with SHA256,
using zero-based counters and ARM `TICKET` or `EPISODE`. The first eight digest
bytes form an unsigned big-endian integer; its remainder modulo unit count is
the index. There is no library RNG. No reports are pooled.

Sorted 5000 sums use exact decimal `h=4999*p`, `j=floor(h)`, `g=h-j`,
`q=x[j]+g*(x[j+1]-x[j])`, for p=`0.025`, `0.5`, `0.975`.
Width is `q975-q025`. No grouping, seed, count or percentile was selected after
seeing results.

## Measured results

All cashflow amounts and widths below are USD, from `MT5-lane1 / D:\Meta 5`.

| Cell | Observed total | N tickets | K episodes | Episode size: number of episodes |
|---|---:|---:|---:|---|
| M1_MAIN | 255.30 | 275 | 239 | 1:227, 2:6, 3:3, 5:1, 11:2 |
| M1_BWD | 50.22 | 267 | 243 | 1:234, 2:5, 3:2, 5:1, 12:1 |
| M4_MAIN | 187.32 | 273 | 238 | 1:226, 2:6, 3:3, 5:1, 10:1, 11:1 |
| M4_BWD | 74.73 | 262 | 236 | 1:227, 2:5, 3:2, 6:1, 13:1 |

| Cell | Arm | Median | q025 | q975 | Central-95% width |
|---|---|---:|---:|---:|---:|
| M1_MAIN | TICKET | 260.430 | -91.06825 | 566.03975 | 657.10800 |
| M1_MAIN | EPISODE | 270.775 | -187.13175 | 629.40375 | 816.53550 |
| M1_BWD | TICKET | 59.390 | -232.06825 | 316.61075 | 548.67900 |
| M1_BWD | EPISODE | 67.395 | -393.11600 | 383.17425 | 776.29025 |
| M4_MAIN | TICKET | 191.100 | -157.08750 | 503.61550 | 660.70300 |
| M4_MAIN | EPISODE | 202.230 | -275.45150 | 574.38050 | 849.83200 |
| M4_BWD | TICKET | 78.130 | -201.87350 | 326.76500 | 528.63850 |
| M4_BWD | EPISODE | 83.470 | -259.04200 | 368.60675 | 627.64875 |

## Interpretation and bounded conclusion

The measured episode width exceeds the ticket width in all four cells, so the
literal preregistered classification is
`TICKET_SAMPLING_UNDERSTATES_UNCERTAINTY`. The alternate
`MIXED_OR_NOT_SUPPORTED` would apply if even one cell were equal or narrower;
tests cover every model/window veto. No favorable model or window was selected.

Lesson: for these frozen reports, preserving realized episode membership widens
the sampled total-net interval. Direct consumer: future B16 robustness-method
design can use this evidence when specifying whether to preserve complete
episodes. No further experiment is opened by this result.

This is descriptive method sensitivity only. It makes no p-value or independence
claim, sets no effective sample floor, reconstructs no native EqDD, estimates no
margin/ruin probability, and performs no stateful price-path Monte Carlo.
It grants no KINT/Grade/Candidate, strategy-verdict, risk/default, runtime,
deployment, trading, or HOLDOUT authority. Episode cashflow sampling does not
establish independence between episodes or model future execution paths.

## Validation and reproduction

- Focused unit suite: **26/26 PASS**. Covers SHA256 known vector/determinism,
  unsigned big-endian/modulo indexing, frozen draw counts, exact quantile
  boundaries/interpolation, both resampling arms, partial-close/multi-exit
  grouping, open-final/unsupported/hash/reconciliation refusals, all four
  accepted-parser comparisons, falsifier vetoes and deterministic output.
- Initial run: **25/26 PASS**; one test constructed fixture balance strings under
  artificially reduced Decimal precision. The single bounded repair moved
  fixture construction before that context change. No analyzer or frozen design
  change was needed. Repair allowance is exhausted.
- Real four-report analysis: PASS; second complete run produced byte-identical
  JSON (SHA256 above). Each run used 5000 replications per arm/report.
- Both Python sources: `py_compile` PASS; compiled artifacts used a temporary
  directory outside the repository. Imports ran with bytecode writing disabled.
- `scripts/check_state.ps1 -Strict`: CLEAN, exit 0.
- Normal staged diff/commit hooks remain required on the actual commit path;
  **BLOCKED: staging could not create
  `D:/EA_LAB/.git/worktrees/b16-episodeunit-20260912/index.lock` (Permission denied)**.
  Linked-worktree Git metadata is outside the writable sandbox and this session
  has no escalation permission. No staged-snapshot/commit-hook PASS is claimed;
  no commit was created, HEAD remains the author base, and nothing was pushed.
  `SAFE_TO_INTEGRATE=NO` until normal staging/hooks/commit and required intake
  review complete in an authorized environment. This environment blocker does
  not change the evidence classification.
- Existing `analyze_r4.py` was not run. Source evidence and preregistration were
  read only. No state/taskboard, EA/core/runtime, registry or config edits.

From the pinned worktree, in PowerShell:

```powershell
. scripts/use_python.ps1
$env:PYTHONDONTWRITEBYTECODE = '1'
python -B scripts/research/b16_r4_offline/test_analyze_episode_unit.py
python -B scripts/research/b16_r4_offline/analyze_episode_unit.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check_state.ps1 -Strict
git diff --check
```

The analyzer writes only JSON to stdout and returns exit 2 on blocked evidence.
The author captured the successful output into the contract's result path.
