<#
.SYNOPSIS
    Central resolver for the split AGENT_TASKBOARD.md active board (ORDER: taskboard-active-split-20260822).

.DESCRIPTION
    AGENT_TASKBOARD.md is now a small manifest: its own ORDER blocks were packed, whole and
    in original global order, into taskboards/active/P01.md, P02.md, P03.md (declared, in
    order, inside a `<!-- TASKBOARD-ACTIVE-PARTS ... -->` marker block at the end of the
    manifest). Every consumer that used to `Get-Content AGENT_TASKBOARD.md` and scan for
    '## ORDER-' lines must instead read the manifest, resolve its declared parts IN ORDER,
    and concatenate. This file is the ONE place that does that, so no caller hardcodes a
    P01/P02/P03 list -- the part count and names are read from the manifest at run time.

    Three read vintages, mirroring the Staged/Committed/Working split every other guard in
    this repo already uses (scripts/check_taskboard_archive.ps1's Get-Snapshot):
      Get-TaskboardActiveLogicalBytes -RepoRoot $r -Mode Working
      Get-TaskboardActiveLogicalBytes -RepoRoot $r -Mode Staged
      Get-TaskboardActiveLogicalBytes -RepoRoot $r -Mode Committed -CommitSha 'HEAD'

    An unreadable manifest (missing marker, a declared part that does not exist at the
    requested vintage) THROWS -- it must never silently resolve to zero parts/orders
    (memory: unreadable-input-must-refuse-not-skip).
#>

$script:TaskboardManifestRelPath = 'AGENT_TASKBOARD.md'
$script:TaskboardPartsMarkerStart = '<!-- TASKBOARD-ACTIVE-PARTS'
$script:TaskboardPartsMarkerEnd = '-->'

function Get-TaskboardActivePartList {
    <# Parses the manifest TEXT for its declared, ORDERED list of active part paths. #>
    param([Parameter(Mandatory = $true)][string]$ManifestText)

    $startIdx = $ManifestText.IndexOf($script:TaskboardPartsMarkerStart)
    if ($startIdx -lt 0) {
        throw "AGENT_TASKBOARD.md manifest is missing the '$($script:TaskboardPartsMarkerStart)' marker -- cannot resolve active parts"
    }
    $searchFrom = $startIdx + $script:TaskboardPartsMarkerStart.Length
    $endIdx = $ManifestText.IndexOf($script:TaskboardPartsMarkerEnd, $searchFrom)
    if ($endIdx -lt 0) {
        throw "AGENT_TASKBOARD.md manifest's TASKBOARD-ACTIVE-PARTS marker is not closed with '-->'"
    }
    $body = $ManifestText.Substring($searchFrom, $endIdx - $searchFrom)

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($body -split "`r?`n")) {
        $t = $line.Trim()
        if (-not $t) { continue }
        $parts.Add($t)
    }
    if ($parts.Count -eq 0) {
        throw "AGENT_TASKBOARD.md manifest declares zero active parts -- refusing (an empty result must not be mistaken for a genuinely empty queue)"
    }

    # ORDERING IS CONTRACTUAL: parts are packed sequentially (P01, P02, P03, ...) in original
    # global order by construction, so the declared list must already be in ascending order.
    # A manifest that lists them out of order (e.g. swaps P02/P03) would silently reorder the
    # reconstructed active queue with no content change to flag it any other way -- refuse
    # instead of reconstructing a queue whose order does not match what was declared clean.
    $sorted = @($parts | Sort-Object)
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($parts[$i] -ne $sorted[$i]) {
            throw "AGENT_TASKBOARD.md manifest's TASKBOARD-ACTIVE-PARTS list is not in ascending order (declared: $($parts -join ', ')) -- part ordering is contractual, refusing to reconstruct a reordered queue"
        }
    }

    return $parts.ToArray()
}

function Invoke-TaskboardGitRaw {
    <# `git <args>` (RepoRoot as cwd), raw bytes on stdout. Self-contained (no dependency on
       any other script's process-spawn helper) so this library can be dot-sourced standalone
       by any caller. #>
    param([string]$RepoRoot, [string]$Arguments)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $RepoRoot
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $ms = New-Object System.IO.MemoryStream
    $proc.StandardOutput.BaseStream.CopyTo($ms)
    [void]$proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [pscustomobject]@{ ExitCode = $proc.ExitCode; Bytes = $ms.ToArray() }
}

function Get-TaskboardGitBlobBytesOrNull {
    <# `git show <ref>:<path>` (ref '' = staged/index: `git show :<path>`). $null if missing. #>
    param([string]$RepoRoot, [string]$Ref, [string]$Path)
    $spec = if ($Ref) { '{0}:{1}' -f $Ref, $Path } else { ':{0}' -f $Path }
    $r = Invoke-TaskboardGitRaw -RepoRoot $RepoRoot -Arguments ('show "{0}"' -f $spec)
    if ($r.ExitCode -ne 0) { return $null }
    return $r.Bytes
}

