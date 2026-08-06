<#
.SYNOPSIS
    ORDER-1461 cage: the launch-banner staleness line, driven directly.

.DESCRIPTION
    WHY IT EXISTS. The banner shipped 2026-08-06 inside mt5_run.ps1 with NO cage of its own --
    run_stale_binaries_tests.ps1 covers the DETECTOR, not the line the runners print. The only
    verification it ever had was a human slicing the block out of the file and running it by
    hand, which is the shape this repo has paid for repeatedly: a check whose only caller is a
    person who remembers.

    It tests the rule function DIRECTLY rather than through a tester launch, the same choice
    run_b1_guard_tests.ps1 makes and for the same reason -- driving it end to end would need an
    MT5 run, so it would never be on a commit path.

    THE LOAD-BEARING CASES ARE THE NEGATIVE ONES. A banner that always says STALE is not a
    detector, and on 2026-08-06 a repo-wide checkout stamp made almost every Boss binary read
    STALE for a reason that is not staleness -- so OK must be reachable, and it is asserted here.

USAGE  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\_test\run_binary_staleness_tests.ps1
EXIT   0 = every case behaved as declared - 1 = at least one did not
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
. (Join-Path $RepoRoot 'scripts\lib\binary_staleness.ps1')

$script:pass = 0
$script:fail = 0
function Assert-True {
    param([string]$Name, [bool]$Cond, [string]$Detail = '')
    if ($Cond) { $script:pass++; Write-Host ("  ok   {0}" -f $Name) }
    else { $script:fail++; Write-Host ("  FAIL {0}{1}" -f $Name, $(if ($Detail) { " -- $Detail" } else { '' })) -ForegroundColor Red }
}

Write-Host ''
Write-Host '[binary-staleness] A. Get-TesterExpertsDir -- where the tester resolves -Expert'

Assert-True 'portable resolves against the INSTALL folder' `
    ((Get-TesterExpertsDir -TerminalPath 'D:\Meta 5b\terminal64.exe' -DataDir 'C:\ignored' -Portable) -ieq 'D:\Meta 5b\MQL5\Experts') `
    (Get-TesterExpertsDir -TerminalPath 'D:\Meta 5b\terminal64.exe' -DataDir 'C:\ignored' -Portable)

# SPECIFICITY. The two branches must not collapse into one: a portable run reading the roaming
# data dir would ask about a DIFFERENT FILE than the one the tester loads, which is the exact
# error class ORDER-1461 exists for.
Assert-True 'non-portable resolves against the DATA DIR, not the install folder' `
    ((Get-TesterExpertsDir -TerminalPath 'D:\Meta 5\terminal64.exe' -DataDir 'C:\Roaming\Term1') -ieq 'C:\Roaming\Term1\MQL5\Experts') `
    (Get-TesterExpertsDir -TerminalPath 'D:\Meta 5\terminal64.exe' -DataDir 'C:\Roaming\Term1')

