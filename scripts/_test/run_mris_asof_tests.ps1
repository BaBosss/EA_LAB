<#
.SYNOPSIS
    Cage for the MRIS `asof` clock (ORDER-434 finding 1).

.DESCRIPTION
    THE DEFECT THIS EXISTS TO PIN
      mris_macro_feeder.ps1's three Compute-Row* functions wrote
      `asof = (Get-Date)` -- the time the FETCH happened, not the time the
      OBSERVATION is for. The downstream freshness gate (EffStatus in
      mris_crisis_models.ps1) age-checks exactly that field, so it was
      measuring the feeder's own clock against itself and could NEVER fire,
      no matter how old the underlying data was.

      Measured live on 2026-07-27: barometer_snapshot_macro.csv said HY_OAS
      was "OK, 2026-07-27 07:37" while the cache behind it ended
      2026-07-23 -- same value, 2.77, four days apart.

    WHY THE TESTS LOOK LIKE THIS
      The feeder cannot be dot-sourced: loading it runs the fetch loop and
      hits the network. So the functions are lifted out of the REAL file by
      AST and defined here verbatim. That matters -- it means this cage
      tests the shipped text, not a copy that can drift away from it. If a
      function is renamed the extraction count assert below fails loudly
      rather than silently testing nothing (the failure mode ORDER-260 /
      341 / 390 / 411 all shared).

    SENSITIVITY *AND* SPECIFICITY (memory: gate-specificity-not-just-sensitivity)
      It is not enough that an old observation reports old. A fresh one must
      still report fresh, or the "fix" is just a gate jammed in the other
      direction. Both directions are asserted for all three feed kinds.

    NUMERIC REGRESSION
      spot / sma200 / atr20 / chg5d_pct are pinned on hand-computable series.
      A clock fix must not move a single number.

.NOTES
    Pure ASCII on purpose: PowerShell 5.1 decodes a BOM-less .ps1 as ANSI.
    Offline only -- no network, no file writes, no snapshot rewrite.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'

# scripts/_test/ -> repo root is TWO levels up. $PSScriptRoot is empty under
# `powershell.exe -File <relative>` from a non-PowerShell shell, so fall back
# rather than silently computing a wrong root.
if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}

$feeder = Join-Path $RepoRoot 'scripts\mris\mris_macro_feeder.ps1'
$scorer = Join-Path $RepoRoot 'scripts\mris\mris_crisis_models.ps1'
foreach ($p in @($feeder, $scorer)) { if (-not (Test-Path $p)) { throw "missing: $p" } }

# ---- lift the real functions out of the real files (no main loop, no network) ----
# Returns the SOURCE TEXT of EVERY function in the file, and asserts the ones this cage
# depends on are among them.
#
# Two lessons are baked in here, both learned by this cage failing on itself:
#   1. It does NOT dot-source them itself -- dot-sourcing inside a function defines the
#      result in that function's scope, which vanishes on return. First run reported
#      "4 functions extracted" and then nothing was callable.
#   2. It extracts ALL functions rather than a hand-listed subset. A curated list is a
#      second copy of the file's structure and goes stale the moment a helper is added:
#      the fix introduced New-AsOfStamp and the cage broke, not because the code was
#      wrong but because the list was. Take everything; REQUIRE only what is called.
function Get-FunctionSource {
    param([string]$Path, [string[]]$Require)
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    $found = [ordered]@{}
    $defs = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($d in $defs) { if (-not $found.Contains($d.Name)) { $found[$d.Name] = $d.Extent.Text } }
    $missing = @($Require | Where-Object { -not $found.Contains($_) })
    if ($missing.Count -gt 0) {
        throw ("cannot extract {0} from {1} -- renamed or removed? A cage that silently tests nothing is the bug it is meant to catch." -f ($missing -join ', '), (Split-Path -Leaf $Path))
    }
    return $found
}

$feederSrc = Get-FunctionSource -Path $feeder -Require @('Compute-RowFred', 'Compute-RowYahoo', 'Compute-RowRatio', 'Get-CloseMap')
$scorerSrc = Get-FunctionSource -Path $scorer -Require @('EffStatus')
foreach ($t in $feederSrc.Values) { . ([ScriptBlock]::Create($t)) }
foreach ($t in $scorerSrc.Values) { . ([ScriptBlock]::Create($t)) }
$nFeeder = $feederSrc.Count
$nScorer = $scorerSrc.Count
Write-Host ("extracted {0} feeder function(s) + {1} scorer function(s) from source" -f $nFeeder, $nScorer)

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param([string]$What, $Expected, $Actual)
    if ("$Expected" -eq "$Actual") {
        $script:pass++
        Write-Host ("   [PASS] {0}" -f $What) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("   [FAIL] {0}`n          expected: {1}`n          actual  : {2}" -f $What, $Expected, $Actual) -ForegroundColor Red
    }
}

