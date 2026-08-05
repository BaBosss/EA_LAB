<#
.SYNOPSIS
    ORDER-510 one-command check: is this terminal/chart safe to update to a post-ORDER-132
    binary, or will OnInit refuse and the EA simply go quiet?

.DESCRIPTION
    The new build fails CLOSED in RiskControl_InitEx (ea_template/core/RiskControl.mqh:137-156)
    when it meets pre-132 magic-only GlobalVariables and RC_AdoptLegacyHalt=false (the default).
    The visible symptom is "the EA is quiet", not "the system refused". This script turns the
    read-only F3 census that ORDER-510 SECOND BLOCKER asks for into a verdict.

    INPUT is whatever the operator can actually produce from Tools -> Global Variables (F3):
    a text file with one GV per line, in any of these shapes --

        Boss_990120_rc_peak_eq
        Boss_990120_rc_peak_eq  10136.29
        Boss_990120_rc_peak_eq<TAB>10136.29<TAB>2026.07.26 17:02

    -- and in any of the encodings a Windows terminal produces (UTF-8 with or without BOM,
    UTF-16LE/BE, or ANSI). The encoding sniff is not decoration: memory
    prove-the-instrument-can-see-the-file records MT5 writing UTF-16LE, against which a
    byte-oriented reader returns zero matches forever and reports "nothing found" as a clean bill
    of health.

    THE FOUR TRIGGERS, exactly as the gate evaluates them (RiskControl.mqh:138-141):

      1  Boss_<magic>_rc_kill_pending > 0.5   gated by RC_PersistHalt   (default true)
      2  Boss_<magic>_rc_halted       > 0.5   gated by RC_PersistHalt
      3  Boss_<magic>_rc_peak_eq      EXISTS  gated by RC_PersistHalt   <- fires on existence
      4  Boss_<magic>_acct_hwm        EXISTS  gated by RC_AcctDDLimitPct > 0

    Trigger 3 has no threshold, so any chart that ran long enough under a pre-132 binary to
    record a peak equity refuses to start. A 0.0 leftover in triggers 1/2 is benign residue and
    does NOT fire the gate -- this script reproduces that distinction rather than flagging every
    legacy name it sees, because a check that cannot say what it ALLOWS gets switched off
    (Decision log 2026-07-30).

.PARAMETER GvDump
    Path to the F3 census text file.

.PARAMETER Account
    Optional login. When given, DEPLOYMENTS.csv is consulted so the report can also name the
    template magics on that account which carry NO legacy key -- the ones the census clears.

.PARAMETER AcctDDLimitPct
    The RC_AcctDDLimitPct the upgraded chart will run with. Trigger 4 is gated on it being > 0
    and the value is not knowable from the census. Left unspecified, an acct_hwm hit is reported
    as CONDITIONAL and counted as NOT SAFE (fail closed).

.PARAMETER AssertDumpComplete
    Required only when the parse finds no Boss GV of ANY vintage. An empty parse is
    indistinguishable from an empty file, a wrong path, or an encoding this reader mishandled, so
    the script refuses to certify it as "clean" on its own. Finding any Boss2_ key is itself proof
    the reader saw the file, and needs no assertion.

.OUTPUTS
    exit 0  every magic in the census is safe to update (nothing fires the gate)
    exit 1  at least one magic fires the gate -- run the adopt-once procedure first
            (_triage/ORDER510_ADOPT_ONCE_PROCEDURE.md), do NOT copy the binary
    exit 2  the check could not be performed (bad path, empty/unproven parse, bad usage)

