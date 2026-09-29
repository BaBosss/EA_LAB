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

$stopCalls = [System.Collections.Generic.List[int]]::new()
$stopAction = { param([int]$ExactProcessId) $stopCalls.Add($ExactProcessId) }.GetNewClosure()
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

Stop-ExactOwnedProcess -ProcessId 4101 -CreationUtc $created `
  -ExpectedExe $nodePath -ExpectedSha $nodeHash -ExpectedArguments @($gatewayPath) `
  -PathArgumentIndexes @(0) -ProcessLookup $ownedLookup -HashLookup $hashLookup `
  -StopAction $stopAction
Assert-Equal $stopCalls.Count 1 'exact owned identity should invoke force-stop once'
Assert-Equal $stopCalls[0] 4101 'force-stop should target the exact owned PID'

$connectionLookup = {
  param([int]$Port)
  @([pscustomobject]@{ LocalPort = $Port; OwningProcess = 4101 })
}
$listener = Get-ExactOwnedListenerIdentity -Port 18768 -ExpectedScript $gatewayPath `
  -ConnectionLookup $connectionLookup -ProcessLookup $ownedLookup -HashLookup $hashLookup
Assert-Equal $listener.ProcessId 4101 'listener should bind to exact owned PID'
Assert-Equal $listener.CreationUtc.ToUniversalTime() $created.ToUniversalTime() 'listener should bind creation time'
Assert-Equal $listener.ExecutableSha256 $nodeHash 'listener should bind executable SHA256'

Assert-Throws {
  Get-ExactOwnedListenerIdentity -Port 18768 -ExpectedScript $gatewayPath `
    -ConnectionLookup $connectionLookup -ProcessLookup $foreignLookup -HashLookup $hashLookup
} 'foreign executable' 'foreign listener owner must fail closed'
Assert-Throws {
  Get-ExactOwnedListenerIdentity -Port 18768 -ExpectedScript $gatewayPath `
    -ConnectionLookup $connectionLookup -ProcessLookup $spoofedLookup -HashLookup $hashLookup
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
    -ConnectionLookup $ambiguousConnections -ProcessLookup $ownedLookup -HashLookup $hashLookup
} 'ambiguous listener ownership' 'multiple listener rows must fail closed'

