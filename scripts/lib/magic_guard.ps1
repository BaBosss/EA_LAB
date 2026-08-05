<#
magic_guard.ps1 - ORDER-1100 (slice S10). THE GLOBAL MAGIC UNIQUENESS RULE, as one callable.

WHY THIS IS A LIBRARY AND NOT SIX LINES INSIDE check_state.ps1
  Two reasons, and the second is the one that earned the file.

  1. ONE IMPLEMENTATION OF THE RULE ITSELF. The decision - which magic may sit on which account,
     and which three legacy collisions are exempt - lives in _triage\factory_os\magic.py, is
     enumerated by run_s10_tests.py, and is ASKED here rather than restated. A PowerShell copy of
     the rule would be a second opinion, and the second opinion is the one nobody drives.

  2. THE CAGE HAS TO BE ABLE TO DRIVE IT. Spawning the whole of check_state.ps1 costs ~3.0s per
     case, and the pre-commit tier's full-run budget has ~0 seconds of headroom (measured: the
     last full runs before this slice were 89.7s and 90.6s against a 90.0s budget). Four driven
     cases through the whole guard would have cost 13.1s and made the tier's own budget refuse the
     commit. As a function it is driven IN PROCESS for a few hundredths of a second per case, and
     the wiring - that check_state actually calls it and routes the answer into a Check - is
     proven once, end to end, against a poisoned index.

WHY IT TAKES TEXT AND NOT PATHS
  ORDER-674's A7: check_state read the WORKING TREE while the hook was judging the INDEX, so a
  duplicate account|magic staged behind a clean worktree copy passed with the gate green - on the
  single inventory for real money. A child process handed a repo path would read the disk and
  reintroduce exactly that. The caller reads both inputs through its own judged reader and hands
  the BYTES down; the temp files below are a transport to a process that needs a path, not a
  second source.

  $AllocText = $null means "the exception list could not be read". That is a FAILURE, never a
  skip: "I cannot see it" must not look like "there is nothing to enforce"
  (memory guard-disarmed-by-prose-reported-as-note).

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  . "$PSScriptRoot\lib\magic_guard.ps1"   then  Test-MagicUniqueness
#>

function Test-MagicUniqueness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        # DELIBERATELY UNTYPED. `[AllowNull()][string]` looks like it accepts $null and does not:
        # PowerShell COERCES $null to [string]::Empty on the way in, so the "I could not read the
        # exception list" branch below became unreachable and the guard reported a clean run over
        # a file it never saw. Caught by the cage's B4, which is the case that exists precisely
        # because a disarmed guard looks exactly like a satisfied one.
        [AllowNull()]$AllocText,
        [AllowNull()]$InvText
    )
    if ($null -eq $AllocText) {
        return @{ ok = $false; detail = ("cannot read the magic exception list " +
            "factory/magic_allocations.jsonl - the global rule cannot be enforced without it, " +
            "and silence here would read as compliance. Regenerate with " +
            "tools\python312\python.exe _triage\factory_os\gen_magic_allocations.py --apply") }
    }
    if ($null -eq $InvText) {
        return @{ ok = $false; detail = 'cannot read portfolio/DEPLOYMENTS.csv - the rule compares the two and cannot run on one' }
    }
    $py = Join-Path $RepoRoot 'tools\python312\python.exe'
    # snapshot: not-a-judged-input -- the interpreter is a TOOL, not evidence. "Does this binary
    # exist on this disk" has no committed answer, and asking git for one would be asking the
    # wrong oracle. Its absence is reported as a failure, never as a skip.
    if (-not (Test-Path -LiteralPath $py)) {
        return @{ ok = $false; detail = "interpreter not found at $py - the magic rule could not be evaluated" }
    }
    $module = Join-Path $RepoRoot '_triage\factory_os\magic.py'
    if (-not (Test-Path -LiteralPath $module)) {
        return @{ ok = $false; detail = "$module is missing - the module that OWNS this rule is gone" }
    }
    $tmpAlloc = [IO.Path]::GetTempFileName()
    $tmpInv   = [IO.Path]::GetTempFileName()
    try {
        # No BOM. PowerShell's Set-Content -Encoding UTF8 writes one and json.loads refuses it;
        # this repo has paid for that trap twice. (magic.py reads utf-8-sig anyway - belt and
        # braces, because the next caller may not.)
        $noBom = New-Object System.Text.UTF8Encoding $false
        [IO.File]::WriteAllText($tmpAlloc, [string]$AllocText, $noBom)
        [IO.File]::WriteAllText($tmpInv,   [string]$InvText,   $noBom)
        $out  = & $py $module 'verify' "--store=$tmpAlloc" "--inventory=$tmpInv"
        $code = $LASTEXITCODE
        return @{ ok = ($code -eq 0); detail = ("magic.py verify exit $code : " + ($out -join ' ')) }
    } finally {
        Remove-Item -LiteralPath $tmpAlloc, $tmpInv -Force -ErrorAction SilentlyContinue
    }
}
