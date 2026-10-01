[CmdletBinding()]
param(
  [switch]$CheckOnly,
  [switch]$LibraryOnly
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Security
Set-StrictMode -Version 2.0
[Console]::OutputEncoding=[Text.UTF8Encoding]::new()

$OldRoot='D:\EA_LAB_CONTROL\lnwjud-direct-v5.3.0'
$V2Root='D:\EA_LAB_CONTROL\lnwjud-current-read-v2-20260922'
$Root='D:\EA_LAB_CONTROL\lnwjud-write-v1-20260928'
$Evidence='D:\EA_LAB_CONTROL\evidence\lnwjud-write-v1-20260928'
$Node='C:\Program Files\nodejs\node.exe'
$TunnelClient=Join-Path $OldRoot 'app\resources\tunnel-client\tunnel-client.exe'
$V2Bundle=Join-Path $V2Root 'EA_LAB_CurrentRead_V2_HTTP_Gateway.bundle.cjs'
$WriteBundle=Join-Path $Root 'EA_LAB_CurrentWrite_V1_HTTP_Gateway.bundle.cjs'
$WriteSeal=Join-Path $Root 'snapshot\snapshot_seal.json'
$Vault=Join-Path $OldRoot 'secure-credentials\lnwjud-currentuser.dpapi'
$SecretPath=Join-Path $OldRoot 'secure-tunnel-read\runtime-api-key.secret'
$TunnelProfilePath=Join-Path $Root 'ea-lab-lnwjud-write-v1.yaml'
$HealthFile=Join-Path $Root 'health-write-v1.url'
$Receipt=Join-Path $Evidence 'LNWJUD_WRITE_V1_SUPERVISOR_LAST.json'
$GatewayLoader=Join-Path $Root 'source_bound_gateway_loader.cjs'
$ExpectedNodeSha='3602f2bb1a10f2cbab4c36886218a33c1ab3db87290e73b033c46c77147d0237'
$ExpectedTunnelSha='fcc85a69ec0ad82518e4f8964f60c45e31787957782a0fc9c1b0c44e82d61b9b'
$ExpectedV2Sha='c8dd4c130398c7dd192c48edeef53d836a739583df569b492a5b4b170a6958b1'
$ExpectedWriteSha='751446b59abe9b54a967f2cb6e2e38ce2f2bd84128d380457aaa647d8c72e216'
$ExpectedGatewayLoaderSha='06593b76abd45e53ec691455c70b9e7486d34b487eb846510d8dd0a2cfaca505'
$VaultEntropy=[Text.Encoding]::UTF8.GetBytes('EA_LAB_LNWJUD_VAULT_V1|BaBoss|CurrentUser')
$Utf8NoBom=New-Object Text.UTF8Encoding($false)

if(-not('EaLab.Lnwjud.NativeCommandLineV1' -as [type])){
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace EaLab.Lnwjud {
  public static class NativeCommandLineV1 {
    [DllImport("shell32.dll", SetLastError = true)]
    public static extern IntPtr CommandLineToArgvW(
      [MarshalAs(UnmanagedType.LPWStr)] string commandLine,
      out int argumentCount);

    [DllImport("kernel32.dll")]
    public static extern IntPtr LocalFree(IntPtr memory);
  }
}
'@
}

function Sha([string]$Path){
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "missing required file: $Path"}
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Wait-Ready([string]$Url,[int]$Seconds=10){
  $deadline=[DateTime]::UtcNow.AddSeconds($Seconds)
  while([DateTime]::UtcNow-lt$deadline){
    try{$r=Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2;if([int]$r.StatusCode-eq200-and([string]$r.Content).Trim()-eq'ready'){return $true}}catch{}
    Start-Sleep -Milliseconds 250
  }
  $false
}
function Get-ProcessInventory(
  [scriptblock]$InventoryAction={@(Get-CimInstance Win32_Process -ErrorAction Stop)}
){
  @(& $InventoryAction)
}
function Get-ListenerInventory(
  [scriptblock]$InventoryAction={@(Get-NetTCPConnection -State Listen -ErrorAction Stop)}
){
  @(& $InventoryAction)
}
function Invoke-WithDiscoveryPreflight(
  [scriptblock]$ProcessInventoryAction={@(Get-CimInstance Win32_Process -ErrorAction Stop)},
  [scriptblock]$ListenerInventoryAction={@(Get-NetTCPConnection -State Listen -ErrorAction Stop)},
  [scriptblock]$Action
){
  [void]@(Get-ProcessInventory -InventoryAction $ProcessInventoryAction)
  [void]@(Get-ListenerInventory -InventoryAction $ListenerInventoryAction)
  & $Action
}
function Wait-PortFree(
  [int]$Port,
  [int]$Seconds=15,
  [scriptblock]$ListenerInventoryAction={@(Get-NetTCPConnection -State Listen -ErrorAction Stop)}
){
  $deadline=[DateTime]::UtcNow.AddSeconds($Seconds)
  while([DateTime]::UtcNow-lt$deadline){
    $listeners=@(Get-ListenerInventory -InventoryAction $ListenerInventoryAction|Where-Object{
      [int]$_.LocalPort-eq$Port-and([string]$_.LocalAddress-eq'127.0.0.1'-or[string]$_.LocalAddress-eq'::1')
    })
    if($listeners.Count-eq0){return $true}
    Start-Sleep -Milliseconds 250
  }
  $false
}
function New-MinimalProcess([string]$File,[string[]]$ArgList){
  $psi=New-Object Diagnostics.ProcessStartInfo
  $psi.FileName=$File
  $psi.Arguments=($ArgList|ForEach-Object{if($_-match'[\s"]'){'"'+($_-replace'"','\"')+'"'}else{$_}})-join' '
  $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.EnvironmentVariables.Clear()
  foreach($k in @('APPDATA','COMSPEC','HOMEDRIVE','HOMEPATH','LOCALAPPDATA','SystemRoot','TEMP','TMP','USERPROFILE','WINDIR')){
    $v=[Environment]::GetEnvironmentVariable($k,'Process');if($v){$psi.EnvironmentVariables[$k]=$v}
  }
  $p=New-Object Diagnostics.Process;$p.StartInfo=$psi;[void]$p.Start();[void]$p.Handle;$p
}
function Stop-Child($p){
  if($null-eq$p){return}
  try{if(-not$p.HasExited){$p.Kill()}}catch{}
  try{$p.WaitForExit(5000)|Out-Null}catch{}
  try{$p.Dispose()}catch{}
}
function Split-WindowsCommandLine([string]$CommandLine){
  if([string]::IsNullOrWhiteSpace($CommandLine)){throw 'process command identity unavailable'}
  $argumentCount=0
  $argv=[EaLab.Lnwjud.NativeCommandLineV1]::CommandLineToArgvW($CommandLine,[ref]$argumentCount)
  if($argv-eq[IntPtr]::Zero){throw 'process command identity parse failed'}
  try{
    $arguments=@()
    for($i=0;$i-lt$argumentCount;$i++){
      $ptr=[Runtime.InteropServices.Marshal]::ReadIntPtr($argv,$i*[IntPtr]::Size)
      $arguments+=[Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
    }
    $arguments
  }finally{
    [void][EaLab.Lnwjud.NativeCommandLineV1]::LocalFree($argv)
  }
}
function Assert-ExactCommandIdentity(
  [string]$CommandLine,
  [string]$ExpectedExe,
  [string[]]$ExpectedArguments,
  [int[]]$PathArgumentIndexes=@()
){
  $actual=@(Split-WindowsCommandLine $CommandLine)
  if($actual.Count-ne(1+$ExpectedArguments.Count)){throw 'process command identity mismatch: argument count'}
  if([IO.Path]::GetFullPath([string]$actual[0])-ine[IO.Path]::GetFullPath($ExpectedExe)){
    throw 'process command identity mismatch: executable token'
  }
  for($i=0;$i-lt$ExpectedArguments.Count;$i++){
    if($PathArgumentIndexes-contains$i){
      if([IO.Path]::GetFullPath([string]$actual[$i+1])-ine[IO.Path]::GetFullPath([string]$ExpectedArguments[$i])){
        throw "process command identity mismatch: path argument $i"
      }
    }elseif([string]$actual[$i+1]-cne[string]$ExpectedArguments[$i]){
      throw "process command identity mismatch: argument $i"
    }
  }
}
function Get-ExactProcessIdentity(
  [int]$ProcessId,
  [string]$ExpectedExe,
  [string]$ExpectedSha,
  [string[]]$ExpectedArguments,
  [int[]]$PathArgumentIndexes=@(),
  [scriptblock]$ProcessLookup={param([int]$LookupProcessId) @(Get-ProcessInventory|Where-Object{[int]$_.ProcessId-eq$LookupProcessId})},
  [scriptblock]$HashLookup={param([string]$ExecutablePath) Sha $ExecutablePath}
){
  $rows=@(& $ProcessLookup $ProcessId)
  if($rows.Count-ne1){throw "process identity unavailable pid=$ProcessId"}
  $proc=$rows[0]
  if([int]$proc.ProcessId-ne$ProcessId){throw "process id mismatch requested=$ProcessId observed=$($proc.ProcessId)"}
  if([string]::IsNullOrWhiteSpace([string]$proc.ExecutablePath)-or[IO.Path]::GetFullPath([string]$proc.ExecutablePath)-ine[IO.Path]::GetFullPath($ExpectedExe)){throw "foreign executable pid=$ProcessId"}
  if(([string](& $HashLookup ([string]$proc.ExecutablePath))).ToLowerInvariant()-ne$ExpectedSha.ToLowerInvariant()){throw "executable hash mismatch pid=$ProcessId"}
  if([string]::IsNullOrWhiteSpace([string]$proc.CreationDate)){throw "process creation identity unavailable pid=$ProcessId"}
  Assert-ExactCommandIdentity ([string]$proc.CommandLine) $ExpectedExe $ExpectedArguments $PathArgumentIndexes
  $proc
}
function Open-ExactOwnedProcess(
  [int]$ProcessId,
  [datetime]$CreationUtc,
  [string]$ExpectedExe,
  [string]$ExpectedSha,
  [string[]]$ExpectedArguments,
  [int[]]$PathArgumentIndexes=@(),
  [scriptblock]$ProcessLookup={param([int]$LookupProcessId) @(Get-ProcessInventory|Where-Object{[int]$_.ProcessId-eq$LookupProcessId})},
  [scriptblock]$HashLookup={param([string]$ExecutablePath) Sha $ExecutablePath},
  [scriptblock]$ProcessHandleAcquire={param([int]$ExactProcessId) [Diagnostics.Process]::GetProcessById($ExactProcessId)}
){
  $proc=Get-ExactProcessIdentity -ProcessId $ProcessId -ExpectedExe $ExpectedExe -ExpectedSha $ExpectedSha `
    -ExpectedArguments $ExpectedArguments -PathArgumentIndexes $PathArgumentIndexes `
    -ProcessLookup $ProcessLookup -HashLookup $HashLookup
  $observed=([datetime]$proc.CreationDate).ToUniversalTime()
  if([Math]::Abs(($observed-$CreationUtc.ToUniversalTime()).TotalMilliseconds)-gt1){throw "process creation identity changed pid=$ProcessId"}
  $boundProcess=$null
  try{
    $boundProcess=& $ProcessHandleAcquire $ProcessId
    if($null-eq$boundProcess-or-not($boundProcess-is[Diagnostics.Process])){throw "process handle acquisition failed pid=$ProcessId"}
    [void]$boundProcess.Handle
    if([int]$boundProcess.Id-ne$ProcessId){throw "bound process id mismatch pid=$ProcessId"}
    $boundCreation=$boundProcess.StartTime.ToUniversalTime()
    if([Math]::Abs(($boundCreation-$observed).TotalMilliseconds)-gt1){throw "process identity changed before handle acquisition pid=$ProcessId"}
    $boundExe=[IO.Path]::GetFullPath([string]$boundProcess.MainModule.FileName)
    if($boundExe-ine[IO.Path]::GetFullPath($ExpectedExe)){throw "bound process executable changed pid=$ProcessId"}
    [pscustomobject]@{Identity=$proc;Process=$boundProcess;ProcessId=$ProcessId;CreationUtc=$boundCreation;ExecutablePath=$boundExe}
  }catch{
    if($null-ne$boundProcess){try{$boundProcess.Dispose()}catch{}}
    throw
  }
}
function Stop-ExactOwnedProcess(
  [int]$ProcessId,
  [datetime]$CreationUtc,
  [string]$ExpectedExe,
  [string]$ExpectedSha,
  [string[]]$ExpectedArguments,
  [int[]]$PathArgumentIndexes=@(),
  [scriptblock]$ProcessLookup={param([int]$LookupProcessId) @(Get-ProcessInventory|Where-Object{[int]$_.ProcessId-eq$LookupProcessId})},
  [scriptblock]$HashLookup={param([string]$ExecutablePath) Sha $ExecutablePath},
  [scriptblock]$ProcessHandleAcquire={param([int]$ExactProcessId) [Diagnostics.Process]::GetProcessById($ExactProcessId)},
  [scriptblock]$AfterValidationAction={param([Diagnostics.Process]$BoundProcess)},
  [scriptblock]$StopAction={
    param([Diagnostics.Process]$BoundProcess)
    if($BoundProcess.HasExited){throw 'bound process exited before termination; PID replacement was not targeted'}
    $retainedHandle=$BoundProcess.Handle
    $BoundProcess.Kill()
    if($BoundProcess.Handle-ne$retainedHandle){throw 'bound process handle changed during termination'}
    if(-not$BoundProcess.WaitForExit(5000)){throw 'bound process did not exit after termination'}
  }
){
  $owned=$null
  try{
    $owned=Open-ExactOwnedProcess -ProcessId $ProcessId -CreationUtc $CreationUtc -ExpectedExe $ExpectedExe `
      -ExpectedSha $ExpectedSha -ExpectedArguments $ExpectedArguments -PathArgumentIndexes $PathArgumentIndexes `
      -ProcessLookup $ProcessLookup -HashLookup $HashLookup -ProcessHandleAcquire $ProcessHandleAcquire
    & $AfterValidationAction $owned.Process
    & $StopAction $owned.Process
  }finally{
    if($null-ne$owned-and$null-ne$owned.Process){try{$owned.Process.Dispose()}catch{}}
  }
}
function Get-ExactTunnelProcesses(){
  $rows=@(Get-ProcessInventory|Where-Object{[string]$_.Name-ieq'tunnel-client.exe'})
  $out=@()
  foreach($row in $rows){
    $creation=([datetime]$row.CreationDate).ToUniversalTime()
    $owned=Open-ExactOwnedProcess -ProcessId ([int]$row.ProcessId) -CreationUtc $creation -ExpectedExe $TunnelClient `
      -ExpectedSha $ExpectedTunnelSha -ExpectedArguments @('run','--profile-file',$TunnelProfilePath) `
      -PathArgumentIndexes @(2) -ProcessLookup {param([int]$ignored) @($row)}.GetNewClosure()
    $out+=[pscustomobject]@{ProcessId=[int]$row.ProcessId;CreationUtc=$creation;Process=$owned.Process}
  }
  $out
}
function Get-ExactOwnedListenerIdentity(
  [int]$Port,
  [string]$ExpectedScript,
  [string]$ExpectedSourceSha,
  [scriptblock]$ConnectionLookup={param([int]$LookupPort) @(Get-ListenerInventory|Where-Object{[int]$_.LocalPort-eq$LookupPort-and([string]$_.LocalAddress-eq'127.0.0.1'-or[string]$_.LocalAddress-eq'::1')})},
  [scriptblock]$ProcessLookup={param([int]$LookupProcessId) @(Get-ProcessInventory|Where-Object{[int]$_.ProcessId-eq$LookupProcessId})},
  [scriptblock]$HashLookup={param([string]$ExecutablePath) Sha $ExecutablePath},
  [scriptblock]$SourceIdentityLookup={param([int]$LookupPort) Invoke-RestMethod -Uri ("http://127.0.0.1:$LookupPort/__ea_lab_loaded_source_identity_v1") -TimeoutSec 3}
){
  if([string]::IsNullOrWhiteSpace($ExpectedSourceSha)){throw 'expected source SHA256 required'}
  $connections=@(& $ConnectionLookup $Port)
  if($connections.Count-eq0){return $null}
  if($connections.Count-ne1){throw "ambiguous listener ownership port=$Port count=$($connections.Count)"}
  $ownerProcessId=[int]$connections[0].OwningProcess
  if($ownerProcessId-le0){throw "invalid listener owner pid port=$Port"}
  $proc=Get-ExactProcessIdentity -ProcessId $ownerProcessId -ExpectedExe $Node `
    -ExpectedSha $ExpectedNodeSha -ExpectedArguments @($GatewayLoader,$ExpectedScript,$ExpectedSourceSha) -PathArgumentIndexes @(0,1) `
    -ProcessLookup $ProcessLookup -HashLookup $HashLookup
  $loaded=& $SourceIdentityLookup $Port
  if($null-eq$loaded-or[string]$loaded.schema-cne'ea_lab_loaded_source_identity_v1'){throw "loaded source identity unavailable port=$Port"}
  if([IO.Path]::GetFullPath([string]$loaded.source_path)-ine[IO.Path]::GetFullPath($ExpectedScript)){throw "loaded source path mismatch port=$Port"}
  if([string]$loaded.source_sha256-cne$ExpectedSourceSha.ToLowerInvariant()){throw "loaded source SHA256 mismatch port=$Port"}
  if(-not($loaded.source_bytes-is[int])-and-not($loaded.source_bytes-is[long])){throw "loaded source byte count unavailable port=$Port"}
  if([long]$loaded.source_bytes-le0){throw "loaded source byte count invalid port=$Port"}
  [pscustomobject]@{
    Port=$Port
    ProcessId=$ownerProcessId
    CreationUtc=([datetime]$proc.CreationDate).ToUniversalTime()
    ExecutablePath=[IO.Path]::GetFullPath([string]$proc.ExecutablePath)
    ExecutableSha256=$ExpectedNodeSha.ToLowerInvariant()
    CommandLine=[string]$proc.CommandLine
    ScriptPath=[IO.Path]::GetFullPath($ExpectedScript)
    LoadedSourcePath=[IO.Path]::GetFullPath([string]$loaded.source_path)
    LoadedSourceSha256=[string]$loaded.source_sha256
    LoadedSourceBytes=[long]$loaded.source_bytes
  }
}
function Assert-SameListenerIdentity($Before,$After){
  if($null-eq$Before-or$null-eq$After){throw 'listener identity changed: listener absent'}
  if([int]$Before.Port-ne[int]$After.Port-or[int]$Before.ProcessId-ne[int]$After.ProcessId){throw "listener identity changed port=$($Before.Port): PID"}
  if(([datetime]$Before.CreationUtc).ToUniversalTime()-ne([datetime]$After.CreationUtc).ToUniversalTime()){throw "listener identity changed port=$($Before.Port): creation time"}
  if([IO.Path]::GetFullPath([string]$Before.ExecutablePath)-ine[IO.Path]::GetFullPath([string]$After.ExecutablePath)){throw "listener identity changed port=$($Before.Port): executable path"}
  if([string]$Before.ExecutableSha256-cne[string]$After.ExecutableSha256){throw "listener identity changed port=$($Before.Port): executable SHA256"}
  if([string]$Before.CommandLine-cne[string]$After.CommandLine-or[IO.Path]::GetFullPath([string]$Before.ScriptPath)-ine[IO.Path]::GetFullPath([string]$After.ScriptPath)){throw "listener identity changed port=$($Before.Port): command"}
  if([IO.Path]::GetFullPath([string]$Before.LoadedSourcePath)-ine[IO.Path]::GetFullPath([string]$After.LoadedSourcePath)-or
    [string]$Before.LoadedSourceSha256-cne[string]$After.LoadedSourceSha256-or
    [long]$Before.LoadedSourceBytes-ne[long]$After.LoadedSourceBytes){throw "listener identity changed port=$($Before.Port): loaded source bytes"}
}
function Stop-KnownListener([int]$Port,[string]$ExpectedScript,[string]$ExpectedSourceSha){
  $listener=Get-ExactOwnedListenerIdentity $Port $ExpectedScript $ExpectedSourceSha
  if($null-eq$listener){return}
  Stop-ExactOwnedProcess -ProcessId $listener.ProcessId -CreationUtc $listener.CreationUtc `
    -ExpectedExe $Node -ExpectedSha $ExpectedNodeSha -ExpectedArguments @($GatewayLoader,$ExpectedScript,$ExpectedSourceSha) `
    -PathArgumentIndexes @(0,1)
  if(-not(Wait-PortFree $Port 10)){throw "known listener did not release port $Port"}
}
function Route-IsReady(
  [string]$HealthBaseOverride='',
  [scriptblock]$ListenerLookup={
    param([int]$LookupPort,[string]$ExpectedScript,[string]$ExpectedSourceSha)
    Get-ExactOwnedListenerIdentity $LookupPort $ExpectedScript $ExpectedSourceSha
  },
  [scriptblock]$StatusLookup={param([string]$BaseUrl) Invoke-RestMethod -Uri ($BaseUrl+'/api/status') -TimeoutSec 3},
  [scriptblock]$HealthLookup={param([string]$Url) Wait-Ready $Url 2}
){
  if([string]::IsNullOrWhiteSpace($HealthBaseOverride)){
    if(-not(Test-Path -LiteralPath $HealthFile -PathType Leaf)){return $false}
    $base=(Get-Content -LiteralPath $HealthFile -Raw -Encoding UTF8).Trim()
  }else{$base=$HealthBaseOverride}
  $writeBefore=& $ListenerLookup 18768 $WriteBundle $ExpectedWriteSha
  if($null-ne$writeBefore-and[string]$writeBefore.LoadedSourceSha256-cne$ExpectedWriteSha){throw 'loaded source SHA256 mismatch port=18768'}
  $v2Before=& $ListenerLookup 18767 $V2Bundle $ExpectedV2Sha
  if($null-ne$v2Before-and[string]$v2Before.LoadedSourceSha256-cne$ExpectedV2Sha){throw 'loaded source SHA256 mismatch port=18767'}
  if($null-eq$writeBefore-or$null-eq$v2Before){return $false}
  try{
    $s=& $StatusLookup $base
    $main=@($s.mcp_routes|Where-Object{$_.name-eq'main'-and$_.target-eq'127.0.0.1:18768'})
    $frozen=@($s.mcp_routes|Where-Object{$_.name-eq'frozen_v1'-and$_.target-eq'127.0.0.1:18767'})
    $healthy=($main.Count-eq1-and$frozen.Count-eq1-and(& $HealthLookup 'http://127.0.0.1:18768/healthz')-and(& $HealthLookup 'http://127.0.0.1:18767/healthz'))
  }catch{return $false}
  if(-not$healthy){return $false}
  $writeAfter=& $ListenerLookup 18768 $WriteBundle $ExpectedWriteSha
  if($null-ne$writeAfter-and[string]$writeAfter.LoadedSourceSha256-cne$ExpectedWriteSha){throw 'loaded source SHA256 mismatch port=18768'}
  $v2After=& $ListenerLookup 18767 $V2Bundle $ExpectedV2Sha
  if($null-ne$v2After-and[string]$v2After.LoadedSourceSha256-cne$ExpectedV2Sha){throw 'loaded source SHA256 mismatch port=18767'}
  Assert-SameListenerIdentity $writeBefore $writeAfter
  Assert-SameListenerIdentity $v2Before $v2After
  $true
}
function Resolve-WriteV1StartupState(
  [object[]]$ExistingTunnelProcesses,
  [scriptblock]$RouteReadyAction={Route-IsReady}
){
  if($ExistingTunnelProcesses.Count-gt1){throw "multiple exact owned tunnel-client processes: $($ExistingTunnelProcesses.Count)"}
  if($ExistingTunnelProcesses.Count-eq0){return [pscustomobject]@{Action='START_FRESH';LaunchAllowed=$true}}
  if(& $RouteReadyAction){return [pscustomobject]@{Action='ADOPT_EXISTING';LaunchAllowed=$false}}
  [pscustomobject]@{Action='RESTART_OWNED';LaunchAllowed=$false}
}
function Assert-SecretAcl([string]$Path){
  $owner=[Security.Principal.WindowsIdentity]::GetCurrent().User
  $system=New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::LocalSystemSid,$null)
  foreach($rule in (Get-Acl -LiteralPath $Path).Access){
    $sid=$rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier])
    if(-not($sid.Equals($owner)-or$sid.Equals($system))){throw "secret ACL includes unexpected identity: $($rule.IdentityReference)"}
    if($rule.AccessControlType-ne[Security.AccessControl.AccessControlType]::Allow){throw 'secret ACL contains non-Allow rule'}
  }
}
if($LibraryOnly){return}
foreach($pair in @(@($Node,$ExpectedNodeSha),@($TunnelClient,$ExpectedTunnelSha),@($GatewayLoader,$ExpectedGatewayLoaderSha),@($V2Bundle,$ExpectedV2Sha),@($WriteBundle,$ExpectedWriteSha))){
  if((Sha $pair[0])-ne$pair[1]){throw "hash mismatch: $($pair[0])"}
}
if(-not(Test-Path -LiteralPath $WriteSeal -PathType Leaf)){throw 'write snapshot seal missing'}
$seal=Get-Content -LiteralPath $WriteSeal -Raw -Encoding UTF8|ConvertFrom-Json
if([string]$seal.snapshot_id-notmatch'^[0-9a-f]{32}$'-or[string]$seal.canonical_head-notmatch'^[0-9a-f]{40}$'){throw 'write snapshot seal identity malformed'}
if(-not(Test-Path -LiteralPath $Vault -PathType Leaf)){throw 'DPAPI vault missing'}
if($CheckOnly){
  [pscustomobject]@{result='CHECK_PASS';gateway_sha256=Sha $WriteBundle;snapshot_id=$seal.snapshot_id;canonical_head=$seal.canonical_head;route_ready=Route-IsReady}|ConvertTo-Json -Compress
  exit 0
}

