<#
pilot_run.ps1 - the shared mechanics of "run one pilot tester pass and read what came back".

WHY THIS EXISTS (ORDER-1273 step 6, 2026-08-04)
  ORDER-1273 selected a configuration per cell from a Model-1 MAIN search surface. A per-dimension
  median need not correspond to ANY row that was actually evaluated, so the selected numbers have to
  be RUN before they can be handed to ORDER-1254 -- otherwise the figure passed on is interpolated
  rather than measured.

  That verification run needs exactly what scripts\pilot_cells.ps1 already had inline: the pinned
  hypothesis config -> gen_default_preset.py path, the mt5_run.ps1 + freshness path, and the
  parse_mt5_report.py path. Re-typing any of them in a second script is how two readers of the same
  artifact drift apart (memory guard-checks-the-wrong-surface), so they live here and BOTH scripts
  dot-source them.

  THE SCOPE OF THE EXTRACTION IS DELIBERATELY THE WHOLE HELPER LAYER, not the three functions the
  order named. A verifier that shared only those three would still have to re-implement:
     * Resolve-PilotPF        - PF is UNDEFINED, not 0, when gross_loss is 0. The tester prints 0
                                and that reads as the exact inverse of what happened.
     * Get-PilotCarriedAtEnd  - under SL_NONE a basket closes only in profit, so a carried loss is
                                never inside the PF printed beside it.
     * Get-PilotCryptoFinancing - the tester charges POINTS-mode swap but not INTEREST_CURRENT, and
                                BTCUSD is the only symbol these two verifications run on.
  Those are the three rules in this file that were each paid for with a wrong number in a table.
  Sharing the plumbing and copying the judgement would have shared the cheap half.

DELIBERATELY INERT TOWARD THE CALLER (same contract as report_freshness.ps1)
  No Set-StrictMode, no $ErrorActionPreference, no output on import, and no global state. Every
  function takes an explicit context built by New-PilotRunContext, so nothing here reads a variable
  that happens to exist in the host script's scope. That is the property that makes the extraction
  checkable: the functions are pure with respect to everything except the files they name.

  FAILURES `throw`; they do not `exit`. A dot-sourced `exit` would kill the host script from inside
  a library, which is invisible at the call site. The caller decides what a failure means.

  $PSScriptRoot IS NOT USED to locate sibling scripts. Inside a dot-sourced file it resolves to
  scripts\lib, not scripts\, so `Join-Path $PSScriptRoot 'mt5_run.ps1'` would silently point at a
  path that does not exist. Every sibling is resolved from the context's RepoRoot instead.

ASCII only (PS 5.1 reads a BOM-less .ps1 as ANSI).
#>

# --- the context ----------------------------------------------------------------------------------
# One object, built once, carrying every dependency the helpers below have. It exists so that a
# reader can see the entire input surface of this library in one place -- the previous inline
# versions closed over eleven script-scope variables, and "which globals does this need" was only
# answerable by reading all of them.
function New-PilotRunContext {
  param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$Terminal,
    [Parameter(Mandatory)][string]$DataDir,
    [Parameter(Mandatory)][string]$OutDir,
    [Parameter(Mandatory)][string]$FromDate,
    [Parameter(Mandatory)][string]$ToDate,
    [Parameter(Mandatory)][int]$Model,
    # '' means "use the build default", which is 0.01. Kept as a string rather than a double so the
    # empty case stays distinguishable from 0 and so the tag below matches what the caller typed.
    [AllowEmptyString()][string]$FirstLot = '',
    [double]$CryptoRateLong = 14.67,
    [double]$CryptoRateShort = 0.49
  )
  # The first lot goes into every generated name. Without it a 0.03 run silently overwrites the 0.01
  # run's .set files and reports, and the two sizings become indistinguishable on disk -- which is
  # the one thing the ORDER-1240 comparison depends on being able to tell apart. ONE rule, here, so
  # the verifier cannot name its artefacts by a different convention than the matrix did.
  $lotTag = if ($FirstLot) { '_lot' + ($FirstLot -replace '\.', 'p') } else { '' }
  return @{
    RepoRoot        = $RepoRoot
    Python          = (Join-Path $RepoRoot 'tools\python312\python.exe')
    ScriptDir       = (Join-Path $RepoRoot 'scripts')
    FactoryOsDir    = (Join-Path $RepoRoot '_triage\factory_os')
    Terminal        = $Terminal
    DataDir         = $DataDir
    OutDir          = $OutDir
    FromDate        = $FromDate
    ToDate          = $ToDate
    Model           = $Model
    FirstLot        = $FirstLot
    LotTag          = $lotTag
    CryptoRateLong  = $CryptoRateLong
    CryptoRateShort = $CryptoRateShort
  }
}

