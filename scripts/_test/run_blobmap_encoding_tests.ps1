<#
.SYNOPSIS
    Targeted cage for Get-GitBlobOidMap stdin encoding in
    scripts/check_taskboard_archive.ps1 (ORDER-411).

.DESCRIPTION
    ORDER-270 replaced ~3 git spawns per commit with one `git cat-file --batch-check`
    process fed over stdin. The refs were written with $proc.StandardInput.WriteLine,
    which on .NET Framework / PS 5.1 inherits [Console]::OutputEncoding. When that
    encoding is UTF-8 it has a 3-byte preamble, and the writer emits it before the first
    line -- so git reads "<BOM><sha>:<path>", answers "missing", and the FIRST commit of
    the walked chain maps to $null. The chain walk then fails closed with
    "archive path not readable at <sha> (renamed/deleted mid-chain?)", naming a commit
    where `git ls-tree` shows the file present.

    Two properties make it nasty enough to deserve its own cage:

      - It is POSITIONAL. Whichever ref goes first is the one that fails, so the error
        blames an arbitrary old commit and reads like history corruption.
      - It is SESSION-DEPENDENT. A console left on the OEM codepage has no preamble, so
        the identical code passes for one lane and blocks another on the same commit.
        That is the shape that wastes an afternoon: "it worked for them".

    So the test forces the hostile condition rather than waiting for it -- it sets
    [Console]::OutputEncoding to UTF-8 WITH a preamble for the duration, and asserts the
    first ref still resolves. Against the pre-fix code this goes red; against the
    BOM-less writer it goes green.

.NOTES
    ASCII only: PS 5.1 decodes a BOM-less .ps1 as ANSI.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}

$validator = Join-Path $RepoRoot 'scripts\check_taskboard_archive.ps1'
. $validator -RepoRoot $RepoRoot 6>$null

$script:pass = 0
$script:fail = 0
function Assert-True {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) { Write-Host ("  ok   {0}" -f $Name); $script:pass++ }
    else {
        Write-Host ("  FAIL {0}" -f $Name) -ForegroundColor Red
        if ($Detail) { Write-Host ("         {0}" -f $Detail) }
        $script:fail++
    }
}

Write-Host '[blobmap-encoding-tests] running'

$archiveRel = 'ARCHIVE_TASKBOARD_2026-07A.md'

# Pick real refs off the current history. Two commits that both contain the archive:
# HEAD, and the oldest commit on HEAD's first-parent chain that touched the archive.
$head = (& git -C $RepoRoot rev-parse HEAD).Trim()
$old  = (& git -C $RepoRoot rev-list --first-parent --max-count=1 --reverse HEAD -- $archiveRel).Trim()
if (-not $old) { $old = $head }