$routeListenerState = [pscustomobject]@{ Calls = 0 }
$routeListenerLookup = {
  param([int]$Port, [string]$ExpectedScript)
  $routeListenerState.Calls++
  [pscustomobject]@{
    Port = $Port
    ProcessId = if ($Port -eq 18768) { 4101 } else { 4102 }
    CreationUtc = if ($Port -eq 18768) { $created } else { $created.AddSeconds(1) }
    ExecutablePath = $nodePath
    ExecutableSha256 = $nodeHash
    CommandLine = ('"{0}" "{1}"' -f $nodePath, $ExpectedScript)
    ScriptPath = $ExpectedScript
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
  param([int]$Port, [string]$ExpectedScript)
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
  }
}.GetNewClosure()
Assert-Throws {
  Route-IsReady -HealthBaseOverride 'http://fixture' -ListenerLookup $mismatchListenerLookup `
    -StatusLookup $statusLookup -HealthLookup $healthLookup
} 'listener identity changed' 'PID/creation change across health checks must fail closed'

. (Join-Path $Here 'install_tasks.ps1') -LibraryOnly

function New-TaskHarness {
  $state = [pscustomobject]@{
    Tasks = @{}
    CreateCalls = [System.Collections.Generic.List[string]]::new()
    DeleteCalls = [System.Collections.Generic.List[string]]::new()
    FailCreateName = ''
    CreateThenFailName = ''
    FailDeleteName = ''
    KeepAfterDelete = $false
  }
  $existsAction = {
    param([string]$Name)
    $state.Tasks.ContainsKey($Name)
  }.GetNewClosure()
  $createAction = {
    param([string]$Name, [string]$Action, [string]$Schedule, [int]$Modifier)
    $state.CreateCalls.Add($Name)
    if($state.FailCreateName -eq $Name){throw "fixture create failure: $Name"}
    $state.Tasks[$Name] = [pscustomobject]@{Action=$Action;Schedule=$Schedule;Modifier=$Modifier}
    if($state.CreateThenFailName -eq $Name){throw "fixture post-create failure: $Name"}
  }.GetNewClosure()
  $deleteAction = {
    param([string]$Name)
    $state.DeleteCalls.Add($Name)
    if($state.FailDeleteName -eq $Name){throw "fixture delete failure: $Name"}
    if(-not$state.KeepAfterDelete){[void]$state.Tasks.Remove($Name)}
  }.GetNewClosure()
  [pscustomobject]@{
    State = $state
    ExistsAction = $existsAction
    CreateAction = $createAction
    DeleteAction = $deleteAction
  }
}

$successfulTasks = New-TaskHarness
$installResult = Invoke-WriteV1TaskInstall -TaskExistsAction $successfulTasks.ExistsAction `
  -CreateTaskAction $successfulTasks.CreateAction -DeleteTaskAction $successfulTasks.DeleteAction
Assert-Equal $installResult.result 'PASS' 'fixture task transaction should complete'
Assert-Equal $successfulTasks.State.Tasks.Count 2 'successful transaction should retain both tasks'

$preexistingTasks = New-TaskHarness
$preexistingTasks.State.Tasks[$StartTask] = [pscustomobject]@{Action='foreign'}
Assert-Throws {
  Invoke-WriteV1TaskInstall -TaskExistsAction $preexistingTasks.ExistsAction `
    -CreateTaskAction $preexistingTasks.CreateAction -DeleteTaskAction $preexistingTasks.DeleteAction
} 'existing WriteV1 Scheduled Task requires explicit ownership reconciliation' 'pre-existing same-name task must be refused'
Assert-Equal $preexistingTasks.State.CreateCalls.Count 0 'pre-existing refusal must happen before creation'

$cleanRollback = New-TaskHarness
$cleanRollback.State.FailCreateName = $RefreshTask
Assert-Throws {
  Invoke-WriteV1TaskInstall -TaskExistsAction $cleanRollback.ExistsAction `
    -CreateTaskAction $cleanRollback.CreateAction -DeleteTaskAction $cleanRollback.DeleteAction
} 'fixture create failure' 'original creation failure should remain visible after verified rollback'
Assert-Equal $cleanRollback.State.Tasks.Count 0 'verified rollback should leave no partial task'
Assert-Equal $cleanRollback.State.DeleteCalls.Count 1 'verified rollback should delete the created start task once'

$postCreateFailure = New-TaskHarness
$postCreateFailure.State.CreateThenFailName = $StartTask
Assert-Throws {
  Invoke-WriteV1TaskInstall -TaskExistsAction $postCreateFailure.ExistsAction `
    -CreateTaskAction $postCreateFailure.CreateAction -DeleteTaskAction $postCreateFailure.DeleteAction
} 'task installation failed:.*fixture post-create failure.*partial activation remains' 'create-then-fail must surface remaining partial activation'
Assert-True $postCreateFailure.State.Tasks.ContainsKey($StartTask) 'unowned post-create failure must remain fail-visible rather than be silently deleted'

$deleteFailure = New-TaskHarness
$deleteFailure.State.FailCreateName = $RefreshTask
$deleteFailure.State.FailDeleteName = $StartTask
Assert-Throws {
  Invoke-WriteV1TaskInstall -TaskExistsAction $deleteFailure.ExistsAction `
    -CreateTaskAction $deleteFailure.CreateAction -DeleteTaskAction $deleteFailure.DeleteAction
} 'task installation failed:.*fixture create failure.*rollback failed:.*fixture delete failure' 'rollback delete failure must be aggregated with original failure'
Assert-True $deleteFailure.State.Tasks.ContainsKey($StartTask) 'failed delete fixture should preserve fail-visible partial task'

$absenceFailure = New-TaskHarness
$absenceFailure.State.FailCreateName = $RefreshTask
$absenceFailure.State.KeepAfterDelete = $true
Assert-Throws {
  Invoke-WriteV1TaskInstall -TaskExistsAction $absenceFailure.ExistsAction `
    -CreateTaskAction $absenceFailure.CreateAction -DeleteTaskAction $absenceFailure.DeleteAction
} 'rollback absence verification failed' 'rollback must read back and reject a task that remains present'
Assert-True $absenceFailure.State.Tasks.ContainsKey($StartTask) 'absence failure fixture should remain visible'

[pscustomobject]@{
  result = 'PASS'
  suite = 'write-v1-safety-s1'
  checks = 37
  runtime_activation = 'NOT_RUN'
} | ConvertTo-Json -Compress
