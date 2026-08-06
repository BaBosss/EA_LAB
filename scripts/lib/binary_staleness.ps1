<#
scripts\lib\binary_staleness.ps1 - ORDER-1461: the launch-banner staleness line, in ONE place.

WHY THIS FILE EXISTS AT ALL, AND WHY IT IS NOT INLINE IN mt5_run.ps1

  It was inline in mt5_run.ps1, and that put it on ONE of the THREE entry points that write
  `Expert=` into a tester .ini and load a compiled binary:

      scripts\mt5_run.ps1        (a backtest)
      scripts\mt5_optimize.ps1   (an OPTIMIZATION -- the one that SELECTS parameters)
      scripts\run_backtest.ps1

  All three already print the `surface:` line from scripts\lib\setfile_surface.ps1, which is the
  precedent this file follows. Covering only the first is the same defect ORDER-1461 is ABOUT,
  one layer over: a correct detector that is not on the path of the thing it governs. The
  optimizer is arguably the worse omission -- a stale binary there does not merely give one
  wrong number, it chooses the parameters everything downstream is built on.

WHAT IT DOES

  Answers one question about the ONE FILE a launch resolves to: is that .ex5 older than its
  source graph? The verdict is produced by scripts\check_stale_binaries.ps1 itself (-OnlyName,
  measured 0.66-0.70s against 107.1s for the full sweep) rather than by a second copy of the
  staleness rule living in a runner, which would drift from it the first time either changed.

  It asks about the exact PATH, not the name group, because that is the finding ORDER-1461
  records: `-Expert Boss_14_GridLog` loads the Experts-root copy while
  `-Expert EALabTpl\Boss_14_GridLog` loads a different, newer one, and on 2026-08-06 the two
  disagreed by eight days.

VISIBLE BEFORE REFUSING

  This returns a STRING. It cannot abort, cannot change an exit code, and every failure inside
  it becomes `UNKNOWN` with the reason attached. 53 ini configs resolve -Expert to the Experts
  root; a refusal wired to this signal would break all 53 at once, which is how a correct
  detector gets switched off (the ORDER-700 reasoning this repo has already paid for).

  🔴 And read this before deciding it is too noisy: on 2026-08-06 fourteen ea_template\core\*.mqh
  files carried the identical mtime 2026-08-06 06:49:53 while the last commit touching
  LabCore.mqh was 2026-08-02 -- a checkout stamp, not edits. So nearly every Boss binary reads
  STALE for a reason that is not staleness. check_stale_binaries.ps1's own header says to check
  that "newer" sources are newer because somebody EDITED them. That is a reason to keep this
  advisory, not a reason to remove it.
#>

