<#
.SYNOPSIS
    Targeted cage for scripts/check_persist_legacy.ps1 (ORDER-510 one-command check).

.DESCRIPTION
    The checker's whole job is to answer "is this chart safe to update" from an F3 census, so
    the cage has to prove it can say BOTH words. A guard that only ever refuses is the failure
    mode the Decision log recorded on 2026-07-30 (optimize_guard refused three working dials and
    the only route past it was to switch the checks off), so the suite carries as many
    must-ALLOW cases as must-REFUSE ones:

      REFUSE  rc_peak_eq exists (trigger 3 has no threshold)
      REFUSE  rc_kill_pending = 1.0, and it must be named as LIVE SAFETY STATE
      REFUSE  acct_hwm with RC_AcctDDLimitPct undeclared (fail closed on the unknown)
      REFUSE  a census that parsed nothing at all, unless the operator asserts it by hand
      ALLOW   rc_kill_pending = 0.0 -- inactive residue, which the gate itself does not fire on
      ALLOW   acct_hwm with RC_AcctDDLimitPct = 0 declared
      ALLOW   a census holding only post-132 Boss2_ keys

    Two cases exist because the reader could pass every functional test and still be blind:

      ENCODING  a UTF-16LE census with no BOM. Memory prove-the-instrument-can-see-the-file was
                paid for by exactly this: MT5 writes UTF-16LE, a byte-oriented reader matches
                zero patterns forever, and "found nothing" gets reported as "clean".
      VINTAGE   a census of Boss2_<hash>_<login>_<symbol>_<magic>_rc_peak_eq names. Those are the
                POST-132 scoped keys -- the state the migration produces. A reader that matched
                them as legacy would declare a correctly-migrated terminal unsafe forever.

    RED-FIRST, measured rather than asserted. Four mechanisms were neutralised one at a time in a
    COPY of the checker and the corresponding case re-run (probe kept out of the repo; it mutates
    a scratchpad copy and touches nothing here):

      remove the UTF-16 sniff            -> encoding case exits 2 instead of 1        RED
      trigger 1 fires on existence       -> residue case exits 1 instead of 0         RED
      certify an empty parse as clean    -> empty case exits 0 instead of 2           RED
      legacy pattern swallows Boss2_     -> exit code stays 0; the parse silently
                                            reads magic 666728 out of the middle of a
                                            scoped key                                RED
                                            only via the name-count assertion

    That last line is the one worth keeping: the VINTAGE case's exit code does NOT discriminate,
    because a misparsed scoped key happens to land on no trigger. What catches it is the assertion
    on the legacy/scoped counts. A version of this suite that only checked exit codes would have
    been inert against the defect it was written for.

    Fixtures are built in a temp folder and deleted afterwards; nothing here touches the real
    tree, the real inventory, or any terminal.

.NOTES
    ASCII only, on purpose -- memory oc-qwen-lane-installed: a .ps1 with non-ASCII bytes and no
    BOM is read as ANSI by PowerShell 5.1.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}
$target = Join-Path $RepoRoot 'scripts\check_persist_legacy.ps1'
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

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("persistlegacy_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

function New-Census {
    param([string]$Name, [string[]]$Lines, [string]$Encoding = 'ascii')
    $p = Join-Path $tmp $Name
    switch ($Encoding) {
        'utf16le-nobom' { [System.IO.File]::WriteAllBytes($p, [System.Text.Encoding]::Unicode.GetBytes(($Lines -join "`r`n"))) }
        'utf16le-bom'   { [System.IO.File]::WriteAllText($p, ($Lines -join "`r`n"), [System.Text.Encoding]::Unicode) }
        'empty'         { [System.IO.File]::WriteAllBytes($p, [byte[]]@()) }
        default         { [System.IO.File]::WriteAllText($p, ($Lines -join "`r`n"), (New-Object System.Text.ASCIIEncoding)) }
    }
    return $p
}

function Invoke-Check {
    param([string[]]$Arguments)
    $global:LASTEXITCODE = 0
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target @Arguments 2>&1 | Out-String
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = $out }
}

Write-Host '[persist-legacy-tests] running'

