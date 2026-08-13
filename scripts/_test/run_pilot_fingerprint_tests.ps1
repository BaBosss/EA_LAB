# ORDER-1330 item 1 -- exercise every branch of the versioned fingerprint, including the refusals.
# Each case states what it proves; a case that cannot fail is not evidence.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\pilot_run.ps1') 2>$null

$ctx = @{ Terminal = 'MT5_LANE_1'; FromDate = '2023.01.01'; ToDate = '2025.12.31'; Model = 4 }
$met = @{ bars = 18624; ticks = 125539367; company = 'TF Global Markets (Aust) Pty Ltd' }
$spec = @{ swap_long = -14.31; swap_short = -0.49; swap_mode = 'INTEREST_CURRENT' }

$fail = 0
function Check($name, $ok, $detail) {
    $tag = if ($ok) { '[OK ]' } else { '[BAD]'; }
    Write-Host ("{0} {1}{2}" -f $tag, $name, $(if ($detail) { " :: $detail" } else { '' }))
    if (-not $ok) { $script:fail++ }
}

# 1. no spec -> v1, and v1 is a BARE digest (no prefix)
$v1 = Get-PilotDataFingerprint -Ctx $ctx -Metrics $met -Symbol EURJPY -Period H1
Check 'no spec returns a bare digest' ($v1 -match '^[0-9a-f]{64}$') $v1

# 1b. THE REGRESSION GUARD. v1 must equal, byte for byte, what this function returned before the
# versioning was added. The first version of that change folded `fpver=v1` into the preimage, so
# an unchanged run hashed differently -- and data_fingerprint is in scheduler.py's
# EXECUTION_KEY_FIELDS, so all 135 committed rows would have stopped matching find_cached and the
# pilot would have re-run cells it already had. This case is the reason that cannot come back:
# the expected value is computed here from the nine parts, independently of the function.
$parts = @($ctx.Terminal, 'EURJPY', 'H1', $ctx.FromDate, $ctx.ToDate,
           ("model=" + $ctx.Model), ("bars=" + $met['bars']),
           ("ticks=" + $met['ticks']), ("server=" + $met['company']))
$sha = [System.Security.Cryptography.SHA256]::Create()
$preVersioning = (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($parts -join '|'))) |
                   ForEach-Object { $_.ToString('x2') }) -join '')
$sha.Dispose()
Check 'v1 is byte-identical to the pre-versioning digest' ($v1 -eq $preVersioning) `
    "expected $preVersioning"

# 2. spec -> v2, and it is a DIFFERENT digest (the spec actually reaches the preimage)
$v2 = Get-PilotDataFingerprint -Ctx $ctx -Metrics $met -Symbol EURJPY -Period H1 -SymbolSpec $spec
Check 'spec is tagged v2' ($v2 -match '^v2:[0-9a-f]{64}$') $v2
Check 'v2 digest differs from v1' (($v2 -replace '^v2:') -ne $v1) 'the spec is in the preimage, not just the tag'

# 3. THE ONE THAT MATTERS: a different swap rate must move the digest. If it does not, the whole
#    change is decoration and ORDER-1330 is not addressed at all.
$spec2 = @{ swap_long = -20.00; swap_short = -0.49; swap_mode = 'INTEREST_CURRENT' }
$v2b = Get-PilotDataFingerprint -Ctx $ctx -Metrics $met -Symbol EURJPY -Period H1 -SymbolSpec $spec2
Check 'a changed swap rate moves the digest' ($v2b -ne $v2) 'this is the defect the order exists for'

# 4. determinism -- same inputs, same value
$v2c = Get-PilotDataFingerprint -Ctx $ctx -Metrics $met -Symbol EURJPY -Period H1 -SymbolSpec $spec
Check 'deterministic' ($v2c -eq $v2) ''

# 5. a PARTIAL spec is refused, by name
$refused = $false; $msg = ''
try { Get-PilotDataFingerprint -Ctx $ctx -Metrics $met -Symbol EURJPY -Period H1 `
        -SymbolSpec @{ swap_long = -14.31 } | Out-Null }