# Sanity: both refs really do have the file, independent of the function under test.
foreach ($ref in @($head, $old)) {
    $probe = & git -C $RepoRoot ls-tree --name-only $ref -- $archiveRel
    Assert-True ("fixture ref {0} really contains the archive" -f $ref.Substring(0, 8)) `
        ([bool]$probe) 'git ls-tree found nothing - fixture assumption broken, not a code failure'
}

$savedOut = [Console]::OutputEncoding
$savedIn  = $null
try { $savedIn = [Console]::InputEncoding } catch { $savedIn = $null }
try {
    # THE HOSTILE CONDITION: UTF-8 *with* preamble, which is what a console switched to
    # UTF-8 actually reports. $true is the whole point of this test - do not "simplify" it
    # to $false, that reproduces the passing session and cages nothing.
    #
    # It must be INPUT encoding. .NET Framework builds Process.StandardInput from
    # [Console]::InputEncoding, so pinning OutputEncoding alone leaves the test at the mercy
    # of whatever the ambient input encoding happens to be - green on an OEM-codepage box
    # even with the bug present. Both are set: Input is the one that discriminates, Output is
    # set too so the test does not silently depend on them tracking each other.
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($true)
    $inputPinned = $false
    try { [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($true); $inputPinned = $true } catch { $inputPinned = $false }
    Assert-True 'test harness really did install a preamble-bearing INPUT encoding' `
        ($inputPinned -and [Console]::InputEncoding.GetPreamble().Count -gt 0) `
        'could not set [Console]::InputEncoding here - this test cannot discriminate in this environment and must not be read as a pass'

    $map = Get-GitBlobOidMap -RepoRoot $RepoRoot -Refs @($old, $head) -Path $archiveRel
    Assert-True 'FIRST ref resolves under a BOM-bearing console encoding' `
        ([bool]$map[$old]) ("got '{0}' for {1}" -f $map[$old], $old)
    Assert-True 'second ref resolves too' ([bool]$map[$head])

    # Positional proof: swapping the order must not move a failure around.
    $swapped = Get-GitBlobOidMap -RepoRoot $RepoRoot -Refs @($head, $old) -Path $archiveRel
    Assert-True 'result is order-independent (first ref swapped)' `
        (($swapped[$head] -eq $map[$head]) -and ($swapped[$old] -eq $map[$old])) `
        'the same ref resolved differently depending on its position in the batch'

    # A path that genuinely does not exist must still map to $null - the fix must not
    # turn fail-closed into fail-open.
    $absent = Get-GitBlobOidMap -RepoRoot $RepoRoot -Refs @($head) -Path 'no/such/file/anywhere.md'
    Assert-True 'a genuinely missing path still maps to $null (still fails closed)' `
        ($null -eq $absent[$head]) ("got '{0}'" -f $absent[$head])

    # ORDER-412 regression 1: NO GLOBAL SIDE EFFECT. The first fix mutated
    # [Console]::InputEncoding process-wide (SetConsoleCP) to solve a problem local to one
    # pipe, and leaked it whenever the getter threw but the setter succeeded.
    #
    # The hostile encoding is RE-ESTABLISHED on the line before the measured call, and that
    # is not decoration. The first version of this case captured "before" once, near the end
    # of the block - by which point the earlier calls above had already reset the encoding,
    # so before and after were both clean and the case passed against code that mutated on
    # every single call. Measured: it failed to fail. A side-effect assertion must own the
    # state it measures, immediately.
    [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($true)
    $encBefore = [Console]::InputEncoding
    $null = Get-GitBlobOidMap -RepoRoot $RepoRoot -Refs @($head) -Path $archiveRel
    $encAfter = [Console]::InputEncoding
    Assert-True 'call does not mutate [Console]::InputEncoding (no process-wide side effect)' `
        (($encAfter.CodePage -eq $encBefore.CodePage) -and
         ($encAfter.GetPreamble().Count -eq $encBefore.GetPreamble().Count)) `
        ("before cp={0} preamble={1}; after cp={2} preamble={3}" -f `
            $encBefore.CodePage, $encBefore.GetPreamble().Count, $encAfter.CodePage, $encAfter.GetPreamble().Count)

    # ORDER-412 regression 2: SINGLE-REF batch returns the ref's OID, not the absorber's row.
    #
    # HONEST SCOPE, so nobody reads more into this than it carries: this does NOT cage the
    # `1..0` descending-range bug that /scrutinize found in the old conditional-absorber
    # code. With the absorber sent unconditionally the reply always has at least 2 lines
    # (absorber + >=1 ref), so Count -eq 1 is unreachable and BOTH the old and new skip
    # idioms give the same answer here - verified by reverting the idiom and watching this
    # case stay green. Select-Object -Skip is kept because it is correct at 0 and 1 rows,
    # i.e. defensive, not load-bearing. What this case does cage is the off-by-one:
    # forget to drop the absorber row, or drop one too many, and it goes red.
    $single = Get-GitBlobOidMap -RepoRoot $RepoRoot -Refs @($head) -Path $archiveRel
    $expected = (& git -C $RepoRoot rev-parse ("{0}:{1}" -f $head, $archiveRel)).Trim()
    Assert-True 'single-ref batch resolves to the ref OID (absorber row dropped exactly once)' `
        ($single[$head] -eq $expected) ("got '{0}', git says '{1}'" -f $single[$head], $expected)
}
finally {
    [Console]::OutputEncoding = $savedOut
    if ($null -ne $savedIn) { try { [Console]::InputEncoding = $savedIn } catch { } }
}

Write-Host ''
Write-Host ("[blobmap-encoding-tests] {0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail -gt 0) { exit 1 }
exit 0
