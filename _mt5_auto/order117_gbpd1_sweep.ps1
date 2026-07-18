$ErrorActionPreference = "Stop"
$lookbacks = 60,80,110
$minbars   = 2,3,5
$swings    = 2,3,4
$windows = @(
  @{n="MAIN"; f="2023.01.01"; t="2025.12.31"},
  @{n="BWD";  f="2020.01.01"; t="2022.12.31"}
)
$setDir = "D:\EA_LAB\_mt5_auto\ab_sets\order117_gbp\d1_sweep"
New-Item -ItemType Directory -Force -Path $setDir | Out-Null
$results = @()
foreach ($lb in $lookbacks) {
  foreach ($mb in $minbars) {
    foreach ($sw in $swings) {
      $tag = "LB${lb}_MB${mb}_SW${sw}"
      $setPath = Join-Path $setDir "MacdDiv_$tag.set"
      @"
_00_OptimizeMode=false
_01_LookbackBars=$lb
_01_SwingRadius=$sw
_01_MinBarsApart=$mb
_02_MacdFast=12
_02_MacdSlow=26
_02_MacdSignal=9
_03_BufferAtrMult=0.10
_03_AtrPeriod=14
_05_LotSize=0.01
_06_Magic=999094
_06_Deviation=20
_06_AllowLive=false
_07_UseRsiGate=false
"@ | Set-Content -Path $setPath -Encoding ASCII

      foreach ($w in $windows) {
        Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 2
        $rname = "O117D1_${tag}_$($w.n)"
        & D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'MacdDiv_Naked' -Symbol GBPUSD -Period D1 `
          -FromDate $w.f -ToDate $w.t -SetFile $setPath -Model 1 -ReportName $rname -Force -TimeoutSec 300 | Out-Null
        $rep = "D:\EA_LAB\_mt5_auto\reports\$rname.htm"
        if (Test-Path $rep) {
          $p = (& D:\EA_LAB\scripts\parse_htm.ps1 -Path $rep | Out-String)
          $pf = ($p | Select-String "PF\s*:\s*([\-\d.]+)").Matches[0].Groups[1].Value
          $tr = ($p | Select-String "Trades\s*:\s*(\d+)").Matches[0].Groups[1].Value
          $dd = ($p | Select-String "DDpct\s*:\s*([\-\d.]+)").Matches[0].Groups[1].Value
          $results += [PSCustomObject]@{Tag=$tag;Window=$w.n;LB=$lb;MB=$mb;SW=$sw;PF=$pf;Trades=$tr;DD=$dd}
        } else {
          $results += [PSCustomObject]@{Tag=$tag;Window=$w.n;LB=$lb;MB=$mb;SW=$sw;PF="NOREPORT";Trades=0;DD=0}
        }
      }
    }
  }
}
$results | Export-Csv -Path "D:\EA_LAB\_mt5_auto\order117_gbpd1_sweep_results.csv" -NoTypeInformation
$results | Format-Table -AutoSize