try {
    # -----------------------------------------------------------------------
    # A. Trigger 3 fires on EXISTENCE -- the case that decides the size of the job
    # -----------------------------------------------------------------------
    $f = New-Census 'peak.txt' @('Boss_990120_rc_peak_eq')
    $r = Invoke-Check @('-GvDump', $f)
    Assert-True 'rc_peak_eq with no value at all still refuses (existence, no threshold)' ($r.Code -eq 1) ("exit {0}" -f $r.Code)
    Assert-True 'names trigger 3 in the output' ($r.Out -match '3 rc_peak_eq EXISTS')

    # -----------------------------------------------------------------------
    # B. ENCODING. UTF-16LE with no BOM is what MT5 writes; a naive reader sees nothing.
    # -----------------------------------------------------------------------
    $f = New-Census 'peak_utf16.txt' @('Boss_990208_rc_peak_eq	10136.29	2026.07.26 17:02') 'utf16le-nobom'
    $r = Invoke-Check @('-GvDump', $f)
    Assert-True 'UTF-16LE (no BOM) census is read, not silently emptied' ($r.Code -eq 1) ("exit {0}; out: {1}" -f $r.Code, $r.Out)
    Assert-True 'reports the sniffed encoding rather than claiming utf-8' ($r.Out -match 'utf-16le \(sniffed')
    Assert-True 'found the magic inside the UTF-16 census' ($r.Out -match '990208')

    $f = New-Census 'peak_utf16bom.txt' @('Boss_990208_rc_peak_eq	10136.29') 'utf16le-bom'
    $r = Invoke-Check @('-GvDump', $f)
    Assert-True 'UTF-16LE with BOM is read too' ($r.Code -eq 1) ("exit {0}" -f $r.Code)

    # -----------------------------------------------------------------------
    # C. VINTAGE. Post-132 scoped keys must not be mistaken for the legacy format.
    # -----------------------------------------------------------------------
    $f = New-Census 'scoped.txt' @(
        'Boss2_1a2b3c4d_463666728_XAUUSD_990120_rc_peak_eq	10136.29',
        'Boss2_1a2b3c4d_463666728_XAUUSD_990120_rc_state	0'
    )
    $r = Invoke-Check @('-GvDump', $f)
    Assert-True 'a fully migrated terminal is SAFE' ($r.Code -eq 0) ("exit {0}; out: {1}" -f $r.Code, $r.Out)
    Assert-True 'counted them as scoped, not legacy' ($r.Out -match '0 legacy Boss_ name\(s\) \| 2 scoped')
    Assert-True 'scoped-only census needs no -AssertDumpComplete' ($r.Out -notmatch 'REFUSED')

    # -----------------------------------------------------------------------
    # D. SPECIFICITY. Inactive residue must NOT block -- the gate does not fire on it.
    # -----------------------------------------------------------------------
    $f = New-Census 'residue.txt' @('Boss_990301_rc_kill_pending	0.0', 'Boss_990301_rc_halted	0.0')
    $r = Invoke-Check @('-GvDump', $f)
    Assert-True 'rc_kill_pending=0.0 + rc_halted=0.0 is SAFE (matches RiskControl.mqh:138-139)' ($r.Code -eq 0) ("exit {0}; out: {1}" -f $r.Code, $r.Out)
    Assert-True 'says so rather than staying silent about it' ($r.Out -match 'inactive residue')

    # a value printed BEFORE the key must not be read as the key's value
    $f = New-Census 'leadingvalue.txt' @('10136.29	Boss_990301_rc_kill_pending	0.0')
    $r = Invoke-Check @('-GvDump', $f)
    Assert-True 'the value is taken from after the key, not from anywhere on the line' ($r.Code -eq 0) ("exit {0}" -f $r.Code)

    # -----------------------------------------------------------------------
    # E. LIVE SAFETY STATE. Active kill must refuse AND be named as undeletable.
    # -----------------------------------------------------------------------
    $f = New-Census 'kill.txt' @('Boss_990302_rc_kill_pending	1.0')
    $r = Invoke-Check @('-GvDump', $f)
    Assert-True 'rc_kill_pending=1.0 refuses' ($r.Code -eq 1) ("exit {0}" -f $r.Code)
    Assert-True 'names it LIVE SAFETY STATE' ($r.Out -match 'LIVE SAFETY STATE')

    # a legacy value the census could not carry is not treated as absent
    $f = New-Census 'killnoval.txt' @('Boss_990302_rc_kill_pending')
    $r = Invoke-Check @('-GvDump', $f)
    Assert-True 'rc_kill_pending with no readable value refuses instead of assuming 0.0' ($r.Code -eq 1) ("exit {0}" -f $r.Code)
    Assert-True 'says the value was unreadable' ($r.Out -match 'UNREADABLE')

    # -----------------------------------------------------------------------
    # F. TRIGGER 4 is conditional on a value the census cannot contain.
    # -----------------------------------------------------------------------
    $f = New-Census 'hwm.txt' @('Boss_990001_acct_hwm	99944.00')
    $r = Invoke-Check @('-GvDump', $f)
    Assert-True 'acct_hwm with RC_AcctDDLimitPct undeclared fails closed' ($r.Code -eq 1) ("exit {0}" -f $r.Code)
    Assert-True 'labels it CONDITIONAL rather than asserting the trigger' ($r.Out -match 'CONDITIONAL')

    $r = Invoke-Check @('-GvDump', $f, '-AcctDDLimitPct', '0')
    Assert-True 'acct_hwm with RC_AcctDDLimitPct=0 declared is SAFE' ($r.Code -eq 0) ("exit {0}; out: {1}" -f $r.Code, $r.Out)

    $r = Invoke-Check @('-GvDump', $f, '-AcctDDLimitPct', '25')
    Assert-True 'acct_hwm with RC_AcctDDLimitPct=25 refuses' ($r.Code -eq 1) ("exit {0}" -f $r.Code)

    # the same fixture carries the default magic: the second, independent refusal
    Assert-True 'flags magic 990001 as the ORDER-129 default-magic refusal as well' ($r.Out -match 'ORDER-129')

    # -----------------------------------------------------------------------
    # G. An empty parse is not evidence of a clean terminal.
    # -----------------------------------------------------------------------
    $f = New-Census 'empty.txt' @() 'empty'
    $r = Invoke-Check @('-GvDump', $f)
    Assert-True 'an empty census is REFUSED, not certified clean' ($r.Code -eq 2) ("exit {0}" -f $r.Code)
    Assert-True 'explains that empty is indistinguishable from unread' ($r.Out -match 'indistinguishable')

    $r = Invoke-Check @('-GvDump', $f, '-AssertDumpComplete')
    Assert-True 'the operator can certify an empty F3 by hand' ($r.Code -eq 0) ("exit {0}" -f $r.Code)
    Assert-True 'and the report records that it rests on an assertion, not evidence' ($r.Out -match 'not on evidence')

    $r = Invoke-Check @('-GvDump', (Join-Path $tmp 'does_not_exist.txt'))
    Assert-True 'a missing census file exits 2, not 0' ($r.Code -eq 2) ("exit {0}" -f $r.Code)

    # -----------------------------------------------------------------------
    # H. Inventory cross-check: name what was CLEARED, and what is a ghost.
    # -----------------------------------------------------------------------
    $fixRepo = Join-Path $tmp 'repo'
    New-Item -ItemType Directory -Path (Join-Path $fixRepo 'portfolio') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fixRepo 'portfolio\DEPLOYMENTS.csv') -Encoding ASCII -Value @(
        'account,account_name,type,platform,host,ea_name,magic,symbol,status,kill_rule,judge_date,start_date,notes',
        '415573666,test,DEMO,MT5,vps,EaOne,990201,XAUUSD,ACTIVE,x,2027-01-01,2026-01-01,n',
        '415573666,test,DEMO,MT5,vps,EaTwo,990202,EURUSD,ACTIVE,x,2027-01-01,2026-01-01,n',
        '415573666,test,DEMO,MT5,vps,EaGone,990203,GBPUSD,REMOVED,x,2027-01-01,2026-01-01,n'
    )
    $f = New-Census 'mixed.txt' @('Boss_990201_rc_peak_eq	500.0', 'Boss_990999_rc_peak_eq	1.0')
    $r = Invoke-Check @('-GvDump', $f, '-Account', '415573666', '-RepoRoot', $fixRepo)
    Assert-True 'cross-check names the inventory magic with no legacy key' ($r.Out -match 'clear-by-absence  magic 990202')
    Assert-True 'a REMOVED row is not counted as something to clear' ($r.Out -notmatch 'magic 990203')
    Assert-True 'a legacy magic absent from the inventory is called a GHOST' ($r.Out -match 'GHOST     magic 990999')
    Assert-True 'the overall verdict is still driven by the gate, not by the cross-check' ($r.Code -eq 1) ("exit {0}" -f $r.Code)
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ("[persist-legacy-tests] {0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail -gt 0) { exit 1 }
exit 0
