$ErrorActionPreference='Stop'
$wt='D:\EA_LAB_CONTROL\worktrees\b16-h07-depth3-20260831'
$root=Join-Path $wt 'factory\runs\b16_h07_20260831\gbp_sell_h4_depth3'
$receiptRegistry='D:\EA_LAB_CONTROL\handoffs\LANE_H_BUILD_RECEIPT_REGISTRY_cf32ba8d.jsonl'
$receiptSha='6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8'
$laneId='b16-h07-depth3-runtime-20260831'
$terminal='D:\Meta 5b\terminal64.exe'
$dataDir='D:\Meta 5b'
$expectedSet='3dbcf63f002a0bfad0371c5f26acf7156a6eabc8820f31a0d67f663f24f3edd5'
$log=Join-Path $root 'execution_console.log'
$receipts=Join-Path $root 'run_receipts.jsonl'
Set-Content -LiteralPath $log -Value '' -Encoding UTF8
Set-Content -LiteralPath $receipts -Value '' -Encoding UTF8
if((Get-FileHash $receiptRegistry -Algorithm SHA256).Hash.ToLower() -ne $receiptSha){throw 'receipt registry SHA mismatch'}
$lane=Get-Content "D:\EA_LAB_CONTROL\lanes\registry-v1\$laneId.json" -Raw | ConvertFrom-Json
if($lane.state -ne 'RUNNING' -or $lane.runtime_lane -ne 'MT5-lane2'){throw 'runtime lane claim invalid'}
$owned=Get-CimInstance Win32_Process | Where-Object { $_.Name -ieq 'terminal64.exe' -and $_.ExecutablePath -ieq $terminal }
if($owned){throw 'Meta5b terminal already running'}
$rows=@(Import-Csv (Join-Path $root 'execution_manifest.csv'))
if($rows.Count -ne 2){throw "expected 2 cells, got $($rows.Count)"}
Push-Location $wt
try {
  foreach($row in $rows){
    $set=Join-Path $wt ($row.set -replace '/','\')
    if((Get-FileHash $set -Algorithm SHA256).Hash.ToLower() -ne $expectedSet){throw 'set SHA mismatch'}
    $started=[DateTimeOffset]::UtcNow
    Add-Content $log ("RUN_START {0} {1}" -f $row.report_name,$started.ToString('o'))
    $output=& .\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_16_KangarooGrid' -Symbol $row.symbol -Period $row.tf `
      -FromDate $row.from -ToDate $row.to -SetFile $set -Model 1 -Deposit 10000 -Leverage 100 `
      -ReportName $row.report_name -Terminal $terminal -DataDir $dataDir -Portable `
      -BuildReceiptRegistry $receiptRegistry -LaneId $laneId 2>&1
    $code=$LASTEXITCODE
    $output | Add-Content $log
    $ended=[DateTimeOffset]::UtcNow
    Add-Content $log ("RUN_END {0} code={1} {2}" -f $row.report_name,$code,$ended.ToString('o'))
    if($code -ne 0){throw "mechanical failure $($row.report_name) exit=$code"}
    $report=Join-Path $wt "_mt5_auto\reports\$($row.report_name).htm"
    $ini=Join-Path $wt "_mt5_auto\ini\$($row.report_name).ini"
    $lev=Join-Path $wt "_mt5_auto\reports\$($row.report_name).leverage_check.json"
    $trunc=Join-Path $wt "_mt5_auto\reports\$($row.report_name).truncation_check.json"
    foreach($p in @($report,$ini,$lev,$trunc)){if(-not(Test-Path $p -PathType Leaf)){throw "missing evidence $p"}}
    if((Get-Item $report).LastWriteTimeUtc -lt $started.UtcDateTime){throw "stale report mtime $($row.report_name)"}
    $cellDir=Join-Path $root ("runtime\{0}\{1}" -f $row.context,$row.window)
    New-Item -ItemType Directory -Force -Path $cellDir | Out-Null
    Copy-Item $report (Join-Path $cellDir 'report.htm') -Force
    Copy-Item $ini (Join-Path $cellDir 'tester.ini') -Force
    Copy-Item $lev (Join-Path $cellDir 'leverage_check.json') -Force
    Copy-Item $trunc (Join-Path $cellDir 'truncation_check.json') -Force
    $receipt=[ordered]@{schema='ea-lab-b16-h07-depth3-run/1';context=$row.context;symbol=$row.symbol;tf=$row.tf;window=$row.window;from=$row.from;to=$row.to;report_name=$row.report_name;started_at=$started.ToString('o');ended_at=$ended.ToString('o');exit_code=$code;report_sha256=(Get-FileHash $report -Algorithm SHA256).Hash.ToLower();set_sha256=(Get-FileHash $set -Algorithm SHA256).Hash.ToLower();build_receipt='br-4fa94d22907b446ebc721d524bdfa5d1';ex5_sha256='212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db'}
    Add-Content $receipts ($receipt | ConvertTo-Json -Compress)
    Write-Host ("ACCEPTED {0} {1}" -f $row.context,$row.window)
  }
} finally { Pop-Location }
Write-Host 'B16_H07_DEPTH3_COMPLETE'