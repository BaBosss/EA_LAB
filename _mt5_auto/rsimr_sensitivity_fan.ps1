# RSI-MR (990103) ORDER-183 follow-up: +-20% single-axis sensitivity fan around the new
# center (RSI25/75 + SL25 + DistAtrMult=9, ORDER-183 winner) -- LADDER Step 5, INCLUDING
# the frozen spacing axis (DistAtrMult) per the skill's explicit rule. Continuous MAIN+BWD,
# full-pinned, D:\Meta 5b.
$ErrorActionPreference = "Continue"
$run = "D:\EA_LAB\scripts\mt5_run.ps1"
$setDir = "D:\EA_LAB\_mt5_auto\ab_sets\rsimr_fan"
$repDir = "D:\EA_LAB\_mt5_auto\reports"
$out = "D:\EA_LAB\_mt5_auto\RSIMR_SENS_FAN.csv"
New-Item -ItemType Directory -Force $setDir | Out-Null
'"tag","axis","rsi_os","rsi_ob","sl_atr","dist_atr","window","pf","net","trades","dd_pct","win_pct"' | Out-File $out -Encoding utf8

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

function Write-BaseSet($Path, $rsiOs, $rsiOb, $slAtr, $distAtr) {
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
_03_DistAtrMult=$distAtr
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
# center = os25 ob75 sl25 dist9. fan each axis +-20% one at a time, others held at center.
$cells = @(
  @{tag="CENTER";      os=25.0; ob=75.0; sl=25.0; dist=9},
  @{tag="RSI_OS_LOW";  os=20.0; ob=75.0; sl=25.0; dist=9},
  @{tag="RSI_OS_HIGH"; os=30.0; ob=75.0; sl=25.0; dist=9},
  @{tag="RSI_OB_LOW";  os=25.0; ob=60.0; sl=25.0; dist=9},
  @{tag="RSI_OB_HIGH"; os=25.0; ob=90.0; sl=25.0; dist=9},
  @{tag="SL_LOW";      os=25.0; ob=75.0; sl=20.0; dist=9},
  @{tag="SL_HIGH";     os=25.0; ob=75.0; sl=30.0; dist=9},
  @{tag="DIST_LOW";    os=25.0; ob=75.0; sl=25.0; dist=7},
  @{tag="DIST_HIGH";   os=25.0; ob=75.0; sl=25.0; dist=11}
)

foreach ($c in $cells) {
  $set = "$setDir\RSIMR_$($c.tag).set"
  Write-BaseSet $set $c.os $c.ob $c.sl $c.dist
  foreach ($w in $windows) {
    $rep = "RSIMR_FAN_$($c.tag)_$($w.tag)"
    Write-Output "[$(Get-Date -Format s)] START $rep"
    & $run -Expert "(Boss)_RSI_MR_GridLog_rev01" -Symbol EURUSD -Period H1 `
        -FromDate $w.f -ToDate $w.t -Model 4 -SetFile $set -ReportName $rep `
        -Terminal "D:\Meta 5b\terminal64.exe" -DataDir "D:\Meta 5b" -Portable `
        -TimeoutSec 1800 | Out-Null
    $htm = "$repDir\$rep.htm"
    if (Test-Path $htm) {
      $s = Parse-Htm $htm
      Write-Output "[$(Get-Date -Format s)] DONE $rep -> PF=$($s.PF) Net=$($s.Net) Trades=$($s.Trades) DD=$($s.DDpct)% Win=$($s.Win)%"
      "`"$($c.tag)`",`"$($c.tag)`",$($c.os),$($c.ob),$($c.sl),$($c.dist),`"$($w.tag)`",$($s.PF),$($s.Net),$($s.Trades),$($s.DDpct),$($s.Win)" | Add-Content $out
    } else {
      Write-Output "[$(Get-Date -Format s)] NO_REPORT $rep"
      "`"$($c.tag)`",`"$($c.tag)`",$($c.os),$($c.ob),$($c.sl),$($c.dist),`"$($w.tag)`",,,,,NO_REPORT" | Add-Content $out
    }
  }
}
Write-Output "SENSITIVITY FAN DONE -> $out"
