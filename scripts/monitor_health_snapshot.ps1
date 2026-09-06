[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutFile = '',
    [datetimeoffset]$AsOf = [datetimeoffset]::Now,
    [double]$StaleHours = 26,
    [double]$FutureToleranceMinutes = 5
)
$ErrorActionPreference='Stop'
if(-not $RepoRoot){$RepoRoot=Split-Path -Parent $PSScriptRoot}
$RepoRoot=[IO.Path]::GetFullPath($RepoRoot)
if($StaleHours -le 0){throw 'MONITOR_HEALTH_REFUSE: StaleHours must be > 0'}
if($FutureToleranceMinutes -le 0){throw 'MONITOR_HEALTH_REFUSE: FutureToleranceMinutes must be > 0'}
$asOfUtc=$AsOf.UtcDateTime
$inv=[Globalization.CultureInfo]::InvariantCulture
function Convert-ObservedUtc {
    param([string]$Text)
    if([string]::IsNullOrWhiteSpace($Text)){return $null}
    $trimmed=$Text.Trim()
    if($trimmed -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:\d{2})$'){return $null}
    try{return ([datetimeoffset]::Parse($trimmed,$inv,[Globalization.DateTimeStyles]::None)).UtcDateTime}
    catch{return $null}
}
function New-SourceHealth {
    param(
        [string]$Name,$ObservedUtc,[string]$Basis,[string]$MissingState='MISSING'
    )
    if($null -eq $ObservedUtc){
        return [pscustomobject][ordered]@{
            name=$Name;state=$MissingState;age_hours=$null;observed_at_utc=$null
            source_timestamp_utc=$null;timestamp_basis=$Basis;observation_adjustment='NONE';source_date_local=$null
        }
    }
    $observed=[datetime]$ObservedUtc
    $future=$observed -gt $asOfUtc.AddMinutes($FutureToleranceMinutes)
    $age=if($future){$null}else{[math]::Max(0,($asOfUtc-$observed).TotalHours)}
    $state=if($future){'FUTURE'}elseif($age -le $StaleHours){'CURRENT'}else{'STALE'}
    return [pscustomobject][ordered]@{
        name=$Name;state=$state;age_hours=if($null -eq $age){$null}else{[math]::Round($age,2)}
        observed_at_utc=$observed.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        source_timestamp_utc=$observed.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        timestamp_basis=$Basis;observation_adjustment='NONE';source_date_local=$null
    }
}
function New-DateOnlyHealth {
    param([string]$Name,[string]$SourceDateLocal,[string]$Basis)
    if(-not $SourceDateLocal){return New-SourceHealth -Name $Name -ObservedUtc $null -Basis $Basis}
    $sourceDate=[datetime]::ParseExact($SourceDateLocal,'yyyy-MM-dd',$inv,[Globalization.DateTimeStyles]::None)
    $state=if($sourceDate.Date -gt $AsOf.Date){'FUTURE'}else{'DATE_ONLY'}
    return [pscustomobject][ordered]@{
        name=$Name;state=$state;age_hours=$null;observed_at_utc=$null;source_timestamp_utc=$null
        timestamp_basis=$Basis;observation_adjustment='NONE';source_date_local=$SourceDateLocal
    }
}
$liveDir=Join-Path $RepoRoot 'portfolio\live_deals'
$liveSourceDate=''
if(Test-Path -LiteralPath $liveDir){
    $dates=@(Get-ChildItem -LiteralPath $liveDir -File -ErrorAction SilentlyContinue | ForEach-Object {
        if($_.Name -match '_(\d{8})\.[^.]+$'){
            try{
                $d=[datetime]::ParseExact($matches[1],'yyyyMMdd',$inv,[Globalization.DateTimeStyles]::None)
                $d.ToString('yyyy-MM-dd')
            }catch{}
        }
    } | Where-Object {$null -ne $_})
    if($dates.Count -gt 0){
        $liveSourceDate=@($dates|Sort-Object -Descending)[0]
    }
}
$crPath=Join-Path $RepoRoot 'portfolio\control_room_snapshot.json'
$cr=$null;$crObserved=$null;$crMissingState='MISSING'
if(Test-Path -LiteralPath $crPath){
    try{$cr=Get-Content -LiteralPath $crPath -Raw -Encoding UTF8|ConvertFrom-Json; $crObserved=Convert-ObservedUtc ([string]$cr.meta.generated_at); if($null -eq $crObserved){$crMissingState='INVALID'}}
    catch{$crMissingState='INVALID'}
}
$successPath=Join-Path $RepoRoot 'portfolio\daily_monitor_last_success.txt'
$successObserved=$null;$successMissingState='MISSING'
if(Test-Path -LiteralPath $successPath){
    try{$successObserved=Convert-ObservedUtc ((Get-Content -LiteralPath $successPath -Raw -Encoding UTF8).Trim());if($null -eq $successObserved){$successMissingState='INVALID'}}
    catch{$successMissingState='INVALID'}
}
$sources=@(
    New-DateOnlyHealth -Name 'live_evidence' -SourceDateLocal $liveSourceDate -Basis 'latest_filename_date_only'
    New-SourceHealth -Name 'control_room_snapshot' -ObservedUtc $crObserved -Basis 'snapshot_meta_generated_at' -MissingState $crMissingState
    New-SourceHealth -Name 'daily_monitor_success' -ObservedUtc $successObserved -Basis 'success_marker_content' -MissingState $successMissingState
)
$coverage=[ordered]@{
    state='UNAVAILABLE_STALE_OR_INVALID';deal_sensors_total=$null;deal_sensors_fresh=$null
    floating_sensors_total=$null;floating_sensors_fresh=$null
}
$crSource=@($sources|Where-Object name -eq 'control_room_snapshot')[0]
if($crSource.state -eq 'CURRENT' -and $null -ne $cr){
    $deal=@($cr.system_health|Where-Object {$_.governance_scope -eq 'LAB_MANAGED'})
    $float=@($cr.floating_risk)
    $coverage.state='AVAILABLE_CURRENT_SNAPSHOT'
    $coverage.deal_sensors_total=$deal.Count
    $coverage.deal_sensors_fresh=@($deal|Where-Object state -eq 'FRESH').Count
    $coverage.floating_sensors_total=$float.Count
    $coverage.floating_sensors_fresh=@($float|Where-Object state -eq 'FRESH').Count
}
$alertPath=Join-Path $RepoRoot 'portfolio\MONITOR_ALERT.txt'
$alertPresent=Test-Path -LiteralPath $alertPath
$repoHead='UNKNOWN'
try{$candidate=(& git -C $RepoRoot rev-parse HEAD 2>$null).Trim();if($candidate -match '^[0-9a-f]{40}$'){$repoHead=$candidate}}catch{}
$revisionState=if($repoHead -eq 'UNKNOWN'){'UNKNOWN'}else{'RESOLVED'}
$status=if($alertPresent -or $revisionState -ne 'RESOLVED' -or @($sources|Where-Object state -ne 'CURRENT').Count -gt 0){'DEGRADED'}else{'CURRENT'}
$payload=[pscustomobject][ordered]@{
    schema_version='EA_LAB_MONITOR_HEALTH_V1'
    generated_at_utc=$asOfUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    source_kind='LOCAL_MONITORING_NONCANONICAL'
    authority='READ_ONLY_NO_RUNTIME_AUTHORITY'
    repo_head=$repoHead
    runtime_revision=[pscustomobject][ordered]@{state=$revisionState;git_head=if($revisionState -eq 'RESOLVED'){$repoHead}else{$null};basis='git_rev_parse_repo_root'}
    status=$status;stale_after_hours=$StaleHours;future_tolerance_minutes=$FutureToleranceMinutes
    alert_present=$alertPresent;sources=$sources;coverage=[pscustomobject]$coverage
}
$json=$payload|ConvertTo-Json -Depth 8
if($OutFile){
    $parent=Split-Path -Parent $OutFile
    if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
    [IO.File]::WriteAllText($OutFile,$json,(New-Object Text.UTF8Encoding($false)))
}else{$json}
