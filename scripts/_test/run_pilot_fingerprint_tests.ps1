# ORDER-1330 item 1 -- exercise every branch of the versioned fingerprint, including the refusals.
# Each case states what it proves; a case that cannot fail is not evidence.
$ErrorActionPreference = 'Stop'
. 'D:\EA_LAB\scripts\lib\pilot_run.ps1' 2>$null

$ctx = @{ Terminal = 'MT5_LANE_1'; FromDate = '2023.01.01'; ToDate = '2025.12.31'; Model = 4 }
$met = @{ bars = 18624; ticks = 125539367; company = 'TF Global Markets (Aust) Pty Ltd' }
$spec = @{ swap_long = -14.31; swap_short = -0.49; swap_mode = 'INTEREST_CURRENT' }

$fail = 0
function Check($name, $ok, $detail) {
    $tag = if ($ok) { '[OK ]' } else { '[BAD]'; }
    Write-Host ("{0} {1}{2}" -f $tag, $name, $(if ($detail) { " :: $detail" } else { '' }))
    if (-not $ok) { $script:fail++ }
}

# 1. no spec -> honestly tagged v1
$v1 = Get-PilotDataFingerprint -Ctx $ctx -Metrics $met -Symbol EURJPY -Period H1
Check 'no spec is tagged v1' ($v1 -match '^v1:[0-9a-f]{64}$') $v1

# 2. spec -> v2, and it is a DIFFERENT digest (the spec actually reaches the preimage)
$v2 = Get-PilotDataFingerprint -Ctx $ctx -Metrics $met -Symbol EURJPY -Period H1 -SymbolSpec $spec
Check 'spec is tagged v2' ($v2 -match '^v2:[0-9a-f]{64}$') $v2
Check 'v2 digest differs from v1' (($v2 -replace '^v2:') -ne ($v1 -replace '^v1:')) 'the spec is in the preimage, not just the tag'

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

# 6. version classification, including the legacy bare digest
Check 'legacy bare sha classified as legacy' ((Get-PilotFingerprintVersion ('a' * 64)) -eq 'legacy') ''
Check 'v1 classified'  ((Get-PilotFingerprintVersion $v1) -eq 'v1') ''
Check 'v2 classified'  ((Get-PilotFingerprintVersion $v2) -eq 'v2') ''

# 7. an unreadable value REFUSES rather than being called absent
$refused = $false
try { Get-PilotFingerprintVersion 'not-a-fingerprint' | Out-Null } catch { $refused = $true }
Check 'unreadable value is refused, not classified' $refused ''

# 8. cross-version comparison REFUSES -- the owner ruling, and the point of the whole change
$refused = $false; $msg = ''
try { Assert-PilotFingerprintComparable -A $v1 -B $v2 -Context 'test' } catch { $refused = $true; $msg = $_.Exception.Message }
Check 'v1 vs v2 comparison refused' ($refused -and $msg -match "'v1' vs 'v2'") ''

$refused = $false
try { Assert-PilotFingerprintComparable -A ('a' * 64) -B $v2 -Context 'test' } catch { $refused = $true }
Check 'legacy vs v2 comparison refused' $refused 'the 135 committed rows cannot be silently compared'

# 9. SPECIFICITY -- same version must still be ALLOWED, or the guard is just "always refuse"
$allowed = $true
try { Assert-PilotFingerprintComparable -A $v1 -B $v1 -Context 'test' | Out-Null } catch { $allowed = $false }
Check 'same-version comparison is allowed' $allowed 'a guard that refuses everything discriminates nothing'

Write-Host ''
if ($fail) { Write-Host "=== $fail CASE(S) FAILED ==="; exit 1 }
Write-Host '=== all cases passed, refusals and specificity included ==='
