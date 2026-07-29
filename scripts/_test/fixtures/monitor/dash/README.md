# fixtures/monitor/dash

A miniature `portfolio\` tree for `scripts/_test/run_monitor_integrity_tests.ps1`
PART 4/5. The suite copies it to a temp directory, stamps the snapshot CSVs with
the current time (the floating panel greys anything over 26h, and fixture mtimes
otherwise depend on when git checked the repo out), then runs the **real**
`scripts/live_dashboard.ps1` against it and reads the HTML.

Account numbers are deliberately fake (`10000000x` / `90000000x`) so a fixture can
never be mistaken for, or joined against, a real login.

## The design that makes the assertions mean something

All three registered accounts trade an **identical** deal series — `+1000`,
`-2000`, `+500` — and carry an **identical** `kill_rule` of `closedDD 20%`. They
differ in exactly one field, `base_equity`:

| account | base_equity | peak / trough | Max DD% | flag at kill 20% / warn 16% |
|---|---|---|---|---|
| `100000001` | `10000` | 11000 / 9000 | **18.2%** | yellow |
| `100000002` | `100000` | 101000 / 99000 | **2.0%** | green |
| `100000003` | *(blank)* | — | **UNKNOWN** | own status, no number |

So any difference the test observes between them can only have come from the
denominator — and the same trading is flagged yellow on one account and green on
another, which is the point: the base equity is not cosmetic, it decides the
kill-switch colour.

The floating snapshots carry an identical `float_pl` of `-2500` on all three, so
the kill-DD *currency* equivalent splits the same way: `2000` (breached),
`20000` (not breached), and nothing computable at all.

`EA_LAB_deals_900000009_*.csv` is the D4 case — a login present in collected data
with no row in `ACCOUNTS.csv`. It must render as UNREGISTERED with its filename as
provenance, never be silently dropped.

## Do not "simplify" these

- The two base equities must stay a factor of 10 apart with the **specific**
  values asserted in the suite. "The numbers differ" would also be satisfied by an
  implementation that resolves per account and reads the wrong row.
- The three accounts must keep the identical deal series. The moment they differ,
  a DD difference no longer isolates the denominator.
- `100000003` must keep its `base_equity` blank. It is the only case that proves
  the code suppresses rather than substitutes.
