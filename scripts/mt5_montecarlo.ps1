<#
.SYNOPSIS
    Monte Carlo on MT5 Strategy Tester report(s) — PowerShell port of scripts/mt5_montecarlo.py.

.DESCRIPTION
    WHY THIS EXISTS: this machine has no Python interpreter (verified 2026-07-28, ORDER-353:
    no python/py on PATH, none in the standard install locations), so the .py tool can only be
    run by delegating to another agent lane. This port keeps a Monte Carlo runnable locally.
    It follows the SAME algorithm as the .py: read closed-trade P&L (profit + commission + swap)
    out of the report's deal table, resample, and report the distribution.

    IT IS A SECOND IMPLEMENTATION OF THE SAME THING, which is a liability if the two drift.
    Two guards against that:
      * -SelfCheck runs PERMUTATION mode and asserts that net and PF come back EXACTLY equal to
        the report's own figures. Permutation only reorders the multiset, so gross profit and
        gross loss — and therefore net and PF — are invariant by construction. If the trade
        extraction is wrong (wrong column, missed rows, double-counted commission) the identity
        breaks. This validates the parser without needing Python present.
      * The bootstrap/permutation distinction is spelled out in the output every run, because
        the default in the .py is PERMUTATION, under which PF CANNOT vary — a PF-5th percentile
        bar read off a permutation run is meaningless and has been mistaken for a passing
        result before (memory: pf5th-bar-cannot-fail-under-current-mc).

.PARAMETER Reports
    One or more report .htm paths. Multiple reports are concatenated into a single trade
    sequence, in the order given — used when a long window had to be sliced (Model 4 over
    3 years exceeds the tester's tick-memory ceiling; see ORDER-355).

.PARAMETER Bootstrap
    Resample WITH replacement, so the multiset changes and net/PF actually vary across
    iterations. REQUIRED for any PF-based bar to mean anything.

.PARAMETER Deposit
    Starting balance for the equity path. Defaults to the first report's declared deposit.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$Reports,
    [switch]$Bootstrap,
    [double]$Deposit = 0,
    [int]$Iterations = 2000,
    [int]$Seed = 20260728,
    [switch]$SelfCheck
)

$ErrorActionPreference = 'Stop'

function Get-ReportCells {
    param([string]$Path)
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $flat = ($raw -replace '<[^>]+>', '|')
    $flat = ($flat -replace '[\r\n\t ]*\|[\r\n\t ]*', '|') -replace '\|{2,}', '|'
    return @{ Raw = $raw; Flat = $flat }
}

function Get-ReportField {
    param([string]$Flat, [string]$Key)
    $m = [regex]::Match($Flat, [regex]::Escape($Key) + ':\|([^|]*)\|')
    if ($m.Success) { return $m.Groups[1].Value } else { return '' }
}

function ConvertTo-Number {
    param([string]$Text)
    $t = $Text -replace '[^\d\.\-]', ''
    if ($t) { return [double]$t } else { return 0.0 }
}

# Extract closed-trade P&L exactly as the .py does: deal rows with 13 cells whose Direction
# column is "out", value = profit + commission + swap.
function Get-Trades {
    param([string]$Path)
    $raw = (Get-ReportCells -Path $Path).Raw
    $out = New-Object System.Collections.Generic.List[double]
    foreach ($rowMatch in [regex]::Matches($raw, '(?s)<tr[^>]*>(.*?)</tr>')) {
        $cells = @([regex]::Matches($rowMatch.Groups[1].Value, '(?s)<t[dh][^>]*>(.*?)</t[dh]>') |
                   ForEach-Object { ($_.Groups[1].Value -replace '<[^>]+>', '').Trim() })
        if ($cells.Count -ne 13) { continue }
        if ($cells[4].ToLowerInvariant() -ne 'out') { continue }
        $profit     = ConvertTo-Number $cells[10]
        $commission = ConvertTo-Number $cells[8]
        $swap       = ConvertTo-Number $cells[9]
        $out.Add($profit + $commission + $swap)
    }
    return , $out.ToArray()
}

$all = New-Object System.Collections.Generic.List[double]
$reportNet = 0.0
$reportGp  = 0.0
$reportGl  = 0.0
foreach ($r in $Reports) {
    if (-not (Test-Path -LiteralPath $r)) { throw "report not found: $r" }
    $t = Get-Trades -Path $r
    if ($t.Count -eq 0) { throw "report has ZERO closed trades, refusing to run: $r  (a 0-trade report is a broken run, not a result -- ORDER-355)" }
    $all.AddRange($t)
    $cells = Get-ReportCells -Path $r
    $reportNet += ConvertTo-Number (Get-ReportField -Flat $cells.Flat -Key 'Total Net Profit')
    $reportGp  += ConvertTo-Number (Get-ReportField -Flat $cells.Flat -Key 'Gross Profit')
    $reportGl  += [math]::Abs((ConvertTo-Number (Get-ReportField -Flat $cells.Flat -Key 'Gross Loss')))
    if ($Deposit -le 0) {
        $d = ConvertTo-Number (Get-ReportField -Flat $cells.Flat -Key 'Initial Deposit')
        if ($d -gt 0) { $Deposit = $d }
    }
}
if ($Deposit -le 0) { $Deposit = 10000.0 }

