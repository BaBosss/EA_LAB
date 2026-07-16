# ORDER-109 follow-up: Zeus AUDJPY regime-rescue candidate — plateau-confirm + Model-4.
# From the 32-run sweep: m2t20 (MAIN 1.32/BWD 1.39) + m1rng25 (1.38/1.32) lift both windows.
# Phase 1 (Model 1): fill plateau neighbors around the two leaders.
# Phase 2 (Model 4, real ticks): confirm the two leaders survive real-tick fills (grid fill-optimism check).
# Output: _mt5_auto\ZEUS_AUDJPY_CONFIRM.csv
$ErrorActionPreference = 'Stop'
$root   = 'D:\EA_LAB'
$setDir = Join-Path $root '_mt5_auto\ab_sets\zeus_regime'
$outCsv = Join-Path $root '_mt5_auto\ZEUS_AUDJPY_CONFIRM.csv'
$base   = Join-Path $root 'ea_projects\(Boss)_ZeusInspired_GridLog\set_files\ZeusInspired_AUDJPY_lot8x.set'
$ea     = '(Boss)_ZeusInspired_GridLog_rev01'
$symbol = 'AUDJPY'

$windows = @(
    @{ tag='MAIN'; from='2023.01.01'; to='2026.07.01' },
    @{ tag='BWD';  from='2020.01.01'; to='2023.01.01' }
)
# Phase 1: plateau neighbors (Model 1). m2t20/25 + m1rng25 already in ZEUS_REGIME_AB.csv.
$plateau = [ordered]@{
    'm2t15'   = @('_50_RegimeMode=2','_50_ADX_TrendMin=15.0')
    'm2t18'   = @('_50_RegimeMode=2','_50_ADX_TrendMin=18.0')
    'm2t22'   = @('_50_RegimeMode=2','_50_ADX_TrendMin=22.0')
    'm1rng20' = @('_50_RegimeMode=1','_50_AllowRange=true','_50_AllowTrendUp=false','_50_AllowTrendDown=false','_50_ADX_TrendMin=20.0')
    'm1rng30' = @('_50_RegimeMode=1','_50_AllowRange=true','_50_AllowTrendUp=false','_50_AllowTrendDown=false','_50_ADX_TrendMin=30.0')
}
# Phase 2: Model-4 confirm on the two current leaders.
$m4 = [ordered]@{
    'm2t20'   = @('_50_RegimeMode=2','_50_ADX_TrendMin=20.0')
    'm1rng25' = @('_50_RegimeMode=1','_50_AllowRange=true','_50_AllowTrendUp=false','_50_AllowTrendDown=false','_50_ADX_TrendMin=25.0')
}

function Parse-Report([string]$htm) {
    $t = (Get-Content $htm -Raw) -replace '<[^>]+>', '|'
    $parts = ($t -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $out = @{}
    $keys = @{ 'Total Net Profit:'='net'; 'Profit Factor:'='pf'; 'Total Trades:'='trades'; 'Equity Drawdown Maximal:'='eqdd' }
    for ($i=0; $i -lt $parts.Count-1; $i++){ if ($keys.ContainsKey($parts[$i])){ $out[$keys[$parts[$i]]]=($parts[$i+1] -replace '\s','') } }
    return $out
}
function Do-Run($cfgName,$lines,$model) {
    $setPath = Join-Path $setDir ("ZC_{0}_m{1}.set" -f $cfgName,$model)
    $content = Get-Content $base
    $content += ''; $content += '; confirm variant ' + $cfgName; $content += $lines
    Set-Content -Path $setPath -Value $content -Encoding utf8
    foreach ($win in $windows) {
        $rep = "ZC_{0}_M{1}_{2}" -f $cfgName,$model,$win.tag
        Write-Host (">> {0}" -f $rep)
        & (Join-Path $root 'scripts\mt5_run.ps1') -Expert $ea -Symbol $symbol -Period H1 `
            -FromDate $win.from -ToDate $win.to -Model $model -ReportName $rep -SetFile $setPath | Out-Null
        $htm = Join-Path $root ("_mt5_auto\reports\{0}.htm" -f $rep)
        if (-not (Test-Path $htm)) { Write-Host "[FAIL] no report: $rep"; continue }
        $m = Parse-Report $htm
        $script:rows += [pscustomobject]@{ config=$cfgName; model=$model; window=$win.tag; net=$m['net']; pf=$m['pf']; trades=$m['trades']; eqdd=$m['eqdd'] }
        Write-Host ("   net={0} pf={1} n={2} eqdd={3}" -f $m['net'],$m['pf'],$m['trades'],$m['eqdd'])
    }
}

$rows = @()
Write-Host "===== PHASE 1: plateau neighbors (Model 1) ====="
foreach ($k in $plateau.Keys) { Do-Run $k $plateau[$k] 1 }
Write-Host "===== PHASE 2: Model-4 confirm (real ticks) ====="
foreach ($k in $m4.Keys) { Do-Run $k $m4[$k] 4 }
$rows | Export-Csv $outCsv -NoTypeInformation -Encoding utf8
Write-Host "DONE -> $outCsv ($($rows.Count) rows)"