[CmdletBinding()]
param([switch]$RedFirst)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$script:CaseFailures = [System.Collections.Generic.List[string]]::new()
$script:CasePasses = [System.Collections.Generic.List[string]]::new()

function Assert-A1([bool]$Condition, [string]$Message) {
  if(-not $Condition){throw "assertion failed: $Message"}
}

function Invoke-A1Case([string]$Name, [scriptblock]$Action) {
  try {
    & $Action
    $script:CasePasses.Add($Name)
    Write-Output "A1_CASE_PASS $Name"
  }
  catch {
    $detail = "$Name`: $($_.Exception.Message)"
    $script:CaseFailures.Add($detail)
    Write-Output "A1_CASE_FAIL $detail"
  }
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$automaticProfileBefore = $PROFILE
. (Join-Path $here 'start_write_v1.ps1') -LibraryOnly
. (Join-Path $here 'install_tasks.ps1') -LibraryOnly

Invoke-A1Case 'automatic-variable-collisions' {
  Assert-A1 ($PROFILE -ceq $automaticProfileBefore) 'dot-sourcing supervisor changed automatic $PROFILE'
  $startAst = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $here 'start_write_v1.ps1'), [ref]$null, [ref]$null)
  $taskAst = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $here 'install_tasks.ps1'), [ref]$null, [ref]$null)
  $badNames = @(
    $startAst.FindAll({param($node) $node -is [Management.Automation.Language.VariableExpressionAst] -and $node.VariablePath.UserPath -ieq 'Profile'}, $true)
    $taskAst.FindAll({param($node) $node -is [Management.Automation.Language.VariableExpressionAst] -and $node.VariablePath.UserPath -ieq 'matches'}, $true)
  )
  Assert-A1 ($badNames.Count -eq 0) 'application variables still collide with $PROFILE or $Matches'
}

Invoke-A1Case 'discovery-unavailable-before-side-effects' {
  $effects = [pscustomobject]@{Count=0}
  $emptyResult = Invoke-WithDiscoveryPreflight -ProcessInventoryAction { @() } `
    -ListenerInventoryAction { @() } -Action {$effects.Count++; 'EMPTY_OK'}
  Assert-A1 ($emptyResult -eq 'EMPTY_OK') 'confirmed-empty inventories must allow the bounded action'
  Assert-A1 ($effects.Count -eq 1) 'confirmed-empty action should run exactly once'
  try {
    Invoke-WithDiscoveryPreflight -ProcessInventoryAction {throw 'process inventory denied'} `
      -ListenerInventoryAction { @() } -Action {$effects.Count++}
    throw 'unavailable process inventory was accepted'
  } catch {
    Assert-A1 ($_.Exception.Message -match 'process inventory denied') 'process discovery error was not preserved'
  }
  try {
    Invoke-WithDiscoveryPreflight -ProcessInventoryAction { @() } `
      -ListenerInventoryAction {throw 'listener inventory denied'} -Action {$effects.Count++}
    throw 'unavailable listener inventory was accepted'
  } catch {
    Assert-A1 ($_.Exception.Message -match 'listener inventory denied') 'listener discovery error was not preserved'
  }
  Assert-A1 ($effects.Count -eq 1) 'unavailable inventory must not run launch/stop action'
}

Invoke-A1Case 'pid-reuse-handle-bound-stop' {
  $pwsh = Join-Path $PSHOME 'powershell.exe'
  $childArgs = @('-NoProfile','-Command','Start-Sleep -Seconds 30')
  $child = Start-Process -FilePath $pwsh -ArgumentList $childArgs -WindowStyle Hidden -PassThru
  try {
    [void]$child.Handle
    $createdUtc = $child.StartTime.ToUniversalTime()
    $commandLine = ('"{0}" -NoProfile -Command "Start-Sleep -Seconds 30"' -f $pwsh)
    $row = [pscustomobject]@{
      ProcessId=$child.Id; ExecutablePath=$pwsh; CreationDate=$createdUtc; CommandLine=$commandLine
    }
    $lookup = {param([int]$requested) @($row)}.GetNewClosure()
    $pwshHash = (Get-FileHash -LiteralPath $pwsh -Algorithm SHA256).Hash.ToLowerInvariant()
    $hashLookup = {param([string]$path) $pwshHash}.GetNewClosure()
    $afterValidation = {
      param($boundProcess)
      Assert-A1 ($boundProcess -is [Diagnostics.Process]) 'validation hook did not receive retained Process handle owner'
      $child.Kill()
      [void]$child.WaitForExit(5000)
    }.GetNewClosure()
    try {
      Stop-ExactOwnedProcess -ProcessId $child.Id -CreationUtc $createdUtc -ExpectedExe $pwsh `
        -ExpectedSha $pwshHash -ExpectedArguments $childArgs -PathArgumentIndexes @() `
        -ProcessLookup $lookup -HashLookup $hashLookup -AfterValidationAction $afterValidation
      throw 'exited bound process was reported terminated'
    } catch {
      Assert-A1 ($_.Exception.Message -match 'bound process exited before termination') `
        'exit/reuse window did not fail closed through retained handle'
    }
  }
  finally {
    try{if(-not $child.HasExited){$child.Kill();[void]$child.WaitForExit(5000)}}catch{}
    $child.Dispose()
  }
}

