# Monitor source adapter MT4 order-history extension V1

Status: bounded Repair1/1 author WIP, pending Control Tower freeze and one targeted exact-head GPT Scrutiny
recheck. Repair1/1 is consumed and no second repair is permitted under this contract. This is not
self-approval or an acceptance record. The implementation was authored from exact base
`3d6941ab0f0edbacffbb60022cd84113d6a288b6` in lane
`ct-monitor-mt4-orders-adapter-v1-20260925`. Before freeze, Main CT fetched canonical
`f043a8a430d17288be80be5ff084730b89432f83`, verified zero overlap on the four scoped paths,
and fast-forwarded the lane worktree to that canonical parent while preserving the staged candidate.

The first acceptance-grade review inspected exact head `f51c931a358615d87bdbcde74dc9b5fe6f7c0066` and returned
`SCRUTINY_REPAIR_REQUIRED` on the sole material finding `MT4A-001`: lexically valid but impossible type
`0`/`1` lots, prices and time ordering could count as closed market-order observations. Review receipt:
`D:\EA_LAB_CONTROL\evidence\monitor-mt4-orders-adapter-v1-20260925\GPT_SCRUTINY_F51C_20260925.json`,
SHA-256 `1e01fa0e99e893d0d1c35d090afdbbab131cff6eb94f87a1565b2ba4b770db4b`.

## Boundary and producer contract

This extension adds the separate `mt4_orders` observation section to the accepted source-adapter package.
It does not add MT4 rows to the existing MT5 `ledger` section. An MT4 row is one whole closed order-history
record, not an MT5 deal event and not a reconstructed trade cycle.

The parser contract now pins `tools/DealsExporter/OrdersExporterMT4.mq4` at base Git blob
`22e508550e70250b78ff6f77bc3896da41def20d` and exact byte SHA-256
`4caee0ebe8440cb13c28c79354904d1cd992163f2864936b22ae68ca1e678593`. It participates in the existing
all-producer preflight: drift in this or any other pinned producer causes the whole builder to refuse with
`PARSER_CONTRACT_SOURCE_CHANGED` before observation sections are built.

Only `EA_LAB_mt4_orders_<login>[_<YYYYMMDD>].csv` files in the caller's explicit ledger root are considered.
The account and optional calendar date grammar are strict. Each filename must resolve to exactly one current
`ACCOUNTS.csv` row whose platform is `MT4`. The exact exporter columns are:

```text
ticket,open_time,close_time,symbol,magic,type,lots,open_price,close_price,profit,swap,commission,comment
```

Missing, unknown or duplicate columns are refused by the existing `Sources.csv` contract. Source discovery
is nonrecursive and retains the existing byte, row, file, directory, stable-read, traversal, hardlink and
reparse-point limits.

## Row and output semantics

- `ticket` is a positive integer identity scoped by account. `magic` and `type` are canonical signed producer
  integers; zero is allowed.
- Types `0` and `1` are closed market-order observations only when parsed `lots`, `open_price` and
  `close_price` are each strictly greater than zero and parsed `open_time` is less than or equal to parsed
  `close_time`. Failures use the fixed reason codes `MT4_MARKET_LOTS_NOT_POSITIVE`,
  `MT4_MARKET_OPEN_PRICE_NOT_POSITIVE`, `MT4_MARKET_CLOSE_PRICE_NOT_POSITIVE` and
  `MT4_MARKET_TIME_ORDER_INVALID`. Equality of open and close time is allowed. Every other syntactically
  valid integer type is counted only in `excluded_non_market_orders`; these market-domain positivity and
  time-order gates do not apply to non-market rows.
- `open_time` and required `close_time` are strict producer broker-time coordinates. Output retains
  `clock_basis=BROKER_TIME_UNQUALIFIED`; no broker-to-UTC conversion is inferred.
- Lots, prices, profit, swap and commission must be syntactically finite fixed-point values. Domain checks
  use the parsed `Decimal` values without float conversion, but no money aggregate or component is emitted.
  A market-order symbol must pass the existing safe-symbol grammar; non-market rows may have an empty
  symbol.
- Repeated daily exports are deduplicated by `(account,ticket)`. Every normalized producer field, including
  the nonprojected comment, must agree. A conflicting or keyed-invalid ticket is quarantined across all
  supplied files. A malformed file or unkeyed invalid row associated with a current MT4 account withholds
  that account's counts instead of falling back to an older valid file.
- A valid header-only export is an observation of zero rows in that export window. It is not lifetime proof.
  File mtime is used only by the stable-byte safety read and never as broker/event freshness.

Per-account output is restricted to an opaque account key, `platform=MT4`, `PARTIAL`/`UNAVAILABLE`, a fixed
reason code, file/source-reference counts, deduplicated closed/excluded counts (or null when withheld),
quarantine count and opaque order keys, broker-coordinate close-window endpoints, clock basis, and
`history_completeness=EXPORT_WINDOW_NOT_LIFETIME_PROOF`. Raw logins, tickets, comments and paths are not
projected. Top-level data uses `unit=MT4_CLOSED_ORDER_RECORDS_NOT_MT5_DEALS` and keeps
`account_totals_across_currencies=null`. The section reasons are always:

- `BROKER_TIME_UNQUALIFIED`
- `EXPORT_WINDOW_NOT_LIFETIME_PROOF`
- `MT4_CLOSED_ORDER_HISTORY_DISTINCT_FROM_MT5_DEALS`

