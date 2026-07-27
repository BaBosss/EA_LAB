<#
.SYNOPSIS
    ORDER-252 -- staleness linter. Finds CLOSED order blocks that still assert
    something the repo has since walked back.

.DESCRIPTION
    ORDER-073, ORDER-143 and ORDER-188 were the same bug three times, not three
    bugs: downstream evidence moved, the closed block did not move with it, and
    the correction was written down somewhere else (a banner on the verdict file,
    a notes column, a newer order). Nothing checked that a closed block's claims
    still matched the repo, so the board kept selling withdrawn evidence.

    check_taskboard_archive.ps1 verifies that closures are LINKED. This verifies
    that closures are still TRUE, which is a different question.

    What it does, for every block whose status is terminal:
      1. resolve every repo path the block cites
      2. flag the block if a cited artifact now carries a retraction banner
         (SUPERSEDED / WITHDRAWN / DEPRECATED / RETRACTED / ถอน / หักล้าง) near
         its top
      3. flag the block if a cited path no longer resolves, or a cited commit is
         not an object in this repository

    WARN-ONLY BY DESIGN. It reports and exits 0 unless -Strict is passed. A
    linter over prose will false-fire, and a hard block on day one just teaches
    people to route around it. Let it be read first; tighten it once the noise
    floor is known.

    Run: powershell -NoProfile -File scripts\check_block_staleness.ps1
         powershell -NoProfile -File scripts\check_block_staleness.ps1 -Strict
#>
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Strict,
    [int]$BannerScanLines = 25,
    [switch]$ShowUnresolved
)

$ErrorActionPreference = 'Stop'

# Reuse the board's own status classifier so this linter and the archive
# validator can never disagree about what "terminal" means. (That classifier is
# itself cage-covered by scripts\_test\run_statusclass_tests.ps1 after the
# ORDER-260 substring bug.)
$validator = Join-Path $RepoRoot 'scripts\check_taskboard_archive.ps1'
. $validator -RepoRoot $RepoRoot 6>$null

$boards = @(
    (Join-Path $RepoRoot 'AGENT_TASKBOARD.md'),
    (Join-Path $RepoRoot 'ARCHIVE_TASKBOARD_2026-07A.md')
)

# Files that are themselves indexes of every verdict ever written will contain
# these words constantly; citing one is not evidence of staleness.
$selfReferential = @(
    'AGENT_TASKBOARD.md','ARCHIVE_TASKBOARD_2026-07A.md','EA_SCORECARD_AND_REGISTRY.md',
    'EA_MASTER_INDEX.csv','PROJECT_STATE.md','PROJECT_HISTORY.md','MASTER_BACKLOG.md',
    'TASKBOARD_DIGEST.md','VISION.md','ROADMAP.md','CLAUDE.md','AGENTS.md'
)

# Thai tokens are built from code points on purpose: Windows PowerShell 5.1 reads
# a .ps1 as ANSI unless it has a BOM, so literal Thai in this file would arrive
# mangled and the tokens would silently never match. Keeping the file ASCII-only
# also matches the oc-qwen lane's constraint on scripts.
$thaiThon    = ([char]0x0E16 + [char]0x0E2D + [char]0x0E19)                                              # withdrawn
$thaiHakLang = ([char]0x0E2B + [char]0x0E31 + [char]0x0E01 + [char]0x0E25 + [char]0x0E49 + [char]0x0E32 + [char]0x0E07)  # refuted
$thaiMoka    = ([char]0x0E42 + [char]0x0E21 + [char]0x0E06 + [char]0x0E30)                               # void
$bannerTokens = @('SUPERSEDED','WITHDRAWN','DEPRECATED','RETRACTED',$thaiThon,$thaiHakLang,$thaiMoka)

