$ErrorActionPreference='Stop'
$wt='D:\EA_LAB_CONTROL\worktrees\b15-countbars-sens01-r2-20260831'
$run=Join-Path $wt 'factory\runs\b15_countbars_sens01_20260831'
$runner=Join-Path $wt 'scripts\mt5_run.ps1'
$receipt='D:\EA_LAB_CONTROL\handoffs\LANE_H_BUILD_RECEIPT_REGISTRY_cf32ba8d.jsonl'
$parent=Join-Path $wt 'ea_template\sets\regression\Boss_15_ST03_defaults.set'
$set1=Join-Path $run 'B15_COUNTBARS_1.set'
$set3=Join-Path $run 'B15_COUNTBARS_3.set'
$log=Join-Path $run 'execution_console.log'
$raw=Join-Path $run 'raw'

$head=(& git -C $wt rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0){throw 'cannot resolve lane HEAD'}
& git -C $wt merge-base --is-ancestor 'a10898e21f555f8074c693874bc5ca5cb25941cc' $head
if($LASTEXITCODE -ne 0){throw 'prereg commit is not an ancestor of lane HEAD'}
if(-not [string]::IsNullOrWhiteSpace((& git -C $wt status --porcelain))){throw 'lane worktree must be clean before MT5'}
New-Item -ItemType Directory -Force -Path $raw | Out-Null
'' | Set-Content -LiteralPath $log -Encoding utf8

$expectedEx5='f3dd7c5f2e2c1eb5a9f30a95a120e8977aa071e86f5ea4d9929e84f74940803a'
$actualEx5=(Get-FileHash -Algorithm SHA256 -LiteralPath 'D:\Meta 5c\MQL5\Experts\EALabTpl\Boss_15_ST03.ex5').Hash.ToLowerInvariant()
if($actualEx5 -ne $expectedEx5){throw "Meta5c EX5 identity mismatch: $actualEx5"}

$checks=@(
  @($parent,'ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c'),
  @($set1,'4fb0fc9ba11f0b9f762bd6115c447891447c74cea2021c9958dacbe9ae5df94c'),
  @($set3,'6834c47a4f7f43a2679c03dd237101f2b011ea155cb8fd9a4676837ef73d75e1')
)
foreach($c in $checks){$h=(Get-FileHash -Algorithm SHA256 -LiteralPath $c[0]).Hash.ToLowerInvariant(); if($h -ne $c[1]){throw "set identity mismatch: $($c[0])"}}
function Copy-CellArtifacts([string]$name){
  $reportDir=Join-Path $wt '_mt5_auto\reports'
  $iniDir=Join-Path $wt '_mt5_auto\ini'
  $dst=Join-Path $raw $name
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  $htm=Join-Path $reportDir ($name+'.htm')
  if(-not (Test-Path -LiteralPath $htm)){throw "missing fresh report: $htm"}
  $src=[IO.File]::OpenRead($htm)
  try{$o=[IO.File]::Create((Join-Path $dst 'report.htm.gz')); try{$gz=New-Object IO.Compression.GZipStream($o,[IO.Compression.CompressionMode]::Compress); try{$src.CopyTo($gz)}finally{$gz.Dispose()}}finally{$o.Dispose()}}finally{$src.Dispose()}
  foreach($suffix in @('leverage_check.json','truncation_check.json')){
    $p=Join-Path $reportDir ($name+'.'+$suffix)
    if(Test-Path -LiteralPath $p){Copy-Item -LiteralPath $p -Destination (Join-Path $dst $suffix) -Force}
  }
  $ini=Join-Path $iniDir ($name+'.ini')
  if(-not (Test-Path -LiteralPath $ini)){throw "missing tester ini: $ini"}
  Copy-Item -LiteralPath $ini -Destination (Join-Path $dst 'tester.ini') -Force
}

function Run-Cell([int]$count,[string]$symbol,[string]$window,[string]$from,[string]$to,[string]$set){
  $name="B15_COUNTBARS_SENS01_COUNT${count}_${symbol}_H4_${window}_M1"
  "RUN_START $name $([DateTimeOffset]::UtcNow.ToString('o'))" | Tee-Object -FilePath $log -Append
  & $runner -Expert 'EALabTpl\Boss_15_ST03' -Symbol $symbol -Period H4 -FromDate $from -ToDate $to `
    -SetFile $set -Model 1 -Deposit 10000 -Leverage 100 -ReportName $name `
    -Terminal 'D:\Meta 5c\terminal64.exe' -DataDir 'D:\Meta 5c' -Portable `
    -BuildReceiptRegistry $receipt -LaneId 'b15-countbars-sens01-20260831' 2>&1 | Tee-Object -FilePath $log -Append
  $code=$LASTEXITCODE
  "RUN_END $name code=$code $([DateTimeOffset]::UtcNow.ToString('o'))" | Tee-Object -FilePath $log -Append
  if($code -ne 0){throw "MT5 cell failed mechanically: $name exit=$code"}
  Copy-CellArtifacts $name
}
foreach($count in @(1,3)){
  $set=if($count -eq 1){$set1}else{$set3}
  Run-Cell $count 'GBPUSD' 'MAIN' '2023.01.01' '2025.12.31' $set
  Run-Cell $count 'GBPUSD' 'BWD'  '2020.01.01' '2022.12.31' $set
  Run-Cell $count 'USDJPY' 'MAIN' '2023.01.01' '2025.12.31' $set
  Run-Cell $count 'USDJPY' 'BWD'  '2020.01.01' '2022.12.31' $set
  Run-Cell $count 'EURUSD' 'MAIN' '2023.01.01' '2025.12.31' $set
  Run-Cell $count 'EURUSD' 'BWD'  '2020.01.01' '2022.12.31' $set
}
'B15_COUNTBARS_SENS01_SEQUENCE_COMPLETE' | Tee-Object -FilePath $log -Append