.NOTES
    ASCII only, on purpose -- memory oc-qwen-lane-installed: a .ps1 with non-ASCII bytes and no
    BOM is read as ANSI by PowerShell 5.1.

    What this check does NOT cover, stated because all three present as "the EA is quiet" and
    will be blamed on this gate (procedure section 8):
      - _0_Magic still on the compiled default 990001 -> INIT_FAILED from the ORDER-129 guard
        (ea_template/core/LabCore.mqh:254-257), regardless of any GV. Reported separately below.
      - _06_AllowLive=false -> the EA starts and never trades.
      - The binary that WROTE these keys is not this source. Anything about what the running EA
        did comes from its Journal, never from reading today's code.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GvDump,
    [string]$Account = '',
    [double]$AcctDDLimitPct = -1,
    [switch]$AssertDumpComplete,
    [string]$RepoRoot = ''
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { Write-Host '[persist-legacy] cannot resolve script directory; pass -RepoRoot' -ForegroundColor Red; exit 2 }
    $RepoRoot = Split-Path -Parent $here
}

# snapshot: worktree -- and it is the only correct vintage here. This checker judges no commit:
# its subject is a census the operator exported from a running terminal seconds ago, which has no
# index or HEAD vintage to have. Everything below reads the disk on purpose.
if (-not (Test-Path -LiteralPath $GvDump)) {
    Write-Host ("[persist-legacy] census file not found: {0}" -f $GvDump) -ForegroundColor Red
    exit 2
}

# ---------------------------------------------------------------------------
# Read the census. Encoding is sniffed, never assumed.
# ---------------------------------------------------------------------------
# snapshot: worktree -- the operator's census file, read as bytes so the encoding can be sniffed
# rather than assumed. A git vintage of this path would be meaningless; it is not in the repo.
$bytes = [System.IO.File]::ReadAllBytes($GvDump)
$encName = 'utf-8'
$text = ''
if ($bytes.Length -eq 0) {
    $text = ''
    $encName = 'empty-file'
} elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
    $encName = 'utf-16le (BOM)'
    $text = [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
} elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
    $encName = 'utf-16be (BOM)'
    $text = [System.Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2)
} elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $encName = 'utf-8 (BOM)'
    $text = [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
} else {
    # No BOM. MT5 writes BOM-less UTF-16LE in places (memory: MT5 log = UTF-16LE), which a
    # UTF-8 read turns into a string full of NULs that matches no pattern. Decide by counting
    # NUL bytes in the first kilobyte rather than by hoping.
    $probe = [Math]::Min($bytes.Length, 1024)
    $nul = 0
    for ($i = 0; $i -lt $probe; $i++) { if ($bytes[$i] -eq 0) { $nul++ } }
    if ($nul * 4 -gt $probe) {
        # every other byte roughly zero => 16-bit units
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 0) {
            $encName = 'utf-16be (sniffed, no BOM)'
            $text = [System.Text.Encoding]::BigEndianUnicode.GetString($bytes)
        } else {
            $encName = 'utf-16le (sniffed, no BOM)'
            $text = [System.Text.Encoding]::Unicode.GetString($bytes)
        }
    } else {
        $encName = 'utf-8 / ansi (no BOM)'
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    }
}

$lines = $text -split "`r?`n"

# ---------------------------------------------------------------------------
# Parse. Legacy = Boss_<magic>_<name> (no account identity, Persist.mqh:88).
#        Scoped = Boss2_<srvhash>_<login>_<symbol>_<magic>_<name> (Persist.mqh:32-39).
# 'Boss_' cannot match a 'Boss2_' name: the underscore is part of the literal.
# ---------------------------------------------------------------------------
$legacy = @{}   # magic -> @{ name -> value(or $null) }
$scopedCount = 0
$legacyCount = 0

$reLegacy = [regex]'Boss_(\d+)_([A-Za-z0-9_]+)'
$reScoped = [regex]'Boss2_[0-9a-fA-F]{8}_\d+_[^\s_]+_(\d+)_([A-Za-z0-9_]+)'
$reNum    = [regex]'(-?\d+(?:\.\d+)?)'

foreach ($line in $lines) {
    if (-not $line) { continue }
    foreach ($m in $reScoped.Matches($line)) { $scopedCount++ }
    foreach ($m in $reLegacy.Matches($line)) {
        $magic = $m.Groups[1].Value
        $name  = $m.Groups[2].Value
        $legacyCount++
        if (-not $legacy.ContainsKey($magic)) { $legacy[$magic] = @{} }
        # value = the first number AFTER the key on the same line, if any. The key itself
        # contains digits, so the search starts past the match.
        $tail = $line.Substring($m.Index + $m.Length)
        $val = $null
        $vm = $reNum.Match($tail)
        if ($vm.Success) { $val = [double]$vm.Groups[1].Value }
        $legacy[$magic][$name] = $val
    }
}

