# News/Macro country and currency context V1

Status: **SOURCE/OFFLINE_TYPED_INVENTORY / PARTIAL / SYNTHETIC/FIXTURE_ONLY**.
US/USD and Japan/JPY have typed slots and explicit UNKNOWN coverage. This is not
qualified populated country intelligence or a world-ready source package.

Owner: existing `EA_LAB-NEWS-MACRO-20260921`, under DOT sole MainCT. The supplied
ownerlongrun authority locator is directive `5e8a2c9823ec819188fa5c28aca1d4ce` and
latest `0c11af...` continuation. The truncated latest locator is not an independently
verified immutable receipt. Author base was freshly fetched and ls-remote verified:
`872524af2444e27a343bce76afbf81770147290b`.

The admitted author lane is `ct-news-macro-context-v1-20261005`, branch
`ct/news-macro-context-v1-20261005`, isolated worktree
`D:\EA_LAB_CONTROL\w\news-macro-context-v1-1005`. Owner-side execution verified
`BABOSS\patip` on `BaBoss`; the device ID supplied by DOT is
`bbb88aa0-1598-43f6-b56c-a7db22af086a` (not independently attested by the shell).
Windows PowerShell 5.1 admitted the lane after unchanged Registry validation.
PowerShell 7.6.5 first refused serialization with
`LANE_REGISTRY[preservation_failed] record JSON cannot round-trip losslessly`;
that attempt wrote no lane record. No Registry tooling or trust configuration changed.
The Registry precheck found no conflicts; active WIP was 2 before B, 3 after B.

## Frozen contract

Before implementation, the author froze `FROZEN_CONTRACT.json` (SHA256
`6f1c45f5d6d0b3d61dbeb7abb650191de6c94b6840b0ad567368a3241ad9e15b`) and
`FROZEN_12_FIXTURES.json` (SHA256
`81c7ef33341cba85829e4ddf7a007738c89c08524930c2face5e19cc860e347b`).
Both are under `factory/runs/news_macro_context_v1_20261004/` and are preserved.

Allowlist: `tools/knowledge_validation/news_macro_context.py`, its adjacent
`test_news_macro_context.py`, this document, and the above run directory only.
Budgets: author 1 / 90 minutes / one candidate; repair 1 / 30 minutes;
independent review 1 / 30 minutes; conditional targeted recheck 1 / 20 minutes.
External feed fetch, native, runtime, Monitor and shared core budgets are zero.
Git refresh is admission evidence and consumed no feed-fetch budget.
A's `e19bc5d...` frozen blocked ledger and its spent review/repair budgets remain separate.
No shared runner/capture repair, author push, reviewer launch or E-path edit belongs to B.

## Typed axes and source ceilings

Each country/currency/factor tuple has separate identity, source, source qualification,
revision and vintage, observed period, release clock, `available_at_utc`, fetch time,
freshness basis/state, coverage, reason codes and missing inputs. UNKNOWN values are
`null`; they never become zero or NEUTRAL. Inventory axes are employment, inflation,
policy rate and ten-year yield. The axis names create no qualified feed or factor value.

US employment has a **locator** to the prior PAYEMS selector receipt. The current
selector SHA256 is `f0c502b437b77c381e76f8c0c0c6e933b488234250b7482b6b3db60badce62bb`;
the receipt SHA256 is `84dff5e92025c5ffb491c7d7507e96b60bfe3ce6db820b25e0519a20c06ca455`.
Its external raw ZIP is not vendored. B neither reconstructs a raw historical package
from the receipt nor claims historical dataset/EA replay qualification.
Japan's factor/source package is UNQUALIFIED for every slot. Supplying Japan values
to the fixture selector is refused. No BOJ, Japan yield, inflation or policy-rate data
is fabricated. The remaining US factor packages are also UNKNOWN.

The unchanged canonical `qualify_replay_package` selects revisions. B validates
additional typed fixture metadata before calling it; it preserves the canonical
future exclusion, cancellation, tentative, coverage and conflicting-revision semantics.
B enforces that `coverage.state` and all record `state` values (including future records)
are scalar strings before selector delegation; invalid types retain full UNKNOWN refusal.
B selects only synthetic US employment fixtures, labeled `FIXTURE_SELECTED`;
real-source selection is refused even if an input claims complete metadata.
No prior real PAYEMS selection is reclassified as synthetic evidence.