# Only file kinds that are supposed to be IN the repo. Reports (.htm), optimizer
# XML and generated .set files are routinely produced outside git, so a missing
# one says nothing about staleness -- including them buried the real signal under
# 200+ non-findings on the first run.
$pathRegex   = '(?<p>(?:[A-Za-z0-9_\-.()]+[\\/])+[A-Za-z0-9_\-.()]+\.(?:md|csv|ps1|py|mq5|mqh))'
# A commit-ish token must contain at least one a-f letter. Without that, this
# regex ate MT5 account numbers (463666728, 415573666), magic numbers, and
# yyyymmdd dates (20260709) and reported 62 "dangling commits", 59 of which were
# never commits at all.
$commitRegex = '(?<![0-9a-zA-Z])(?<c>(?=[0-9a-f]*[a-f])[0-9a-f]{8,40})(?![0-9a-zA-Z])'

$bannerCache = @{}
function Test-ArtifactRetracted {
    param([string]$FullPath)
    if ($bannerCache.ContainsKey($FullPath)) { return $bannerCache[$FullPath] }
    # What counts as a BANNER rather than a passing mention. Tuned against the real
    # corpus on 2026-07-27, where the loose version produced 23 hits of which
    # roughly half were prose:
    #   * near the top of the file (banners are announcements, not footnotes)
    #   * Latin tokens must be UPPERCASE -- "superseded, see rev02 below" inside a
    #     sentence is narration; "**SUPERSEDED**" is a banner
    #   * not inside a markdown table row -- RECONCILE_EXCEPTIONS.md is a table OF
    #     superseded things, so every row would otherwise fire
    #   * the token has to appear early on the line, not buried in a paragraph
    $hit = $null
    try {
        $head = Get-Content -LiteralPath $FullPath -TotalCount $BannerScanLines -Encoding UTF8 -ErrorAction Stop
        foreach ($line in $head) {
            $trimmed = $line.Trim()
            if ($trimmed.StartsWith('|')) { continue }
            foreach ($tok in $bannerTokens) {
                $isLatin = ($tok -match '^[A-Z]+$')
                $idx = if ($isLatin) {
                    $line.IndexOf($tok, [System.StringComparison]::Ordinal)   # case-sensitive
                } else {
                    $line.IndexOf($tok, [System.StringComparison]::Ordinal)
                }
                if ($idx -ge 0 -and $idx -lt 60) {
                    $hit = ('{0} :: {1}' -f $tok, $trimmed)
                    break
                }
            }
            if ($hit) { break }
        }
    } catch { $hit = $null }
    $bannerCache[$FullPath] = $hit
    return $hit
}

$commitCache = @{}
function Test-CommitExists {
    param([string]$Sha)
    if ($commitCache.ContainsKey($Sha)) { return $commitCache[$Sha] }
    $r = Invoke-GitRaw -RepoRoot $RepoRoot -Arguments ('cat-file -e "{0}^{{commit}}"' -f $Sha)
    $ok = ($r.ExitCode -eq 0)
    $commitCache[$Sha] = $ok
    return $ok
}

$retracted = New-Object System.Collections.Generic.List[object]
$missingPath = New-Object System.Collections.Generic.List[object]
$missingCommit = New-Object System.Collections.Generic.List[object]
$terminalCount = 0
$scannedCount = 0

