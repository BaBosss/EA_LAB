<#
.SYNOPSIS
    Test cage for scripts/check_order_collision.ps1.

.DESCRIPTION
    Self-contained. Every fixture is written into the session scratchpad (never the
    repo) and removed in a finally block. The script under test is driven through its
    offline override parameters, so no git index is touched and the real repo state
    cannot influence a result.

    Deliberately ASCII-only source: Windows PowerShell 5.1 decodes a BOM-less .ps1 as
    ANSI, so the Thai/em-dash literals that these fixtures need are built at runtime
    from code points / base64 instead of being typed inline.

    Prints "PASS n/n" and exits 0 when everything passes; exits 1 otherwise.
#>
param(
    [string]$Scratch = 'C:\Users\patip\AppData\Local\Temp\claude\D--EA-LAB\f75a76ed-5766-4016-a9ad-080d83c1984c\scratchpad'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Sut = Join-Path (Split-Path -Parent $ScriptDir) 'check_order_collision.ps1'
if (-not (Test-Path -LiteralPath $Sut)) { throw "script under test not found: $Sut" }

# --- runtime-built non-ASCII constants -------------------------------------
$EM    = [char]0x2014                                                                   # em-dash
$MID   = [char]0x00B7                                                                   # middle dot (the real ledger's owns-paths separator)
$THAI  = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('4LiX4LiU4Liq4Lit4Lia4Lig4Liy4Lip4Liy4LmE4LiX4Lii'))   # "thai language test"
$THAI2 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('4LmE4Lih4LmI4LmE4LiU4LmJ4LiI4Lit4LiH'))               # "not reserved"

$FixtureDir = Join-Path $Scratch ('order_collision_fix_' + [guid]::NewGuid().ToString('N'))

$script:Pass = 0
$script:Fail = 0
$script:Total = 0

function Write-Fixture {
    <# Write UTF-8 (no BOM) then read it back with -Encoding UTF8, so the fixture
       round-trips through the same decode path a real file would. #>
    param([string]$Name, [string]$Text)
    $p = Join-Path $FixtureDir $Name
    [IO.File]::WriteAllText($p, $Text, (New-Object System.Text.UTF8Encoding($false)))
    return (Get-Content -LiteralPath $p -Raw -Encoding UTF8)
}

function New-Ledger {
    param([string[]]$LaneRows)
    $l = @()
    $l += '# SESSION_LEDGER'
    $l += ''
    $l += '## open lanes'
    $l += ''
    $l += '| session id | start | order block | owns paths | mt5 lane | status |'
    $l += '|---|---|---|---|---|---|'
    foreach ($r in $LaneRows) { $l += $r }
    $l += ''
    $l += '## closed history'
    $l += ''
    $l += '| session id | span | order block | summary |'
    $l += '|---|---|---|---|'
    $l += ('| `S-OLD` | 2026-07-01 | 100-109 | ' + $THAI + ' |')
    return ($l -join "`r`n")
}

function Invoke-Sut {
    param([hashtable]$Params)
    $global:LASTEXITCODE = 0
    $out = ''
    try {
        # ToString() per record, NOT Out-String: Out-String hard-wraps at the console
        # width and would split the very lines these assertions match on.
        $out = ((& $Sut @Params 6>&1 | ForEach-Object { $_.ToString() }) -join "`n")
    } catch {
        return [pscustomobject]@{ Code = -1; Out = ('THREW: ' + $_.Exception.Message) }
    }
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = $out }
}

function Test-Case {
    param(
        [string]$Name,
        [int]$ExpectCode,
        [hashtable]$Params,
        [string[]]$MustContain = @(),
        [string[]]$MustNotContain = @()
    )
    $script:Total++
    $r = Invoke-Sut -Params $Params
    $problems = New-Object System.Collections.Generic.List[string]
    if ($r.Code -ne $ExpectCode) { $problems.Add("exit $($r.Code), expected $ExpectCode") }
    # String.Contains = ordinal + CASE-SENSITIVE. PowerShell's -like is case-INsensitive,
    # which would make a MustNotContain of 'BLOCK' match the word 'reserved-block'.
    foreach ($m in $MustContain) {
        if (-not $r.Out.Contains($m)) { $problems.Add("output missing: $m") }
    }
    foreach ($m in $MustNotContain) {
        if ($r.Out.Contains($m)) { $problems.Add("output should not contain: $m") }
    }
    if ($problems.Count -eq 0) {
        $script:Pass++
        Write-Host ("  ok   {0}" -f $Name)
    } else {
        $script:Fail++
        Write-Host ("  FAIL {0}" -f $Name)
        foreach ($p in $problems) { Write-Host ("         - {0}" -f $p) }
        foreach ($line in ($r.Out -split "`r?`n")) { if ($line.Trim()) { Write-Host ("         | {0}" -f $line) } }
    }
}

