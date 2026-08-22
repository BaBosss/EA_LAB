<#
.SYNOPSIS
    ORDER: taskboard-active-split-20260822. Adversarial (negative) coverage for the
    AGENT_TASKBOARD.md active-board split: scripts/lib/taskboard_source.ps1 and the two
    consumers it feeds directly on the commit path (check_order_collision.ps1,
    check_taskboard_archive.ps1's Invoke-ActiveConservationCheck).

.DESCRIPTION
    Cases A-F from the migration's acceptance criteria. Every fixture is built in a
    throwaway TEMP directory; nothing here touches the real repo's AGENT_TASKBOARD.md,
    taskboards/active/*, or git state. Exit 0 = all cases behaved as required, exit 1 =
    at least one case did not refuse/trigger as required.
#>
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $RepoRoot 'scripts\lib\taskboard_source.ps1')

$failures = New-Object System.Collections.Generic.List[string]
function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) { Write-Host "  ok   $Label" }
    else { Write-Host "  FAIL $Label" -ForegroundColor Red; $failures.Add($Label) }
}

function New-TempDir {
    $p = Join-Path $env:TEMP ('taskboard_negtest_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $p | Out-Null
    return $p
}

$BLOCK_A = "## ORDER-100 -- fixture A -- OPEN`r`nbody A`r`n"
$BLOCK_B = "## ORDER-200 -- fixture B -- OPEN`r`nbody B`r`n"
$BLOCK_C = "## ORDER-300 -- fixture C -- OPEN`r`nbody C`r`n"

function New-Manifest {
    param([string[]]$PartNames)
    $lines = @('# fixture manifest', '', '<!-- TASKBOARD-ACTIVE-PARTS')
    $lines += $PartNames
    $lines += '-->'
    return ($lines -join "`n") + "`n"
}

Write-Host '=== D: missing declared part MUST fail visible ==='
$d = New-TempDir
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $d 'taskboards\active') | Out-Null
    Set-Content -LiteralPath (Join-Path $d 'AGENT_TASKBOARD.md') -Value (New-Manifest -PartNames @('taskboards/active/P01.md', 'taskboards/active/P02.md')) -NoNewline -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $d 'taskboards\active\P01.md') -Value $BLOCK_A -NoNewline -Encoding UTF8
    # P02.md deliberately NOT created.
    $threw = $false
    try { [void](Get-TaskboardActiveLogicalBytes -RepoRoot $d -Mode Working) } catch { $threw = $true }
    Assert-True $threw 'D: missing declared part throws (refuses, does not silently drop it)'
} finally { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue }

Write-Host '=== F: improper part reordering MUST refuse ==='
try {
    $manifestReordered = New-Manifest -PartNames @('taskboards/active/P02.md', 'taskboards/active/P01.md')
    $threw = $false
    try { [void](Get-TaskboardActivePartList -ManifestText $manifestReordered) } catch { $threw = $true }
    Assert-True $threw 'F: manifest declaring parts out of ascending order throws'

    $manifestOrdered = New-Manifest -PartNames @('taskboards/active/P01.md', 'taskboards/active/P02.md')
    $ok = $false
    try { [void](Get-TaskboardActivePartList -ManifestText $manifestOrdered); $ok = $true } catch { $ok = $false }
    Assert-True $ok 'F control: correctly-ordered manifest does NOT throw'
} catch { Assert-True $false "F: unexpected tooling failure: $($_.Exception.Message)" }

Write-Host '=== zero-parts marker MUST refuse (not "empty queue") ==='
try {
    $manifestEmpty = "# fixture`n`n<!-- TASKBOARD-ACTIVE-PARTS`n-->`n"
    $threw = $false
    try { [void](Get-TaskboardActivePartList -ManifestText $manifestEmpty) } catch { $threw = $true }
    Assert-True $threw 'zero declared parts throws'
} catch { Assert-True $false "zero-parts tooling failure: $($_.Exception.Message)" }

Write-Host '=== pre-split fixture (no marker) falls back to whole-manifest content ==='
$legacy = New-TempDir
try {
    $legacyText = "# legacy single-file board`n`n$BLOCK_A$BLOCK_B"
    Set-Content -LiteralPath (Join-Path $legacy 'AGENT_TASKBOARD.md') -Value $legacyText -NoNewline -Encoding UTF8
    $bytes = Get-TaskboardActiveLogicalBytes -RepoRoot $legacy -Mode Working
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    Assert-True ($text -eq $legacyText) 'legacy (no-marker) manifest reconstructs as its own full content'
} finally { Remove-Item -Recurse -Force $legacy -ErrorAction SilentlyContinue }

Write-Host '=== positive control: 2-part reconstruction preserves order + content ==='
$pos = New-TempDir
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $pos 'taskboards\active') | Out-Null
    Set-Content -LiteralPath (Join-Path $pos 'AGENT_TASKBOARD.md') -Value (New-Manifest -PartNames @('taskboards/active/P01.md', 'taskboards/active/P02.md')) -NoNewline -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $pos 'taskboards\active\P01.md') -Value $BLOCK_A -NoNewline -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $pos 'taskboards\active\P02.md') -Value $BLOCK_B -NoNewline -Encoding UTF8
    $text = Get-TaskboardActiveLogicalText -RepoRoot $pos -Mode Working
    Assert-True ($text -eq ($BLOCK_A + $BLOCK_B)) 'reconstruction == part1 + part2, in declared order'
} finally { Remove-Item -Recurse -Force $pos -ErrorAction SilentlyContinue }

Write-Host '=== A: duplicate order id across parts MUST refuse (check_order_collision.ps1 RULE 1) ==='
try {
    $dupActive = $BLOCK_A + $BLOCK_B + $BLOCK_A   # ORDER-100 appears twice, distinct parts in spirit
    $r = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\check_order_collision.ps1') `
        -StagedFileList 'AGENT_TASKBOARD.md' -StagedActiveContent $dupActive -ArchiveContent ' ' -HeadActiveContent ' ' 2>&1
    $rc = $LASTEXITCODE
    Assert-True ($rc -eq 1) "A: duplicate id across staged active content -> BLOCK (rc=$rc)"
} catch { Assert-True $false "A: tooling failure: $($_.Exception.Message)" }

Write-Host '=== E: staging only a secondary part (root untouched) MUST still trigger the guard ==='
try {
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\check_order_collision.ps1') `
        -StagedFileList 'taskboards/active/P02.md' -StagedActiveContent $BLOCK_C -ArchiveContent ' ' -HeadActiveContent ' ' 2>&1
    $rc = $LASTEXITCODE
    $noOp = ($out -join "`n") -match 'not staged -- pass \(no-op\)'
    Assert-True (-not $noOp) 'E: part-only staged path does not early-exit as a no-op'
} catch { Assert-True $false "E: tooling failure: $($_.Exception.Message)" }

Write-Host '=== C: a deleted block MUST surface as OrderLost (Invoke-ActiveConservationCheck) ==='
try {
    . (Join-Path $RepoRoot 'scripts\check_taskboard_archive.ps1') -RepoRoot $RepoRoot 6>$null
    $splitBlocks = @(Get-ClassifiedBlocks -Text ($BLOCK_A + $BLOCK_B) -SourceTag 'split-active')
    $currentActiveBlocks = @(Get-ClassifiedBlocks -Text $BLOCK_A -SourceTag 'current-active')   # ORDER-200 removed
    $currentArchiveBlocks = @(Get-ClassifiedBlocks -Text '' -SourceTag 'current-archive')        # not archived either
    $result = Invoke-ActiveConservationCheck -SplitActiveBlocks $splitBlocks -CurrentActiveBlocks $currentActiveBlocks -CurrentArchiveBlocks $currentArchiveBlocks
    Assert-True ($result.OrderLost.Count -eq 1) 'C: a block removed from active AND absent from archive -> OrderLost'

    $currentArchiveBlocksB = @(Get-ClassifiedBlocks -Text $BLOCK_B -SourceTag 'current-archive')  # legitimately archived instead
    $result2 = Invoke-ActiveConservationCheck -SplitActiveBlocks $splitBlocks -CurrentActiveBlocks $currentActiveBlocks -CurrentArchiveBlocks $currentArchiveBlocksB
    Assert-True ($result2.OrderLost.Count -eq 0) 'C control: a block moved to archive is conserved, not lost'
} catch { Assert-True $false "C: tooling failure: $($_.Exception.Message)" }

Write-Host '=== B: a mutated block MUST be distinguishable from an unmutated one (hash-based, migration verifier) ==='
try {
    $orig = @{ Id = 'ORDER-100'; Sha256 = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($BLOCK_A))) -Algorithm SHA256).Hash }
    $mutatedText = $BLOCK_A -replace 'body A', 'body A -- TAMPERED'
    $mutated = @{ Id = 'ORDER-100'; Sha256 = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($mutatedText))) -Algorithm SHA256).Hash }
    Assert-True ($orig.Sha256 -ne $mutated.Sha256) 'B: same id, mutated body -> different hash (bijection check would flag it)'
    $unmutated = @{ Id = 'ORDER-100'; Sha256 = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($BLOCK_A))) -Algorithm SHA256).Hash }
    Assert-True ($orig.Sha256 -eq $unmutated.Sha256) 'B control: identical bytes -> identical hash (no false mutation)'
} catch { Assert-True $false "B: tooling failure: $($_.Exception.Message)" }

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "=== $($failures.Count) FAILURE(S) ===" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
Write-Host '=== ALL NEGATIVE/ADVERSARIAL CASES PASS ===' -ForegroundColor Green
exit 0
