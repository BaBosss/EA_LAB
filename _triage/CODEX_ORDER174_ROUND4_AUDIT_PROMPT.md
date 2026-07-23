# QA task: independent verification of the ORDER-174 backtest-correlation extension (round 4)

Neutral quality-assurance inspection of `D:\EA_LAB\scripts\portfolio_risk_admission.py` at commit
`d5320e5` (verify the script blob matches that commit if HEAD advanced). Round 3 verified the
deals-shape poison, the original strict-timestamp repros, genuine-MT5-report compatibility, and
all round-2 behaviors; it found 2 SEV-1 + 2 MINOR, all addressed in this small revision.
Changed surfaces only: `_MONEY_GROUPED_RE` (one consistent separator), `_DEAL_TS_RE` (space-only
separator), the seconds range check, the no-realized-deals wording, and cage-30 fixtures.

## Ground rules
- Read-only, with one exception: you MAY create temp files under a temp directory and run
  `D:\EA_LAB\tools\python312\python.exe` against in-memory/temp inputs to probe behavior.
- Do NOT modify any repo file, any .set, any CSV under portfolio/, or the git index.
- Prefer executing concrete failing-input probes over reading alone.
- Report findings with severity (SEV-1 wrong number/sizing decision, SEV-2 correctness risk,
  MINOR), each with a concrete reproducing input and observed output.

## Claims to verify (responding to round-3 F1-F4)
1. (was F1) Money grouping accepts exactly ONE consistent thousands separator per number:
   '1,234,567.5', '1 234', '-2,000' parse; '3,000 000', '1,234 567', '1,0' are CORRUPT and
   poison the series (pair stays at the 1.0 default). Probe the round-3 repro end-to-end and
   any further grouping edge you can devise (leading separator, trailing separator, 4-digit
   groups, separator before decimal, multiple decimals).
2. (was F2) Timestamps: space separator only ('T' poisons), seconds range-checked (':99'
   poisons), full-match anchored (valid prefix + trailing junk poisons). Probe all three
   end-to-end plus any further timestamp edge you can devise.
3. (was F3) The no-realized-deals exclusion now carries 'WHOLE magic excluded'.
4. (was F4) Cage 30 kills these mutations: removing the regex end anchor, restoring '[ T]',
   removing the seconds check, and restoring the per-group '[ ,]' class. Verify each by
   in-memory mutation.
5. No NEW defects from this revision and no regression: genuine MT5 reports from
   `D:\EA_LAB\_mt5_auto\reports\` still parse cleanly (sample a few, including at least one
   UTF-16 one if present); cage 28/29/30 semantics hold; the round-2/round-3 verified
   behaviors (overlap refusal, output protection via actual CLI, fail-soft non-file/unreadable
   paths, deals-shape poison, prefix-timestamp poison) hold; a spot-check of one or two
   ORDER-170 engine invariants holds; the current-inventory CLI run (empty map -> 0/N
   measured, N default) holds.

Deliberate design points, not defects (flag only if you can produce a WRONG number through
them): rows without an 'out' cell skipped silently; refusal of mid-month-split windows;
locale-decimal commas treated as corrupt rather than guessed; day validated only to 1-31
(month-length/leap precision is not needed for month bucketing); the empty map template;
live outranking backtest; absent pairs defaulting to 1.0.

## Required output
Write your full report to `D:\EA_LAB\_triage\CODEX_ORDER174_ROUND4_AUDIT_RESULT.md` with:
- a verdict line: `VERDICT: PASS` (no SEV-1/SEV-2 findings) or `VERDICT: FAIL`
- a claim-by-claim table (VERIFIED / NOT VERIFIED / PARTIAL with evidence)
- every finding with severity, file:line, concrete reproducing input, observed output
- the exact output of `D:\EA_LAB\tools\python312\python.exe D:\EA_LAB\scripts\portfolio_risk_admission.py --selftest`
