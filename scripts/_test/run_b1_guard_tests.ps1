# Cage for the B1_DATASET.csv guard rules -- ORDER-500.
#
# Tests scripts/lib/b1_guard.ps1 DIRECTLY, which is the same file
# scripts/check_precommit_staged.ps1 and .githooks/commit-msg call. There is no
# synthetic copy of the rules here, deliberately: ORDER-421 found the ORDER-105 cage
# had been running at 14% of itself because its fixture copied the real hook without
# tracking the hook's dependency list. A cage that shares the implementation with the
# thing it protects cannot drift away from it.
#
# Every case is pre-registered in BOTH directions -- must-block AND must-stay-silent.
# A guard that only ever gets shown its trigger is a guard nobody has proven is
# specific (memory `gate-specificity-not-just-sensitivity`).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $repoRoot 'scripts\lib\b1_guard.ps1')

$script:pass = 0
$script:fail = 0
$script:failed = New-Object System.Collections.Generic.List[string]

function Assert-Case {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        $script:pass++
        Write-Host ("  [PASS] {0}" -f $Name)
    } else {
        $script:fail++
        $script:failed.Add($Name)
        Write-Host ("  [FAIL] {0}{1}" -f $Name, $(if ($Detail) { " -- $Detail" } else { '' }))
    }
}

function ToBytes { param([string]$s) return [System.Text.Encoding]::UTF8.GetBytes($s) }

$HEADER = 'order_id,close_date,status_at_cutoff,cutoff_blob_line,evidence_commit,class,outcome,onboarding_time,context_incident,context_rework,wrong_order_file_scope,lead_attention_hours,notes'
function Row { param([string]$Id, [string]$Notes = 'plain note')
    return ('{0},2026-07-28,REVIEWED,same-file,PENDING,TOOLING,closed,1,0,0,0,0.5,"{1}"' -f $Id, $Notes)
}

Write-Host '=== B1 guard cage (ORDER-500) ==='

# ---------------------------------------------------------------- RULE 1: append-only
Write-Host "`n-- Test-B1AppendOnly (ORDER-144 default, unchanged) --"

$head = ToBytes ($HEADER + "`n" + (Row 'ORDER-001') + "`n")
$appended = ToBytes ($HEADER + "`n" + (Row 'ORDER-001') + "`n" + (Row 'ORDER-002') + "`n")
$mutated = ToBytes ($HEADER + "`n" + (Row 'ORDER-001' 'EDITED') + "`n")
$truncated = ToBytes ($HEADER + "`n")

Assert-Case 'pure append is allowed' `
    ($null -eq (Test-B1AppendOnly -HeadBytes $head -StagedBytes $appended))

Assert-Case 'modifying an existing HEAD byte is BLOCKED' `
    ($null -ne (Test-B1AppendOnly -HeadBytes $head -StagedBytes $mutated))

Assert-Case 'truncating the file is BLOCKED' `
    ($null -ne (Test-B1AppendOnly -HeadBytes $head -StagedBytes $truncated))

Assert-Case 'identical bytes are allowed (a no-op restage is not a modification)' `
    ($null -eq (Test-B1AppendOnly -HeadBytes $head -StagedBytes $head))

Assert-Case 'a file with no HEAD (first commit) is allowed' `
    ($null -eq (Test-B1AppendOnly -HeadBytes $null -StagedBytes $appended))

# ------------------------------------------------- RULE 1b: ORDER-500 audited repair
Write-Host "`n-- audited repair path (ORDER-500 option B) --"

Assert-Case 'a declared repair MAY modify existing bytes' `
    ($null -eq (Test-B1AppendOnly -HeadBytes $head -StagedBytes $mutated -RepairDeclared $true))

Assert-Case 'an UNdeclared modification is still blocked (the default did not move)' `
    ($null -ne (Test-B1AppendOnly -HeadBytes $head -StagedBytes $mutated -RepairDeclared $false))

$kw = Get-B1RepairKeyword
Assert-Case 'the keyword is recognised in a commit message' `
    (Test-B1RepairDeclared -Message ("repair the glued row`n`n" + $kw + ": ORDER-412 lost ORDER-280"))

Assert-Case 'an ordinary message does NOT declare a repair' `
    (-not (Test-B1RepairDeclared -Message 'ORDER-431 REVIEWED: ceiling measured at MAIN 1.18'))

Assert-Case 'an empty message does NOT declare a repair' `
    (-not (Test-B1RepairDeclared -Message ''))

# Specificity: the keyword must not fire on prose that merely discusses repairs.
Assert-Case 'prose about repairing B1 does NOT declare a repair' `
    (-not (Test-B1RepairDeclared -Message 'this commit does not repair b1 dataset rows, it only appends'))

# -------------------------------------------------------------- RULE 2: row shape
Write-Host "`n-- Test-B1RowShape (ORDER-500, the assertion that was missing) --"

