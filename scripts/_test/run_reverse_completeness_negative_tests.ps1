<#
    run_reverse_completeness_negative_tests.ps1 -- D-F5 (Audit D, 2026-08-20).

    Proves run_guard_trigger_tests.ps1 PART 8 in BOTH DIRECTIONS.

    Why this file exists at all: PART 8 is a completeness roll-up, and this repo's paid-for
    lesson about roll-ups is that they go permanently green and nobody notices
    (completeness-rollup-measured-after-topup, guard-must-print-its-scope-not-just-its-verdict).
    A green PART 8 is only evidence if the red case has been OBSERVED.

    It drives the REAL PART 8 through the -RegistryPath seam. It does not reimplement the check.
    A cage that re-implements the rule tests the copy (cage-baseline-must-not-be-a-photo-of-
    the-repo), and the copy is the one thing that cannot drift into the defect.

    ASCII-only output on purpose. This suite is NOT wired into the fast tier -- see its row in
    scripts/_test/SUITE_TIER_REGISTRY.txt for the reason and the measured cost.

    Cases:
      ATTACK 1  a row removed          -> UNCLASSIFIED fires
      ATTACK 2  one WILDCARD blanket   -> refused; a universal entry cannot silence the check
      ATTACK 3  a row for no real file -> STALE ROW fires
      ATTACK 4  PREDEV flipped to FAST -> PREDEV disposition BROKEN fires
      ATTACK 5  a reason of 4 chars    -> "no usable reason" fires
      CONTROL   the real registry      -> exit 0, and the scope counts are PRINTED
