<#
pilot_cells.ps1 - ORDER-1230 (slice S13). The Boss_14 H01/H02 pilot matrix, design 8.3.

WHAT IT DOES. Runs the pilot coverage cells - `XAUUSD EURUSD USDJPY BTCUSD` x `H1 H4` x the two
hypothesis revisions = 16 cells (design 8.3, decision 72) - on ONE declared lane, and writes one
JSON record per cell into factory/runs/pilot/. It issues NO verdict and computes no pass/fail
against any bar: design section 10 stops this slice at EVIDENCE_COMPLETE, and the numbers this
produces are evidence for a human to judge later.

WHY EVERY NUMBER IS PRINTED AS PF + TRADES + DRAWDOWN, ALWAYS TOGETHER. Not cosmetics, and not
this script's idea: schemas.json makes it structural - `MetricRef` REQUIRES pf, trades and dd_pct
together, with the comment "PF is unrepresentable without trades and dd_pct by construction: two
BWD-clearing hosts had 52 and 62 trades at under 2% DD while every failing host had 343-473". A
bar can be cleared by NOT PARTICIPATING (memory bar-cleared-by-non-participation), and a PF quoted
alone hides exactly that.

WHY THE FLAT-LOT PROBE RUNS ON THE PARENT AND NOT ON THE WRAPPER. `LotProg` is in
hypothesis_b14.LOCKED_SELECTORS, so the generated wrapper compiles it to a `const` and a .set
naming it is silently ignored there - which the `locked-absent` parity case demonstrated on real
runs. H01's pre-registered FALSIFIER is the flat-lot comparison ("flat-lot variant PF >= escalated
PF"), so the falsifier is NOT EXPRESSIBLE ON ITS OWN WRAPPER and has to be run parent-side, with
the wrapper's effective config plus LotProg=PROG_NONE. That substitution is only legitimate because
parity established the two sides agree on all seven points of design 5.5 under this exact
configuration; without that pass this probe would be measuring a different EA and calling it a
control. Stated here because a reader who sees "parent" in a wrapper matrix will otherwise assume
it is a mistake.

WHY THE LANE IS WRITTEN OUT AND NOT INHERITED. BTCUSD tick history differs 14x across installs
(design 8.3, memory btc-tick-data-differs-per-mt5-install) and only the primary install carries BTC
back to 2020, so a cell run on the wrong lane is a WRONG number rather than a noisy one. The lane
is a parameter with an explicit default, it is recorded in every record, and it is printed in the
header - a cross-install comparison must be impossible to make by accident.

CRYPTO FINANCING IS DEDUCTED POST-HOC AND SAID OUT LOUD. The tester charges POINTS-mode swap
(XAUUSD, verified -29.25) but NOT INTEREST_CURRENT (BTCUSD, -14.67%/yr) - memory
tester-charges-points-swap-not-interest-swap. Every BTCUSD record therefore carries
`financing_deducted` with the cost and the rate, and its `net_profit` is the ADJUSTED figure with
the raw one kept beside it. PF is left as the tester reported it and flagged, because this script
cannot recompute a profit factor from an aggregate without the per-position gross split - claiming
an adjusted PF it did not compute would be worse than naming the gap.