foreach ($board in $boards) {
    if (-not (Test-Path -LiteralPath $board)) { continue }
    $boardName = Split-Path $board -Leaf
    $lines = Get-Content -LiteralPath $board -Encoding UTF8

    $curHeader = $null; $curStart = 0; $buf = New-Object System.Collections.Generic.List[string]

    function Complete-Block {
        param([string]$Header, [int]$StartLine, [string[]]$Body)
        if (-not $Header) { return }
        $script:scannedCount++

        $isTerminal = $false
        try {
            $status = Get-StatusClass -Header $Header -BlockType 'ORDER'
            $isTerminal = ($status.Class -eq 'Terminal')
        } catch { $isTerminal = $false }
        if (-not $isTerminal) { return }
        $script:terminalCount++

        $blockText = ($Header + "`n" + ($Body -join "`n"))
        $orderId = if ($Header -match '^##\s*(ORDER-[A-Za-z0-9\-]+)') { $matches[1] } else { '(unnamed)' }
        $where = ('{0}:{1}' -f $boardName, $StartLine)

        $seenPaths = @{}
        foreach ($m in [regex]::Matches($blockText, $pathRegex)) {
            $rel = $m.Groups['p'].Value -replace '/', '\'
            # Blocks cite absolute paths as often as relative ones. The regex has
            # no anchor, so "D:\EA_LAB\scripts\x.ps1" arrives here as
            # "EA_LAB\scripts\x.ps1" -- normalise it back to repo-relative rather
            # than reporting a real file as missing.
            $rel = $rel -replace '^(?i)(?:[A-Z]:\\)?EA_LAB\\', ''
            if ($seenPaths.ContainsKey($rel)) { continue }
            $seenPaths[$rel] = $true
            $leaf = Split-Path $rel -Leaf
            if ($selfReferential -contains $leaf) { continue }
            if ($rel -like '*.claude\worktrees\*') { continue }

            $full = Join-Path $RepoRoot $rel
            if (-not (Test-Path -LiteralPath $full)) {
                $script:missingPath.Add([pscustomobject]@{ Order = $orderId; Where = $where; Path = $rel })
                continue
            }
            if ((Get-Item -LiteralPath $full).PSIsContainer) { continue }
            $banner = Test-ArtifactRetracted -FullPath $full
            if ($banner) {
                $script:retracted.Add([pscustomobject]@{ Order = $orderId; Where = $where; Path = $rel; Banner = $banner })
            }
        }

        $seenCommits = @{}
        foreach ($m in [regex]::Matches($blockText, $commitRegex)) {
            $sha = $m.Groups['c'].Value
            if ($seenCommits.ContainsKey($sha)) { continue }
            $seenCommits[$sha] = $true
            if (-not (Test-CommitExists -Sha $sha)) {
                $script:missingCommit.Add([pscustomobject]@{ Order = $orderId; Where = $where; Commit = $sha })
            }
        }
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -like '## *') {
            Complete-Block -Header $curHeader -StartLine $curStart -Body $buf.ToArray()
            $curHeader = $lines[$i]; $curStart = $i + 1; $buf.Clear()
        } elseif ($curHeader) {
            $buf.Add($lines[$i])
        }
    }
    Complete-Block -Header $curHeader -StartLine $curStart -Body $buf.ToArray()
}

Write-Host ''
Write-Host '=== ORDER-252 staleness linter (warn-only) ===' -ForegroundColor Cyan
Write-Host ("blocks scanned: {0} | terminal: {1}" -f $scannedCount, $terminalCount)
Write-Host ''

if ($retracted.Count -gt 0) {
    Write-Host ("[STALE] {0} closed block(s) cite an artifact that now carries a retraction banner:" -f $retracted.Count) -ForegroundColor Yellow
    foreach ($r in $retracted) {
        Write-Host ("  {0} ({1})" -f $r.Order, $r.Where)
        Write-Host ("      cites : {0}" -f $r.Path)
        Write-Host ("      banner: {0}" -f $r.Banner)
    }
    Write-Host ''
} else {
    Write-Host '[OK] no closed block cites a retracted artifact' -ForegroundColor Green
}

if ($missingCommit.Count -gt 0) {
    Write-Host ("[DANGLING] {0} cited commit(s) are not objects in this repository:" -f $missingCommit.Count) -ForegroundColor Yellow
    foreach ($c in $missingCommit) { Write-Host ("  {0} ({1}) -> {2}" -f $c.Order, $c.Where, $c.Commit) }
    Write-Host ''
} else {
    Write-Host '[OK] every cited commit resolves' -ForegroundColor Green
}

if ($missingPath.Count -gt 0) {
    Write-Host ("[UNRESOLVED] {0} cited path(s) do not exist (moved without a citation rewrite?)" -f $missingPath.Count) -ForegroundColor DarkYellow
    if ($ShowUnresolved) {
        foreach ($p in $missingPath) { Write-Host ("  {0} ({1}) -> {2}" -f $p.Order, $p.Where, $p.Path) }
    } else {
        Write-Host '        (re-run with -ShowUnresolved to list them)'
    }
    Write-Host ''
}

$hard = $retracted.Count + $missingCommit.Count
if ($Strict -and $hard -gt 0) {
    Write-Host ("STRICT: {0} finding(s) that are not merely unresolved paths" -f $hard) -ForegroundColor Red
    exit 1
}
exit 0
