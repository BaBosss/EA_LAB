<#
pilot_verify_selected.ps1 - ORDER-1273 step 6. Run the SELECTED configurations, once each.

WHY THIS EXISTS
  ORDER-1273 selects a configuration per cell as the PER-DIMENSION MEDIAN of the plateau set,
  snapped to the declared grid. A per-dimension median need not correspond to any row that was
  actually evaluated -- and for B14-H01-r1/BTCUSD/H4 it demonstrably does not (0 of 3,991 rows carry
  that combination; the nearest 4 rows differ in one dimension). Without this run, the number handed
  to ORDER-1254 would be INTERPOLATED, not measured.

WHAT IT DOES NOT DO
  It issues no verdict. Design section 10 stops this slice at EVIDENCE_COMPLETE, and everything here
  is Model 1 on MAIN -- which CLAUDE.md makes non-verdict-grade for a grid, and both hypotheses
  carry engine_edge=true, for which Model 4 is mandatory. It does not judge the result against any
  bar, does not re-select, and does not touch BWD (design 6.2: BWD is never a search surface; it is
  ORDER-1254's hard gate).

WHERE THE MECHANICS LIVE
  scripts\lib\pilot_run.ps1, shared with scripts\pilot_cells.ps1. There is exactly one preset
  generator (gen_default_preset.py) and one report parser (parse_mt5_report.py) in this repo and
  both scripts reach them through that library.

USAGE  powershell -NoProfile -File scripts\pilot_verify_selected.ps1
       powershell -NoProfile -File scripts\pilot_verify_selected.ps1 -CellIds 'B14-H02-r1/BTCUSD/H4'
REQUIRES: MT5 GUI closed (mt5_run.ps1's process guard).
ASCII only (PS 5.1 reads a BOM-less .ps1 as ANSI).
#>
[CmdletBinding()]
param(
  # Empty = the NEWEST record in factory\runs\pilot\selection. Never a hardcoded filename: the
  # selection cage already establishes that the newest record is the live answer and that a
  # superseded one must not resurrect an old one.
  [string]$SelectionRecord = '',
  # Empty = every SELECTED row in that record.
  [string[]]$CellIds = @(),
  # MAIN, pinned. CLAUDE.md pins MAIN = 2023.01-2025.12 and the probe surface was produced over
  # exactly this window; verifying over a different one verifies a different thing.
  [string]$FromDate = '2023.01.01',
  [string]$ToDate   = '2025.12.31',
  [ValidateSet('MAIN', 'BWD', 'HOLDOUT', 'OTHER')]
  [string]$Window   = 'MAIN',
  [int]$Model       = 1,
  # ORDER-1240 resolved this mechanically to 0.03 and the probe swept the lot0p03 configuration.
  # It is CHECKED against the probe's own base .set below rather than trusted from this default.
  [string]$FirstLot = '0.03',
  [string]$Terminal = 'D:\Meta 5\terminal64.exe',
  [string]$DataDir  = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
  [string]$OutDir   = '',
  [double]$CryptoRateLong  = 14.67,
  [double]$CryptoRateShort = 0.49
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$py = Join-Path $root 'tools\python312\python.exe'
# Every python child gets utf-8 stdout, or the first non-cp1252 glyph raises UnicodeEncodeError and
# surfaces as an unexplained non-zero exit (memory thai-output-kills-a-suite-inside-the-hook).
$env:PYTHONIOENCODING = 'utf-8'
if (-not $OutDir) { $OutDir = Join-Path $root 'factory\runs\pilot' }
$verifyDir = Join-Path $OutDir 'verification'
New-Item -ItemType Directory -Force $verifyDir | Out-Null

. (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')
. (Join-Path $PSScriptRoot 'lib\pilot_run.ps1')

function Fail([string]$msg) { Write-Host ("REFUSED: " + $msg) -ForegroundColor Red; exit 1 }

# --- the selection record -------------------------------------------------------------------------
if (-not $SelectionRecord) {
  $cands = @(Get-ChildItem (Join-Path $OutDir 'selection') -Filter 'selection_*.jsonl' -ErrorAction SilentlyContinue |
             Sort-Object Name -Descending)
  if ($cands.Count -eq 0) { Fail ("no selection record under " + (Join-Path $OutDir 'selection') + " -- ORDER-1273 step 5 has to have run before step 6 can verify anything") }
  $SelectionRecord = $cands[0].FullName
}
if (-not (Test-Path -LiteralPath $SelectionRecord)) { Fail ("selection record not found: " + $SelectionRecord) }
Write-Host ("=== ORDER-1273 step 6 -- verifying the SELECTED configurations ===") -ForegroundColor Cyan
Write-Host ("  record : " + $SelectionRecord)
Write-Host ("  window : " + $Window + " " + $FromDate + ".." + $ToDate + "  model " + $Model + "  first lot " + $FirstLot)
Write-Host ("  LANE   : " + $Terminal)
Write-Host ("  NO VERDICT IS ISSUED HERE -- design section 10 stops this slice at EVIDENCE_COMPLETE") -ForegroundColor DarkGray

$all = @()
foreach ($line in (Get-Content -LiteralPath $SelectionRecord -Encoding UTF8)) {
  if ($line.Trim()) { $all += ($line | ConvertFrom-Json) }
}
$selected = @($all | Where-Object { $_.status -eq 'SELECTED' })
if ($selected.Count -eq 0) { Fail ("no SELECTED row in " + $SelectionRecord) }

if ($CellIds.Count -gt 0) {
  foreach ($c in $CellIds) {
    $hit = @($all | Where-Object { $_.cell_id -eq $c })
    if ($hit.Count -eq 0) { Fail ("cell " + $c + " does not appear in the record at all") }
    # "not SELECTED" is named with its actual status. A BOUNDARY cell is ORDER-1302's problem and
    # running it here would produce a number for a configuration the criterion did not choose.
    if ($hit[0].status -ne 'SELECTED') { Fail ("cell " + $c + " has status " + $hit[0].status + ", not SELECTED. Only a SELECTED cell has a configuration to verify; " + $hit[0].status + " is ORDER-1302's business.") }
  }
  $selected = @($selected | Where-Object { $CellIds -contains $_.cell_id })
}

# --- refusals that must happen BEFORE any tester time is spent ------------------------------------
foreach ($s in $selected) {
  if ($s.boundary_dimensions -and @($s.boundary_dimensions).Count -gt 0) {
    Fail ("cell " + $s.cell_id + " is marked SELECTED but names boundary dimension(s) " +
          (@($s.boundary_dimensions) -join ', ') + ". The record contradicts itself and this script " +
          "will not resolve that by picking one half of it.")
  }
  if (-not $s.selected -or -not $s.dimensions) { Fail ("cell " + $s.cell_id + " carries no selected values") }
  # Every swept dimension must have a selected value and vice versa. A record that selects on six of
  # seven dimensions would leave the seventh at its pinned default silently, and the run would be of
  # a configuration nobody chose.
  $selKeys = @($s.selected.PSObject.Properties.Name | Sort-Object)
  $dimKeys = @($s.dimensions | Sort-Object)
  if (($selKeys -join ',') -ne ($dimKeys -join ',')) {
    Fail ("cell " + $s.cell_id + " selects on {" + ($selKeys -join ', ') + "} but declares swept dimensions {" + ($dimKeys -join ', ') + "}")
  }
}

# THE SIZING IS CHECKED AGAINST THE PROBE'S OWN BASE .set, NOT TRUSTED FROM THE PARAMETER DEFAULT.
# The probe swept the lot0p03 configuration; a verification at a different first lot verifies a
# different thing, and the two would be indistinguishable in the record afterwards.
$lotTagExpected = 'lot' + ($FirstLot -replace '\.', 'p')
foreach ($rev in (@($selected | ForEach-Object { $_.hypothesis_revision }) | Sort-Object -Unique)) {
  $probeBase = Join-Path $OutDir ('effective_' + ($rev -replace '-', '_') + '_baseline_' + $lotTagExpected + '.set')
  if (-not (Test-Path -LiteralPath $probeBase)) {
    Fail ("the probe base .set for " + $rev + " at first lot " + $FirstLot + " is not on disk (" + $probeBase + "). That file is what pilot_probe.ps1 swept; without it there is nothing to confirm this verification runs the same sizing the surface was produced at.")
  }
  $lotLine = @(Get-Content -LiteralPath $probeBase | Where-Object { $_ -match '^_41_FixedLot=' })
  if ($lotLine.Count -ne 1) { Fail ($probeBase + " declares _41_FixedLot " + $lotLine.Count + " time(s); exactly one is required") }
  $declared = ($lotLine[0] -split '=', 2)[1].Trim()
  if ([double]$declared -ne [double]$FirstLot) {
    Fail ("the probe for " + $rev + " swept _41_FixedLot=" + $declared + " but this verification was asked for " + $FirstLot + ". Refusing: the run would not be of the configuration the surface was searched at.")
  }
}

$ctx = New-PilotRunContext -RepoRoot $root -Terminal $Terminal -DataDir $DataDir -OutDir $OutDir `
         -FromDate $FromDate -ToDate $ToDate -Model $Model -FirstLot $FirstLot `
         -CryptoRateLong $CryptoRateLong -CryptoRateShort $CryptoRateShort
if (-not (Test-Path $Terminal)) { Fail ("terminal not found on the pinned lane: " + $Terminal) }

# --- was the selected point ever evaluated? (offline, before the tester) ---------------------------
# Answered from the surface itself so the run has a reference where one exists. Where none exists,
# that is the finding, and the record says so in the same breath as the number.
$surfaceRows = @{}
foreach ($s in $selected) {
  $j = & $py (Join-Path $PSScriptRoot 'pilot_selected_surface_row.py') $SelectionRecord '--cell' $s.cell_id
  if ($LASTEXITCODE -ne 0) { Fail ("pilot_selected_surface_row.py failed for " + $s.cell_id + ": " + ($j -join ' ')) }
  $surfaceRows[$s.cell_id] = (($j -join "`n") | ConvertFrom-Json)
}

# --- the runs ---------------------------------------------------------------------------------------
$records = New-Object System.Collections.Generic.List[object]
$rows = New-Object System.Collections.Generic.List[object]

foreach ($s in $selected) {
  $rev = $s.hypothesis_revision
  $slug = $rev -replace '-', '_'
  $wrapper = 'EALabTpl\generated\' + $slug
  $symbol = $s.logical_symbol
  $period = $s.tf
  Write-Host ""
  Write-Host (">> verify " + $s.cell_id) -ForegroundColor Cyan

  # The overrides are read from the record, never typed here.
  $ov = @()
  foreach ($k in ($s.selected.PSObject.Properties.Name | Sort-Object)) {
    $ov += ($k + '=' + $s.selected.$k)
  }
  Write-Host ("   selected: " + ($ov -join ' ')) -ForegroundColor DarkGray

  $set = Get-PilotEffectiveSet -Ctx $ctx -Revision $rev -Tag ('selected_' + ($symbol + '_' + $period)) -Overrides $ov

  # THE GENERATED .set IS READ BACK AND ASSERTED. gen_default_preset.py normalises 21.0 -> 21 for an
  # int input, so the comparison is numeric -- but an override that was silently dropped, or landed
  # on a different key, would otherwise produce a clean-looking run of the WRONG configuration, and
  # nothing downstream could tell.
  $onDisk = @{}
  foreach ($l in (Get-Content -LiteralPath $set.path)) {
    if ($l -match '^([A-Za-z_0-9]+)=([^|]*)') { $onDisk[$Matches[1]] = $Matches[2].Trim() }
  }
  # A non-numeric or empty value is REFUSED BY NAME rather than thrown at by the cast. `[double]''`
  # raises a bare conversion error whose message says nothing about which key or which cell, and an
  # unreadable value must never share an exit path with a value that disagrees.
  function Get-SetNumber([hashtable]$map, [string]$key, [string]$where) {
    if (-not $map.ContainsKey($key)) { Fail ("the generated .set " + $where + " has no line for " + $key) }
    $raw = $map[$key]
    $d = 0.0
    if (-not [double]::TryParse($raw, [ref]$d)) {
      Fail ("the generated .set " + $where + " carries " + $key + "=" + $raw + ", which is not a number. 'I could not read it' is not 'it matches'.")
    }
    return $d
  }
  foreach ($k in $s.selected.PSObject.Properties.Name) {
    if ((Get-SetNumber $onDisk $k $set.path) -ne [double]$s.selected.$k) {
      Fail ("the generated .set carries " + $k + "=" + $onDisk[$k] + " but the selection says " + $s.selected.$k + ". The run would be of a configuration nobody chose.")
    }
  }
  if ((Get-SetNumber $onDisk '_41_FixedLot' $set.path) -ne [double]$FirstLot) {
    Fail ("the generated .set carries _41_FixedLot=" + $onDisk['_41_FixedLot'] + ", not " + $FirstLot)
  }
  Write-Host ("   .set     : " + (Split-Path -Leaf $set.path) + "  hash " + $set.hash.Substring(0, 12) + " (every selected value read back and confirmed)") -ForegroundColor DarkGray

  $reportName = 'S13VERIFY_' + $slug + '_' + $symbol + '_' + $period + '_' + $Window + $ctx.LotTag
  $t0 = Get-Date
  $htm = Invoke-PilotCell -Ctx $ctx -Expert $wrapper -Symbol $symbol -Period $period -SetPath $set.path -ReportName $reportName
  $elapsed = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)

  $m = Get-PilotReportMetrics -Ctx $ctx -Htm $htm
  $pfInfo = Resolve-PilotPF -Metrics $m
  $carried = Get-PilotCarriedAtEnd -Ctx $ctx -Htm $htm
  $sr = $surfaceRows[$s.cell_id]

  $rec = [ordered]@{
    entity                = 'PilotSelectedVerification'
    cell_id               = $s.cell_id
    hypothesis_revision   = $rev
    arm                   = 'selected-verification'
    expert                = $wrapper
    logical_symbol        = $symbol
    tf                    = $period
    window                = $Window
    from_date             = $FromDate
    to_date               = $ToDate
    model                 = $Model
    first_lot             = $FirstLot
    lane                  = $Terminal
    criterion_order       = $s.criterion_order
    selection_record      = $SelectionRecord
    selected              = $s.selected
    trade_floor           = $s.trade_floor
    data_fingerprint      = (Get-PilotDataFingerprint -Ctx $ctx -Metrics $m -Symbol $symbol -Period $period)
    effective_config_hash = $set.hash
    set                   = $set.path
    report                = $htm
    run_seconds           = $elapsed
    pf                    = $pfInfo.pf
    pf_undefined          = $pfInfo.undefined
    pf_undefined_why      = $pfInfo.why
    trades                = (ConvertTo-PilotNumber $m['total_trades'])
    dd_pct                = (ConvertTo-PilotNumber $m['equity_drawdown_maximal_pct'])
    gross_profit          = (ConvertTo-PilotNumber $m['gross_profit'])
    gross_loss            = (ConvertTo-PilotNumber $m['gross_loss'])
    net_profit            = (ConvertTo-PilotNumber $m['net_profit'])
    long_trades           = (ConvertTo-PilotNumber $m['long_trades'])
    short_trades          = (ConvertTo-PilotNumber $m['short_trades'])
    bars                  = (ConvertTo-PilotNumber $m['bars'])
    ticks                 = (ConvertTo-PilotNumber $m['ticks'])
    history_quality       = $m['history_quality']
    server                = $m['company']
    carried_at_end_count  = $carried.carried_count
    carried_at_end_profit = $carried.carried_profit
    carried_at_end_why    = $carried.why
    # The surface side of the question, carried in the same record as the measurement so nobody has
    # to go and look it up to know which of the two cases this cell is.
    selected_point_evaluated_on_surface = $sr.evaluated_on_surface
    surface_reference_rows              = $sr.matching_rows
    surface_rows_total                  = $sr.surface_rows
    financing_deducted    = $null
    notes                 = @()
  }

  if ($symbol -match 'BTC|ETH') {
    $rec.financing_deducted = @{
      applied           = $true
      rate_long_pct_yr  = $CryptoRateLong
      rate_short_pct_yr = $CryptoRateShort
      tool              = 'scripts/swap_adjust_crypto.py'
      detail            = (Get-PilotCryptoFinancing -Ctx $ctx -Htm $htm)
    }
    $rec.notes += ('CRYPTO FINANCING: the tester charges POINTS-mode swap but NOT INTEREST_CURRENT, ' +
                   'so this cell is optimistic by the amount above until deducted. The PF here is ' +
                   'the TESTER PF and is NOT financing-adjusted.')
  }
  $rec.notes += ('Model ' + $Model + ' is a pulse-finding pass, NOT verdict-grade for a grid: ' +
                 'CLAUDE.md makes Model 4 mandatory for the ENGINE-EDGE class both of these ' +
                 'hypotheses carry. No verdict follows from this record.')
  if ($sr.evaluated_on_surface) {
    $rec.notes += ('THE SELECTED POINT IS A ROW THE OPTIMIZER EVALUATED (' +
                   (@($sr.matching_rows | ForEach-Object { 'pass ' + $_.pass + ': Result ' + $_.result + ', Trades ' + $_.trades }) -join '; ') +
                   '). A disagreement between that row and the measurement above is a finding about ' +
                   'the harness, not about the strategy.')
  } else {
    $rec.notes += ('THE SELECTED POINT WAS NEVER EVALUATED on the ' + $sr.surface_rows_total +
                   '-row surface it was selected from -- it is the per-dimension median snapped to ' +
                   'the grid. THIS RUN IS THE ONLY MEASURED NUMBER THAT EXISTS FOR THIS ' +
                   'CONFIGURATION, which is exactly why ORDER-1273 step 6 is not optional.')
  }
  if ($pfInfo.undefined) { $rec.notes += ('PF UNDEFINED: ' + $pfInfo.why) }
  if ($carried.carried_count -gt 0) {
    $rec.notes += ('CARRIED AT END: ' + $carried.why + ' The PF above does not include it.')
  }
  $records.Add($rec) | Out-Null
  $rows.Add([pscustomobject]@{
    cell = $s.cell_id; pf = $rec.pf; n = $rec.trades; dd = $rec.dd_pct
    undef = $pfInfo.undefined; carried = $carried.carried_profit
    surf = $(if ($sr.evaluated_on_surface) { 'row ' + $sr.matching_rows[0].pass } else { 'NOT ON SURFACE' })
    surfn = $(if ($sr.evaluated_on_surface) { $sr.matching_rows[0].trades } else { $null })
  }) | Out-Null
}

# --- output -----------------------------------------------------------------------------------------
$stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$outFile = Join-Path $verifyDir ('verification_' + $Window + $ctx.LotTag + '_' + $stamp + '.jsonl')
$sw = New-Object System.IO.StreamWriter($outFile, $false, (New-Object System.Text.UTF8Encoding($false)))
foreach ($r in $records) { $sw.WriteLine(($r | ConvertTo-Json -Depth 8 -Compress)) }
$sw.Close()

Write-Host ""
Write-Host ("=== " + $records.Count + " verification run(s) -- lane " + $Terminal + " ===") -ForegroundColor Cyan
Write-Host ""
# PF NEVER PRINTS ALONE, and the surface reference prints beside it so the reader can see at a glance
# whether there was anything to check the number against.
Write-Host ("  {0,-26} {1,10} {2,7} {3,8} {4,10}  {5,-16} {6}" -f 'cell', 'PF', 'trades', 'DD%', 'carried', 'surface ref', 'surf n')
foreach ($r in $rows) {
  $pf = if ($r.undef) { 'UNDEF' } elseif ($null -eq $r.pf) { 'n/a' } else { '{0:N2}' -f $r.pf }
  $n  = if ($null -eq $r.n)  { 'n/a' } else { '{0:N0}' -f $r.n }
  $dd = if ($null -eq $r.dd) { 'n/a' } else { '{0:N2}' -f $r.dd }
  $ca = if ($null -ne $r.carried -and $r.carried -ne 0) { '{0:N2}' -f $r.carried } else { '' }
  $sn = if ($null -eq $r.surfn) { '' } else { '{0:N0}' -f $r.surfn }
  $colour = if ($r.surf -eq 'NOT ON SURFACE' -or $r.undef -or $ca) { 'Yellow' } else { 'Gray' }
  Write-Host ("  {0,-26} {1,10} {2,7} {3,8} {4,10}  {5,-16} {6}" -f $r.cell, $pf, $n, $dd, $ca, $r.surf, $sn) -ForegroundColor $colour
}
Write-Host ""
Write-Host ("  'NOT ON SURFACE' = the selected point is a per-dimension median the optimizer never") -ForegroundColor DarkGray
Write-Host ("  evaluated, so this run is the ONLY measured number for that configuration.") -ForegroundColor DarkGray
Write-Host ("  'carried' = positions the tester force-closed at the window end. Under SL_NONE a basket") -ForegroundColor DarkGray
Write-Host ("  closes only in profit, so a carried loss NEVER enters the PF beside it.") -ForegroundColor DarkGray
Write-Host ("  PF 'UNDEF' = no losing trades at all; it is NOT 0.00.") -ForegroundColor DarkGray
Write-Host ""
Write-Host ("  records -> " + $outFile)
Write-Host ("  A PF here is a MEASUREMENT, not a verdict, and not a pass against any bar.") -ForegroundColor DarkGray
Write-Host ("  Read every PF with the trade count beside it: a bar can be cleared by not trading.") -ForegroundColor DarkGray
Write-Host ("  ORDER-1254 owns the BWD hard gate and Model 4. Nothing here substitutes for either.") -ForegroundColor DarkGray
exit 0