# ---- synthetic payload builders -------------------------------------------------
# Business-day-ish sequence ending on $LastDate. Exact weekday does not matter: the
# functions never look at the calendar, only at order and count.
function New-FredCsv {
    param([datetime]$LastDate, [double[]]$Values)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('observation_date,SERIES')
    $n = $Values.Count
    for ($i = 0; $i -lt $n; $i++) {
        $d = $LastDate.AddDays(-($n - 1 - $i))
        [void]$sb.AppendLine(('{0},{1}' -f $d.ToString('yyyy-MM-dd'), $Values[$i]))
    }
    return $sb.ToString()
}

function New-YahooJson {
    param([datetime]$LastDate, [double[]]$Closes, [switch]$NoHighLow)
    $n = $Closes.Count
    $ts = @(); $hi = @(); $lo = @()
    for ($i = 0; $i -lt $n; $i++) {
        $d = $LastDate.AddDays(-($n - 1 - $i))
        $ts += [long]([DateTimeOffset]::new([datetime]::SpecifyKind($d.Date, [DateTimeKind]::Utc)).ToUnixTimeSeconds())
        $hi += $Closes[$i] + 1
        $lo += $Closes[$i] - 1
    }
    $quote = if ($NoHighLow) {
        @{ close = $Closes }
    } else {
        @{ close = $Closes; high = $hi; low = $lo }
    }
    $obj = @{ chart = @{ result = @( @{ timestamp = $ts; indicators = @{ quote = @($quote) } } ) } }
    return ($obj | ConvertTo-Json -Depth 10)
}

# ---- the hand-computable series -------------------------------------------------
# values 1..7 -> spot 7 | sma over 7 = 4 | mean|diff| over 6 = 1 | chg5d = (7/2-1)*100 = 250
$SERIES = @(1, 2, 3, 4, 5, 6, 7)
$STALE_DATE = (Get-Date).Date.AddDays(-9)
$FRESH_DATE = (Get-Date).Date

Write-Host ''
Write-Host '=== FRED (the feed the live defect was measured on) ==='
$rowStale = Compute-RowFred -Symbol 'HY_TEST' -Note 'n' -RawCsv (New-FredCsv -LastDate $STALE_DATE -Values $SERIES) -FromCache $false
Assert-Equal 'stale FRED: asof carries the OBSERVATION date, not the fetch time' `
    $STALE_DATE.ToString('yyyy-MM-dd') ("$($rowStale.asof)".Split(' ')[0])
$rowFresh = Compute-RowFred -Symbol 'HY_TEST' -Note 'n' -RawCsv (New-FredCsv -LastDate $FRESH_DATE -Values $SERIES) -FromCache $false
Assert-Equal 'fresh FRED: today observation still reports today (specificity)' `
    $FRESH_DATE.ToString('yyyy-MM-dd') ("$($rowFresh.asof)".Split(' ')[0])

Write-Host '   -- numeric regression: a clock fix must move NO number --'
Assert-Equal 'FRED spot'      7   $rowStale.spot
Assert-Equal 'FRED sma200'    4   $rowStale.sma200
Assert-Equal 'FRED atr20'     1   $rowStale.atr20
Assert-Equal 'FRED chg5d_pct' 250 $rowStale.chg5d_pct

