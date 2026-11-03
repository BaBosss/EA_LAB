<#
.SYNOPSIS
    Cage for the board readers that still read AGENT_TASKBOARD.md alone after the
    2026-08-22 active-board split (74b5c574): check_handoff_contract.ps1,
    check_block_staleness.ps1, regen_archive_artifacts_staged.ps1 and
    check_verdict_kill.ps1.

.DESCRIPTION
    Since the split, AGENT_TASKBOARD.md is a manifest and every active '## ORDER-' block
    lives in the parts it declares (taskboards/active/P0*.md). A reader that opens the
    manifest alone sees zero active orders and says nothing about it. Each case below
    builds a throwaway git repo under %TEMP% whose ONLY copy of the order under test sits
    in a declared part, copies in the real script under test plus its libraries, and
    asserts the behaviour that is only possible if the part was read. Each reader also has
    a specificity case (the reader still says no where it should) so a fix that makes
    everything green cannot pass.

    Fails before the migration, passes after: run it with -SourceRoot pointing at a tree
    holding the pre-migration scripts to see the RED half.

    ASCII-only source (Windows PowerShell 5.1 decodes a BOM-less .ps1 as ANSI).

    Run:  powershell -NoProfile -File scripts\_test\run_taskboard_manifest_reader_tests.ps1
    Exit: 0 when every case matched, 1 otherwise.
