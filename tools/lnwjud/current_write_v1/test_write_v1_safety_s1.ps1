[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "assertion failed: $Message" }
}

function Assert-Equal($Actual, $Expected, [string]$Message) {
  if ($Actual -ne $Expected) {
    throw "assertion failed: $Message (actual=$Actual expected=$Expected)"
  }
}

function Assert-Throws([scriptblock]$Action, [string]$Pattern, [string]$Message) {
  try {
    & $Action
  }
  catch {
    if ([string]$_.Exception.Message -notmatch $Pattern) {
      throw "assertion failed: $Message (unexpected error: $($_.Exception.Message))"
    }
    return
  }
  throw "assertion failed: $Message (no error)"
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Here 'start_write_v1.ps1') -LibraryOnly

$nodePath = 'C:\Program Files\nodejs\node.exe'
$nodeHash = '3602f2bb1a10f2cbab4c36886218a33c1ab3db87290e73b033c46c77147d0237'
$gatewayPath = 'D:\EA_LAB_CONTROL\lnwjud-write-v1-20260928\EA_LAB_CurrentWrite_V1_HTTP_Gateway.bundle.cjs'
$gatewayHash = '0ee04a04ba1a2ee5482363fa0a7aac86ba0b8cb4a7decd7bee5a2cbb90abddb1'
$created = [datetime]'2026-09-29T01:02:03.456Z'

function New-ProcessFixture(
  [int]$ProcessId,
  [string]$ExecutablePath = $nodePath,
  [datetime]$CreationDate = $created,
  [string]$CommandLine = ('"{0}" "{1}"' -f $nodePath, $gatewayPath)
) {
  [pscustomobject]@{
    ProcessId = $ProcessId
    ExecutablePath = $ExecutablePath
    CreationDate = $CreationDate
    CommandLine = $CommandLine
  }
}

$ownedRow = New-ProcessFixture -ProcessId 4101
$ownedLookup = { param([int]$RequestedProcessId) @($ownedRow) }.GetNewClosure()
$hashLookup = { param([string]$ExecutablePath) $nodeHash }.GetNewClosure()
$automaticPidBefore = $PID
$owned = Get-ExactProcessIdentity `
  -ProcessId 4101 `
  -ExpectedExe $nodePath `
  -ExpectedSha $nodeHash `
  -ExpectedArguments @($gatewayPath) `
  -PathArgumentIndexes @(0) `
  -ProcessLookup $ownedLookup `
  -HashLookup $hashLookup
Assert-Equal $owned.ProcessId 4101 'owned process identity should be returned'
Assert-Equal $PID $automaticPidBefore 'automatic PID must remain unchanged after invocation'

$foreignRow = New-ProcessFixture -ProcessId 4101 -ExecutablePath 'C:\Windows\System32\cmd.exe'
$foreignLookup = { param([int]$RequestedProcessId) @($foreignRow) }.GetNewClosure()
Assert-Throws {
  Get-ExactProcessIdentity -ProcessId 4101 -ExpectedExe $nodePath -ExpectedSha $nodeHash `
    -ExpectedArguments @($gatewayPath) -PathArgumentIndexes @(0) `
    -ProcessLookup $foreignLookup -HashLookup $hashLookup
} 'foreign executable' 'foreign executable must fail closed'

$spoofedRow = New-ProcessFixture -ProcessId 4101 -CommandLine ('"{0}" "D:\foreign\other.cjs" "{1}"' -f $nodePath, $gatewayPath)
$spoofedLookup = { param([int]$RequestedProcessId) @($spoofedRow) }.GetNewClosure()
Assert-Throws {
  Get-ExactProcessIdentity -ProcessId 4101 -ExpectedExe $nodePath -ExpectedSha $nodeHash `
    -ExpectedArguments @($gatewayPath) -PathArgumentIndexes @(0) `
    -ProcessLookup $spoofedLookup -HashLookup $hashLookup
} 'command identity mismatch' 'expected script as an unused extra argument must fail closed'

$tunnelPath = 'D:\EA_LAB_CONTROL\lnwjud-direct-v5.3.0\app\resources\tunnel-client\tunnel-client.exe'
$tunnelHash = 'fcc85a69ec0ad82518e4f8964f60c45e31787957782a0fc9c1b0c44e82d61b9b'
$profilePath = 'D:\EA_LAB_CONTROL\lnwjud-write-v1-20260928\ea-lab-lnwjud-write-v1.yaml'
$tunnelRow = New-ProcessFixture -ProcessId 4201 -ExecutablePath $tunnelPath `
  -CommandLine ('"{0}" run --profile-file "{1}"' -f $tunnelPath, $profilePath)