Write-Host ''
Write-Host '=== FRED with a gap row (the . placeholder FRED uses for a missing obs) ==='
# The date column must stay ALIGNED with the value column when a row is skipped --
# an off-by-one here would report the wrong observation date, which is the same class
# of defect with a friendlier face.
# Layout, oldest first: -7 = 1 | -6 = '.' (the gap) | -5..0 = 2..7. The last row must
# land EXACTLY on $STALE_DATE, or this test asserts a date that is not in its own input.
# (First draft used -(7-$k+1), which put the last row a day early -- the code returned
# the true last observation date and the assertion was what was wrong. Worth leaving in
# the record: a red cage is a claim about the code OR about the test, and which one it
# is has to be checked, not assumed.)
$gapCsv = "observation_date,SERIES`n"
$gapCsv += ('{0},1' -f $STALE_DATE.AddDays(-7).ToString('yyyy-MM-dd')) + "`n"
$gapCsv += ('{0},.' -f $STALE_DATE.AddDays(-6).ToString('yyyy-MM-dd')) + "`n"
foreach ($k in 2..7) { $gapCsv += ('{0},{1}' -f $STALE_DATE.AddDays(-(7 - $k)).ToString('yyyy-MM-dd'), $k) + "`n" }
$rowGap = Compute-RowFred -Symbol 'HY_TEST' -Note 'n' -RawCsv $gapCsv -FromCache $false
Assert-Equal 'gap row skipped: asof is the last DATED-AND-VALUED observation' `
    $STALE_DATE.ToString('yyyy-MM-dd') ("$($rowGap.asof)".Split(' ')[0])
Assert-Equal 'gap row skipped: spot still the last real value' 7 $rowGap.spot

Write-Host ''
Write-Host '=== Yahoo (same defect, same file, never separately reported) ==='
$yStale = Compute-RowYahoo -Symbol 'SP_TEST' -Note 'n' -RawJson (New-YahooJson -LastDate $STALE_DATE -Closes $SERIES) -FromCache $false
Assert-Equal 'stale Yahoo: asof carries the last BAR date' `
    $STALE_DATE.ToString('yyyy-MM-dd') ("$($yStale.asof)".Split(' ')[0])
$yFresh = Compute-RowYahoo -Symbol 'SP_TEST' -Note 'n' -RawJson (New-YahooJson -LastDate $FRESH_DATE -Closes $SERIES) -FromCache $false
Assert-Equal 'fresh Yahoo: today bar still reports today (specificity)' `
    $FRESH_DATE.ToString('yyyy-MM-dd') ("$($yFresh.asof)".Split(' ')[0])
Write-Host '   -- numeric regression (Yahoo atr uses true range: h-l = 2 every bar) --'
Assert-Equal 'Yahoo spot'      7   $yStale.spot
Assert-Equal 'Yahoo sma200'    4   $yStale.sma200
Assert-Equal 'Yahoo atr20'     2   $yStale.atr20
Assert-Equal 'Yahoo chg5d_pct' 250 $yStale.chg5d_pct

Write-Host ''
Write-Host '=== ratio feed (CREDITPX) ==='
# HYG 2,4,..,14 over IEF all-1 -> ratio 2,4,..,14: spot 14 | sma 8 | mean|diff| 2 | chg5d 250
$num = New-YahooJson -LastDate $STALE_DATE -Closes @(2, 4, 6, 8, 10, 12, 14)
$den = New-YahooJson -LastDate $STALE_DATE -Closes @(1, 1, 1, 1, 1, 1, 1)
$rStale = Compute-RowRatio -Symbol 'CREDITPX_TEST' -Note 'n' -RawNum $num -RawDen $den -FromCache $false
Assert-Equal 'stale ratio: asof carries the last ALIGNED date' `
    $STALE_DATE.ToString('yyyy-MM-dd') ("$($rStale.asof)".Split(' ')[0])
Assert-Equal 'ratio spot'      14  $rStale.spot
Assert-Equal 'ratio sma200'    8   $rStale.sma200
Assert-Equal 'ratio atr20'     2   $rStale.atr20
Assert-Equal 'ratio chg5d_pct' 250 $rStale.chg5d_pct

Write-Host ''
Write-Host '=== the point of all of it: the downstream gate can now actually fire ==='
# EffStatus reads $MaxAgeHours from its script scope in the real scorer; supply it here
# the same way the real param block does, and vary it to test both directions.
$MaxAgeHours = 48
Assert-Equal 'gate FIRES on a 9-day-old observation (was impossible before: asof was always now)' `
    'STALE_AGED' (EffStatus $rowStale)
Assert-Equal 'gate STAYS QUIET on a fresh observation (specificity)' `
    'OK' (EffStatus $rowFresh)

$MaxAgeHours = 120
Assert-Equal 'threshold is honoured, not hard-coded: 9 days still stale at MaxAgeHours=120' `
    'STALE_AGED' (EffStatus $rowStale)

# A row whose fetch failed is STALE by data_status regardless of dates -- that leg
# already worked and must keep working.
$cacheRow = Compute-RowFred -Symbol 'HY_TEST' -Note 'n' -RawCsv (New-FredCsv -LastDate $FRESH_DATE -Values $SERIES) -FromCache $true
Assert-Equal 'cache fallback still tags STALE via data_status (unchanged leg)' 'STALE' (EffStatus $cacheRow)

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host ("FAIL  {0}/{1} passed, {2} failed" -f $script:pass, ($script:pass + $script:fail), $script:fail) -ForegroundColor Red
    exit 1
}
Write-Host ("PASS  {0}/{0}" -f $script:pass) -ForegroundColor Green
exit 0