catch { $refused = $true; $msg = $_.Exception.Message }
Check 'partial spec refused and names the missing fields' `
    ($refused -and $msg -match 'swap_short' -and $msg -match 'swap_mode') $msg.Substring(0, [Math]::Min(90, $msg.Length))

# 5b. A present key with no usable value is also a partial observation.  Otherwise PowerShell
# would concatenate $null as empty and claim v2 from precisely the unknown broker input we refuse.
$refused = $false; $msg = ''
try { Get-PilotDataFingerprint -Ctx $ctx -Metrics $met -Symbol EURJPY -Period H1 `
        -SymbolSpec @{ swap_long = $null; swap_short = -0.49; swap_mode = 'INTEREST_CURRENT' } | Out-Null }
catch { $refused = $true; $msg = $_.Exception.Message }
Check 'null-valued spec field is refused rather than hashed as empty' `
    ($refused -and $msg -match 'swap_long') $msg.Substring(0, [Math]::Min(90, $msg.Length))

# 6. version classification, including the legacy bare digest
Check 'a bare sha is v1, not a third state' ((Get-PilotFingerprintVersion ('a' * 64)) -eq 'v1') 'the recipe is identical, so the label must be too'
Check 'v1 classified'  ((Get-PilotFingerprintVersion $v1) -eq 'v1') ''
Check 'v2 classified'  ((Get-PilotFingerprintVersion $v2) -eq 'v2') ''

# 7. an unreadable value REFUSES rather than being called absent
$refused = $false
try { Get-PilotFingerprintVersion 'not-a-fingerprint' | Out-Null } catch { $refused = $true }
Check 'unreadable value is refused, not classified' $refused ''

$refused = $false
try { Get-PilotFingerprintVersion 'v2:garbage' | Out-Null } catch { $refused = $true }
Check 'malformed tagged value is refused, not classified by its prefix' $refused ''

# 8. cross-version comparison REFUSES -- the owner ruling, and the point of the whole change
$refused = $false; $msg = ''
try { Assert-PilotFingerprintComparable -A $v1 -B $v2 -Context 'test' } catch { $refused = $true; $msg = $_.Exception.Message }
Check 'v1 vs v2 comparison refused' ($refused -and $msg -match "'v1' vs 'v2'") ''

$refused = $false
try { Assert-PilotFingerprintComparable -A ('a' * 64) -B $v2 -Context 'test' } catch { $refused = $true }
Check 'a committed bare row vs v2 is refused' $refused 'the 135 committed rows cannot be silently compared to v2'

# SPECIFICITY for the pair above: a bare row and a NEW v1 row are the same recipe, so comparing
# them must be ALLOWED. If this refused, the change would have orphaned every committed row.
$allowed = $true
try { Assert-PilotFingerprintComparable -A ('a' * 64) -B $v1 -Context 'test' | Out-Null } catch { $allowed = $false }
Check 'a committed bare row vs a new v1 row IS comparable' $allowed 'same recipe, same version'

# 9. SPECIFICITY -- same version must still be ALLOWED, or the guard is just "always refuse"
$allowed = $true
try { Assert-PilotFingerprintComparable -A $v1 -B $v1 -Context 'test' | Out-Null } catch { $allowed = $false }
Check 'same-version comparison is allowed' $allowed 'a guard that refuses everything discriminates nothing'

### ORDER-1330 Blocker A -- Get-PilotSymbolSpec / Get-PilotDataFingerprintProbed ####################
# These cases fake the ONE boundary that cannot be a pure function -- the mt5_run.ps1 process -- with
# a stub that appends a real UTF-16LE line to a real file at the real relative path
# (Tester\logs\<today>.log), so the function under test does its OWN file I/O, seeking and decoding.
# Nothing about the position-tracking or the regex is faked.
$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('pilotspec_' + [guid]::NewGuid().ToString('N'))
$fakeScriptDir = Join-Path $tmpRoot 'scripts'
New-Item -ItemType Directory -Force $fakeScriptDir | Out-Null
$today = Get-Date -Format 'yyyyMMdd'
# EACH CASE GETS ITS OWN DataDir, not a shared one. The function under test scopes its log path to
# $Ctx.DataDir\Tester\logs\<today>.log, so a shared fake DataDir across cases would make an EARLIER
# case's legitimate line double as the "stale" fixture for a LATER case (found by round 1 of this
# cage's own self-scrutiny: case 10's real -14.31 entry was, by coincidence, ALSO the first match in
# the whole file, which let a broken whole-file-search implementation pass case 11 for the wrong
# reason). Isolating DataDir per case is what makes the attack mean what its name says.
function New-FakeDataDir([string]$Tag) {
    $dir = Join-Path $tmpRoot ('data_' + $Tag)
    New-Item -ItemType Directory -Force (Join-Path $dir 'Tester\logs') | Out-Null
    return $dir
}

function Write-FakeSwapLine([string]$Path, [string]$Symbol, [string]$Long, [string]$Short) {
    $line = "SWAPPROBE $Symbol | mode=INTEREST_CURRENT (annual %) | swap_long=$Long swap_short=$Short | rollover3days=WEDNESDAY`r`n"
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($line)
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
    try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
}

# The stub is swapped between cases via a script-scope switch, so each case controls exactly what
# "the probe ran" produced without touching MT5.
$stubBody = @'
param($Expert,$Symbol,$Period,$FromDate,$ToDate,$SetFile,$Model,$ReportName,$Terminal,$DataDir)
$behaviorPath = Join-Path $env:PILOTSPEC_TEST_ROOT 'behavior.txt'
$behavior = if (Test-Path $behaviorPath) { Get-Content $behaviorPath -Raw } else { 'append' }
switch ($behavior.Trim()) {
  'append'   { & (Join-Path $env:PILOTSPEC_TEST_ROOT 'append_real.ps1') $Symbol; exit 0 }
  'nogrow'   { exit 0 }
  'fail'     { exit 1 }
  'garbage'  {
    $p = Join-Path $DataDir ('Tester\logs\' + (Get-Date -Format 'yyyyMMdd') + '.log')
    $bytes = [System.Text.Encoding]::Unicode.GetBytes("not a swapprobe line at all`r`n")
    $fs = [System.IO.File]::Open($p, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
    try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
    exit 0
  }
}
'@
Set-Content -Path (Join-Path $fakeScriptDir 'mt5_run.ps1') -Value $stubBody -Encoding UTF8
$appendReal = @'
param($Symbol)
$p = Join-Path $env:PILOTSPEC_TEST_DATADIR ('Tester\logs\' + (Get-Date -Format 'yyyyMMdd') + '.log')
$line = "SWAPPROBE $Symbol | mode=INTEREST_CURRENT (annual %) | swap_long=$env:PILOTSPEC_TEST_LONG swap_short=$env:PILOTSPEC_TEST_SHORT | rollover3days=WEDNESDAY`r`n"
$bytes = [System.Text.Encoding]::Unicode.GetBytes($line)
$fs = [System.IO.File]::Open($p, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
'@
Set-Content -Path (Join-Path $fakeScriptDir 'append_real.ps1') -Value $appendReal -Encoding UTF8
$env:PILOTSPEC_TEST_ROOT = $fakeScriptDir

function Set-StubBehavior([string]$b) { Set-Content -Path (Join-Path $fakeScriptDir 'behavior.txt') -Value $b -NoNewline }
function New-SpecCtx([string]$dataDir) { @{ RepoRoot = $tmpRoot; ScriptDir = $fakeScriptDir; Terminal = 'FAKE_LANE'; DataDir = $dataDir } }

# 10. POSITIVE -- a fresh log, the probe appends one line, the exact values come back.
$dd10 = New-FakeDataDir 'case10'
$env:PILOTSPEC_TEST_DATADIR = $dd10
Set-StubBehavior 'append'
$env:PILOTSPEC_TEST_LONG = '-14.310000'; $env:PILOTSPEC_TEST_SHORT = '-0.490000'
$spec10 = Get-PilotSymbolSpec -Ctx (New-SpecCtx $dd10) -Symbol 'BTCUSD' -ReportName 'CASE10'
Check 'symbol-spec probe reads back the appended line' `
    ($spec10.swap_mode -eq 'INTEREST_CURRENT' -and $spec10.swap_long -eq -14.31 -and $spec10.swap_short -eq -0.49) `
    ($spec10 | ConvertTo-Json -Compress)

# 11. THE ATTACK THIS MECHANISM EXISTS TO SURVIVE (GUARD_SHAPES shape 1 -- reads the wrong bytes).
# Own DataDir, so the "stale" line is genuinely the only thing already in this case's log and
# genuinely the first thing a whole-file reader would match -- round 1 of this cage's own
# self-scrutiny found that a SHARED fake log let an earlier case's legitimate entry double as the
# stale fixture, which happened to also be the right answer and let a broken (whole-file-search)
# implementation pass this case for the wrong reason. Isolating DataDir per case is the fix, and it
# was verified against the naive implementation before being trusted (see the lane's write-up).
$dd11 = New-FakeDataDir 'case11'
Write-FakeSwapLine -Path (Join-Path $dd11 ('Tester\logs\' + $today + '.log')) -Symbol 'BTCUSD' -Long '-999.000000' -Short '-999.000000'
$env:PILOTSPEC_TEST_DATADIR = $dd11
Set-StubBehavior 'append'
$env:PILOTSPEC_TEST_LONG = '-14.310000'; $env:PILOTSPEC_TEST_SHORT = '-0.490000'
$spec11 = Get-PilotSymbolSpec -Ctx (New-SpecCtx $dd11) -Symbol 'BTCUSD' -ReportName 'CASE11'
Check 'a stale earlier SWAPPROBE line for the same symbol is NOT read -- only bytes appended by THIS run are' `
    ($spec11.swap_long -eq -14.31) `
    ('got ' + $spec11.swap_long + '; -999 would mean the stale line leaked through')

# 12. ATTACK -- the log does not grow (probe "succeeded" but produced nothing new) -> REFUSE.
$dd12 = New-FakeDataDir 'case12'
$env:PILOTSPEC_TEST_DATADIR = $dd12
Set-StubBehavior 'nogrow'
$refused = $false
try { Get-PilotSymbolSpec -Ctx (New-SpecCtx $dd12) -Symbol 'BTCUSD' -ReportName 'CASE12' | Out-Null } catch { $refused = $true }
Check 'no log growth refuses rather than silently reusing whatever is already there' $refused ''

# 13. ATTACK -- mt5_run.ps1 itself fails -> REFUSE, named as a process failure.
$dd13 = New-FakeDataDir 'case13'
$env:PILOTSPEC_TEST_DATADIR = $dd13
Set-StubBehavior 'fail'
$refused = $false; $msg = ''
try { Get-PilotSymbolSpec -Ctx (New-SpecCtx $dd13) -Symbol 'BTCUSD' -ReportName 'CASE13' | Out-Null } catch { $refused = $true; $msg = $_.Exception.Message }
Check 'a failed probe process refuses and says so' ($refused -and $msg -match 'exited') $msg

# 14. ATTACK -- the log grows but with no parseable SWAPPROBE line -> REFUSE, not a partial guess.
$dd14 = New-FakeDataDir 'case14'
$env:PILOTSPEC_TEST_DATADIR = $dd14
Set-StubBehavior 'garbage'
$refused = $false
try { Get-PilotSymbolSpec -Ctx (New-SpecCtx $dd14) -Symbol 'BTCUSD' -ReportName 'CASE14' | Out-Null } catch { $refused = $true }
Check 'appended bytes with no matching SWAPPROBE line refuse' $refused ''

# 15. ENGAGEMENT for Get-PilotDataFingerprintProbed -- when the probe succeeds, the result is v2 and
# matches calling Get-PilotDataFingerprint with that exact spec directly (the wrapper is not doing
# its own, separate hashing).
$dd15 = New-FakeDataDir 'case15'
$env:PILOTSPEC_TEST_DATADIR = $dd15
Set-StubBehavior 'append'
$env:PILOTSPEC_TEST_LONG = '-14.310000'; $env:PILOTSPEC_TEST_SHORT = '-0.490000'
$probed15 = Get-PilotDataFingerprintProbed -Ctx (New-SpecCtx $dd15) -Metrics $met -Symbol 'BTCUSD' -Period 'H4' -ReportTag 'CASE15'
$direct15 = Get-PilotDataFingerprint -Ctx (New-SpecCtx $dd15) -Metrics $met -Symbol 'BTCUSD' -Period 'H4' `
    -SymbolSpec @{ swap_long = -14.31; swap_short = -0.49; swap_mode = 'INTEREST_CURRENT' }
