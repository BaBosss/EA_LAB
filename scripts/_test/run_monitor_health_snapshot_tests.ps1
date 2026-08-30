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
$portfolio=Join-Path $root 'portfolio';$live=Join-Path $portfolio 'live_deals'
New-Item -ItemType Directory -Force $live|Out-Null
$asOf=[datetime]'2026-08-30T12:00:00Z'
try{
    $liveFile=Join-Path $live 'sample_20260830.csv';Write-NoBom $liveFile "h`n1`n"
    $cr=Join-Path $portfolio 'control_room_snapshot.json';Write-Snapshot $cr '2026-08-30T11:00:00Z'
    $success=Join-Path $portfolio 'daily_monitor_last_success.txt';Write-NoBom $success '2026-08-30 11:00:00Z'
    foreach($p in @($liveFile,$cr,$success)){(Get-Item $p).LastWriteTimeUtc=[datetime]'2026-09-01T00:00:00Z'}
    $out=Join-Path $root 'health.json'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json;$raw=Get-Content $out -Raw
    Assert-True ($j.status -eq 'CURRENT') 'fresh semantic timestamps should be CURRENT'
    Assert-True ($j.coverage.state -eq 'AVAILABLE_CURRENT_SNAPSHOT') 'fresh snapshot coverage should be available'
    Assert-True ($j.coverage.deal_sensors_total -eq 1 -and $j.coverage.deal_sensors_fresh -eq 1) 'deal counts'
    Assert-True ($raw -notmatch 'SECRET_ACCOUNT') 'account identifiers must not leak'
    Assert-True ($raw -notmatch [regex]::Escape($root)) 'local paths must not leak'

    Write-Snapshot $cr '2026-08-28T00:00:00Z'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json
    Assert-True ($j.status -eq 'DEGRADED') 'stale semantic snapshot timestamp must degrade overall status'
    Assert-True ($j.coverage.state -eq 'UNAVAILABLE_STALE_OR_INVALID') 'stale coverage must not be re-presented as current'
    Assert-True ($null -eq $j.coverage.deal_sensors_total) 'stale coverage counts must be unavailable'
    Write-Snapshot $cr '2026-08-30T11:00:00Z'
    Remove-Item $liveFile -Force
    $oldLive=Join-Path $live 'sample_20260811.csv';Write-NoBom $oldLive "h`n1`n"
    (Get-Item $oldLive).LastWriteTimeUtc=[datetime]'2026-09-01T00:00:00Z'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json
    $liveHealth=@($j.sources|Where-Object name -eq 'live_evidence')[0]
    Assert-True ($liveHealth.state -eq 'STALE') 'checkout mtime must not make old filename evidence current'
    Assert-True ($liveHealth.timestamp_basis -eq 'latest_filename_date_upper_bound') 'live timestamp basis must be explicit'

    Remove-Item $oldLive -Force;Write-NoBom (Join-Path $live 'sample_20260830.csv') "h`n1`n"
    Write-NoBom (Join-Path $portfolio 'MONITOR_ALERT.txt') 'contains sensitive operational prose'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json;$raw=Get-Content $out -Raw
    Assert-True ($j.status -eq 'DEGRADED' -and $j.alert_present) 'alert marker must degrade status'
    Assert-True ($raw -notmatch 'sensitive operational prose') 'alert prose must not be copied'
    Remove-Item (Join-Path $portfolio 'MONITOR_ALERT.txt') -Force

    Write-NoBom $cr '{broken'
    & $script -RepoRoot $root -OutFile $out -AsOf $asOf -StaleHours 26
    $j=Get-Content $out -Raw|ConvertFrom-Json
    $crHealth=@($j.sources|Where-Object name -eq 'control_room_snapshot')[0]
    Assert-True ($crHealth.state -eq 'INVALID') 'invalid snapshot must be explicit'
    Assert-True ($j.status -eq 'DEGRADED') 'invalid snapshot must degrade status'

    $source=Get-Content $script -Raw
    foreach($forbidden in @('daily_monitor.ps1','collect_live_deals.ps1','monitor_rotation.ps1','publish_dashboard_gist.ps1','terminal64.exe')){
        Assert-True ($source -notmatch [regex]::Escape($forbidden)) "read-only projection must not invoke $forbidden"
    }
    Write-Output 'PASS monitor health snapshot tests'
}finally{
    if(Test-Path $root){Remove-Item $root -Recurse -Force}
}
