$ErrorActionPreference='Stop'
$wt='D:\EA_LAB_CONTROL\worktrees\ct-b16-earlyzone01-20260910'
$d=Join-Path $wt 'factory\runs\b16_earlyzone01_20260910'
$terminal='D:\Meta 5c\terminal64.exe'; $data='D:\Meta 5c'
$registry='D:\EA_LAB_CONTROL\handoffs\LANE_H_BUILD_RECEIPT_REGISTRY_cf32ba8d.jsonl'
$lane='ct-b16-earlyzone01-20260910'
$parent=Join-Path $d 'B16_XAU_M15_EARLYZONE01_PARENT.set'; $child=Join-Path $d 'B16_XAU_M15_EARLYZONE01_CHILD.set'
$parentSha='7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782'
$childSha='551385b8a1b16141f3924315988bdf101d12a6aee2246ac1eb59ff1ba16ad88f'
$ex5='D:\Meta 5c\MQL5\Experts\EALabTpl\Boss_16_KangarooGrid.ex5'; $ex5Sha='212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db'
if((Get-FileHash $parent -Algorithm SHA256).Hash.ToLower() -ne $parentSha){throw 'parent set identity mismatch'}
if((Get-FileHash $child -Algorithm SHA256).Hash.ToLower() -ne $childSha){throw 'child set identity mismatch'}
if((Get-FileHash $ex5 -Algorithm SHA256).Hash.ToLower() -ne $ex5Sha){throw 'EX5 identity mismatch'}
$lr=Get-Content "D:\EA_LAB_CONTROL\lanes\registry-v1\$lane.json" -Raw | ConvertFrom-Json
if($lr.state -ne 'RUNNING' -or $lr.head_sha -ne '9b26192acb54c61c98e055272e0f7b2945b93c4b' -or $lr.runtime_lane -ne 'D:\Meta 5c'){throw 'lane identity mismatch'}
if(Get-CimInstance Win32_Process | Where-Object {$_.Name -ieq 'terminal64.exe' -and $_.ExecutablePath -ieq $terminal}){throw 'Meta5c already running'}
$rows=@(
 @{arm='PARENT';window='MAIN';from='2023.01.01';to='2025.12.31';set=$parent},
 @{arm='CHILD';window='MAIN';from='2023.01.01';to='2025.12.31';set=$child},
 @{arm='PARENT';window='BWD';from='2020.01.01';to='2022.12.31';set=$parent},
 @{arm='CHILD';window='BWD';from='2020.01.01';to='2022.12.31';set=$child}
)
$log=Join-Path $d 'execution_console.log'
$receipts=Join-Path $d 'run_receipts.jsonl'
[IO.File]::WriteAllText($log,'')
[IO.File]::WriteAllText($receipts,'')
foreach($r in $rows){
 $name="B16_EARLYZONE01_$($r.arm)_XAUUSD_M15_$($r.window)_M1"
 $started=[DateTimeOffset]::UtcNow
 Add-Content $log ("RUN_START {0} {1}" -f $name,$started.ToString('o'))
 $out=& (Join-Path $wt 'scripts\mt5_run.ps1') -Expert 'EALabTpl\Boss_16_KangarooGrid' -Symbol 'XAUUSD' -Period 'M15' -FromDate $r.from -ToDate $r.to -SetFile $r.set -Model 1 -Deposit 10000 -Leverage 100 -ReportName $name -Terminal $terminal -DataDir $data -Portable -BuildReceiptRegistry $registry -LaneId $lane 2>&1
 $code=$LASTEXITCODE
 $out | Tee-Object -FilePath $log -Append | Out-Host
 $ended=[DateTimeOffset]::UtcNow
 Add-Content $log ("RUN_END {0} code={1} {2}" -f $name,$code,$ended.ToString('o'))
 if($code -ne 0){throw "mt5_run failed $name exit=$code"}
 $report=Join-Path $wt "_mt5_auto\reports\$name.htm"
 $ini=Join-Path $wt "_mt5_auto\ini\$name.ini"
 $lev=Join-Path $wt "_mt5_auto\reports\$name.leverage_check.json"
 $trunc=Join-Path $wt "_mt5_auto\reports\$name.truncation_check.json"
 foreach($p in @($report,$ini,$lev,$trunc)){if(-not(Test-Path $p -PathType Leaf)){throw "missing evidence $p"}}
 if((Get-Item $report).LastWriteTimeUtc -lt $started.UtcDateTime){throw "stale report $name"}
 $cell=Join-Path $d "runtime\$($r.arm)\$($r.window)"
 New-Item -ItemType Directory -Force -Path $cell | Out-Null
 Copy-Item $report (Join-Path $cell 'report.htm') -Force
 Copy-Item $ini (Join-Path $cell 'tester.ini') -Force
 Copy-Item $lev (Join-Path $cell 'leverage_check.json') -Force
 Copy-Item $trunc (Join-Path $cell 'truncation_check.json') -Force
 $rec=[ordered]@{schema='ea-lab-b16-earlyzone01-run/1';arm=$r.arm;window=$r.window;from=$r.from;to=$r.to;started_at=$started.ToString('o');ended_at=$ended.ToString('o');exit_code=$code;set_sha256=(Get-FileHash $r.set -Algorithm SHA256).Hash.ToLower();report_sha256=(Get-FileHash $report -Algorithm SHA256).Hash.ToLower();ex5_sha256=$ex5Sha;installation=$data;model=1;optimization=0;deposit=10000;leverage=100}
 Add-Content $receipts ($rec|ConvertTo-Json -Compress)
 Write-Host "ACCEPTED_RAW $($r.arm) $($r.window)"
}
Write-Host 'EARLYZONE01_RUNTIME_COMPLETE'