[void](Invoke-WithDiscoveryPreflight -Action {$true})

$existing=@(Get-ExactTunnelProcesses)
$startupState=Resolve-WriteV1StartupState -ExistingTunnelProcesses $existing
if($startupState.Action-eq'ADOPT_EXISTING'){
  Write-Output ('WRITE_V1_ALREADY_READY tunnel_pid='+$existing[0].ProcessId)
  try{
    while(-not$existing[0].Process.HasExited){
      if(-not(Route-IsReady)){
        Stop-ExactOwnedProcess -ProcessId $existing[0].ProcessId -CreationUtc $existing[0].CreationUtc `
          -ExpectedExe $TunnelClient -ExpectedSha $ExpectedTunnelSha `
          -ExpectedArguments @('run','--profile-file',$TunnelProfilePath) -PathArgumentIndexes @(2)
        break
      }
      Start-Sleep -Seconds 30
    }
  }finally{$existing[0].Process.Dispose()}
}
$existing=@(Get-ExactTunnelProcesses)
if($existing.Count-gt1){throw "multiple exact owned tunnel-client processes after adoption: $($existing.Count)"}
if($existing.Count-eq1){
  Stop-ExactOwnedProcess -ProcessId $existing[0].ProcessId -CreationUtc $existing[0].CreationUtc `
    -ExpectedExe $TunnelClient -ExpectedSha $ExpectedTunnelSha `
    -ExpectedArguments @('run','--profile-file',$TunnelProfilePath) -PathArgumentIndexes @(2)
  $existing[0].Process.WaitForExit(5000)|Out-Null
  $existing[0].Process.Dispose()
}
Start-Sleep -Milliseconds 750
Stop-KnownListener 18768 $WriteBundle $ExpectedWriteSha
Stop-KnownListener 18767 $V2Bundle $ExpectedV2Sha
if(Test-Path -LiteralPath $SecretPath){Remove-Item -LiteralPath $SecretPath -Force}