Invoke-A1Case 'stale-loaded-gateway-refused' {
  $created = [datetime]'2026-09-29T01:02:03.456Z'
  $calls = [pscustomobject]@{Count=0}
  $listenerLookup = {
    param([int]$port,[string]$scriptPath,[string]$expectedSourceSha)
    $calls.Count++
    [pscustomobject]@{
      Port=$port; ProcessId=if($port-eq18768){4101}else{4102}; CreationUtc=$created
      ExecutablePath=$Node; ExecutableSha256=$ExpectedNodeSha
      CommandLine='fixture'; ScriptPath=$scriptPath
      LoadedSourcePath=$scriptPath; LoadedSourceSha256=('0' * 64); LoadedSourceBytes=1
    }
  }.GetNewClosure()
  $statusLookup = {param([string]$base) [pscustomobject]@{mcp_routes=@(
    [pscustomobject]@{name='main';target='127.0.0.1:18768'},
    [pscustomobject]@{name='frozen_v1';target='127.0.0.1:18767'})}}
  $healthLookup = {param([string]$url) $true}
  try {
    [void](Route-IsReady -HealthBaseOverride 'http://fixture' -ListenerLookup $listenerLookup `
      -StatusLookup $statusLookup -HealthLookup $healthLookup)
    throw 'stale loaded source was adopted'
  } catch {
    Assert-A1 ($_.Exception.Message -match 'loaded source SHA256 mismatch') 'stale loaded bytes were not refused'
  }
  Assert-A1 ($calls.Count -eq 1) 'stale source must fail during first listener proof before health/adoption'
}

Invoke-A1Case 'a2-default-route-listener-binding-forwards-source-sha' {
  $created = [datetime]'2026-09-30T01:02:03.456Z'
  $routeCalls = [System.Collections.Generic.List[object]]::new()
  $originalListenerIdentity = ${function:Get-ExactOwnedListenerIdentity}
  $listenerIdentitySpy = {
    param([int]$port,[string]$scriptPath,[string]$expectedSourceSha)
    $routeCalls.Add([pscustomobject]@{Port=$port;ScriptPath=$scriptPath;ExpectedSourceSha=$expectedSourceSha})
    $loadedSha = if($port-eq18768){$ExpectedWriteSha}else{$ExpectedV2Sha}
    [pscustomobject]@{
      Port=$port;ProcessId=if($port-eq18768){8101}else{8102};CreationUtc=$created
      ExecutablePath=$Node;ExecutableSha256=$ExpectedNodeSha;CommandLine='a2-fixture'
      ScriptPath=$scriptPath;LoadedSourcePath=$scriptPath;LoadedSourceSha256=$loadedSha;LoadedSourceBytes=1234
    }
  }.GetNewClosure()
  $statusLookup = {param([string]$base) [pscustomobject]@{mcp_routes=@(
    [pscustomobject]@{name='main';target='127.0.0.1:18768'},
    [pscustomobject]@{name='frozen_v1';target='127.0.0.1:18767'})}}
  $healthLookup = {param([string]$url) $true}
  try {
    Set-Item -Path Function:\script:Get-ExactOwnedListenerIdentity -Value $listenerIdentitySpy
    Assert-A1 (Route-IsReady -HealthBaseOverride 'http://fixture' `
      -StatusLookup $statusLookup -HealthLookup $healthLookup) 'default production route binding should be ready'
  }
  finally {
    Set-Item -Path Function:\script:Get-ExactOwnedListenerIdentity -Value $originalListenerIdentity
  }
  Assert-A1 ($routeCalls.Count -eq 4) 'default route binding must check both listeners before and after health'
  foreach($call in $routeCalls){
    $expectedScript = if($call.Port-eq18768){$WriteBundle}else{$V2Bundle}
    $expectedSha = if($call.Port-eq18768){$ExpectedWriteSha}else{$ExpectedV2Sha}
    Assert-A1 ([string]$call.ScriptPath -ceq $expectedScript) "default route script mismatch port=$($call.Port)"
    Assert-A1 ([string]$call.ExpectedSourceSha -ceq $expectedSha) `
      "default route expected SHA not forwarded port=$($call.Port) observed='$($call.ExpectedSourceSha)'"
  }
}

Invoke-A1Case 'a2-listener-source-sha-fails-closed-and-reaches-loaded-identity' {
  $created = [datetime]'2026-09-30T01:02:03.456Z'
  $connectionLookup = {param([int]$port) @([pscustomobject]@{LocalPort=$port;OwningProcess=8201})}
  $hashLookup = {param([string]$path) $ExpectedNodeSha}.GetNewClosure()

  $missingBoundaryCalls = [pscustomobject]@{Count=0}
  try {
    [void](Get-ExactOwnedListenerIdentity -Port 18768 -ExpectedScript $WriteBundle `
      -ConnectionLookup {param([int]$port) $missingBoundaryCalls.Count++;@()}.GetNewClosure())
    throw 'missing expected source SHA was accepted'
  } catch {
    Assert-A1 ($_.Exception.Message -match 'expected source SHA256 required') 'missing expected source SHA did not fail closed'
  }
  Assert-A1 ($missingBoundaryCalls.Count -eq 0) 'missing expected source SHA reached listener discovery'

  $emptyRow = [pscustomobject]@{
    ProcessId=8201;ExecutablePath=$Node;CreationDate=$created
    CommandLine=('"{0}" "{1}" "{2}" ""' -f $Node,$GatewayLoader,$WriteBundle)
  }
  try {
    [void](Get-ExactOwnedListenerIdentity -Port 18768 -ExpectedScript $WriteBundle -ExpectedSourceSha '' `
      -ConnectionLookup $connectionLookup -ProcessLookup {param([int]$pid) @($emptyRow)}.GetNewClosure() `
      -HashLookup $hashLookup -SourceIdentityLookup {param([int]$port) [pscustomobject]@{
        schema='ea_lab_loaded_source_identity_v1';source_path=$WriteBundle;source_sha256='';source_bytes=1234
      }}.GetNewClosure())
    throw 'empty expected source SHA was accepted'
  } catch {
    Assert-A1 ($_.Exception.Message -match 'expected source SHA256 required') 'empty expected source SHA did not fail closed'
  }

  $wrongSha = ('f' * 64)
  $wrongRow = [pscustomobject]@{
    ProcessId=8201;ExecutablePath=$Node;CreationDate=$created
    CommandLine=('"{0}" "{1}" "{2}" {3}' -f $Node,$GatewayLoader,$WriteBundle,$wrongSha)
  }
  try {
    [void](Get-ExactOwnedListenerIdentity -Port 18768 -ExpectedScript $WriteBundle -ExpectedSourceSha $wrongSha `
      -ConnectionLookup $connectionLookup -ProcessLookup {param([int]$pid) @($wrongRow)}.GetNewClosure() `
      -HashLookup $hashLookup -SourceIdentityLookup {param([int]$port) [pscustomobject]@{
        schema='ea_lab_loaded_source_identity_v1';source_path=$WriteBundle;source_sha256=$ExpectedWriteSha;source_bytes=1234
      }}.GetNewClosure())
    throw 'wrong expected source SHA was accepted'
  } catch {
    Assert-A1 ($_.Exception.Message -match 'loaded source SHA256 mismatch') 'wrong expected source SHA did not fail closed'
  }

  $identityCalls = [pscustomobject]@{Count=0}
  $correctRow = [pscustomobject]@{
    ProcessId=8201;ExecutablePath=$Node;CreationDate=$created
    CommandLine=('"{0}" "{1}" "{2}" {3}' -f $Node,$GatewayLoader,$WriteBundle,$ExpectedWriteSha)
  }
  $correct = Get-ExactOwnedListenerIdentity -Port 18768 -ExpectedScript $WriteBundle `
    -ExpectedSourceSha $ExpectedWriteSha -ConnectionLookup $connectionLookup `
    -ProcessLookup {param([int]$pid) @($correctRow)}.GetNewClosure() -HashLookup $hashLookup `
    -SourceIdentityLookup {param([int]$port) $identityCalls.Count++;[pscustomobject]@{
      schema='ea_lab_loaded_source_identity_v1';source_path=$WriteBundle;source_sha256=$ExpectedWriteSha;source_bytes=1234
    }}.GetNewClosure()
  Assert-A1 ($identityCalls.Count -eq 1) 'correct expected source SHA did not reach loaded-source identity check'
  Assert-A1 ($correct.LoadedSourceSha256 -ceq $ExpectedWriteSha) 'correct loaded-source identity was not retained'
}

Invoke-A1Case 'foreign-task-replacement-not-deleted' {
  $owned = [pscustomobject]@{Name='fixture';InvocationId='owned';DefinitionSha256=[string]::new([char]'a',64)}
  $foreign = [pscustomobject]@{Name='fixture';InvocationId='foreign';DefinitionSha256=[string]::new([char]'b',64)}
  $deleteCalls = [pscustomobject]@{Count=0}
  try {
    Remove-CreatedTask -OwnedIdentity $owned -TaskQueryAction {param([string]$name) $foreign}.GetNewClosure() `
      -DeleteTaskAction {param([string]$name) $deleteCalls.Count++}.GetNewClosure()
    throw 'foreign replacement was accepted as owned'
  } catch {
    Assert-A1 ($_.Exception.Message -match 'task ownership changed before rollback') 'foreign replacement mismatch was not reported'
  }
  Assert-A1 ($deleteCalls.Count -eq 0) 'foreign replacement must never be deleted'
}

