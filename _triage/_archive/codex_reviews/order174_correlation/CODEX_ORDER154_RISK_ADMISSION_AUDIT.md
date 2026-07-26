# CODEX ORDER-154 — Neutral QA audit of portfolio risk admission

> ⚠️ **File provenance:** Codex ran this audit read-only and its sandbox refused the file write, so the
> report text below was transcribed verbatim from its return by Opus-seat (2026-07-23). Opus-seat then
> **independently re-verified 4 of the findings by direct probe** before accepting them — results
> appended at the bottom. Nothing here was taken on trust.

Target: `scripts/portfolio_risk_admission.py`
Specification: `AGENT_TASKBOARD.md`, ORDER-154 DESIGN
Audit mode: findings only; no source edits, backtests, strategy verdicts, staging, or commits.

## Summary

The quadratic-form implementation is correct on finite, positive, per-strategy inputs: it performs the
full double summation, uses symmetric pair lookup, takes one square root after the complete sum, and
applies the specified missing-correlation default of `1.0`. CSV parsing uses `csv.DictReader`,
REAL_CENT is report-only, and the limitation text appears in both the module header and generated report.

The implementation is not yet fail-closed enough for sizing use. Five SEV-1 findings can produce a wrong
aggregate risk number or admission decision, principally through basket duplication, zero-filled deal
data, acceptance of zero DD95, an unwired broker-minimum assumption, and a bounds-check bypass in
`admit_candidate`.

Self-test executed read-only with the repository portable Python: 6/6 reported PASS. Those tests do not
cover several findings below, and the missing-DD95 test is not capable of detecting an inversion of the
conservative parsing default.

## SEV-1

### 1. `basket_id` is ignored, so a shared basket DD95 can be counted once per sibling magic
`portfolio_risk_admission.py:104-124`, `:426-447`

`load_expectations()` reduces the file to `magic -> DD95` and discards `basket_id`. `summarize_account()`
then includes every numeric magic independently. If siblings repeat the same basket-level DD95, the
quadratic form counts it multiple times.

```csv
magic,basket_id,dd95_expected
LEG1,BASKET_X,10
LEG2,BASKET_X,10
```
Emits `20.0%`; the one shared basket figure should contribute `10.0%` once.

The current `expectations.csv` avoids the error **by convention only** (each IchiADX basket has one
numeric primary row and one `UNKNOWN` sibling). The code neither enforces nor validates that convention.

### 2. Missing/unparseable deal P&L cells become zero and can create a non-conservative measured correlation
`:127-131`, `:178`, `:208-216`

`_num()` returns `0.0` for `None`, empty cell, or unparseable text. A malformed `profit` cell therefore
does not make the pair correlation UNKNOWN — it becomes a zero monthly observation and may yield a
correlation below `1.0`, bypassing the required conservative default.

Failing input: shared monthly `A=[1,2,3,4]`, `B=[1,2,"",4]` → Pearson ≈ `0.52915`. For `DD95=10` each,
estimate ≈ `17.488%`; treating the corrupted pair as missing would default to `1.0` → `20.0%`.

Missing whole deal files and pairs with insufficient shared months **do** default safely to `1.0`; the
unsafe path is a *partially* malformed series still variable enough for Pearson.

### 3. A literal numeric zero DD95 is accepted as known and silently enters arithmetic as zero
`:117-123`, `:248-268`, `:429-446`

`float(raw)` accepts `"0"`/`"0.0"` without positivity/finiteness check. A single row with
`dd95_expected=0` passes the bounds guard and emits `portfolio_DD_est=0.0` instead of being excluded.

All other absence forms are handled safely (empty, whitespace, case-insensitive `UNKNOWN`, `None`,
missing column, unparseable text, missing file). Numeric zero is the silent-zero hole.

### 4. Broker minimum is a placeholder, so the default path can emit an unusable reduced factor instead of escalating
`:62-63`, `:286-287`, `:380-405`

Default `broker_min_lot_factor=0.01` is a placeholder; the real `broker_min_lot / locked_lot` ratio is
never read or supplied by the report path, so "cannot fit at broker minimum" is unreliable.

Failing input: existing DD95 `20`, candidate `20`, budget `21` → required scale `0.05`, returns
`ADMIT_REDUCED` factor `0.05`. If locked lot is `0.10` and broker min `0.01`, true minimum factor is
`0.10` → correct answer is `DEFER_ESCALATE`.

### 5. The required bounds guard does not run on every computation path in `admit_candidate`
`:315-337`, `:346-360`