# --- the effective .set per revision ----------------------------------------------------------------
# The pinned hypothesis config, plus the caller's overrides, compiled by gen_default_preset.py --
# which owns the preset format and is the ONLY generator. This function owns the COMPOSITION rule
# (pinned config -> first lot -> overrides, last writer wins) and that rule is what would drift if
# it were typed twice.
function Get-PilotEffectiveSet {
  param(
    [Parameter(Mandatory)][hashtable]$Ctx,
    [Parameter(Mandatory)][string]$Revision,
    [Parameter(Mandatory)][string]$Tag,
    [string[]]$Overrides = @()
  )
  $root = $Ctx.RepoRoot
  $py = $Ctx.Python
  $setFile = Join-Path $Ctx.OutDir ('effective_' + ($Revision -replace '-', '_') + '_' + $Tag + $Ctx.LotTag + '.set')
  $pins = & $py -c @"
import sys, os, io
sys.path.insert(0, r'$root\_triage\factory_os')
import hypothesis_b14 as HB
hyp = HB.HYPOTHESES['$Revision'.rsplit('-r', 1)[0]]
for k, v in sorted(hyp['config'].items()):
    sys.stdout.write('%s=%s\n' % (k, v))
"@
  if ($LASTEXITCODE -ne 0) { throw ("could not read the pinned config for " + $Revision + ": " + ($pins -join ' ')) }
  $eff = [ordered]@{}
  foreach ($p in $pins) { if ($p.Trim()) { $kv = $p.Trim() -split '=', 2; $eff[$kv[0]] = $kv[1] } }
  # Applied BEFORE the per-case overrides, so a caller that deliberately names _41_FixedLot in its
  # override list still wins. That ordering is the reason a verification at the swept lot and a
  # matrix run at the same lot produce the same bytes.
  if ($Ctx.FirstLot) { $eff['_41_FixedLot'] = $Ctx.FirstLot }
  # Merged into ONE map before the compiler sees it, override winning. Appending both lists makes a
  # key appear twice in the same layer and compile_preset refuses it by name -- correctly, because
  # rank exists BETWEEN layers, not inside one (the same trap parity_run.ps1 records).
  foreach ($o in $Overrides) { $kv = $o -split '=', 2; $eff[$kv[0]] = $kv[1] }
  $genArgs = @((Join-Path $Ctx.FactoryOsDir 'gen_default_preset.py'), '--build', 'LAB_ENTRY_14', '--out', $setFile)
  foreach ($k in $eff.Keys) { $genArgs += @('--override', ($k + '=' + $eff[$k])) }
  $out = & $py $genArgs
  if ($LASTEXITCODE -ne 0) { throw ("gen_default_preset.py refused for " + $Revision + "/" + $Tag + ": " + ($out -join ' ')) }
  # @() around the filter: `(... | Where-Object {...})[0]` returns a [char] when exactly one line
  # matches, because it indexes into the string instead of the collection. It fails EVERY time,
  # not intermittently (memory powershell-pipeline-count-null-on-single-result).
  $hashLine = @($out | Where-Object { $_ -like 'expected_hash=*' })
  if ($hashLine.Count -ne 1) { throw ("gen_default_preset.py printed " + $hashLine.Count + " expected_hash lines for " + $Revision + "/" + $Tag + "; exactly one is required to identify the config") }
  return @{ path = $setFile; hash = ($hashLine[0] -replace 'expected_hash=', '') }
}

