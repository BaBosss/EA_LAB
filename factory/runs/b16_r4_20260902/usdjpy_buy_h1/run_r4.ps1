param([ValidateSet('CONTROL','MODEL4')][string]$Stage='CONTROL')
$ErrorActionPreference='Stop'
$wt='D:\EA_LAB_CONTROL\worktrees\chat2-b16-routing-0dc2bb88'
$root=Join-Path $wt 'factory\runs\b16_r4_20260902\usdjpy_buy_h1'
$laneId='b16-r4-execfidelity-runtime-20260902'
$terminal='D:\Meta 5\terminal64.exe'
$dataDir='C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355'
$receiptRegistry='D:\EA_LAB_CONTROL\handoffs\LANE_H_BUILD_RECEIPT_REGISTRY_cf32ba8d.jsonl'
$receiptRegistrySha='6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8'
$set=Join-Path $root 'B16_USDJPY_BUY_H1_R4_PARENT.set'
$setSha='7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782'
$ex5Sha='212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db'
$sourceEx5='D:\Meta 5b\MQL5\Experts\EALabTpl\Boss_16_KangarooGrid.ex5'
$primaryEx5=Join-Path $dataDir 'MQL5\Experts\EALabTpl\Boss_16_KangarooGrid.ex5'
$py=Join-Path $wt 'tools\python312\python.exe'
$manifest=Join-Path $root 'execution_manifest.csv'
$log=Join-Path $root 'execution_console.log'
$receipts=Join-Path $root 'run_receipts.jsonl'

function Get-Sha([string]$Path){
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return ''}
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower()
}
function Assert-Model4GlobalSerial {
  $active=@('RUNNING','REVIEW','FROZEN','INTEGRATING')
  $other=@(Get-ChildItem 'D:\EA_LAB_CONTROL\lanes\registry-v1' -Filter '*.json' | ForEach-Object {
    try { Get-Content $_.FullName -Raw | ConvertFrom-Json } catch { throw "registry parse failure: $($_.FullName)" }
  } | Where-Object { $_.lane_id -ne $laneId -and $_.writer -eq $true -and $active -contains $_.state -and -not [string]::IsNullOrWhiteSpace([string]$_.runtime_lane) })
  if($other.Count -gt 0){throw ('MODEL4_GLOBAL_SERIAL_CONFLICT: '+(($other | ForEach-Object {"$($_.lane_id):$($_.runtime_lane):$($_.state)"}) -join ','))}
  $watch=[Diagnostics.Stopwatch]::StartNew()
  do {
    $procs=@(Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('terminal64.exe','terminal.exe') })
    if($procs.Count -eq 0){break}
    Start-Sleep -Seconds 2
  } while($watch.Elapsed.TotalSeconds -lt 30)
  if($procs.Count -gt 0){throw ('MODEL4_GLOBAL_SERIAL_PROCESS_CONFLICT: '+(($procs | ForEach-Object {"$($_.Name):$($_.ExecutablePath)"}) -join ','))}
}

$head=(git -C $wt rev-parse HEAD).Trim()
$lanePath="D:\EA_LAB_CONTROL\lanes\registry-v1\$laneId.json"
if(-not(Test-Path $lanePath)){throw 'runtime lane record missing'}
$lane=Get-Content $lanePath -Raw | ConvertFrom-Json
if($lane.state -ne 'RUNNING' -or $lane.runtime_lane -ne 'MT5-lane1' -or $lane.head_sha -ne $head){throw 'runtime lane claim/head invalid'}
if((Get-Sha $receiptRegistry) -ne $receiptRegistrySha){throw 'receipt registry SHA mismatch'}
if((Get-Sha $set) -ne $setSha){throw 'R4 parent set SHA mismatch'}
if((Get-Sha $sourceEx5) -ne $ex5Sha){throw 'accepted source EX5 unavailable or changed'}
if(-not(Test-Path $py)){throw 'portable Python missing'}
$sameInstall=@(Get-CimInstance Win32_Process | Where-Object { $_.Name -ieq 'terminal64.exe' -and $_.ExecutablePath -ieq $terminal })
if($sameInstall){throw 'MT5-lane1 terminal already running'}

