# ORDER-057 Stage B: Regime.mqh A/B matrix (run by Claude 2026-07-09; Codex quota out, ZCode n/a)
# 2 EAs x 2 windows x 8 configs = 32 runs -> _mt5_auto\REGIME_AB.csv
$ErrorActionPreference = 'Stop'
$root = 'D:\EA_LAB'
$setDir = Join-Path $root '_mt5_auto\ab_sets\regime_sets'
$outCsv = Join-Path $root '_mt5_auto\REGIME_AB.csv'

$targets = @(
    @{ tag='XAU';    symbol='XAUUSD'; base=(Join-Path $root 'ea_template\sets\Boss14_GridLog_XAU_ISpick.set') },
    @{ tag='AUDNZD'; symbol='AUDNZD'; base=(Join-Path $root 'ea_template\sets\Boss14_GridLog_AUDNZD_DEMO.set') }
)
$windows = @(
    @{ tag='FWD'; from='2023.01.01'; to='2026.07.01' },
    @{ tag='BWD'; from='2020.01.01'; to='2023.01.01' }
)
# config -> extra .set lines (base run = no extra lines, mode stays default 0)
$configs = [ordered]@{
    'base'     = @()
    'm1t20'    = @('_50_RegimeMode=1','_50_AllowRange=false','_50_AllowTrendUp=true','_50_AllowTrendDown=true','_50_ADX_TrendMin=20.0')
    'm1t25'    = @('_50_RegimeMode=1','_50_AllowRange=false','_50_AllowTrendUp=true','_50_AllowTrendDown=true','_50_ADX_TrendMin=25.0')
    'm1t30'    = @('_50_RegimeMode=1','_50_AllowRange=false','_50_AllowTrendUp=true','_50_AllowTrendDown=true','_50_ADX_TrendMin=30.0')
    'm1rng25'  = @('_50_RegimeMode=1','_50_AllowRange=true','_50_AllowTrendUp=false','_50_AllowTrendDown=false','_50_ADX_TrendMin=25.0')
    'm2t20'    = @('_50_RegimeMode=2','_50_ADX_TrendMin=20.0')
    'm2t25'    = @('_50_RegimeMode=2','_50_ADX_TrendMin=25.0')
    'm2t30'    = @('_50_RegimeMode=2','_50_ADX_TrendMin=30.0')
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

$rows = @()
foreach ($tgt in $targets) {
    foreach ($cfgName in $configs.Keys) {
        # build variant set once per target+config
        $setPath = Join-Path $setDir ("B14_{0}_{1}.set" -f $tgt.tag, $cfgName)
        $content = Get-Content $tgt.base
        $content += ''
        $content += '; ORDER-057B regime variant: ' + $cfgName
        $content += $configs[$cfgName]
        Set-Content -Path $setPath -Value $content -Encoding utf8
        foreach ($win in $windows) {
            $rep = "REGIMEAB_{0}_{1}_{2}" -f $tgt.tag, $cfgName, $win.tag
            Write-Host (">> {0}" -f $rep)
            & (Join-Path $root 'scripts\mt5_run.ps1') -Expert 'EALabTpl\Boss_14_GridLog' -Symbol $tgt.symbol -Period H1 `
                -FromDate $win.from -ToDate $win.to -Model 1 -ReportName $rep -SetFile $setPath | Out-Null
            $htm = Join-Path $root ("_mt5_auto\reports\{0}.htm" -f $rep)
            if (-not (Test-Path $htm)) { Write-Host "[FAIL] no report: $rep"; continue }
            $m = Parse-Report $htm
            $row = [pscustomobject]@{ ea=$tgt.tag; window=$win.tag; config=$cfgName; net=$m['net']; pf=$m['pf']; trades=$m['trades']; eqdd=$m['eqdd'] }
            $rows += $row
            Write-Host ("   net={0} pf={1} n={2} eqdd={3}" -f $m['net'], $m['pf'], $m['trades'], $m['eqdd'])
        }
    }
}
$rows | Export-Csv $outCsv -NoTypeInformation -Encoding utf8
Write-Host "DONE -> $outCsv ($($rows.Count) rows)"
