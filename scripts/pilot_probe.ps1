<#
pilot_probe.ps1 - ORDER-1253 (slice S13). The decision-13 OPTIMIZE PROBE for the pilot cells.

WHAT THIS IS, AND WHAT IT IS NOT. Design 3.4 gives every supported cell "a real Baseline + small
optimize probe (decision 13)". The Baseline half is `pilot_cells.ps1` and it has run: all 16 cells
sit at BASELINE_RUN. This is the other half. It is NOT the flat-lot arm that pilot_cells.ps1
already ran against every cell - that arm is H01's pre-registered FALSIFIER, it answers "does the
edge live in the escalation engine or in the signal", and PROBE_DONE_STATES in
check_pilot_acceptance.py deliberately excludes BASELINE_RUN so that no one can tick 8.6 item 7
from it by accident.

THE SWEPT DIMENSIONS ARE NOT CHOSEN HERE, AND THAT IS THE POINT. They are every ParameterBinding
of the revision whose role is TUNABLE, whose `optimizable` the resolver derives as true, and which
carries a `safe_range` - read from `_triage/factory_os/registry.py`, which design 5.4 makes THE
one resolver for exactly this reason. The ranges are the store's, not this script's. ORDER-1253's
prohibition is "picking any parameter by which value gives the better PF", and the defence against
it is structural: a dimension set derived from a committed registry cannot be adjusted after seeing
a result without that adjustment being a visible edit to the store.

WHY A MISSING KEY IS A REFUSAL. A `||start||step||stop||Y` line for an input the wrapper does not
expose is a sweep of nothing: MT5 accepts it, the optimizer reports a full surface of numbers, and
the "plateau" is noise. That is failure mode 1 in optimize_guard.ps1's own header, and this script
would be manufacturing it. So every probe dimension must be present in the base .set or the cell
is refused before the tester is touched.

EVERY PASS GOES THROUGH THE GUARD, BY CONSTRUCTION. This calls mt5_optimize.ps1, which pre-flights
the .ini through optimize_guard.ps1 and (ORDER-1253) records the decision in
factory/optimize_decisions.jsonl. -DeliberateRefusal adds a SAFETY dimension to the sweep on
purpose: it is the same shape as design 8.4's deliberate-refusal parity case, it is a REAL
submission of a REAL .ini, and the guard refuses it before any tester wall-clock is spent. A guard
observed only on fixtures is UNTESTED (CLAUDE.md).

NO VERDICT. Design section 10 stops this slice at EVIDENCE_COMPLETE. This script runs a search and
records where it landed; it does not judge the EA, and it does not decide whether a cell PULSEs.

USAGE
  powershell -NoProfile -File scripts\pilot_probe.ps1 -Symbols XAUUSD -Periods H1
  powershell -NoProfile -File scripts\pilot_probe.ps1 -Symbols XAUUSD -Periods H1 -DeliberateRefusal
  (one -Symbols / -Periods value per invocation: `-File` never parses a comma-joined list)
