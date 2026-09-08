<# Focused fail-closed tests for the versioned TPL baseline contract. #>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
. (Join-Path $RepoRoot 'scripts\lib\tpl_baseline.ps1')

$template = Join-Path ([IO.Path]::GetTempPath()) ('tpl_baseline_fixture_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $template | Out-Null
function New-Fixture {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('tpl_baseline_case_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force (Join-Path $dir 'ea_template\sets\regression') | Out-Null
    New-Item -ItemType Directory -Force (Join-Path $dir 'ea_template\regression_reports\build6090') | Out-Null
    New-Item -ItemType Directory -Force (Join-Path $dir '_triage\factory_os') | Out-Null
    Get-ChildItem (Join-Path $RepoRoot 'ea_template\Boss_*.mq5') | Copy-Item -Destination (Join-Path $dir 'ea_template')
    Get-ChildItem (Join-Path $RepoRoot 'ea_template\sets\regression\*.set') | Copy-Item -Destination (Join-Path $dir 'ea_template\sets\regression')
    Get-ChildItem (Join-Path $RepoRoot 'ea_template\regression_reports\build6090\*.htm') | Copy-Item -Destination (Join-Path $dir 'ea_template\regression_reports\build6090')
    Get-ChildItem (Join-Path $RepoRoot 'ea_template\regression_baseline*.json'), (Join-Path $RepoRoot 'ea_template\regression_baseline_build6090.csv') | Copy-Item -Destination (Join-Path $dir 'ea_template')
    Copy-Item (Join-Path $RepoRoot '_triage\factory_os\wrapper_owners.csv') (Join-Path $dir '_triage\factory_os\wrapper_owners.csv')
    return $dir
}
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Write-Json([string]$Path, [object]$Value) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false))) }
function Expect-Refusal([string]$Name, [scriptblock]$Mutate) {
    $dir = New-Fixture
    try {
        & $Mutate $dir
        $ok = $false; $message = ''
        try { Get-TplActiveBaseline -Root $dir -ActiveSelectorPath (Join-Path $dir 'ea_template\regression_baseline.active.json') | Out-Null }
        catch { $message = $_.Exception.Message; $ok = $true }
        if (-not $ok) { throw "FAIL: $Name unexpectedly passed" }
        Write-Host "[PASS] $Name :: $message"
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
}
function Expect-Allowed([string]$Name, [scriptblock]$Mutate, [scriptblock]$Assert) {
    $dir = New-Fixture
    try {
        & $Mutate $dir
        try { $result = Get-TplActiveBaseline -Root $dir -ActiveSelectorPath (Join-Path $dir 'ea_template\regression_baseline.active.json') }
        catch { throw "FAIL: $Name unexpectedly refused: $($_.Exception.Message)" }
        & $Assert $result
        Write-Host "[PASS] $Name"
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
}
function Add-WrapperOwner([string]$Root, [string]$Tag, [string]$RelativePath) {
    Add-Content -LiteralPath (Join-Path $Root '_triage\factory_os\wrapper_owners.csv') -Value ("{0},{1}" -f $Tag,$RelativePath)
}
function New-LineageRepo {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('tpl_lineage_case_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force (Join-Path $dir 'ea_template\core') | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir 'README.md'), 'seed')
    [IO.File]::WriteAllText((Join-Path $dir 'ea_template\core\Seed.mqh'), '// seed')
    [IO.File]::WriteAllText((Join-Path $dir 'ea_template\Boss_11_Historical.mq5'), '// historical')
    & git init --quiet $dir
    & git -C $dir config user.name 'TPL lineage test'
    & git -C $dir config user.email 'tpl-lineage-test@example.invalid'
    & git -C $dir add .
    & git -C $dir commit --quiet -m initial
    if ($LASTEXITCODE -ne 0) { throw "failed to create lineage fixture: $dir" }
    return $dir
}
function Get-LineageHead([string]$Root) { return (& git -C $Root rev-parse HEAD).Trim() }
function Commit-LineageFile([string]$Root, [string]$RelativePath, [string]$Text, [string]$Message) {
    $path = Join-Path $Root ($RelativePath -replace '/', '\')
    New-Item -ItemType Directory -Force (Split-Path -Parent $path) | Out-Null
    [IO.File]::WriteAllText($path, $Text)
    & git -C $Root add -- $RelativePath
    & git -C $Root commit --quiet -m $Message
    if ($LASTEXITCODE -ne 0) { throw "failed lineage fixture commit: $Message" }
    return (Get-LineageHead $Root)
}
function New-LineageBaseline([string]$Tip, [string]$Base = '') {
    if (-not $Base) { $Base = $Tip }
    return [pscustomobject]@{ Manifest = [pscustomobject]@{
        baseline_source_commit = $Base
        accepted_runtime_lineage_tip = $Tip
        cases = @([pscustomobject]@{ ea = 'Boss_11_Historical'; source_path = 'ea_template/Boss_11_Historical.mq5' })
    } }
}
function Expect-SourceRefusal([string]$Name, [string]$Root, [string]$Tip, [string]$Base = '') {
    $refused = $false
    try { Assert-TplSourceContract -Root $Root -Baseline (New-LineageBaseline $Tip $Base) | Out-Null }
    catch { $refused = $true; Write-Host "[PASS] $Name :: $($_.Exception.Message)" }
    if (-not $refused) { throw "FAIL: $Name unexpectedly passed" }
}
function Expect-SourceAllowed([string]$Name, [string]$Root, [string]$Tip, [string]$Base = '') {
    try { Assert-TplSourceContract -Root $Root -Baseline (New-LineageBaseline $Tip $Base) | Out-Null; Write-Host "[PASS] $Name" }
    catch { throw "FAIL: $Name unexpectedly refused: $($_.Exception.Message)" }
}
function Invoke-GeneratorLineageProbe([string]$Root, [string]$SourceCommit, [string]$AcceptedTip) {
    $script = Join-Path $RepoRoot 'scripts\generate_tpl_baseline.ps1'
    $missingTerminal = Join-Path $Root 'missing-terminal.exe'
    $probeId = [guid]::NewGuid().ToString('N')
    $stdout = Join-Path ([IO.Path]::GetTempPath()) ('generator-' + $probeId + '.stdout.log')
    $stderr = Join-Path ([IO.Path]::GetTempPath()) ('generator-' + $probeId + '.stderr.log')
    $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script,
        '-RepoRoot', $Root, '-SourceCommit', $SourceCommit,
        '-AcceptedRuntimeLineageTip', $AcceptedTip, '-Terminal', $missingTerminal
    ) -RedirectStandardOutput $stdout -RedirectStandardError $stderr -Wait -PassThru -WindowStyle Hidden
    $output = @((Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue), (Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue))
    Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
    return [pscustomobject]@{ ExitCode = $proc.ExitCode; Output = (($output | Out-String).Trim()) }
}
function Expect-GeneratorLineageAllowed([string]$Name, [string]$Root, [string]$SourceCommit, [string]$AcceptedTip) {
    $probe = Invoke-GeneratorLineageProbe $Root $SourceCommit $AcceptedTip
    if ($probe.ExitCode -eq 0 -or $probe.Output -notmatch 'terminal not found') {
        throw "FAIL: $Name did not pass lineage preflight: exit=$($probe.ExitCode) output=$($probe.Output)"
    }
    Write-Host "[PASS] $Name :: lineage accepted before expected terminal refusal"
}
function Expect-GeneratorLineageRefusal([string]$Name, [string]$Root, [string]$SourceCommit, [string]$AcceptedTip) {
    $probe = Invoke-GeneratorLineageProbe $Root $SourceCommit $AcceptedTip
    if ($probe.ExitCode -eq 0 -or $probe.Output -notmatch 'not linearly related') {
        throw "FAIL: $Name did not refuse unrelated lineage: exit=$($probe.ExitCode) output=$($probe.Output)"
    }
    Write-Host "[PASS] $Name :: $($probe.Output)"
}

try {
    Expect-Refusal 'missing active manifest' { param($d) Remove-Item (Join-Path $d 'ea_template\regression_baseline.active.json') -Force }
    Expect-Refusal 'missing versioned metrics' { param($d) Remove-Item (Join-Path $d 'ea_template\regression_baseline_build6090.csv') -Force }
    Expect-Refusal 'corrupted metrics hash' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.csv'; $b=[IO.File]::ReadAllBytes($p); $b[20]=($b[20] -bxor 1); [IO.File]::WriteAllBytes($p,$b) }
    Expect-Refusal 'wrong MT5 build' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.expected_mt5_build=5836; Write-Json $p $m }
    Expect-Refusal 'Build-5836 report compared to Build-6090 reference' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].report_build=5836; Write-Json $p $m }
    Expect-Refusal 'wrong set hash' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].declared_set_sha256=('0'*64); Write-Json $p $m }
    Expect-Refusal 'undeclared set' { param($d) $set=Join-Path $d 'ea_template\sets\regression\Boss_11_GridTrend_defaults.set'; $lines=@(Get-Content $set | Where-Object { $_ -notmatch '^;\s*build=' }); [IO.File]::WriteAllLines($set,$lines); $hash=(Get-FileHash $set -Algorithm SHA256).Hash.ToLowerInvariant(); $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].declared_set_sha256=$hash; Write-Json $p $m }
    Expect-Refusal 'wrong source identity' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].source_commit='ac294d3a8f8e3a2b0dfa88860c2558e0646df6fb'; Write-Json $p $m }
    Expect-Refusal 'stale report' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].report_fresh=$false; Write-Json $p $m }
    Expect-Refusal 'tester contract mismatch' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.tester_contract.timeframe='M30'; Write-Json $p $m }
    Expect-Refusal 'duplicate historical manifest case' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases=@($m.cases)+@($m.cases[0]); Write-Json $p $m }
    Expect-Refusal 'metrics row count exceeds historical manifest cohort' { param($d) $csv=Join-Path $d 'ea_template\regression_baseline_build6090.csv'; Add-Content -LiteralPath $csv -Value 'Boss_20_New,0.00,1.00,0,0.00(0.00%)'; $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.metrics_sha256=(Get-FileHash $csv -Algorithm SHA256).Hash.ToLowerInvariant(); Write-Json $p $m }
    Expect-Refusal 'missing EA' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases=@($m.cases | Select-Object -Skip 1); Write-Json $p $m }
    Expect-Refusal 'extra EA' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].ea='Boss_99_Extra'; Write-Json $p $m }
    # B-F3 (Audit B): Get-TplExpectedEas used to gate on a literal wrapper COUNT ("-ne 8"),
    # which cannot see a same-count SWAP on disk. These three prove the replacement -- set
    # equality between disk and manifest -- actually fires for add, remove, AND a
    # count-preserving swap, with the manifest left untouched in every case.
    Expect-Refusal 'disk wrapper added (extra real-shaped file, manifest unchanged)' { param($d) Copy-Item (Join-Path $d 'ea_template\Boss_11_GridTrend.mq5') (Join-Path $d 'ea_template\Boss_99_Decoy.mq5') }
    Expect-Refusal 'malformed wrapper owner header' { param($d) $p=Join-Path $d '_triage\factory_os\wrapper_owners.csv'; $r=@(Get-Content $p); $r[0]='lab_entry,wrapper_path'; [IO.File]::WriteAllLines($p,$r) }
    Expect-Refusal 'three-field wrapper owner row' { param($d) $p=Join-Path $d '_triage\factory_os\wrapper_owners.csv'; Add-Content -LiteralPath $p -Value 'LAB_ENTRY_99,ea_template/Boss_99_Decoy.mq5,extra' }
    Expect-Allowed 'registered new Boss wrapper is tracked but not historically baselined' {
        param($d)
        Copy-Item (Join-Path $d 'ea_template\Boss_11_GridTrend.mq5') (Join-Path $d 'ea_template\Boss_20_New.mq5')
        Add-WrapperOwner $d 'LAB_ENTRY_20' 'ea_template/Boss_20_New.mq5'
    } {
        param($result)
        if (@($result.Manifest.cases).Count -ne 8 -or @($result.Metrics).Count -ne 8) { throw 'historical cohort cardinality changed' }
        $pending = @($result.RegisteredUnbaselinedEas)
        if ($pending.Count -ne 1 -or $pending[0].Name -ne 'Boss_20_New' -or $pending[0].Tag -ne 'LAB_ENTRY_20' -or $pending[0].SourcePath -ne 'ea_template/Boss_20_New.mq5') {
            throw 'registered unbaselined wrapper was not returned explicitly'
        }
    }
    Expect-Refusal 'registered wrapper path with mismatched LAB_ENTRY tag' { param($d) Copy-Item (Join-Path $d 'ea_template\Boss_11_GridTrend.mq5') (Join-Path $d 'ea_template\Boss_20_New.mq5'); Add-WrapperOwner $d 'LAB_ENTRY_21' 'ea_template/Boss_20_New.mq5' }
    Expect-Refusal 'duplicate wrapper registration by build tag' { param($d) Copy-Item (Join-Path $d 'ea_template\Boss_11_GridTrend.mq5') (Join-Path $d 'ea_template\Boss_20_New.mq5'); Add-WrapperOwner $d 'LAB_ENTRY_20' 'ea_template/Boss_20_New.mq5'; Add-WrapperOwner $d 'LAB_ENTRY_20' 'ea_template/Boss_20_Other.mq5' }
    Expect-Refusal 'duplicate wrapper registration by exact path' { param($d) Copy-Item (Join-Path $d 'ea_template\Boss_11_GridTrend.mq5') (Join-Path $d 'ea_template\Boss_20_New.mq5'); Add-WrapperOwner $d 'LAB_ENTRY_20' 'ea_template/Boss_20_New.mq5'; Add-WrapperOwner $d 'LAB_ENTRY_21' 'ea_template/Boss_20_New.mq5' }
    Expect-Refusal 'historical Boss wrapper missing owner registration' { param($d) $p=Join-Path $d '_triage\factory_os\wrapper_owners.csv'; $lines=@(Get-Content -LiteralPath $p); $lines=@($lines | Where-Object { $_ -notmatch '^LAB_ENTRY_15,' }); [IO.File]::WriteAllLines($p,$lines,(New-Object Text.UTF8Encoding($false))) }
    Expect-Refusal 'disk wrapper removed (manifest unchanged)' { param($d) Remove-Item (Join-Path $d 'ea_template\Boss_15_ST03.mq5') -Force }
    Expect-Refusal 'disk wrapper swapped for a same-count decoy (manifest unchanged)' { param($d) Remove-Item (Join-Path $d 'ea_template\Boss_15_ST03.mq5') -Force; Copy-Item (Join-Path $d 'ea_template\Boss_11_GridTrend.mq5') (Join-Path $d 'ea_template\Boss_15_Decoy.mq5') }
    Expect-Refusal 'malformed manifest' { param($d) [IO.File]::WriteAllText((Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'), '{not-json') }
    Expect-Refusal 'incomplete provenance' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].report_sha256=$null; Write-Json $p $m }
    $lineage = New-LineageRepo
    try {
        $tip = Get-LineageHead $lineage
        Expect-SourceRefusal 'missing lineage tip' $lineage ''
        Expect-SourceRefusal 'malformed lineage tip' $lineage 'not-a-commit-sha'

        Expect-SourceAllowed 'baseline source equals HEAD' $lineage $tip $tip

        $mainBranch = (& git -C $lineage branch --show-current).Trim()
        & git -C $lineage checkout --quiet -b side
        $sideTip = Commit-LineageFile $lineage 'side.txt' 'side' 'side lineage'
        & git -C $lineage checkout --quiet $mainBranch
        $mainTip = Commit-LineageFile $lineage 'README.md' 'mainline' 'non-protected lineage'
        Expect-SourceRefusal 'valid non-ancestor lineage tip' $lineage $sideTip
        Expect-SourceAllowed 'baseline ancestor with non-protected descendant' $lineage $tip $tip

        $protectedTip = Commit-LineageFile $lineage 'ea_template/core/Changed.mqh' '// protected' 'protected lineage'
        Expect-SourceRefusal 'protected EA change after baseline source' $lineage $tip $tip
        Expect-SourceRefusal 'runtime tip not ancestor of baseline source' $lineage $sideTip $tip

        & git -C $lineage checkout --quiet -b source-contract-side $tip
        $sideCurrent = Commit-LineageFile $lineage 'side-current.txt' 'side-current' 'side current'
        Expect-SourceRefusal 'baseline source not ancestor of current HEAD' $lineage $tip $mainTip

        $adjacent = New-LineageRepo
        try {
            $adjacentBase = Get-LineageHead $adjacent
            $adjacentControl = Commit-LineageFile $adjacent 'control.txt' 'control' 'adjacent control'
            [IO.File]::WriteAllText((Join-Path $adjacent 'ea_template\Boss_20_New.mq5'), '// new wrapper')
            [IO.File]::WriteAllText((Join-Path $adjacent 'ea_template\core\Seed.mqh'), '// changed with Boss20')
            & git -C $adjacent add -- ea_template/Boss_20_New.mq5 ea_template/core/Seed.mqh
            & git -C $adjacent commit --quiet -m 'new registered Boss wrapper and associated core change'
            $unbaselined = @([pscustomobject]@{ Name='Boss_20_New'; Tag='LAB_ENTRY_20'; SourcePath='ea_template/Boss_20_New.mq5' })
            Expect-SourceRefusal 'default source contract still refuses registered new behavioral Boss' $adjacent $adjacentBase $adjacentBase
            try {
                Assert-TplSourceContract -Root $adjacent -Baseline (New-LineageBaseline $adjacentBase $adjacentBase) -AdjacentControlRef $adjacentControl -RegisteredUnbaselinedEas $unbaselined | Out-Null
                Write-Host '[PASS] adjacent control allows one registered new Boss plus associated core change'
            } catch { throw "FAIL: valid adjacent control unexpectedly refused: $($_.Exception.Message)" }
            $noPendingRefused = $false
            try { Assert-TplSourceContract -Root $adjacent -Baseline (New-LineageBaseline $adjacentBase $adjacentBase) -AdjacentControlRef $adjacentControl -RegisteredUnbaselinedEas @() | Out-Null }
            catch { $noPendingRefused = $true; Write-Host "[PASS] adjacent control refuses core change without registered unbaselined Boss :: $($_.Exception.Message)" }
            if (-not $noPendingRefused) { throw 'FAIL: adjacent control allowed core change without registered unbaselined Boss' }
            $shortRefused = $false
            try { Assert-TplSourceContract -Root $adjacent -Baseline (New-LineageBaseline $adjacentBase $adjacentBase) -AdjacentControlRef $adjacentControl.Substring(0,12) -RegisteredUnbaselinedEas $unbaselined | Out-Null }
            catch { $shortRefused = $true; Write-Host "[PASS] adjacent control refuses abbreviated SHA :: $($_.Exception.Message)" }
            if (-not $shortRefused) { throw 'FAIL: adjacent control allowed abbreviated SHA' }
        } finally { Remove-Item -LiteralPath $adjacent -Recurse -Force -ErrorAction SilentlyContinue }

        $adjacentOld = New-LineageRepo
        try {
            $oldBase = Get-LineageHead $adjacentOld
            $oldControl = Commit-LineageFile $adjacentOld 'first.txt' 'first' 'first parent'
            Commit-LineageFile $adjacentOld 'second.txt' 'second' 'actual control' | Out-Null
            Commit-LineageFile $adjacentOld 'ea_template/Boss_20_New.mq5' '// new wrapper' 'new wrapper plus protected source' | Out-Null
            $pending = @([pscustomobject]@{ Name='Boss_20_New'; Tag='LAB_ENTRY_20'; SourcePath='ea_template/Boss_20_New.mq5' })
            $refused = $false
            try { Assert-TplSourceContract -Root $adjacentOld -Baseline (New-LineageBaseline $oldBase $oldBase) -AdjacentControlRef $oldControl -RegisteredUnbaselinedEas $pending | Out-Null }
            catch { $refused = $true; Write-Host "[PASS] adjacent control refuses non-parent commit :: $($_.Exception.Message)" }
            if (-not $refused) { throw 'FAIL: adjacent control allowed a non-parent commit' }
        } finally { Remove-Item -LiteralPath $adjacentOld -Recurse -Force -ErrorAction SilentlyContinue }

        $adjacentHistorical = New-LineageRepo
        try {
            $historicalBase = Get-LineageHead $adjacentHistorical
            $historicalControl = Commit-LineageFile $adjacentHistorical 'control.txt' 'control' 'adjacent control'
            [IO.File]::WriteAllText((Join-Path $adjacentHistorical 'ea_template\Boss_11_Historical.mq5'), '// changed historical')
            [IO.File]::WriteAllText((Join-Path $adjacentHistorical 'ea_template\Boss_20_New.mq5'), '// new wrapper')
            & git -C $adjacentHistorical add -- ea_template/Boss_11_Historical.mq5 ea_template/Boss_20_New.mq5
            & git -C $adjacentHistorical commit --quiet -m 'changed historical and added new wrapper'
            $pending = @([pscustomobject]@{ Name='Boss_20_New'; Tag='LAB_ENTRY_20'; SourcePath='ea_template/Boss_20_New.mq5' })
            $refused = $false
            try { Assert-TplSourceContract -Root $adjacentHistorical -Baseline (New-LineageBaseline $historicalBase $historicalBase) -AdjacentControlRef $historicalControl -RegisteredUnbaselinedEas $pending | Out-Null }
            catch { $refused = $true; Write-Host "[PASS] adjacent control refuses changed historical Boss :: $($_.Exception.Message)" }
            if (-not $refused) { throw 'FAIL: adjacent control allowed a changed historical Boss wrapper' }
        } finally { Remove-Item -LiteralPath $adjacentHistorical -Recurse -Force -ErrorAction SilentlyContinue }

        $adjacentExisting = New-LineageRepo
        try {
            $existingBase = Get-LineageHead $adjacentExisting
            Commit-LineageFile $adjacentExisting 'ea_template/Boss_20_New.mq5' '// already present' 'register wrapper before control' | Out-Null
            $existingControl = Get-LineageHead $adjacentExisting
            Commit-LineageFile $adjacentExisting 'ea_template/core/Seed.mqh' '// later arbitrary core change' 'later arbitrary core change' | Out-Null
            $pending = @([pscustomobject]@{ Name='Boss_20_New'; Tag='LAB_ENTRY_20'; SourcePath='ea_template/Boss_20_New.mq5' })
            $refused = $false
            try { Assert-TplSourceContract -Root $adjacentExisting -Baseline (New-LineageBaseline $existingBase $existingBase) -AdjacentControlRef $existingControl -RegisteredUnbaselinedEas $pending | Out-Null }
            catch { $refused = $true; Write-Host "[PASS] adjacent control refuses unrelated later core change :: $($_.Exception.Message)" }
            if (-not $refused) { throw 'FAIL: adjacent control allowed unrelated later core change' }
        } finally { Remove-Item -LiteralPath $adjacentExisting -Recurse -Force -ErrorAction SilentlyContinue }

        $generatorF = New-LineageRepo
        try {
            $generatorFTip = Get-LineageHead $generatorF
            $generatorFSource = Commit-LineageFile $generatorF 'local.txt' 'local' 'local candidate'
            & git -C $generatorF update-ref refs/remotes/origin/master $generatorFTip
            Expect-GeneratorLineageAllowed 'local SourceCommit descendant of origin/master' $generatorF $generatorFSource $generatorFTip
        } finally { Remove-Item -LiteralPath $generatorF -Recurse -Force -ErrorAction SilentlyContinue }

        $generatorG = New-LineageRepo
        try {
            $generatorGSource = Get-LineageHead $generatorG
            & git -C $generatorG checkout --quiet -b origin-history
            $generatorGOrigin = Commit-LineageFile $generatorG 'origin.txt' 'origin' 'origin history'
            & git -C $generatorG checkout --quiet $generatorGSource
            & git -C $generatorG update-ref refs/remotes/origin/master $generatorGOrigin
            Expect-GeneratorLineageAllowed 'SourceCommit ancestor of origin/master' $generatorG $generatorGSource $generatorGSource
        } finally { Remove-Item -LiteralPath $generatorG -Recurse -Force -ErrorAction SilentlyContinue }

        $generatorH = New-LineageRepo
        try {
            $generatorHTip = Get-LineageHead $generatorH
            & git -C $generatorH checkout --quiet --orphan unrelated
            & git -C $generatorH rm -r --cached . 2>$null | Out-Null
            [IO.File]::WriteAllText((Join-Path $generatorH 'unrelated.txt'), 'unrelated')
            & git -C $generatorH add .
            & git -C $generatorH commit --quiet -m unrelated
            $generatorHSource = Get-LineageHead $generatorH
            & git -C $generatorH update-ref refs/remotes/origin/master $generatorHTip
            Expect-GeneratorLineageRefusal 'unrelated source and origin histories' $generatorH $generatorHSource $generatorHTip
        } finally { Remove-Item -LiteralPath $generatorH -Recurse -Force -ErrorAction SilentlyContinue }
    } finally { Remove-Item -LiteralPath $lineage -Recurse -Force -ErrorAction SilentlyContinue }

    $ownerFiles = @(
        (Join-Path $RepoRoot 'ea_template\regression_baseline_build6090.manifest.json'),
        (Join-Path $RepoRoot 'scripts\generate_tpl_baseline.ps1'),
        (Join-Path $RepoRoot 'scripts\lib\tpl_baseline.ps1')
    )
    $oldOwnerHit = @(Select-String -Path $ownerFiles -SimpleMatch 'ac294d3a8f8e3a2b0dfa88860c2558e0646df6fb')
    if ($oldOwnerHit.Count -gt 0) { throw 'FAIL: old orphan lineage SHA remains in an active owner' }
    Write-Host '[PASS] old orphan lineage SHA absent from active owners'
    Write-Host 'TPL BASELINE CONTRACT TESTS: existing negative coverage plus A-H PASS' -ForegroundColor Green
    exit 0
} finally { Remove-Item -LiteralPath $template -Recurse -Force -ErrorAction SilentlyContinue }
