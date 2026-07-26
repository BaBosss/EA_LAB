<#
.SYNOPSIS
    Generates TASKBOARD_DIGEST.md -- one line per order across BOTH taskboards.

.DESCRIPTION
    The problem this solves: AGENT_TASKBOARD.md + ARCHIVE_TASKBOARD_2026-07A.md are
    ~1.4MB of full order bodies. There was no way to answer "what happened to
    ORDER-183?" without grepping a huge file, and docs/memory_control/ARCHIVE_INDEX.md
    -- which sounds like the answer -- is a block_id/sha256 manifest for the integrity
    validator, not something a human reads.

    So this emits the human layer: order id, date, one-line title, the verdict verb,
    the outcome clause, and which file holds the full body. Detail stays in the
    archive; you come here first and only open the archive when you need the body.

    DETERMINISTIC BY CONSTRUCTION -- no timestamps, no run ids, no hostname. Running it
    twice against unchanged boards reproduces the file byte-for-byte, which is what
    lets -Check work as a staleness gate.

.PARAMETER Check
    READ-ONLY. Regenerates in memory and compares to the on-disk TASKBOARD_DIGEST.md.
    Exit 0 if identical, 1 if stale/missing, 2 on a tooling failure. Never writes.

.PARAMETER Root
    Repo root. Defaults to the parent of this script's directory.

.NOTES
    Header grammar this parses (stable since ORDER-124 template):
        ## ORDER-<id> — [<tag>] <title> — `<STATUS>`
    The status is the LAST backtick span in the header; everything between the first
    em-dash and that span is the title. Both are optional in older rows, so every
    field degrades to empty rather than throwing -- a digest that skips a malformed
    row silently would be worse than one that shows it blank.
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$ACTIVE_REL  = 'AGENT_TASKBOARD.md'
$ARCHIVE_REL = 'ARCHIVE_TASKBOARD_2026-07A.md'
$OUT_REL     = 'TASKBOARD_DIGEST.md'

$activePath  = Join-Path $Root $ACTIVE_REL
$archivePath = Join-Path $Root $ARCHIVE_REL
$outPath     = Join-Path $Root $OUT_REL

function Get-OrderHeaders {
    <# Returns one object per '## ORDER-...' header found in $Path. #>
    param([string]$Path, [string]$Location)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "taskboard not found: $Path"
    }
    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    $rows  = New-Object System.Collections.Generic.List[object]

    for ($idx = 0; $idx -lt $lines.Count; $idx++) {
        $line = $lines[$idx]
        if ($line -notmatch '^##\s+ORDER-') { continue }

        # id = everything after 'ORDER-' up to the first space, em-dash or backtick
        $orderId = ''
        if ($line -match '^##\s+ORDER-([^\s—`]+)') { $orderId = $Matches[1].TrimEnd('.',',',':') }

        # status = the backtick span that opens with a status verb. Headers carry other
        # backtick spans (EA names, .set paths) both before AND after the status -- e.g.
        # "... — `REVIEWED(Claude, 2026-07-04)` (role: ZCode ...)" -- so neither "first"
        # nor "last" is right. Match on the verb vocabulary instead, and remember WHERE
        # it started so the title can be cut exactly there.
        $statusFull  = ''
        $statusStart = -1
        $verbPattern = '^(REVIEWED|DONE|CLOSED|FIXED|CORRECTED|RESOLVED|OPEN|CLAIMED|BLOCKED|SKIPPED|BUILT|FUNNELED|STAGE2-DONE|PART|WAITING|CAMPAIGN|CORE|GBPJPY|Wave1|🚀|PENDING)'
        foreach ($tick in [regex]::Matches($line, '`([^`]+)`')) {
            $candidate = $tick.Groups[1].Value.Trim()
            if ($candidate -match $verbPattern) {
                $statusFull  = $candidate
                $statusStart = $tick.Index
                break
            }
        }
        # fall back to the last span only if no verb matched, so odd rows still get something
        if (-not $statusFull) {
            $tickMatches = [regex]::Matches($line, '`([^`]+)`')
            if ($tickMatches.Count -gt 0) {
                $lastTick    = $tickMatches[$tickMatches.Count - 1]
                $statusFull  = $lastTick.Groups[1].Value.Trim()
                $statusStart = $lastTick.Index
            }
        }

        # verb = leading word of the status, normalised for grouping
        $verb = ''
        if ($statusFull -match '^([A-Za-z][A-Za-z0-9\-\+/ ]*?)\s*[\(:·]') { $verb = $Matches[1].Trim() }
        elseif ($statusFull -match '^([A-Za-z][A-Za-z0-9\-\+/]*)') { $verb = $Matches[1].Trim() }
        if ($verb) { $verb = $verb.ToUpperInvariant() }

        # outcome = the clause after the first ':' in the status (that is where the
        # verdict sentence lives), else the status minus the verb+attribution
        $outcome = ''
        $colonAt = $statusFull.IndexOf(':')
        if ($colonAt -ge 0 -and $colonAt -lt ($statusFull.Length - 1)) {
            $outcome = $statusFull.Substring($colonAt + 1).Trim()
        }

        # date = the LAST yyyy-mm-dd appearing in the status span
        $closedOn = ''
        $dateMatches = [regex]::Matches($statusFull, '\d{4}-\d{2}-\d{2}')
        if ($dateMatches.Count -gt 0) { $closedOn = $dateMatches[$dateMatches.Count - 1].Value }

        # title = the header text BEFORE the status span, minus the '## ORDER-id —' prefix
        $title = $line
        if ($statusStart -ge 0) { $title = $line.Substring(0, $statusStart) }
        $title = $title -replace '^##\s+ORDER-[^\s—`]+\s*', ''
        $title = $title -replace '^—\s*', ''
        $title = $title.Trim().TrimEnd([char]0x2014).Trim()

        $rows.Add([pscustomobject]@{
            OrderId  = $orderId
            SortKey  = (Get-OrderSortKey -OrderId $orderId)
            Title    = (ConvertTo-CellText -Text $title    -Max 90)
            Verb     = $verb
            Outcome  = (ConvertTo-CellText -Text $outcome  -Max 110)
            ClosedOn = $closedOn
            Location = $Location
            Line     = ($idx + 1)
        })
    }
    return $rows
}