New-Item -ItemType Directory -Force -Path $FixtureDir | Out-Null
try {
    Write-Host ("[order-collision-tests] fixtures: {0}" -f $FixtureDir)
    Write-Host ("[order-collision-tests] sut     : {0}" -f $Sut)

    # ------------------------------------------------------------------ fixtures
    $activeClean = Write-Fixture 'active_clean.md' (@(
        '# AGENT_TASKBOARD',
        '',
        ('## ORDER-230 ' + $EM + ' [ops] ' + $THAI + ' ' + $EM + ' `OPEN`'),
        'body',
        ('## ORDER-GEN-STANDING ' + $EM + ' standing order ' + $EM + ' `OPEN-STANDING`'),
        'body'
    ) -join "`r`n")

    # duplicate 231, written with an em-dash immediately after the id (no space) and a
    # Thai title -- proves both the id-terminator and the UTF-8 path.
    $activeDup = Write-Fixture 'active_dup.md' (@(
        '# AGENT_TASKBOARD',
        '',
        ('## ORDER-231' + $EM + $THAI + ' first'),
        'body',
        ('## ORDER-231 ' + $EM + ' second, unrelated'),
        'body'
    ) -join "`r`n")

    $activeCrossArchive = Write-Fixture 'active_cross.md' (@(
        '# AGENT_TASKBOARD',
        '',
        ('## ORDER-230 ' + $EM + ' fine'),
        ('## ORDER-051 ' + $EM + ' this number was archived long ago')
    ) -join "`r`n")

    # 200 / 082 are on the grandfather allowlist
    $activeGrandDup = Write-Fixture 'active_grand_dup.md' (@(
        '# AGENT_TASKBOARD',
        ('## ORDER-200 ' + $EM + ' macro tooling'),
        ('## ORDER-200 (history Phase A/B) ' + $EM + ' reused header'),
        ('## ORDER-098-C ' + $EM + ' one'),
        ('## ORDER-098-C ' + $EM + ' another, unrelated')
    ) -join "`r`n")

    $activeGrandCross = Write-Fixture 'active_grand_cross.md' (@(
        '# AGENT_TASKBOARD',
        ('## ORDER-082 ' + $EM + ' still open here')
    ) -join "`r`n")

    $activeNewInside = Write-Fixture 'active_new_inside.md' (@(
        '# AGENT_TASKBOARD',
        ('## ORDER-100 ' + $EM + ' pre-existing, far outside any block'),
        ('## ORDER-231 ' + $EM + ' brand new, inside 230-239')
    ) -join "`r`n")

    $activeNewOutside = Write-Fixture 'active_new_outside.md' (@(
        '# AGENT_TASKBOARD',
        ('## ORDER-100 ' + $EM + ' pre-existing, far outside any block'),
        ('## ORDER-245 ' + $EM + ' brand new, NOT inside 230-239')
    ) -join "`r`n")

    $activeNewNonNumeric = Write-Fixture 'active_new_nonnum.md' (@(
        '# AGENT_TASKBOARD',
        ('## ORDER-100 ' + $EM + ' pre-existing'),
        ('## ORDER-LANEC-FAN ' + $EM + ' brand new, no number consumed')
    ) -join "`r`n")

    $headActive100 = Write-Fixture 'head_active_100.md' (@(
        '# AGENT_TASKBOARD',
        ('## ORDER-100 ' + $EM + ' pre-existing, far outside any block')
    ) -join "`r`n")

    # archive holds 051, plus an archive-INTERNAL duplicate (071 twice) that this
    # guard must ignore -- the archive is append-only history, not our business.
    $archive = Write-Fixture 'archive.md' (@(
        '# ARCHIVE',
        ('## ORDER-051 ' + $EM + ' archived'),
        ('## ORDER-071 ' + $EM + ' archived once'),
        ('## ORDER-071 ' + $EM + ' archived twice (pre-existing archive defect)'),
        ('## ORDER-082 ' + $EM + ' archived')
    ) -join "`r`n")

    $sessionThai = 'S-2026-07-26-' + $THAI
    $ledgerActive = Write-Fixture 'ledger_active.md' (New-Ledger @(
        ('| `' + $sessionThai + '` | 2026-07-26 13:00 | **230-239** | `docs/SESSION_LEDGER.md` ' + $MID + ' `_mt5_auto/**` ' + $MID + ' `scripts/check_order_collision.ps1` | ' + $THAI + ' | `ACTIVE` |'),
        ('| `S-OTHER` | 2026-07-20 | 210-219 | `portfolio/**` | - | `CLOSED` |')
    ))

    $ledgerNoActive = Write-Fixture 'ledger_noactive.md' (New-Ledger @(
        ('| `S-A` | 2026-07-26 | **230-239** | `_mt5_auto/**` | - | `CLOSED` |'),
        ('| `S-B` | 2026-07-25 | 210-219 | `portfolio/**` | - | `ABANDONED` |')
    ))

    $ledgerActiveNoBlock = Write-Fixture 'ledger_active_noblock.md' (New-Ledger @(
        ('| `S-GENSTANDING` | 2026-07-26 | (' + $THAI2 + ') | `_mt5_auto/**` | - | `ACTIVE` |')
    ))

    # ---- ORDER-675: a range token must be a RANGE, not any two numbers with a dash ----
    # Found by using this guard: a real lane row cited `ARCHIVE_TASKBOARD_2026-07A.md` in its
    # order-block cell. The cell scan matched "2026-07", the low>high swap turned it into
    # 7-2026, and that ONE range contains every order number this repo will ever issue -- so
    # the reserved-block rule passed ORDER-999 while reporting PASS.
    $ledgerActiveFilename = Write-Fixture 'ledger_active_filename.md' (New-Ledger @(
        ('| `S-FNAME` | 2026-07-31 | **230-239** ' + $MID + ' parsed out of `ARCHIVE_TASKBOARD_2026-07A.md` before reserving | `_mt5_auto/**` | - | `ACTIVE` |')
    ))

    # Same defect through a plain date rather than a filename.
    $ledgerActiveDate = Write-Fixture 'ledger_active_date.md' (New-Ledger @(
        ('| `S-DATE` | 2026-07-31 | **230-239** ' + $MID + ' re-derived 2026-07-31 by parsing both boards | `_mt5_auto/**` | - | `ACTIVE` |')
    ))

    # A descending pair is not a range. Swapping it invents a declaration nobody wrote.
    $ledgerActiveDescending = Write-Fixture 'ledger_active_desc.md' (New-Ledger @(
        ('| `S-DESC` | 2026-07-31 | **239-230** | `_mt5_auto/**` | - | `ACTIVE` |')
    ))

    # ENGAGEMENT: two real blocks in one cell must BOTH still be enforced after the fix.
    $ledgerActiveTwoBlocks = Write-Fixture 'ledger_active_two.md' (New-Ledger @(
        ('| `S-TWO` | 2026-07-31 | **610-619** + **660-669** | `_mt5_auto/**` | - | `ACTIVE` |')
    ))

    $activeNew999 = Write-Fixture 'active_new_999.md' (@(
        '# AGENT_TASKBOARD',
        ('## ORDER-100 ' + $EM + ' pre-existing, far outside any block'),
        ('## ORDER-999 ' + $EM + ' brand new, outside anything anyone reserved')
    ) -join "`r`n")

    $activeNew665 = Write-Fixture 'active_new_665.md' (@(
        '# AGENT_TASKBOARD',
        ('## ORDER-100 ' + $EM + ' pre-existing'),
        ('## ORDER-665 ' + $EM + ' brand new, inside the SECOND declared block')
    ) -join "`r`n")

    $activeNew635 = Write-Fixture 'active_new_635.md' (@(
        '# AGENT_TASKBOARD',
        ('## ORDER-100 ' + $EM + ' pre-existing'),
        ('## ORDER-635 ' + $EM + ' brand new, BETWEEN the two declared blocks')
    ) -join "`r`n")

    $ledgerNoTable = Write-Fixture 'ledger_notable.md' (@(
        '# SESSION_LEDGER',
        '',
        'the lane table was deleted by mistake'
    ) -join "`r`n")

    $ledgerNoStatusCol = Write-Fixture 'ledger_nostatus.md' (@(
        '# SESSION_LEDGER',
        '',
        '| session id | order block | owns paths |',
        '|---|---|---|',
        '| `S-A` | 230-239 | `_mt5_auto/**` |'
    ) -join "`r`n")

    # ------------------------------------------------------------------ cases

    Write-Host '[order-collision-tests] running'

    Test-Case -Name 'nothing staged (unrelated file) -> pass, no-op' -ExpectCode 0 -Params @{
        StagedFileList = @('README.md', 'scripts/foo.ps1')
    } -MustContain @('not staged -- pass') -MustNotContain @('BLOCK')

    Test-Case -Name 'nothing staged at all (empty list) -> pass, no-op' -ExpectCode 0 -Params @{
        StagedFileList = @()
    } -MustContain @('not staged -- pass')

    Test-Case -Name 'clean board, no ledger -> pass' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeClean
        ArchiveContent      = $archive
    } -MustContain @('PASS', 'not found in HEAD') -MustNotContain @('BLOCK')

    Test-Case -Name 'RULE1 duplicate id inside active board (em-dash + Thai title) -> BLOCK' -ExpectCode 1 -Params @{
        StagedActiveContent = $activeDup
        ArchiveContent      = $archive
    } -MustContain @('BLOCK', 'duplicate order id ORDER-231', '2 headers')

    Test-Case -Name 'RULE1 id present in BOTH active and archive -> BLOCK' -ExpectCode 1 -Params @{
        StagedActiveContent = $activeCrossArchive
        ArchiveContent      = $archive
    } -MustContain @('BLOCK', 'ORDER-051 exists in BOTH')

    Test-Case -Name 'RULE1 grandfathered duplicate (200, 098-C) -> pass with NOTE' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeGrandDup
        ArchiveContent      = $archive
    } -MustContain @('PASS', 'grandfathered duplicate id ORDER-200', 'grandfathered duplicate id ORDER-098-C') -MustNotContain @('BLOCK')

    Test-Case -Name 'RULE1 grandfathered cross-board id (082) -> pass with NOTE' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeGrandCross
        ArchiveContent      = $archive
    } -MustContain @('PASS', 'grandfathered id ORDER-082 exists in both boards') -MustNotContain @('BLOCK')

    Test-Case -Name 'RULE1 archive-internal duplicate (071 twice) is not our business -> pass' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeClean
        ArchiveContent      = $archive
    } -MustContain @('PASS') -MustNotContain @('ORDER-071')

    Test-Case -Name 'RULE2 new order INSIDE reserved block (231 in 230-239) -> pass' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeNewInside
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerActive
    } -MustContain @('PASS') -MustNotContain @('BLOCK')

    Test-Case -Name 'RULE2 new order OUTSIDE reserved block (245 vs 230-239) -> BLOCK' -ExpectCode 1 -Params @{
        StagedActiveContent = $activeNewOutside
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerActive
    } -MustContain @('BLOCK', 'ORDER-245 is outside every ACTIVE reserved block (230-239)')

    Test-Case -Name 'RULE2 pre-existing out-of-block id (100, already in HEAD) is not flagged' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeNewInside
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerActive
    } -MustNotContain @('ORDER-100 is outside')

    Test-Case -Name 'RULE2 new NON-NUMERIC id outside any block (LANEC-FAN) -> pass, exempt' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeNewNonNumeric
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerActive
    } -MustContain @('PASS', 'ORDER-LANEC-FAN is exempt') -MustNotContain @('BLOCK')

    Test-Case -Name 'RULE2 no ACTIVE row in ledger -> pass with NOTE, rule skipped' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeNewOutside
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerNoActive
    } -MustContain @('PASS', 'no ACTIVE lane in docs/SESSION_LEDGER.md (2 row(s) parsed)') -MustNotContain @('BLOCK')

    Test-Case -Name 'RULE2 ACTIVE row with no parseable block -> pass with NOTE, rule skipped' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeNewOutside
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerActiveNoBlock
    } -MustContain @('PASS', 'declares a parseable order block') -MustNotContain @('BLOCK')

    # ---- ORDER-675 ----------------------------------------------------------------
    # ATTACK. A filename in the block cell must not become a range. Before the fix the
    # cell scan read "2026-07" out of ARCHIVE_TASKBOARD_2026-07A.md, swapped it to
    # 7-2026, and that range contains every id -- so this case PASSED and said so.
    Test-Case -Name 'RULE2/675 ATTACK filename 2026-07A in block cell must not become a range -> BLOCK' -ExpectCode 1 -Params @{
        StagedActiveContent = $activeNewOutside
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerActiveFilename
    } -MustContain @('BLOCK', 'ORDER-245 is outside every ACTIVE reserved block (230-239)')

    Test-Case -Name 'RULE2/675 ATTACK a date in the block cell must not become a range -> BLOCK (999)' -ExpectCode 1 -Params @{
        StagedActiveContent = $activeNew999
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerActiveDate
    } -MustContain @('BLOCK', 'ORDER-999 is outside every ACTIVE reserved block (230-239)')

    # ENGAGEMENT. The fix must not achieve its result by parsing nothing: the real block
    # in the very same cell still has to be found and still has to permit its own ids.
    Test-Case -Name 'RULE2/675 ENGAGEMENT the real block in that same cell still parses -> 231 passes' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeNewInside
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerActiveFilename
    } -MustContain @('PASS', 'enforcing reserved block(s): 230-239') -MustNotContain @('BLOCK')

    Test-Case -Name 'RULE2/675 ENGAGEMENT two declared blocks are BOTH enforced -> 665 passes' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeNew665
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerActiveTwoBlocks
    } -MustContain @('PASS', 'enforcing reserved block(s): 610-619, 660-669') -MustNotContain @('BLOCK')

    Test-Case -Name 'RULE2/675 SPECIFICITY the gap between two blocks is still outside -> 635 BLOCKs' -ExpectCode 1 -Params @{
        StagedActiveContent = $activeNew635
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerActiveTwoBlocks
    } -MustContain @('BLOCK', 'ORDER-635 is outside every ACTIVE reserved block (610-619, 660-669)')

    # A descending pair is not a range. Swapping it invents a declaration nobody wrote --
    # and the swap is what made the filename defect fatal rather than merely wrong.
    Test-Case -Name 'RULE2/675 descending pair is reported, not silently swapped' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeNewOutside
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerActiveDescending
    } -MustContain @('PASS', 'ignored malformed order-block token 239-230', 'declares a parseable order block') -MustNotContain @('BLOCK')

    Test-Case -Name 'RULE2 ledger absent entirely -> pass with NOTE' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeNewOutside
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
    } -MustContain @('PASS', 'docs/SESSION_LEDGER.md not found in HEAD') -MustNotContain @('BLOCK')

    Test-Case -Name 'RULE3 owned glob path warns, exit code unchanged (Thai session id round-trips)' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeNewInside
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerActive
        StagedFileList      = @('AGENT_TASKBOARD.md', '_mt5_auto/deep/nested/run.csv', 'scripts/check_order_collision.ps1', 'docs/UNOWNED.md')
    } -MustContain @('PASS', ('WARN: staged path _mt5_auto/deep/nested/run.csv is declared by ACTIVE session ' + $sessionThai), 'WARN: staged path scripts/check_order_collision.ps1') -MustNotContain @('BLOCK', 'docs/UNOWNED.md is declared')

    Test-Case -Name 'RULE3 warn never masks a RULE2 block (both fire, exit 1)' -ExpectCode 1 -Params @{
        StagedActiveContent = $activeNewOutside
        HeadActiveContent   = $headActive100
        ArchiveContent      = ''
        LedgerContent       = $ledgerActive
        StagedFileList      = @('AGENT_TASKBOARD.md', '_mt5_auto/run.csv')
    } -MustContain @('WARN: staged path _mt5_auto/run.csv', 'BLOCK', 'ORDER-245 is outside')

    # -----------------------------------------------------------------------------------------
    # RULE 4 (ORDER-760) -- a lane row must have the header's width.
    #
    # The defect, twice on 2026-08-01 and once before that: a cell is free PROSE and the guard's
    # INPUT at the same time. A literal '|' shifts every column after it, the status is read from
    # the wrong cell, and the guard prints "no ACTIVE lane ... rules skipped" and PASSES. Two
    # commits were made with RULE 2 and RULE 3 unarmed. These cases exist so that the next time it
    # happens, something other than a human probing the guard notices.
    $ledgerRawPipe = Write-Fixture 'ledger_rawpipe.md' (New-Ledger @(
        ('| `S-PIPE` | 2026-08-01 | **230-239** | `docs/SESSION_LEDGER.md` | - | `ACTIVE`, and this cell has a raw | in it |')
    ))
    $ledgerEscapedPipe = Write-Fixture 'ledger_escpipe.md' (New-Ledger @(
        ('| `S-ESC` | 2026-08-01 | **230-239** | `docs/SESSION_LEDGER.md` | - | `ACTIVE`, and this cell writes a literal \| the correct way |')
    ))
    $ledgerShortRow = Write-Fixture 'ledger_shortrow.md' (New-Ledger @(
        ('| `S-SHORT` | 2026-08-01 | **230-239** | `docs/**` |')
    ))

    Test-Case -Name 'RULE 4 ATTACK a raw | in a lane cell BLOCKS instead of silently disarming RULE 2' -ExpectCode 1 -Params @{
        StagedActiveContent = $activeClean
        ArchiveContent      = ''
        LedgerContent       = $ledgerRawPipe
    } -MustContain @('BLOCK', 'S-PIPE', 'cells', 'header has')

    # SPECIFICITY, and it is C3 of the order: '\|' is how markdown writes a literal pipe. A rule
    # that fired on the CORRECT spelling would ban the only correct spelling -- and this is not
    # hypothetical: S-2026-08-01-CODEXBRIEF had already written '\|' properly and the old splitter
    # was breaking on it, which is why the escape half shipped with the count half.
    Test-Case -Name 'RULE 4 SPECIFICITY an ESCAPED \| is a literal pipe, not a column break' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeClean
        ArchiveContent      = ''
        LedgerContent       = $ledgerEscapedPipe
    } -MustContain @('enforcing reserved block(s): 230-239')

    # A row too SHORT loses its status column entirely. That branch used to `continue` in silence,
    # so the row vanished from the parse while the table still reported plenty of rows.
    Test-Case -Name 'RULE 4 ATTACK a row too short to have a status column is refused, not dropped' -ExpectCode 1 -Params @{
        StagedActiveContent = $activeClean
        ArchiveContent      = ''
        LedgerContent       = $ledgerShortRow
    } -MustContain @('BLOCK', 'S-SHORT')

    # CONTROL, and it is the case that ORDER-731 taught this repo to write. RULE 4 first read the
    # ledger from HEAD like RULE 2 does -- and immediately refused the very commit that REPAIRED
    # the malformed row, because HEAD still held it. A gate that blocks its own repair is exactly
    # the defect ORDER-731 exists for, recreated inside the fix for a different one (shape 5).
    # RULE 4 therefore judges the STAGED ledger; RULE 2 and RULE 3 keep their ratified HEAD read.
    Test-Case -Name 'RULE 4 CONTROL a commit that REPAIRS a malformed row is allowed to land' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeClean
        ArchiveContent      = ''
        LedgerContent       = $ledgerRawPipe      # HEAD still holds the bad row
        StagedLedgerContent = $ledgerActive       # ...and this commit fixes it
    } -MustContain @('enforcing reserved block(s)') -MustNotContain @('BLOCK:')

    # ...and the mirror image, which is the whole point of moving the snapshot: a commit that
    # INTRODUCES a malformed row is refused BEFORE it lands, not after.
    Test-Case -Name 'RULE 4 ATTACK a commit that INTRODUCES a malformed row is refused before it lands' -ExpectCode 1 -Params @{
        StagedActiveContent = $activeClean
        ArchiveContent      = ''
        LedgerContent       = $ledgerActive       # HEAD is clean
        StagedLedgerContent = $ledgerRawPipe      # ...and this commit breaks it
    } -MustContain @('BLOCK', 'S-PIPE')

    # ENGAGEMENT: the well-formed fixtures every other case in this file uses must still pass, or
    # RULE 4 is over-reaching and the greens above mean nothing.
    Test-Case -Name 'RULE 4 ENGAGEMENT the ordinary well-formed ledger is unaffected' -ExpectCode 0 -Params @{
        StagedActiveContent = $activeClean
        ArchiveContent      = ''
        LedgerContent       = $ledgerActive
    } -MustContain @('enforcing reserved block(s)')

    Test-Case -Name 'ledger present but has no table at all -> exit 2 tooling' -ExpectCode 2 -Params @{
        StagedActiveContent = $activeClean
        ArchiveContent      = ''
        LedgerContent       = $ledgerNoTable
    } -MustContain @('TOOLING', 'contains no markdown table')

    Test-Case -Name 'ledger present but lane table has no status column -> exit 2 tooling' -ExpectCode 2 -Params @{
        StagedActiveContent = $activeClean
        ArchiveContent      = ''
        LedgerContent       = $ledgerNoStatusCol
    } -MustContain @('TOOLING', 'no lane table')

    Write-Host ''
    if ($script:Fail -eq 0) {
        Write-Host ("PASS {0}/{1}" -f $script:Pass, $script:Total)
    } else {
        Write-Host ("FAIL {0}/{1} passed, {2} failed" -f $script:Pass, $script:Total, $script:Fail)
    }
} finally {
    Remove-Item -LiteralPath $FixtureDir -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:Fail -ne 0) { exit 1 }
exit 0
