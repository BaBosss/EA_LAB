[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference='Stop'
if(-not $RepoRoot){$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path}
$tool=Join-Path $RepoRoot 'scripts\execution_reliability\converge_state_surfaces.ps1'
$fixture=Join-Path $env:TEMP ('ea lab state sync ' + [guid]::NewGuid().ToString('N'))
$pass=0; $fail=0
function Ok([string]$Name,[bool]$Condition,[string]$Why){if($Condition){$script:pass++;Write-Host "PASS $Name"}else{$script:fail++;Write-Host "FAIL $Name :: $Why"}}
function Invoke-Tool([string[]]$Arguments){
    $saved=$ErrorActionPreference; $ErrorActionPreference='Continue'
    $out=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool @Arguments 2>&1)
    $rc=$LASTEXITCODE; $ErrorActionPreference=$saved
    return [pscustomobject]@{ExitCode=$rc;Text=(($out|Out-String).Trim())}
}
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'scripts\lib'),(Join-Path $fixture 'taskboards\active')|Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'AGENT_TASKBOARD.md') -Destination $fixture
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'ARCHIVE_TASKBOARD_2026-07A.md') -Destination $fixture
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'TASKBOARD_DIGEST.md') -Destination $fixture
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'PROJECT_STATE.md') -Destination $fixture
    Copy-Item -Path (Join-Path $RepoRoot 'taskboards\active\*') -Destination (Join-Path $fixture 'taskboards\active')
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\make_taskboard_digest.ps1') -Destination (Join-Path $fixture 'scripts')
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\taskboard_source.ps1') -Destination (Join-Path $fixture 'scripts\lib')
    $fakeState=Join-Path $fixture 'scripts\check_state.ps1'
    [IO.File]::WriteAllText($fakeState,"param([string]`$Root,[switch]`$Strict)`nif(-not (Test-Path -LiteralPath (Join-Path `$Root 'PROJECT_STATE.md'))){exit 2}`nexit 0`n",(New-Object Text.UTF8Encoding($false)))

    $x=Invoke-Tool -Arguments @('-Root',$fixture,'-CheckOnly','-Json')
    Ok 'check-only accepts converged copied surfaces' ($x.ExitCode -eq 0 -and $x.Text -match '"status":"PASS"') $x.Text

    $p03=Join-Path $fixture 'taskboards\active\P03.md'
    Add-Content -LiteralPath $p03 -Value '' -Encoding UTF8
    Add-Content -LiteralPath $p03 -Value '## ORDER-STATE-SYNC-FIXTURE - fixture mutation - `DONE`' -Encoding UTF8
    $stateHash=(Get-FileHash -Algorithm SHA256 (Join-Path $fixture 'PROJECT_STATE.md')).Hash
    $boardHash=(Get-FileHash -Algorithm SHA256 $p03).Hash
    $digestBefore=(Get-FileHash -Algorithm SHA256 (Join-Path $fixture 'TASKBOARD_DIGEST.md')).Hash
    $x=Invoke-Tool -Arguments @('-Root',$fixture,'-CheckOnly','-Json')
    Ok 'check-only refuses stale digest without writing it' ($x.ExitCode -eq 2 -and $x.Text -match 'digest check failed') $x.Text
    Ok 'check-only leaves stale digest byte-identical' ((Get-FileHash -Algorithm SHA256 (Join-Path $fixture 'TASKBOARD_DIGEST.md')).Hash -eq $digestBefore) 'digest changed in read-only mode'

    $x=Invoke-Tool -Arguments @('-Root',$fixture,'-Json')
    $digestAfter=(Get-FileHash -Algorithm SHA256 (Join-Path $fixture 'TASKBOARD_DIGEST.md')).Hash
    Ok 'apply mode regenerates digest then validates' ($x.ExitCode -eq 0 -and $x.Text -match '"generated_digest":true') $x.Text
    Ok 'apply mode changed only generated digest among owned source surfaces' ($digestAfter -ne $digestBefore -and (Get-FileHash -Algorithm SHA256 (Join-Path $fixture 'PROJECT_STATE.md')).Hash -eq $stateHash -and (Get-FileHash -Algorithm SHA256 $p03).Hash -eq $boardHash) 'state/taskboard bytes moved during convergence'
    [IO.File]::WriteAllText($fakeState,"param([string]`$Root,[switch]`$Strict)`nexit 1`n",(New-Object Text.UTF8Encoding($false)))
    $x=Invoke-Tool -Arguments @('-Root',$fixture,'-CheckOnly','-Json')
    Ok 'state guard failure remains fail-closed after digest converges' ($x.ExitCode -eq 2 -and $x.Text -match 'state check failed') $x.Text
} catch {
    $fail++; Write-Host "FAIL harness :: $($_.Exception.Message) :: $($_.InvocationInfo.PositionMessage) :: $($_.ScriptStackTrace)"
} finally {
    if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue}
}
Write-Host "TOTAL PASS=$pass FAIL=$fail"
if($fail){exit 1}else{exit 0}
