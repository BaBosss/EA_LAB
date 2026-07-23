# RSI-MR (990103) ORDER-182 follow-up: entry-threshold (RSI band) x SL-width lever sweep.
# Continues the continuity-check methodology (continuous single-span, MAIN+BWD both-window,
# full-pinned .set, D:\Meta 5b) — spacing (DistAtrMult=9) already swept in ORDER-182; this
# gets levers 2 and 3 (entry-threshold, SL width) toward the >=3-lever verdict requirement.
$ErrorActionPreference = "Continue"
$run = "D:\EA_LAB\scripts\mt5_run.ps1"
$setDir = "D:\EA_LAB\_mt5_auto\ab_sets\rsimr_lever2"
$repDir = "D:\EA_LAB\_mt5_auto\reports"
$out = "D:\EA_LAB\_mt5_auto\RSIMR_LEVER2_SWEEP.csv"
New-Item -ItemType Directory -Force $setDir | Out-Null
'"tag","rsi_os","rsi_ob","sl_atr","window","pf","net","trades","dd_pct","win_pct"' | Out-File $out -Encoding utf8

function Parse-Htm($Path) {
  $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::Unicode)
  $txt = ($raw -replace '<[^>]+>', ' ') -replace '&nbsp;', ' '
  function Grab($label) {
    $m = [regex]::Match($txt, [regex]::Escape($label) + '\s*(-?[\d]{1,3}(?:[ ,]\d{3})*(?:\.\d+)?)')
    if ($m.Success) { return ($m.Groups[1].Value -replace '[ ,]', '') }
    return $null
  }
  $pf = Grab 'Profit Factor:'
  $np = Grab 'Total Net Profit:'
  $tr = Grab 'Total Trades:'
  $mddm = [regex]::Match($txt, 'Equity Drawdown Maximal:\s*([\d.,]+)\s*\(([\d.,]+)%\)')
  $ddpct = if ($mddm.Success) { $mddm.Groups[2].Value } else { "" }
  $pt = [regex]::Match($txt, 'Profit Trades \(% of total\):\s*(\d+)\s*\(([\d.,]+)%\)')
  $winp = if ($pt.Success) { $pt.Groups[2].Value } else { "" }
  return [PSCustomObject]@{ PF=$pf; Net=$np; Trades=$tr; DDpct=$ddpct; Win=$winp }
}

function Write-BaseSet($Path, $rsiOs, $rsiOb, $slAtr) {
@"
_00_OptimizeMode=false
_01_RsiPeriod=14
_01_RsiOversold=$rsiOs
_01_RsiOverbought=$rsiOb
_01_RsiReArm=50.0
_01_AtrPeriod=14
_01_UseEmaFilter=true
_01_EmaPeriod=20
_01_WithTrendMult=2.0
_01_CounterMult=1.0
_01_UseMacdConfirm=false
_01_MacdFast=12
_01_MacdSlow=26
_01_MacdSignal=9
_01_UseAvgRsi=false
_02_SlAtrMult=$slAtr
_02_SlMaxPips=600.0
_03_DistAtrMult=9
_03_MinDistPips=20.0
_04_TpUsd=15.0
_04_TpTargetMult=1.0
_04_PartialPct1=50.0
_04_PartialFrac1=0.3
_04_PartialPct2=75.0
_04_PartialFrac2=0.3
_05_LotMode=3
_05_BaseLot=0.01
_05_LinearStep=0.01
_05_MartMult=1.3
_05_LogFactor=5.0
_05_UseLnNotLog10=true
_06_MaxPositions=8
_06_MaxTotalLot=1.0
_06_DailyLossPct=5.0
_06_EmergencyDdPct=40.0
_07_Magic=990103
_07_Deviation=20
_07_AllowLive=false
"@ | Out-File $Path -Encoding ascii
}

$windows = @(
  @{tag="MAIN"; f="2023.01.01"; t="2026.01.01"},
  @{tag="BWD";  f="2020.01.01"; t="2023.01.01"}
)
$rsiBands = @(
  @{tag="RSI25_75"; os=25.0; ob=75.0},
  @{tag="RSI30_70"; os=30.0; ob=70.0},
  @{tag="RSI35_65"; os=35.0; ob=65.0}
)
$slWidths = @(15.0, 25.0, 35.0)

foreach ($band in $rsiBands) {
  foreach ($sl in $slWidths) {
    $tag = "$($band.tag)_SL$sl"
    $set = "$setDir\RSIMR_$tag.set"
    Write-BaseSet $set $band.os $band.ob $sl
    foreach ($w in $windows) {
      $rep = "RSIMR_L2_$($tag)_$($w.tag)"
      Write-Output "[$(Get-Date -Format s)] START $rep"
      & $run -Expert "(Boss)_RSI_MR_GridLog_rev01" -Symbol EURUSD -Period H1 `
          -FromDate $w.f -ToDate $w.t -Model 4 -SetFile $set -ReportName $rep `
          -Terminal "D:\Meta 5b\terminal64.exe" -DataDir "D:\Meta 5b" -Portable `
          -TimeoutSec 1800 | Out-Null
      $htm = "$repDir\$rep.htm"
      if (Test-Path $htm) {
        $s = Parse-Htm $htm
        Write-Output "[$(Get-Date -Format s)] DONE $rep -> PF=$($s.PF) Net=$($s.Net) Trades=$($s.Trades) DD=$($s.DDpct)% Win=$($s.Win)%"
        "`"$tag`",$($band.os),$($band.ob),$sl,`"$($w.tag)`",$($s.PF),$($s.Net),$($s.Trades),$($s.DDpct),$($s.Win)" | Add-Content $out
      } else {
        Write-Output "[$(Get-Date -Format s)] NO_REPORT $rep"
        "`"$tag`",$($band.os),$($band.ob),$sl,`"$($w.tag)`",,,,,NO_REPORT" | Add-Content $out
      }
    }
  }
}
Write-Output "LEVER2 SWEEP DONE -> $out"