REQUIRES: MT5 GUI closed (mt5_run.ps1's process guard).

USAGE  powershell -NoProfile -File scripts\pilot_cells.ps1
       powershell -NoProfile -File scripts\pilot_cells.ps1 -Symbols XAUUSD -Periods H1
ASCII only (PS 5.1 reads a BOM-less .ps1 as ANSI).
#>
[CmdletBinding()]
param(
  [string[]]$Symbols   = @('XAUUSD', 'EURUSD', 'USDJPY', 'BTCUSD'),
  [string[]]$Periods   = @('H1', 'H4'),
  [string[]]$Revisions = @('B14-H01-r1', 'B14-H02-r1'),
  [string]$FromDate    = '2023.01.01',
  [string]$ToDate      = '2025.12.31',
  # The window LABEL that lands in the record. MetricRef's enum is MAIN/BWD/HOLDOUT/OTHER, and
  # CLAUDE.md pins MAIN = 2023.01-2025.12 and BWD = 2020-2022. Passing dates without moving this
  # label would file BWD numbers under MAIN, so it is validated against the enum rather than free
  # text -- but the CALLER still owns keeping the two consistent, which -Window cannot check.
  [ValidateSet('MAIN', 'BWD', 'HOLDOUT', 'OTHER')]
  [string]$Window      = 'MAIN',
  # Model 1 (1-minute OHLC). NOT a verdict-grade model for a grid: CLAUDE.md bans Model 2 as
  # evidence for grids and makes Model 4 MANDATORY for the ENGINE-EDGE class, which is what both
  # of these hypotheses are labelled. This slice stops at EVIDENCE_COMPLETE and issues no verdict,
  # so a pulse-finding pass is the right cost here -- and every record carries `model`, so nothing
  # produced under Model 1 can later be quoted as if it had been produced under Model 4.
  [int]$Model          = 1,
  [switch]$SkipFlatLotProbe,
  [string]$Parent      = 'EALabTpl\Boss_14_GridLog',
  [string]$Terminal    = 'D:\Meta 5\terminal64.exe',
  [string]$DataDir     = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
  [string]$OutDir      = '',
  # BTCUSD SYMBOL_SWAP_LONG / SYMBOL_SWAP_SHORT as annual percentage magnitudes.
  [double]$CryptoRateLong  = 14.67,
  [double]$CryptoRateShort = 0.49
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$py = Join-Path $root 'tools\python312\python.exe'
# Every python child gets utf-8 stdout. A child of the pre-commit hook inherits an ANSI pipe and
# the first non-cp1252 glyph raises UnicodeEncodeError, which surfaces as an unexplained non-zero
# exit with the cause swallowed (memory thai-output-kills-a-suite-inside-the-hook). This script is
# not in the hook today; the line costs nothing and removes the trap if it ever is.
$env:PYTHONIOENCODING = 'utf-8'
if (-not $OutDir) { $OutDir = Join-Path $root 'factory\runs\pilot' }
New-Item -ItemType Directory -Force $OutDir | Out-Null

. (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')

function Fail([string]$msg) { Write-Host ("[FAIL] " + $msg) -ForegroundColor Red; exit 1 }

Write-Host ("=== ORDER-1230 pilot matrix, design 8.3 -- " + $Window + " " + $FromDate + ".." + $ToDate + " model " + $Model + " ===") -ForegroundColor Cyan
Write-Host ("  LANE: " + $Terminal) -ForegroundColor Cyan
Write-Host ("        every record carries this lane; design 8.3 pins BTCUSD to it for its whole life") -ForegroundColor DarkGray
Write-Host ("  NO VERDICT IS ISSUED HERE -- design section 10 stops this slice at EVIDENCE_COMPLETE") -ForegroundColor DarkGray
if (-not (Test-Path $Terminal)) { Fail ("terminal not found on the pinned lane: " + $Terminal) }

# --- the effective .set per revision --------------------------------------------------------------
# One .set per revision, reused across every symbol and timeframe, because the hypothesis config is
# what the revision IS. Instrument-specific tuning is the InstrumentProfile entity's job (design
# 4.3) and this pilot deliberately does not do it -- so a weak cell here means "this config on this
# symbol", never "this symbol cannot work", and the records say so.
function Get-EffectiveSet([string]$rev, [string]$tag, [string[]]$overrides) {
  $setFile = Join-Path $OutDir ('effective_' + ($rev -replace '-', '_') + '_' + $tag + '.set')
  $pins = & $py -c @"
import sys, os, io
sys.path.insert(0, r'$root\_triage\factory_os')
import hypothesis_b14 as HB
hyp = HB.HYPOTHESES['$rev'.rsplit('-r', 1)[0]]
for k, v in sorted(hyp['config'].items()):
    sys.stdout.write('%s=%s\n' % (k, v))
"@
  if ($LASTEXITCODE -ne 0) { Fail ("could not read the pinned config for " + $rev + ": " + ($pins -join ' ')) }
  $eff = [ordered]@{}
  foreach ($p in $pins) { if ($p.Trim()) { $kv = $p.Trim() -split '=', 2; $eff[$kv[0]] = $kv[1] } }
  # Merged into ONE map before the compiler sees it, override winning. Appending both lists makes a
  # key appear twice in the same layer and compile_preset refuses it by name -- correctly, because
  # rank exists BETWEEN layers, not inside one (the same trap parity_run.ps1 records).
  foreach ($o in $overrides) { $kv = $o -split '=', 2; $eff[$kv[0]] = $kv[1] }
  $genArgs = @((Join-Path $root '_triage\factory_os\gen_default_preset.py'), '--build', 'LAB_ENTRY_14', '--out', $setFile)
  foreach ($k in $eff.Keys) { $genArgs += @('--override', ($k + '=' + $eff[$k])) }
  $out = & $py $genArgs
  if ($LASTEXITCODE -ne 0) { Fail ("gen_default_preset.py refused for " + $rev + "/" + $tag + ": " + ($out -join ' ')) }
  # @() around the filter: `(... | Where-Object {...})[0]` returns a [char] when exactly one line
  # matches, because it indexes into the string instead of the collection. It fails EVERY time,
  # not intermittently (memory powershell-pipeline-count-null-on-single-result).
  $hashLine = @($out | Where-Object { $_ -like 'expected_hash=*' })
  if ($hashLine.Count -ne 1) { Fail ("gen_default_preset.py printed " + $hashLine.Count + " expected_hash lines for " + $rev + "/" + $tag + "; exactly one is required to identify the config") }
  return @{ path = $setFile; hash = ($hashLine[0] -replace 'expected_hash=', '') }
}

# --- report -> metrics ----------------------------------------------------------------------------
# Parsed by scripts/parse_mt5_report.py, which already owns this format. A second parser here would
# be a second reader of the same artifact, free to drift from the first
# (memory guard-checks-the-wrong-surface).
function Get-ReportMetrics([string]$htm) {
  $lines = & $py (Join-Path $root 'scripts\parse_mt5_report.py') $htm
  if ($LASTEXITCODE -ne 0) { Fail ("parse_mt5_report.py failed on " + $htm) }
  $m = @{}
  foreach ($l in $lines) {
    if ($l -match '^\s*([a-z_0-9]+):\s*(.*)$') { $m[$Matches[1]] = $Matches[2].Trim() }
  }
  return $m
}

function As-Num($v) {
  if ($null -eq $v -or "$v" -eq '') { return $null }
  $d = 0.0
  if ([double]::TryParse(("$v" -replace '[^0-9\.\-]', ''), [ref]$d)) { return $d }
  return $null
}

# 🔴 PF IS UNDEFINED, NOT ZERO, WHEN THERE ARE NO LOSING TRADES, and the first run of this matrix
# printed `PF 0.00` for USDJPY H1 -- a cell with 99 trades, 99 winners and gross_loss = 0. MT5
# leaves the field empty/zero because gross_profit/gross_loss divides by zero; rendering that as
# 0.00 reports the single best win rate in the matrix as the single worst result in it. Exactly
# inverted, and it would have been quoted from the table by anyone who did not open the report.
# So the undefined case is recorded as $null with its reason, never as a number.
function Resolve-PF([hashtable]$m) {
  $gl = As-Num $m['gross_loss']
  $pf = As-Num $m['profit_factor']
  $tr = As-Num $m['total_trades']
  if ($null -ne $gl -and $gl -eq 0 -and $null -ne $tr -and $tr -gt 0) {
    return @{ pf = $null; undefined = $true
              why = ('PF is UNDEFINED, not 0: gross_loss is 0 across ' + $tr + ' trade(s), so the ' +
                     'ratio has no denominator. The tester prints 0 here and that reads as the ' +
                     'exact opposite of what happened.') }
  }
  return @{ pf = $pf; undefined = $false; why = $null }
}

# Positions the tester force-closed when the window ended. Under SL_NONE + a money-denominated
# basket TP a basket closes only in profit, so an unresolved one is simply carried -- and its loss
# is NOT part of the closed-trade statistics the report's PF is computed from. Measured on the
# first matrix run: XAUUSD H1 carried -433.34 that its PF of 3.05 does not see. Reporting PF
# without this number beside it overstates every cell that carries one.
function Get-CarriedAtEnd([string]$htm) {
  $out = & $py (Join-Path $root 'scripts\pilot_carried.py') $htm
  if ($LASTEXITCODE -ne 0) { Fail ("pilot_carried.py failed on " + $htm) }
  return (($out -join "`n") | ConvertFrom-Json)
}

# design 6.4: data_fingerprint = hash(lane . symbol . tf . from . to . model . bars . ticks .
# server . Bases\ state marker). The Bases\ marker is NOT included and that is stated rather than
# quietly dropped: nothing in this repo computes it yet, and a fingerprint that silently omits a
# declared component would claim more identity than it has. bars/ticks/company come from the report
# itself, so two runs over different history produce different fingerprints, which is the property
# the cross-install rule actually needs.
function Get-DataFingerprint([hashtable]$m, [string]$symbol, [string]$period) {
  $parts = @($Terminal, $symbol, $period, $FromDate, $ToDate, "model=$Model",
             ("bars=" + $m['bars']), ("ticks=" + $m['ticks']), ("server=" + $m['company']))
  $joined = ($parts -join '|')
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($joined))
  $sha.Dispose()
  return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Get-CryptoFinancing([string]$htm) {
  $out = & $py (Join-Path $root 'scripts\swap_adjust_crypto.py') `
            '--rate-long' $CryptoRateLong '--rate-short' $CryptoRateShort $htm
  if ($LASTEXITCODE -ne 0) { Fail ("swap_adjust_crypto.py failed on " + $htm + ": " + ($out -join ' ')) }
  return ($out -join "`n")
}

# --- one tester pass ------------------------------------------------------------------------------
function Invoke-Cell([string]$expert, [string]$symbol, [string]$period, [string]$setPath,
                     [string]$reportName) {
  $runStart = Get-Date
  & (Join-Path $PSScriptRoot 'mt5_run.ps1') -Expert $expert -Symbol $symbol -Period $period `
      -FromDate $FromDate -ToDate $ToDate -SetFile $setPath -Model $Model `
      -ReportName $reportName -Terminal $Terminal -DataDir $DataDir | Out-Null
  $rc = $LASTEXITCODE
  # THE EXIT CODE IS CHECKED BEFORE THE REPORT. An aborted run (mt5_run refuses while the GUI holds
  # the install, exit 2) leaves the PREVIOUS report in place, and "the .htm exists" would then read
  # last week's numbers as this cell's. "I could not run it" and "it produced this" must never
  # share an exit path.
  if ($rc -ne 0) { Fail ("cell " + $symbol + " " + $period + " (" + $expert + "): mt5_run.ps1 exited " + $rc + " -- the tester did not produce this run, so NOTHING is known about this cell.") }
  $htm = Join-Path $root ('_mt5_auto\reports\' + $reportName + '.htm')
  if (-not (Test-ReportIsFresh -Htm $htm -RunStart $runStart -RunnerExit $rc -Label $reportName)) {
    Fail ("cell " + $symbol + " " + $period + ": the report at " + $htm + " is not evidence from THIS run (absent, or written before it started).")
  }
  return $htm
}

# --- the matrix -----------------------------------------------------------------------------------
$records = New-Object System.Collections.Generic.List[object]
$rows = New-Object System.Collections.Generic.List[object]

foreach ($rev in $Revisions) {
  $slug = $rev -replace '-', '_'
  $wrapper = 'EALabTpl\generated\' + $slug
  $baseSet = Get-EffectiveSet $rev 'baseline' @()
  # PROG_NONE = 50 ("None (same lot)") in ENUM_LOT_PROGRESSION, Inputs.mqh line 102. This is the
  # flat-lot arm of the pre-registered falsifier, not a tuning choice.
  $flatSet = Get-EffectiveSet $rev 'flatlot' @('LotProg=PROG_NONE')

  foreach ($symbol in $Symbols) {
    foreach ($period in $Periods) {
      $cellId = $rev + '/' + $symbol + '/' + $period
      Write-Host ""
      Write-Host (">> cell " + $cellId) -ForegroundColor Cyan

      $tag = $slug + '_' + $symbol + '_' + $period + '_' + $Window
      $htm = Invoke-Cell $wrapper $symbol $period $baseSet.path ('S13CELL_' + $tag + '_baseline')
      $m = Get-ReportMetrics $htm
      $pfInfo = Resolve-PF $m
      $carried = Get-CarriedAtEnd $htm

      $rec = [ordered]@{
        entity                = 'PilotCellRun'
        cell_id               = $cellId
        hypothesis_revision   = $rev
        arm                   = 'baseline'
        expert                = $wrapper
        logical_symbol        = $symbol
        tf                    = $period
        window                = $Window
        from_date             = $FromDate
        to_date               = $ToDate
        model                 = $Model
        lane                  = $Terminal
        data_fingerprint      = (Get-DataFingerprint $m $symbol $period)
        effective_config_hash = $baseSet.hash
        set                   = $baseSet.path
        report                = $htm
        pf                    = $pfInfo.pf
        pf_undefined          = $pfInfo.undefined
        pf_undefined_why      = $pfInfo.why
        trades                = (As-Num $m['total_trades'])
        dd_pct                = (As-Num $m['equity_drawdown_maximal_pct'])
        gross_profit          = (As-Num $m['gross_profit'])
        gross_loss            = (As-Num $m['gross_loss'])
        carried_at_end_count  = $carried.carried_count
        carried_at_end_profit = $carried.carried_profit
        carried_at_end_why    = $carried.why
        net_profit            = (As-Num $m['net_profit'])
        net_profit_raw        = (As-Num $m['net_profit'])
        long_trades           = (As-Num $m['long_trades'])
        short_trades          = (As-Num $m['short_trades'])
        bars                  = (As-Num $m['bars'])
        ticks                 = (As-Num $m['ticks'])
        history_quality       = $m['history_quality']
        server                = $m['company']
        financing_deducted    = $null
        notes                 = @()
      }

      if ($symbol -match 'BTC|ETH') {
        $fin = Get-CryptoFinancing $htm
        $rec.financing_deducted = @{
          applied      = $true
          rate_long_pct_yr  = $CryptoRateLong
          rate_short_pct_yr = $CryptoRateShort
          tool         = 'scripts/swap_adjust_crypto.py'
          detail       = $fin
        }
        $rec.notes += ('CRYPTO FINANCING: the tester charges POINTS-mode swap but NOT ' +
                       'INTEREST_CURRENT, so this cell is optimistic by the amount above until ' +
                       'deducted. PF as printed is the TESTER PF and is NOT financing-adjusted -- ' +
                       'recomputing it needs the per-position gross split, which this script does ' +
                       'not have.')
      }
      $rec.notes += ('Model ' + $Model + ' is a pulse-finding pass, NOT verdict-grade for a grid: ' +
                     'CLAUDE.md makes Model 4 mandatory for the ENGINE-EDGE class both of these ' +
                     'hypotheses carry.')
      $records.Add($rec) | Out-Null

      if ($pfInfo.undefined) { $rec.notes += ('PF UNDEFINED: ' + $pfInfo.why) }
      if ($carried.carried_count -gt 0) {
        $rec.notes += ('CARRIED AT END: ' + $carried.why + ' The PF above does not include it.')
      }

      $rows.Add([pscustomobject]@{
        cell = $cellId; arm = 'baseline'; pf = $rec.pf; n = $rec.trades; dd = $rec.dd_pct
        undef = $pfInfo.undefined; carried = $carried.carried_profit
      }) | Out-Null

      if (-not $SkipFlatLotProbe) {
        # PARENT-SIDE, and legitimate only because parity holds -- see the header.
        $htmF = Invoke-Cell $Parent $symbol $period $flatSet.path ('S13CELL_' + $tag + '_flatlot')
        $mf = Get-ReportMetrics $htmF
        $pfInfoF = Resolve-PF $mf
        $carriedF = Get-CarriedAtEnd $htmF
        $recF = [ordered]@{
          entity                = 'PilotCellRun'
          cell_id               = $cellId
          hypothesis_revision   = $rev
          arm                   = 'flat-lot-probe'
          expert                = $Parent
          logical_symbol        = $symbol
          tf                    = $period
          window                = $Window
          from_date             = $FromDate
          to_date               = $ToDate
          model                 = $Model
          lane                  = $Terminal
          data_fingerprint      = (Get-DataFingerprint $mf $symbol $period)
          effective_config_hash = $flatSet.hash
          set                   = $flatSet.path
          report                = $htmF
          pf                    = $pfInfoF.pf
          pf_undefined          = $pfInfoF.undefined
          pf_undefined_why      = $pfInfoF.why
          trades                = (As-Num $mf['total_trades'])
          dd_pct                = (As-Num $mf['equity_drawdown_maximal_pct'])
          gross_profit          = (As-Num $mf['gross_profit'])
          gross_loss            = (As-Num $mf['gross_loss'])
          carried_at_end_count  = $carriedF.carried_count
          carried_at_end_profit = $carriedF.carried_profit
          net_profit            = (As-Num $mf['net_profit'])
          long_trades           = (As-Num $mf['long_trades'])
          short_trades          = (As-Num $mf['short_trades'])
          bars                  = (As-Num $mf['bars'])
          ticks                 = (As-Num $mf['ticks'])
          history_quality       = $mf['history_quality']
          server                = $mf['company']
          notes                 = @(
            ('PARENT-SIDE BY NECESSITY: LotProg is a LOCKED_SELECTOR, so the wrapper compiles it ' +
             'to a const and cannot express its own falsifier. Run on ' + $Parent + ' with the ' +
             'wrapper effective config + LotProg=PROG_NONE. Comparable only because parity holds ' +
             'on all seven points of design 5.5 for this configuration.'),
            'This is the FALSIFIER ARM of the pre-registration, not a tuning result. It is not a verdict.'
          )
        }

        # DID THE PROBE PROBE ANYTHING? Asked before the two PFs are allowed to sit next to each
        # other. H01's falsifier reads "flat-lot PF >= escalated PF", and two arms that are the
        # SAME EA satisfy it trivially -- which is how a mechanism that never ran gets written up
        # as a falsified claim. pilot_probe_compare.py compares the TRADE LISTS, because identical
        # PF with different lists is two strategies agreeing on one window while identical lists is
        # the lever doing nothing, and only the second is inertness.
        $cmpJson = & $py (Join-Path $root 'scripts\pilot_probe_compare.py') $htm $htmF
        if ($LASTEXITCODE -ne 0) { Fail ("pilot_probe_compare.py failed for " + $cellId) }
        $cmp = ($cmpJson -join "`n") | ConvertFrom-Json
        $recF.probe_state = $cmp.probe_state
        $recF.probe_why = $cmp.why
        $recF.escalated_distinct_volumes = $cmp.escalated_distinct_volumes
        $recF.escalated_deepest_level = $cmp.escalated_deepest_level
        if ($cmp.probe_state -ne 'EXERCISED') {
          $recF.notes += ('PROBE ' + $cmp.probe_state + ' -- the falsifier CANNOT be evaluated ' +
                          'from this pair. ' + $cmp.why)
        }

        $records.Add($recF) | Out-Null
        # undef/carried carried onto THIS row too. Without them the flat-lot arm of USDJPY H1
        # printed `n/a` beside a baseline printing `UNDEF` -- the same fact rendered two ways, one
        # of which reads as "not measured" rather than "no losing trades". Two spellings of one
        # state is how a table starts lying quietly.
        $rows.Add([pscustomobject]@{
          cell = $cellId; arm = 'flat-lot'; pf = $recF.pf; n = $recF.trades; dd = $recF.dd_pct
          undef = $pfInfoF.undefined; carried = $carriedF.carried_profit
          probe = $cmp.probe_state
        }) | Out-Null
      }
    }
  }
}

# --- output ---------------------------------------------------------------------------------------
$stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$outFile = Join-Path $OutDir ('pilot_cells_' + $Window + '_' + $stamp + '.jsonl')
$sw = New-Object System.IO.StreamWriter($outFile, $false, (New-Object System.Text.UTF8Encoding($false)))
foreach ($r in $records) { $sw.WriteLine(($r | ConvertTo-Json -Depth 8 -Compress)) }
$sw.Close()

Write-Host ""
# @() around the filter before .Count. `(pipeline).Count` is $null when EXACTLY ONE item matches,
# because it indexes into the item instead of a collection -- the same trap this file warns about
# up in Get-EffectiveSet, hit here on the first smoke run with a single cell. It printed an empty
# count rather than failing, which is why it is worth the wrapper and not a mental note.
$cellCount = @($rows | Where-Object { $_.arm -eq 'baseline' }).Count
Write-Host ("=== " + $records.Count + " run(s) over " + $cellCount + " cell(s) -- lane " + $Terminal + " ===") -ForegroundColor Cyan
Write-Host ""
# PF NEVER PRINTS ALONE. See the header.
# Alignment is {n,width} with a NEGATIVE width for left -- `{2,>8}` is not .NET format syntax and
# throws "Input string was not in a correct format" AFTER every tester run has already been paid
# for, which is the most expensive place to put a formatting bug.
Write-Host ("  {0,-28} {1,-14} {2,10} {3,7} {4,8} {5,10}  {6}" -f 'cell', 'arm', 'PF', 'trades', 'DD%', 'carried', 'probe')
foreach ($r in $rows) {
  # An undefined PF prints as the WORD, never as a number. See Resolve-PF.
  $undef = ($r.PSObject.Properties.Match('undef').Count -gt 0 -and $r.undef)
  $pf = if ($undef) { 'UNDEF' } elseif ($null -eq $r.pf) { 'n/a' } else { '{0:N2}' -f $r.pf }
  $n  = if ($null -eq $r.n)  { 'n/a' } else { '{0:N0}' -f $r.n }
  $dd = if ($null -eq $r.dd) { 'n/a' } else { '{0:N2}' -f $r.dd }
  $ca = if ($r.PSObject.Properties.Match('carried').Count -gt 0 -and $null -ne $r.carried -and $r.carried -ne 0) { '{0:N2}' -f $r.carried } else { '' }
  # -Property is required: a baseline row has no `probe` member at all, and reading a missing
  # property under StrictMode is an error rather than $null.
  $pr = if ($r.PSObject.Properties.Match('probe').Count -gt 0 -and $r.probe) { $r.probe } else { '' }
  $colour = if (($pr -and $pr -ne 'EXERCISED') -or $undef -or $ca) { 'Yellow' } else { 'Gray' }
  Write-Host ("  {0,-28} {1,-14} {2,10} {3,7} {4,8} {5,10}  {6}" -f $r.cell, $r.arm, $pf, $n, $dd, $ca, $pr) -ForegroundColor $colour
}
Write-Host ""
Write-Host ("  PF 'UNDEF' = no losing trades at all, so the ratio has no denominator. It is NOT 0.00,") -ForegroundColor DarkGray
Write-Host ("  and the tester printing 0 there is the single most invertible number in this table.") -ForegroundColor DarkGray
Write-Host ("  'carried' = positions the tester force-closed at the window end. Under SL_NONE a basket") -ForegroundColor DarkGray
Write-Host ("  closes only in profit, so a carried loss NEVER enters the PF beside it.") -ForegroundColor DarkGray
$inert = @($rows | Where-Object { $_.PSObject.Properties.Match('probe').Count -gt 0 -and $_.probe -and $_.probe -ne 'EXERCISED' })
if ($inert.Count -gt 0) {
  Write-Host ""
  Write-Host ("  !! " + $inert.Count + " flat-lot probe(s) are NOT EXERCISED. For those cells the two arms are the") -ForegroundColor Yellow
  Write-Host ("     SAME EA, so 'flat-lot PF >= escalated PF' is satisfied trivially and means NOTHING.") -ForegroundColor Yellow
  Write-Host ("     A mechanism with zero fires is UNTESTED -- never passed, and never falsified.") -ForegroundColor Yellow
}
Write-Host ""
Write-Host ("  records -> " + $outFile)
Write-Host ("  A PF here is a MEASUREMENT, not a verdict, and not a pass against any bar.") -ForegroundColor DarkGray
Write-Host ("  Read every PF with the trade count beside it: a bar can be cleared by not trading.") -ForegroundColor DarkGray
exit 0
