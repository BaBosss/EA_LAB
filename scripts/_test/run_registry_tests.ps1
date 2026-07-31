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

Write-Host '   -- A: the CONTROL. No revision => byte-identical verdicts --'
$withEmpty = RunGuard @('-HypothesisRevision', $rev, '-BindingsRoot', $work)
$baseVerdicts   = (($base       -split "`n") | Where-Object { $_ -match '^\[(ALLOW|REFUSE)\]' }) -join "`n"
$emptyVerdicts  = (($withEmpty  -split "`n") | Where-Object { $_ -match '^\[(ALLOW|REFUSE)\]' }) -join "`n"
Ok 'A a revision with ZERO bindings changes not one verdict line' ($baseVerdicts -eq $emptyVerdicts)
Ok 'A and it still SAYS it consulted the resolver, rather than being silently inert' `
    ($withEmpty -match 'BINDINGS: .* resolved 0 ParameterBinding row')

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