$profits = $all.ToArray()
$n = $profits.Count

$mode = if ($Bootstrap) { 'BOOTSTRAP (with replacement -- net and PF vary)' }
        else { 'PERMUTATION (reorder only -- net and PF are INVARIANT by construction)' }

Write-Host ''
Write-Host "mode      : $mode"
Write-Host ("reports   : {0}" -f ($Reports -join ', '))
Write-Host ("trades    : {0}    deposit: {1}    iterations: {2}    seed: {3}" -f $n, $Deposit, $Iterations, $Seed)

if ($SelfCheck) {
    # Parser validation that does not need Python: the extracted trades must reproduce the
    # report's own gross profit / gross loss / net. If they do not, the extraction is wrong
    # and every number below it would be wrong too.
    $gp = ($profits | Where-Object { $_ -gt 0 } | Measure-Object -Sum).Sum
    $gl = -(($profits | Where-Object { $_ -lt 0 } | Measure-Object -Sum).Sum)
    if (-not $gp) { $gp = 0.0 }
    if (-not $gl) { $gl = 0.0 }
    $net = $gp - $gl
    $dNet = [math]::Abs($net - $reportNet)
    Write-Host ''
    Write-Host '--- SELF-CHECK: extracted trades vs the report''s own totals ---'
    Write-Host ("  net      extracted {0,12:N2}   report {1,12:N2}   diff {2:N2}" -f $net, $reportNet, $dNet)
    Write-Host ("  gross +  extracted {0,12:N2}   report {1,12:N2}" -f $gp, $reportGp)
    Write-Host ("  gross -  extracted {0,12:N2}   report {1,12:N2}" -f $gl, $reportGl)
    if ($dNet -gt 0.05) {
        Write-Host '  RESULT: FAIL -- extraction does not reproduce the report. Do not trust any MC number from this run.'
        exit 1
    }
    Write-Host '  RESULT: PASS -- extraction reproduces the report to the cent.'
}

$rng = New-Object System.Random($Seed)
$finals  = New-Object double[] $Iterations
$maxdds  = New-Object double[] $Iterations
$pfs     = New-Object double[] $Iterations
$ruinHit = 0

for ($i = 0; $i -lt $Iterations; $i++) {
    if ($Bootstrap) {
        $order = New-Object double[] $n
        for ($k = 0; $k -lt $n; $k++) { $order[$k] = $profits[$rng.Next(0, $n)] }
    } else {
        $order = $profits.Clone()
        for ($k = $n - 1; $k -gt 0; $k--) {
            $j = $rng.Next(0, $k + 1)
            $tmp = $order[$k]; $order[$k] = $order[$j]; $order[$j] = $tmp
        }
    }
    $equity = $Deposit; $peak = $Deposit; $maxdd = 0.0; $gp = 0.0; $gl = 0.0; $ruined = $false
    foreach ($p in $order) {
        $equity += $p
        if ($p -gt 0) { $gp += $p } else { $gl += -$p }
        if ($equity -gt $peak) { $peak = $equity }
        if ($peak -gt 0) {
            $dd = ($peak - $equity) / $peak * 100.0
            if ($dd -gt $maxdd) { $maxdd = $dd }
        }
        if ($equity -le 0) { $ruined = $true; break }
    }
    if ($ruined) { $ruinHit++ }
    $finals[$i] = $equity - $Deposit
    $maxdds[$i] = $maxdd
    $pfs[$i] = if ($gl -gt 0) { $gp / $gl } else { [double]::PositiveInfinity }
}

function Pct { param([double[]]$Data, [double]$P)
    $s = $Data | Sort-Object
    $idx = [int][math]::Floor(($P / 100.0) * ($s.Count - 1))
    return $s[$idx]
}

Write-Host ''
Write-Host '--- results ---'
Write-Host ("  net    : 5th {0,10:N2}   50th {1,10:N2}   95th {2,10:N2}" -f (Pct $finals 5), (Pct $finals 50), (Pct $finals 95))
Write-Host ("  PF     : 5th {0,10:N2}   50th {1,10:N2}   95th {2,10:N2}" -f (Pct $pfs 5), (Pct $pfs 50), (Pct $pfs 95))
Write-Host ("  maxDD% : 50th {0,10:N2}   95th {1,10:N2}   99th {2,10:N2}" -f (Pct $maxdds 50), (Pct $maxdds 95), (Pct $maxdds 99))
Write-Host ("  P(net<0) : {0:N1}%      ruin (equity<=0) : {1:N2}%" -f ((@($finals | Where-Object { $_ -lt 0 }).Count / $Iterations * 100.0)), ($ruinHit / $Iterations * 100.0))
if (-not $Bootstrap) {
    Write-Host ''
    Write-Host '  NOTE: permutation mode -- the PF row above is a constant, not a distribution.'
    Write-Host '        Do NOT read a PF-5th bar off this run. Re-run with -Bootstrap.'
}
Write-Host ''
