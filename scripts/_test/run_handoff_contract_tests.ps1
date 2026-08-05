<#
.SYNOPSIS
    Test cage for scripts/check_handoff_contract.ps1.

.DESCRIPTION
    Self-contained. Every fixture is written into the session scratchpad (never the
    repo) and removed in a finally block. The script under test is driven through its
    offline override parameters, so no git index is touched and the real repo state
    cannot influence a result.

    Fixtures are written to disk as UTF-8 (no BOM) and read back with -Encoding UTF8
    on purpose: that puts the Thai text through the same decode path a real handoff
    blob takes, so a mojibake regression shows up as a failed assertion rather than
    as ugly console output nobody reads.

    Deliberately ASCII-only source: Windows PowerShell 5.1 decodes a BOM-less .ps1 as
    ANSI, so the Thai / em-dash literals these fixtures need are built at runtime from
    code points and base64 instead of being typed inline.

    Prints "PASS n/n" and exits 0 when everything passes; exits 1 otherwise.
#>
param(
    [string]$Scratch = 'C:\Users\patip\AppData\Local\Temp\claude\D--EA-LAB\f75a76ed-5766-4016-a9ad-080d83c1984c\scratchpad'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Sut = Join-Path (Split-Path -Parent $ScriptDir) 'check_handoff_contract.ps1'
if (-not (Test-Path -LiteralPath $Sut)) { throw "script under test not found: $Sut" }

# --- runtime-built non-ASCII constants -------------------------------------
$EM    = [char]0x2014                                                                   # em-dash
$THAI  = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('4LiX4LiU4Liq4Lit4Lia4Lig4Liy4Lip4Liy4LmE4LiX4Lii'))   # "thai language test"
$THAI2 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('4LmE4Lih4LmI4LmE4LiU4LmJ4LiI4Lit4LiH'))               # "not reserved"

$FixtureDir = Join-Path $Scratch ('handoff_contract_fix_' + [guid]::NewGuid().ToString('N'))

$script:Pass = 0
$script:Fail = 0
$script:Total = 0

function Write-Fixture {
    <# Write UTF-8 (no BOM) then read it back with -Encoding UTF8, so the fixture
       round-trips through the same decode path a real blob would. #>
    param([string]$Name, [string]$Text)
    $p = Join-Path $FixtureDir $Name
    [IO.File]::WriteAllText($p, $Text, (New-Object System.Text.UTF8Encoding($false)))
    return (Get-Content -LiteralPath $p -Raw -Encoding UTF8)
}

