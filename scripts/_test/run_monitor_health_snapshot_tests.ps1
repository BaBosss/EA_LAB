$ErrorActionPreference='Stop'
$script=Join-Path (Split-Path -Parent $PSScriptRoot) 'monitor_health_snapshot.ps1'
function Assert-True([bool]$Value,[string]$Message){if(-not $Value){throw "ASSERT: $Message"}}
function Write-NoBom([string]$Path,[string]$Text){
    $parent=Split-Path -Parent $Path
    if($parent -and -not(Test-Path $parent)){New-Item -ItemType Directory -Force $parent|Out-Null}
    [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false)))
}
function Write-Snapshot([string]$Path,[string]$Generated){
    $obj=[ordered]@{
      meta=@{generated_at=$Generated}
      system_health=@(@{account='SECRET_ACCOUNT';collector='MT5';state='FRESH';governance_scope='LAB_MANAGED'})
      floating_risk=@(@{account='SECRET_ACCOUNT';state='FRESH'})
    }
    Write-NoBom $Path ($obj|ConvertTo-Json -Depth 5)
}
$root=Join-Path $env:TEMP ('ea_monitor_health_'+[guid]::NewGuid().ToString('N'))
$noGit=Join-Path $env:TEMP ('ea_monitor_nongit_'+[guid]::NewGuid().ToString('N'))
$portfolio=Join-Path $root 'portfolio';$live=Join-Path $portfolio 'live_deals'
New-Item -ItemType Directory -Force $live|Out-Null
$asOf=[datetimeoffset]'2026-08-30T12:00:00Z'
try{
    $liveFile=Join-Path $live 'sample_20260830.csv';Write-NoBom $liveFile "h`n1`n"
    $cr=Join-Path $portfolio 'control_room_snapshot.json';Write-Snapshot $cr '2026-08-30T11:00:00Z'
    $success=Join-Path $portfolio 'daily_monitor_last_success.txt';Write-NoBom $success '2026-08-30T11:00:00Z'
    foreach($p in @($liveFile,$cr,$success)){(Get-Item $p).LastWriteTimeUtc=[datetime]'2026-09-01T00:00:00Z'}
    & git -C $root init | Out-Null
    & git -C $root config user.email 'monitor-health-test@example.invalid'
    & git -C $root config user.name 'Monitor Health Test'
    & git -C $root add portfolio
    & git -C $root commit -m 'fixture' | Out-Null
    $fixtureHead=(& git -C $root rev-parse HEAD).Trim()
    $out=Join-Path $root 'health.json'
    $beforeHashes=@{};foreach($p in @($liveFile,$cr,$success)){$beforeHashes[$p]=(Get-FileHash $p -Algorithm SHA256).Hash}
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json;$raw=Get-Content $out -Raw
    foreach($p in @($liveFile,$cr,$success)){Assert-True ((Get-FileHash $p -Algorithm SHA256).Hash -eq $beforeHashes[$p]) "source evidence must remain byte-identical: $p"}
    Assert-True ($j.status -eq 'DEGRADED') 'date-only live evidence must keep overall health fail-closed'
    Assert-True ($j.generated_at_utc -eq '2026-08-30T12:00:00Z') 'generation time must be explicit UTC'
    Assert-True ($j.repo_head -eq $fixtureHead -and $j.runtime_revision.state -eq 'RESOLVED') 'runtime revision must bind the observed repository head'
    $liveHealth=@($j.sources|Where-Object name -eq 'live_evidence')[0]
    Assert-True ($liveHealth.state -eq 'DATE_ONLY') 'current-day filename must not invent CURRENT freshness'
    Assert-True ($null -eq $liveHealth.observed_at_utc -and $null -eq $liveHealth.source_timestamp_utc) 'date-only filename must not invent an exact timestamp'
    Assert-True ($liveHealth.source_date_local -eq '2026-08-30' -and $liveHealth.timestamp_basis -eq 'latest_filename_date_only') 'date-only source and basis must remain explicit'
    Assert-True ($j.coverage.state -eq 'AVAILABLE_CURRENT_SNAPSHOT') 'fresh snapshot coverage should be available'
    Assert-True ($j.coverage.deal_sensors_total -eq 1 -and $j.coverage.deal_sensors_fresh -eq 1) 'deal counts'
    Assert-True ($raw -notmatch 'SECRET_ACCOUNT') 'account identifiers must not leak'
    Assert-True ($raw -notmatch [regex]::Escape($root)) 'local paths must not leak'

    $futureLive=Join-Path $live 'sample_20260831.csv';Write-NoBom $futureLive "h`n1`n"
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json;$futureLiveHealth=@($j.sources|Where-Object name -eq 'live_evidence')[0]
    Assert-True ($futureLiveHealth.state -eq 'FUTURE') 'future filename date must be explicit'
    Assert-True ($null -eq $futureLiveHealth.observed_at_utc -and $null -eq $futureLiveHealth.source_timestamp_utc) 'future filename must not clamp to generation time'
    Assert-True ($futureLiveHealth.source_date_local -eq '2026-08-31') 'future filename date must remain visible without a fabricated instant'
    Remove-Item $futureLive -Force

    Write-NoBom $success '2026-08-28T00:00:00Z';(Get-Item $success).LastWriteTimeUtc=[datetime]'2026-09-01T00:00:00Z'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json;$successHealth=@($j.sources|Where-Object name -eq 'daily_monitor_success')[0]
    Assert-True ($successHealth.state -eq 'STALE') 'success marker content, not checkout mtime, must drive freshness'
    Assert-True ($successHealth.timestamp_basis -eq 'success_marker_content') 'success timestamp basis must be explicit'
    Write-NoBom $success '2026-08-30T11:00:00Z'

    Write-NoBom $success '2026-08-30T13:00:01Z'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26 -FutureToleranceMinutes 5
    $j=Get-Content $out -Raw|ConvertFrom-Json;$futureSuccess=@($j.sources|Where-Object name -eq 'daily_monitor_success')[0]
    Assert-True ($futureSuccess.state -eq 'FUTURE' -and $null -eq $futureSuccess.age_hours) 'future success marker must be explicit and cannot be age-zero current'
    Assert-True ($j.status -eq 'DEGRADED') 'future evidence must degrade overall status'
    Write-NoBom $success '2026-08-30T11:00:00Z'

    Write-NoBom $success '2026-08-30T18:00:00+07:00'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json;$offsetSuccess=@($j.sources|Where-Object name -eq 'daily_monitor_success')[0]
    Assert-True ($offsetSuccess.state -eq 'CURRENT' -and $offsetSuccess.observed_at_utc -eq '2026-08-30T11:00:00Z') 'explicit offset timestamp must normalize to UTC'

    Write-NoBom $success '2026-08-30T11:00:00'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json;$noZoneSuccess=@($j.sources|Where-Object name -eq 'daily_monitor_success')[0]
    Assert-True ($noZoneSuccess.state -eq 'INVALID') 'timezone-less success timestamp must fail closed'
    Write-NoBom $success '2026-08-30T11:00:00Z'

    Write-Snapshot $cr '2026-08-30T11:00:00'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json;$noZoneCr=@($j.sources|Where-Object name -eq 'control_room_snapshot')[0]
    Assert-True ($noZoneCr.state -eq 'INVALID' -and $j.coverage.state -eq 'UNAVAILABLE_STALE_OR_INVALID') 'timezone-less snapshot timestamp and coverage must fail closed'
    Write-Snapshot $cr '2026-08-30T11:00:00Z'

    Write-Snapshot $cr '2026-08-28T00:00:00Z'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json
    Assert-True ($j.status -eq 'DEGRADED') 'stale semantic snapshot timestamp must degrade overall status'
    Assert-True ($j.coverage.state -eq 'UNAVAILABLE_STALE_OR_INVALID') 'stale coverage must not be re-presented as current'
    Assert-True ($null -eq $j.coverage.deal_sensors_total) 'stale coverage counts must be unavailable'
    Write-Snapshot $cr '2026-08-30T11:00:00Z'

    Write-Snapshot $cr '2026-08-30T13:00:01Z'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26 -FutureToleranceMinutes 5
    $j=Get-Content $out -Raw|ConvertFrom-Json;$futureCr=@($j.sources|Where-Object name -eq 'control_room_snapshot')[0]
    Assert-True ($futureCr.state -eq 'FUTURE') 'future snapshot timestamp must be explicit'
    Assert-True ($j.coverage.state -eq 'UNAVAILABLE_STALE_OR_INVALID') 'future snapshot coverage must be unavailable'
    Write-Snapshot $cr '2026-08-30T11:00:00Z'
    Remove-Item $liveFile -Force
    $oldLive=Join-Path $live 'sample_20260811.csv';Write-NoBom $oldLive "h`n1`n"
    (Get-Item $oldLive).LastWriteTimeUtc=[datetime]'2026-09-01T00:00:00Z'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json
    $liveHealth=@($j.sources|Where-Object name -eq 'live_evidence')[0]
    Assert-True ($liveHealth.state -eq 'DATE_ONLY') 'old date-only filename must remain unqualified rather than fabricate hourly staleness'
    Assert-True ($null -eq $liveHealth.age_hours -and $liveHealth.timestamp_basis -eq 'latest_filename_date_only') 'date-only live evidence must expose no invented age'

    Remove-Item $oldLive -Force;Write-NoBom (Join-Path $live 'sample_20260830.csv') "h`n1`n"
    Write-NoBom (Join-Path $portfolio 'MONITOR_ALERT.txt') 'contains sensitive operational prose'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json;$raw=Get-Content $out -Raw
    Assert-True ($j.status -eq 'DEGRADED' -and $j.alert_present) 'alert marker must degrade status'
    Assert-True ($raw -notmatch 'sensitive operational prose') 'alert prose must not be copied'
    Remove-Item (Join-Path $portfolio 'MONITOR_ALERT.txt') -Force

    Remove-Item $success -Force
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json;$missingSuccess=@($j.sources|Where-Object name -eq 'daily_monitor_success')[0]
    Assert-True ($missingSuccess.state -eq 'MISSING') 'missing success marker must be explicit'
    Assert-True ($j.status -eq 'DEGRADED') 'missing evidence must degrade status'
    Write-NoBom $success '2026-08-30T11:00:00Z'

    Write-NoBom $cr '{broken'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json
    $crHealth=@($j.sources|Where-Object name -eq 'control_room_snapshot')[0]
    Assert-True ($crHealth.state -eq 'INVALID') 'invalid snapshot must be explicit'
    Assert-True ($j.status -eq 'DEGRADED') 'invalid snapshot must degrade status'

    $noGitPortfolio=Join-Path $noGit 'portfolio';$noGitLive=Join-Path $noGitPortfolio 'live_deals'
    New-Item -ItemType Directory -Force $noGitLive|Out-Null
    Write-NoBom (Join-Path $noGitLive 'sample_20260830.csv') "h`n1`n"
    Write-Snapshot (Join-Path $noGitPortfolio 'control_room_snapshot.json') '2026-08-30T11:00:00Z'
    Write-NoBom (Join-Path $noGitPortfolio 'daily_monitor_last_success.txt') '2026-08-30T11:00:00Z'
    & $script -RepoRoot $noGit -OutFile (Join-Path $root 'nogit-health.json') -AsOf $asOf -StaleHours 26
    $noGitHealth=Get-Content (Join-Path $root 'nogit-health.json') -Raw|ConvertFrom-Json
    Assert-True ($noGitHealth.repo_head -eq 'UNKNOWN' -and $noGitHealth.runtime_revision.state -eq 'UNKNOWN') 'missing runtime Git revision must be explicit'
    Assert-True ($noGitHealth.status -eq 'DEGRADED') 'missing runtime Git revision must not report CURRENT'

    $badToleranceRefused=$false
    try{& $script -RepoRoot $root -OutFile $out -AsOf $asOf -FutureToleranceMinutes 0}catch{$badToleranceRefused=$_.Exception.Message -match 'FutureToleranceMinutes'}
    Assert-True $badToleranceRefused 'non-positive future tolerance must be refused'

    $source=Get-Content $script -Raw
    foreach($forbidden in @('daily_monitor.ps1','collect_live_deals.ps1','monitor_rotation.ps1','publish_dashboard_gist.ps1','terminal64.exe')){
        Assert-True ($source -notmatch [regex]::Escape($forbidden)) "read-only projection must not invoke $forbidden"
    }
    Write-Output 'PASS monitor health snapshot tests'
}finally{
    if(Test-Path $root){Remove-Item $root -Recurse -Force}
    if(Test-Path $noGit){Remove-Item $noGit -Recurse -Force}
}
