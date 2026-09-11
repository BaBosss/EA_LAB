$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$refresh=Join-Path $repo 'scripts/mobile_monitor_refresh.ps1'
$health=Join-Path $repo 'scripts/monitor_health_snapshot.ps1'
$sha=(& git -C $repo rev-parse HEAD).Trim()
$root=Join-Path ([IO.Path]::GetTempPath()) ('ea_mobile_operational_test_'+[guid]::NewGuid().ToString('N'))
function Assert-True([bool]$Value,[string]$Message){if(-not $Value){throw "ASSERT: $Message"}}
function Write-Text([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false)))}
New-Item -ItemType Directory -Path $root | Out-Null
try{
    $runtime=Join-Path $root 'runtime';$portfolio=Join-Path $runtime 'portfolio'
    $registry=Join-Path $root 'registry'
    New-Item -ItemType Directory -Path $portfolio,$registry | Out-Null
    Write-Text (Join-Path $runtime 'fixture.txt') 'runtime lineage fixture'
    & git -C $runtime init -q
    & git -C $runtime -c user.name=Fixture -c user.email=fixture@example.invalid add fixture.txt
    & git -C $runtime -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm fixture
    Assert-True ($LASTEXITCODE -eq 0) 'runtime fixture commit'
    $runtimeSha=(& git -C $runtime rev-parse HEAD).Trim()
    # Evaluate the actual producer metadata expressions without running collectors.
    $producerSource=Get-Content (Join-Path $repo 'scripts/control_room_snapshot.ps1') -Raw
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseInput($producerSource,[ref]$tokens,[ref]$errors)
    $meta=$ast.FindAll({param($n) $n -is [Management.Automation.Language.HashtableAst]},$true) | Where-Object {
        @($_.KeyValuePairs | Where-Object {$_.Item1.Extent.Text -eq 'generated_at'}).Count -gt 0
    } | Select-Object -Last 1
    Assert-True ($null -ne $meta) 'actual producer metadata located'
    $expressions=@{};foreach($pair in $meta.KeyValuePairs){$expressions[$pair.Item1.Extent.Text]=$pair.Item2.Extent.Text}
    $producerMeta=& { param($Root,$expressions)
        $now=([datetime]'2026-09-10T12:00:00Z').ToLocalTime()
        @{stamp=(& ([scriptblock]::Create($expressions.generated_at)));head=(& ([scriptblock]::Create($expressions.git_head)))}
    } $runtime $expressions
    Assert-True ($producerMeta.head -ceq $runtimeSha) 'snapshot producer full exact SHA'
    Assert-True ($producerMeta.stamp -ceq '2026-09-10T12:00:00Z') 'snapshot producer UTC seconds'
    $unknownHead=& {param($Root,$expression) & ([scriptblock]::Create($expression))} $registry $expressions.git_head
    Assert-True (-not $unknownHead -or $unknownHead -eq 'UNKNOWN') 'unresolved producer Git must not invent identity'
    $stamp='2026-09-10T12:00:00Z'
    $cr=Join-Path $portfolio 'control_room_snapshot.json'
    Write-Text $cr (@{meta=@{generated_at=$stamp;git_head=$runtimeSha};system_health=@(@{account='SECRET_ACCOUNT_123456789';state='FRESH';governance_scope='LAB_MANAGED'});floating_risk=@()} | ConvertTo-Json -Depth 6)
    $success=Join-Path $portfolio 'daily_monitor_last_success.txt'
    Write-Text $success $stamp
    $projection=Join-Path $root 'safe_projection.json'
    Write-Text $projection '{"entity":"SafeProjection","build_id":"0123456789abcdef","generated_at":"2026-09-10T12:00:00","accounts":[],"findings":[]}'
    $outHealth=Join-Path $root 'health.json'
    & $health -RepoRoot $runtime -ExpectedCanonicalSha $sha -OutFile $outHealth -AsOf ([datetimeoffset]$stamp)
    $j=Get-Content -LiteralPath $outHealth -Raw | ConvertFrom-Json
    Assert-True ($j.repo_head -eq $runtimeSha -and $j.canonical_binding -eq 'DIFFERENT_REPO_HEAD' -and $j.status -eq 'DEGRADED') 'runtime mismatch must not be rebound to canonical'
    Assert-True ($j.snapshot_revision.binding_state -eq 'MATCHES_RUNTIME_HEAD') 'snapshot producer revision must be observed separately'
    Assert-True (@($j.sources | Where-Object { $_.name -eq 'control_room_snapshot' -and $_.state -eq 'CURRENT' }).Count -eq 1) 'qualified current control-room observation'
    $inputHash=(Get-FileHash -LiteralPath $cr -Algorithm SHA256).Hash
    $parameters=@{RepoRoot=$repo;CanonicalRef=$sha;ExpectedSha=$sha;LaneRegistryPath=$registry;SafeProjectionPath=$projection;MonitoringSourceRoot=$runtime;AsOf=[datetimeoffset]$stamp}
    # Run the real preflight only: a defective guard must never write into a source.
    $refreshSource=Get-Content -LiteralPath $refresh -Raw
    $preflightEnd=$refreshSource.IndexOf(". (Join-Path `$PSScriptRoot 'use_python.ps1')")
    Assert-True ($preflightEnd -gt 0) 'refresh preflight boundary located'
    $preflight=[scriptblock]::Create($refreshSource.Substring(0,$preflightEnd)+"`nthrow 'PREFLIGHT_ACCEPTED'")
    $containmentFailures=@()
    foreach($sourceName in @('RepoRoot','MonitoringSourceRoot','LaneRegistryPath')){
        foreach($relation in @('equal','output-inside-source','source-inside-output','disjoint-prefix-sibling')){
            $probe=@{};foreach($key in $parameters.Keys){$probe[$key]=$parameters[$key]}
            $sourcePath=$probe[$sourceName]
            switch($relation){
                'equal' {$probeOut=$sourcePath}
                'output-inside-source' {$probeOut=Join-Path $sourcePath 'a1-unused-output'}
                'source-inside-output' {
                    $probeOut=Split-Path -Parent $sourcePath
                    if($sourceName -ne 'RepoRoot'){
                        $probeOut=Join-Path $root ('a1-unused-parent-'+$sourceName)
                        $probe[$sourceName]=Join-Path $probeOut 'source'
                    }
                }
                'disjoint-prefix-sibling' {$probeOut=$sourcePath+'-a1-unused-output'}
            }
            $beforeExists=Test-Path -LiteralPath $probeOut
            $message=''
            try{& $preflight @probe -OutputDirectory $probeOut}catch{$message=$_.Exception.Message}
            $expected=if($relation -eq 'disjoint-prefix-sibling'){'^PREFLIGHT_ACCEPTED$'}else{'^MONITOR_REFRESH_REFUSE: (output overlaps a source root|output must not already exist)$'}
            if($message -notmatch $expected){$containmentFailures+="$sourceName $relation ($message)"}
            Assert-True ((Test-Path -LiteralPath $probeOut) -eq $beforeExists) 'preflight must not create output'
        }
    }
    Assert-True ($containmentFailures.Count -eq 0) ('source/output containment: '+($containmentFailures -join '; '))
    $site=Join-Path $root 'site'
    & $refresh @parameters -OutputDirectory $site
    $index=Get-Content -LiteralPath (Join-Path $site 'report_index.json') -Raw | ConvertFrom-Json
    Assert-True ($index.project.canonical_sha -eq $sha) 'exact canonical identity'
    Assert-True ($index.monitoring.status -eq 'DEGRADED' -and $index.monitoring.binding_state -eq 'DIFFERENT_REPO_HEAD') 'runtime mismatch survives end-to-end build'
    Assert-True ($index.safe_projection.freshness -eq 'UNKNOWN') 'legacy projection must not acquire fabricated freshness'
    Assert-True ($index.control_tower.project.global_state -eq 'DEGRADED_MONITORING') 'refresh must preserve canonical global monitoring'
    Assert-True ((Get-FileHash -LiteralPath $cr -Algorithm SHA256).Hash -eq $inputHash) 'monitor source bytes unchanged'
    Assert-True (@(Get-ChildItem -LiteralPath $registry -Force).Count -eq 0) 'read-only registry audit must not create source locks'
    Assert-True (Test-Path -LiteralPath (Join-Path $site 'index.html')) 'static assets exported'
    $public=(Get-ChildItem -LiteralPath $site -File | ForEach-Object {Get-Content -LiteralPath $_.FullName -Raw}) -join "`n"
    Assert-True ($public -notmatch 'SECRET_ACCOUNT_123456789' -and $public -notmatch [regex]::Escape($root)) 'public output excludes raw account and local input paths'
    Assert-True (-not(Test-Path -LiteralPath (Join-Path $site 'lane_audit.json'))) 'raw registry audit is private'
    $bad=@{};foreach($key in $parameters.Keys){$bad[$key]=$parameters[$key]};$bad.ExpectedSha='0000000000000000000000000000000000000000'
    $refused=$false;$badOut=Join-Path $root 'refused'
    try{& $refresh @bad -OutputDirectory $badOut}catch{$refused=$_.Exception.Message -match 'exact SHA mismatch'}
    Assert-True ($refused -and -not(Test-Path -LiteralPath $badOut)) 'exact SHA mismatch refuses before output'
    $refused=$false
    try{& $refresh @parameters -OutputDirectory $site}catch{$refused=$_.Exception.Message -match 'already exist'}
    Assert-True $refused 'existing output cannot silently preserve a stale index'
    $missing=@{};foreach($key in $parameters.Keys){$missing[$key]=$parameters[$key]}
    $missing.LaneRegistryPath=Join-Path $root 'missing-registry'
    $missing.SafeProjectionPath=Join-Path $root 'missing-projection.json'
    $missing.MonitoringSourceRoot=Join-Path $root 'missing-monitor'
    $missingOut=Join-Path $root 'missing-site'
    & $refresh @missing -OutputDirectory $missingOut
    $m=Get-Content -LiteralPath (Join-Path $missingOut 'report_index.json') -Raw | ConvertFrom-Json
    Assert-True ($m.control_tower.registry.status -eq 'UNAVAILABLE') 'missing registry fail-visible'
    Assert-True ($m.safe_projection.status -ne 'AVAILABLE') 'missing projection fail-visible'
    Assert-True ($m.monitoring.status -eq 'DEGRADED' -and $m.monitoring.binding_state -eq 'UNKNOWN') 'missing monitoring fail-visible'
    Assert-True (-not(Test-Path -LiteralPath $missing.MonitoringSourceRoot) -and -not(Test-Path -LiteralPath $missing.LaneRegistryPath)) 'missing sources are not created'
    # Exercise the actual terminal DailyMonitor branch without collectors or Git actions.
    $source=Get-Content -LiteralPath (Join-Path $repo 'scripts/daily_monitor.ps1') -Raw
    $start=$source.LastIndexOf('if ($failed.Count -gt 0) {')
    Assert-True ($start -ge 0) 'real success/failure terminal branch located'
    $tail=Join-Path $root 'daily-tail.ps1'
    Write-Text $tail ('param([string]$successMarker,[string]$alertFile,[string]$log,[switch]$Degraded)' + "`n" + '$failed=@();if($Degraded){$failed=@("fixture-degraded")};$dataAgeH=0;$coverageMsg="fixture"' + "`n" + $source.Substring($start))
    $marker=Join-Path $root 'success.txt';$alert=Join-Path $root 'alert.txt';$log=Join-Path $root 'tail.log'
    & powershell -NoProfile -File $tail -successMarker $marker -alertFile $alert -log $log
    Assert-True ($LASTEXITCODE -eq 0) 'full-green terminal branch exits zero'
    $markerText=(Get-Content -LiteralPath $marker -Raw).Trim()
    Assert-True ($markerText -cmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') 'full-green success timestamp is UTC seconds'
    $markerHash=(Get-FileHash -LiteralPath $marker -Algorithm SHA256).Hash
    & powershell -NoProfile -File $tail -successMarker $marker -alertFile $alert -log $log -Degraded
    Assert-True ($LASTEXITCODE -eq 1 -and (Get-FileHash -LiteralPath $marker -Algorithm SHA256).Hash -eq $markerHash) 'degraded completion preserves prior success bytes'
    Write-Output 'PASS mobile monitor operationalization tests'
}finally{
    $full=[IO.Path]::GetFullPath($root)
    $prefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if(-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $full) -notlike 'ea_mobile_operational_test_*'){throw 'invalid fixture cleanup boundary'}
    Remove-Item -LiteralPath $full -Recurse -Force
}
