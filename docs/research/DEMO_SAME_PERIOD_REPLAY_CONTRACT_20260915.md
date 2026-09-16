# Demo Same-Period Replay Diagnostic Contract — 2026-09-15

Status: `PROSPECTIVE / DIAGNOSTIC_ONLY / MODEL1 / NO_TUNING / NO_PROMOTION_AUTHORITY`

Canonical base: `97dd65c8a2518124e883584edda95dc672d55ea6`.
Owner request: continue the 22-EA Demo assessment and check same-period Backtest behavior.
Direct consumer: owner-facing 22-EA Demo report; no Candidate/Grade/KINT/DEMO->LIVE consumer.

## Question
For the highest-impact currently observed Demo rows, does a same-period frozen-bundle backtest show broadly compatible signal/economic behavior, or is the observed Demo path materially divergent?
This is an outcome-known diagnostic replay. It is not a fresh strategy selection experiment and may not be used to retune, optimize, reopen BWD search, spend HOLDOUT, or promote an EA.

## Fixed execution method
- Host/device: `BaBoss` / `bbb88aa0-1598-43f6-b56c-a7db22af086a`.
- Tester installation: `D:\Meta 5` only.
- Tester model: `Model=1` / 1 Minute OHLC research minimum.
- Deposit: USD 10,000; leverage 1:100; Optimization=0; ForwardMode=0.
- Each cell uses the exact expected Demo bundle `.ex5` bytes and tracked `.set` bytes frozen below; no source compile and no parameter edit.
- Copy bundle binaries into an order-owned `MQL5\Experts\EA_LAB_TEST\ORDER-DEMO-SAMEPERIOD-20260915\` tree byte-identically and verify SHA256 before launch.
- Record actual tester broker/account/server/build from the report/runtime. Broker mismatch is evidence, not something to repair by changing terminal login.
- Do not use `-Force`; one tester job at a time; inspect exit code, report freshness, truncation evidence and post-run process state before the next cell.

## Frozen cells

| Cell | Demo magic / EA | Symbol / TF | Same-period window | Bundle EX5 SHA256 | Set SHA256 |
|---|---|---|---|---|---|
| DSPR-C01 | `999094` MacdDiv_Naked | XAUUSD / H4 | 2026-07-16..2026-09-14 | `56D2FCF6F74B7E8909AFB4C7CA24B41A0A5B120D3097C445ADB4C104303C9C93` | `622E5EDC812B49D98F7241E4FCDE5BFF6826AFCAE4D158BDEA44C838F4338AF7` |
| DSPR-C02 | `990068` IchiADX XAU slow | XAUUSD / H1 | 2026-07-16..2026-09-14 | `299E24DF5BABE9EB85AB25BAACF5633E6608D133F546176A8C3CD5940D8E8CF4` | `523DBD9A2E244377590921DE5461DE30724164CCF30D786CF4FA5040038232C0` |
| DSPR-C03 | `990069` IchiADX XAU med | XAUUSD / H4 | 2026-07-16..2026-09-14 | `299E24DF5BABE9EB85AB25BAACF5633E6608D133F546176A8C3CD5940D8E8CF4` | `901BF276F8F37965F68D5F5E9717C8EC5C9FC9DDA91223C0C79775B5A3D262F3` |
| DSPR-C04 | `990016` Boss_16_KangarooGrid | XAUUSD / H1 | 2026-07-28..2026-09-14 | `B5001606FCBB30FF419A45DB7F9D477185E22DCDB5B6B1B7DCDAEB7CC0127CFC` | `37C6DA42C674C15CD17AA73633E332D1E115B7452524FA04EA6910C97F0C4F6B` |
| DSPR-C05 | `990301` Boss_17_Wave5 | XAUUSD / H1 | 2026-07-16..2026-09-14 | `653482D450D8BA29EE4D57BBBFC7B747C64A16B5BCFA08C164187CAB9121BA3C` | `D57D0AC5FAE5D81E039B698FD61E88449B0F95B953C85CF5D08F3B603447701A` |

Binary hashes are observational pins from the existing local `_vps_deploy` bundle bytes named by canonical `portfolio/ATTESTATION_MAP.csv`; the set hashes are from the exact canonical worktree at the pinned base. Boss16's binary hash is additionally recorded in canonical deployment notes.

## Demo comparison source
MT5 direct export: `EA_LAB_deals_463666728.csv`, observed SHA256 `5C92F6D29F3B77EE1629192D49E8F60ADA936724C30F051E7B95BD66C6265EBF`, with deal timestamps through 2026-09-14 18:59:31.
Current snapshot: `EA_LAB_snapshot_463666728.csv`, observed SHA256 `30723CBEBF3BB964536ECAF4ACBC36306CAD1EE3C8DFB4987EF1B169630EF977`, server time 2026-09-15 04:07:33.

## Required output per cell
- Fresh report for the exact requested window, with no stale-report reuse and no truncation ambiguity.
- Report/tester identity: expert, set, symbol, TF, model, dates, deposit, leverage, broker/account/server/build.
- PF, net, total trades/deals, native EqDD, and closed trade timestamps/directions where extractable.
- Demo side: observed closed count, net, PF, timing/direction sequence and any current floating exposure kept separate.
- Comparison must state concrete count/sign/timing/economic differences; do not manufacture a single numeric parity score.

## Interpretation ceiling
If tester broker/server or symbol economics differ from the Exness Demo environment, classification is `BROKER_ENVIRONMENT_CONFUND / EXACT_PARITY_NOT_CERTIFIABLE` even when trade patterns look similar.
A Model1 replay may establish diagnostic signal-path convergence or divergence only. It cannot establish exact tick/fill parity.
Zero/zero is insufficient proof of parity. Missing history, stale binary/config identity, truncated reports or mechanical failures remain `UNKNOWN/BLOCKED`, not strategy failure.

## Loop breaker and hard stops
Exactly five cells; no parameter/range changes and no replacement set selection after outcomes are visible.
One bounded mechanical/harness repair maximum; the same unresolved mechanical question twice => stop affected cell `BLOCKED`.
No Model2 performance claim; no Model4 in this contract; no optimization; no BWD search; no HOLDOUT use; no Candidate/Grade/KINT; no risk/default change; no runtime attach/detach/reattach; no trading/LIVE action.
Do not change terminal login/server merely to chase broker parity. A broker-environment mismatch is a report limitation and may motivate a later separately approved environment-fidelity contract.

## Acceptance
The milestone closes when all five cells are either mechanically complete or explicitly blocked with preserved evidence, Demo-vs-replay comparison is source-bound, and the owner-facing report is updated without overstating parity or strategy verdict.

## Prospective pre-run amendment 1 — legacy bundle identity
This amendment was frozen before any `DSPR-*` tester outcome was observed. Preflight found that none of the four exact Demo EX5 hashes is present in the current stamped `portfolio/build_receipts.jsonl` registry, and all five frozen deployment sets are `UNDECLARED` under the modern set-surface parser. Assignment counts are 13 (MacdDiv), 14/14 (Ichi H1/H4), 42 (Boss16), and 9 (Wave5); these counts do not prove a complete effective input surface.

These are legacy-deployment identity limitations, not strategy failures. The frozen binary/set hashes and test windows above are unchanged. No replacement set, rebuild, source compile, parameter completion, or post-outcome repair is authorized.

For this diagnostic only, the runner may use the existing explicit `-AllowLegacyIdentity` path, but every resulting cell is non-green identity evidence and MUST carry `LEGACY_IDENTITY_CONFUND / FULL_CONFIG_PARITY_NOT_CERTIFIABLE`. This allowance cannot support Candidate, promotion, strategy PASS, baseline repin, or any later acceptance-grade performance claim.
Isolation control: copy each exact EX5 to a unique order-owned expert alias under `MQL5\Experts\EA_LAB_TEST\ORDER-DEMO-SAMEPERIOD-20260915\`; before launch, prove the alias has no pre-existing tester-profile cache and verify copied EX5/set SHA256 against the frozen hashes. A unique alias is used only to prevent prior tester-cache inputs from contaminating this run; it does not prove that every unlisted live-chart input was at compiled default on the Demo terminal.

If a unique cache-free alias cannot be established, hash equality fails, or the modern runner refuses for a reason beyond the explicitly accepted legacy receipt/surface condition, stop that cell `BLOCKED_IDENTITY_OR_HARNESS`; do not weaken another gate. Preserve the runner's `LEGACY_ALLOWED` line and all hash/cache preflight evidence in the result package.

The existing broker rule remains higher-level and cumulative: a cell may simultaneously be `LEGACY_IDENTITY_CONFUND` and `BROKER_ENVIRONMENT_CONFUND`. Exact parity is therefore not certifiable under this amendment; the direct consumer is only gross signal/economic divergence diagnosis from the same date window.