$wellFormed = ToBytes ($HEADER + "`n" + (Row 'ORDER-001') + "`n" + (Row 'ORDER-002') + "`n")
Assert-Case 'well-formed rows pass' `
    ($null -eq (Test-B1RowShape -StagedBytes $wellFormed))

# THE ACTUAL ORDER-500 DEFECT: an append with no leading newline glues two rows into
# one record carrying 2x-1 fields. Reproduced here from the real shape of the damage.
$glued = ToBytes ($HEADER + "`n" + (Row 'ORDER-001') + (Row 'ORDER-002') + "`n")
Assert-Case 'a glued row (append with no leading newline) is BLOCKED' `
    ($null -ne (Test-B1RowShape -StagedBytes $glued))

$gluedMsg = Test-B1RowShape -StagedBytes $glued
Assert-Case 'the glued-row message names the field count so the reader can act' `
    ($null -ne $gluedMsg -and $gluedMsg -match 'fields, expected')

$tooFew = ToBytes ($HEADER + "`n" + 'ORDER-003,2026-07-28,REVIEWED' + "`n")
Assert-Case 'a short row is BLOCKED' `
    ($null -ne (Test-B1RowShape -StagedBytes $tooFew))

$unterminated = ToBytes ($HEADER + "`n" + 'ORDER-004,2026-07-28,REVIEWED,same-file,PENDING,TOOLING,closed,1,0,0,0,0.5,"never closed' + "`n")
Assert-Case 'an unterminated quoted field is BLOCKED' `
    ($null -ne (Test-B1RowShape -StagedBytes $unterminated))

# Specificity -- the things that look malformed but are legal in real B1 rows.
$commasInNotes = ToBytes ($HEADER + "`n" + (Row 'ORDER-005' 'one, two, three, and four commas') + "`n")
Assert-Case 'commas inside a quoted note do NOT trip the guard' `
    ($null -eq (Test-B1RowShape -StagedBytes $commasInNotes))

$doubledQuotes = ToBytes ($HEADER + "`n" + 'ORDER-006,2026-07-28,REVIEWED,same-file,PENDING,TOOLING,closed,1,0,0,0,0.5,"he said ""no"" twice, then left"' + "`n")
Assert-Case 'doubled quotes inside a note do NOT trip the guard' `
    ($null -eq (Test-B1RowShape -StagedBytes $doubledQuotes))

$newlineInNote = ToBytes ($HEADER + "`n" + 'ORDER-007,2026-07-28,REVIEWED,same-file,PENDING,TOOLING,closed,1,0,0,0,0.5,"line one' + "`n" + 'line two"' + "`n")
Assert-Case 'a newline inside a quoted note does NOT trip the guard (records are not lines)' `
    ($null -eq (Test-B1RowShape -StagedBytes $newlineInNote))

$crlf = ToBytes ($HEADER + "`r`n" + (Row 'ORDER-008') + "`r`n")
Assert-Case 'CRLF line endings do NOT trip the guard (the real file is mixed 22/72)' `
    ($null -eq (Test-B1RowShape -StagedBytes $crlf))

$bom = ToBytes ([char]0xFEFF + $HEADER + "`n" + (Row 'ORDER-009') + "`n")
Assert-Case 'a UTF-8 BOM does NOT trip the guard (the real file has one)' `
    ($null -eq (Test-B1RowShape -StagedBytes $bom))

$noTrailingNewline = ToBytes ($HEADER + "`n" + (Row 'ORDER-010'))
Assert-Case 'a missing trailing newline is NOT itself a malformed row' `
    ($null -eq (Test-B1RowShape -StagedBytes $noTrailingNewline))

# A repair commit is not exempt from row shape.
Assert-Case 'row shape still applies to a declared repair' `
    ($null -ne (Test-B1RowShape -StagedBytes $glued))

# ------------------------------------------------- the real file must satisfy both
Write-Host "`n-- the live B1_DATASET.csv --"

$livePath = Join-Path $repoRoot 'docs\memory_control\B1_DATASET.csv'
if (Test-Path -LiteralPath $livePath) {
    $liveBytes = [System.IO.File]::ReadAllBytes($livePath)
    $liveShape = Test-B1RowShape -StagedBytes $liveBytes
    # EXPECTED RED until ORDER-500's repair lands: the glued ORDER-412 row is still in
    # the file. This case is here so the cage reports the known defect rather than
    # quietly passing over it -- see the ORDER-500 row on the board.
    if ($null -eq $liveShape) {
        Write-Host '  [INFO] live B1_DATASET.csv is well-formed (the ORDER-500 repair has landed)'
    } else {
        Write-Host ('  [KNOWN-DEFECT] live B1_DATASET.csv still carries the ORDER-500 damage: ' + $liveShape)
    }
} else {
    Write-Host '  [INFO] live B1_DATASET.csv not found -- skipped'
}

Write-Host ("`n=== {0} passed, {1} failed ===" -f $script:pass, $script:fail)
if ($script:fail -gt 0) {
    foreach ($f in $script:failed) { Write-Host ("  failed: {0}" -f $f) }
    exit 1
}
Write-Host 'ALL CASES PASSED'
exit 0