$tunnelLookup = { param([int]$RequestedProcessId) @($tunnelRow) }.GetNewClosure()
$tunnelHashLookup = { param([string]$ExecutablePath) $tunnelHash }.GetNewClosure()
$ownedTunnel = Get-ExactProcessIdentity -ProcessId 4201 -ExpectedExe $tunnelPath -ExpectedSha $tunnelHash `
  -ExpectedArguments @('run','--profile-file',$profilePath) -PathArgumentIndexes @(2) `
  -ProcessLookup $tunnelLookup -HashLookup $tunnelHashLookup
Assert-Equal $ownedTunnel.ProcessId 4201 'exact tunnel command/profile should be owned'

$spoofedTunnelRow = New-ProcessFixture -ProcessId 4201 -ExecutablePath $tunnelPath `
  -CommandLine ('"{0}" run --profile-file "D:\foreign\profile.yaml" "{1}"' -f $tunnelPath, $profilePath)
$spoofedTunnelLookup = { param([int]$RequestedProcessId) @($spoofedTunnelRow) }.GetNewClosure()
Assert-Throws {
  Get-ExactProcessIdentity -ProcessId 4201 -ExpectedExe $tunnelPath -ExpectedSha $tunnelHash `
    -ExpectedArguments @('run','--profile-file',$profilePath) -PathArgumentIndexes @(2) `
    -ProcessLookup $spoofedTunnelLookup -HashLookup $tunnelHashLookup
} 'command identity mismatch' 'expected profile as an unused extra argument must fail closed'

$wrongPidRow = New-ProcessFixture -ProcessId 9999
$wrongPidLookup = { param([int]$RequestedProcessId) @($wrongPidRow) }.GetNewClosure()
Assert-Throws {
  Get-ExactProcessIdentity -ProcessId 4101 -ExpectedExe $nodePath -ExpectedSha $nodeHash `
    -ExpectedArguments @($gatewayPath) -PathArgumentIndexes @(0) `
    -ProcessLookup $wrongPidLookup -HashLookup $hashLookup
} 'process id mismatch' 'PID mismatch must fail closed'

$stopCalls = [System.Collections.Generic.List[object]]::new()
$stopAction = { param([Diagnostics.Process]$ExactProcess) $stopCalls.Add($ExactProcess) }.GetNewClosure()
Assert-Throws {
  Stop-ExactOwnedProcess -ProcessId 4101 -CreationUtc $created `
    -ExpectedExe $nodePath -ExpectedSha $nodeHash -ExpectedArguments @($gatewayPath) `
    -PathArgumentIndexes @(0) -ProcessLookup $foreignLookup -HashLookup $hashLookup `
    -StopAction $stopAction
} 'foreign executable' 'foreign identity must refuse force-stop'
Assert-Equal $stopCalls.Count 0 'foreign identity must not invoke force-stop'
Assert-Throws {
  Stop-ExactOwnedProcess -ProcessId 4101 -CreationUtc $created.AddSeconds(1) `
    -ExpectedExe $nodePath -ExpectedSha $nodeHash -ExpectedArguments @($gatewayPath) `
    -PathArgumentIndexes @(0) -ProcessLookup $ownedLookup -HashLookup $hashLookup `
    -StopAction $stopAction
} 'creation identity changed' 'creation mismatch must refuse force-stop'
Assert-Equal $stopCalls.Count 0 'creation mismatch must not invoke force-stop'

$connectionLookup = {
  param([int]$Port)
  @([pscustomobject]@{ LocalPort = $Port; OwningProcess = 4101 })
}
$listenerRow = New-ProcessFixture -ProcessId 4101 `
  -CommandLine ('"{0}" "{1}" "{2}" {3}' -f $nodePath, $GatewayLoader, $gatewayPath, $gatewayHash)
$listenerProcessLookup = { param([int]$RequestedProcessId) @($listenerRow) }.GetNewClosure()
$sourceIdentityLookup = {
  param([int]$Port)
  [pscustomobject]@{schema='ea_lab_loaded_source_identity_v1';source_path=$gatewayPath;source_sha256=$gatewayHash;source_bytes=1234}
}.GetNewClosure()
$listener = Get-ExactOwnedListenerIdentity -Port 18768 -ExpectedScript $gatewayPath `
  -ExpectedSourceSha $gatewayHash -ConnectionLookup $connectionLookup -ProcessLookup $listenerProcessLookup `
  -HashLookup $hashLookup -SourceIdentityLookup $sourceIdentityLookup
Assert-Equal $listener.ProcessId 4101 'listener should bind to exact owned PID'
Assert-Equal $listener.CreationUtc.ToUniversalTime() $created.ToUniversalTime() 'listener should bind creation time'
Assert-Equal $listener.ExecutableSha256 $nodeHash 'listener should bind executable SHA256'

Assert-Throws {
  Get-ExactOwnedListenerIdentity -Port 18768 -ExpectedScript $gatewayPath `
    -ExpectedSourceSha $gatewayHash -ConnectionLookup $connectionLookup -ProcessLookup $foreignLookup `
    -HashLookup $hashLookup -SourceIdentityLookup $sourceIdentityLookup
} 'foreign executable' 'foreign listener owner must fail closed'
Assert-Throws {
  Get-ExactOwnedListenerIdentity -Port 18768 -ExpectedScript $gatewayPath `
    -ExpectedSourceSha $gatewayHash -ConnectionLookup $connectionLookup -ProcessLookup $spoofedLookup `
    -HashLookup $hashLookup -SourceIdentityLookup $sourceIdentityLookup
} 'command identity mismatch' 'listener with expected script as unused extra argument must fail closed'

$ambiguousConnections = {
  param([int]$Port)
  @(
    [pscustomobject]@{ LocalPort = $Port; OwningProcess = 4101 },
    [pscustomobject]@{ LocalPort = $Port; OwningProcess = 4102 }
  )
}
Assert-Throws {
  Get-ExactOwnedListenerIdentity -Port 18768 -ExpectedScript $gatewayPath `
    -ExpectedSourceSha $gatewayHash -ConnectionLookup $ambiguousConnections -ProcessLookup $listenerProcessLookup `
    -HashLookup $hashLookup -SourceIdentityLookup $sourceIdentityLookup
} 'ambiguous listener ownership' 'multiple listener rows must fail closed'

$routeListenerState = [pscustomobject]@{ Calls = 0 }
$routeListenerLookup = {
  param([int]$Port, [string]$ExpectedScript, [string]$ExpectedSourceSha)
  $routeListenerState.Calls++
  [pscustomobject]@{
    Port = $Port
    ProcessId = if ($Port -eq 18768) { 4101 } else { 4102 }
    CreationUtc = if ($Port -eq 18768) { $created } else { $created.AddSeconds(1) }
    ExecutablePath = $nodePath
    ExecutableSha256 = $nodeHash
    CommandLine = ('"{0}" "{1}"' -f $nodePath, $ExpectedScript)
    ScriptPath = $ExpectedScript
    LoadedSourcePath = $ExpectedScript
    LoadedSourceSha256 = $ExpectedSourceSha
    LoadedSourceBytes = 1234
  }
}.GetNewClosure()
$statusLookup = {
  param([string]$BaseUrl)
  [pscustomobject]@{ mcp_routes = @(
    [pscustomobject]@{ name = 'main'; target = '127.0.0.1:18768' },
    [pscustomobject]@{ name = 'frozen_v1'; target = '127.0.0.1:18767' }
  ) }
}
$healthLookup = { param([string]$Url) $true }
Assert-True (Route-IsReady -HealthBaseOverride 'http://fixture' -ListenerLookup $routeListenerLookup `
  -StatusLookup $statusLookup -HealthLookup $healthLookup) 'owned listeners and healthy exact routes should be ready'
Assert-Equal $routeListenerState.Calls 4 'ready route must bind both listeners before and after health checks'

$mismatchState = [pscustomobject]@{ Calls = 0 }
$mismatchListenerLookup = {
  param([int]$Port, [string]$ExpectedScript, [string]$ExpectedSourceSha)
  $mismatchState.Calls++
  $afterHealth = $mismatchState.Calls -gt 2
  [pscustomobject]@{
    Port = $Port
    ProcessId = if ($afterHealth -and $Port -eq 18768) { 5101 } elseif ($Port -eq 18768) { 4101 } else { 4102 }
    CreationUtc = if ($afterHealth -and $Port -eq 18768) { $created.AddMinutes(1) } elseif ($Port -eq 18768) { $created } else { $created.AddSeconds(1) }
    ExecutablePath = $nodePath
    ExecutableSha256 = $nodeHash
    CommandLine = ('"{0}" "{1}"' -f $nodePath, $ExpectedScript)
    ScriptPath = $ExpectedScript
    LoadedSourcePath = $ExpectedScript
    LoadedSourceSha256 = $ExpectedSourceSha
    LoadedSourceBytes = 1234
  }
}.GetNewClosure()
Assert-Throws {
  Route-IsReady -HealthBaseOverride 'http://fixture' -ListenerLookup $mismatchListenerLookup `
    -StatusLookup $statusLookup -HealthLookup $healthLookup
} 'listener identity changed' 'PID/creation change across health checks must fail closed'

. (Join-Path $Here 'install_tasks.ps1') -LibraryOnly

$taskXml=@'
<?xml version="1.0" encoding="UTF-16"?>
<Task xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>EA_LAB_LNWJUD_WRITE_V1_TASK_V1|invocation=00000000-0000-0000-0000-000000000001|role=REFRESH</Description></RegistrationInfo>
  <Triggers><TimeTrigger><Repetition><Interval>PT10M</Interval></Repetition></TimeTrigger></Triggers>
  <Principals><Principal><UserId>S-1-5-21-fixture</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Actions><Exec><Command>powershell.exe</Command><Arguments>-NoProfile -File "D:\path with space\refresh.ps1"</Arguments></Exec></Actions>
</Task>
'@
[void]('seed-42' -match 'seed-(\d+)')
$automaticMatchesBefore=$Matches[1]
$parsedTask=Get-TaskDefinitionIdentity -Name 'fixture' `
  -TaskInventoryAction {@([pscustomobject]@{TaskPath='\';TaskName='fixture'})} `
  -ExportTaskAction {param([string]$name) $taskXml}.GetNewClosure()
Assert-Equal $parsedTask.InvocationId '00000000-0000-0000-0000-000000000001' 'task definition parser must bind invocation UUID'
Assert-Equal $parsedTask.ActionArguments '-NoProfile -File "D:\path with space\refresh.ps1"' 'task definition parser must preserve quoted action'
Assert-Equal $parsedTask.TriggerKind 'TimeTrigger' 'task definition parser must bind trigger kind'
Assert-Equal $parsedTask.RepetitionInterval 'PT10M' 'task definition parser must bind repetition interval'
Assert-Equal $parsedTask.PrincipalUserId 'S-1-5-21-fixture' 'task definition parser must bind principal'
Assert-Equal $Matches[1] $automaticMatchesBefore 'task definition parser must not collide with automatic $Matches'

function New-TaskHarness {
  $state = [pscustomobject]@{
    Tasks = @{}
    CreateCalls = [System.Collections.Generic.List[string]]::new()
    DeleteCalls = [System.Collections.Generic.List[string]]::new()
    FailCreateName = ''
    CreateThenFailName = ''
    FailDeleteName = ''
    ReplaceStartBeforeFailure = $false
    FailQueryName = ''
    KeepAfterDelete = $false
  }
  $queryAction = {
    param([string]$Name)
    if($state.FailQueryName -eq $Name){throw "fixture query failure: $Name"}
    if($state.Tasks.ContainsKey($Name)){$state.Tasks[$Name]}else{$null}
  }.GetNewClosure()
  $createAction = {
    param($Spec)
    $state.CreateCalls.Add($Spec.Name)
    if($state.FailCreateName -eq $Spec.Name){
      if($state.ReplaceStartBeforeFailure){
        $state.Tasks[$StartTask]=[pscustomobject]@{
          Name=$StartTask;InvocationId='00000000-0000-0000-0000-000000000099';Description='foreign'
          ActionCommand='foreign.exe';ActionArguments='';WorkingDirectory='';TriggerKind='LogonTrigger'
          TriggerUserId='foreign';RepetitionInterval='';PrincipalUserId='foreign'
          PrincipalLogonType='InteractiveToken';PrincipalRunLevel='LeastPrivilege';DefinitionSha256=[string]::new([char]'f',64)
        }
      }
      throw "fixture create failure: $($Spec.Name)"
    }
    $state.Tasks[$Spec.Name] = [pscustomobject]@{
      Name=$Spec.Name;InvocationId=$Spec.InvocationId;Description=$Spec.Description
      ActionCommand=$Spec.ActionCommand;ActionArguments=$Spec.ActionArguments;WorkingDirectory=$Spec.WorkingDirectory
      TriggerKind=$Spec.TriggerKind;TriggerUserId=$Spec.TriggerUserId;RepetitionInterval=$Spec.RepetitionInterval
      PrincipalUserId=$Spec.PrincipalUserId;PrincipalLogonType=$Spec.PrincipalLogonType
      PrincipalRunLevel=$Spec.PrincipalRunLevel
      DefinitionSha256=[string]::new([char]'a',64)
    }
    if($state.CreateThenFailName -eq $Spec.Name){throw "fixture post-create failure: $($Spec.Name)"}
  }.GetNewClosure()
  $deleteAction = {
    param([string]$Name)
    $state.DeleteCalls.Add($Name)
    if($state.FailDeleteName -eq $Name){throw "fixture delete failure: $Name"}
    if(-not$state.KeepAfterDelete){[void]$state.Tasks.Remove($Name)}
  }.GetNewClosure()
  [pscustomobject]@{
    State = $state
    QueryAction = $queryAction
    CreateAction = $createAction
    DeleteAction = $deleteAction
  }
}

$fixtureInvocation='00000000-0000-0000-0000-000000000001'
$fixturePrincipal='S-1-5-21-fixture'
$successfulTasks = New-TaskHarness
$installResult = Invoke-WriteV1TaskInstall -TaskQueryAction $successfulTasks.QueryAction `
  -CreateTaskAction $successfulTasks.CreateAction -DeleteTaskAction $successfulTasks.DeleteAction `
  -InvocationId $fixtureInvocation -PrincipalUserId $fixturePrincipal
Assert-Equal $installResult.result 'PASS' 'fixture task transaction should complete'
Assert-Equal $successfulTasks.State.Tasks.Count 2 'successful transaction should retain both tasks'
Assert-Equal $installResult.invocation_id $fixtureInvocation 'successful transaction must retain invocation UUID'

$preexistingTasks = New-TaskHarness
$preexistingTasks.State.Tasks[$StartTask] = [pscustomobject]@{Name=$StartTask;InvocationId='foreign';DefinitionSha256=[string]::new([char]'f',64)}
Assert-Throws {
  Invoke-WriteV1TaskInstall -TaskQueryAction $preexistingTasks.QueryAction `
    -CreateTaskAction $preexistingTasks.CreateAction -DeleteTaskAction $preexistingTasks.DeleteAction `
    -InvocationId $fixtureInvocation -PrincipalUserId $fixturePrincipal
} 'existing WriteV1 Scheduled Task requires explicit ownership reconciliation' 'pre-existing same-name task must be refused'
Assert-Equal $preexistingTasks.State.CreateCalls.Count 0 'pre-existing refusal must happen before creation'

$cleanRollback = New-TaskHarness
$cleanRollback.State.FailCreateName = $RefreshTask
Assert-Throws {
  Invoke-WriteV1TaskInstall -TaskQueryAction $cleanRollback.QueryAction `
    -CreateTaskAction $cleanRollback.CreateAction -DeleteTaskAction $cleanRollback.DeleteAction `
    -InvocationId $fixtureInvocation -PrincipalUserId $fixturePrincipal
} 'fixture create failure' 'original creation failure should remain visible after verified rollback'
Assert-Equal $cleanRollback.State.Tasks.Count 0 'verified rollback should leave no partial task'
Assert-Equal $cleanRollback.State.DeleteCalls.Count 1 'verified rollback should delete the created start task once'

$postCreateFailure = New-TaskHarness
$postCreateFailure.State.CreateThenFailName = $RefreshTask
Assert-Throws {
  Invoke-WriteV1TaskInstall -TaskQueryAction $postCreateFailure.QueryAction `
    -CreateTaskAction $postCreateFailure.CreateAction -DeleteTaskAction $postCreateFailure.DeleteAction `
    -InvocationId $fixtureInvocation -PrincipalUserId $fixturePrincipal
} 'fixture post-create failure' 'create-then-fail should preserve original error after successful owned rollback'
Assert-Equal $postCreateFailure.State.Tasks.Count 0 'matching invocation tasks must roll back after create-then-fail'
Assert-Equal $postCreateFailure.State.DeleteCalls.Count 2 'both exact owned tasks should be deleted in reverse rollback'

$deleteFailure = New-TaskHarness
$deleteFailure.State.FailCreateName = $RefreshTask
$deleteFailure.State.FailDeleteName = $StartTask
Assert-Throws {
  Invoke-WriteV1TaskInstall -TaskQueryAction $deleteFailure.QueryAction `
    -CreateTaskAction $deleteFailure.CreateAction -DeleteTaskAction $deleteFailure.DeleteAction `
    -InvocationId $fixtureInvocation -PrincipalUserId $fixturePrincipal
} 'task installation failed:.*fixture create failure.*rollback failed:.*fixture delete failure' 'rollback delete failure must be aggregated with original failure'
Assert-True $deleteFailure.State.Tasks.ContainsKey($StartTask) 'failed delete fixture should preserve fail-visible partial task'

$absenceFailure = New-TaskHarness
$absenceFailure.State.FailCreateName = $RefreshTask
$absenceFailure.State.KeepAfterDelete = $true
Assert-Throws {
  Invoke-WriteV1TaskInstall -TaskQueryAction $absenceFailure.QueryAction `
    -CreateTaskAction $absenceFailure.CreateAction -DeleteTaskAction $absenceFailure.DeleteAction `
    -InvocationId $fixtureInvocation -PrincipalUserId $fixturePrincipal
} 'rollback absence verification failed' 'rollback must read back and reject a task that remains present'
Assert-True $absenceFailure.State.Tasks.ContainsKey($StartTask) 'absence failure fixture should remain visible'

$foreignReplacement = New-TaskHarness
$foreignReplacement.State.FailCreateName = $RefreshTask
$foreignReplacement.State.ReplaceStartBeforeFailure = $true
Assert-Throws {
  Invoke-WriteV1TaskInstall -TaskQueryAction $foreignReplacement.QueryAction `
    -CreateTaskAction $foreignReplacement.CreateAction -DeleteTaskAction $foreignReplacement.DeleteAction `
    -InvocationId $fixtureInvocation -PrincipalUserId $fixturePrincipal
} 'task ownership changed before rollback.*partial activation remains' 'foreign replacement must remain and be reported as partial activation'
Assert-Equal $foreignReplacement.State.DeleteCalls.Count 0 'foreign replacement must not be deleted'
Assert-True $foreignReplacement.State.Tasks.ContainsKey($StartTask) 'foreign replacement must remain fail-visible'

$queryFailure = New-TaskHarness
$queryFailure.State.FailCreateName = $RefreshTask
$queryFailure.State.FailQueryName = $StartTask
Assert-Throws {
  Invoke-WriteV1TaskInstall -TaskQueryAction $queryFailure.QueryAction `
    -CreateTaskAction $queryFailure.CreateAction -DeleteTaskAction $queryFailure.DeleteAction `
    -InvocationId $fixtureInvocation -PrincipalUserId $fixturePrincipal
} 'query failure' 'rollback query failure must fail closed and remain visible'
Assert-Equal $queryFailure.State.DeleteCalls.Count 0 'query failure must not authorize task deletion'

[pscustomobject]@{
  result = 'PASS'
  suite = 'write-v1-safety-s1'
  checks = 54
  runtime_activation = 'NOT_RUN'
} | ConvertTo-Json -Compress