function Get-TaskboardActiveLogicalBytes {
    <#
    .SYNOPSIS
        Reconstructs the full logical active-board bytes: every declared part's raw bytes,
        concatenated in the manifest's declared order. This is what every ORDER-block-scanning
        consumer should read instead of AGENT_TASKBOARD.md alone.

    .PARAMETER Mode
        Working   -- read the manifest + parts straight off disk (no git).
        Staged    -- read the manifest + parts from the git INDEX (`git show :<path>`).
        Committed -- read the manifest + parts from -CommitSha (`git show <sha>:<path>`).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][ValidateSet('Working', 'Staged', 'Committed')][string]$Mode,
        [string]$CommitSha = ''
    )

    if ($Mode -eq 'Committed' -and -not $CommitSha) {
        throw 'Get-TaskboardActiveLogicalBytes -Mode Committed requires -CommitSha'
    }
    $gitRef = if ($Mode -eq 'Committed') { $CommitSha } else { '' }

    if ($Mode -eq 'Working') {
        $manifestFullPath = Join-Path $RepoRoot $script:TaskboardManifestRelPath
        if (-not (Test-Path -LiteralPath $manifestFullPath)) {
            throw "AGENT_TASKBOARD.md not found at $manifestFullPath"
        }
        $manifestBytes = [System.IO.File]::ReadAllBytes($manifestFullPath)
    } else {
        $manifestBytes = Get-TaskboardGitBlobBytesOrNull -RepoRoot $RepoRoot -Ref $gitRef -Path $script:TaskboardManifestRelPath
        if ($null -eq $manifestBytes) {
            throw "AGENT_TASKBOARD.md not readable at $Mode ($(if ($gitRef) { $gitRef } else { 'index' }))"
        }
    }

    $manifestText = [System.Text.Encoding]::UTF8.GetString($manifestBytes)

    # A manifest with no TASKBOARD-ACTIVE-PARTS marker is a pre-split single-file board (the
    # shape every fixture/test built before ORDER: taskboard-active-split-20260822, including
    # a legitimately empty board with zero '## ORDER-' lines). Treat it as the whole content --
    # this is a DIFFERENT SHAPE from the marker being present-but-empty (which still throws
    # inside Get-TaskboardActivePartList), so "not migrated yet" and "migrated but unreadable"
    # stay distinguishable.
    if ($manifestText.IndexOf($script:TaskboardPartsMarkerStart) -lt 0) {
        return $manifestBytes
    }

    $parts = Get-TaskboardActivePartList -ManifestText $manifestText

    $partByteArrays = New-Object System.Collections.Generic.List[byte[]]
    foreach ($p in $parts) {
        if ($Mode -eq 'Working') {
            $fp = Join-Path $RepoRoot $p
            if (-not (Test-Path -LiteralPath $fp)) {
                throw "AGENT_TASKBOARD.md declares active part '$p' but it does not exist on disk"
            }
            $partByteArrays.Add([System.IO.File]::ReadAllBytes($fp))
        } else {
            $b = Get-TaskboardGitBlobBytesOrNull -RepoRoot $RepoRoot -Ref $gitRef -Path $p
            if ($null -eq $b) {
                throw "AGENT_TASKBOARD.md declares active part '$p' but it is not readable at $Mode ($(if ($gitRef) { $gitRef } else { 'index' }))"
            }
            $partByteArrays.Add($b)
        }
    }

    $total = 0
    foreach ($b in $partByteArrays) { $total += $b.Length }
    $out = New-Object 'byte[]' $total
    $offset = 0
    foreach ($b in $partByteArrays) { [Array]::Copy($b, 0, $out, $offset, $b.Length); $offset += $b.Length }
    return $out
}

function Get-TaskboardActiveLogicalText {
    <# Same as Get-TaskboardActiveLogicalBytes, decoded as UTF-8 text (BOM stripped). #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][ValidateSet('Working', 'Staged', 'Committed')][string]$Mode,
        [string]$CommitSha = ''
    )
    $bytes = Get-TaskboardActiveLogicalBytes -RepoRoot $RepoRoot -Mode $Mode -CommitSha $CommitSha
    $enc = New-Object System.Text.UTF8Encoding($false)
    $text = $enc.GetString($bytes)
    if ($text.Length -gt 0 -and [int]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }
    return $text
}

function Get-TaskboardActiveLogicalLines {
    <# Convenience for line-oriented callers (make_status.ps1 style '^## ORDER-' scans). #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][ValidateSet('Working', 'Staged', 'Committed')][string]$Mode,
        [string]$CommitSha = ''
    )
    $text = Get-TaskboardActiveLogicalText -RepoRoot $RepoRoot -Mode $Mode -CommitSha $CommitSha
    return @($text -split "`r?`n")
}
