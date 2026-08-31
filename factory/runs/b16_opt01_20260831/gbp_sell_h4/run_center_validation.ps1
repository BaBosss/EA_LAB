$ErrorActionPreference='Stop'
$wt='D:\EA_LAB_CONTROL\worktrees\b16-gbp-sell-opt01-reanchor-20260831'
$root=Join-Path $wt 'factory\runs\b16_opt01_20260831\gbp_sell_h4'
$laneId='b16-gbp-sell-opt01-reanchor-20260831'
$terminal='D:\Meta 5b\terminal64.exe'
$dataDir='D:\Meta 5b'
$receiptRegistry='D:\EA_LAB_CONTROL\handoffs\LANE_H_BUILD_RECEIPT_REGISTRY_cf32ba8d.jsonl'
$receiptRegistrySha='6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8'
$set=Join-Path $root 'B16_GBP_SELL_H4_OPT01_CENTER_21_70.set'
$setSha='e98bc667a5384047991a1bfc674d84caefec381534834500b1a3db40652f6bc5'
$selection=Join-Path $root 'selection.json'
$selectionSha='8701d2fbe107c8f814875f34456adb34997f89c85b6f1827f9a2a9515ced1622'
$manifest=Join-Path $root 'validation_manifest.csv'
$log=Join-Path $root 'validation_execution_console.log'
$receipts=Join-Path $root 'validation_run_receipts.jsonl'

if(git -C $wt status --porcelain){throw 'worktree must be clean before fixed validation'}
$head=(git -C $wt rev-parse HEAD).Trim()
$lane=Get-Content "D:\EA_LAB_CONTROL\lanes\registry-v1\$laneId.json" -Raw | ConvertFrom-Json
if($lane.state -ne 'RUNNING' -or $lane.runtime_lane -ne 'MT5-lane2' -or $lane.head_sha -ne $head){throw 'runtime lane claim/head invalid'}
if((Get-FileHash $receiptRegistry -Algorithm SHA256).Hash.ToLower() -ne $receiptRegistrySha){throw 'receipt registry SHA mismatch'}
if((Get-FileHash $set -Algorithm SHA256).Hash.ToLower() -ne $setSha){throw 'fixed set SHA mismatch'}
if((Get-FileHash $selection -Algorithm SHA256).Hash.ToLower() -ne $selectionSha){throw 'selection SHA mismatch'}
$lock=Get-Content (Join-Path $root 'center_lock.json') -Raw | ConvertFrom-Json
if($lock.coarse_head -ne '0c0d35d5422e85115947e882694f73740766eebe' -or $lock.selected._16_RsiPeriod -ne 21 -or [double]$lock.selected._16_RsiHigh -ne 70.0 -or -not $lock.optimization_search_closed){throw 'center lock invalid'}
$assign=@(Get-Content $set | Where-Object {$_ -and -not $_.StartsWith(';') -and $_.Contains('=')})
$ydims=@($assign | Where-Object {$_ -match '\|\|Y$'})
if($assign.Count -ne 173 -or $ydims.Count -ne 0){throw "fixed set surface mismatch assignments=$($assign.Count) Y=$($ydims.Count)"}
if($assign -notcontains '_16_Direction=2' -or $assign -notcontains '_16_RsiPeriod=21' -or $assign -notcontains '_16_RsiHigh=70.0'){throw 'fixed center values missing'}
git -C $wt merge-base --is-ancestor '0c0d35d5422e85115947e882694f73740766eebe' $head | Out-Null
if($LASTEXITCODE -ne 0){throw 'coarse evidence head not ancestor of validation head'}
git -C $wt diff --quiet cf32ba8d32a8292e8f7b5ad2ef766e3442b20125 $head -- ea_template/Boss_16_KangarooGrid.mq5 ea_template/core
if($LASTEXITCODE -ne 0){throw 'relevant B16/core source bytes changed since accepted build ref'}
if(Test-Path $receipts){throw 'validation receipts already exist; replay is forbidden'}
$rows=@(Import-Csv $manifest)
if($rows.Count -ne 2 -or $rows[0].window -ne 'MAIN' -or $rows[1].window -ne 'BWD'){throw 'validation manifest invalid'}
$owned=Get-CimInstance Win32_Process | Where-Object { $_.Name -ieq 'terminal64.exe' -and $_.ExecutablePath -ieq $terminal }
if($owned){throw 'Meta5b terminal already running'}
[IO.File]::WriteAllText($log,'',(New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($receipts,'',(New-Object Text.UTF8Encoding($false)))
Push-Location $wt
try {
  foreach($row in $rows){
    $started=[DateTimeOffset]::UtcNow
    Add-Content -LiteralPath $log -Value ("RUN_START {0} {1}" -f $row.report_name,$started.ToString('o'))
    $output=& .\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_16_KangarooGrid' -Symbol $row.symbol -Period $row.tf `
      -FromDate $row.from -ToDate $row.to -SetFile $set -Model 1 -Deposit 10000 -Leverage 100 `
      -ReportName $row.report_name -Terminal $terminal -DataDir $dataDir -Portable `
      -BuildReceiptRegistry $receiptRegistry -LaneId $laneId 2>&1
    $code=$LASTEXITCODE
    $output | Add-Content -LiteralPath $log
    $ended=[DateTimeOffset]::UtcNow
    Add-Content -LiteralPath $log -Value ("RUN_END {0} code={1} {2}" -f $row.report_name,$code,$ended.ToString('o'))
    if($code -ne 0){throw "mechanical failure $($row.report_name) exit=$code"}
    $report=Join-Path $wt "_mt5_auto\reports\$($row.report_name).htm"
    $ini=Join-Path $wt "_mt5_auto\ini\$($row.report_name).ini"
    $lev=Join-Path $wt "_mt5_auto\reports\$($row.report_name).leverage_check.json"
    $trunc=Join-Path $wt "_mt5_auto\reports\$($row.report_name).truncation_check.json"
    foreach($p in @($report,$ini,$lev,$trunc)){if(-not(Test-Path $p -PathType Leaf)){throw "missing evidence $p"}}
    if((Get-Item $report).LastWriteTimeUtc -lt $started.UtcDateTime){throw "stale report mtime $($row.report_name)"}
    $cellDir=Join-Path $root ("validation\{0}" -f $row.window)
    New-Item -ItemType Directory -Force -Path $cellDir | Out-Null
    Copy-Item $report (Join-Path $cellDir 'report.htm') -Force
    Copy-Item $ini (Join-Path $cellDir 'tester.ini') -Force
    Copy-Item $lev (Join-Path $cellDir 'leverage_check.json') -Force
    Copy-Item $trunc (Join-Path $cellDir 'truncation_check.json') -Force
    $receipt=[ordered]@{schema='ea-lab-b16-opt01-fixed-validation/1';hypothesis_revision='B16-H05-r1';head_sha=$head;window=$row.window;symbol=$row.symbol;tf=$row.tf;from=$row.from;to=$row.to;report_name=$row.report_name;started_at=$started.ToString('o');ended_at=$ended.ToString('o');exit_code=$code;report_sha256=(Get-FileHash $report -Algorithm SHA256).Hash.ToLower();set_sha256=$setSha;build_receipt='br-4fa94d22907b446ebc721d524bdfa5d1';ex5_sha256='212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db';holdout='UNSPENT'}
    Add-Content -LiteralPath $receipts -Value ($receipt | ConvertTo-Json -Compress)
    Write-Host ("VALIDATION_ACCEPTED {0}" -f $row.window)
  }
} finally { Pop-Location }
Write-Host 'B16_OPT01_CENTER_VALIDATION_COMPLETE'