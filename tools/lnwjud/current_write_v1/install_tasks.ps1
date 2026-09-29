[CmdletBinding()]
param([switch]$LibraryOnly)

$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$Root='D:\EA_LAB_CONTROL\lnwjud-write-v1-20260928'
$Start=Join-Path $Root 'start_write_v1.ps1'
$Refresh=Join-Path $Root 'refresh_write_v1_snapshot.ps1'
$StartTask='EA_LAB_LNWJUD_WriteV1'
$RefreshTask='EA_LAB_LNWJUD_WriteV1_Refresh'
$TaskIdentityPrefix='EA_LAB_LNWJUD_WRITE_V1_TASK_V1'

function Get-TextSha256([string]$Text){
  $bytes=[Text.UTF8Encoding]::new($false).GetBytes($Text)
  try{
    $sha=[Security.Cryptography.SHA256]::Create()
    try{([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()}
    finally{$sha.Dispose()}
  }finally{[Array]::Clear($bytes,0,$bytes.Length)}
}

function Get-TaskDefinitionIdentity(
  [string]$Name,
  [scriptblock]$TaskInventoryAction={@(Get-ScheduledTask -ErrorAction Stop)},
  [scriptblock]$ExportTaskAction={param([string]$TaskName) Export-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop}
){
  $taskMatches=@(& $TaskInventoryAction|Where-Object{$_.TaskPath-eq'\'-and$_.TaskName-ieq$Name})
  if($taskMatches.Count-eq0){return $null}
  if($taskMatches.Count-ne1){throw "ambiguous Scheduled Task readback name=$Name count=$($taskMatches.Count)"}
  $xmlText=[string](& $ExportTaskAction $Name)
  if([string]::IsNullOrWhiteSpace($xmlText)){throw "Scheduled Task definition unavailable name=$Name"}
  try{[xml]$xml=$xmlText}catch{throw "Scheduled Task definition XML invalid name=$Name`: $($_.Exception.Message)"}
  $ns=[Xml.XmlNamespaceManager]::new($xml.NameTable)
  $ns.AddNamespace('t','http://schemas.microsoft.com/windows/2004/02/mit/task')
  $execNodes=@($xml.SelectNodes('/t:Task/t:Actions/t:Exec',$ns))
  $triggerNodes=@($xml.SelectNodes('/t:Task/t:Triggers/*',$ns))
  $principalNodes=@($xml.SelectNodes('/t:Task/t:Principals/t:Principal',$ns))
  if($execNodes.Count-ne1-or$triggerNodes.Count-ne1-or$principalNodes.Count-ne1){throw "Scheduled Task definition cardinality invalid name=$Name"}
  $exec=$execNodes[0];$trigger=$triggerNodes[0];$principal=$principalNodes[0]
  $descriptionNode=$xml.SelectSingleNode('/t:Task/t:RegistrationInfo/t:Description',$ns)
  $commandNode=$exec.SelectSingleNode('t:Command',$ns)
  $argumentsNode=$exec.SelectSingleNode('t:Arguments',$ns)
  $workingNode=$exec.SelectSingleNode('t:WorkingDirectory',$ns)
  $intervalNode=$trigger.SelectSingleNode('t:Repetition/t:Interval',$ns)
  $triggerUserNode=$trigger.SelectSingleNode('t:UserId',$ns)
  $principalUserNode=$principal.SelectSingleNode('t:UserId',$ns)
  $logonNode=$principal.SelectSingleNode('t:LogonType',$ns)
  $runLevelNode=$principal.SelectSingleNode('t:RunLevel',$ns)
  $description=if($null-eq$descriptionNode){''}else{[string]$descriptionNode.InnerText}
  $invocation=''
  $taskIdentityMatch=[regex]::Match($description,'^EA_LAB_LNWJUD_WRITE_V1_TASK_V1\|invocation=([0-9a-f-]{36})\|role=(START|REFRESH)$')
  if($taskIdentityMatch.Success){$invocation=$taskIdentityMatch.Groups[1].Value}
  [pscustomobject]@{
    Name=$Name;InvocationId=$invocation;Description=$description
    ActionCommand=if($null-eq$commandNode){''}else{[string]$commandNode.InnerText}
    ActionArguments=if($null-eq$argumentsNode){''}else{[string]$argumentsNode.InnerText}
    WorkingDirectory=if($null-eq$workingNode){''}else{[string]$workingNode.InnerText}
    TriggerKind=[string]$trigger.LocalName
    TriggerUserId=if($null-eq$triggerUserNode){''}else{[string]$triggerUserNode.InnerText}
    RepetitionInterval=if($null-eq$intervalNode){''}else{[string]$intervalNode.InnerText}
    PrincipalUserId=if($null-eq$principalUserNode){''}else{[string]$principalUserNode.InnerText}
    PrincipalLogonType=if($null-eq$logonNode){''}else{[string]$logonNode.InnerText}
    PrincipalRunLevel=if($null-eq$runLevelNode){''}else{[string]$runLevelNode.InnerText}
    DefinitionSha256=Get-TextSha256 $xmlText
  }
}

function New-WriteV1TaskSpec(
  [string]$Name,[string]$Role,[string]$ActionArguments,[string]$TriggerKind,
  [string]$RepetitionInterval,[string]$InvocationId,[string]$PrincipalUserId
){
  [pscustomobject]@{
    Name=$Name;Role=$Role;InvocationId=$InvocationId
    Description="$TaskIdentityPrefix|invocation=$InvocationId|role=$Role"
    ActionCommand='powershell.exe';ActionArguments=$ActionArguments;WorkingDirectory=''
    TriggerKind=$TriggerKind;TriggerUserId=if($TriggerKind-eq'LogonTrigger'){$PrincipalUserId}else{''}
    RepetitionInterval=$RepetitionInterval;PrincipalUserId=$PrincipalUserId
    PrincipalLogonType='InteractiveToken';PrincipalRunLevel='LeastPrivilege'
  }
}

function Assert-TaskMatchesSpec($Identity,$Spec){
  if($null-eq$Identity){throw "Scheduled Task readback missing name=$($Spec.Name)"}
  foreach($field in @('Name','InvocationId','Description','ActionCommand','ActionArguments','WorkingDirectory','TriggerKind','TriggerUserId','RepetitionInterval','PrincipalUserId','PrincipalLogonType','PrincipalRunLevel')){
    if([string]$Identity.$field-cne[string]$Spec.$field){throw "Scheduled Task identity mismatch name=$($Spec.Name) field=$field"}
  }
  if([string]$Identity.DefinitionSha256-notmatch'^[0-9a-f]{64}$'){throw "Scheduled Task definition hash invalid name=$($Spec.Name)"}
}

function Assert-SameTaskIdentity($Expected,$Actual){
  if($null-eq$Actual){throw "task ownership changed before rollback name=$($Expected.Name): task absent"}
  foreach($field in @('Name','InvocationId','Description','ActionCommand','ActionArguments','WorkingDirectory','TriggerKind','TriggerUserId','RepetitionInterval','PrincipalUserId','PrincipalLogonType','PrincipalRunLevel','DefinitionSha256')){
    if([string]$Expected.$field-cne[string]$Actual.$field){throw "task ownership changed before rollback name=$($Expected.Name) field=$field"}
  }
}

function New-WriteV1Task($Spec){
  $action=New-ScheduledTaskAction -Execute $Spec.ActionCommand -Argument $Spec.ActionArguments
  if($Spec.TriggerKind-eq'LogonTrigger'){$trigger=New-ScheduledTaskTrigger -AtLogOn -User $Spec.PrincipalUserId}
  elseif($Spec.TriggerKind-eq'TimeTrigger'){$trigger=New-ScheduledTaskTrigger -Once -At ([DateTime]::Now.AddMinutes(1)) -RepetitionInterval ([TimeSpan]::FromMinutes(10))}
  else{throw "unsupported task trigger kind: $($Spec.TriggerKind)"}
  $principal=New-ScheduledTaskPrincipal -UserId $Spec.PrincipalUserId -LogonType Interactive -RunLevel Limited
  Register-ScheduledTask -TaskName $Spec.Name -TaskPath '\' -Action $action -Trigger $trigger `
    -Principal $principal -Description $Spec.Description -ErrorAction Stop|Out-Null
}

function Remove-CreatedTask(
  $OwnedIdentity,
  [scriptblock]$TaskQueryAction={param([string]$TaskName) Get-TaskDefinitionIdentity $TaskName},
  [scriptblock]$DeleteTaskAction={param([string]$TaskName) Unregister-ScheduledTask -TaskName $TaskName -TaskPath '\' -Confirm:$false -ErrorAction Stop}
){
  $before=& $TaskQueryAction $OwnedIdentity.Name
  Assert-SameTaskIdentity $OwnedIdentity $before
  & $DeleteTaskAction $OwnedIdentity.Name
  $after=& $TaskQueryAction $OwnedIdentity.Name
  if($null-ne$after){throw "rollback absence verification failed name=$($OwnedIdentity.Name)"}
}

function Invoke-WriteV1TaskInstall(
  [scriptblock]$TaskQueryAction={param([string]$TaskName) Get-TaskDefinitionIdentity $TaskName},
  [scriptblock]$CreateTaskAction={param($Spec) New-WriteV1Task $Spec},
  [scriptblock]$DeleteTaskAction={param([string]$TaskName) Unregister-ScheduledTask -TaskName $TaskName -TaskPath '\' -Confirm:$false -ErrorAction Stop},
  [string]$InvocationId=([Guid]::NewGuid().ToString('D')),
  [string]$PrincipalUserId=([Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
){
  if($InvocationId-notmatch'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'){throw 'task invocation UUID malformed'}
  $startArgs='-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$Start+'"'
  $refreshArgs='-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$Refresh+'"'
  $specs=@(
    New-WriteV1TaskSpec $StartTask 'START' $startArgs 'LogonTrigger' '' $InvocationId $PrincipalUserId
    New-WriteV1TaskSpec $RefreshTask 'REFRESH' $refreshArgs 'TimeTrigger' 'PT10M' $InvocationId $PrincipalUserId
  )
  foreach($spec in $specs){if($null-ne(& $TaskQueryAction $spec.Name)){throw 'existing WriteV1 Scheduled Task requires explicit ownership reconciliation; installer will not overwrite or adopt it'}}
  $owned=@{}
  $attempted=[System.Collections.Generic.List[object]]::new()
  try{
    foreach($spec in $specs){
      $attempted.Add($spec)
      & $CreateTaskAction $spec
      $identity=& $TaskQueryAction $spec.Name
      Assert-TaskMatchesSpec $identity $spec
      $owned[$spec.Name]=$identity
    }
    foreach($spec in $specs){Assert-SameTaskIdentity $owned[$spec.Name] (& $TaskQueryAction $spec.Name)}
  }catch{
    $originalError=[string]$_.Exception.Message
    $rollbackErrors=[System.Collections.Generic.List[string]]::new()
    foreach($spec in $attempted){
      if($owned.ContainsKey($spec.Name)){continue}
      try{
        $current=& $TaskQueryAction $spec.Name
        if($null-ne$current){Assert-TaskMatchesSpec $current $spec;$owned[$spec.Name]=$current}
      }catch{$rollbackErrors.Add("rollback ownership reconciliation failed name=$($spec.Name)`: $($_.Exception.Message)")}
    }
    for($i=$attempted.Count-1;$i-ge0;$i--){
      $spec=$attempted[$i]
      if(-not$owned.ContainsKey($spec.Name)){continue}
      try{Remove-CreatedTask -OwnedIdentity $owned[$spec.Name] -TaskQueryAction $TaskQueryAction -DeleteTaskAction $DeleteTaskAction}
      catch{$rollbackErrors.Add([string]$_.Exception.Message)}
    }
    $remaining=[System.Collections.Generic.List[string]]::new()
    foreach($spec in $specs){
      try{if($null-ne(& $TaskQueryAction $spec.Name)){$remaining.Add($spec.Name)}}
      catch{$rollbackErrors.Add("rollback final readback failed name=$($spec.Name)`: $($_.Exception.Message)")}
    }
    if($remaining.Count-gt0){$rollbackErrors.Add("partial activation remains: $($remaining -join ', ')")}
    if($rollbackErrors.Count-gt0){throw "task installation failed: $originalError; rollback failed: $($rollbackErrors -join '; ')"}
    throw $originalError
  }
  [pscustomobject]@{
    result='PASS';invocation_id=$InvocationId;start_task=$StartTask;refresh_task=$RefreshTask
    start_definition_sha256=$owned[$StartTask].DefinitionSha256
    refresh_definition_sha256=$owned[$RefreshTask].DefinitionSha256;rollback='NOT_REQUIRED'
  }
}

if($LibraryOnly){return}
foreach($runtimeScript in @($Start,$Refresh)){if(-not(Test-Path -LiteralPath $runtimeScript -PathType Leaf)){throw "missing runtime script: $runtimeScript"}}
Invoke-WriteV1TaskInstall
