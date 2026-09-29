[CmdletBinding()]
param([switch]$LibraryOnly)

$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$Root='D:\EA_LAB_CONTROL\lnwjud-write-v1-20260928'
$Start=Join-Path $Root 'start_write_v1.ps1'
$Refresh=Join-Path $Root 'refresh_write_v1_snapshot.ps1'
$StartTask='EA_LAB_LNWJUD_WriteV1'
$RefreshTask='EA_LAB_LNWJUD_WriteV1_Refresh'

function Test-TaskExists([string]$Name){
  $matches=@(Get-ScheduledTask -ErrorAction Stop|Where-Object{$_.TaskPath-eq'\'-and$_.TaskName-ieq$Name})
  if($matches.Count-gt1){throw "ambiguous Scheduled Task readback name=$Name count=$($matches.Count)"}
  $matches.Count-eq1
}
function New-WriteV1Task([string]$Name,[string]$Action,[string]$Schedule,[int]$Modifier){
  $arguments=@('/Create','/TN',$Name,'/TR',$Action,'/SC',$Schedule,'/RL','LIMITED')
  if($Modifier-gt0){$arguments+=@('/MO',[string]$Modifier)}
  & schtasks.exe @arguments
  if($LASTEXITCODE-ne0){throw "failed to register Scheduled Task name=$Name rc=$LASTEXITCODE"}
}
function Remove-CreatedTask(
  [string]$Name,
  [scriptblock]$TaskExistsAction={param([string]$TaskName) Test-TaskExists $TaskName},
  [scriptblock]$DeleteTaskAction={
    param([string]$TaskName)
    & schtasks.exe /Delete /TN $TaskName /F 1>$null 2>$null
    if($LASTEXITCODE-ne0){throw "rollback delete failed name=$TaskName rc=$LASTEXITCODE"}
  }
){
  & $DeleteTaskAction $Name
  if(& $TaskExistsAction $Name){throw "rollback absence verification failed name=$Name"}
}
function Invoke-WriteV1TaskInstall(
  [scriptblock]$TaskExistsAction={param([string]$TaskName) Test-TaskExists $TaskName},
  [scriptblock]$CreateTaskAction={param([string]$TaskName,[string]$Action,[string]$Schedule,[int]$Modifier) New-WriteV1Task $TaskName $Action $Schedule $Modifier},
  [scriptblock]$DeleteTaskAction={
    param([string]$TaskName)
    & schtasks.exe /Delete /TN $TaskName /F 1>$null 2>$null
    if($LASTEXITCODE-ne0){throw "rollback delete failed name=$TaskName rc=$LASTEXITCODE"}
  }
){
  if((& $TaskExistsAction $StartTask)-or(& $TaskExistsAction $RefreshTask)){
    throw 'existing WriteV1 Scheduled Task requires explicit ownership reconciliation; installer will not overwrite or adopt it'
  }
  $startAction='powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$Start+'"'
  $refreshAction='powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$Refresh+'"'
  $createdStart=$false
  $createdRefresh=$false
  try{
    & $CreateTaskAction $StartTask $startAction 'ONLOGON' 0
    $createdStart=$true
    & $CreateTaskAction $RefreshTask $refreshAction 'MINUTE' 10
    $createdRefresh=$true
    if(-not(& $TaskExistsAction $StartTask)){throw 'supervisor task readback failed'}
    if(-not(& $TaskExistsAction $RefreshTask)){throw 'refresh task readback failed'}
  }catch{
    $originalError=[string]$_.Exception.Message
    $rollbackErrors=[System.Collections.Generic.List[string]]::new()
    if($createdRefresh){
      try{Remove-CreatedTask -Name $RefreshTask -TaskExistsAction $TaskExistsAction -DeleteTaskAction $DeleteTaskAction}
      catch{$rollbackErrors.Add([string]$_.Exception.Message)}
    }
    if($createdStart){
      try{Remove-CreatedTask -Name $StartTask -TaskExistsAction $TaskExistsAction -DeleteTaskAction $DeleteTaskAction}
      catch{$rollbackErrors.Add([string]$_.Exception.Message)}
    }
    $remainingTasks=[System.Collections.Generic.List[string]]::new()
    foreach($taskName in @($StartTask,$RefreshTask)){
      try{if(& $TaskExistsAction $taskName){$remainingTasks.Add($taskName)}}
      catch{$rollbackErrors.Add("rollback final absence readback failed name=$taskName`: $($_.Exception.Message)")}
    }
    if($remainingTasks.Count-gt0){$rollbackErrors.Add("partial activation remains: $($remainingTasks -join ', ')")}
    if($rollbackErrors.Count-gt0){
      throw "task installation failed: $originalError; rollback failed: $($rollbackErrors -join '; ')"
    }
    throw
  }
  [pscustomobject]@{
    result='PASS'
    start_task=$StartTask
    refresh_task=$RefreshTask
    rollback='NOT_REQUIRED'
  }
}

if($LibraryOnly){return}
foreach($runtimeScript in @($Start,$Refresh)){
  if(-not(Test-Path -LiteralPath $runtimeScript -PathType Leaf)){throw "missing runtime script: $runtimeScript"}
}
Invoke-WriteV1TaskInstall
