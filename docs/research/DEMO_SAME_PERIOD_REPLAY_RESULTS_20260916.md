# Demo Same-Period Replay Diagnostic Results - 2026-09-16

Status: `EXECUTION_COMPLETE_WITH_PRESERVED_BLOCKERS / DIAGNOSTIC_ONLY / EXACT_PARITY_NOT_CERTIFIABLE`.
Five priority cells executed; three pass the typed truncation gate; two remain `BLOCKED_TRUNCATION_UNRESOLVED`. This is not five accepted full-window comparisons or a full 22-EA parity certification.

Result base: `a9c54b8f4e2924a4329ea502ba34ffb5ee435c53`.
Exact execution head: `8059b227b318d6997846e8d7866fea5e05d5282b`.
Contract: `docs/research/DEMO_SAME_PERIOD_REPLAY_CONTRACT_20260915.md`.
Direct consumer: owner-facing 22-EA Demo assessment; no Candidate/Grade/KINT/DEMO-to-LIVE consumer.

## Evidence chain and bounded repair 1/1
The five existing reports record `D:\Meta 5` / MT5-lane1, Model1 / 1 Minute OHLC, USD 10,000, leverage 1:100, Optimization=0 and Forward=0. No tester run was repeated for this repair.

The preserved historical `ALIAS_PREFLIGHT.json` records five unique aliases, equal source/destination EX5 SHA256 values, and zero pre-existing alias-cache matches. Its exact bytes are now included and hash-bound in `factory/runs/demo_sameperiod_replay_20260916/evidence/` and `source_manifest.json`.

Historical per-cell postcheck outcomes were observed in the execution conversation but are **NOT_DURABLY_PRESERVED** as replayable receipts. The package does not certify historical post-run process counts or per-cell post-run EX5/set equality. No new observation is substituted for the missing historical checks, and no postcheck outcome is reconstructed.

C01/C02/C05 retain typed `CHECK_PASS / truncated=false`. C03/C04 retain `UNKNOWN / truncated=null` and are **BLOCKED_TRUNCATION_UNRESOLVED**. Quiet-tail prose is a checker heuristic, not independent proof that the whole requested window executed or that no cage stopped the EA. Their numeric results remain descriptive and ineligible for full-window conclusions.

Original independent review and Control Tower intake findings are preserved verbatim under `evidence/`. This single repair binds available evidence and corrects unsupported claims; it does not change metrics, raw reports, sidecars, EX5s, sets, or research authority.

## Demo-source reconciliation
The originally pinned whole-file SHA256 `5C92F6D2...C6265EBF` has no preserved original bytes. A later observed exporter had SHA256 `13744ECC...92B3D7`. Append-only evolution is **not proven**.

The preserved 120-row, five-magic subset through `2026.09.14 23:59:59` has SHA256 `26C3B30C...D40046CD`. Its count/net/PF recomputations agree with the earlier recorded aggregate tuples, but no original ticket-row comparison was possible. This is **AGGREGATE_RECONCILED_ONLY / ORIGINAL_ROW_IDENTITY_UNPROVEN**, not historical row-level reconciliation.

Tester date labels end at `2026.09.14`; the Demo subset includes that date through 23:59:59. Equal UTC boundaries, live attachment start, and complete effective configuration are unverified. These are same-requested-calendar-period diagnostics, not certified exact-instant comparisons.

## Observed values (USD; no strategy grade)
| Cell / magic | Demo observed exits / net / PF | Replay trades / net / PF | Replay native EqDD | Eligibility |
|---|---|---|---|---|
| C01 / `999094` MacdDiv XAU H4 | 25 / -467.37 / 0.260 | 19 / -87.77 / 0.80 | 3.77% | Typed truncation CHECK_PASS; limited diagnostic only |
| C02 / `990068` Ichi XAU H1 | 6 / +686.01 / 1.761 | 7 / +457.88 / 1.41 | 14.84% | Typed truncation CHECK_PASS; limited diagnostic only |
| C03 / `990069` Ichi XAU H4 | 3 / -1,643.56 / 0.00 | 1 / -621.70 / 0.00 | 7.47% | BLOCKED_TRUNCATION_UNRESOLVED; descriptive only |
| C04 / `990016` Boss16 XAU H1 | 12 / +117.56 / 2.935 | 10 / -318.44 / 0.26 | 5.92% | BLOCKED_TRUNCATION_UNRESOLVED; descriptive only |
| C05 / `990301` Wave5 XAU H1 | 14 / -9.57 / 0.729 | 15 / -171.00 / 0.49 | 2.65% | Typed truncation CHECK_PASS; limited diagnostic only |

Net includes observed profit, swap and commission. Demo PF uses net closed-deal amounts; MT5 counts are deals/exits, not certified independent grid baskets. Replay EqDD is the native report percentage, not Demo equity drawdown. Demo native intratrade equity/exposure and original effective-input state are unavailable in this package.

## Exploratory timing alignment, not clock qualification
The preserved parser searches all 25 whole-hour shifts from -12h to +12h **after outcomes are known**. For each cell it maximizes one-to-one same-direction entry matches within 20 minutes, breaking ties by total timing error. It selects -4h / 10 of 19 for C01; -3h / 6 of 7 for C02; -8h / 1 of 1 for sparse C03; -3h / 5 of 10 for C04; -3h / 14 of 15 for C05.

These optimized descriptive counts do not independently establish broker-clock mapping, signal parity, equal observation windows, or predictive validity. C03's single best-aligned match is particularly uninformative. The JSON/CSV carry `EXPLORATORY_POST_OUTCOME_ALIGNMENT`; none of these offsets is a qualified clock model.

## Ichi XAU combined arithmetic
H1 + H4 observed Demo = 9 exits / -957.55 / PF 0.623766.
H1 + H4 replay = 8 trades / -163.82 / PF 0.905120.
PF uses combined gross profits divided by combined gross losses, not the average of component PFs.

The combined replay contains blocked C03 and is **DESCRIPTIVE_AGGREGATE_ONLY_CONTAINS_BLOCKED_C03**. Its negative total is arithmetic over the available reports, not an eligible full-window basket comparison. H1's positive result alone also does not certify the combined deployed basket.

## Interpretation and decision boundary
MacdDiv and Wave5 show negative observed net in both ledgers; Ichi H1 is positive in both. None establishes exact parity or a causal explanation for the differences. Boss16's available report has the opposite net sign to Demo, but unresolved coverage means this is an investigation flag, not proof of a full-window strategy/configuration failure. Ichi H4 is also descriptive only.

All five cells retain `LEGACY_IDENTITY_CONFUND / FULL_CONFIG_PARITY_NOT_CERTIFIABLE`: legacy EX5s have no stamped build receipt and sets are UNDECLARED. ThinkMarkets-Live Build 6182 versus Exness Demo adds `BROKER_ENVIRONMENT_CONFUND`. Historic postchecks, original Demo row identity and common UTC boundaries remain unresolved. No causal broker/config attribution is established.

The bounded run count is exhausted. Publishing this evidence package closes only documentation/limited diagnostic reporting, not the unresolved acceptance gaps. No new MT5, retune, optimization, BWD search, HOLDOUT, Model4, Candidate, Grade/KINT, baseline repin, risk/default, runtime, deployment or trading authority follows. Any future environment-fidelity investigation needs its own prospective contract and independently qualified inputs; do not repeat these cells to seek a better result.
