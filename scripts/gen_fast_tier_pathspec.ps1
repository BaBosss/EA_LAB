<#
.SYNOPSIS
    Generate the pre-commit fast-tier trigger pathspec from what the suites declare they guard.

.DESCRIPTION
    BACKLOG-D32.

    The hook used to decide whether to run scripts/_test/run_fast_cages.ps1 by matching staged
    files against a hand-enumerated list of DIRECTORIES that happened to contain guarded files.
    Five times in four days a new cage guarded something no entry matched, so the suite ran only
    when an unrelated file was staged beside it -- enforced in appearance, absent in fact. The
    ORDER-500 comment in .githooks/pre-commit predicted the recurrence in writing, and then it
    recurred twice more, once to the person who wrote the prediction.

    The list is now DERIVED. run_fast_cages.ps1 owns $SUITE_GUARDS; this script reads that table
    through -ExportGuards and writes .githooks/fast_tier_pathspec, one pathspec per line. Adding
    a suite without declaring its inputs fails run_guard_trigger_tests.ps1, because the two key
    sets must match.

    Every suite implicitly guards itself, run_fast_cages.ps1, and the hooks -- those are added
    here rather than repeated eleven times in the table.

.PARAMETER Check
    Compare the generated pathspec against the committed file and exit 1 if they differ.
    Writes nothing.

.EXAMPLE
    powershell -File scripts/gen_fast_tier_pathspec.ps1
    powershell -File scripts/gen_fast_tier_pathspec.ps1 -Check
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent $here
}

$OUT = Join-Path $RepoRoot '.githooks\fast_tier_pathspec'
$cages = Join-Path $RepoRoot 'scripts\_test\run_fast_cages.ps1'

$ps = (Get-Process -Id $PID).Path
if (-not $ps) { $ps = 'powershell.exe' }

$json = & $ps -NoProfile -ExecutionPolicy Bypass -File $cages -ExportGuards
if ($LASTEXITCODE -ne 0) {
    # Fail loudly. If the table cannot be read, the honest outcome is "unknown", never an
    # empty pathspec -- an empty pathspec matches nothing and silently disables the tier,
    # which is the exact shape of every defect this file exists to close.
    Write-Host '[gen-pathspec] FAIL: could not read the suite/guards table from run_fast_cages.ps1' -ForegroundColor Red
    exit 1
}
$table = ($json | Out-String) | ConvertFrom-Json

$paths = New-Object System.Collections.Generic.List[string]

# Implicit for every suite: the suites themselves, the runner, the generated pathspec, the
# hooks, and this generator. Editing any of them changes what is enforced.
$paths.Add('scripts/_test/*')
$paths.Add('scripts/gen_fast_tier_pathspec.ps1')
$paths.Add('.githooks/*')

foreach ($suite in $table.Suites) {
    $declared = $table.Guards.$suite
    if (-not $declared) {
        Write-Host ("[gen-pathspec] FAIL: suite {0} declares no guarded paths" -f $suite) -ForegroundColor Red
        exit 1
    }
    foreach ($p in $declared) { $paths.Add($p) }
}

$lines = @($paths | Sort-Object -Unique)
$text = ($lines -join "`n") + "`n"

if ($Check) {
    if (-not (Test-Path -LiteralPath $OUT)) {
        Write-Host "[gen-pathspec] FAIL: $OUT does not exist -- run this script without -Check" -ForegroundColor Red
        exit 1
    }
    $have = (Get-Content -LiteralPath $OUT -Raw) -replace "`r`n", "`n"
    if ($have -ne $text) {
        Write-Host '[gen-pathspec] FAIL: the committed trigger pathspec does not match the declared guards.' -ForegroundColor Red
        Write-Host '  committed:'; ($have -split "`n" | Where-Object { $_ }) | ForEach-Object { Write-Host "    $_" }
        Write-Host '  declared: '; ($lines) | ForEach-Object { Write-Host "    $_" }
        exit 1
    }
    Write-Host ("[gen-pathspec] OK: {0} pathspec entries match the declared guards" -f $lines.Count)
    exit 0
}

# NOT Set-Content -Encoding utf8: in Windows PowerShell 5.1 that writes a BOM, and the first
# line of this file is a pathspec read by a bash hook. A BOM turns `.githooks/*` into
# `<U+FEFF>.githooks/*`, which matches nothing -- the trigger would quietly lose its first
# entry. Same family as memory `dotnet-stdin-bom-corrupts-first-request`: positional,
# invisible, and it degrades to silence rather than to an error.
[IO.File]::WriteAllText($OUT, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("[gen-pathspec] wrote {0} ({1} entries)" -f $OUT, $lines.Count)
exit 0