if($Stage -eq 'CONTROL'){
  if(Test-Path $receipts){throw 'R4 receipts already exist; control replay forbidden'}
  $before=Get-Sha $primaryEx5
  if($before -ne $ex5Sha){
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $primaryEx5) | Out-Null
    Copy-Item -LiteralPath $sourceEx5 -Destination $primaryEx5 -Force
  }
  $after=Get-Sha $primaryEx5
  if($after -ne $ex5Sha){throw 'primary MT5 exact EX5 provisioning failed'}
  $preflight=[ordered]@{schema='ea-lab-b16-r4-runtime-preflight/1';head_sha=$head;runtime_lane='MT5-lane1';terminal=$terminal;data_dir=$dataDir;primary_ex5_preexisting_sha256=$before;accepted_source_ex5=$sourceEx5;accepted_ex5_sha256=$ex5Sha;primary_ex5_after_sha256=$after;set_sha256=$setSha;build_receipt='br-4fa94d22907b446ebc721d524bdfa5d1';provisioned_exact_binary=($before -ne $after);holdout='UNSPENT'}
  [IO.File]::WriteAllText((Join-Path $root 'runtime_preflight.json'),($preflight|ConvertTo-Json -Depth 5)+"`n",(New-Object Text.UTF8Encoding($false)))
  [IO.File]::WriteAllText($log,'',(New-Object Text.UTF8Encoding($false)))
  [IO.File]::WriteAllText($receipts,'',(New-Object Text.UTF8Encoding($false)))
}else{
  if((Get-Sha $primaryEx5) -ne $ex5Sha){throw 'primary EX5 changed after control lineage'}
  if(-not(Test-Path (Join-Path $root 'evidence_summary.json'))){throw 'control analysis missing'}
  $summary=Get-Content (Join-Path $root 'evidence_summary.json') -Raw | ConvertFrom-Json
  if(-not $summary.model1_control_pass){throw "Model1 control not passed: $($summary.classification)"}
  Assert-Model4GlobalSerial
}
$rows=@(Import-Csv $manifest | Where-Object {$_.stage -eq $Stage})
if($rows.Count -ne 2){throw "expected 2 rows for stage $Stage, got $($rows.Count)"}
Push-Location $wt
try {
  foreach($row in $rows){
    $tag="M$($row.model)_$($row.window)"
    $cellDir=Join-Path $root "runtime\$tag"
    if(Test-Path $cellDir){throw "cell already exists; replay forbidden: $tag"}
    $started=[DateTimeOffset]::UtcNow
    Add-Content -LiteralPath $log -Value ("RUN_START {0} model={1} {2}" -f $row.report_name,$row.model,$started.ToString('o'))
    $output=& .\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_16_KangarooGrid' -Symbol $row.symbol -Period $row.tf `
      -FromDate $row.from -ToDate $row.to -SetFile $set -Model ([int]$row.model) -Deposit 10000 -Leverage 100 `
      -ReportName $row.report_name -Terminal $terminal -DataDir $dataDir -BuildReceiptRegistry $receiptRegistry -LaneId $laneId 2>&1
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
    if($Stage -eq 'MODEL4'){
      $otherTerm=@(Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('terminal64.exe','terminal.exe') })
      if($otherTerm.Count -gt 0){throw 'terminal process persisted after Model4 cell'}
    }
    New-Item -ItemType Directory -Force -Path $cellDir | Out-Null
    Copy-Item $report (Join-Path $cellDir 'report.htm')
    Copy-Item $ini (Join-Path $cellDir 'tester.ini')
    Copy-Item $lev (Join-Path $cellDir 'leverage_check.json')
    Copy-Item $trunc (Join-Path $cellDir 'truncation_check.json')
    $ys=& $py .\scripts\report_year_split.py (Join-Path $cellDir 'report.htm') 2>&1
    if($LASTEXITCODE -ne 0){throw "year split failed for $tag"}
    [IO.File]::WriteAllLines((Join-Path $cellDir 'year_split.txt'),[string[]]$ys,(New-Object Text.UTF8Encoding($false)))
    $receipt=[ordered]@{schema='ea-lab-b16-r4-run/1';hypothesis_revision='B16-R4-r1';head_sha=$head;runtime_lane='MT5-lane1';stage=$Stage;model=[int]$row.model;window=$row.window;symbol=$row.symbol;tf=$row.tf;from=$row.from;to=$row.to;report_name=$row.report_name;started_at=$started.ToString('o');ended_at=$ended.ToString('o');exit_code=$code;report_sha256=(Get-Sha $report);set_sha256=$setSha;build_receipt='br-4fa94d22907b446ebc721d524bdfa5d1';ex5_sha256=$ex5Sha;holdout='UNSPENT'}
    Add-Content -LiteralPath $receipts -Value ($receipt | ConvertTo-Json -Compress)
    Write-Host ("R4_CELL_ACCEPTED {0} model={1}" -f $row.window,$row.model)
    if($Stage -eq 'MODEL4' -and $row.window -eq 'MAIN'){Assert-Model4GlobalSerial}
  }
} finally { Pop-Location }
& $py (Join-Path $root 'analyze_r4.py')
if($LASTEXITCODE -ne 0){throw 'R4 analysis failed'}
Write-Host ("B16_R4_STAGE_COMPLETE {0}" -f $Stage)
