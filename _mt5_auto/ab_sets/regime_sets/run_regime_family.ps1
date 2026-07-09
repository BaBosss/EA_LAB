# ORDER-062: _50_ regime-axis re-funnel of Boss_14 family (lane 2)
# 8 symbols x {base, m1t20, m1t25} x {FWD 2023-26, BWD 2020-22} = 48 runs -> REGIME_FAMILY.csv
# mode2 dropped (Stage B: mode2 <= mode1 everywhere). AUDNZD/XAU already done in Stage B.
$ErrorActionPreference = 'Stop'
$root = 'D:\EA_LAB'
$setDir = Join-Path $root '_mt5_auto\ab_sets\regime_sets'
$outCsv = Join-Path $root '_mt5_auto\REGIME_FAMILY.csv'

$targets = @(
    @{ tag='GBPAUD'; symbol='GBPAUD'; base='ea_template\sets\Boss14_GridLog_GBPAUD_p26.set' },
    @{ tag='CADJPY'; symbol='CADJPY'; base='ea_template\sets\Boss14_GridLog_CADJPY_DEMO.set' },
    @{ tag='EURJPY'; symbol='EURJPY'; base='ea_template\sets\Boss14_GridLog_EURJPY_DEMO.set' },
    @{ tag='EURUSD'; symbol='EURUSD'; base='ea_template\sets\Boss14_GridLog_EURUSD_DEMO.set' },
    @{ tag='USDJPY'; symbol='USDJPY'; base='ea_template\sets\Boss14_GridLog_USDJPY_DEMO.set' },
    @{ tag='AUDCAD'; symbol='AUDCAD'; base='ea_template\sets\Boss14_GridLog_AUDCAD_DEMO.set' },
    @{ tag='NZDUSD'; symbol='NZDUSD'; base='ea_template\sets\Boss14_GridLog_NZDUSD_ISpick.set' },
    @{ tag='GBPJPY'; symbol='GBPJPY'; base='ea_template\sets\Boss14_GridLog_GBPJPY_ISpick.set' }
)
$windows = @(
    @{ tag='FWD'; from='2023.01.01'; to='2026.07.01' },
    @{ tag='BWD'; from='2020.01.01'; to='2023.01.01' }
)
$configs = [ordered]@{
    'base'  = @()
    'm1t20' = @('_50_RegimeMode=1','_50_AllowRange=false','_50_AllowTrendUp=true','_50_AllowTrendDown=true','_50_ADX_TrendMin=20.0')
    'm1t25' = @('_50_RegimeMode=1','_50_AllowRange=false','_50_AllowTrendUp=true','_50_AllowTrendDown=true','_50_ADX_TrendMin=25.0')
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
    $basePath = Join-Path $root $tgt.base
    if (-not (Test-Path $basePath)) { Write-Host "[SKIP] missing set: $($tgt.base)"; continue }
    foreach ($cfgName in $configs.Keys) {
        $setPath = Join-Path $setDir ("FAM_{0}_{1}.set" -f $tgt.tag, $cfgName)
        $content = Get-Content $basePath
        $content += ''
        $content += '; ORDER-062 regime variant: ' + $cfgName
        $content += $configs[$cfgName]
        Set-Content -Path $setPath -Value $content -Encoding utf8
        foreach ($win in $windows) {
            $rep = "REGFAM_{0}_{1}_{2}" -f $tgt.tag, $cfgName, $win.tag
            Write-Host (">> {0}" -f $rep)
            & (Join-Path $root 'scripts\mt5_run.ps1') -Expert 'EALabTpl\Boss_14_GridLog' -Symbol $tgt.symbol -Period H1 `
                -FromDate $win.from -ToDate $win.to -Model 1 -ReportName $rep -SetFile $setPath `
                -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable | Out-Null
            $htm = Join-Path $root ("_mt5_auto\reports\{0}.htm" -f $rep)
            if (-not (Test-Path $htm)) { Write-Host "[FAIL] no report: $rep"; continue }
            $m = Parse-Report $htm
            $rows += [pscustomobject]@{ ea=$tgt.tag; window=$win.tag; config=$cfgName; net=$m['net']; pf=$m['pf']; trades=$m['trades']; eqdd=$m['eqdd'] }
            Write-Host ("   net={0} pf={1} n={2} eqdd={3}" -f $m['net'], $m['pf'], $m['trades'], $m['eqdd'])
        }
    }
}
$rows | Export-Csv $outCsv -NoTypeInformation -Encoding utf8
Write-Host "DONE -> $outCsv ($($rows.Count) rows)"