$enc=[IO.File]::ReadAllBytes($Vault)
$plain=[Security.Cryptography.ProtectedData]::Unprotect($enc,$VaultEntropy,[Security.Cryptography.DataProtectionScope]::CurrentUser)
try{$vaultObj=([Text.Encoding]::UTF8.GetString($plain)|ConvertFrom-Json);$tunnelId=[string]$vaultObj.tunnel_id;$runtimeKey=[string]$vaultObj.runtime_api_key}
finally{[Array]::Clear($plain,0,$plain.Length);[Array]::Clear($enc,0,$enc.Length)}
if($tunnelId-notmatch'^tunnel_[a-z0-9]{32}$'-or[string]::IsNullOrWhiteSpace($runtimeKey)){throw 'vault contents invalid'}

$profileText=@"
config_version: 1
control_plane:
  base_url: "https://api.openai.com"
  tunnel_id: "$tunnelId"
  api_key: "file:$($SecretPath.Replace('\','\\'))"
health:
  listen_addr: "127.0.0.1:0"
  url_file: "$($HealthFile.Replace('\','\\'))"
admin_ui:
  open_browser: false
log:
  level: info
  format: json
mcp:
  server_urls:
    - channel: main
      url: "http://127.0.0.1:18768/mcp"
    - channel: frozen_v1
      url: "http://127.0.0.1:18767/mcp"
  startup_wait_timeout: "15s"
  connection_max_ttl: "10m"
  max_concurrent_requests: 10