function Get-OrderSortKey {
    <# '210' -> '000210~' ; '098-C' -> '000098~C' ; 'LANEC-FAN' -> '999999~LANEC-FAN'.
       Keeps numeric orders in numeric order and parks the named lanes at the end. #>
    param([string]$OrderId)
    if ($OrderId -match '^(\d+)(.*)$') {
        return ('{0:D6}~{1}' -f [int]$Matches[1], $Matches[2])
    }
    return ('999999~{0}' -f $OrderId)
}

function ConvertTo-CellText {
    <# Collapse to a single markdown table cell: strip pipes/newlines, cap length. #>
    param([string]$Text, [int]$Max)
    if (-not $Text) { return '' }
    $out = $Text -replace '\|', '/'
    $out = $out -replace '\s+', ' '
    $out = $out.Trim()
    if ($out.Length -gt $Max) { $out = $out.Substring(0, $Max - 1).TrimEnd() + [char]0x2026 }
    return $out
}

function Build-Digest {
    $activeRows  = Get-OrderHeaders -Path $activePath  -Location 'ACTIVE'
    $archiveRows = Get-OrderHeaders -Path $archivePath -Location 'ARCHIVE'

    $all = New-Object System.Collections.Generic.List[object]
    $all.AddRange($activeRows)
    $all.AddRange($archiveRows)
    $sorted = $all | Sort-Object SortKey, Location, Line

    $activeCount  = $activeRows.Count
    $archiveCount = $archiveRows.Count

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('# TASKBOARD_DIGEST — ทุก order บรรทัดเดียว')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('> **GENERATED — read-only — ห้ามแก้มือ.** สร้างโดย `scripts/make_taskboard_digest.ps1`')
    [void]$sb.AppendLine('> จาก `AGENT_TASKBOARD.md` + `ARCHIVE_TASKBOARD_2026-07A.md` · `-Check` = เช็คว่า stale ไหม (read-only)')
    [void]$sb.AppendLine('>')
    [void]$sb.AppendLine('> ไฟล์นี้คือ**ชั้นที่มนุษย์อ่าน** — อยากได้รายละเอียดค่อยเปิดบอร์ดตามคอลัมน์ `อยู่ที่`.')
    [void]$sb.AppendLine('> (`docs/memory_control/ARCHIVE_INDEX.md` ชื่อคล้ายกันแต่คนละงาน — นั่นคือตาราง sha256 ของ validator)')
    [void]$sb.AppendLine('>')
    [void]$sb.AppendLine('> **`อยู่ที่` = ACTIVE** → ยังอยู่บน `AGENT_TASKBOARD.md` (ยังไม่ปิด หรือปิดแล้วแต่ยังไม่ได้ย้าย)')
    [void]$sb.AppendLine('> **`อยู่ที่` = ARCHIVE** → เนื้อเต็มอยู่ใน `ARCHIVE_TASKBOARD_2026-07A.md`')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine(('- order ทั้งหมด: **{0}** · ยังอยู่บนบอร์ด: **{1}** · เข้าคลังแล้ว: **{2}**' -f ($activeCount + $archiveCount), $activeCount, $archiveCount))
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| order | ปิดเมื่อ | สถานะ | เรื่อง | ผลลัพธ์ | อยู่ที่ |')
    [void]$sb.AppendLine('|---|---|---|---|---|---|')

    foreach ($row in $sorted) {
        [void]$sb.AppendLine(('| ORDER-{0} | {1} | {2} | {3} | {4} | {5}:{6} |' -f `
            $row.OrderId, $row.ClosedOn, $row.Verb, $row.Title, $row.Outcome, $row.Location, $row.Line))
    }

    return $sb.ToString()
}

try {
    $digest = Build-Digest
}
catch {
    Write-Host "[digest] TOOLING FAILURE: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}

if ($Check) {
    if (-not (Test-Path -LiteralPath $outPath)) {
        Write-Host "[digest] STALE: $OUT_REL does not exist -- run without -Check to generate it" -ForegroundColor Yellow
        exit 1
    }
    $onDisk = Get-Content -LiteralPath $outPath -Raw -Encoding UTF8
    # compare on canonical LF so a CRLF checkout does not read as drift
    $normDisk = $onDisk   -replace "`r`n", "`n"
    $normNew  = $digest   -replace "`r`n", "`n"
    if ($normDisk -eq $normNew) {
        Write-Host "[digest] OK -- $OUT_REL matches both taskboards" -ForegroundColor Green
        exit 0
    }
    Write-Host "[digest] STALE -- $OUT_REL does not match the taskboards; regenerate it" -ForegroundColor Yellow
    exit 1
}

Set-Content -LiteralPath $outPath -Value $digest -Encoding UTF8 -NoNewline
Write-Host "[digest] wrote $OUT_REL" -ForegroundColor Green
exit 0