function Get-StaleCheckLine {
    <#
    .SYNOPSIS
        One `stale-check: ...` banner line for the binary a launch is about to load.
    .PARAMETER Expert
        The tester's -Expert value, exactly as it goes into the .ini. May carry a subfolder
        (`EALabTpl\Boss_14_GridLog`); the tester resolves it against the Experts folder and so
        does this.
    .PARAMETER ExpertsDir
        The MQL5\Experts folder the tester will resolve against. The CALLER computes it, because
        only the caller knows whether it is running /portable (install folder) or against a
        roaming data dir -- guessing that here would be this file inventing a fact it does not
        have.
    .PARAMETER ScriptRoot
        Where check_stale_binaries.ps1 lives. Defaults to this file's parent's parent (scripts\).
    .OUTPUTS
        [string] - always exactly one line, never $null, never throws.
    #>
    param(
        [Parameter(Mandatory)][string]$Expert,
        [Parameter(Mandatory)][string]$ExpertsDir,
        [string]$ScriptRoot = '',
        # Where the .mq5 sources are. Defaults to $ScriptRoot's parent, which is the repo in
        # every production call. It is a PARAMETER because a cage cannot otherwise put a fixture
        # source anywhere but inside the real repo -- and a cage that has to write into the tree
        # it is testing is the hazard memory `mutating-cage-must-not-be-on-commit-path` records.
        [string]$RepoRoot = ''
    )
    try {
        if (-not $ScriptRoot) { $ScriptRoot = Split-Path -Parent $PSScriptRoot }
        # The three callers do not agree on whether -Expert carries the extension:
        # run_backtest.ps1 defaults $ExpertName to "$Project.ex5" (line 137) while mt5_run.ps1
        # and mt5_optimize.ps1 pass a bare name. Appending blindly gives `X.ex5.ex5`, which
        # Test-Path answers False for -- i.e. it would have degraded to a permanent UNKNOWN on
        # one caller and looked like "no binary there" rather than like a bug. Normalised here,
        # once, and caged both ways.
        $expertRel = $Expert -replace '\.ex5$', ''
        $expertEx5 = Join-Path $ExpertsDir ($expertRel + '.ex5')
        if (-not (Test-Path -LiteralPath $expertEx5)) {
            return "stale-check: UNKNOWN -- no binary at '$expertEx5' (the tester resolves -Expert against this folder)"
        }
        $staleScript = Join-Path $ScriptRoot 'check_stale_binaries.ps1'
        if (-not (Test-Path -LiteralPath $staleScript)) {
            return "stale-check: UNKNOWN -- detector not found at '$staleScript'"
        }
        $staleJson = Join-Path $env:TEMP ("stalecheck_{0}.json" -f [guid]::NewGuid().ToString('N'))
        try {
            # -RepoRoot is passed EXPLICITLY, derived from where the detector actually lives.
            # check_stale_binaries.ps1 defaults it to the literal "D:\EA_LAB", and inheriting
            # that default is the defect memory `hardcoded-repo-path-defeats-worktree-cage`
            # already records against mt5_run.ps1: a run inside a git worktree would search the
            # MAIN checkout for the .mq5, so the sources it compares against are not the ones the
            # binary was built from. Caught by this function's own cage, which puts its fixture
            # source outside D:\EA_LAB and got NO_SOURCE until this line existed.
            $repoRoot = if ($RepoRoot) { $RepoRoot } else { Split-Path -Parent $ScriptRoot }
            # -IncludeForeign. Without it, check_stale_binaries.ps1's own NO_SOURCE suppression
            # (line ~398: "counted, not listed - 709 of them would bury the 10 that matter") drops
            # the record BEFORE it reaches the JSON, and this function fell back to the line
            # below reading "produced no record" -- which is true of the JSON and false of the
            # file: check_stale_binaries.ps1 DID find it, hash it, and look for its source; it
            # just decided the finding was not ours to judge and said nothing. "I could not see
            # this file" and "I saw it and decided it was not mine to judge" are different facts
            # (memory `name-it-honestly-when-you-cannot-prove-it`). ORDER-1461 item 2 found this
            # live: our own renamed `Boss_14_GridLog_OLD`/`_OLD2` have no `.mq5` of that name in
            # this repo, so they were filed as somebody else's EA and the banner went permanently
            # UNKNOWN over binaries that exist. The "bury 10 in 709" concern that motivated the
            # suppression does not apply here: -OnlyName already narrows the sweep to ONE name
            # group, so -IncludeForeign can only ever surface that one record.
            & powershell -NoProfile -ExecutionPolicy Bypass -File $staleScript `
                -OnlyName ([IO.Path]::GetFileNameWithoutExtension($expertEx5)) `
                -Roots $ExpertsDir -RepoRoot $repoRoot -JsonOut $staleJson -IncludeForeign 6>&1 | Out-Null
            # The detector exits 2 on STALE. That is ITS verdict, not this launch's, and the
            # caller's own exit code must not inherit it -- mt5_run.ps1 already learned this
            # lesson once for the truncation check ("the check is advisory; do not let its code
            # leak into ours"). Cleared here so every caller gets it for free.
            $global:LASTEXITCODE = 0

            $rec = $null
            if (Test-Path -LiteralPath $staleJson) {
                # ASSIGN, THEN ITERATE -- do NOT write @(Get-Content ... | ConvertFrom-Json). On
                # PowerShell 5.1 ConvertFrom-Json emits the whole array as ONE pipeline item, so
                # the @() wrapper yields Count=1 whose .path is every path joined by spaces
                # (member enumeration). That matched nothing and printed UNKNOWN with a
                # GetFullPath format error -- measured 2026-08-06, same family as the
                # `($pipeline).Count is $null on one result` trap already recorded for this repo.
                $parsed = Get-Content -LiteralPath $staleJson -Raw | ConvertFrom-Json
                $wanted = [IO.Path]::GetFullPath($expertEx5)
                foreach ($r in $parsed) {
                    if ($r.path -and ([IO.Path]::GetFullPath([string]$r.path) -ieq $wanted)) { $rec = $r; break }
                }
            }
        }
        finally {
            Remove-Item -LiteralPath $staleJson -Force -ErrorAction SilentlyContinue
        }
        if ($null -eq $rec) {
            # With -IncludeForeign above, a NO_SOURCE binary now DOES produce a record -- so
            # reaching here means the detector's own file scan did not find this exact path
            # (e.g. a race between the Test-Path above and the detector's Get-ChildItem), a
            # genuinely different fact from "found it, could not judge it". Worded to match.
            return "stale-check: UNKNOWN -- check_stale_binaries.ps1's own scan did not find a record for '$expertEx5' (not the same as NO_SOURCE, which now reports)"
        }
        # Lead with the STALENESS segment, not the first one. The detail opens with the
        # hash-differs advisory whenever a second copy exists, which is almost always (the MQL5
        # compiler is not byte-reproducible), so a naive truncation spends its whole budget on
        # the part that is explicitly advisory and cuts off the part that NAMES THE NEWER SOURCE
        # FILES -- leaving a bare "STALE", which is exactly what check_stale_binaries.ps1 refuses
        # to emit and what got ignored in the 2026-07-25 Boss_16 case.
        $segments  = @(("$($rec.detail)" -replace '\s+', ' ') -split ' \| ')
        $stalePart = $segments | Where-Object { $_ -like 'binary mtime*' } | Select-Object -First 1
        $why = if ($stalePart) { $stalePart } else { $segments -join ' | ' }
        if ($why.Length -gt 300) { $why = $why.Substring(0, 300) + ' ...' }
        return "stale-check: $($rec.status) -- $($rec.path) mtime=$($rec.mtime) :: $why"
    }
    catch {
        $global:LASTEXITCODE = 0
        return "stale-check: UNKNOWN -- $($_.Exception.Message)"
    }
}

function Get-TesterExpertsDir {
    <#
    .SYNOPSIS
        The MQL5\Experts folder a tester launch will resolve -Expert against.
    .DESCRIPTION
        /portable puts the data dir in the INSTALL folder; otherwise it is the roaming data dir
        the caller was given. Both runners computed this inline and one of them would eventually
        have got it wrong, so it lives beside the thing that consumes it.
    #>
    param(
        [string]$TerminalPath = '',
        [string]$DataDir = '',
        [switch]$Portable
    )
    if ($Portable) {
        if (-not $TerminalPath) { return '' }
        return (Join-Path (Split-Path -Parent $TerminalPath) 'MQL5\Experts')
    }
    if (-not $DataDir) { return '' }
    return (Join-Path $DataDir 'MQL5\Experts')
}
