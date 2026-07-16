# ORDER-110 (regime-rescue #2): XAU NY-session breakout rebuilt on LabCore (Entry 12 Donchian)
# + _50_ regime gate. Runs on Meta5b (portable) in parallel with Zeus on Meta5.
# Coarse: TF{H1,H4} x Bars{8,20,40} x session{NY 13-21 GMT, none} x regime{off,m1t25} x window{MAIN,BWD}
#   = 24 configs x 2 windows = 48 runs -> _mt5_auto\XAUNY_REGIME_AB.csv
# Fixed: SL ATR 2.0, TP ATR 3.0, ConfirmBars 1. Expert = EALabTpl\Boss_12_Breakout (StackMode SINGLE default).
$ErrorActionPreference = 'Stop'
$root   = 'D:\EA_LAB'
$setDir = Join-Path $root '_mt5_auto\ab_sets\xauny_regime'
$outCsv = Join-Path $root '_mt5_auto\XAUNY_REGIME_AB.csv'
$ea     = 'EALabTpl\Boss_12_Breakout'
$symbol = 'XAUUSD'

$tfs      = @('H1','H4')
$barsList = @(8,20,40)
$sessions = [ordered]@{ 'NY'=@(13,21); 'none'=@(0,0) }
$regimes  = [ordered]@{
    'roff'  = @()
    'm1t25' = @('_50_RegimeMode=1','_50_AllowRange=false','_50_AllowTrendUp=true','_50_AllowTrendDown=true','_50_ADX_TrendMin=25.0')
}
$windows = @(
    @{ tag='MAIN'; from='2023.01.01'; to='2026.07.01' },
    @{ tag='BWD';  from='2020.01.01'; to='2023.01.01' }
)

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
foreach ($tf in $tfs) {
  foreach ($bars in $barsList) {
    foreach ($sess in $sessions.Keys) {
      foreach ($reg in $regimes.Keys) {
        # build minimal set (only overrides; rest = compiled LAB_ENTRY_12 defaults)
        $hf = $sessions[$sess][0]; $ht = $sessions[$sess][1]
        $lines = @(
          '; ORDER-110 XAU_NY regime rescue variant',
          "_12_Bars=$bars", '_12_ConfirmBars=1',
          "_12_HourFrom=$hf", "_12_HourTo=$ht",
          'SLMode=33', '_33_SL_ATRmult=2.0',
          'ExitMode=22', '_22_TP_ATRmult=3.0',
          'StackMode=90', 'TradeDir=60', '_0_BarOpenOnly=true'
        )
        $lines += $regimes[$reg]
        $setPath = Join-Path $setDir ("XNY_{0}_b{1}_{2}_{3}.set" -f $tf,$bars,$sess,$reg)
        Set-Content -Path $setPath -Value $lines -Encoding utf8
        foreach ($win in $windows) {
          $rep = "XNY_{0}_b{1}_{2}_{3}_{4}" -f $tf,$bars,$sess,$reg,$win.tag
          Write-Host (">> {0}" -f $rep)
          & (Join-Path $root 'scripts\mt5_run.ps1') -Expert $ea -Symbol $symbol -Period $tf `
              -FromDate $win.from -ToDate $win.to -Model 1 -Deposit 10000 -Leverage 100 `
              -ReportName $rep -SetFile $setPath `
              -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable | Out-Null
          $htm = Join-Path $root ("_mt5_auto\reports\{0}.htm" -f $rep)
          if (-not (Test-Path $htm)) { Write-Host "[FAIL] no report: $rep"; continue }
          $m = Parse-Report $htm
          $rows += [pscustomobject]@{ tf=$tf; bars=$bars; session=$sess; regime=$reg; window=$win.tag; net=$m['net']; pf=$m['pf']; trades=$m['trades']; eqdd=$m['eqdd'] }
          Write-Host ("   net={0} pf={1} n={2} eqdd={3}" -f $m['net'],$m['pf'],$m['trades'],$m['eqdd'])
        }
      }
    }
  }
}
$rows | Export-Csv $outCsv -NoTypeInformation -Encoding utf8
Write-Host "DONE -> $outCsv ($($rows.Count) rows)"