Assert-True 'a missing data dir yields empty, not a half-formed path' `
    ((Get-TesterExpertsDir -TerminalPath 'D:\Meta 5\terminal64.exe' -DataDir '') -eq '')

Write-Host ''
Write-Host '[binary-staleness] B. Get-StaleCheckLine -- against a real fixture tree'

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('stalebanner_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$fixRepo  = Join-Path $tmp 'repo'
$fixSrc   = Join-Path $fixRepo 'ea_template'
$fixExp   = Join-Path $tmp 'Experts'
$fixSub   = Join-Path $fixExp 'EALabTpl'
try {
    New-Item -ItemType Directory -Path $fixSrc, $fixSub -Force | Out-Null
    $old = (Get-Date).AddDays(-10)
    $new = (Get-Date).AddDays(-1)

    # EaOld: binary older than its source -> STALE
    Set-Content -LiteralPath (Join-Path $fixSrc 'EaOld.mq5') -Value '// source' -Encoding ASCII
    (Get-Item -LiteralPath (Join-Path $fixSrc 'EaOld.mq5')).LastWriteTime = $new
    Set-Content -LiteralPath (Join-Path $fixExp 'EaOld.ex5') -Value 'binary' -Encoding ASCII
    (Get-Item -LiteralPath (Join-Path $fixExp 'EaOld.ex5')).LastWriteTime = $old

    # EaNew: binary newer than its source -> OK
    Set-Content -LiteralPath (Join-Path $fixSrc 'EaNew.mq5') -Value '// source' -Encoding ASCII
    (Get-Item -LiteralPath (Join-Path $fixSrc 'EaNew.mq5')).LastWriteTime = $old
    Set-Content -LiteralPath (Join-Path $fixExp 'EaNew.ex5') -Value 'binary' -Encoding ASCII
    (Get-Item -LiteralPath (Join-Path $fixExp 'EaNew.ex5')).LastWriteTime = $new

    # A SUBFOLDER copy of EaOld that is FRESH. This pair is the whole finding: `-Expert EaOld`
    # and `-Expert EALabTpl\EaOld` are two different files under one name, and the banner has to
    # answer about the one the tester will actually load.
    Set-Content -LiteralPath (Join-Path $fixSub 'EaOld.ex5') -Value 'binary2' -Encoding ASCII
    (Get-Item -LiteralPath (Join-Path $fixSub 'EaOld.ex5')).LastWriteTime = $new

    $scriptRoot = Join-Path $RepoRoot 'scripts'

    $lOld = Get-StaleCheckLine -Expert 'EaOld' -ExpertsDir $fixExp -ScriptRoot $scriptRoot -RepoRoot $fixRepo
    Assert-True 'a binary older than its source reads STALE' ($lOld -like 'stale-check: STALE*') $lOld
    Assert-True 'and it NAMES the newer source file rather than saying only STALE' `
        ($lOld -match 'EaOld\.mq5') $lOld
    Assert-True 'and it names the exact PATH it judged' ($lOld -match 'Experts\\EaOld\.ex5') $lOld

    # SPECIFICITY. Without this the line could be hardcoded to STALE and every case above passes.
    $lNew = Get-StaleCheckLine -Expert 'EaNew' -ExpertsDir $fixExp -ScriptRoot $scriptRoot -RepoRoot $fixRepo
    Assert-True 'a binary NEWER than its source reads OK' ($lNew -like 'stale-check: OK*') $lNew

    # The discriminating pair: same name, two files, different verdicts.
    #
    # 📌 It reads HASH_DIFFERS, not OK, and that is the DETECTOR'S CONTRACT rather than a defect:
    # two copies of one name with different SHA256s are always flagged, and the flag is ADVISORY
    # because MQL5 compilation is not byte-reproducible (5/5 distinct hashes from identical
    # source, measured in check_stale_binaries.ps1). The first draft of this case asserted 'OK'
    # and failed -- writing the assertion the code SHOULD satisfy, then reading what it actually
    # says, is how the difference surfaced. It matters in production: nearly every EA on this
    # machine has a sibling copy, so HASH_DIFFERS is the COMMON reading of a healthy binary and
    # must never be read as "stale".
    # 🔴 READ THE STATUS FIELD, never the whole line. `-like '*STALE*'` is case-INSENSITIVE in
    # PowerShell and the line begins with the literal prefix `stale-check:`, so that test is TRUE
    # for every line this function can ever return -- including OK. The first draft of these two
    # cases did exactly that and reported a failure that was entirely in the assertion.
    function Get-Status([string]$Line) {
        $m = [regex]::Match($Line, '^stale-check:\s+(\S+)\s+--')
        if ($m.Success) { return $m.Groups[1].Value } else { return '<unparseable>' }
    }
    $lSub = Get-StaleCheckLine -Expert 'EALabTpl\EaOld' -ExpertsDir $fixExp -ScriptRoot $scriptRoot -RepoRoot $fixRepo
    Assert-True 'a subfolder copy of the SAME NAME is judged as its own file, and is NOT stale' `
        ((Get-Status $lSub) -ne 'STALE' -and $lSub -match 'EALabTpl') ("status={0} :: {1}" -f (Get-Status $lSub), $lSub)
    Assert-True 'and the two same-name copies do NOT get the same verdict' `
        ((Get-Status $lOld) -eq 'STALE' -and (Get-Status $lSub) -ne 'STALE') `
        ("root={0} sub={1}" -f (Get-Status $lOld), (Get-Status $lSub))
    Assert-True 'the advisory hash difference is reported, not silently dropped' `
        ($lSub -like '*HASH_DIFFERS*') $lSub

    # run_backtest.ps1 passes "$Project.ex5". Appending blindly gives X.ex5.ex5, which reads as
    # "no binary there" -- a permanent UNKNOWN wearing the shape of an honest answer.
    $lExt = Get-StaleCheckLine -Expert 'EaOld.ex5' -ExpertsDir $fixExp -ScriptRoot $scriptRoot -RepoRoot $fixRepo
    Assert-True 'an -Expert that already carries .ex5 gives the SAME line as the bare name' `
        ($lExt -eq $lOld) ("with=[$lExt] without=[$lOld]")

    $lMissing = Get-StaleCheckLine -Expert 'NoSuchEa' -ExpertsDir $fixExp -ScriptRoot $scriptRoot -RepoRoot $fixRepo
    Assert-True 'a missing binary is UNKNOWN and names the path it looked for' `
        ($lMissing -like 'stale-check: UNKNOWN*' -and $lMissing -match 'NoSuchEa\.ex5') $lMissing

    # ORDER-1461 item 2, the honest-naming half. A binary that EXISTS but has no matching .mq5
    # anywhere in the fake repo used to be filed by check_stale_binaries.ps1 as NO_SOURCE and then
    # SUPPRESSED (its own "709 foreign binaries would bury the 10 that matter" rule) before ever
    # reaching the JSON -- so this function fell back to "produced no record", which reads as
    # "could not see this file" when the fact is "saw it, decided it was not ours to judge".
    # Reachable in production: our own renamed Boss_14_GridLog_OLD/_OLD2 have no matching .mq5 and
    # went permanently UNKNOWN this way. The fixture is a binary with genuinely nobody's .mq5.
    Set-Content -LiteralPath (Join-Path $fixExp 'EaOrphan.ex5') -Value 'binary3' -Encoding ASCII
    $lOrphan = Get-StaleCheckLine -Expert 'EaOrphan' -ExpertsDir $fixExp -ScriptRoot $scriptRoot -RepoRoot $fixRepo
    Assert-True 'a binary with NO matching .mq5 anywhere reads NO_SOURCE, not a bare UNKNOWN' `
        ((Get-Status $lOrphan) -eq 'NO_SOURCE') ("status={0} :: {1}" -f (Get-Status $lOrphan), $lOrphan)
    Assert-True 'and it says it COULD NOT VERIFY, not that it found no record' `
        ($lOrphan -match 'cannot verify staleness' -and $lOrphan -notmatch 'produced no record') $lOrphan

    $lNoDet = Get-StaleCheckLine -Expert 'EaOld' -ExpertsDir $fixExp -ScriptRoot (Join-Path $tmp 'nowhere')
    Assert-True 'a missing DETECTOR is UNKNOWN, not silently absent' `
        ($lNoDet -like 'stale-check: UNKNOWN*' -and $lNoDet -match 'detector not found') $lNoDet

    # ADVISORY, ENFORCED. The detector exits 2 on STALE. If that leaked, a caller reading
    # $LASTEXITCODE after the banner would see a failure the launch never had -- and mt5_run.ps1
    # already carries a comment about exactly this hazard for the truncation check.
    $global:LASTEXITCODE = 0
    $null = Get-StaleCheckLine -Expert 'EaOld' -ExpertsDir $fixExp -ScriptRoot $scriptRoot -RepoRoot $fixRepo
    Assert-True 'a STALE verdict does not leak exit code 2 into the caller' `
        ($LASTEXITCODE -eq 0) ("LASTEXITCODE=$LASTEXITCODE")

    # It must never abort its caller, whatever it is handed.
    $threw = $false
    try { $null = Get-StaleCheckLine -Expert 'x' -ExpertsDir 'Z:\does\not\exist' -ScriptRoot $scriptRoot }
    catch { $threw = $true }
    Assert-True 'an unusable Experts dir returns a line instead of throwing' (-not $threw)
}
finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host '[binary-staleness] C. every tester entry point actually calls it'

