<#
run_registry_tests.ps1 - ORDER-630 (slice S5), the CONSUMER half of R4.

_triage\factory_os\run_registry_tests.py proves the resolver answers correctly and that
check_registries' five criteria can each go red. Neither of those proves the thing the design
row actually asks for: that optimize_guard READS that answer and acts on it.

  A  CONTROL, and it is the load-bearing one. With no -HypothesisRevision, this script's output
     must be IDENTICAL to before the wiring existed -- every existing call site passes no
     revision, and a guard that quietly changed its verdicts would be far worse than one that
     never gained the feature. Asserted by running the same arguments twice, once with a
     revision that has no bindings, and comparing the verdict lines.

  B  A LOCKED binding must turn an otherwise-ALLOWed parameter into REFUSE, naming the resolver.
     This is the per-hypothesis point of the whole ParameterBinding entity.

  C  SPECIFICITY. A TUNABLE binding on the same parameter must NOT refuse it. Without this, B
     would be satisfied by a wiring that refuses everything it touches
     (memory: gate-specificity-not-just-sensitivity).

  D  FAIL CLOSED. A revision was named but the resolver cannot be reached => throw. "I could not
     read the bindings" must never be published as "there are no bindings".

The synthetic bindings live in a temp tree reached through -BindingsRoot, so nothing writes into
the committed store. That seam cannot buy permission -- see the parameter's own comment.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_registry_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if ($RepoRoot -eq '') { $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }

$script:pass = 0
$script:fail = 0

# ORDER-670: the tier-verifiable evidence-mode marker. Emitted by running evidence.for_run()
# in THIS suite's own process chain, so it proves the mode ARRIVED through hook -> tier ->
# suite -> python -- not what this wrapper believes. If python or the module is broken the
# marker is absent and the tier fails closed naming this suite.
$pyExe = Join-Path $RepoRoot 'tools\python312\python.exe'
& $pyExe -c "import sys, os; sys.path.insert(0, os.path.join(r'$RepoRoot', '_triage', 'factory_os')); import evidence; print(evidence.EvidenceSource.for_run().marker('run_registry_tests.ps1'))"
function Ok([string]$n, $c) {
    if ($c) { $script:pass++; Write-Host "   [PASS] $n" }
    else { $script:fail++; Write-Host "   [FAIL] $n" }
}

