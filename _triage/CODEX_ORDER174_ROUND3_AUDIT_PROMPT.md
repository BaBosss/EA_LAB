# QA task: independent verification of the ORDER-174 backtest-correlation extension (round 3)

Neutral quality-assurance inspection of `D:\EA_LAB\scripts\portfolio_risk_admission.py` at commit
`49ed60b` (verify the script blob matches that commit if HEAD advanced). Round 2 verified the
overlap refusal, output protection, and fail-soft non-file handling, and found 3 SEV-1 + 2 MINOR
on deeper malformed report input, all addressed in this revision. Changed surfaces:
`_parse_money_cell()`, `_DEAL_TS_RE` strict timestamp parse, the deals-shaped-row poison rule in
`_extract_backtest_monthly()`, unified exclusion wording, per-magic cage assertions, cage 30.

## Ground rules
- Read-only, with one exception: you MAY create temp files under a temp directory and run
  `D:\EA_LAB\tools\python312\python.exe` against in-memory/temp inputs to probe behavior.
- Do NOT modify any repo file, any .set, any CSV under portfolio/, or the git index.
- Prefer executing concrete failing-input probes over reading alone.
- Report findings with severity (SEV-1 wrong number/sizing decision, SEV-2 correctness risk,
  MINOR), each with a concrete reproducing input and observed output.

## Claims to verify (responding to round-2 F1-F5)
1. (was F1) A row carrying a realized-deal direction cell ('out') with a cell count other than
   13 poisons the WHOLE series. Probe the round-2 repro (good 4-month segment + a readable
   segment holding one 12-cell 'out' row -> magic excluded with reason, pair defaults to 1.0).
   Rows without an 'out' cell (headers, settings, orders tables) are still skipped silently --
   that is the intended filter, not a defect.
2. (was F2) Deal timestamps must FULLY match YYYY.MM.DD HH:MM[:SS] with month 1-12, day 1-31,
   hour <= 23, minute <= 59 -- '2026.013.15 ...', '2026.01THIS_IS_NOT_A_DATE', and similar
   prefix-only spellings poison the series and can never count toward MIN_SHARED_MONTHS.
3. (was F3) Money cells accept commas/spaces ONLY as well-formed thousands grouping
   ('1,234.5', '1 234', '-2,000' parse correctly); '1,0' and other malformed groupings are
   CORRUPT and poison the series. Probe the round-2 repro pair and confirm the resulting pair
   stays at the 1.0 default.
4. (was F4/F5) Cage 29/30 assertions are per-magic (no joined-string cross-matching); the
   `is_file() -> exists()` mutation is now killed (magic E's reason must specifically say
   'not a regular file'); every exclusion reason carries 'WHOLE magic excluded'. Verify by
   mutation: is_file->exists, removing the deals-shape poison, relaxing the timestamp regex to
   the old prefix form, and reverting _parse_money_cell to blind comma deletion should each
   fail at least one cage.
5. No NEW defects from this revision and no regression: cage 28/29 semantics, the round-2
   verified behaviors (overlap refusal + non-overlap concatenation control, output-path
   protection via actual CLI, fail-soft unreadable/directory paths), a spot-check of one or
   two ORDER-170 engine invariants, and the current-inventory CLI run (empty map -> 0/N
   measured, N default) all hold. Also sanity-check that a REAL MT5 report from
   `D:\EA_LAB\_mt5_auto\reports\` (pick any recent .htm with a deals table) still parses
   months successfully through `_extract_backtest_monthly()` -- the strict rules must not
   reject genuine MT5 output. If genuine reports fail to parse, that is a finding (the
   feature would be silently useless).

Robustness probes on malformed report data remain in scope -- expectation everywhere:
fail-soft exclusion with a surfaced per-magic reason, conservative 1.0 fallback, never a
fabricated observation, never a crash, never a write to any input.

Deliberate design points, not defects (flag only if you can produce a WRONG number through
them): rows without an 'out' cell skipped silently; refusal of mid-month-split windows;
locale-decimal commas treated as corrupt rather than guessed; the empty map template; live
outranking backtest; absent pairs defaulting to 1.0.

## Required output
Write your full report to `D:\EA_LAB\_triage\CODEX_ORDER174_ROUND3_AUDIT_RESULT.md` with:
- a verdict line: `VERDICT: PASS` (no SEV-1/SEV-2 findings) or `VERDICT: FAIL`
- a claim-by-claim table (VERIFIED / NOT VERIFIED / PARTIAL with evidence)
- every finding with severity, file:line, concrete reproducing input, observed output
- the exact output of `D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest`