# The defect this file was written after: the banner existed on ONE of the three scripts that
# write `Expert=` into a tester .ini. DERIVED, not listed -- any future runner that writes an
# Expert= line is demanded to carry the banner too, so the next one cannot be forgotten the way
# mt5_optimize.ps1 and run_backtest.ps1 were.
#
# THE PREDICATE IS "BUILDS ITS OWN MT5 TESTER INI", not "mentions an Expert". Both halves were
# measured, because the first draft used the loose form and named five scripts that should not
# be demanded:
#   hedge_recovery_sweep.ps1, walkforward.ps1  DELEGATE to mt5_run.ps1 -- they already get the
#                                              banner, and demanding a second one would print it
#                                              twice and tie a sweep to a detector it never calls
#   monitor_rotation.ps1                       matched on an incidental string; it launches no tester
#   mt4_run.ps1, mt4_optimize.ps1              MT4. They load .ex4 from a different tree, and
#                                              check_stale_binaries.ps1 scans .ex5 only.
# 🚫 The MT4 pair is EXCLUDED BY NAME rather than filtered away quietly: whether MT4 binaries can
# go stale the same way is a real question and this cage does not answer it. See ORDER-1500.
$mt4Excluded = @('mt4_run.ps1', 'mt4_optimize.ps1')
$runners = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'scripts') -Filter '*.ps1' -File |
    Where-Object {
        $t = Get-Content -LiteralPath $_.FullName -Raw
        ($t -match '\[Tester\]') -and ($t -match 'Expert=\$') -and ($mt4Excluded -notcontains $_.Name)
    })
Assert-True 'the derivation found exactly the three MT5 tester entry points' `
    ($runners.Count -eq 3) `
    ("found {0}: {1}" -f $runners.Count, (($runners | ForEach-Object { $_.Name }) -join ', '))
$missing = @()
foreach ($r in $runners) {
    $txt = Get-Content -LiteralPath $r.FullName -Raw
    if ($txt -notmatch 'Get-StaleCheckLine') { $missing += $r.Name }
}
Assert-True 'every script that writes Expert= into a tester ini prints the stale-check line' `
    ($missing.Count -eq 0) ("missing: {0}" -f ($missing -join ', '))

Write-Host ''
Write-Host ("[binary-staleness] {0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail -gt 0) { exit 1 }
exit 0
