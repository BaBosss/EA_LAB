param(
  [Parameter(Mandatory)][string]$OutFile,
  [int]$SwingRadius = 3,
  [bool]$UseCross = $false,
  [int]$CrossWithinBars = 3
)
$lines = @(
  "_00_OptimizeMode=false",
  "_01_LookbackBars=60",
  "_01_SwingRadius=$SwingRadius",
  "_01_MinBarsApart=2",
  "_02_MacdFast=12",
  "_02_MacdSlow=44",
  "_02_MacdSignal=13",
  "_03_BufferAtrMult=0.15",
  "_03_AtrPeriod=18",
  "_05_LotSize=0.01",
  "_06_Magic=999094",
  "_06_Deviation=20",
  "_06_AllowLive=false",
  "_07_UseRsiGate=false",
  "_07_RsiPeriod=14",
  "_07_RsiBuyMax=45.0",
  "_07_RsiSellMin=55.0",
  "_08_UseMacdCross=$($UseCross.ToString().ToLower())",
  "_08_CrossWithinBars=$CrossWithinBars"
)
[IO.File]::WriteAllLines($OutFile, $lines)
Write-Output "wrote $OutFile"