#>
[CmdletBinding()]
param([string]$RepoRoot)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) {
    $d = $PSScriptRoot
    if (-not $d -and $MyInvocation.MyCommand.Path) { $d = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $d) { throw 'cannot resolve script directory; pass -RepoRoot' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $d)
}
Push-Location $RepoRoot
try {
    $fail = 0
    function Bad([string]$m) { Write-Host "  [FAIL] $m" -ForegroundColor Red; $script:fail++ }
    function Good([string]$m) { Write-Host "  [ok]   $m" }

    $ps = (Get-Process -Id $PID).Path
    if (-not $ps) { $ps = 'powershell.exe' }
    $target = Join-Path $RepoRoot 'scripts\_test\run_guard_trigger_tests.ps1'
    $realReg = Join-Path $RepoRoot 'scripts\_test\SUITE_TIER_REGISTRY.txt'
    if (-not (Test-Path -LiteralPath $realReg)) {
        Bad 'the real registry is missing -- this suite cannot fabricate variants of a file that does not exist'
        exit 1
    }
    # HARVESTED, NOT HAND-AUTHORED. Every fixture below is the REAL registry with one mutation,
    # so a case cannot pass because the fixture happens to disagree with production about
    # something unrelated.
    $realLines = @(Get-Content -LiteralPath $realReg)

    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("df5_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    function Invoke-Part8 {
        param([string[]]$Lines, [string]$Label)
        $p = Join-Path $tmpDir ("reg_" + $Label + '.txt')
        Set-Content -LiteralPath $p -Value $Lines -Encoding ASCII
        $out = @(& $ps -NoProfile -ExecutionPolicy Bypass -File $target -RegistryPath $p 2>&1)
        return [pscustomobject]@{ Code = $LASTEXITCODE; Text = ($out -join "`n") }
    }
    function DataRowIndexes { param([string[]]$L)
        $ix = @(); for ($i = 0; $i -lt $L.Count; $i++) {
            $t = $L[$i].Trim(); if ($t -and -not $t.StartsWith('#') -and $t.Contains('|')) { $ix += $i }
        }; return $ix
    }

    try {
        Write-Host '[reverse-completeness] ATTACK 1 -- a classified suite is removed from the registry'
        # Remove the row for a suite that is NOT in the fast tier, so only the UNCLASSIFIED
        # branch is exercised and the FAST cross-check is not what produces the red.
        $victim = 'run_chainwalk_tests.ps1'
        $mut = @($realLines | Where-Object { -not $_.StartsWith($victim + '|') })
        if ($mut.Count -ne $realLines.Count - 1) {
            Bad "ATTACK 1 fixture did not remove exactly one row for $victim (removed $($realLines.Count - $mut.Count))"
        } else {
            $r = Invoke-Part8 -Lines $mut -Label 'missing'
            if ($r.Code -ne 0 -and $r.Text -match ('PART 8 UNCLASSIFIED: scripts/_test/' + [regex]::Escape($victim))) {
                Good "ATTACK 1 an unclassified run_* file is REFUSED by name (exit $($r.Code))"
            } else {
                Bad ("ATTACK 1 expected a non-zero exit naming $victim; got exit $($r.Code)")
            }
        }

        Write-Host '[reverse-completeness] ATTACK 2 -- a single WILDCARD blanket entry'
        # THE CENTRAL CASE. If one catch-all row could satisfy the check, the check would be
        # decorative. The registry must be a CLOSED set.
        $blanket = @('# fabricated blanket registry', 'run_*|UNMEASURED|a single universal entry that claims to cover every suite at once')
        $r = Invoke-Part8 -Lines $blanket -Label 'blanket'
        if ($r.Code -ne 0 -and $r.Text -match 'uses a WILDCARD name' -and $r.Text -match 'PART 8 UNCLASSIFIED') {
            Good "ATTACK 2 a universal entry is refused AND leaves every file unclassified (exit $($r.Code))"
        } else {
            Bad ("ATTACK 2 a blanket entry was not refused as expected; exit $($r.Code)")
        }

        Write-Host '[reverse-completeness] ATTACK 3 -- a row that names no real file'
        $stale = @($realLines) + 'run_a_suite_that_does_not_exist_tests.ps1|UNMEASURED|a declaration that matches nothing, which is the original defect wearing a classification'
        $r = Invoke-Part8 -Lines $stale -Label 'stale'
        if ($r.Code -ne 0 -and $r.Text -match 'PART 8 STALE ROW') {
            Good "ATTACK 3 a row for a non-existent file is REFUSED (exit $($r.Code))"
        } else {
            Bad ("ATTACK 3 expected STALE ROW; got exit $($r.Code)")
        }

        Write-Host '[reverse-completeness] ATTACK 4 -- the accepted PREDEV disposition is flipped to FAST'
        $predev = 'run_new_template_entry_tests.ps1'
        $flip = @($realLines | ForEach-Object {
            if ($_.StartsWith($predev + '|')) { $_ -replace '\|NOT_WIRED\|', '|FAST|' } else { $_ }
        })
        if (-not ($flip -join "`n").Contains($predev + '|FAST|')) {
            Bad "ATTACK 4 fixture failed to flip $predev to FAST"
        } else {
            $r = Invoke-Part8 -Lines $flip -Label 'predev'
            if ($r.Code -ne 0 -and $r.Text -match 'PREDEV disposition BROKEN') {
                Good "ATTACK 4 re-wiring the MEASURED_NOT_WIRED suite is REFUSED (exit $($r.Code))"
            } else {
                Bad ("ATTACK 4 expected PREDEV disposition BROKEN; got exit $($r.Code)")
            }
        }

        Write-Host '[reverse-completeness] ATTACK 5 -- a classification with no usable reason'
        $ix = @(DataRowIndexes -L $realLines)
        $noReason = @($realLines)
        # pick a NOT_WIRED/UNMEASURED row so the FAST cross-check is not the thing that fires
        $picked = $null
        foreach ($i in $ix) { if ($noReason[$i] -match '\|UNMEASURED\|') { $picked = $i; break } }
        if ($null -eq $picked) {
            Bad 'ATTACK 5 could not find an UNMEASURED row to mutate'
        } else {
            $fnOnly = ($noReason[$picked] -split '\|')[0]
            $noReason[$picked] = "$fnOnly|UNMEASURED|tbd"
            $r = Invoke-Part8 -Lines $noReason -Label 'noreason'
            if ($r.Code -ne 0 -and $r.Text -match 'has no usable reason') {
                Good "ATTACK 5 a reason-less classification is REFUSED (exit $($r.Code))"
            } else {
                Bad ("ATTACK 5 expected 'no usable reason'; got exit $($r.Code)")
            }
        }

        Write-Host '[reverse-completeness] CONTROL -- the real registry, unmutated'
        # NOT INERT: the control must be GREEN and must PRINT the scope, otherwise the five reds
        # above are consistent with "PART 8 always fails".
        $r = Invoke-Part8 -Lines $realLines -Label 'control'
        $printsScope = ($r.Text -match '\[scope\] examined \d+ tracked scripts/_test/run_\* file') -and
                       ($r.Text -match '\[scope\] classified: FAST \d+') -and
                       ($r.Text -match '\[scope\] explicitly EXEMPT-with-reason')
        if ($r.Code -eq 0 -and $printsScope) {
            Good 'CONTROL the healthy registry is GREEN and PRINTS its scope counts (not inert)'
            foreach ($ln in ($r.Text -split "`n")) { if ($ln -match '\[scope\]') { Write-Host ("         " + $ln.Trim()) } }
        } else {
            Bad ("CONTROL expected exit 0 with three [scope] lines; got exit $($r.Code)")
        }
    } finally {
        Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($fail -gt 0) {
        Write-Host "[reverse-completeness] $fail FAILURE(S)" -ForegroundColor Red
        exit 1
    }
    Write-Host '[reverse-completeness] all cases green -- PART 8 fires on 5 distinct bad registries and stays green on the real one'
    exit 0
}
finally {
    Pop-Location
}
