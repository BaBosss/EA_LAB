# ORDER-109 (regime-rescue #1): Zeus regime-gate A/B on parked cells AUDJPY/AUDUSD.
# Phase 1 = no-op proof (pre-graft baseline vs grafted mode-0 must be bit-identical).
# Phase 2 = regime sweep both-window (8 configs x 2 windows x 2 symbols = 32 runs).
# Outputs: _mt5_auto\ZEUS_REGIME_NOOP.csv  +  _mt5_auto\ZEUS_REGIME_AB.csv
$ErrorActionPreference = 'Stop'
$root   = 'D:\EA_LAB'
$setDir = Join-Path $root '_mt5_auto\ab_sets\zeus_regime'
$noopCsv = Join-Path $root '_mt5_auto\ZEUS_REGIME_NOOP.csv'
$abCsv   = Join-Path $root '_mt5_auto\ZEUS_REGIME_AB.csv'
$zeusSets = Join-Path $root 'ea_projects\(Boss)_ZeusInspired_GridLog\set_files'

$eaNew  = '(Boss)_ZeusInspired_GridLog_rev01'   # grafted (has _50_)
$eaBase = '_ZeusBaseline_pregraft'              # pre-graft baseline (no _50_)

$targets = @(
    @{ tag='AUDJPY'; symbol='AUDJPY'; base=(Join-Path $zeusSets 'ZeusInspired_AUDJPY_lot8x.set') },
    @{ tag='AUDUSD'; symbol='AUDUSD'; base=(Join-Path $zeusSets 'ZeusInspired_AUDUSD_lot10x.set') }
)
$windows = @(
    @{ tag='MAIN'; from='2023.01.01'; to='2026.07.01' },
    @{ tag='BWD';  from='2020.01.01'; to='2023.01.01' }
)
# config -> extra .set lines appended to Zeus base (base run = no extra lines, mode stays default 0)
$configs = [ordered]@{
    'base'    = @()
    'm1t20'   = @('_50_RegimeMode=1','_50_AllowRange=false','_50_AllowTrendUp=true','_50_AllowTrendDown=true','_50_ADX_TrendMin=20.0')
    'm1t25'   = @('_50_RegimeMode=1','_50_AllowRange=false','_50_AllowTrendUp=true','_50_AllowTrendDown=true','_50_ADX_TrendMin=25.0')
    'm1t30'   = @('_50_RegimeMode=1','_50_AllowRange=false','_50_AllowTrendUp=true','_50_AllowTrendDown=true','_50_ADX_TrendMin=30.0')
    'm1rng25' = @('_50_RegimeMode=1','_50_AllowRange=true','_50_AllowTrendUp=false','_50_AllowTrendDown=false','_50_ADX_TrendMin=25.0')
    'm2t20'   = @('_50_RegimeMode=2','_50_ADX_TrendMin=20.0')
    'm2t25'   = @('_50_RegimeMode=2','_50_ADX_TrendMin=25.0')
    'm2t30'   = @('_50_RegimeMode=2','_50_ADX_TrendMin=30.0')
}

function Parse-Report([string]$htm) {
    $t = Get-Content $htm -Raw
    $t = $t -replace '<[^>]+>', '|'
    $parts = ($t -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $out = @{}
    $keys = @{ 'Total Net Profit:'='net'; 'Profit Factor:'='pf'; 'Total Trades:'='trades'; 'Equity Drawdown Maximal:'='eqdd' }
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        if ($keys.ContainsKey($parts[$i])) { $out[$keys[$parts[$i]]] = ($parts[$i+1] -replace '\s','') }
    }
    return $out
}