function New-Handoff {
    <# A realistic handoff: a prose section, then the routing block, then a trailing
       '## ' section whose content must NOT be parsed as routing. #>
    param(
        [string[]]$RoutingLines,
        [switch]$NoMarker,
        [string[]]$TrailingLines = @()
    )
    $l = @()
    $l += ('# HANDOFF 2026-07-26 ' + $EM + ' ' + $THAI)
    $l += ''
    $l += '## what happened'
    $l += ($THAI + ' ORDER-999 ' + $THAI2)   # prose OUTSIDE the block: must be ignored
    $l += ''
    $l += '## routing'
    $l += ''
    if (-not $NoMarker) { $l += '<!-- HANDOFF-ROUTING -->' }
    $l += ''
    foreach ($r in $RoutingLines) { $l += $r }
    $l += ''
    foreach ($r in $TrailingLines) { $l += $r }
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
    # which would make a MustNotContain of 'BLOCK' match the word 'block'.
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
    Write-Host ("[handoff-contract-tests] fixtures: {0}" -f $FixtureDir)
    Write-Host ("[handoff-contract-tests] sut     : {0}" -f $Sut)

    # ------------------------------------------------------------------ boards
    $activeBoard = Write-Fixture 'active_board.md' (@(
        '# AGENT_TASKBOARD',
        '',
        ('## ORDER-230 ' + $EM + ' [ops] ' + $THAI + ' ' + $EM + ' `OPEN`'),
        'body',
        ('## ORDER-098-C ' + $EM + ' one of the two orders filed under this id'),
        'body',
        ('## ORDER-LANEC-FAN ' + $EM + ' non-numeric lane id'),
        'body'
    ) -join "`n")

    $archiveBoard = Write-Fixture 'archive_board.md' (@(
        '# ARCHIVE_TASKBOARD_2026-07A',
        '',
        ('## ORDER-051 ' + $EM + ' closed long ago ' + $THAI),
        'body',
        ('## REVIEW ORDER-051 ' + $EM + ' reviewed'),
        'body'
    ) -join "`r`n")

    $backlog = Write-Fixture 'backlog.md' (@(
        '# MASTER_BACKLOG',
        '',
        '## 9. deferred',
        '',
        ('| # | ' + $THAI + ' | wake-up | source |'),
        '|---|---|---|---|',
        ('| D1 | Boss_16 pair-liquidation check | attach/binary swap | ORDER-138 |'),
        ('| D7 | Exit_DynCloseTargetMoney into Kangaroo | after exit-owner review | ORDER-098-C |')
    ) -join "`r`n")

    # ------------------------------------------------------------------ handoffs
    $pathThai = '_triage/HANDOFF_2026-07-26_' + $THAI + '.md'

    $hfGood = Write-Fixture 'hf_good.md' (New-Handoff -RoutingLines @(
        ('| item | ' + $THAI + ' | destination |'),
        '|---|---|---|',
        ('| finish the fan-out | ' + $THAI + ' | `ORDER-230` |'),
        ('| archived follow-up | ' + $THAI2 + ' | ORDER-051 |'),
        ('| Kangaroo exit merge | ' + $THAI + ' | BACKLOG-D7 |'),
        ('| bundle sweep | ' + $THAI + ' | **DONE** |')
    ) -TrailingLines @(
        '## notes',
        ('ORDER-999 ' + $THAI + ' -- prose AFTER the block, must not be parsed'),
        '| tempting | table | ORDER-998 |'
    ))

    $hfNoMarker = Write-Fixture 'hf_nomarker.md' (New-Handoff -NoMarker -RoutingLines @(
        '| item | destination |',
        '|---|---|',
        '| finish the fan-out | ORDER-230 |'
    ))

    $hfNoTokens = Write-Fixture 'hf_notokens.md' (New-Handoff -RoutingLines @(
        ('| item | ' + $THAI + ' |'),
        '|---|---|',
        ('| ' + $THAI + ' | ' + $THAI2 + ' |'),
        ('| something else | later |')
    ))

    $hfBulletsOnly = Write-Fixture 'hf_bullets.md' (New-Handoff -RoutingLines @(
        ('- ' + $THAI + ' ORDER-230'),
        '- follow up on the fan-out later'
    ))

    $hfOrder999 = Write-Fixture 'hf_order999.md' (New-Handoff -RoutingLines @(
        '| item | destination |',
        '|---|---|',
        ('| ' + $THAI + ' | ORDER-999 |')
    ))

    $hfArchiveOnly = Write-Fixture 'hf_archiveonly.md' (New-Handoff -RoutingLines @(
        '| item | destination |',
        '|---|---|',
        ('| ' + $THAI + ' | ORDER-051 |')
    ))

    $hfBacklogD7 = Write-Fixture 'hf_backlog_d7.md' (New-Handoff -RoutingLines @(
        '| item | destination |',
        '|---|---|',
        ('| ' + $THAI + ' | BACKLOG-D7 |')
    ))

    $hfBacklogD99 = Write-Fixture 'hf_backlog_d99.md' (New-Handoff -RoutingLines @(
        '| item | destination |',
        '|---|---|',
        ('| ' + $THAI + ' | BACKLOG-D99 |')
    ))

    $hfDoneOnly = Write-Fixture 'hf_doneonly.md' (New-Handoff -RoutingLines @(
        '| item | destination |',
        '|---|---|',
        ('| ' + $THAI + ' | DONE |')
    ))

    $hfNonNumeric = Write-Fixture 'hf_nonnumeric.md' (New-Handoff -RoutingLines @(
        '| item | destination |',
        '|---|---|',
        ('| ' + $THAI + ' | ORDER-LANEC-FAN |')
    ))

    $hfSuffixId = Write-Fixture 'hf_suffix_id.md' (New-Handoff -RoutingLines @(
        '| item | destination |',
        '|---|---|',
        ('| ' + $THAI + ' | ORDER-098-C |')
    ))

    $hfBareId = Write-Fixture 'hf_bare_id.md' (New-Handoff -RoutingLines @(
        '| item | destination |',
        '|---|---|',
        ('| ' + $THAI + ' | ORDER-098 |')
    ))

    $hfProseInBlock = Write-Fixture 'hf_prose_in_block.md' (New-Handoff -RoutingLines @(
        ('' + $THAI + ' ORDER-997 ' + $THAI2 + ' -- prose inside the block, not a table row'),
        '',
        '| item | destination |',
        '|---|---|',
        ('| ' + $THAI + ' | ORDER-230 |')
    ))

    $hfTwoBad = Write-Fixture 'hf_two_bad.md' (New-Handoff -RoutingLines @(
        '| item | destination |',
        '|---|---|',
        ('| ' + $THAI + ' | ORDER-996 |'),
        ('| ' + $THAI2 + ' | BACKLOG-D98 |')
    ))

    # ------------------------------------------------------------------ cases

    Write-Host '[handoff-contract-tests] running'

    Test-Case -Name 'no handoff staged (unrelated files) -> pass, no-op' -ExpectCode 0 -Params @{
        StagedFileList = @("M`tREADME.md", "A`tscripts/foo.ps1", "M`t_triage/NOTES_something.md")
    } -MustContain @('no added/modified handoff staged -- pass (no-op)') -MustNotContain @('BLOCK')

    Test-Case -Name 'nothing staged at all (empty list) -> pass, no-op' -ExpectCode 0 -Params @{
        StagedFileList = @()
    } -MustContain @('pass (no-op)') -MustNotContain @('BLOCK')

    Test-Case -Name 'valid routing, every token resolves (Thai path + Thai cells) -> pass' -ExpectCode 0 -Params @{
        HandoffContentMap   = @{ $pathThai = $hfGood }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
        BacklogContent      = $backlog
    } -MustContain @(
        'PASS -- 1 handoff file(s) staged, 4 destination token(s), all resolved',
        ('routed: ' + $pathThai + ' -- 2 order, 1 backlog, 1 done')
    ) -MustNotContain @('BLOCK', 'ORDER-999', 'ORDER-998', '?')

    Test-Case -Name 'ADDED status also triggers (A, not just M)' -ExpectCode 0 -Params @{
        StagedFileList      = @("A`t" + $pathThai)
        HandoffContentMap   = @{ $pathThai = $hfGood }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
        BacklogContent      = $backlog
    } -MustContain @('PASS') -MustNotContain @('BLOCK')

    Test-Case -Name 'missing <!-- HANDOFF-ROUTING --> marker -> BLOCK' -ExpectCode 1 -Params @{
        HandoffContentMap   = @{ '_triage/HANDOFF_nomarker.md' = $hfNoMarker }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
    } -MustContain @('BLOCK', '_triage/HANDOFF_nomarker.md has no <!-- HANDOFF-ROUTING --> section', '1 handoff routing violation(s)')

    Test-Case -Name 'marker present, table rows carry no destination token -> BLOCK' -ExpectCode 1 -Params @{
        HandoffContentMap   = @{ '_triage/HANDOFF_notokens.md' = $hfNoTokens }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
    } -MustContain @('BLOCK', '_triage/HANDOFF_notokens.md has a <!-- HANDOFF-ROUTING --> section', 'no destination token')

    Test-Case -Name 'marker present, bullet list instead of a table -> BLOCK (zero tokens)' -ExpectCode 1 -Params @{
        HandoffContentMap   = @{ '_triage/HANDOFF_bullets.md' = $hfBulletsOnly }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
    } -MustContain @('BLOCK', 'no destination token')

    Test-Case -Name 'ORDER-999 on neither board -> BLOCK' -ExpectCode 1 -Params @{
        HandoffContentMap   = @{ '_triage/HANDOFF_999.md' = $hfOrder999 }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
    } -MustContain @('BLOCK', 'routes to ORDER-999 but no "## ORDER-999" header exists in AGENT_TASKBOARD.md or ARCHIVE_TASKBOARD_2026-07A.md')

    Test-Case -Name 'order that resolves ONLY in the archive (ORDER-051) -> pass' -ExpectCode 0 -Params @{
        HandoffContentMap   = @{ '_triage/HANDOFF_arch.md' = $hfArchiveOnly }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
    } -MustContain @('PASS', '1 destination token(s)') -MustNotContain @('BLOCK')

    Test-Case -Name 'order that resolves in NEITHER because the archive is absent -> BLOCK' -ExpectCode 1 -Params @{
        HandoffContentMap   = @{ '_triage/HANDOFF_arch.md' = $hfArchiveOnly }
        ActiveBoardContent  = $activeBoard
    } -MustContain @('BLOCK', 'routes to ORDER-051')

    Test-Case -Name 'BACKLOG-D7 has a row in MASTER_BACKLOG.md -> pass' -ExpectCode 0 -Params @{
        HandoffContentMap   = @{ '_triage/HANDOFF_d7.md' = $hfBacklogD7 }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
        BacklogContent      = $backlog
    } -MustContain @('PASS', '0 order, 1 backlog, 0 done') -MustNotContain @('BLOCK')

    Test-Case -Name 'BACKLOG-D99 has no row -> BLOCK' -ExpectCode 1 -Params @{
        HandoffContentMap   = @{ '_triage/HANDOFF_d99.md' = $hfBacklogD99 }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
        BacklogContent      = $backlog
    } -MustContain @('BLOCK', 'routes to BACKLOG-D99 but no "| D99 |" row exists in MASTER_BACKLOG.md')

    Test-Case -Name 'bare DONE needs no board at all -> pass' -ExpectCode 0 -Params @{
        HandoffContentMap = @{ '_triage/HANDOFF_done.md' = $hfDoneOnly }
    } -MustContain @('PASS', '0 order, 0 backlog, 1 done') -MustNotContain @('BLOCK')

    Test-Case -Name 'non-numeric ORDER-LANEC-FAN resolves -> pass' -ExpectCode 0 -Params @{
        HandoffContentMap   = @{ '_triage/HANDOFF_lanec.md' = $hfNonNumeric }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
    } -MustContain @('PASS', '1 order, 0 backlog, 0 done') -MustNotContain @('BLOCK')

    Test-Case -Name 'suffixed id ORDER-098-C resolves against its own header -> pass' -ExpectCode 0 -Params @{
        HandoffContentMap   = @{ '_triage/HANDOFF_098c.md' = $hfSuffixId }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
    } -MustContain @('PASS') -MustNotContain @('BLOCK')

    Test-Case -Name 'bare ORDER-098 is NOT satisfied by the ORDER-098-C header -> BLOCK' -ExpectCode 1 -Params @{
        HandoffContentMap   = @{ '_triage/HANDOFF_098.md' = $hfBareId }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
    } -MustContain @('BLOCK', 'routes to ORDER-098 but no "## ORDER-098" header')

    Test-Case -Name 'token after the block-ending "## " heading is ignored -> pass' -ExpectCode 0 -Params @{
        HandoffContentMap   = @{ $pathThai = $hfGood }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
        BacklogContent      = $backlog
    } -MustContain @('PASS') -MustNotContain @('ORDER-998', 'ORDER-999')

    Test-Case -Name 'prose token INSIDE the block is ignored, the table row is honoured -> pass' -ExpectCode 0 -Params @{
        HandoffContentMap   = @{ '_triage/HANDOFF_prose.md' = $hfProseInBlock }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
    } -MustContain @('PASS', '1 order, 0 backlog, 0 done') -MustNotContain @('BLOCK', 'ORDER-997')

    Test-Case -Name 'SESSION_HANDOFF*.md triggers too' -ExpectCode 1 -Params @{
        HandoffContentMap   = @{ '_triage/SESSION_HANDOFF_2026-07-26.md' = $hfNoMarker }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
    } -MustContain @('BLOCK', '_triage/SESSION_HANDOFF_2026-07-26.md has no')

    Test-Case -Name 'handoff under _triage/_archive/ -> ignored, pass' -ExpectCode 0 -Params @{
        StagedFileList      = @("M`t_triage/_archive/handoffs_closed/HANDOFF_2026-07-24C.md")
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
    } -MustContain @('pass (no-op)') -MustNotContain @('BLOCK')

    Test-Case -Name 'DELETED handoff -> ignored, pass' -ExpectCode 0 -Params @{
        StagedFileList      = @("D`t_triage/HANDOFF_2026-07-25C_EVIDENCE_INTEGRITY_SWEEP.md")
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
    } -MustContain @('pass (no-op)') -MustNotContain @('BLOCK')

    Test-Case -Name 'RENAME into the archive (the real archival move) -> ignored, pass' -ExpectCode 0 -Params @{
        StagedFileList      = @("R100`t_triage/HANDOFF_old.md`t_triage/_archive/handoffs_closed/HANDOFF_old.md")
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
    } -MustContain @('pass (no-op)') -MustNotContain @('BLOCK')

    Test-Case -Name 'two unresolved tokens in one handoff -> both named, exit 1' -ExpectCode 1 -Params @{
        HandoffContentMap   = @{ '_triage/HANDOFF_twobad.md' = $hfTwoBad }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
        BacklogContent      = $backlog
    } -MustContain @('routes to ORDER-996', 'routes to BACKLOG-D98', '2 handoff routing violation(s)')

    Test-Case -Name 'good handoff + bad handoff in one commit -> only the bad one is named' -ExpectCode 1 -Params @{
        # parenthesised on purpose: ',' binds tighter than '+', so @("M<tab>" + $p, "x")
        # would concatenate the whole array into ONE string instead of listing two paths
        StagedFileList      = @(("M`t" + $pathThai), "A`t_triage/HANDOFF_999.md")
        HandoffContentMap   = @{ $pathThai = $hfGood; '_triage/HANDOFF_999.md' = $hfOrder999 }
        ActiveBoardContent  = $activeBoard
        ArchiveBoardContent = $archiveBoard
        BacklogContent      = $backlog
    } -MustContain @(
        ('routed: ' + $pathThai),
        'BLOCK: _triage/HANDOFF_999.md',
        '1 handoff routing violation(s)'
    ) -MustNotContain @('BLOCK: ' + $pathThai)

    Test-Case -Name 'staged handoff whose blob cannot be read -> exit 2 tooling' -ExpectCode 2 -Params @{
        StagedFileList      = @("M`t_triage/HANDOFF_ghost.md")
        HandoffContentMap   = @{ '_triage/HANDOFF_other.md' = $hfDoneOnly }
        ActiveBoardContent  = $activeBoard
    } -MustContain @('TOOLING', 'cannot read the staged blob for _triage/HANDOFF_ghost.md') -MustNotContain @('BLOCK')

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