Invoke-A1Case 'duplicate-start-owned-adoption' {
  $routeChecks=[pscustomobject]@{Count=0}
  $ownedTunnel=[pscustomobject]@{ProcessId=7001;CreationUtc=[datetime]::UtcNow;Process=$null}
  $state=Resolve-WriteV1StartupState -ExistingTunnelProcesses @($ownedTunnel) -RouteReadyAction {
    $routeChecks.Count++;$true
  }.GetNewClosure()
  Assert-A1 ($state.Action -eq 'ADOPT_EXISTING') 'verifiably owned ready route must be adopted'
  Assert-A1 (-not$state.LaunchAllowed) 'duplicate START must not receive launch authority'
  Assert-A1 ($routeChecks.Count -eq 1) 'duplicate START must verify the existing route exactly once'
  try{
    [void](Resolve-WriteV1StartupState -ExistingTunnelProcesses @($ownedTunnel) -RouteReadyAction {throw 'source identity unavailable'})
    throw 'unverifiable existing route was treated as launchable'
  }catch{Assert-A1 ($_.Exception.Message -match 'source identity unavailable') 'unverifiable duplicate did not fail closed'}
}

if($script:CaseFailures.Count -gt 0){
  $mode = if($RedFirst){'RED_FIRST_EXPECTED'}else{'FAIL'}
  throw "$mode A1 failures=$($script:CaseFailures.Count): $($script:CaseFailures -join ' | ')"
}

[pscustomobject]@{
  result='PASS'
  suite='write-v1-amendment-a1'
  checks=$script:CasePasses.Count
  runtime_activation='NOT_RUN'
} | ConvertTo-Json -Compress
