$ErrorActionPreference='Stop'
$wt='D:\EA_LAB_CONTROL\worktrees\b16-gbp-sell-opt01-20260831'
$root=Join-Path $wt 'factory\runs\b16_opt01_20260831\gbp_sell_h4'
$laneId='b16-gbp-sell-opt01-20260831'
$terminal='D:\Meta 5b\terminal64.exe'
$dataDir='D:\Meta 5b'
$receiptRegistry='D:\EA_LAB_CONTROL\handoffs\LANE_H_BUILD_RECEIPT_REGISTRY_cf32ba8d.jsonl'
$receiptRegistrySha='6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8'
$set=Join-Path $root 'B16_GBP_SELL_H4_OPT01.set'
$setSha='d582f4d42350aa83f0c01bd5b6b90a1f044f40a61de1347d4952db86b9a521a1'
$reportName='B16_OPT01_GBPUSD_H4_MAIN_M1'
$decisionLog=Join-Path $wt 'factory\optimize_decisions.jsonl'
$log=Join-Path $root 'execution_console.log'
$receiptPath=Join-Path $root 'optimization_receipt.json'

if(git -C $wt status --porcelain){throw 'worktree must be clean before optimizer launch'}
$head=(git -C $wt rev-parse HEAD).Trim()
$lane=Get-Content "D:\EA_LAB_CONTROL\lanes\registry-v1\$laneId.json" -Raw | ConvertFrom-Json
if($lane.state -ne 'RUNNING' -or $lane.runtime_lane -ne 'MT5-lane2' -or $lane.head_sha -ne $head){throw 'runtime lane claim/head invalid'}
if((Get-FileHash $receiptRegistry -Algorithm SHA256).Hash.ToLower() -ne $receiptRegistrySha){throw 'receipt registry SHA mismatch'}
if((Get-FileHash $set -Algorithm SHA256).Hash.ToLower() -ne $setSha){throw 'optimize set SHA mismatch'}
$assign=@(Get-Content $set | Where-Object {$_ -and -not $_.StartsWith(';') -and $_.Contains('=')})
$ydims=@($assign | Where-Object {$_ -match '\|\|Y$'})
if($assign.Count -ne 173 -or $ydims.Count -ne 2){throw "set surface mismatch assignments=$($assign.Count) Y=$($ydims.Count)"}
if($ydims[0] -notmatch '^_16_RsiPeriod=14\|\|7\|\|7\|\|28\|\|Y$' -or $ydims[1] -notmatch '^_16_RsiHigh=70\.0\|\|60\|\|5\|\|80\|\|Y$'){throw 'unexpected optimize dimensions'}
git -C $wt diff --quiet cf32ba8d32a8292e8f7b5ad2ef766e3442b20125 $head -- ea_template/Boss_16_KangarooGrid.mq5 ea_template/core
if($LASTEXITCODE -ne 0){throw 'relevant B16/core source bytes changed since accepted build ref'}
$owned=Get-CimInstance Win32_Process | Where-Object { $_.Name -ieq 'terminal64.exe' -and $_.ExecutablePath -ieq $terminal }
if($owned){throw 'Meta5b terminal already running'}
$beforeLines=if(Test-Path $decisionLog){@(Get-Content $decisionLog).Count}else{0}
$started=[DateTimeOffset]::UtcNow
Push-Location $wt
try {
  $out=& .\scripts\mt5_optimize.ps1 -Expert 'EALabTpl\Boss_16_KangarooGrid' -Symbol GBPUSD -Period H4 `
    -FromDate 2023.01.01 -ToDate 2025.12.31 -SetFile $set -Model 1 -Optimization 2 -Criterion 7 `
    -Deposit 10000 -Leverage 100 -ReportName $reportName -Terminal $terminal -DataDir $dataDir -Portable `
    -BuildReceiptRegistry $receiptRegistry -HypothesisRevision 'B16-H05-r1' -GuardBuild 16 -LaneId $laneId 2>&1
  $code=$LASTEXITCODE
} finally { Pop-Location }
$ended=[DateTimeOffset]::UtcNow
$out | Set-Content -LiteralPath $log -Encoding UTF8
if($code -ne 0){throw "optimizer launcher failed exit=$code"}
$xml=Join-Path $wt "_mt5_auto\optimizations\$reportName.xml"
$ini=Join-Path $wt "_mt5_auto\ini\$reportName.ini"
foreach($p in @($xml,$ini)){if(-not(Test-Path $p -PathType Leaf)){throw "missing optimizer evidence $p"}}
if((Get-Item $xml).LastWriteTimeUtc -lt $started.UtcDateTime){throw 'optimizer XML is stale'}
Copy-Item $xml (Join-Path $root 'optimizer.xml') -Force
Copy-Item $ini (Join-Path $root 'tester.ini') -Force
$added=@(Get-Content $decisionLog | Select-Object -Skip $beforeLines)
$mine=@($added | ForEach-Object { try {$_|ConvertFrom-Json}catch{$null} } | Where-Object {$_ -and $_.hypothesis_revision -eq 'B16-H05-r1' -and $_.lane -eq $terminal})
if($mine.Count -ne 1){throw "expected exactly one H05 guard decision row, got $($mine.Count)"}
[IO.File]::WriteAllText((Join-Path $root 'guard_decision.json'),($mine[0]|ConvertTo-Json -Depth 12),(New-Object Text.UTF8Encoding($false)))
$receipt=[ordered]@{schema='ea-lab-b16-opt01-run/1';hypothesis_revision='B16-H05-r1';head_sha=$head;started_at=$started.ToString('o');ended_at=$ended.ToString('o');exit_code=$code;logical_symbol='GBPUSD';tester_symbol='GBPUSD';tf='H4';window='MAIN';from='2023.01.01';to='2025.12.31';model=1;optimization=2;criterion=7;set_sha256=$setSha;xml_sha256=(Get-FileHash $xml -Algorithm SHA256).Hash.ToLower();build_receipt='br-4fa94d22907b446ebc721d524bdfa5d1';ex5_sha256='212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db';receipt_registry_sha256=$receiptRegistrySha;holdout='UNSPENT'}
[IO.File]::WriteAllText($receiptPath,($receipt|ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
Write-Host "B16_OPT01_COMPLETE xml_sha=$($receipt.xml_sha256)"