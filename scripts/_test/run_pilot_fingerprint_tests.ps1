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

# 6. version classification, including the legacy bare digest
Check 'a bare sha is v1, not a third state' ((Get-PilotFingerprintVersion ('a' * 64)) -eq 'v1') 'the recipe is identical, so the label must be too'
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

Write-Host ''
if ($fail) { Write-Host "=== $fail CASE(S) FAILED ==="; exit 1 }
Write-Host '=== all cases passed, refusals and specificity included ==='
