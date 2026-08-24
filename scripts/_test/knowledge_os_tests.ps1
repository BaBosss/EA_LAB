[CmdletBinding()]
param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
$tests = 0
function Assert-True([bool]$Condition,[string]$Message) {
    $script:tests++
    if (-not $Condition) { throw "FAIL: $Message" }
    Write-Output "ok $($script:tests) - $Message"
}
function Invoke-Packet([string]$Ref,[string]$OrderId='') {
    $invoke = @{ Root = $Root; Ref = $Ref; Stdout = $true }
    if ($OrderId) { $invoke['OrderId'] = $OrderId }
    $raw = & (Join-Path $Root 'scripts\make_context_packet.ps1') @invoke | Out-String
    return ($raw | ConvertFrom-Json)
}
$map = & (Join-Path $Root 'scripts\make_knowledge_map.ps1') -Root $Root -Check | Out-String
Assert-True ($LASTEXITCODE -eq 0 -and $map -match 'KNOWLEDGE_MAP CHECK PASS') 'knowledge map regenerates without drift'
$ki = & (Join-Path $Root 'scripts\check_knowledge_integrity.ps1') -Root $Root 3>&1 | Out-String
Assert-True ($LASTEXITCODE -eq 0 -and $ki -match 'KNOWLEDGE_INTEGRITY PASS') 'knowledge integrity checker passes with documented warnings only'
Assert-True ($ki -match 'KINT-001') 'known sample-floor contradiction is surfaced rather than silently resolved'
$p1 = Invoke-Packet 'origin/master'
$p2 = Invoke-Packet 'origin/master'
Assert-True ($p1.freshness -eq 'FRESH') 'origin/master packet reports FRESH'
Assert-True ($p1.packet_hash -eq $p2.packet_hash) 'identical source commit yields deterministic packet hash'
Assert-True ($p1.core.task.taskboard_parts.Count -ge 1) 'split active taskboard parts are discovered'
Assert-True ($p1.core.task.active_headers.Count -ge 1) 'active order headers come from reconstructed active queue'
Assert-True (($p1.core.task.active_headers -join "`n") -notmatch 'ORDER-xxx') 'template/example headers are excluded from active-order output'
$parent = (& git -C $Root rev-parse 'origin/master^').Trim()
$pOld = Invoke-Packet $parent
Assert-True ($pOld.freshness -eq 'STALE') 'non-current pinned ref reports STALE'
$pOrder = Invoke-Packet 'origin/master' 'ORDER-1461'
Assert-True ($pOrder.core.task.order_found -eq $true) 'exact active order lookup succeeds across split taskboard'
Assert-True ($pOrder.core.task.order_excerpt[0] -match '^## ORDER-1461\b') 'exact order excerpt begins at requested order header'
Assert-True (($pOrder.core.task.order_excerpt -join "`n") -notmatch '^## ORDER-(?!1461\b)') 'order excerpt does not bleed into the next order'
$guarded = $false
try {
    & (Join-Path $Root 'scripts\make_context_packet.ps1') -Root $Root -Ref 'origin/master' -OutputPath (Join-Path $Root '_forbidden_context_packet.json') | Out-Null
} catch {
    if ($_.Exception.Message -match 'must not be written inside the repository') { $guarded = $true } else { throw }
}
Assert-True $guarded 'context packet refuses writes inside repository'
Assert-True (-not (Test-Path (Join-Path $Root '_forbidden_context_packet.json'))) 'forbidden in-repo packet is not created'
$tempControl = Join-Path ([IO.Path]::GetTempPath()) ('ea_lab_kos_' + [guid]::NewGuid().ToString('N'))
try {
    & (Join-Path $Root 'scripts\make_context_packet.ps1') -Root $Root -Ref 'origin/master' -ControlRoot $tempControl | Out-Null
    $written = @(Get-ChildItem -LiteralPath (Join-Path $tempControl 'context-packets') -Filter '*.json' -File)
    Assert-True ($written.Count -eq 1) 'portable ControlRoot writes one transient packet outside the repo'
    $writtenPacket = Get-Content -LiteralPath $written[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ($writtenPacket.source_commit -eq $p1.source_commit -and $writtenPacket.non_authoritative -eq $true) 'portable transient packet preserves pinned non-authoritative identity'
} finally {
    if (Test-Path -LiteralPath $tempControl) { Remove-Item -LiteralPath $tempControl -Recurse -Force }
}
$inbox = Get-Content -LiteralPath (Join-Path $Root 'docs\research\RESEARCH_IDEA_INBOX.md') -Raw -Encoding UTF8
Assert-True ($inbox -match 'NON-AUTHORITATIVE INTAKE ONLY') 'research inbox preserves non-authoritative boundary'
$draft = Get-Content -LiteralPath (Join-Path $Root 'docs\research\FACTORY_VNEXT_DESIGN_DRAFT.md') -Raw -Encoding UTF8
Assert-True ($draft -match 'NON-CANONICAL FOR CURRENT FACTORY POLICY') 'Factory vNext draft remains non-canonical pending policy migration'
$trackedPackets = @(& git -C $Root ls-files '*context-packet*' '*context_packets*')
Assert-True ($trackedPackets.Count -eq 0) 'no generated context packet is committed as authority'
Write-Output ("KNOWLEDGE_OS_TESTS PASS tests={0}" -f $tests)
exit 0