"@
[IO.File]::WriteAllText($TunnelProfilePath,$profileText,$Utf8NoBom)
if(Test-Path $HealthFile){Remove-Item -LiteralPath $HealthFile -Force}
$v2=$null;$write=$null;$tunnel=$null
try{
  $v2=New-MinimalProcess $Node @($GatewayLoader,$V2Bundle,$ExpectedV2Sha)
  if(-not(Wait-Ready 'http://127.0.0.1:18767/healthz' 20)){throw 'V2 fallback gateway failed readiness'}
  $v2Identity=Get-ExactOwnedListenerIdentity 18767 $V2Bundle $ExpectedV2Sha
  if($null-eq$v2Identity){throw 'V2 fallback gateway listener identity unavailable'}
  $write=New-MinimalProcess $Node @($GatewayLoader,$WriteBundle,$ExpectedWriteSha)
  if(-not(Wait-Ready 'http://127.0.0.1:18768/healthz' 20)){throw 'Write V1 gateway failed readiness'}
  $writeIdentity=Get-ExactOwnedListenerIdentity 18768 $WriteBundle $ExpectedWriteSha
  if($null-eq$writeIdentity){throw 'Write V1 gateway listener identity unavailable'}
  [IO.File]::WriteAllText($SecretPath,$runtimeKey,$Utf8NoBom);$runtimeKey=$null;Assert-SecretAcl $SecretPath
  $doctor=Start-Process -FilePath $TunnelClient -ArgumentList @('doctor','--profile-file',$TunnelProfilePath,'--explain') -NoNewWindow -Wait -PassThru
  if($doctor.ExitCode-ne0){throw "profile doctor failed rc=$($doctor.ExitCode)"}
  $tunnel=New-MinimalProcess $TunnelClient @('run','--profile-file',$TunnelProfilePath)
  $deadline=[DateTime]::UtcNow.AddSeconds(60)
  while([DateTime]::UtcNow-lt$deadline-and-not(Route-IsReady)){
    if($tunnel.HasExited){throw "tunnel-client exited during start rc=$($tunnel.ExitCode)"}
    Start-Sleep -Milliseconds 300
  }
  if(-not(Route-IsReady)){throw 'tunnel route did not reach ready state'}
  Remove-Item -LiteralPath $SecretPath -Force
  if(Test-Path $SecretPath){throw 'runtime secret deletion failed'}
  New-Item -ItemType Directory -Force -Path $Evidence|Out-Null
  $obj=[ordered]@{result='RUNNING';started_at=[DateTimeOffset]::Now.ToString('o');tunnel_pid=$tunnel.Id;v2_gateway_pid=$v2.Id;write_gateway_pid=$write.Id;snapshot_id=$seal.snapshot_id;canonical_head=$seal.canonical_head;write_gateway_sha256=Sha $WriteBundle;runtime_secret_absent=$true}
  [IO.File]::WriteAllText($Receipt,($obj|ConvertTo-Json -Depth 6),$Utf8NoBom)
  Write-Output ('WRITE_V1_SUPERVISOR_READY tunnel_pid='+$tunnel.Id)
  while(-not$tunnel.HasExited){
    if($v2.HasExited){throw "V2 gateway exited rc=$($v2.ExitCode)"}
    if($write.HasExited){throw "Write gateway exited rc=$($write.ExitCode)"}
    if(-not(Route-IsReady)){throw 'route or gateway health failed'}
    Start-Sleep -Seconds 30
  }
  throw "tunnel-client exited rc=$($tunnel.ExitCode)"
}finally{
  $runtimeKey=$null
  try{if(Test-Path $SecretPath){Remove-Item -LiteralPath $SecretPath -Force}}catch{}
  Stop-Child $tunnel;Stop-Child $write;Stop-Child $v2
}
