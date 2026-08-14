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

CRYPTO FINANCING IS TESTER-NATIVE AND SAID OUT LOUD. The tester's Deals/Swap aggregate is retained
as provenance beside the raw tester metrics. No post-hoc estimate is applied to `net_profit`, PF,
or gross profit/loss; a swap mode alone is never treated as proof that the tester skipped financing.

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
  # ORDER-1240. Empty = use the build default, which is 0.01 and is the sizing ORDER-1230 measured
  # as INERT on all 16 cells. A value here is applied to BOTH arms of every cell, so it changes the
  # sizing under test and never the comparison. It is resolved by scripts\pilot_sizing_sweep.ps1
  # against a criterion that does not read a profit factor -- do not set it by hand to a value that
  # "looks better", because that is choosing the configuration having seen the result.
  [string]$FirstLot = '',
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
# ORDER-1273 step 6: the run mechanics moved to scripts\lib\pilot_run.ps1 so the verification of the
# SELECTED configurations calls the same code this matrix did, rather than a second copy of it. The
# functions below are FORWARDERS with no logic of their own -- they bind the context and change
# nothing else, which is why every call site in this file is untouched.
#
# ONE STATED BEHAVIOUR CHANGE: the library `throw`s where these functions used to call Fail(). Both
# end the script with exit 1 and the same message text; the throw prints as a PowerShell error with
# a position, instead of a `[FAIL] ` line on stdout. A library must not `exit` out of its caller.
. (Join-Path $PSScriptRoot 'lib\pilot_run.ps1')

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
# The first lot goes into every generated name. Without it a 0.03 run silently overwrites the 0.01
# run's .set files and reports, and the two sizings become indistinguishable on disk -- which is the
# one thing this whole ORDER-1240 comparison depends on being able to tell apart.
$ctx = New-PilotRunContext -RepoRoot $root -Terminal $Terminal -DataDir $DataDir -OutDir $OutDir `
         -FromDate $FromDate -ToDate $ToDate -Model $Model -FirstLot $FirstLot `
         -CryptoRateLong $CryptoRateLong -CryptoRateShort $CryptoRateShort
# The naming rule lives in the context now, so the verifier cannot name its artefacts by a different
# convention than this matrix did. Read back rather than recomputed here, deliberately.
$lotTag = $ctx.LotTag