Write-Host ('[persist-legacy] census: {0}' -f $GvDump)
Write-Host ('[persist-legacy] encoding {0} | {1} line(s) | {2} legacy Boss_ name(s) | {3} scoped Boss2_ name(s)' -f $encName, $lines.Count, $legacyCount, $scopedCount)

if ($legacyCount -eq 0 -and $scopedCount -eq 0) {
    if (-not $AssertDumpComplete) {
        Write-Host '[persist-legacy] REFUSED: the parse found no Boss GV of any vintage.' -ForegroundColor Red
        Write-Host '                 That is indistinguishable from an empty file, a wrong path, or an' -ForegroundColor Red
        Write-Host '                 encoding this reader mishandled -- it is not evidence the terminal is clean.' -ForegroundColor Red
        Write-Host '                 Re-export, or pass -AssertDumpComplete to certify by hand that F3 was empty.' -ForegroundColor Red
        exit 2
    }
    Write-Host '[persist-legacy] note: empty census accepted on the operator''s -AssertDumpComplete, not on evidence.' -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Classify, one magic at a time, exactly as the gate does.
# ---------------------------------------------------------------------------
$blocked = 0
$clear   = 0
$notes   = New-Object System.Collections.ArrayList

foreach ($magic in ($legacy.Keys | Sort-Object)) {
    $keys = $legacy[$magic]
    $fires = New-Object System.Collections.ArrayList
    $live  = New-Object System.Collections.ArrayList
    $conditional = $false

    if ($keys.ContainsKey('rc_kill_pending')) {
        $v = $keys['rc_kill_pending']
        if ($null -ne $v -and $v -gt 0.5) { [void]$fires.Add('1 rc_kill_pending>0.5'); [void]$live.Add('rc_kill_pending') }
        elseif ($null -eq $v) { [void]$fires.Add('1 rc_kill_pending value UNREADABLE'); [void]$live.Add('rc_kill_pending') }
        else { [void]$notes.Add("$magic : rc_kill_pending=$v is inactive residue - does not fire the gate, and is NOT to be deleted") }
    }
    if ($keys.ContainsKey('rc_halted')) {
        $v = $keys['rc_halted']
        if ($null -ne $v -and $v -gt 0.5) { [void]$fires.Add('2 rc_halted>0.5'); [void]$live.Add('rc_halted') }
        elseif ($null -eq $v) { [void]$fires.Add('2 rc_halted value UNREADABLE'); [void]$live.Add('rc_halted') }
        else { [void]$notes.Add("$magic : rc_halted=$v is inactive residue - does not fire the gate, and is NOT to be deleted") }
    }
    if ($keys.ContainsKey('rc_peak_eq')) {
        [void]$fires.Add('3 rc_peak_eq EXISTS')
    }
    if ($keys.ContainsKey('acct_hwm')) {
        if ($AcctDDLimitPct -gt 0) { [void]$fires.Add('4 acct_hwm EXISTS (RC_AcctDDLimitPct>0)') }
        elseif ($AcctDDLimitPct -eq 0) { [void]$notes.Add("$magic : acct_hwm present but RC_AcctDDLimitPct=0 was declared - trigger 4 stays silent") }
        else { [void]$fires.Add('4 acct_hwm EXISTS (CONDITIONAL: RC_AcctDDLimitPct not declared)'); $conditional = $true }
    }

    $other = @($keys.Keys | Where-Object { $_ -notin @('rc_kill_pending','rc_halted','rc_peak_eq','acct_hwm') } | Sort-Object)

    if ($fires.Count -eq 0) {
        $clear++
        Write-Host ('  SAFE      magic {0} : {1} legacy key(s), none of them a gate trigger' -f $magic, $keys.Count) -ForegroundColor Green
    } else {
        $blocked++
        Write-Host ('  NOT SAFE  magic {0} : gate fires on -> {1}' -f $magic, ($fires -join ' | ')) -ForegroundColor Red
        if ($live.Count -gt 0) {
            Write-Host ('              LIVE SAFETY STATE ({0}) - adopt-once is the route; deleting it disarms a kill' -f ($live -join ', ')) -ForegroundColor Red
        }
        if ($conditional) {
            Write-Host '              counted as NOT SAFE because RC_AcctDDLimitPct was not declared (pass -AcctDDLimitPct)' -ForegroundColor Yellow
        }
    }
    if ($other.Count -gt 0) {
        Write-Host ('              other pre-132 residue: {0}' -f ($other -join ', '))
    }
    if ($magic -eq '990001') {
        Write-Host '              + magic 990001 is the compiled default: the ORDER-129 guard (LabCore.mqh:254-257)' -ForegroundColor Yellow
        Write-Host '                returns INIT_FAILED outside the tester regardless of any GV. Two refusals, one symptom.' -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Optional cross-check against the inventory, so the report can also name what
# it CLEARED rather than only what it blocked.
# ---------------------------------------------------------------------------
if ($Account) {
    $csv = Join-Path $RepoRoot 'portfolio\DEPLOYMENTS.csv'
    # snapshot: worktree -- deliberate. The question is "what is deployed right now", so the
    # working copy is the right vintage; an index or HEAD read would answer about a commit that
    # this ops check has nothing to do with.
    if (-not (Test-Path -LiteralPath $csv)) {
        Write-Host ("[persist-legacy] inventory not found, cross-check skipped: {0}" -f $csv) -ForegroundColor Yellow
    } else {
        # snapshot: worktree -- same vintage as the Test-Path above, for the same reason.
        $rows = @(Import-Csv -LiteralPath $csv | Where-Object { $_.account -eq $Account -and $_.status -ne 'REMOVED' })
        if ($rows.Count -eq 0) {
            Write-Host ("[persist-legacy] inventory has no non-REMOVED row for account {0} - nothing to cross-check" -f $Account) -ForegroundColor Yellow
        } else {
            $noKey = @($rows | Where-Object { -not $legacy.ContainsKey($_.magic) })
            Write-Host ('[persist-legacy] inventory {0}: {1} non-REMOVED row(s); {2} carry no legacy key in this census' -f $Account, $rows.Count, $noKey.Count)
            foreach ($r in $noKey) {
                Write-Host ('  clear-by-absence  magic {0} ({1} {2})' -f $r.magic, $r.ea_name, $r.symbol)
            }
            $ghost = @($legacy.Keys | Where-Object { $m = $_; -not ($rows | Where-Object { $_.magic -eq $m }) } | Sort-Object)
            foreach ($g in $ghost) {
                Write-Host ('  GHOST     magic {0} holds legacy keys but has no non-REMOVED row on this account' -f $g) -ForegroundColor Yellow
            }
        }
    }
}

foreach ($n in $notes) { Write-Host ('  note      {0}' -f $n) }

Write-Host ''
if ($blocked -gt 0) {
    Write-Host ('=== NOT SAFE TO UPDATE: {0} magic(s) fire the fail-closed gate, {1} clear ===' -f $blocked, $clear) -ForegroundColor Red
    Write-Host '    Run _triage/ORDER510_ADOPT_ONCE_PROCEDURE.md per magic BEFORE copying any binary.'
    Write-Host '    Do not delete Boss_<magic>_* to make this pass - section 7 is the only route.'
    exit 1
}
Write-Host ('=== SAFE TO UPDATE on this census: {0} magic(s) checked, none fires the gate ===' -f $clear) -ForegroundColor Green
Write-Host '    Scope: this census, this terminal, this moment. It generalises to no other account'
Write-Host '    (463666728 had 14 template charts and only 4 legacy keys), and it says nothing about'
Write-Host '    _06_AllowLive or a chart still wearing the default magic.'
exit 0