Check 'probed fingerprint is v2 and matches the direct call with the same spec' `
    ($probed15 -match '^v2:' -and $probed15 -eq $direct15) ("probed=$probed15 direct=$direct15")

# 16. SPECIFICITY -- when the probe fails, Get-PilotDataFingerprintProbed does NOT throw: it falls
# back to the honest v1 answer. A wrapper that propagated the throw would abort the whole pilot
# matrix over a diagnostic side-probe failing, which is a worse outcome than an honestly-labelled v1.
$dd16 = New-FakeDataDir 'case16'
$env:PILOTSPEC_TEST_DATADIR = $dd16
Set-StubBehavior 'fail'
$fellBack = $true; $probed16 = $null
try { $probed16 = Get-PilotDataFingerprintProbed -Ctx (New-SpecCtx $dd16) -Metrics $met -Symbol 'BTCUSD' -Period 'H4' -ReportTag 'CASE16' -WarningAction SilentlyContinue }
catch { $fellBack = $false }
Check 'a failed probe falls back to v1 instead of aborting the caller' `
    ($fellBack -and $probed16 -match '^[0-9a-f]{64}$') $probed16

# 17. Blocker B's migration inventory is intentionally EMPTY.  The 132 historical pilot/coverage
# fields are all bare v1 digests; none has a joinable per-run swap spec, so emitting v2 for any of
# them would fabricate broker data.  This census is exact on purpose: the separate three old
# scheduler execution keys under factory/runs are not pilot evidence and are outside this migration.
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$historicalFiles = @((Get-ChildItem (Join-Path $repoRoot 'factory\runs\pilot') -Recurse -File -Filter '*.jsonl' |
                     Where-Object { $_.FullName -notmatch '[\\/]swap_probe[\\/]' })) +
                   @(Get-Item (Join-Path $repoRoot 'factory\coverage.jsonl'))