# --- forwarders -------------------------------------------------------------------------------------
# Every one of these is a single call into scripts\lib\pilot_run.ps1 with the context bound. They
# carry NO logic: the composition rule, the UNDEF-not-zero rule, the carried-at-end refusals, the
# fingerprint recipe and the exit-code-before-report ordering all live in the library and exist once.
function Get-EffectiveSet([string]$rev, [string]$tag, [string[]]$overrides) {
  Get-PilotEffectiveSet -Ctx $ctx -Revision $rev -Tag $tag -Overrides $overrides
}
function Get-ReportMetrics([string]$htm) { Get-PilotReportMetrics -Ctx $ctx -Htm $htm }
function As-Num($v) { ConvertTo-PilotNumber $v }
function Resolve-PF([hashtable]$m) { Resolve-PilotPF -Metrics $m }
function Get-CarriedAtEnd([string]$htm) { Get-PilotCarriedAtEnd -Ctx $ctx -Htm $htm }
# ORDER-1330 Blocker A. Probes the SAME lane, immediately adjacent to the cell this fingerprint is
# for, and feeds the reading into -SymbolSpec so the result is v2. A probe failure does not abort
# the matrix -- Get-PilotDataFingerprintProbed falls back to v1, loudly, never silently.
function Get-DataFingerprint([hashtable]$m, [string]$symbol, [string]$period, [string]$reportTag) {
  Get-PilotDataFingerprintProbed -Ctx $ctx -Metrics $m -Symbol $symbol -Period $period -ReportTag $reportTag
}
function Get-CryptoFinancing([string]$htm) { Get-PilotCryptoFinancing -Ctx $ctx -Htm $htm }
function Invoke-Cell([string]$expert, [string]$symbol, [string]$period, [string]$setPath,
                     [string]$reportName) {
  Invoke-PilotCell -Ctx $ctx -Expert $expert -Symbol $symbol -Period $period `
                   -SetPath $setPath -ReportName $reportName
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

      $tag = $slug + '_' + $symbol + '_' + $period + '_' + $Window + $lotTag
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
        # The INDEPENDENT VARIABLE of ORDER-1240, recorded explicitly rather than left implicit in
        # the .set path and the config hash. '' means the build default (0.01), which is the sizing
        # ORDER-1230 measured as inert.
        first_lot             = $(if ($FirstLot) { $FirstLot } else { 'build-default (0.01)' })
        from_date             = $FromDate
        to_date               = $ToDate
        model                 = $Model
        lane                  = $Terminal
        data_fingerprint      = (Get-DataFingerprint $m $symbol $period ('S13CELL_' + $tag + '_baseline'))
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
          applied      = $false
          metric_basis = 'tester_native'
          tester_swap_charged = $fin.tester_swap_charged
          swap_mode_probe = (Get-PilotSwapModeProbeReference -Ctx $ctx -Symbol $symbol)
          tester_swap_extractor = 'scripts/swap_adjust_crypto.py --tester-swap-only'
          detail       = $fin.detail
        }
        $rec.notes += ('CRYPTO FINANCING: the MT5 tester Swap column is included in the stored ' +
                       'tester-native metrics. financing_deducted records the report-derived ' +
                       'tester swap for provenance; no post-hoc deduction is applied.')
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
        # 🔴 THE ESCALATED ARM OF THE COMPARISON IS RUN AGAIN, ON THE PARENT, AND THE BASELINE ABOVE
        # IS NOT REUSED FOR IT. Found by /scrutinize round 1 over this file's own first results.
        # The baseline runs the WRAPPER and the flat-lot arm must run the PARENT (LotProg is a
        # LOCKED_SELECTOR, so the wrapper cannot express it). Comparing those two directly makes
        # every pair differ in TWO variables -- the lever AND the binary -- and attributes the whole
        # difference to the lever.
        #
        # Parity does license substituting the parent for the wrapper, but only where it was
        # DEMONSTRATED: XAUUSD H1, 2024.01..2024.07, model 1, at the build-default first lot. This
        # matrix runs 2023.01..2025.12 over four symbols at a different first lot, and parity has
        # never been run there. "Parity holds for this configuration" was the claim; it is not the
        # configuration parity was measured on.
        #
        # So the comparison is now parent-vs-parent and single-variable, which is what
        # pilot_sizing_sweep.ps1 already did. The wrapper baseline stays as the CELL's evidence --
        # the pilot is validating the wrapper -- and the falsifier is judged on the probe pair.
        $htmE = Invoke-Cell $Parent $symbol $period $baseSet.path ('S13CELL_' + $tag + '_probeesc')
        $htmF = Invoke-Cell $Parent $symbol $period $flatSet.path ('S13CELL_' + $tag + '_flatlot')
        $mf = Get-ReportMetrics $htmF
        $pfInfoF = Resolve-PF $mf
        $carriedF = Get-CarriedAtEnd $htmF
        $me = Get-ReportMetrics $htmE
        $pfInfoE = Resolve-PF $me
        $carriedE = Get-CarriedAtEnd $htmE

        # The escalated side of the comparison gets its OWN record and its own row. Without it the
        # table shows a flat-lot arm next to a WRAPPER baseline and a reader compares those two --
        # which is the confound this arm exists to remove, reintroduced by the renderer.
        $recE = [ordered]@{
          entity                = 'PilotCellRun'
          cell_id               = $cellId
          hypothesis_revision   = $rev
          arm                   = 'probe-escalated'
          expert                = $Parent
          logical_symbol        = $symbol
          tf                    = $period
          window                = $Window
          first_lot             = $(if ($FirstLot) { $FirstLot } else { 'build-default (0.01)' })
          from_date             = $FromDate
          to_date               = $ToDate
          model                 = $Model
          lane                  = $Terminal
          data_fingerprint      = (Get-DataFingerprint $me $symbol $period ('S13CELL_' + $tag + '_probeesc'))
          effective_config_hash = $baseSet.hash
          set                   = $baseSet.path
          report                = $htmE
          pf                    = $pfInfoE.pf
          pf_undefined          = $pfInfoE.undefined
          trades                = (As-Num $me['total_trades'])
          dd_pct                = (As-Num $me['equity_drawdown_maximal_pct'])
          gross_profit          = (As-Num $me['gross_profit'])
          gross_loss            = (As-Num $me['gross_loss'])
          carried_at_end_count  = $carriedE.carried_count
          carried_at_end_profit = $carriedE.carried_profit
          net_profit            = (As-Num $me['net_profit'])
          notes                 = @(
            ('THE ESCALATED SIDE OF THE FALSIFIER, run on ' + $Parent + ' with the SAME effective ' +
             'config as the wrapper baseline. It exists so the probe pair is parent-vs-parent and ' +
             'differs only in LotProg. Compare THIS against the flat-lot arm -- not the wrapper ' +
             'baseline, which differs in the binary too.')
          )
        }
        $records.Add($recE) | Out-Null
        $rows.Add([pscustomobject]@{
          cell = $cellId; arm = 'probe-escalated'; pf = $recE.pf; n = $recE.trades; dd = $recE.dd_pct
          undef = $pfInfoE.undefined; carried = $carriedE.carried_profit
        }) | Out-Null
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
          data_fingerprint      = (Get-DataFingerprint $mf $symbol $period ('S13CELL_' + $tag + '_flatlot'))
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
        # $htmE, NOT $htm: parent-vs-parent, so the only difference between the two sides is LotProg.
        $cmpJson = & $py (Join-Path $root 'scripts\pilot_probe_compare.py') $htmE $htmF
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

        # /scrutinize round 3: EXERCISED is NOT the same as COMPARABLE, and the comparator says
        # "the falsifier comparison is meaningful for this cell" when it reaches that verdict.
        # It cannot know better -- it deliberately never reads a profit factor, which is what stops
        # it being talked into one. But H01's falsifier is literally "flat-lot PF >= escalated PF",
        # and USDJPY H1 has NO losing trades on either arm, so both PFs are UNDEFINED and the
        # comparison has nothing to compare even though the lever demonstrably moved. Left alone,
        # that cell reads as a fully exercised, fully answered falsifier. It is neither.
        $recF.falsifier_comparable = -not ($pfInfoE.undefined -or $pfInfoF.undefined)
        if (-not $recF.falsifier_comparable) {
          $recF.notes += ('FALSIFIER NOT COMPARABLE despite probe=' + $cmp.probe_state + ': at ' +
                          'least one arm has an UNDEFINED profit factor (no losing trades, so no ' +
                          'denominator). "flat-lot PF >= escalated PF" cannot be evaluated here. ' +
                          'The lever moved; the criterion still has nothing to read.')
          $rows.Add([pscustomobject]@{
            cell = $cellId; arm = '  ^ falsifier'; pf = $null; n = $null; dd = $null
            undef = $true; carried = $null; probe = 'NOT-COMPARABLE'
          }) | Out-Null
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
$outFile = Join-Path $OutDir ('pilot_cells_' + $Window + $lotTag + '_' + $stamp + '.jsonl')
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
# TWO COUNTERS, NOT ONE. The first version filtered on "probe is set and is not EXERCISED", which
# swept up the NOT-COMPARABLE rows and then described them with the INERT wording -- telling the
# reader that USDJPY H1's two arms are "the SAME EA" when they demonstrably differ (100 vs 99
# trades) and the real problem is that neither arm has a defined PF. One message for two distinct
# states is how a reader learns the wrong lesson from a correct warning.
$inert = @($rows | Where-Object {
  $_.PSObject.Properties.Match('probe').Count -gt 0 -and $_.probe -and
  $_.probe -ne 'EXERCISED' -and $_.probe -ne 'NOT-COMPARABLE' })
$notcmp = @($rows | Where-Object {
  $_.PSObject.Properties.Match('probe').Count -gt 0 -and $_.probe -eq 'NOT-COMPARABLE' })
if ($inert.Count -gt 0) {
  Write-Host ""
  Write-Host ("  !! " + $inert.Count + " flat-lot probe(s) are NOT EXERCISED. For those cells the two arms are the") -ForegroundColor Yellow
  Write-Host ("     SAME EA, so 'flat-lot PF >= escalated PF' is satisfied trivially and means NOTHING.") -ForegroundColor Yellow
  Write-Host ("     A mechanism with zero fires is UNTESTED -- never passed, and never falsified.") -ForegroundColor Yellow
}
if ($notcmp.Count -gt 0) {
  Write-Host ""
  Write-Host ("  !! " + $notcmp.Count + " cell(s) have an EXERCISED lever but a NON-COMPARABLE falsifier. Different") -ForegroundColor Yellow
  Write-Host ("     problem from the line above: the arms DO differ, but at least one has no losing") -ForegroundColor Yellow
  Write-Host ("     trade, so its PF has no denominator and 'flat-lot PF >= escalated PF' has nothing") -ForegroundColor Yellow
  Write-Host ("     to read. The lever moved; the criterion still cannot be evaluated.") -ForegroundColor Yellow
}
Write-Host ""
Write-Host ("  records -> " + $outFile)
Write-Host ("  A PF here is a MEASUREMENT, not a verdict, and not a pass against any bar.") -ForegroundColor DarkGray
Write-Host ("  Read every PF with the trade count beside it: a bar can be cleared by not trading.") -ForegroundColor DarkGray
exit 0