function Run-One([string]$ea, [string]$symbol, [string]$from, [string]$to, [string]$rep, [string]$setPath) {
    & (Join-Path $root 'scripts\mt5_run.ps1') -Expert $ea -Symbol $symbol -Period H1 `
        -FromDate $from -ToDate $to -Model 1 -ReportName $rep -SetFile $setPath | Out-Null
    $htm = Join-Path $root ("_mt5_auto\reports\{0}.htm" -f $rep)
    if (-not (Test-Path $htm)) { return $null }
    return Parse-Report $htm
}

# ---------- PHASE 1: no-op proof (MAIN window only, base set) ----------
Write-Host "===== PHASE 1: NO-OP PROOF (baseline vs grafted mode-0) ====="
$noopRows = @()
$noopFail = $false
foreach ($tgt in $targets) {
    $w = $windows[0]  # MAIN
    $bp = Run-One $eaBase $tgt.symbol $w.from $w.to ("ZNOOP_{0}_baseline" -f $tgt.tag) $tgt.base
    $gp = Run-One $eaNew  $tgt.symbol $w.from $w.to ("ZNOOP_{0}_graft0"  -f $tgt.tag) $tgt.base
    if ($null -eq $bp -or $null -eq $gp) { Write-Host "[FAIL] missing report for $($tgt.tag)"; $noopFail=$true; continue }
    $identical = ($bp['net'] -eq $gp['net']) -and ($bp['pf'] -eq $gp['pf']) -and ($bp['trades'] -eq $gp['trades']) -and ($bp['eqdd'] -eq $gp['eqdd'])
    if (-not $identical) { $noopFail = $true }
    $noopRows += [pscustomobject]@{ symbol=$tgt.tag; baseline_net=$bp['net']; graft_net=$gp['net']; baseline_pf=$bp['pf']; graft_pf=$gp['pf']; baseline_trades=$bp['trades']; graft_trades=$gp['trades']; baseline_eqdd=$bp['eqdd']; graft_eqdd=$gp['eqdd']; identical=$identical }
    Write-Host ("  {0}: baseline net={1}/pf={2}/n={3}  graft0 net={4}/pf={5}/n={6}  IDENTICAL={7}" -f $tgt.tag,$bp['net'],$bp['pf'],$bp['trades'],$gp['net'],$gp['pf'],$gp['trades'],$identical)
}
$noopRows | Export-Csv $noopCsv -NoTypeInformation -Encoding utf8
if ($noopFail) { Write-Host "*** NO-OP FAILED — graft changed behavior. STOP, do not trust the sweep. ***" }
else { Write-Host "*** NO-OP PASS — grafted mode-0 == pre-graft baseline. Proceeding to sweep. ***" }

# ---------- PHASE 2: regime sweep both-window ----------
Write-Host "===== PHASE 2: REGIME SWEEP (both-window) ====="
$rows = @()
foreach ($tgt in $targets) {
    foreach ($cfgName in $configs.Keys) {
        $setPath = Join-Path $setDir ("Z_{0}_{1}.set" -f $tgt.tag, $cfgName)
        $content = Get-Content $tgt.base
        $content += ''
        $content += '; ORDER-109 Zeus regime variant: ' + $cfgName
        $content += $configs[$cfgName]
        Set-Content -Path $setPath -Value $content -Encoding utf8
        foreach ($win in $windows) {
            $rep = "ZREG_{0}_{1}_{2}" -f $tgt.tag, $cfgName, $win.tag
            Write-Host (">> {0}" -f $rep)
            $m = Run-One $eaNew $tgt.symbol $win.from $win.to $rep $setPath
            if ($null -eq $m) { Write-Host "[FAIL] no report: $rep"; continue }
            $rows += [pscustomobject]@{ symbol=$tgt.tag; window=$win.tag; config=$cfgName; net=$m['net']; pf=$m['pf']; trades=$m['trades']; eqdd=$m['eqdd'] }
            Write-Host ("   net={0} pf={1} n={2} eqdd={3}" -f $m['net'],$m['pf'],$m['trades'],$m['eqdd'])
        }
    }
}
$rows | Export-Csv $abCsv -NoTypeInformation -Encoding utf8
Write-Host "DONE -> $noopCsv (noop) + $abCsv ($($rows.Count) sweep rows)"