# --- report -> metrics ------------------------------------------------------------------------------
# Parsed by scripts/parse_mt5_report.py, which already owns this format. A second parser here would
# be a second reader of the same artifact, free to drift from the first
# (memory guard-checks-the-wrong-surface).
function Get-PilotReportMetrics {
  param(
    [Parameter(Mandatory)][hashtable]$Ctx,
    [Parameter(Mandatory)][string]$Htm
  )
  $lines = & $Ctx.Python (Join-Path $Ctx.ScriptDir 'parse_mt5_report.py') $Htm
  if ($LASTEXITCODE -ne 0) { throw ("parse_mt5_report.py failed on " + $Htm) }
  $m = @{}
  foreach ($l in $lines) {
    if ($l -match '^\s*([a-z_0-9]+):\s*(.*)$') { $m[$Matches[1]] = $Matches[2].Trim() }
  }
  return $m
}

function ConvertTo-PilotNumber {
  param([Parameter(Position = 0)]$Value)
  if ($null -eq $Value -or "$Value" -eq '') { return $null }
  $d = 0.0
  if ([double]::TryParse(("$Value" -replace '[^0-9\.\-]', ''), [ref]$d)) { return $d }
  return $null
}

# PF IS UNDEFINED, NOT ZERO, WHEN THERE ARE NO LOSING TRADES, and the first run of the pilot matrix
# printed `PF 0.00` for USDJPY H1 -- a cell with 99 trades, 99 winners and gross_loss = 0. MT5
# leaves the field empty/zero because gross_profit/gross_loss divides by zero; rendering that as
# 0.00 reports the single best win rate in the matrix as the single worst result in it. Exactly
# inverted, and it would have been quoted from the table by anyone who did not open the report.
# So the undefined case is recorded as $null with its reason, never as a number.
function Resolve-PilotPF {
  param([Parameter(Mandatory)][hashtable]$Metrics)
  $gl = ConvertTo-PilotNumber $Metrics['gross_loss']
  $pf = ConvertTo-PilotNumber $Metrics['profit_factor']
  $tr = ConvertTo-PilotNumber $Metrics['total_trades']
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
function Get-PilotCarriedAtEnd {
  param(
    [Parameter(Mandatory)][hashtable]$Ctx,
    [Parameter(Mandatory)][string]$Htm
  )
  $out = & $Ctx.Python (Join-Path $Ctx.ScriptDir 'pilot_carried.py') $Htm
  if ($LASTEXITCODE -ne 0) { throw ("pilot_carried.py failed on " + $Htm) }
  $c = ($out -join "`n") | ConvertFrom-Json
  # The tool COUNTS rows it could not parse and an earlier caller was discarding the count. A
  # carried figure that silently dropped rows understates exactly the loss it exists to reveal --
  # and it understates it in the flattering direction, which is the direction nobody audits. Two
  # ways it must not pass quietly:
  if (-not $c.readable) {
    throw ("pilot_carried.py could not read the Deals table of " + $Htm + " -- 'no carried positions' and 'I could not look' are different facts and this cell must not be recorded as if they were the same.")
  }
  if ($c.unparsed_rows -gt 0) {
    throw ("pilot_carried.py could not parse the profit of " + $c.unparsed_rows + " force-closed row(s) in " + $Htm + ". The carried total would be understated by an unknown amount, so it is refused rather than reported.")
  }
  return $c
}

# design 6.4: data_fingerprint = hash(lane . symbol . tf . from . to . model . bars . ticks .
# server . Bases\ state marker). The Bases\ marker is NOT included and that is stated rather than
# quietly dropped: nothing in this repo computes it yet, and a fingerprint that silently omits a
# declared component would claim more identity than it has. bars/ticks/company come from the report
# itself, so two runs over different history produce different fingerprints, which is the property
# the cross-install rule actually needs.
function Get-PilotDataFingerprint {
  param(
    [Parameter(Mandatory)][hashtable]$Ctx,
    [Parameter(Mandatory)][hashtable]$Metrics,
    [Parameter(Mandatory)][string]$Symbol,
    [Parameter(Mandatory)][string]$Period
  )
  $parts = @($Ctx.Terminal, $Symbol, $Period, $Ctx.FromDate, $Ctx.ToDate, ("model=" + $Ctx.Model),
             ("bars=" + $Metrics['bars']), ("ticks=" + $Metrics['ticks']), ("server=" + $Metrics['company']))
  $joined = ($parts -join '|')
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($joined))
  $sha.Dispose()
  return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Get-PilotCryptoFinancing {
  param(
    [Parameter(Mandatory)][hashtable]$Ctx,
    [Parameter(Mandatory)][string]$Htm
  )
  $out = & $Ctx.Python (Join-Path $Ctx.ScriptDir 'swap_adjust_crypto.py') `
            '--rate-long' $Ctx.CryptoRateLong '--rate-short' $Ctx.CryptoRateShort $Htm
  if ($LASTEXITCODE -ne 0) { throw ("swap_adjust_crypto.py failed on " + $Htm + ": " + ($out -join ' ')) }
  return ($out -join "`n")
}

# --- one tester pass --------------------------------------------------------------------------------
# Requires scripts\lib\report_freshness.ps1 to have been dot-sourced by the host script. It is not
# dot-sourced from here: a library that dot-sources another library makes the caller's scope depend
# on this file's import order, and report_freshness.ps1's own header is explicit that it is imported
# by the host.
function Invoke-PilotCell {
  param(
    [Parameter(Mandatory)][hashtable]$Ctx,
    [Parameter(Mandatory)][string]$Expert,
    [Parameter(Mandatory)][string]$Symbol,
    [Parameter(Mandatory)][string]$Period,
    [Parameter(Mandatory)][string]$SetPath,
    [Parameter(Mandatory)][string]$ReportName
  )
  if (-not (Get-Command Test-ReportIsFresh -ErrorAction SilentlyContinue)) {
    throw ("Invoke-PilotCell needs Test-ReportIsFresh; dot-source scripts\lib\report_freshness.ps1 in the host script before calling it. Without it a run that produced nothing would be read off a leftover report.")
  }
  $runStart = Get-Date
  & (Join-Path $Ctx.ScriptDir 'mt5_run.ps1') -Expert $Expert -Symbol $Symbol -Period $Period `
      -FromDate $Ctx.FromDate -ToDate $Ctx.ToDate -SetFile $SetPath -Model $Ctx.Model `
      -ReportName $ReportName -Terminal $Ctx.Terminal -DataDir $Ctx.DataDir | Out-Null
  $rc = $LASTEXITCODE
  # THE EXIT CODE IS CHECKED BEFORE THE REPORT. An aborted run (mt5_run refuses while the GUI holds
  # the install, exit 2) leaves the PREVIOUS report in place, and "the .htm exists" would then read
  # last week's numbers as this cell's. "I could not run it" and "it produced this" must never
  # share an exit path.
  if ($rc -ne 0) { throw ("cell " + $Symbol + " " + $Period + " (" + $Expert + "): mt5_run.ps1 exited " + $rc + " -- the tester did not produce this run, so NOTHING is known about this cell.") }
  $htm = Join-Path $Ctx.RepoRoot ('_mt5_auto\reports\' + $ReportName + '.htm')
  if (-not (Test-ReportIsFresh -Htm $htm -RunStart $runStart -RunnerExit $rc -Label $ReportName)) {
    throw ("cell " + $Symbol + " " + $Period + ": the report at " + $htm + " is not evidence from THIS run (absent, or written before it started).")
  }
  return $htm
}
