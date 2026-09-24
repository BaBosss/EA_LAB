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
    # The synthetic new-Boss cases own their new tags. Do not import unrelated live
    # unbaselined wrappers (e.g. a real Boss20) into the historical fixture cohort.
    $historical = (Get-Content (Join-Path $RepoRoot 'ea_template\regression_baseline_build6090.manifest.json') -Raw | ConvertFrom-Json).cases
    foreach ($case in $historical) { Copy-Item -LiteralPath (Join-Path $RepoRoot $case.source_path) -Destination (Join-Path $dir 'ea_template') }
    Get-ChildItem (Join-Path $RepoRoot 'ea_template\sets\regression\*.set') | Copy-Item -Destination (Join-Path $dir 'ea_template\sets\regression')
    Get-ChildItem (Join-Path $RepoRoot 'ea_template\regression_reports\build6090\*.htm') | Copy-Item -Destination (Join-Path $dir 'ea_template\regression_reports\build6090')
    Get-ChildItem (Join-Path $RepoRoot 'ea_template\regression_baseline*.json'), (Join-Path $RepoRoot 'ea_template\regression_baseline_build6090.csv') | Copy-Item -Destination (Join-Path $dir 'ea_template')
    $owners = @('build_tag,wrapper_rel') + @($historical | ForEach-Object {
        if ($_.ea -notmatch '^Boss_(\d+)_') { throw 'malformed historical fixture identity' }
        'LAB_ENTRY_' + $Matches[1] + ',' + $_.source_path
    })
    [IO.File]::WriteAllLines((Join-Path $dir '_triage\factory_os\wrapper_owners.csv'), $owners)
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
function New-DeclaredDeltaFixture {
    $dir = New-Fixture
    New-Item -ItemType Directory -Force (Join-Path $dir 'ea_template/core'), (Join-Path $dir 'scripts/lib') | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir 'ea_template/core/Seed.mqh'), '// control')
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts/tpl_regression.ps1') -Destination (Join-Path $dir 'scripts')
    foreach ($lib in @('tpl_baseline.ps1','evidence.ps1','setfile_surface.ps1')) {
        Copy-Item -LiteralPath (Join-Path $RepoRoot "scripts/lib/$lib") -Destination (Join-Path $dir 'scripts/lib')
    }
    & git -C $dir init --quiet
    & git -C $dir config user.name 'TPL declared delta fixture'
    & git -C $dir config user.email 'tpl-delta@example.invalid'
    & git -C $dir config core.autocrlf false
    & git -C $dir add .
    & git -C $dir commit --quiet -m 'synthetic baseline source'
    if ($LASTEXITCODE -ne 0) { throw 'delta fixture seed commit failed' }
    $seed = Get-LineageHead $dir
    $manifestPath = Join-Path $dir 'ea_template/regression_baseline_build6090.manifest.json'
    $manifest = Read-Json $manifestPath
    $manifest.baseline_source_commit = $seed
    $manifest.accepted_runtime_lineage_tip = $seed
    foreach ($case in $manifest.cases) { $case.source_commit = $seed }
    Write-Json $manifestPath $manifest
    & git -C $dir add .
    & git -C $dir commit --quiet -m 'synthetic canonical provenance control'
    if ($LASTEXITCODE -ne 0) { throw 'delta fixture control commit failed' }
    return [pscustomobject]@{ Root=$dir; Seed=$seed; Control=(Get-LineageHead $dir) }
}
function Invoke-DeclaredDeltaCase([string]$Name, [scriptblock]$Arrange, [string]$Refusal = '') {
    $fixture = New-DeclaredDeltaFixture
    $d = $fixture.Root
    try {
        $source = Commit-LineageFile $d 'ea_template/core/Seed.mqh' '// declared change' 'exact declared delta'
        $call = @{ Root=$d; Baseline=(Get-TplActiveBaseline $d); DeclaredCoreDelta=$true;
            ControlCommit=$fixture.Control; SourceCommit=$source; BehavioralDeltaPaths=@('ea_template/core/Seed.mqh') }
        & $Arrange $fixture $call
        $failure = ''
        try { $actual = Assert-TplSourceContract @call }
        catch { $failure = $_.Exception.Message }
        if ($Refusal) {
            if (-not $failure -or $failure -notmatch $Refusal) { throw "FAIL: $Name expected '$Refusal', got '$failure'" }
        } elseif ($failure -or $actual -cne $call.SourceCommit) { throw "FAIL: $Name unexpectedly refused: $failure" }
        $script:deltaPass++
        Write-Host "[PASS] Contract1 $Name :: $failure"
    } finally {
        $resolved = [IO.Path]::GetFullPath($d)
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'tpl_baseline_case_*') { throw 'unsafe delta fixture cleanup' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
function Add-DeltaCommit([object]$Fixture, [hashtable]$Call, [string]$Path) {
    # Keep an exact adjacent pair while introducing the extra change in that pair.
    $Call.ControlCommit = $Call.SourceCommit
    [IO.File]::WriteAllText((Join-Path $Fixture.Root 'ea_template/core/Seed.mqh'), '// next declared change')
    $target = Join-Path $Fixture.Root $Path
    New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
    [IO.File]::WriteAllText($target, '// undeclared change')
    & git -C $Fixture.Root add .
    & git -C $Fixture.Root commit --quiet -m 'extra behavioral delta'
    if ($LASTEXITCODE -ne 0) { throw 'extra delta fixture commit failed' }
    $Call.SourceCommit = Get-LineageHead $Fixture.Root
}
function Test-DeclaredDeltaCases {
    $script:deltaPass = 0
    Invoke-DeclaredDeltaCase 'C exact declared core delta' { }
    Invoke-DeclaredDeltaCase 'D undeclared core' { param($f,$c) Add-DeltaCommit $f $c 'ea_template/core/Extra.mqh' } 'undeclared behavioral delta'
    Invoke-DeclaredDeltaCase 'E extra Boss' { param($f,$c) Add-DeltaCommit $f $c 'ea_template/Boss_11_GridTrend.mq5' } 'source hash mismatch'
    Invoke-DeclaredDeltaCase 'F extra entry' { param($f,$c) Add-DeltaCommit $f $c 'ea_template/EA_LabTemplate.mq5' } 'undeclared behavioral delta'
    Invoke-DeclaredDeltaCase 'G expected delta absent' { param($f,$c) $c.BehavioralDeltaPaths += 'ea_template/core/Absent.mqh' } 'delta absent'
    Invoke-DeclaredDeltaCase 'H wrong control SHA' { param($f,$c) $c.ControlCommit=$f.Seed } 'single immediate parent'
    Invoke-DeclaredDeltaCase 'I wrong source SHA' { param($f,$c) $c.SourceCommit=$f.Control } 'exact HEAD'
    Invoke-DeclaredDeltaCase 'J empty declaration' { param($f,$c) $c.BehavioralDeltaPaths=@() } 'nonempty behavioral'
    Invoke-DeclaredDeltaCase 'K duplicate declaration' { param($f,$c) $c.BehavioralDeltaPaths += $c.BehavioralDeltaPaths[0] } 'duplicate behavioral'
    Invoke-DeclaredDeltaCase 'L traversal' { param($f,$c) $c.BehavioralDeltaPaths=@('ea_template/core/../core/Seed.mqh') } 'noncanonical literal'
    Invoke-DeclaredDeltaCase 'M absolute path' { param($f,$c) $c.BehavioralDeltaPaths=@((Join-Path $f.Root 'ea_template/core/Seed.mqh')) } 'noncanonical literal'
    Invoke-DeclaredDeltaCase 'N outside repository' { param($f,$c) $c.BehavioralDeltaPaths=@('../elsewhere/Seed.mqh') } 'noncanonical literal'
    Invoke-DeclaredDeltaCase 'O selector mismatch' { param($f,$c) Add-Content -LiteralPath (Join-Path $f.Root 'ea_template/regression_baseline.active.json') ' ' } 'working source bytes'
    Invoke-DeclaredDeltaCase 'O baseline source mismatch' { param($f,$c) $c.Baseline.Manifest.baseline_source_commit=$c.SourceCommit } 'canonical selector/source'
    Invoke-DeclaredDeltaCase 'P deterministic repeat and ValidateOnly public route' {
        param($f,$c)
        $first = Assert-TplSourceContract @c
        $second = Assert-TplSourceContract @c
        $treeBefore = (& git -C $f.Root rev-parse 'HEAD^{tree}').Trim()
        $command = Join-Path $f.Root 'scripts/tpl_regression.ps1'
        $output = & powershell -NoProfile -File $command -ValidateOnly -DeclaredCoreDelta -ControlCommit $c.ControlCommit -SourceCommit $c.SourceCommit -BehavioralDeltaPaths 'ea_template/core/Seed.mqh' 2>&1
        $code = $LASTEXITCODE
        $treeAfter = (& git -C $f.Root rev-parse 'HEAD^{tree}').Trim()
        $dirty = @(& git -C $f.Root status --porcelain --untracked-files=all)
        if ($code -ne 0 -or ($output | Out-String) -notmatch 'STRUCTURALLY READY; RUNTIME CONTROL\+CURRENT RUN REQUIRED' -or $first -cne $second -or $treeBefore -cne $treeAfter -or $dirty.Count) {
            throw "FAIL: repeat/ValidateOnly identity mismatch: exit=$code output=$output"
        }
        Write-Host ('REPEATABILITY ' + (@{ control=$c.ControlCommit; source=$first; tree_before=$treeBefore; tree_after=$treeAfter; invocations=3; validate_only_exit=$code; clean=$true } | ConvertTo-Json -Compress))
    }
    Invoke-DeclaredDeltaCase 'Q matching output arbitrary control' {
        param($f,$c)
        # Both refs contain byte-identical archived metrics. That cannot select a control.
        $metric='ea_template/regression_baseline_build6090.csv'
        $a=& git -C $f.Root rev-parse ($f.Seed + ':' + $metric)
        $b=& git -C $f.Root rev-parse ($c.SourceCommit + ':' + $metric)
        if ($a -cne $b) { throw 'matching-output fixture did not match' }
        $c.ControlCommit=$f.Seed
    } 'single immediate parent'
    Invoke-DeclaredDeltaCase 'case-alias duplicate' { param($f,$c) $c.BehavioralDeltaPaths += 'EA_TEMPLATE/CORE/SEED.MQH' } 'duplicate behavioral'
    Invoke-DeclaredDeltaCase 'case alias' { param($f,$c) $c.BehavioralDeltaPaths=@('ea_template/core/seed.mqh') } 'case-aliased'
    Invoke-DeclaredDeltaCase 'backslash spelling' { param($f,$c) $c.BehavioralDeltaPaths=@('ea_template\core\Seed.mqh') } 'noncanonical literal'
    Invoke-DeclaredDeltaCase 'wildcard declaration' { param($f,$c) $c.BehavioralDeltaPaths=@('ea_template/core/*.mqh') } 'noncanonical literal'
    Invoke-DeclaredDeltaCase 'undeclared generated' { param($f,$c) Add-DeltaCommit $f $c 'ea_template/generated/Extra.mqh' } 'undeclared behavioral delta'
    Invoke-DeclaredDeltaCase 'undeclared module' { param($f,$c) Add-DeltaCommit $f $c 'ea_template/modules/Extra.mqh' } 'undeclared behavioral delta'
    Invoke-DeclaredDeltaCase 'dirty source bytes' { param($f,$c) Add-Content -LiteralPath (Join-Path $f.Root 'ea_template/core/Seed.mqh') '// hidden' } 'working source bytes'
    Invoke-DeclaredDeltaCase 'assume unchanged cannot hide bytes' { param($f,$c) & git -C $f.Root update-index --assume-unchanged ea_template/core/Seed.mqh; Add-Content -LiteralPath (Join-Path $f.Root 'ea_template/core/Seed.mqh') '// hidden' } 'working source bytes'
    Invoke-DeclaredDeltaCase 'staged source with clean disk' {
        param($f,$c)
        $p=Join-Path $f.Root 'ea_template/core/Seed.mqh'; $bytes=[IO.File]::ReadAllBytes($p)
        Add-Content -LiteralPath $p '// staged'; & git -C $f.Root add -- ea_template/core/Seed.mqh
        [IO.File]::WriteAllBytes($p,$bytes)
    } 'staged source/provenance'
    Invoke-DeclaredDeltaCase 'untracked behavioral' { param($f,$c) [IO.File]::WriteAllText((Join-Path $f.Root 'ea_template/core/Hidden.mqh'),'// hidden') } 'untracked/case-aliased'
    Invoke-DeclaredDeltaCase 'ignored behavioral' { param($f,$c) [IO.File]::WriteAllText((Join-Path $f.Root '.git/info/exclude'),'ea_template/core/Hidden.mqh'); [IO.File]::WriteAllText((Join-Path $f.Root 'ea_template/core/Hidden.mqh'),'// hidden') } 'untracked/case-aliased'
    Invoke-DeclaredDeltaCase 'unrelated nonbehavioral allowance' { param($f,$c) [IO.File]::WriteAllText((Join-Path $f.Root 'notes.txt'),'notes') }
    Invoke-DeclaredDeltaCase 'missing mode never falls back' { param($f,$c) $c.Remove('DeclaredCoreDelta') } 'explicit mode'
    Invoke-DeclaredDeltaCase 'invalid mode never enters legacy' { param($f,$c) $c.DeclaredCoreDelta=$false; $c.AdjacentControlRef=$f.Control } 'explicit mode'
    Invoke-DeclaredDeltaCase 'mixed legacy and declared' { param($f,$c) $c.AdjacentControlRef=$f.Control } 'cannot mix'
    Invoke-DeclaredDeltaCase 'revision expression' { param($f,$c) $c.ControlCommit='HEAD^' } 'exact lowercase 40-hex'
    Invoke-DeclaredDeltaCase 'abbreviated source' { param($f,$c) $c.SourceCommit=$c.SourceCommit.Substring(0,12) } 'exact lowercase 40-hex'
    Invoke-DeclaredDeltaCase 'whitespace SHA' { param($f,$c) $c.ControlCommit=' '+$c.ControlCommit } 'exact lowercase 40-hex'
    Invoke-DeclaredDeltaCase 'nonbehavioral declaration' { param($f,$c) $c.BehavioralDeltaPaths=@('README.md') } 'outside behavioral source'
    Invoke-DeclaredDeltaCase 'committed selector replacement' {
        param($f,$c)
        $c.ControlCommit=$c.SourceCommit
        Add-Content -LiteralPath (Join-Path $f.Root 'ea_template/regression_baseline.active.json') ' '
        $c.SourceCommit=Commit-LineageFile $f.Root 'ea_template/core/Seed.mqh' '// next' 'next delta'
        & git -C $f.Root add .
        & git -C $f.Root commit --quiet -m 'changed selector'
        if ($LASTEXITCODE -ne 0) { throw 'selector fixture commit failed' }
        $c.ControlCommit=(& git -C $f.Root rev-parse 'HEAD^').Trim()
        $c.SourceCommit=Get-LineageHead $f.Root
    } 'canonical baseline provenance changed'
    Write-Host "TPL DECLARED DELTA TESTS: $script:deltaPass/$script:deltaPass PASS (A/B covered by unchanged legacy assertions)"
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

    Test-DeclaredDeltaCases
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