#>
param(
    # Where the scripts under test are copied FROM. Defaults to this checkout.
    [string]$SourceRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$scratch = Join-Path $env:TEMP ('tb_manifest_reader_' + $PID)
if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
New-Item -ItemType Directory -Force -Path $scratch | Out-Null

$results = New-Object System.Collections.Generic.List[object]
function Add-Result {
    param([string]$Name, [bool]$Pass, [string]$Detail = '')
    $results.Add([pscustomobject]@{ Name = $Name; Pass = $Pass; Detail = $Detail })
}

function Invoke-Proc {
    <# Run an executable with $Dir as cwd; drain stdout and stderr concurrently. #>
    param([string]$Dir, [string]$File, [string]$Arguments)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $File
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $Dir
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $errTask = $proc.StandardError.ReadToEndAsync()
    $out = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit()
    $err = $errTask.GetAwaiter().GetResult()
    return [pscustomobject]@{ ExitCode = $proc.ExitCode; Text = ($out + $err) }
}

function Invoke-Git {
    param([string]$Dir, [string]$Arguments)
    $r = Invoke-Proc -Dir $Dir -File 'git' -Arguments $Arguments
    if ($r.ExitCode -ne 0) { throw "git $Arguments failed in ${Dir}: $($r.Text)" }
    return $r
}

function Invoke-Script {
    param([string]$Dir, [string]$Rel, [string]$Arguments = '')
    return Invoke-Proc -Dir $Dir -File 'powershell.exe' -Arguments ('-NoProfile -ExecutionPolicy Bypass -File "{0}" {1}' -f (Join-Path $Dir $Rel), $Arguments)
}

function Write-RepoFile {
    param([string]$Dir, [string]$Rel, [string]$Text)
    $full = Join-Path $Dir $Rel
    $parent = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [System.IO.File]::WriteAllText($full, $Text, $Utf8NoBom)
}

$Manifest = "# AGENT_TASKBOARD (manifest)`n`nThe active queue lives in the parts below.`n`n<!-- TASKBOARD-ACTIVE-PARTS`ntaskboards/active/P01.md`n-->`n"
$Archive  = "## ORDER-800 -- archived probe -- ``REVIEWED```nbody`n"

function New-BoardRepo {
    <# A git repo whose active order(s) exist ONLY in the declared part P01. #>
    param([string]$Tag, [string]$PartText, [string]$ArchiveText = $Archive)
    $dir = Join-Path $scratch $Tag
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Invoke-Git -Dir $dir -Arguments 'init -q' | Out-Null
    Invoke-Git -Dir $dir -Arguments 'config user.email test@example.com' | Out-Null
    Invoke-Git -Dir $dir -Arguments 'config user.name "manifest reader test"' | Out-Null
    Invoke-Git -Dir $dir -Arguments 'config core.autocrlf false' | Out-Null
    foreach ($rel in @('scripts\check_taskboard_archive.ps1','scripts\lib\taskboard_source.ps1','scripts\check_handoff_contract.ps1',
                       'scripts\check_block_staleness.ps1','scripts\regen_archive_artifacts_staged.ps1','scripts\check_verdict_kill.ps1')) {
        $src = Join-Path $SourceRoot $rel
        if (-not (Test-Path -LiteralPath $src)) { throw "source script missing: $src" }
        $dest = Join-Path $dir $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dest -Force
    }
    Write-RepoFile -Dir $dir -Rel 'AGENT_TASKBOARD.md' -Text $Manifest
    Write-RepoFile -Dir $dir -Rel 'taskboards\active\P01.md' -Text $PartText
    Write-RepoFile -Dir $dir -Rel 'ARCHIVE_TASKBOARD_2026-07A.md' -Text $ArchiveText
    Write-RepoFile -Dir $dir -Rel 'MASTER_BACKLOG.md' -Text "# backlog`n"
    # The regen writes into this directory; a real checkout always has it.
    Write-RepoFile -Dir $dir -Rel 'docs\memory_control\.keep' -Text ''
    Invoke-Git -Dir $dir -Arguments 'add -A' | Out-Null
    Invoke-Git -Dir $dir -Arguments 'commit -q -m base' | Out-Null
    return $dir
}

try {

# ----------------------------------------------------------------------------
# check_handoff_contract.ps1 -- ORDER tokens resolve against the LOGICAL board.
# ----------------------------------------------------------------------------
$hPart = "## ORDER-901 -- live probe -- ``OPEN```nbody`n"
function New-HandoffText([string]$Dest) {
    return "# handoff`n`n<!-- HANDOFF-ROUTING -->`n| item | destination |`n|---|---|`n| probe item | $Dest |`n"
}

$h1 = New-BoardRepo -Tag 'handoff_active_only' -PartText $hPart
Write-RepoFile -Dir $h1 -Rel '_triage\PROMPT_NEXT_SESSION_probe.md' -Text (New-HandoffText 'ORDER-901')
Invoke-Git -Dir $h1 -Arguments 'add -- _triage/PROMPT_NEXT_SESSION_probe.md' | Out-Null
$r = Invoke-Script -Dir $h1 -Rel 'scripts\check_handoff_contract.ps1'
Add-Result -Name 'handoff-routes-to-order-that-lives-only-in-an-active-part' -Pass ($r.ExitCode -eq 0) -Detail ("exit={0} {1}" -f $r.ExitCode, ($r.Text.Trim() -replace "`r?`n", ' | '))

$h2 = New-BoardRepo -Tag 'handoff_unknown' -PartText $hPart
Write-RepoFile -Dir $h2 -Rel '_triage\PROMPT_NEXT_SESSION_probe.md' -Text (New-HandoffText 'ORDER-999')
Invoke-Git -Dir $h2 -Arguments 'add -- _triage/PROMPT_NEXT_SESSION_probe.md' | Out-Null
$r = Invoke-Script -Dir $h2 -Rel 'scripts\check_handoff_contract.ps1'
Add-Result -Name 'handoff-SPECIFICITY-order-on-no-board-still-blocks' -Pass (($r.ExitCode -eq 1) -and ($r.Text -match 'ORDER-999')) -Detail ("exit={0}" -f $r.ExitCode)

# A declared part that is not in the index is unreadable input: refuse, never resolve
# against fewer orders.
$h3 = New-BoardRepo -Tag 'handoff_part_unstaged' -PartText $hPart
Invoke-Git -Dir $h3 -Arguments 'rm -q --cached -- taskboards/active/P01.md' | Out-Null
Write-RepoFile -Dir $h3 -Rel '_triage\PROMPT_NEXT_SESSION_probe.md' -Text (New-HandoffText 'ORDER-901')
Invoke-Git -Dir $h3 -Arguments 'add -- _triage/PROMPT_NEXT_SESSION_probe.md' | Out-Null
$r = Invoke-Script -Dir $h3 -Rel 'scripts\check_handoff_contract.ps1'
Add-Result -Name 'handoff-declared-part-missing-from-index-refuses' -Pass (($r.ExitCode -eq 2) -and ($r.Text -match 'P01')) -Detail ("exit={0} {1}" -f $r.ExitCode, ($r.Text.Trim() -replace "`r?`n", ' | '))

# ----------------------------------------------------------------------------
# check_block_staleness.ps1 -- closed blocks in the active parts are linted.
# ----------------------------------------------------------------------------
$sPart = "## ORDER-902 -- closed probe -- ``REVIEWED```ncites commit deadbeefcafe0902 which does not exist`n"
$s1 = New-BoardRepo -Tag 'staleness' -PartText $sPart
$headSha = (Invoke-Git -Dir $s1 -Arguments 'rev-parse HEAD').Text.Trim()
# Specificity: a second closed block citing a commit that DOES exist must not be flagged.
[System.IO.File]::AppendAllText((Join-Path $s1 'taskboards\active\P01.md'), "`n## ORDER-903 -- closed probe -- ``REVIEWED```ncites real commit $headSha`n", $Utf8NoBom)
$r = Invoke-Script -Dir $s1 -Rel 'scripts\check_block_staleness.ps1' -Arguments ('-Strict -RepoRoot "{0}"' -f $s1)
$dangling = [regex]::Matches($r.Text, '(?m)^\s+ORDER-\S+ \(.*\) -> [0-9a-f]+')
Add-Result -Name 'staleness-scans-closed-blocks-in-active-parts' `
    -Pass (($r.ExitCode -eq 1) -and ($r.Text -match 'ORDER-902 \(taskboards/active/P01\.md:1\) -> deadbeefcafe0902')) `
    -Detail ("exit={0} {1}" -f $r.ExitCode, ($r.Text.Trim() -replace "`r?`n", ' | '))
Add-Result -Name 'staleness-SPECIFICITY-existing-commit-not-flagged' `
    -Pass (($dangling.Count -eq 1) -and ($r.Text -notmatch [regex]::Escape($headSha))) `
    -Detail ("dangling_rows={0}" -f $dangling.Count)

# ----------------------------------------------------------------------------
# regen_archive_artifacts_staged.ps1 -- the candidate is built from the LOGICAL board.
# ORDER-800 is archived REVIEWED; reopening it in an active part is a cross-board
# exception that check_precommit_staged.ps1 sees. A regen that reads the manifest alone
# misses it and writes artifacts blessing the snapshot (exit 0).
# ----------------------------------------------------------------------------
$g1 = New-BoardRepo -Tag 'regen_conflict' -PartText "## ORDER-800 -- reopened probe -- ``OPEN```nbody`n"
$r = Invoke-Script -Dir $g1 -Rel 'scripts\regen_archive_artifacts_staged.ps1'
Add-Result -Name 'regen-sees-active-part-order-that-conflicts-with-archive' `
    -Pass (($r.ExitCode -eq 2) -and ($r.Text -match 'ABORT')) `
    -Detail ("exit={0} {1}" -f $r.ExitCode, ($r.Text.Trim() -replace "`r?`n", ' | '))

$g2 = New-BoardRepo -Tag 'regen_clean' -PartText "## ORDER-904 -- unrelated probe -- ``OPEN```nbody`n"
$r = Invoke-Script -Dir $g2 -Rel 'scripts\regen_archive_artifacts_staged.ps1'
$excPath = Join-Path $g2 'docs\memory_control\RECONCILE_EXCEPTIONS.md'
Add-Result -Name 'regen-SPECIFICITY-clean-logical-board-still-writes-artifacts' `
    -Pass (($r.ExitCode -eq 0) -and (Test-Path -LiteralPath $excPath)) `
    -Detail ("exit={0} {1}" -f $r.ExitCode, ($r.Text.Trim() -replace "`r?`n", ' | '))

# ----------------------------------------------------------------------------
# check_verdict_kill.ps1 -- a kill verdict staged into an active part gets the reminder.
# ----------------------------------------------------------------------------
$vPart = "## ORDER-905 -- probe -- ``OPEN```nbody`n"
$v1 = New-BoardRepo -Tag 'verdict_kill' -PartText $vPart
[System.IO.File]::AppendAllText((Join-Path $v1 'taskboards\active\P01.md'), "verdict: DEAD on the default smoke`n", $Utf8NoBom)
Invoke-Git -Dir $v1 -Arguments 'add -- taskboards/active/P01.md' | Out-Null
$r = Invoke-Script -Dir $v1 -Rel 'scripts\check_verdict_kill.ps1'
Add-Result -Name 'verdict-kill-reminder-fires-on-active-part' -Pass (($r.ExitCode -eq 0) -and ($r.Text -match 'KILL-GATE REMINDER')) -Detail ("exit={0}" -f $r.ExitCode)

$v2 = New-BoardRepo -Tag 'verdict_kill_evidence' -PartText $vPart
[System.IO.File]::AppendAllText((Join-Path $v2 'taskboards\active\P01.md'), "verdict: DEAD after a full optimize, ceiling below 1.0 both-window`n", $Utf8NoBom)
Invoke-Git -Dir $v2 -Arguments 'add -- taskboards/active/P01.md' | Out-Null
$r = Invoke-Script -Dir $v2 -Rel 'scripts\check_verdict_kill.ps1'
Add-Result -Name 'verdict-kill-SPECIFICITY-silent-when-optimize-evidence-staged' -Pass (($r.ExitCode -eq 0) -and ($r.Text -notmatch 'KILL-GATE REMINDER')) -Detail ("exit={0}" -f $r.ExitCode)

} finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host '=== taskboard manifest-reader cage ==='
$allPass = $true
foreach ($x in $results) {
    $status = if ($x.Pass) { 'PASS' } else { $allPass = $false; 'FAIL' }
    Write-Host ("[{0}] {1,-66} {2}" -f $status, $x.Name, $x.Detail)
}
$passed = @($results | Where-Object { $_.Pass }).Count
Write-Host ("PASS {0}/{1}" -f $passed, $results.Count)
if ($allPass) { exit 0 } else { exit 1 }