Existing portfolio computed directly at `:315-324` without the `max <= est <= sum` check. Only the later
full-size candidate result is bounds-checked. The unchecked existing value can be returned directly or
influence a sizing decision.

```python
existing = {"A": 10.0, "B": 10.0}; corr = {frozenset(("A","B")): -1.0}
candidate = ("C", 5.0); budget = 25.0
```
Existing estimate `0.0` violates the `10.0` lower bound, yet combined `15.0` passes and the function
returns `ADMIT_FULL`. Calling guarded `portfolio_dd_est(existing, corr)` would refuse.

## SEV-2

**6. Reduced factor rounded before emission without recomputing post-round risk** (`:372-405`) — exact
root solved then `round(x,4)`; rounding up can exceed budget with no post-round check. Candidate DD95
`30`, budget `10.001` → emits `0.3334` implying `10.002`.

**7. Non-finite DD95 not rejected; `+inf` passes the bounds guard** (`:117-123`, `:253-268`) — tokens
like `inf`/`Infinity` accepted; both `max` and `sum` are inf so bounds succeed, returns `inf`, JSON emits
non-standard `Infinity`. (`NaN` happens to fail the comparison, but validation should be explicit.)

**8. Output path options can overwrite protected input files or a `.set`** (`:800-804`, `:819-821`) —
`--out-md`/`--out-json` accept arbitrary paths with no protected-path guard, e.g.
`--out-md portfolio/DEPLOYMENTS.csv` reads then overwrites it, contradicting the header's "never writes"
guarantee.

**9. The missing-DD95 self-test is tautological** (`:744-764`) — Test 5 omits `UNKNOWN2` from its own
fixture and never calls `load_expectations()`; Test 6 only calls a nonexistent path. A regression mapping
an `UNKNOWN` cell to `0.0` would still pass every missing-DD95 test.

## MINOR

**10. Custom `--expectations` paths reported using default path's existence** (`:537`, `:559`) —
coverage metadata/missing-file message check the module constant, not `args.expectations`.

## Checks that pass

Formula (genuine double summation, single sqrt after full sum) · symmetry + `corr_ii=1.0` · missing
correlation at pair/file level (except SEV-1 #2 path) · all *named* missing-DD95 forms · main formula
bounds refusal for finite positive inputs · CSV quote handling (`csv.DictReader` throughout; 49
deployment + 48 expectation rows parsed with zero misalignment incl. quoted embedded commas) ·
lot-factor range on the normal default path · REAL_CENT report-only · default side effects limited to
the two `_triage` artifacts · self-test executes 6/6 · limitation disclosure present in header,
`LIMITATION` constant, and generated reports.

---

## ✅ Opus-seat independent verification (2026-07-23) — did not take the report on trust

Re-ran 4 findings by direct in-memory probe against the real module:

| Finding | Probe | Result |
|---|---|---|
| SEV-1 #3 zero DD95 | `portfolio_dd_est({'EA1': 0.0}, {})` | returned **`0.0`** → **CONFIRMED** |
| SEV-2 #7 infinity | `portfolio_dd_est({'EA1': inf}, {})` | returned **`inf`** → **CONFIRMED** |
| SEV-1 #5 bounds bypass | `admit_candidate('C',5.0,{'A':10,'B':10},{AB:-1.0},25.0)` | returned **`ADMIT_FULL`** while the guarded `portfolio_dd_est()` on the *same* existing inputs **raised `RiskAdmissionError`** → **CONFIRMED** |
| SEV-1 #1 basket_id | source scan of `load_expectations()` | string `basket_id` **absent** → **CONFIRMED** |

**Judgement (Opus-seat):** audit accepted in full. Note this is exactly the outcome the blind-review rule
exists for — the implementing agent's own cage reported 6/6 PASS and still shipped 5 SEV-1 defects, none
of which its self-tests were structurally capable of catching (see SEV-2 #9).

**Consequence for the current numbers:** the previously reported figures (463666728 = 61.03%, 415573666 =
4.15%) are **not invalidated by these defects** — today's `expectations.csv` happens to satisfy the
basket convention by hand, contains no zero/infinite DD95, and the account path's own bounds guard did
run. But the tool is **not yet safe to size real money from** until SEV-1 #1/#3/#5 are fixed, because
each is a silent-wrong-number path rather than a crash.

**Not fixed in this pass** — fixes belong in a follow-up order so the fix itself can be re-audited
rather than self-certified.
