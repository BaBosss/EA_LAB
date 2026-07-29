# fixtures/monitor/snapshots

Hand-written `control_room_snapshot.json` fixtures for
`scripts/_test/run_monitor_integrity_tests.ps1` PART 2/3
(the `Get-MonitorCoverage` rules in `scripts/lib/monitor_coverage.ps1`).

They are trimmed to the sections the coverage check reads — `meta`,
`system_health`, `floating_risk`, `summary.unknown_magics_unclassified` — and
nothing else. A full snapshot is ~64 deployment rows of noise that would make a
diff on these files unreadable, and none of it is input to the rules under test.

Account numbers are deliberately fake (`10000000x` / `90000000x`) so that a
fixture can never be mistaken for, or accidentally joined against, a real login.

| file | what it pins |
|---|---|
| `green.json` | everything FRESH on both sensors, incl. a healthy non-LAB account — the chain must exit 0 |
| `warn_nonlab.json` | a `USER_OBSERVED` account with a dead deal sensor **and** a BLIND float sensor — logged, never red |
| `red_float_blind.json` | a LAB_MANAGED account whose float sensor is `BLIND` while its deal sensor is `FRESH` — the D1 defect, exactly |
| `red_float_stale.json` | same but `STALE` — kept as its own fixture so the two states cannot collapse into one code path |
| `red_float_missing.json` | a LAB_MANAGED account absent from the `floating_risk` array entirely |
| `red_deal_stale.json` | the pre-existing rule: LAB_MANAGED deal sensor `STALE` — a regression guard, it must keep working |
| `no_floating_section.json` | a pre-v3-shaped snapshot with no `floating_risk` at all |
| `unclassified.json` | everything fresh, but `unknown_magics_unclassified = 2` — must be logged and must NOT be red |
| `unreadable.json` | malformed JSON — "I cannot read the input" must not report as "nothing to report" |
| `not_a_snapshot.json` | valid JSON, wrong document — same treatment as unreadable |
