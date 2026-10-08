[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$OutFile = '',
    [string]$ExpectedCanonicalSha = '',
    [datetimeoffset]$AsOf = [datetimeoffset]::Now,
    [double]$StaleHours = 26,
    [double]$FutureToleranceMinutes = 5
)
$ErrorActionPreference='Stop'
if(-not $RepoRoot){$RepoRoot=Split-Path -Parent $PSScriptRoot}
$RepoRoot=[IO.Path]::GetFullPath($RepoRoot)
if($ExpectedCanonicalSha -and $ExpectedCanonicalSha -cnotmatch '^[0-9a-f]{40}$'){throw 'MONITOR_HEALTH_REFUSE: invalid canonical SHA'}
if([double]::IsNaN($StaleHours) -or [double]::IsInfinity($StaleHours) -or $StaleHours -le 0){throw 'MONITOR_HEALTH_REFUSE: StaleHours must be finite and > 0'}
if([double]::IsNaN($FutureToleranceMinutes) -or [double]::IsInfinity($FutureToleranceMinutes) -or $FutureToleranceMinutes -le 0){throw 'MONITOR_HEALTH_REFUSE: FutureToleranceMinutes must be finite and > 0'}
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
function Get-CurrentFileCoverage {
    # A read-only local-file observation. Never starts collectors or infers terminal liveness.
    $result=[ordered]@{state='UNKNOWN_SCOPE';observed_at_utc=$asOfUtc.ToString('yyyy-MM-ddTHH:mm:ssZ');authority='LOCAL_FILE_OBSERVATION_ONLY';timestamp_basis='FILE_LAST_WRITE_UTC_NOT_BROKER_CLOCK';scope_basis='ACCOUNTS_CSV_LAB_MANAGED';deal_stale_after_hours=30;floating_stale_after_hours=26;deal_sensors_total=$null;deal_sensors_fresh=$null;deal_sensors_stale=$null;deal_sensors_unknown=$null;deal_sensors_missing=$null;floating_sensors_total=$null;floating_sensors_fresh=$null;floating_sensors_stale=$null;floating_sensors_unknown=$null;floating_sensors_missing=$null}
    $accountPath=Join-Path $RepoRoot 'portfolio\ACCOUNTS.csv'
    if(-not (Test-Path -LiteralPath $accountPath)){return [pscustomobject]$result}
    $accounts=@();$seen=@{}
    try {
        $scopeRows=@(Import-Csv -LiteralPath $accountPath -ErrorAction Stop)
        if($scopeRows.Count -eq 0){return [pscustomobject]$result}
        foreach($row in $scopeRows){
            if($row.account -notmatch '^[1-9]\d*$' -or $row.governance_scope -notin @('LAB_MANAGED','USER_OBSERVED','ARCHIVED') -or $seen.ContainsKey([string]$row.account)){return [pscustomobject]$result}
            $seen[[string]$row.account]=$true
            if($row.governance_scope -eq 'LAB_MANAGED'){$accounts+=[string]$row.account}
        }
    }catch{return [pscustomobject]$result}
    if($accounts.Count -eq 0){return [pscustomobject]$result}
    $result.deal_sensors_total=$accounts.Count;$result.floating_sensors_total=$accounts.Count
    foreach($kind in @('deal','floating')){foreach($state in @('fresh','stale','unknown','missing')){$result["${kind}_sensors_${state}"]=0}}
    foreach($account in $accounts){
        foreach($kind in @('deal','floating')){
            $state='unknown';$files=@();$file=$null
            try {
                if($kind -eq 'deal'){
                    $files=@(Get-ChildItem -LiteralPath $liveDir -File -Filter "EA_LAB_deals_${account}_*.csv" -ErrorAction SilentlyContinue|Sort-Object Name)
                    if($files.Count -eq 0){$files=@(Get-ChildItem -LiteralPath $liveDir -File -Filter "EA_LAB_mt4_orders_${account}_*.csv" -ErrorAction SilentlyContinue|Sort-Object Name)}
                }else{$files=@(Get-ChildItem -LiteralPath $liveDir -File -Filter "EA_LAB_snapshot_${account}_*.csv" -ErrorAction SilentlyContinue|Sort-Object Name)}
                if($files.Count -eq 0){$state='missing'}else{
                    $file=$files[-1];$age=($asOfUtc-$file.LastWriteTimeUtc).TotalHours
                    $bar=if($kind -eq 'deal'){30}else{26}
                    if($age -lt 0){$state='unknown'}elseif($age -gt $bar){$state='stale'}else{
                        $header=@(((Get-Content -LiteralPath $file.FullName -TotalCount 1 -ErrorAction Stop) -split ',')|ForEach-Object {$_.Trim().Trim('"')})
                        $data=@(Import-Csv -LiteralPath $file.FullName -ErrorAction Stop)
                        if($kind -eq 'deal'){
                            if($header -contains 'ticket' -and $header -contains 'magic'){$state='fresh'}
                        }else{
                            $accountRows=@($data|Where-Object row_type -eq 'ACCOUNT')
                            if($accountRows.Count -eq 1 -and [string]$accountRows[0].login -ceq $account){
                                $numericValid=$true
                                foreach($field in @('equity','balance')){
                                    $number=0.0;$text=[string]$accountRows[0].$field
                                    if([string]::IsNullOrWhiteSpace($text) -or -not [double]::TryParse($text,[Globalization.NumberStyles]::Float,$inv,[ref]$number) -or [double]::IsNaN($number) -or [double]::IsInfinity($number)){$numericValid=$false}
                                }
                                if($numericValid){$state='fresh'}
                            }
                        }
                    }
                }
            }catch{$state='unknown'}
            $result["${kind}_sensors_${state}"]++
        }
    }
    $result.state=if($result.deal_sensors_fresh -eq $accounts.Count -and $result.floating_sensors_fresh -eq $accounts.Count){'COMPLETE_CURRENT_FILE_OBSERVATION'}else{'PARTIAL_CURRENT_FILE_OBSERVATION'}
    return [pscustomobject]$result
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
    $jsonParseArgs=@{}
    if((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')){$jsonParseArgs.DateKind='String'}
    try{$cr=Get-Content -LiteralPath $crPath -Raw -Encoding UTF8|ConvertFrom-Json @jsonParseArgs; $crObserved=Convert-ObservedUtc ([string]$cr.meta.generated_at); if($null -eq $crObserved){$crMissingState='INVALID'}}
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
    observed_at_utc=$null;authority='SNAPSHOT_OBSERVATION_ONLY';timestamp_basis='SNAPSHOT_META_GENERATED_AT'
    expected_lab_accounts=$null;missing_floating_observations=$null
}
$crSource=@($sources|Where-Object name -eq 'control_room_snapshot')[0]
if($crSource.state -eq 'CURRENT' -and $null -ne $cr){
    $coverage.state='UNAVAILABLE_INVALID_COVERAGE'
    $valid=($cr.system_health -is [array] -and $cr.floating_risk -is [array])
    $dealSeen=@{};$floatSeen=@{}
    if($valid){
        foreach($row in $cr.system_health){
            if($null -eq $row -or $row -isnot [pscustomobject] -or [string]$row.account -notmatch '^[1-9]\d*$' -or $row.state -notin @('FRESH','STALE','NO_SENSOR','UNKNOWN') -or $row.governance_scope -notin @('LAB_MANAGED','USER_OBSERVED','ARCHIVED','UNREGISTERED') -or $dealSeen.ContainsKey([string]$row.account)){$valid=$false;break}
            $dealSeen[[string]$row.account]=$row.governance_scope
        }
        foreach($row in $cr.floating_risk){
            if($null -eq $row -or $row -isnot [pscustomobject] -or [string]$row.account -notmatch '^[1-9]\d*$' -or $row.state -notin @('FRESH','STALE','BLIND','MISSING','UNKNOWN') -or $floatSeen.ContainsKey([string]$row.account) -or -not $dealSeen.ContainsKey([string]$row.account)){$valid=$false;break}
            $floatSeen[[string]$row.account]=$true
        }
    }
    if($valid){
        $deal=@($cr.system_health|Where-Object governance_scope -eq 'LAB_MANAGED')
        $float=@($cr.floating_risk|Where-Object {$dealSeen[[string]$_.account] -eq 'LAB_MANAGED'})
        if($deal.Count -gt 0){
            $coverage.state=if($deal.Count -eq $float.Count){'AVAILABLE_SNAPSHOT_OBSERVATION'}else{'PARTIAL_SNAPSHOT_OBSERVATION'}
            $coverage.observed_at_utc=$crSource.observed_at_utc
            $coverage.expected_lab_accounts=$deal.Count;$coverage.missing_floating_observations=$deal.Count-$float.Count
            $coverage.deal_sensors_total=$deal.Count;$coverage.deal_sensors_fresh=@($deal|Where-Object state -eq 'FRESH').Count
            $coverage.floating_sensors_total=$float.Count;$coverage.floating_sensors_fresh=@($float|Where-Object state -eq 'FRESH').Count
        }
    }
}
$currentCoverage=Get-CurrentFileCoverage
$alertPath=Join-Path $RepoRoot 'portfolio\MONITOR_ALERT.txt'
$alertPresent=Test-Path -LiteralPath $alertPath
$repoHead='UNKNOWN'
try{$candidate=(& git -C $RepoRoot rev-parse HEAD 2>$null).Trim();if($candidate -match '^[0-9a-f]{40}$'){$repoHead=$candidate}}catch{}
$revisionState=if($repoHead -eq 'UNKNOWN'){'UNKNOWN'}else{'RESOLVED'}
$canonicalBinding=if(-not $ExpectedCanonicalSha -or $repoHead -eq 'UNKNOWN'){'UNKNOWN'}elseif($repoHead -ceq $ExpectedCanonicalSha){'MATCHES_CANONICAL_SHA'}else{'DIFFERENT_REPO_HEAD'}
$snapshotHead=if($null -ne $cr -and [string]$cr.meta.git_head -cmatch '^[0-9a-f]{40}$'){[string]$cr.meta.git_head}else{'UNKNOWN'}
$snapshotBinding=if($snapshotHead -eq 'UNKNOWN' -or $repoHead -eq 'UNKNOWN'){'UNKNOWN'}elseif($snapshotHead -ceq $repoHead){'MATCHES_RUNTIME_HEAD'}else{'DIFFERENT_SNAPSHOT_HEAD'}
$status=if($alertPresent -or $revisionState -ne 'RESOLVED' -or $canonicalBinding -ne 'MATCHES_CANONICAL_SHA' -or $snapshotBinding -ne 'MATCHES_RUNTIME_HEAD' -or $coverage.state -ne 'AVAILABLE_SNAPSHOT_OBSERVATION' -or $currentCoverage.state -ne 'COMPLETE_CURRENT_FILE_OBSERVATION' -or @($sources|Where-Object state -ne 'CURRENT').Count -gt 0){'DEGRADED'}else{'CURRENT'}
$payload=[pscustomobject][ordered]@{
    schema_version='EA_LAB_MONITOR_HEALTH_V1'
    generated_at_utc=$asOfUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    source_kind='LOCAL_MONITORING_NONCANONICAL'
    authority='READ_ONLY_NO_RUNTIME_AUTHORITY'
    repo_head=$repoHead
    runtime_revision=[pscustomobject][ordered]@{state=$revisionState;git_head=if($revisionState -eq 'RESOLVED'){$repoHead}else{$null};basis='git_rev_parse_repo_root'}
    runtime_process_identity=[pscustomobject]@{state='UNKNOWN';basis='NO_EXPECTED_PID_CREATION_EXECUTABLE_RECEIPT';authority='NO_PROCESS_LIVENESS_INFERENCE'}
    canonical_binding=$canonicalBinding
    snapshot_revision=[pscustomobject][ordered]@{git_head=$snapshotHead;binding_state=$snapshotBinding;basis='snapshot_meta_git_head'}
    status=$status;stale_after_hours=$StaleHours;future_tolerance_minutes=$FutureToleranceMinutes
    alert_present=$alertPresent;sources=$sources;coverage=[pscustomobject]$coverage;current_file_coverage=$currentCoverage
}
$json=$payload|ConvertTo-Json -Depth 8
if($OutFile){
    $parent=Split-Path -Parent $OutFile
    if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
    [IO.File]::WriteAllText($OutFile,$json,(New-Object Text.UTF8Encoding($false)))
}else{$json}