ASCII only (PS 5.1 reads a BOM-less .ps1 as ANSI).
#>
[CmdletBinding()]
param(
  [string[]]$Symbols   = @('XAUUSD', 'EURUSD', 'USDJPY', 'BTCUSD'),
  [string[]]$Periods   = @('H1', 'H4'),
  [string[]]$Revisions = @('B14-H01-r1', 'B14-H02-r1'),
  # MAIN, and it is not a default anybody may quietly move: design 6.2's ratified search policy is
  # "search on MAIN only - BWD is never a search surface". BWD is ORDER-1254's job and it JUDGES
  # what this selects; optimizing on it would make the hard gate a second selection surface.
  [string]$FromDate    = '2023.01.01',
  [string]$ToDate      = '2025.12.31',
  [int]$Model          = 1,
  [int]$Optimization   = 2,     # 2 = genetic. Design 6.2: >1,000 combos -> genetic coarse first.
  # 1 = PF max. Design 6.2: "engine-edge uses PF + double trade floor", and both pilot hypotheses
  # carry engine_edge=true. Criterion 7 (Complex) is the default for everything else.
  [int]$Criterion      = 1,
  [string]$Terminal    = 'D:\Meta 5\terminal64.exe',
  [string]$DataDir     = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
  [int]$TimeoutSec     = 21600,
  # The lot the baseline matrix was re-run at (ORDER-1240 resolved it mechanically to 0.03: the
  # smallest first lot at which the flat-lot probe returns EXERCISED). The probe must sweep the
  # SAME configuration the baseline measured, or the two are not comparable.
  [string]$LotTag      = 'lot0p03',
  [switch]$DeliberateRefusal,
  # 🚫 -PreflightOnly WAS HERE AND IS GONE. It printed "the launcher will be invoked and is
  # expected to stop at the guard or the process check" and then invoked the launcher normally --
  # so on a FREE lane it would have run a full 11-25 minute optimization under a flag whose name
  # promises the opposite. A flag that is only safe because something else happens to be busy is
  # not a preflight. Removed rather than fixed: the guard runs INSIDE mt5_optimize.ps1, and
  # calling it separately here would make this script a second consumer of the same rule with its
  # own argument list, which is how two consumers drift apart.
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$py   = Join-Path $root 'tools\python312\python.exe'
$outDir = Join-Path $root 'factory\runs\pilot\probe'
New-Item -ItemType Directory -Force $outDir | Out-Null

function Fail { param([string]$Msg) Write-Host "REFUSED: $Msg" -ForegroundColor Red; exit 1 }

# --- the dimension set, from the ONE resolver -----------------------------------------------------
function Get-ProbeDimensions {
  param([string]$Revision)
  $resolver = Join-Path $root '_triage\factory_os\registry.py'
  $json = & $py $resolver 'resolve' $Revision '--build-tag=14'
  if ($LASTEXITCODE -ne 0) { Fail "the ParameterBinding resolver refused for ${Revision}: $($json -join ' ')" }
  $all = ($json -join '') | ConvertFrom-Json
  $dims = @()
  foreach ($p in $all.PSObject.Properties) {
    $b = $p.Value
    if ($b.role -eq 'TUNABLE' -and $b.optimizable -eq $true -and $b.safe_range) {
      $dims += [pscustomobject]@{
        Name  = $p.Name
        Start = [double]$b.safe_range.start
        Step  = [double]$b.safe_range.step
        Stop  = [double]$b.safe_range.stop
      }
    }
  }
  if ($dims.Count -eq 0) {
    # Not "nothing to sweep, carry on". A revision with no sweepable dimension cannot HAVE a
    # decision-13 probe, and reporting that as a completed probe is the shape this repo keeps
    # paying for: a checker that goes green because it could not look.
    Fail "$Revision resolves ZERO TUNABLE dimensions carrying a safe_range, so it has no decision-13 probe to run. That is a registry statement, not a search result."
  }
  return ($dims | Sort-Object Name)
}

# --- the probe .set: the cell's own config, with ranges on the pre-registered dimensions ----------
function New-ProbeSet {
  param([string]$BasePath, [object[]]$Dims, [string]$OutPath, [string]$Injected)
  if (-not (Test-Path -LiteralPath $BasePath)) { Fail "base .set not found: $BasePath (run pilot_cells.ps1 first - the probe sweeps the config the baseline measured)" }
  $lines = Get-Content -LiteralPath $BasePath
  $seen = @{}
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($l in $lines) {
    $t = $l.TrimEnd()
    $hit = $null
    foreach ($d in $Dims) { if ($t -match ('^' + [regex]::Escape($d.Name) + '=')) { $hit = $d; break } }
    if ($hit) {
      $val = ($t -split '=', 2)[1]
      # The START VALUE STAYS THE CELL'S OWN. MT5 reads the first field as the current value and
      # the four that follow as the range, so keeping it means the probe's search starts from the
      # configuration the baseline actually measured rather than from a value nobody ran.
      $out.Add(('{0}={1}||{2}||{3}||{4}||Y' -f $hit.Name, $val, $hit.Start, $hit.Step, $hit.Stop))
      $seen[$hit.Name] = $true
    }
    elseif ($Injected -and ($t -match ('^' + [regex]::Escape($Injected) + '='))) {
      $val = ($t -split '=', 2)[1]
      # DELIBERATE. A real operator adding depth "for profit" writes exactly this line.
      $out.Add(('{0}={1}||1||1||8||Y' -f $Injected, $val))
      $seen[$Injected] = $true
    }
    else { $out.Add($t) }
  }
  $missing = @($Dims | Where-Object { -not $seen.ContainsKey($_.Name) } | ForEach-Object { $_.Name })
  if ($missing.Count -gt 0) {
    Fail ("the base .set does not expose " + ($missing -join ', ') + " - a sweep on an input the wrapper does not carry produces a full surface of numbers that mean nothing (optimize_guard.ps1 failure mode 1). Refusing before the tester is touched.")
  }
  if ($Injected -and -not $seen.ContainsKey($Injected)) { Fail "the base .set does not expose $Injected, so the deliberate-refusal case would not be refused for the reason it claims" }
  [System.IO.File]::WriteAllLines($OutPath, $out, (New-Object System.Text.UTF8Encoding($false)))
}

# --- fail closed on the `powershell -File` array trap ---------------------------------------------
# `powershell -File script.ps1 -Symbols A,B,C` delivers ONE element "A,B,C" to a [string[]]
# parameter -- the comma is never parsed. MEASURED THE HARD WAY: an invocation of this script from
# bash produced a single "cell" called `B14-H01-r1/EURUSD,USDJPY,BTCUSD/H1,H4`, ran 14.4s, produced
# no optimizer XML, and was recorded as a completed probe -- while the six real cells it was meant
# to run were never attempted. The trap is already documented in
# scripts/_test/run_optimize_guard_tests.ps1's Invoke-Guard, and I walked into it anyway, which is
# the argument for a refusal rather than a comment.
foreach ($tok in ($Symbols + $Periods + $Revisions)) {
  if ($tok -match ',') {
    Fail "'$tok' contains a comma. Under ``powershell -File`` a comma-joined list arrives as ONE string, so this would run a single cell named after all of them and silently skip the rest. Use -Command, or pass one -Symbols/-Periods value per invocation."
  }
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$recordPath = Join-Path $outDir ("probe_runs_" + $stamp + ".jsonl")
Write-Host "=== pilot_probe.ps1 - the decision-13 optimize probe ===" -ForegroundColor Cyan
Write-Host "lane   : $Terminal"
Write-Host "window : $FromDate - $ToDate (MAIN; design 6.2 forbids searching on BWD)"
Write-Host "record : $recordPath"
Write-Host ""

$cells = 0
foreach ($rev in $Revisions) {
  $dims = Get-ProbeDimensions -Revision $rev
  Write-Host ("$rev probe dimensions ({0}, from the ParameterBinding store):" -f $dims.Count) -ForegroundColor Yellow
  foreach ($d in $dims) { Write-Host ("  {0,-22} {1} .. {2} step {3}" -f $d.Name, $d.Start, $d.Stop, $d.Step) }
  $baseSet = Join-Path $root ('factory\runs\pilot\effective_' + ($rev -replace '-', '_') + '_baseline_' + $LotTag + '.set')
  # DERIVED FROM THE .set, NEVER TYPED. This was the literal string '0.03' in the record while
  # -LotTag chose which file to read, and the two sets on disk carry DIFFERENT lots
  # (`_lot0p03` -> 0.03, the plain one -> 0.01). So `-LotTag baseline` would have written a record
  # claiming 0.03 for a run made at 0.01 -- and gen_pilot_cells compares exactly that field to
  # decide whether a probe belongs to a cell, so the check written to catch a mismatched
  # configuration would have been defeated by the field it reads.
  if (-not (Test-Path -LiteralPath $baseSet)) { Fail "base .set not found: $baseSet" }
  $lotLine = @(Get-Content -LiteralPath $baseSet | Where-Object { $_ -match '^_41_FixedLot=' })
  if ($lotLine.Count -ne 1) {
    Fail ("$baseSet declares _41_FixedLot " + $lotLine.Count + " time(s); exactly one is required to state the sizing this probe ran at")
  }
  $firstLot = ($lotLine[0] -split '=', 2)[1].Trim()
  $wrapper = 'EALabTpl\generated\' + ($rev -replace '-', '_')

  foreach ($symbol in $Symbols) {
    foreach ($period in $Periods) {
      $cells++
      $slug = ($rev -replace '-', '_') + '_' + $symbol + '_' + $period
      $injected = $null
      if ($DeliberateRefusal) { $injected = '_9_MaxLevels' }
      $probeSet = Join-Path $outDir ('probe_' + $slug + $(if ($injected) { '_REFUSALCASE' } else { '' }) + '.set')
      New-ProbeSet -BasePath $baseSet -Dims $dims -OutPath $probeSet -Injected $injected
      $reportName = 'S13PROBE_' + $slug + $(if ($injected) { '_REFUSALCASE' } else { '' })

      Write-Host ""
      Write-Host ("--- cell {0}/{1}/{2} ---" -f $rev, $symbol, $period) -ForegroundColor Cyan
      Write-Host ("set: $probeSet")

      # A HASHTABLE, not an array. `@array` splatting passes every element POSITIONALLY, so the
      # literal string '-Expert' bound to -Expert, $wrapper bound to -Symbol, and by the seventh
      # slot -Model was being handed the string "-FromDate". The launcher refused to bind and said
      # so; had the shifted values all happened to be type-compatible, this would have run a
      # different cell than the record claimed. Two defects on the first run of this script, and
      # the array name (`$args`, an automatic variable) was the smaller of them.
      $optArgs = @{
        Expert = $wrapper; Symbol = $symbol; Period = $period
        FromDate = $FromDate; ToDate = $ToDate; SetFile = $probeSet
        Model = $Model; Optimization = $Optimization; Criterion = $Criterion
        ReportName = $reportName; Terminal = $Terminal; DataDir = $DataDir
        TimeoutSec = $TimeoutSec
        # DECLARED, and it costs something to declare it: ORDER-671 makes a swept dimension the
        # revision does not bind a REFUSAL, not a note. That is the intended cost -- a probe that
        # claims to be evidence about B14-H01-r1 may not sweep a dial that revision never mentions.
        HypothesisRevision = $rev
        # The .ini names a generated wrapper, so the guard resolves no Boss build from it and the
        # build-inertness layer silently sits out. The pilot wrapper IS build 14 (every binding in
        # the store carries build_tag LAB_ENTRY_14), so the build is stated rather than left
        # unresolved -- an unchecked layer that prints "NOT checked" is still an unchecked layer.
        GuardBuild = 14
      }
      if ($Force) { $optArgs['Force'] = $true }
      # $LASTEXITCODE is CLEARED first, and a launcher that never ran is recorded as -1 rather
      # than inheriting the previous cell's success. On this script's first run a parameter-binding
      # failure was written into the record as `exit=0 guard_refused=False` -- a launcher that
      # never started, filed as a clean pass (memory `ps-function-returns-uncaptured-script-output`).
      # 🔴 WAIT FOR THE LANE, because the launcher RETURNS WHILE STILL HOLDING IT.
      # mt5_optimize.ps1 breaks out of its wait loop two seconds after the XML appears and does
      # not wait for the terminal to exit -- but its FIRST action is a process guard that aborts
      # with exit 2 when that terminal is running. Measured tonight: EURUSD H4 finished, MT5
      # stayed up, and the next FOUR cells aborted in 0s each. The batch reported "all six
      # attempted" and produced two. The records were honest (exit=2, xml_present=false) and
      # gen_pilot_cells excluded them, so nothing was faked -- but four cells of tester time were
      # lost to a script colliding with itself.
      $waited = 0
      while ((Get-Process terminal64 -ErrorAction SilentlyContinue |
              Where-Object { $_.Path -eq $Terminal }) -and $waited -lt 300) {
        if ($waited -eq 0) { Write-Host "waiting for the previous run to release $Terminal ..." }
        Start-Sleep -Seconds 5; $waited += 5
      }
      if ($waited -ge 300) {
        # REFUSE rather than record another exit=2 row. A junk record per cell is how a batch
        # reports six attempts and two results.
        Fail "the MT5 lane $Terminal was still held after 300s. Refusing to submit $slug into a busy lane -- the previous run has not released it, and recording another exit=2 row would turn a stuck lane into a run store full of attempts."
      }
      if ($waited -gt 0) { Write-Host "lane free after ${waited}s" }

      $prevEAP = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      $global:LASTEXITCODE = $null
      $launchError = $null
      $started = Get-Date
      try   { & (Join-Path $PSScriptRoot 'mt5_optimize.ps1') @optArgs 2>&1 | Write-Host }
      catch {
        $launchError = $_.Exception.Message
        # PRINTED, not only recorded. A launcher that threw and said nothing on the console is the
        # same silence as a launcher that was never called.
        Write-Host ("LAUNCHER THREW: " + $launchError) -ForegroundColor Red
      }
      $rc = $(if ($null -eq $LASTEXITCODE) { -1 } else { $LASTEXITCODE })
      if ($launchError) { $rc = -1 }
      $ErrorActionPreference = $prevEAP
      $elapsed = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
      $xmlPath = Join-Path $root ('_mt5_auto\optimizations\' + $reportName + '.xml')
      $xmlIsFresh = $false
      if (Test-Path -LiteralPath $xmlPath) {
        # -ge, not -gt: a run shorter than the filesystem's timestamp resolution would otherwise
        # fail its own freshness test. The window this leaves open is one clock tick, against a
        # stale file that is minutes or hours old.
        $xmlIsFresh = ((Get-Item -LiteralPath $xmlPath).LastWriteTime -ge $started)
      }

      $rec = [ordered]@{
        entity              = 'PilotProbeRun'
        cell_id             = "$rev/$symbol/$period"
        hypothesis_revision = $rev
        arm                 = $(if ($injected) { 'deliberate-refusal' } else { 'optimize-probe' })
        expert              = $wrapper
        logical_symbol      = $symbol
        tf                  = $period
        window              = 'MAIN'
        from_date           = $FromDate
        to_date             = $ToDate
        model               = $Model
        optimization        = $Optimization
        criterion           = $Criterion
        lane                = $Terminal
        first_lot           = $firstLot
        set                 = $probeSet
        dimensions          = @($dims | ForEach-Object { $_.Name })
        injected_dimension  = $injected
        launcher_exit_code  = $rc
        launcher_error      = $launchError
        elapsed_sec         = $elapsed
        # RECORDED SEPARATELY FROM THE EXIT CODE, on purpose. The launcher used to print
        # "NO XML" and exit 0, so a run that produced nothing was indistinguishable in this
        # record from one that produced a full surface. That is fixed at the source (exit 4),
        # and this field is the second, independent statement.
        #
        # 🔴 "EXISTS" IS NOT ENOUGH, AND A SMOKE RUN PROVED IT. Re-submitting a cell whose
        # launcher ABORTED (MT5 already running) still found the XML from that cell's EARLIER
        # successful run sitting at the same path, and recorded xml_present=true for a run that
        # never started. The destination is keyed on the report name, so it survives across
        # attempts. The artefact must therefore be NEWER than this attempt, or the field is a
        # statement about history rather than about this run.
        xml_present         = $xmlIsFresh
        # 3 = optimize_guard refused. Named here because "the launcher exited non-zero" and "the
        # guard refused this sweep" are different events and only one of them is evidence for 8.6.
        guard_refused       = ($rc -eq 3)
        xml                 = (Join-Path $root ('_mt5_auto\optimizations\' + $reportName + '.xml'))
        notes               = @(
          'The swept dimension set is DERIVED from factory/parameter_bindings.jsonl via registry.py; it is not chosen in this script and not chosen from any result.',
          'No verdict: design section 10 stops this slice at EVIDENCE_COMPLETE.'
        )
      }
      $enc = New-Object System.Text.UTF8Encoding($false)
      [System.IO.File]::AppendAllText($recordPath, ($rec | ConvertTo-Json -Depth 6 -Compress) + "`n", $enc)
      Write-Host ("cell recorded: exit={0} elapsed={1}s guard_refused={2}" -f $rc, $elapsed, ($rc -eq 3))
    }
  }
}

Write-Host ""
Write-Host ("=== {0} cell submission(s); records in {1} ===" -f $cells, $recordPath) -ForegroundColor Green
