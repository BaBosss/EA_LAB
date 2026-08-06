<#
.SYNOPSIS
    Targeted cage for scripts/check_stale_binaries.ps1 (ORDER-370).

.DESCRIPTION
    ORDER-221 gave this detector four roots: ea_template, ea_projects, the D:\Meta 5b
    portable Experts folder, and the roaming Experts folder. All four are places a binary
    is BUILT or TESTED. The one place a binary is actually SHIPPED TO A CHART --
    _vps_deploy\** -- had zero records, and .ex5 is gitignored, so nothing else on this
    machine would ever have shown it.

    Two things are caged here, and they fail for different reasons:

      A. DEFAULT SCOPE. The default -Roots list must contain _vps_deploy. Read out of the
         param block by AST, not by grepping the file, so a mention in a comment cannot
         satisfy it. This is the test that goes red if somebody re-narrows the scope.

      B. BUNDLE SHAPE. A _vps_deploy bundle is a folder holding a lone .ex5 with NO .mq5
         next to it -- the source lives back in ea_template/ea_projects. That shape was
         never exercised before, so it gets a fixture: stale bundle, fresh bundle, and an
         orphan bundle with no source anywhere in the repo. The orphan must come back
         NO_SOURCE rather than crashing or being mislabelled STALE.

    Fixtures are built in a temp folder and deleted afterwards; nothing here touches the
    real tree or the real JSON sidecar.

.NOTES
    ASCII only, on purpose -- see memory oc-qwen-lane-installed: a .ps1 with non-ASCII
    bytes and no BOM is read as ANSI by PowerShell 5.1.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'

# scripts/_test/ -> two levels up. $PSScriptRoot is empty under `powershell -File <relative>`
# from a non-PowerShell shell, so fall back to $MyInvocation (ORDER-260 precedent).
if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}
$target = Join-Path $RepoRoot 'scripts\check_stale_binaries.ps1'
if (-not (Test-Path -LiteralPath $target)) { throw "not found: $target" }

$script:pass = 0
$script:fail = 0

function Assert-True {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        Write-Host ("  ok   {0}" -f $Name)
        $script:pass++
    } else {
        Write-Host ("  FAIL {0}" -f $Name) -ForegroundColor Red
        if ($Detail) { Write-Host ("         {0}" -f $Detail) }
        $script:fail++
    }
}

Write-Host '[stale-binaries-tests] running'

# ---------------------------------------------------------------------------
# A. Default -Roots must include _vps_deploy (read via AST, not text search).
# ---------------------------------------------------------------------------
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($target, [ref]$null, [ref]$parseErrors)
if ($parseErrors -and $parseErrors.Count -gt 0) { throw "target does not parse: $($parseErrors[0].Message)" }

$paramBlock = $ast.ParamBlock
if (-not $paramBlock) { throw 'target has no param block' }
$rootsParam = $paramBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Roots' }
Assert-True 'target declares a -Roots parameter' ([bool]$rootsParam)

