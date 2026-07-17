# MRIS PowerShell QA review

- **MAJOR** — `scripts/mris/mris_web_feeder.ps1:55-57`: a non-empty HTTP-200 Yahoo error is cached before its JSON/chart payload is validated, destroying the last usable cache. Concrete input: a prior good `^VIX.json`, followed by response `{"chart":{"result":null,"error":{"code":"Not Found"}}}`. Line 57 overwrites the good cache; line 72 then throws, and a later network outage cannot use the prior cache. Minimal fix: parse and validate `chart.result[0]` and quote arrays before replacing the cache (or write the cache only after `Compute-Row` succeeds).

- **MAJOR** — `scripts/mris/mris_web_feeder.ps1:193`: snapshot output is written directly to the live path, so an interrupted/failed write can truncate the only snapshot. Concrete failure: the `-Snapshot` volume runs out of space while the 8-row string is being written (or AV/power interrupts the write). Minimal fix: write a same-directory temporary UTF-8 file, then atomically replace/move it, retaining a backup.

- **MAJOR** — `scripts/mris/mris_classify.ps1:164-165`: XAU's VIX co-move check reads raw `data_status`, not the age-gated active result. Concrete input (with default 120h): `VIX,...,chg5d_pct=20,data_status=OK,asof=2026-01-01 00:00` plus fresh `XAUUSD,...,chg5d_pct=2,data_status=OK,asof=<now>`. VIX is excluded as `STALE_AGED`, but XAU still receives signal `-1` at line 169 from that stale VIX change. Minimal fix: require the already-calculated VIX result to be `.active` (or centralize the effective status before cross-row reads).

- **MAJOR** — `scripts/mris/mris_classify.ps1:33` (also feeder `:182-183`): CSV number parsing/formatting is culture-dependent. Concrete failing input: under `de-DE`, snapshot field `VIX,17.5,,,,OK,,x` is parsed by `Double.TryParse` as `175`, causing the VIX STRESS override rather than a mid-range VIX; conversely a `de-DE` feeder can emit `"1,2345"`, which an `en-US` classifier reads as `12345`. Minimal fix: serialize and parse numeric CSV values with `InvariantCulture` (`NumberStyles.Float` for parsing).

- **MINOR** — `scripts/mris/mris_classify.ps1:43-46`: a non-empty malformed `asof` silently fails open. Concrete input: an old row with `data_status=OK,asof=2026-01-01T00:00:00Z`; `ParseExact` throws and the empty catch leaves it active forever. Minimal fix: catch into an inactive status such as `STALE_INVALID_ASOF`; preserve ungated behavior only for blank/missing `asof`.

Checked correct: OHLC filtering preserves high/low/close alignment; SMA/ATR/5d indices and short-series behavior are correct; the US10Y bps formula/sign is correct; valid invariant `asof` values age-gate correctly; the direct VIX STRESS override reads the active set; merge ordering, missing `asof` header addition, failure-value retention, and CSV quoting are correct. No remaining PS 5.1 case-collision, `+=`, null-side, or one-item-pipeline defect found.

Verdict: **fix-then-ship**.
