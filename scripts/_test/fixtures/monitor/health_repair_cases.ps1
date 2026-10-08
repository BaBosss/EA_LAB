[CmdletBinding()]
param([Parameter(Mandatory)][string]$RepoRoot)
$ErrorActionPreference='Stop'
. (Join-Path $RepoRoot 'scripts\lib\monitor_coverage.ps1')
$provider=Join-Path $RepoRoot 'scripts\monitor_health_snapshot.ps1'
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('health-repair-'+[guid]::NewGuid().ToString('N'))
$portfolio=Join-Path $fixture 'portfolio';$live=Join-Path $portfolio 'live_deals'
New-Item -ItemType Directory -Path $live -Force|Out-Null
$script:passed=0;$script:failed=0
function Check([string]$Name,[bool]$Value){if($Value){$script:passed++;Write-Output "PASS $Name"}else{$script:failed++;Write-Output "FAIL $Name"}}
function Write-Text([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false)))}
function Snapshot($Doc){Write-Text (Join-Path $portfolio 'control_room_snapshot.json') ($Doc|ConvertTo-Json -Depth 12)}
function Read-Health {& $provider -RepoRoot $fixture -AsOf ([datetimeoffset]'2026-10-08T12:00:00Z') -OutFile (Join-Path $fixture 'health.json');$options=@{};if((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')){$options.DateKind='String'};Get-Content (Join-Path $fixture 'health.json') -Raw|ConvertFrom-Json @options}
$good=@{meta=@{generated_at='2026-10-08T11:00:00Z';git_head=('a'*40)};system_health=@(@{account='123';governance_scope='LAB_MANAGED';state='FRESH'});floating_risk=@(@{account='123';state='FRESH'})}
try{
    $marker=Join-Path $portfolio 'daily_monitor_last_success.txt'
    $now=[datetime]'2026-10-08T12:00:00Z'
    foreach($case in @(
        @{name='future marker';marker='2026-10-08T13:00:00Z';bar=30;expected='UNKNOWN'},
        @{name='sub-rounding future marker';marker='2026-10-08T12:00:01Z';bar=30;expected='UNKNOWN'},
        @{name='NaN threshold';marker='2026-10-08T11:00:00Z';bar=[double]::NaN;expected='UNKNOWN'},
        @{name='infinite threshold';marker='2026-10-08T11:00:00Z';bar=[double]::PositiveInfinity;expected='UNKNOWN'},
        @{name='invalid timestamp';marker='garbage';bar=30;expected='UNKNOWN'},
        @{name='stale marker';marker='2026-10-06T00:00:00Z';bar=30;expected='OVERDUE'},
        @{name='valid offset marker';marker='2026-10-08T18:00:00+07:00';bar=30;expected='OK'}
    )){Write-Text $marker $case.marker;$h=Get-MonitorChainHealth -RepoRoot $fixture -Now $now -BarHours $case.bar;Check $case.name ($h.State -eq $case.expected)}
    Remove-Item -LiteralPath $marker
    Check 'missing marker unknown' ((Get-MonitorChainHealth -RepoRoot $fixture -Now $now -BarHours 30).State -eq 'UNKNOWN')
    Write-Text $marker '2026-10-08T13:00:00Z';Write-Text (Join-Path $portfolio 'MONITOR_ALERT.txt') 'real gap'
    Check 'standing alert wins invalid time and threshold' ((Get-MonitorChainHealth -RepoRoot $fixture -Now $now -BarHours ([double]::NaN)).State -eq 'ALERT')
    Remove-Item -LiteralPath (Join-Path $portfolio 'MONITOR_ALERT.txt')
    Write-Text $marker '2026-10-08T11:00:00Z'
    foreach($shape in @($null,'FRESH',17)){
        Snapshot @{meta=$good.meta;system_health=$shape;floating_risk=$shape}
        $h=Read-Health
        Check "malformed coverage $shape unavailable" ($h.coverage.state -eq 'UNAVAILABLE_INVALID_COVERAGE' -and $null -eq $h.coverage.floating_sensors_total)
    }
    Snapshot @{meta=$good.meta;system_health=$good.system_health;floating_risk=@()}
    $h=Read-Health;Check 'missing account observation explicit partial' ($h.coverage.state -eq 'PARTIAL_SNAPSHOT_OBSERVATION' -and $h.coverage.floating_sensors_total -eq 0)
    Snapshot $good;$h=Read-Health
    Check 'snapshot counts timestamped historical observation' ($h.coverage.state -eq 'AVAILABLE_SNAPSHOT_OBSERVATION' -and $h.coverage.observed_at_utc -eq '2026-10-08T11:00:00Z' -and $h.coverage.authority -eq 'SNAPSHOT_OBSERVATION_ONLY')
    Check 'absent account scope unknown counts' ($h.current_file_coverage.state -eq 'UNKNOWN_SCOPE' -and $null -eq $h.current_file_coverage.deal_sensors_total)
    Write-Text (Join-Path $portfolio 'ACCOUNTS.csv') "account,governance_scope`n123,LAB_MANAGED`n"
    $deal=Join-Path $live 'EA_LAB_deals_123_20261008.csv'
    $float=Join-Path $live 'EA_LAB_snapshot_123_20261008.csv'
    Write-Text $deal "ticket,magic,time_unix`n1,42,1`n"
    Write-Text $float "row_type,login,equity,balance`nACCOUNT,123,100,100`n"
    (Get-Item $deal).LastWriteTimeUtc=[datetime]'2026-10-08T11:00:00Z';(Get-Item $float).LastWriteTimeUtc=[datetime]'2026-10-08T11:00:00Z'
    $h=Read-Health;Check 'current files fresh specificity' ($h.current_file_coverage.state -eq 'COMPLETE_CURRENT_FILE_OBSERVATION' -and $h.current_file_coverage.deal_sensors_fresh -eq 1 -and $h.current_file_coverage.floating_sensors_fresh -eq 1)
    Write-Text $deal '"ticket","magic","time_unix"';(Get-Item $deal).LastWriteTimeUtc=[datetime]'2026-10-08T11:00:00Z'
    $h=Read-Health;Check 'quoted header empty deal history is still a readable sensor' ($h.current_file_coverage.deal_sensors_fresh -eq 1)
    (Get-Item $deal).LastWriteTimeUtc=[datetime]'2026-10-07T05:00:00Z'
    $h=Read-Health;Check 'current stale file cannot inherit snapshot FRESH' ($h.current_file_coverage.deal_sensors_fresh -eq 0 -and $h.current_file_coverage.deal_sensors_stale -eq 1 -and $h.coverage.deal_sensors_fresh -eq 1)
    $mt4=Join-Path $live 'EA_LAB_mt4_orders_123_20261008.csv';Write-Text $mt4 "ticket,magic`n1,42`n";(Get-Item $mt4).LastWriteTimeUtc=[datetime]'2026-10-08T11:00:00Z'
    $h=Read-Health;Check 'collector priority cannot cherry-pick fresh fallback' ($h.current_file_coverage.deal_sensors_stale -eq 1)
    Remove-Item -LiteralPath $mt4
    (Get-Item $deal).LastWriteTimeUtc=[datetime]'2026-10-08T12:00:01Z'
    $h=Read-Health;Check 'future file unknown, never fresh' ($h.current_file_coverage.deal_sensors_fresh -eq 0 -and $h.current_file_coverage.deal_sensors_unknown -eq 1)
    Remove-Item -LiteralPath $deal
    $h=Read-Health;Check 'missing CSV counted missing' ($h.current_file_coverage.deal_sensors_missing -eq 1 -and $h.current_file_coverage.state -eq 'PARTIAL_CURRENT_FILE_OBSERVATION')
    Write-Text $float "row_type,login,equity,balance`nACCOUNT,999,100,100`n";(Get-Item $float).LastWriteTimeUtc=[datetime]'2026-10-08T11:00:00Z'
    $h=Read-Health;Check 'wrong CSV account unknown' ($h.current_file_coverage.floating_sensors_unknown -eq 1)
    Write-Text $float "row_type,login,equity,balance`nACCOUNT,123,,100`n";(Get-Item $float).LastWriteTimeUtc=[datetime]'2026-10-08T11:00:00Z'
    $h=Read-Health;Check 'null floating numeric not zero or fresh' ($h.current_file_coverage.floating_sensors_unknown -eq 1 -and $h.current_file_coverage.floating_sensors_fresh -eq 0)
    foreach($bad in @('NaN','Infinity','garbage')){Write-Text $float "row_type,login,equity,balance`nACCOUNT,123,$bad,100`n";(Get-Item $float).LastWriteTimeUtc=[datetime]'2026-10-08T11:00:00Z';$h=Read-Health;Check "invalid numeric $bad unknown" ($h.current_file_coverage.floating_sensors_unknown -eq 1)}
    Write-Text (Join-Path $portfolio 'ACCOUNTS.csv') "account,governance_scope`n123,LAB_MANAGED`n123,LAB_MANAGED`n"
    $h=Read-Health;Check 'duplicate account scope unknown rather than double count' ($h.current_file_coverage.state -eq 'UNKNOWN_SCOPE' -and $null -eq $h.current_file_coverage.deal_sensors_total)
    Write-Text (Join-Path $portfolio 'ACCOUNTS.csv') "account,governance_scope`n123,LAB_MANAGED`n"
    foreach($identity in @(@{},@{pid=17;creation_time='OLD';executable='unknown'},@{pid=17;creation_time='NEW';executable='terminal64.exe';state='PASS';heartbeat='2099-01-01T00:00:00Z'})){
        $good.meta.runtime_process_identity=$identity;Snapshot $good;$h=Read-Health
        Check 'missing/reused/unknown PID and spoofed heartbeat never prove liveness' ($h.runtime_process_identity.state -eq 'UNKNOWN')
    }
    $good.meta.generated_at='garbage';Snapshot $good;$h=Read-Health
    Check 'invalid snapshot timestamp unavailable' ($h.coverage.state -eq 'UNAVAILABLE_STALE_OR_INVALID')
    foreach($value in @([double]::NaN,[double]::PositiveInfinity)){
        $refused=$false;try{& $provider -RepoRoot $fixture -StaleHours $value -OutFile (Join-Path $fixture 'bad.json')}catch{$refused=$true}
        Check 'non-finite health threshold refused' $refused
        $refused=$false;try{& $provider -RepoRoot $fixture -FutureToleranceMinutes $value -OutFile (Join-Path $fixture 'bad.json')}catch{$refused=$true}
        Check 'non-finite future tolerance refused' $refused
    }
    Write-Output "RESULT $script:passed passed; $script:failed failed"
}finally{
    $resolved=[IO.Path]::GetFullPath($fixture)
    if(-not $resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe fixture cleanup'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
if($script:failed -gt 0){exit 1}