$historicalText = ($historicalFiles | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
$historicalCount = [regex]::Matches($historicalText, '"data_fingerprint"\s*:').Count
$hasRecordedSpec = $historicalText -match '"(?:swap_long|swap_short|swap_mode|symbol_spec)"\s*:'
Check 'Blocker B has no reconstructible v2 historical rows: 132 bare v1 fields, no per-run spec' `
    ($historicalCount -eq 132 -and $historicalText -notmatch '"data_fingerprint"\s*:\s*"v2:' -and -not $hasRecordedSpec) `
    ("fingerprints={0}; v2={1}; recorded_spec={2}" -f $historicalCount, `
     ([regex]::Matches($historicalText, '"data_fingerprint"\s*:\s*"v2:').Count), $hasRecordedSpec)

Remove-Item -Recurse -Force $tmpRoot -ErrorAction SilentlyContinue
Remove-Item Env:\PILOTSPEC_TEST_ROOT, Env:\PILOTSPEC_TEST_DATADIR, Env:\PILOTSPEC_TEST_LONG, Env:\PILOTSPEC_TEST_SHORT -ErrorAction SilentlyContinue

Write-Host ''
if ($fail) { Write-Host "=== $fail CASE(S) FAILED ==="; exit 1 }
Write-Host '=== all cases passed, refusals and specificity included ==='
