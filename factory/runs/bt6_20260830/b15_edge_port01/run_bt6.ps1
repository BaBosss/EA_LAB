$ErrorActionPreference='Stop'
$wt='D:\EA_LAB_CONTROL\worktrees\bt6-b15-edge-port01'
$run=Join-Path $wt 'factory\runs\bt6_20260830\b15_edge_port01'
$log=Join-Path $run 'execution_console.log'
$parent=Join-Path $wt 'ea_template\sets\regression\Boss_15_ST03_defaults.set'
$child=Join-Path $run 'B15_EDGE_PORT_01.set'
$receipt='D:\EA_LAB_CONTROL\handoffs\LANE_H_BUILD_RECEIPT_REGISTRY_cf32ba8d.jsonl'
$runner=Join-Path $wt 'scripts\mt5_run.ps1'
'' | Set-Content -LiteralPath $log -Encoding utf8
function Run-Cell([string]$variant,[string]$symbol,[string]$window,[string]$from,[string]$to,[string]$set){
  $name="BT6_B15_EDGE_PORT01_${variant}_${symbol}_H4_${window}_M1"
  "RUN_START $name $([DateTimeOffset]::UtcNow.ToString('o'))" | Tee-Object -FilePath $log -Append
  & $runner -Expert 'EALabTpl\Boss_15_ST03' -Symbol $symbol -Period H4 -FromDate $from -ToDate $to `
    -SetFile $set -Model 1 -Deposit 10000 -Leverage 100 -ReportName $name `
    -Terminal 'D:\Meta 5c\terminal64.exe' -DataDir 'D:\Meta 5c' -Portable `
    -BuildReceiptRegistry $receipt -LaneId 'bt6-b15-edge-port01-runtime-20260830' 2>&1 | Tee-Object -FilePath $log -Append
  $code=$LASTEXITCODE; "RUN_END $name code=$code $([DateTimeOffset]::UtcNow.ToString('o'))" | Tee-Object -FilePath $log -Append
  if($code -ne 0){throw "MT5 cell failed mechanically: $name exit=$code"}
}
Run-Cell 'PARENT' 'USDJPY' 'MAIN' '2023.01.01' '2025.12.31' $parent
Run-Cell 'PARENT' 'USDJPY' 'BWD'  '2020.01.01' '2022.12.31' $parent
Run-Cell 'CHILD'  'USDJPY' 'MAIN' '2023.01.01' '2025.12.31' $child
Run-Cell 'CHILD'  'USDJPY' 'BWD'  '2020.01.01' '2022.12.31' $child
Run-Cell 'PARENT' 'EURUSD' 'MAIN' '2023.01.01' '2025.12.31' $parent
Run-Cell 'PARENT' 'EURUSD' 'BWD'  '2020.01.01' '2022.12.31' $parent
Run-Cell 'CHILD'  'EURUSD' 'MAIN' '2023.01.01' '2025.12.31' $child
Run-Cell 'CHILD'  'EURUSD' 'BWD'  '2020.01.01' '2022.12.31' $child
$raw=Join-Path $run 'raw'; New-Item -ItemType Directory -Force $raw | Out-Null
Get-ChildItem (Join-Path $wt '_mt5_auto\reports') -Filter 'BT6_B15_EDGE_PORT01_*' -File | ForEach-Object {
 if($_.Extension -eq '.htm'){$dst=Join-Path $raw ($_.Name+'.gz'); $src=[IO.File]::OpenRead($_.FullName); try{$o=[IO.File]::Create($dst); try{$gz=New-Object IO.Compression.GZipStream($o,[IO.Compression.CompressionMode]::Compress); try{$src.CopyTo($gz)}finally{$gz.Dispose()}}finally{$o.Dispose()}}finally{$src.Dispose()}}
 elseif($_.Extension -eq '.json'){Copy-Item $_.FullName $raw -Force}
}
Get-ChildItem (Join-Path $wt '_mt5_auto\ini') -Filter 'BT6_B15_EDGE_PORT01_*.ini' -File | Copy-Item -Destination $raw -Force
'BT6_SEQUENCE_COMPLETE' | Tee-Object -FilePath $log -Append