Source release-clock evidence and versioned timezone conversion must precede availability.
A period, vintage date, fetched time or generated time is never substituted for
`available_at_utc`. Current-only inputs cannot replay history. Fixture freshness requires
an explicitly supplied positive integer age limit and `available_at_utc` basis; there is
no default. A stale or unknown freshness state withholds the value. These fixture limits
are not recommendations for a production factor or revisions to existing selector behavior.

## Symbols, global context and broker time

The frozen metadata table is an exact lookup. `USD` maps to US/USD, `JPY` to JP/JPY,
and `USDJPY` has base USD, quote JPY and explicit US/JP inventory links. There is no
suffix stripping, case conversion, reverse-pair inference or heuristic country mapping.
`XAUUSD` and `BTCUSD` describe metal/crypto bases quoted in USD, with no country link.
`EURGBP`, all other currencies and unlisted symbols are NOTSUPPORTED/UNKNOWN pending
a separately frozen extension.

Existing global MRIS remains owned by `portfolio/mris/regime_state.json`. B exposes
only that owner reference and its unchanged RISK_ON / NEUTRAL / RISK_OFF / STRESS
vocabulary; it does not compute or substitute a global regime. Existing
`US10Y_JP10Y` is a carry proxy using the US `^TNX` leg. It is not a qualified Japan
series, and B's Japan and US yield slots stay UNKNOWN. Historical prose about a
BOJ-pinned yield in the original MRIS source is not a newly qualified numerical input.

Optional explicit broker binding reuses the canonical P4B `server_to_utc` normalizer.
It requires accepted `ThinkMarkets-Live` lineage and mapping version, server dates
2019-03-01 through 2025-12-31, and exact agreement with decision UTC. Transition server
dates remain UNKNOWN. No 2026 extension exists. Absence of a broker binding is UNKNOWN,
and fixture UTC selection alone confers no broker/tester or historical EA replay qualification.
The existing historical macro-source and broker-clock contracts remain authoritative.

## Frozen validation and direct consumer

The twelve synthetic cases cover: available-at selection, future revisions, missing
source/clock/hash, conflicting revisions, unknown freshness, unknown coverage,
current-only refusal, Japan UNKNOWN preservation, explicit pair/asset mapping,
proxy/country separation, repeatable output/hash and clock/global/authority boundaries.
Bounded subcases cover exact availability/freshness boundaries, raw tampering,
missing vintage/period/availability, ambiguous simultaneous revisions, duplicates,
unsupported suffixes/currencies, non-US inputs, policy fields, cancellation and tentative
records, unqualified broker lineage, transition dates and the forbidden 2026 extension.
Every output retains PARTIAL and SYNTHETIC/FIXTURE_ONLY and all real qualification flags false.

Run from the isolated root after dot-sourcing `scripts/use_python.ps1` and
`Assert-PortablePython -Root <root>`:

```powershell
& $python tools/knowledge_validation/test_news_macro_context.py
& $python -m unittest discover -s tools/knowledge_validation/tests -p test_offline_replay_validator.py
& $python tools/knowledge_validation/news_macro_context.py --input <request.json> --raw-source <fixture-bytes.txt>
```

The CLI reads local input only and prints JSON. Exit 0 means a synthetic factor was
selected; 1 means every value remains UNKNOWN; 2 means unreadable/invalid input,
including non-scalar enum state types.
The proposed E interface is the `ea_lab_news_macro_context/1` output envelope, plus
exact source/candidate/evidence hashes. E must inspect individual typed states/reasons,
preserve UNKNOWN and PARTIAL, and retain B's qualification ceilings. No existing E
validator integration or automatic store write is claimed. Existing NewsMacro ownership
is the other direct consumer. There is no country score, factor weight, BUY/SELL output,
policy choice, source/default change, feed ingest, profitability claim or runtime activation.

After deterministic green, freeze one exact candidate and evidence for parent DOT's
qualified independent-review admission. The author cannot approve its own candidate.
Validation results and exact candidate identity are provided by the run evidence and
external freeze checkpoint; no accepted/source-canonical verdict is implied here.

Author CLI gate initially failed `CLI_IMPORT001`: the portable interpreter excludes
CWD from module search, so `-m tools.knowledge_validation.news_macro_context` could not
resolve `tools`. Repair 1/1 binds the standalone entry point to its own source root and
uses the explicit script path above. Failure evidence is preserved in `CLI_FAILURE.json`.
Shared interpreter, runner, hooks, trust and security settings were not changed. This
consumes B's repair budget; a further source gate or review finding must stop for DOT.