Successful reads remain `PARTIAL`; this extension does not claim `REAL_DATA_QUALIFIED`.

## Deterministic validation

Portable Python was provisioned with `scripts/use_python.ps1`. Because the portable interpreter is isolated,
tests used a process-local repository-root `sys.path` insertion; no global `PYTHONPATH` was changed.

The MT4 coverage exercises the exact producer hash pin, valid market rows, non-market exclusion, identical
full-history deduplication, conflict quarantine, header-only zero, strict filename dates, missing/ambiguous or
non-MT4 metadata, missing/unknown/duplicate columns, malformed ticket/magic/type/times/numerics/symbol, newer
malformed-file withholding, absence of money aggregates and private source values, and the separate builder
section. Repair1 adds adversarial cases for type `0` zero lots, type `1` negative lots, type `0` zero open
price, type `1` negative open price, type `0` zero close price, type `1` negative close price, reversed market
times, accepted equal market times, valid/impossible repeated-ticket history in both discovery orders, and a
non-market row with valid zero/negative numerics and reversed times that remains excluded.

The targeted MT4 suite passed 18/18. The full adapter suite, including the unchanged existing MT5 ledger
behavior, completed 91 discovered tests: 90 passed and the one already-documented privilege-dependent native
symlink test was skipped on this Windows session. Both commands used the documented process-local
repository-root `sys.path` launcher.

Source `compileall` and `git diff --check` also passed. These are author gates, not an acceptance verdict.

## Read-only real-source smoke

The Repair1 author read, without running collectors or terminals, the explicit current root
`D:\EA_LAB_WORKSPACE\runtime\daily-monitor-aec3dd24-20260914\portfolio\live_deals` using the uncommitted
repaired worktree based on exact start head `f51c931a358615d87bdbcde74dc9b5fe6f7c0066`; the builder's pinned
producer/metadata Git source ref was that same start head, and the fixed observation time was
`2026-09-25T00:00:00Z`. The result contained exactly two current MT4 accounts and the new fail-visible
market-domain errors described below. Main CT must bind this smoke to the resulting frozen repair head/source
bytes before the targeted exact-head recheck:

| Opaque account key | Files | Raw-window result after full-history dedup | Excluded non-market | Quarantined | Close window, broker coordinate |
|---|---:|---:|---:|---:|---|
| `account-c1c5e3fec7fed93ed9dd210cca460d167c96b0c2bc04642c128729e10ad08181` | 41 | 661 closed market orders | 424 | 131 | `2026-07-01T08:37:57` to `2026-09-04T12:32:46` |
| `account-aae4c3308dd83486ba7fcaf3b6081a10a9a49da4dda66f676ffe273b76d9571d` | 28 | 230 closed market orders | 0 | 0 | `2026-07-09T13:51:32` to `2026-09-24T18:02:39` |

Across both accounts the reader parsed 11,240 raw repeated-history rows from 69 files. Both account and
section availability are `PARTIAL`; cross-currency totals are null and integration
`real_data_qualified=false`. The serialized bounded observation contained no raw current account ID, raw
ticket or private root path. No `comment` field exists in the projection, and the adversarial fixture proves
an arbitrary private comment is not emitted.

It quarantined 131 unique type `0`/`1` tickets for `MT4_MARKET_LOTS_NOT_POSITIVE`; repeated full-history
rows produced 1,405 fail-visible section errors for those unique identities. The second MT4 account and both
close-window endpoints were unchanged from the pre-repair smoke.

These are source-observation counts only. They are not performance, completeness, freshness, attachment,
guard, identity or portfolio-money evidence.

## Historical orphan diagnosis

Read-only diagnosis identified one historical account absent from current `ACCOUNTS.csv`, represented here
only as
`historical-account-294df450fbb187d783a16365adb86a6e8c273aa885464e745f3f48f3928f741c`.
Exactly three MT5 deal files belong to it, dated `20260706`, `20260709` and `20260710`. All three have the
same SHA-256, consist only of the exporter header and contain zero data rows.

Git history records the account as registered `UNVERIFIED` pending enumeration on 2026-07-18 at
`32b9fd20658d067c133c19a77a2b7f9cd0f0d799`, then removed as a dead row on 2026-07-24 at
`1e3df05f74bcd10b5ce7065be53688a5b138f773`. The current inventory and those zero-row historical artifacts
therefore do not justify restoring an `ACCOUNTS.csv` row. The three existing MT5
`ACCOUNT_METADATA_MISSING_OR_AMBIGUOUS` findings remain intentionally fail-visible; this extension does not
weaken or rewrite MT5 ledger semantics to clear them.

## Authority and remaining limits

This package does not modify or run an exporter, collector, terminal, scheduler, runtime, deployment,
Registry, account inventory, owner web app or trading path. It does not establish runtime attachment,
identity, guard effectiveness, source lifetime completeness, UTC time, event freshness, P/L, PF, win rate,
drawdown, portfolio money or a trade-cycle interpretation. There is no runtime/trading, DEMO/LIVE,
risk/default or promotion authority.

The remaining process is Control Tower intake, clean exact-head freeze and one targeted read-only GPT
Scrutiny recheck of `MT4A-001`. The bounded author must not self-approve, commit, push, merge, rebase or
activate this WIP. All prior limits remain unchanged: no runtime, inventory, account/deployment registry,
Owner Monitor, OneDrive, task, terminal, risk, trading or MT5-ledger semantic change is authorized.