$defaultRoots = @()
if ($rootsParam -and $rootsParam.DefaultValue) {
    # The default is an array literal of string constants; pull the constants out of it.
    $defaultRoots = @($rootsParam.DefaultValue.FindAll(
        { param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true
    ) | ForEach-Object { $_.Value })
}
Assert-True 'default -Roots is a non-empty list of literal paths' ($defaultRoots.Count -gt 0) `
    ("parsed {0} entries" -f $defaultRoots.Count)

# THE ORDER-370 REGRESSION. _vps_deploy is where binaries go to be attached.
$hasVps = @($defaultRoots | Where-Object { $_ -match '_vps_deploy' }).Count -gt 0
Assert-True 'default -Roots covers _vps_deploy (the attach surface)' $hasVps `
    ("default roots were: {0}" -f ($defaultRoots -join ' | '))

# The build/test roots ORDER-221 chose must not be dropped while adding the new one.
foreach ($needed in @('ea_template', 'ea_projects', 'Meta 5b', 'Terminal')) {
    $ok = @($defaultRoots | Where-Object { $_ -match [regex]::Escape($needed) }).Count -gt 0
    Assert-True ("default -Roots still covers '{0}'" -f $needed) $ok
}

# ---------------------------------------------------------------------------
# B. Bundle shape: a lone .ex5 in a folder, source living elsewhere in the repo.
# ---------------------------------------------------------------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("stalecage_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
$fixRepo   = Join-Path $tmp 'repo'
$fixSrc    = Join-Path $fixRepo 'ea_template'
$fixDeploy = Join-Path $fixRepo '_vps_deploy'
$jsonOut   = Join-Path $tmp 'out.json'

try {
    New-Item -ItemType Directory -Path $fixSrc -Force | Out-Null
    foreach ($b in @('StaleBundle', 'FreshBundle', 'OrphanBundle')) {
        New-Item -ItemType Directory -Path (Join-Path $fixDeploy $b) -Force | Out-Null
    }

    $old = (Get-Date).AddDays(-10)
    $new = (Get-Date).AddDays(-1)

    # Case 1: binary OLDER than its source -> STALE
    Set-Content -LiteralPath (Join-Path $fixSrc 'EaStale.mq5') -Value '// source' -Encoding ASCII
    (Get-Item -LiteralPath (Join-Path $fixSrc 'EaStale.mq5')).LastWriteTime = $new
    Set-Content -LiteralPath (Join-Path $fixDeploy 'StaleBundle\EaStale.ex5') -Value 'binary' -Encoding ASCII
    (Get-Item -LiteralPath (Join-Path $fixDeploy 'StaleBundle\EaStale.ex5')).LastWriteTime = $old

    # Case 2: binary NEWER than its source -> OK
    Set-Content -LiteralPath (Join-Path $fixSrc 'EaFresh.mq5') -Value '// source' -Encoding ASCII
    (Get-Item -LiteralPath (Join-Path $fixSrc 'EaFresh.mq5')).LastWriteTime = $old
    Set-Content -LiteralPath (Join-Path $fixDeploy 'FreshBundle\EaFresh.ex5') -Value 'binary' -Encoding ASCII
    (Get-Item -LiteralPath (Join-Path $fixDeploy 'FreshBundle\EaFresh.ex5')).LastWriteTime = $new

    # Case 3: bought/downloaded EA, no .mq5 anywhere -> NO_SOURCE, not STALE, not a crash
    Set-Content -LiteralPath (Join-Path $fixDeploy 'OrphanBundle\EaOrphan.ex5') -Value 'binary' -Encoding ASCII

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target `
        -Roots $fixDeploy -RepoRoot $fixRepo -JsonOut $jsonOut -IncludeForeign *> $null
    $exit = $LASTEXITCODE

    Assert-True 'exits 2 when a bundle binary is older than its source' ($exit -eq 2) `
        ("exit code was {0}" -f $exit)
    Assert-True 'wrote a JSON sidecar' (Test-Path -LiteralPath $jsonOut)

    # NOT `@(Get-Content ... | ConvertFrom-Json)`. On PS 5.1 ConvertFrom-Json emits a
    # multi-element JSON array as ONE pipeline object, so @() around the pipeline collects it
    # as a single element and .Count reads 1 no matter how many records there are. (Piping
    # that nested array onward still enumerates correctly, which is what makes it deceptive -
    # every per-row assertion below passed while the count assertion read 1.) Assign first,
    # then wrap the variable, where @() flattens as expected. Same array/scalar footgun class
    # as the $badCount bug this file was written to catch, one layer up.
    $rows = @()
    if (Test-Path -LiteralPath $jsonOut) {
        $parsed = Get-Content -LiteralPath $jsonOut -Raw | ConvertFrom-Json
        $rows = @($parsed)
    }
    Assert-True 'recorded all three bundle binaries' ($rows.Count -eq 3) `
        ("got {0} row(s)" -f $rows.Count)

    function Get-Row { param([string]$Name) return ($rows | Where-Object { $_.name -eq $Name } | Select-Object -First 1) }

    $rStale  = Get-Row 'EaStale'
    $rFresh  = Get-Row 'EaFresh'
    $rOrphan = Get-Row 'EaOrphan'

    Assert-True 'bundle older than source is STALE' ($rStale -and $rStale.status -eq 'STALE') `
        ("status was '{0}'" -f $(if ($rStale) { $rStale.status } else { '<missing>' }))
    Assert-True 'STALE detail names the newer source file' `
        ([bool]($rStale -and $rStale.detail -match 'EaStale\.mq5'))
    Assert-True 'bundle newer than source is OK' ($rFresh -and $rFresh.status -eq 'OK') `
        ("status was '{0}'" -f $(if ($rFresh) { $rFresh.status } else { '<missing>' }))
    Assert-True 'bundle with no .mq5 anywhere is NO_SOURCE (not STALE)' `
        ($rOrphan -and $rOrphan.status -eq 'NO_SOURCE') `
        ("status was '{0}'" -f $(if ($rOrphan) { $rOrphan.status } else { '<missing>' }))

    # -----------------------------------------------------------------------
    # C. -OnlyName, the run-path entry point (ORDER-1461).
    #    mt5_run.ps1 prints this script's verdict in its launch banner, and can only
    #    afford to do that because -OnlyName narrows the scan to one name (0.7s against
    #    107s for the full sweep). Two things have to hold or the banner lies:
    #    narrowing must not change the VERDICT, in either direction, and it must not
    #    overwrite the full sweep's sidecar with its one name group.
    # -----------------------------------------------------------------------
    $oneJson = Join-Path $tmp 'one.json'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target `
        -Roots $fixDeploy -RepoRoot $fixRepo -JsonOut $oneJson -OnlyName 'EaStale' *> $null
    $oneExit = $LASTEXITCODE
    $oneRows = @()
    if (Test-Path -LiteralPath $oneJson) { $oneParsed = Get-Content -LiteralPath $oneJson -Raw | ConvertFrom-Json; $oneRows = @($oneParsed) }
    Assert-True '-OnlyName scans exactly the one name group' ($oneRows.Count -eq 1 -and $oneRows[0].name -eq 'EaStale') `
        ("got {0} row(s): {1}" -f $oneRows.Count, (($oneRows | ForEach-Object { $_.name }) -join ','))
    Assert-True '-OnlyName keeps the STALE verdict and the exit code' `
        ($oneExit -eq 2 -and $oneRows.Count -eq 1 -and $oneRows[0].status -eq 'STALE') `
        ("exit={0} status='{1}'" -f $oneExit, $(if ($oneRows.Count) { $oneRows[0].status } else { '<none>' }))

    # Specificity: narrowing must not manufacture staleness. A guard that only ever says
    # STALE is not a detector, and the run path prints this on EVERY launch.
    $okJson = Join-Path $tmp 'one_ok.json'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target `
        -Roots $fixDeploy -RepoRoot $fixRepo -JsonOut $okJson -OnlyName 'EaFresh' *> $null
    $okExit = $LASTEXITCODE
    $okRows = @()
    if (Test-Path -LiteralPath $okJson) { $okParsed = Get-Content -LiteralPath $okJson -Raw | ConvertFrom-Json; $okRows = @($okParsed) }
    Assert-True '-OnlyName on a fresh binary is OK and exits 0' `
        ($okExit -eq 0 -and $okRows.Count -eq 1 -and $okRows[0].status -eq 'OK') `
        ("exit={0} rows={1} status='{2}'" -f $okExit, $okRows.Count, $(if ($okRows.Count) { $okRows[0].status } else { '<none>' }))

    # The sidecar hazard. Without -JsonOut, a narrowed run would write ONE name group over
    # the full sweep's stale_binaries_check.json, leaving a file that still looks like the
    # audit and answers "nothing found" for every binary it silently stopped containing.
    # Asserted against the REAL default path, read-only, in both directions: if it exists it
    # must be byte-identical afterward; if it does not, it must not be created.
    $defaultSidecar = 'D:\EA_LAB\_mt5_auto\reports\stale_binaries_check.json'
    $sidecarBefore = if (Test-Path -LiteralPath $defaultSidecar) { (Get-FileHash -LiteralPath $defaultSidecar -Algorithm SHA256).Hash } else { '<absent>' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target `
        -Roots $fixDeploy -RepoRoot $fixRepo -OnlyName 'EaStale' *> $null
    $sidecarAfter = if (Test-Path -LiteralPath $defaultSidecar) { (Get-FileHash -LiteralPath $defaultSidecar -Algorithm SHA256).Hash } else { '<absent>' }
    Assert-True '-OnlyName without -JsonOut leaves the full sweep sidecar untouched' `
        ($sidecarBefore -eq $sidecarAfter) ("before={0} after={1}" -f $sidecarBefore, $sidecarAfter)
}
finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host ("[stale-binaries-tests] {0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail -gt 0) { exit 1 }
exit 0