$guard = Join-Path $RepoRoot 'scripts\optimize_guard.ps1'
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("s5cons_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $work 'factory') -Force | Out-Null

# A parameter that is ALLOW today, so the binding is the only thing that can change its verdict.
# Chosen by RUNNING the guard below, not by reading the registry -- if it ever stops being ALLOW,
# the control assertion goes red and says so rather than the test silently proving nothing.
# MEASURED, not assumed: `TrendFilter` was the first choice and the PRE-CHECK below caught that
# it is REFUSE at build 16 (inert per PARAM_INACTIVE_AUDIT). With an already-refused parameter,
# case C ("a TUNABLE binding does not refuse") could never have discriminated -- it would have
# been a green assertion proving nothing. The pre-check exists so that choice is made by running
# the guard rather than by reading the registry and hoping.
$param = '_2_BasketTP_ATRmult'
$build = '14'
$rev = 'B14-H01-r1'

function Seed([string]$role) {
    $stores = @('universe','instrument_profiles','hypotheses','parameter_bindings','coverage')
    foreach ($s in $stores) {
        Set-Content -LiteralPath (Join-Path $work "factory\$s.jsonl") -Encoding ASCII `
            -Value '{"_comment": "synthetic fixture for run_registry_tests.ps1"}'
    }
    if ($role -ne '') {
        $row = '{"definition_ref": {"blob_oid": "' + ('0'*40) + '", "commit_oid": "' + ('0'*40) +
               '", "entity": "OwnerRef", "owner_type": "param_registry", "path": "docs/PARAM_REGISTRY.csv", "raw_sha256": "' + ('0'*64) +
               '"}, "entity": "ParameterBinding", "hypothesis_revision": "' + $rev +
               '", "locked_value": 1, "parameter": "' + $param + '", "role": "' + $role + '", "surface": "RESEARCH"}'
        Add-Content -LiteralPath (Join-Path $work 'factory\parameter_bindings.jsonl') -Encoding ASCII -Value $row
    }
}

function RunGuard([string[]]$extra) {
    $a = @('-NoProfile','-File',$guard,'-ParamNames',$param,'-Build',$build,'-WarnOnly') + $extra
    $out = & powershell $a 2>&1
    return (@($out) -join "`n")
}

try {
Write-Host '=== ORDER-630 (S5) R4 consumer half: optimize_guard reads the ONE resolver ==='

Seed ''
$base = RunGuard @()
Ok "PRE-CHECK: '$param' is ALLOW with no binding, so a binding is the only thing that can change it" `
    ($base -match "\[ALLOW\] $param")

Write-Host '   -- A: declaring a revision that binds NOTHING now REFUSES (ORDER-671) --'
$withEmpty = RunGuard @('-HypothesisRevision', $rev, '-BindingsRoot', $work)
# SUPERSEDED BY OWNER DECISION, and rewritten rather than deleted. This case used to assert
# 'a revision with ZERO bindings changes not one verdict line' -- true of the old behaviour and
# FALSE of the ratified one, because declaring a revision is now a claim of attribution that an
# empty binding set cannot support. Keeping it would have been a test asserting the rule the
# owner replaced.
Ok 'A a revision that binds NOTHING refuses every swept parameter, rather than passing silently' `
    ($withEmpty -match "\[REFUSE\] $([regex]::Escape($param))")
Ok 'A and it still SAYS it consulted the resolver, rather than being silently inert' `
    ($withEmpty -match 'BINDINGS: .* resolved 0 ParameterBinding row')
Ok 'A SPECIFICITY the UNDECLARED run is untouched -- that is the whole scope of the change' `
    ($base -match "\[ALLOW\] $([regex]::Escape($param))")

Write-Host '   -- A2: an UNBOUND parameter under a DECLARED revision must not be SILENT --'
# FOUND BY A BLIND AUDIT and reproduced before acceptance: case A above proves the verdict does not
# change, and that was read as the whole story. It is not. registry.py returns optimizable=$null /
# source=UNBOUND precisely so permission is never granted BY SILENCE, and this consumer was
# dropping that $null -- so a run declared to belong to a revision swept a parameter that revision
# never described and NOTHING said so. Case A remains true and is now insufficient on its own; both
# halves are asserted together so neither can be quoted without the other.
Ok 'A2 an UNBOUND parameter under a declared revision is NAMED in the output' `
    ($withEmpty -match 'UNBOUND')
# ORDER-671 U1, OWNER-RATIFIED. This was a NOTE, argued on COMPLETENESS grounds. The owner decided
# on ATTRIBUTION instead: `-HypothesisRevision X` claims the run is evidence about X, and a
# dimension X never describes cannot be evidence about X -- which needs no ruling on whether a
# binding set must be closed. The two assertions this replaces are kept in the commit message, not
# deleted silently: 'NO OPINION' and '[ALLOW]' were both TRUE of the old behaviour and are both
# FALSE of the ratified one, so leaving either would be a test asserting the superseded rule.
Ok 'U1 an UNBOUND parameter under a declared revision is REFUSED, not noted' `
    ($withEmpty -match "\[REFUSE\] $([regex]::Escape($param))")
Ok 'U1 and the refusal names BOTH the parameter and the revision -- "something is unbound" is not actionable' `
    (($withEmpty -match [regex]::Escape($param)) -and ($withEmpty -match [regex]::Escape($rev)))
Ok 'U1 and it states the ATTRIBUTION ground, not a completeness rule nobody ratified' `
    ($withEmpty -match 'EVIDENCE ABOUT')
Ok 'U1 and it names the two ways out, so the refusal is a fork rather than a wall' `
    (($withEmpty -match 'register a ParameterBinding') -and ($withEmpty -match 'drop -HypothesisRevision'))
# U2, THE SPECIFICITY HALF, and it is not optional. With NO revision declared there is no
# per-hypothesis layer at all, so nothing may change. The first version of THIS repair (the
# earlier note) fired on every legacy call site and was caught only because this line already
# existed -- GUARD_SHAPES shape 5, "collateral outside the example's slice". Asserted next to U1
# so neither can be quoted without the other.
Ok 'U2 SPECIFICITY with no revision declared, no UNBOUND line is emitted at all' `
    ($base -notmatch 'UNBOUND')
Ok 'U2 SPECIFICITY and the undeclared run still ALLOWS -- the refusal did not leak past its scope' `
    ($base -match "\[ALLOW\] $([regex]::Escape($param))")

Write-Host '   -- B: a LOCKED binding turns ALLOW into REFUSE --'
Seed 'LOCKED'
$locked = RunGuard @('-HypothesisRevision', $rev, '-BindingsRoot', $work)
Ok 'B a LOCKED binding makes the parameter REFUSE' ($locked -match "\[REFUSE\] $param")
Ok 'B and the reason names the ROLE and the revision' `
    ($locked -match "role='LOCKED' in $rev is not optimizable")
Ok 'B and it names the resolver that decided, so the answer is traceable to one file' `
    ($locked -match 'registry\.py')

Write-Host '   -- C: SPECIFICITY. A TUNABLE binding must NOT refuse --'
Seed 'TUNABLE'
$tunable = RunGuard @('-HypothesisRevision', $rev, '-BindingsRoot', $work)
Ok 'C a TUNABLE binding leaves the parameter ALLOW' ($tunable -match "\[ALLOW\] $param")
Ok 'C and says so explicitly rather than staying silent' `
    ($tunable -match "role='TUNABLE' in $rev is optimizable")

Write-Host '   -- C2: a SAFETY binding refuses too, so the allowlist is not "not LOCKED" --'
Seed 'SAFETY'
$safety = RunGuard @('-HypothesisRevision', $rev, '-BindingsRoot', $work)
Ok 'C2 a SAFETY binding also REFUSES (optimizable is an allowlist, not a LOCKED blacklist)' `
    ($safety -match "\[REFUSE\] $param" -and $safety -match "role='SAFETY'")

Write-Host '   -- E: the ajv live-row guard must be TRIGGERED by the store it governs --'
# BLIND AUDIT round 4, the strongest finding of the batch: run_schema_fixtures.py validates every
# LIVE registry row against its entity with ajv, and it runs inside run_contract_binding_tests.ps1
# -- but staging factory/instrument_profiles.jsonl selected only THIS suite. The checker existed,
# worked, and was not on the commit path of the file it governs. A guard the governed input does
# not trigger runs when something ELSE is staged, which is BACKLOG-D32's defect one layer up.
$selFile = Join-Path $work 'staged.txt'
Set-Content -LiteralPath $selFile -Encoding ASCII -Value 'factory/instrument_profiles.jsonl'
$sel = & powershell @('-NoProfile','-File',(Join-Path $RepoRoot ('scripts'+[char]92+'_test'+[char]92+'run_fast_cages.ps1')),
                      '-StagedPathsFile',$selFile,'-ExportSelection') 2>&1
Ok 'E staging a registry store selects the suite where ajv validates live rows' `
    ((@($sel) -join ' ') -match 'run_contract_binding_tests\.ps1')
Ok 'E and it still selects this suite too, so neither replaced the other' `
    ((@($sel) -join ' ') -match 'run_registry_tests\.ps1')
# SPECIFICITY: an unrelated staged path must NOT select them, or the assertion above proves
# nothing about the mapping.
Set-Content -LiteralPath $selFile -Encoding ASCII -Value 'docs/PARAM_LINKAGE.md'
$sel2 = & powershell @('-NoProfile','-File',(Join-Path $RepoRoot ('scripts'+[char]92+'_test'+[char]92+'run_fast_cages.ps1')),
                       '-StagedPathsFile',$selFile,'-ExportSelection') 2>&1
Ok 'E SPECIFICITY an unrelated path does not select the registry suite' `
    ((@($sel2) -join ' ') -notmatch 'run_registry_tests\.ps1')

Write-Host '   -- D: FAIL CLOSED when a revision is named and the bindings cannot be read --'
$threw = $false
$msg = ''
try {
    $null = & powershell @('-NoProfile','-File',$guard,'-ParamNames',$param,'-Build',$build,'-WarnOnly',
                           '-HypothesisRevision',$rev,'-BindingsRoot',(Join-Path $work 'no_such_dir')) 2>&1
    if ($LASTEXITCODE -ne 0) { $threw = $true }
} catch { $threw = $true; $msg = $_.Exception.Message }
Ok 'D naming a revision whose bindings cannot be read is a FAILURE, not an empty resolve' $threw

Write-Host ''
if ($script:fail -gt 0) { Write-Host ("FAIL  {0}/{1} passed, {2} failed" -f $script:pass, ($script:pass+$script:fail), $script:fail); exit 1 }
Write-Host ("PASS  {0}/{0}" -f $script:pass)
exit 0
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
