Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert-TraycerPilotSafePath {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Path)
    $full=[IO.Path]::GetFullPath($Path).TrimEnd('\')
    $protected=[IO.Path]::GetFullPath('D:\EA_LAB').TrimEnd('\')
    if($full.Equals($protected,[StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($protected+'\',[StringComparison]::OrdinalIgnoreCase)){
        throw "Protected dirty primary checkout is forbidden: $full"
    }
    return $full
}
function Get-TraycerInstallation {
    [CmdletBinding()] param()
    $exe=Join-Path $env:LOCALAPPDATA 'Programs\traycer\Traycer.exe'
    $cli=Join-Path $env:LOCALAPPDATA 'Programs\traycer\resources\cli\win32-x64\traycer.exe'
    if(-not (Test-Path -LiteralPath $exe)){
        return [pscustomobject]@{found=$false;path=$exe;cli_path=$cli;version=$null;signature_status=$null;signer_subject=$null}
    }
    $item=Get-Item -LiteralPath $exe
    $sig=Get-AuthenticodeSignature -FilePath $exe
    [pscustomobject]@{found=$true;path=$exe;cli_path=$cli;version=$item.VersionInfo.FileVersion;signature_status=[string]$sig.Status;signer_subject=$(if($sig.SignerCertificate){$sig.SignerCertificate.Subject}else{''})}
}
function Get-TraycerPilotPreflight {
    [CmdletBinding()] param()
    $tools=[ordered]@{}
    foreach($name in @('git','claude','codex','qwen','gemini')){
        $cmd=Get-Command $name -ErrorAction SilentlyContinue
        $tools[$name]=[pscustomobject]@{found=($null -ne $cmd);path=$(if($cmd){$cmd.Source}else{$null})}
    }
    [pscustomobject]@{timestamp=(Get-Date).ToString('o');tools=[pscustomobject]$tools;traycer=(Get-TraycerInstallation)}
}function Get-TraycerPilotRepoIdentity {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Path)
    $safe=Assert-TraycerPilotSafePath $Path
    $inside=(& git -C $safe rev-parse --is-inside-work-tree 2>$null)
    if($LASTEXITCODE -ne 0 -or $inside.Trim() -ne 'true'){ throw "Not a Git worktree: $safe" }
    $head=(& git -C $safe rev-parse HEAD).Trim()
    $branch=(& git -C $safe branch --show-current).Trim()
    $dirty=@(& git -C $safe status --porcelain)
    [pscustomobject]@{path=$safe;head=$head;branch=$branch;clean=($dirty.Count -eq 0);dirty=@($dirty)}
}
function New-TraycerPilotCage {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Name)
    $safeRoot=Assert-TraycerPilotSafePath $Root
    $path=Assert-TraycerPilotSafePath (Join-Path $safeRoot $Name)
    if(Test-Path -LiteralPath $path){ throw "Cage already exists: $path" }
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    & git -C $path init -q
    if($LASTEXITCODE -ne 0){ throw 'git init failed' }
    & git -C $path config core.autocrlf false
    & git -C $path config user.name 'EA_LAB Traycer Pilot'
    & git -C $path config user.email 'traycer-pilot@local.invalid'
    Set-Content -LiteralPath (Join-Path $path 'README.md') -Encoding UTF8 -Value "# Disposable Traycer Pilot Cage`n`nNo EA_LAB canonical authority."
    & git -C $path add README.md
    if($LASTEXITCODE -ne 0){ throw 'git add failed' }
    & git -C $path commit -q -m 'init disposable traycer cage'
    if($LASTEXITCODE -ne 0){ throw 'git commit failed' }
    $dirty=@(& git -C $path status --porcelain)
    [pscustomobject]@{path=$path;clean=($dirty.Count -eq 0);head=(& git -C $path rev-parse HEAD).Trim()}
}
function Get-TraycerEvidenceProperty {
    param([Parameter(Mandatory)][object]$Object,[Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][string]$Context)
    $property=$Object.PSObject.Properties[$Name]
    if($null -eq $property -or $null -eq $property.Value){ throw "$Context.$Name is required" }
    return $property.Value
}
function Assert-TraycerEvidenceText {
    param([Parameter(Mandatory)][object]$Value,[Parameter(Mandatory)][string]$Context,[Parameter(Mandatory)][string]$Pattern)
    if($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch $Pattern){ throw "$Context is malformed" }
    return [string]$Value
}
function Get-TraycerEvidenceIdentity {
    param([Parameter(Mandatory)][object]$Value,[Parameter(Mandatory)][string]$Context)
    $label=Assert-TraycerEvidenceText (Get-TraycerEvidenceProperty $Value 'label' $Context) "$Context.label" '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
    $digest=Assert-TraycerEvidenceText (Get-TraycerEvidenceProperty $Value 'digest' $Context) "$Context.digest" '^sha256:[0-9a-f]{64}$'
    [pscustomobject]@{label=$label;digest=$digest;key="$label|$digest"}
}
function Assert-TraycerEvidenceEndpointAuthentication {
    param([Parameter(Mandatory)][object]$Endpoint,[Parameter(Mandatory)][string]$Context)
    $authentication=Get-TraycerEvidenceProperty $Endpoint 'authentication' $Context
    if((Get-TraycerEvidenceProperty $authentication 'authenticated' "$Context.authentication") -ne $true){ throw "$Context.authentication.authenticated must be true" }
    $proof=Get-TraycerEvidenceProperty $authentication 'proof' "$Context.authentication"
    Assert-TraycerEvidenceText (Get-TraycerEvidenceProperty $proof 'kind' "$Context.authentication.proof") "$Context.authentication.proof.kind" '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$' | Out-Null
    Assert-TraycerEvidenceText (Get-TraycerEvidenceProperty $proof 'digest' "$Context.authentication.proof") "$Context.authentication.proof.digest" '^sha256:[0-9a-f]{64}$' | Out-Null
}
function Assert-TraycerEvidenceBoundIdentity {
    param([Parameter(Mandatory)][object]$Identity,[Parameter(Mandatory)][hashtable]$Known,[Parameter(Mandatory)][string]$Context)
    if(-not $Known.ContainsKey($Identity.key)){ throw "$Context does not bind to an authenticated endpoint" }
}
function Test-TraycerAuthenticatedA2AEvidence {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$EvidencePath)
    if(-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)){ throw "Evidence file not found: $EvidencePath" }
    try { $evidence=Get-Content -Raw -LiteralPath $EvidencePath | ConvertFrom-Json } catch { throw "Evidence is not valid JSON: $EvidencePath" }
    if($null -eq $evidence){ throw 'Evidence is empty' }
    if((Get-TraycerEvidenceProperty $evidence 'schema_version' 'evidence') -ne 1){ throw 'Unsupported evidence.schema_version' }
    $capture=Get-TraycerEvidenceProperty $evidence 'capture' 'evidence'
    if((Get-TraycerEvidenceProperty $capture 'kind' 'evidence.capture') -ne 'authenticated_a2a_exchange'){ throw 'Evidence must describe an authenticated A2A exchange' }
    if((Get-TraycerEvidenceProperty $capture 'redaction' 'evidence.capture') -ne 'identity_labels_and_digests_only'){ throw 'Evidence must use the supported redaction contract' }
    $endpoints=@(Get-TraycerEvidenceProperty $evidence 'endpoints' 'evidence')
    if($endpoints.Count -ne 2){ throw 'Evidence must identify exactly two authenticated endpoints' }
    $known=@{}; $labels=@{}; $digests=@{}
    for($index=0;$index -lt $endpoints.Count;$index++){
        $context="evidence.endpoints[$index]"
        $identity=Get-TraycerEvidenceIdentity (Get-TraycerEvidenceProperty $endpoints[$index] 'identity' $context) "$context.identity"
        if($known.ContainsKey($identity.key) -or $labels.ContainsKey($identity.label) -or $digests.ContainsKey($identity.digest)){ throw 'Evidence contains duplicate endpoint identity' }
        Assert-TraycerEvidenceEndpointAuthentication $endpoints[$index] $context
        $known[$identity.key]=$identity; $labels[$identity.label]=$true; $digests[$identity.digest]=$true
    }
    $exchange=Get-TraycerEvidenceProperty $evidence 'exchange' 'evidence'
    Assert-TraycerEvidenceText (Get-TraycerEvidenceProperty $exchange 'id' 'evidence.exchange') 'evidence.exchange.id' '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$' | Out-Null
    if((Get-TraycerEvidenceProperty $exchange 'status' 'evidence.exchange') -ne 'success'){ throw 'Evidence exchange must report success' }
    $sender=Get-TraycerEvidenceIdentity (Get-TraycerEvidenceProperty $exchange 'sender' 'evidence.exchange') 'evidence.exchange.sender'
    $receiver=Get-TraycerEvidenceIdentity (Get-TraycerEvidenceProperty $exchange 'receiver' 'evidence.exchange') 'evidence.exchange.receiver'
    if($sender.key -eq $receiver.key){ throw 'Evidence sender and receiver must be distinct' }
    Assert-TraycerEvidenceBoundIdentity $sender $known 'Evidence exchange sender'
    Assert-TraycerEvidenceBoundIdentity $receiver $known 'Evidence exchange receiver'
    $message=Get-TraycerEvidenceProperty $exchange 'message' 'evidence.exchange'
    Assert-TraycerEvidenceText (Get-TraycerEvidenceProperty $message 'id' 'evidence.exchange.message') 'evidence.exchange.message.id' '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$' | Out-Null
    if((Get-TraycerEvidenceProperty $message 'status' 'evidence.exchange.message') -ne 'success'){ throw 'Evidence message must report success' }
    $messageSender=Get-TraycerEvidenceIdentity (Get-TraycerEvidenceProperty $message 'sender' 'evidence.exchange.message') 'evidence.exchange.message.sender'
    $messageReceiver=Get-TraycerEvidenceIdentity (Get-TraycerEvidenceProperty $message 'receiver' 'evidence.exchange.message') 'evidence.exchange.message.receiver'
    if($messageSender.key -eq $messageReceiver.key){ throw 'Evidence message sender and receiver must be distinct' }
    Assert-TraycerEvidenceBoundIdentity $messageSender $known 'Evidence message sender'
    Assert-TraycerEvidenceBoundIdentity $messageReceiver $known 'Evidence message receiver'
    if($messageSender.key -ne $sender.key -or $messageReceiver.key -ne $receiver.key){ throw 'Evidence message endpoints must match the exchange endpoints' }
    [pscustomobject]@{status='CAGE_READY';authenticated_endpoints=2;exchange_id=[string]$exchange.id;message_id=[string]$message.id;real_a2a_pass=$false}
}
Export-ModuleMember -Function Assert-TraycerPilotSafePath,Get-TraycerInstallation,Get-TraycerPilotPreflight,Get-TraycerPilotRepoIdentity,New-TraycerPilotCage,Test-TraycerAuthenticatedA2AEvidence
