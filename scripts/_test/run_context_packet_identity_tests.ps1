param([string]$Root)
$ErrorActionPreference='Stop'
if(-not $Root){$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path}
$sha=(& git -C $Root rev-parse origin/master).Trim()
$scriptPath=Join-Path $Root 'scripts\make_context_packet.ps1'

function Assert-Refused {
    param([scriptblock]$Action,[string]$Pattern,[string]$Label)
    $refused=$false
    try { & $Action | Out-Null }
    catch { $refused=$_.Exception.Message -match $Pattern }
    if(-not $refused){throw "$Label was accepted or failed for the wrong reason"}
}

$packet = (& $scriptPath -Root $Root -Ref $sha -ExpectedRemoteSha $sha -Stdout | Out-String) | ConvertFrom-Json
if($packet.remote_verification -cne 'CALLER_SUPPLIED_MATCH'){throw 'missing caller remote binding'}
if(($packet.core.current_status_excerpt -join "`n") -notmatch 'CURRENT PROGRAM STATUS'){throw 'current status excerpt only contains header metadata'}
$router=@($packet.core.sources | Where-Object path -eq 'START_HERE.md')
if($router.Count -ne 1){throw 'startup router missing'}
foreach($source in $packet.core.sources){
    $blob=(& git -C $Root rev-parse ($sha+':'+$source.path)).Trim()
    if($source.git_blob -cne $blob){throw 'source blob mismatch'}
}
Assert-Refused { & $scriptPath -Root $Root -Ref $sha -ExpectedRemoteSha ('0'*40) -Stdout } 'differs from caller-verified remote' 'moved remote SHA'
$unverified=(& $scriptPath -Root $Root -Ref $sha -Stdout | Out-String) | ConvertFrom-Json
if($unverified.remote_verification -cne 'NOT_PERFORMED'){throw 'local tracking ref misreported as remote verification'}

# ORDER-1461 is deliberately longer than the former silent 90-line cap. The
# production packet must return its whole exact peer-heading block.
$longOrder=(& $scriptPath -Root $Root -Ref $sha -ExpectedRemoteSha $sha -OrderId 'ORDER-1461' -Stdout | Out-String) | ConvertFrom-Json
if($longOrder.core.task.order_lookup_state -cne 'FOUND_COMPLETE' -or
   $longOrder.core.task.order_found -ne $true -or
   $longOrder.core.task.order_complete -ne $true){throw 'long canonical order not explicitly complete'}
$longLines=@($longOrder.core.task.order_excerpt)
if($longOrder.core.task.order_line_count -le 90){throw 'long-order fixture no longer exercises the former 90-line cap'}
if($longLines.Count -ne $longOrder.core.task.order_line_count){throw 'long canonical order line count does not match returned block'}
if($longLines[0] -notmatch '^##\s+ORDER-1461(?:\s|$)'){throw 'long canonical order starts at the wrong heading'}
if(@($longLines | Select-Object -Skip 1 | Where-Object {$_ -match '^##(?:\s+|$)'}).Count -ne 0){throw 'long canonical order crossed into the next peer block'}

$missing=(& $scriptPath -Root $Root -Ref $sha -ExpectedRemoteSha $sha -OrderId 'ORDER-NOT-PRESENT-999999' -Stdout | Out-String) | ConvertFrom-Json
if($missing.core.task.order_lookup_state -cne 'MISSING' -or
   $missing.core.task.order_found -ne $false -or
   $missing.core.task.order_complete -ne $false -or
   $missing.core.task.order_line_count -ne 0 -or
   @($missing.core.task.order_excerpt).Count -ne 0){throw 'missing canonical order did not remain an explicit incomplete result'}

$contractPath=Join-Path ([IO.Path]::GetTempPath()) ("ea-lab-owner-contract-{0}.txt" -f [guid]::NewGuid().ToString('N'))
$contractMarker='UNIQUE_OWNER_LOCAL_CONTENT_MUST_NOT_ENTER_PACKET'
[IO.File]::WriteAllText($contractPath,"$contractMarker`nSYNTHETIC_IDENTITY_FIXTURE_ONLY",(New-Object Text.UTF8Encoding($false)))
try {
    $contractHash=(Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $contractId='OWNER-SYSTEM-CONVERGENCE-20260906'
    $contractRaw=(& $scriptPath -Root $Root -Ref $sha -ExpectedRemoteSha $sha -TaskContractPath $contractPath -ExpectedTaskContractSha256 $contractHash -TaskContractId $contractId -Stdout | Out-String)
    $contractPacket=$contractRaw | ConvertFrom-Json
    $binding=$contractPacket.core.task.owner_local_contract
    if($contractPacket.core.task.selection_mode -cne 'OWNER_LOCAL_CONTRACT' -or
       $contractPacket.core.task.order_lookup_state -cne 'NOT_REQUESTED' -or
       $null -ne $contractPacket.core.task.order_id){throw 'owner-local contract accidentally selected an unrelated canonical order'}
    if($binding.contract_id -cne $contractId -or
       $binding.absolute_path -cne [IO.Path]::GetFullPath($contractPath) -or
       $binding.sha256 -cne $contractHash -or
       $binding.source_classification -cne 'OWNER_LOCAL_NONCANONICAL_EVIDENCE' -or
       $binding.canonical -ne $false -or
       $binding.content_included -ne $false -or
       $binding.content_interpreted -ne $false -or
       $binding.authority_granted -ne $false){throw 'owner-local contract binding lost its noncanonical/no-authority classification'}
    if($contractRaw.Contains($contractMarker)){throw 'owner-local contract content leaked into packet'}

    Assert-Refused { & $scriptPath -Root $Root -Ref $sha -ExpectedRemoteSha $sha -TaskContractPath $contractPath -ExpectedTaskContractSha256 ('0'*64) -TaskContractId $contractId -Stdout } 'SHA-256 mismatch' 'wrong owner-local contract hash'
    Assert-Refused { & $scriptPath -Root $Root -Ref $sha -ExpectedRemoteSha $sha -TaskContractPath ($contractPath+'.missing') -ExpectedTaskContractSha256 $contractHash -TaskContractId $contractId -Stdout } 'contract is missing' 'missing owner-local contract'
    Assert-Refused { & $scriptPath -Root $Root -Ref $sha -ExpectedRemoteSha $sha -TaskContractPath $contractPath -TaskContractId $contractId -Stdout } 'required together' 'partial owner-local contract identity'
    Assert-Refused { & $scriptPath -Root $Root -Ref $sha -ExpectedRemoteSha $sha -OrderId 'ORDER-1461' -TaskContractPath $contractPath -ExpectedTaskContractSha256 $contractHash -TaskContractId $contractId -Stdout } 'OrderId conflicts with TaskContractId' 'conflicting canonical/external task identity'

    $insidePath=Join-Path $Root 'START_HERE.md'
    $insideHash=(Get-FileHash -LiteralPath $insidePath -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-Refused { & $scriptPath -Root $Root -Ref $sha -ExpectedRemoteSha $sha -TaskContractPath $insidePath -ExpectedTaskContractSha256 $insideHash -TaskContractId $contractId -Stdout } 'must be external to the repository' 'repository file presented as owner-local contract'
} finally {
    if([IO.File]::Exists($contractPath)){[IO.File]::Delete($contractPath)}
}

Write-Output "CONTEXT_IDENTITY PASS sources=$($packet.core.sources.Count) no_network=true long_order_lines=$($longLines.Count) owner_local_contract=bound_not_interpreted"
