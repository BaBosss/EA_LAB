<#
run_pilot_swap_probe_tests.ps1 - M1 LANE A / finding A-F1.

WHY THIS EXISTS
  scripts\lib\pilot_run.ps1, Get-PilotSwapModeProbeReference, declared its accumulator as

      $matches = @()

  PowerShell variable names are case-insensitive, so that local name IS the AUTOMATIC variable
  $Matches. Two lines later the loop condition runs

      "$($probe.taken_utc)" -match '^\d{4}-...Z$'

  and the -match operator OVERWRITES $Matches with the regex match dictionary on every successful
  comparison. The accumulator therefore stopped being an array:

    * on a VALID probe, `$matches += $probe` became Hashtable + PSCustomObject, which PowerShell
      refuses ("A hash table can only be added to another hash table") -- so a healthy BTC/ETH
      probe THREW instead of resolving.
    * on an INVALID probe (dated correctly, swap_mode missing/blank) the append was skipped, but
      $Matches was still the 1-entry match dictionary left behind by -match, so
      `if ($matches.Count -eq 1)` was TRUE and the function returned a FALSE CITATION for a
      probe file that contains no usable symbol-spec observation.

  Both directions are exercised below, which is the point: a cage that only proves the healthy
  path would have passed on the broken code (case 2 returned a string quite happily).

  The legitimate use of the automatic $Matches at the bottom of Get-PilotCryptoFinancing (a
  `[void](... -match ...)` immediately followed by `$Matches[1]`) is NOT the same defect and is
  deliberately left alone.

SCOPE / CATEGORY
  Fixture-only. Builds throwaway probe .jsonl files under a scratch repo root and calls the
  function directly. No MT5, no tester, no read of the real factory\runs\pilot\swap_probe.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\_test\run_pilot_swap_probe_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if ($RepoRoot -eq '') { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

. (Join-Path $RepoRoot 'scripts\lib\pilot_run.ps1')

$failures = @()
$checks   = 0
function Check { param([string]$Name, [bool]$Ok, [string]$Detail)
  $script:checks++
  if ($Ok) { Write-Output ("  [PASS] " + $Name) }
  else { Write-Output ("  [FAIL] " + $Name + " -- " + $Detail); $script:failures += ($Name + ": " + $Detail) }
}

$tmp = Join-Path $env:TEMP ('pilot_swap_probe_tests_' + [guid]::NewGuid().ToString('N').Substring(0,8))
$probeDir = Join-Path $tmp 'factory\runs\pilot\swap_probe'
New-Item -ItemType Directory -Force -Path $probeDir | Out-Null
$ctx = @{ RepoRoot = $tmp; Terminal = 'MT5_LANE_1' }

function Set-ProbeFiles { param([hashtable]$Files)
  Get-ChildItem -LiteralPath $probeDir -File -ErrorAction SilentlyContinue | Remove-Item -Force
  foreach ($name in $Files.Keys) {
    $lines = @($Files[$name])
    Set-Content -LiteralPath (Join-Path $probeDir $name) -Value $lines -Encoding ASCII
  }
}

# A probe line built field by field so a case can omit or corrupt exactly one field.
function New-ProbeLine {
  param([string]$Symbol = 'BTCUSD', [string]$Lane = 'MT5_LANE_1',
        [string]$Taken = '2026-08-04T11:22:33Z', $SwapMode = 'INTEREST_CURRENT',
        [string]$Entity = 'SwapProbe', [string]$Probe = 'spec', [switch]$OmitSwapMode)
  $o = [ordered]@{ entity = $Entity; probe = $Probe; logical_symbol = $Symbol; lane = $Lane
                   taken_utc = $Taken; swap_long = -14.31; swap_short = -0.49 }
  if (-not $OmitSwapMode) { $o['swap_mode'] = $SwapMode }
  return ((New-Object psobject -Property $o) | ConvertTo-Json -Compress -Depth 4)
}

function Invoke-Ref { param([string]$Symbol = 'BTCUSD')
  $r = @{ threw = $false; value = $null; message = '' }
  try { $r.value = Get-PilotSwapModeProbeReference -Ctx $ctx -Symbol $Symbol }
  catch { $r.threw = $true; $r.message = $_.Exception.Message }
  return $r
}

try {
  Write-Output 'A-F1 Get-PilotSwapModeProbeReference'

  # ---- 1. HEALTHY CONTROL: exactly one valid dated probe resolves, and does NOT throw.
  Set-ProbeFiles @{ 'swap_probe_20260804.jsonl' = @((New-ProbeLine)) }
  $r = Invoke-Ref
  Check 'healthy: one valid probe does not throw' (-not $r.threw) $r.message
  Check 'healthy: resolves to the probe file path' `
    ($r.value -eq 'factory/runs/pilot/swap_probe/swap_probe_20260804.jsonl') ("got: " + $r.value)

  # ---- 2. THE FALSE CITATION. Dated correctly, swap_mode ABSENT. The -match in the loop
  #        condition succeeded, so the corrupted $Matches had Count 1 and a citation was emitted
  #        for a file with no usable observation. Must REFUSE and must emit NO citation.
  Set-ProbeFiles @{ 'swap_probe_20260804.jsonl' = @((New-ProbeLine -OmitSwapMode)) }
  $r = Invoke-Ref
  Check 'missing swap_mode: refuses' $r.threw ("returned instead: " + $r.value)
  Check 'missing swap_mode: emits no citation' ($null -eq $r.value) ("citation leaked: " + $r.value)

  # ---- 2b. same, but swap_mode present and BLANK (an unreadable value is not an absent field).
  Set-ProbeFiles @{ 'swap_probe_20260804.jsonl' = @((New-ProbeLine -SwapMode '')) }
  $r = Invoke-Ref
  Check 'blank swap_mode: refuses' $r.threw ("returned instead: " + $r.value)
  Check 'blank swap_mode: emits no citation' ($null -eq $r.value) ("citation leaked: " + $r.value)

  # ---- 3. undated / malformed taken_utc -> refuse, no citation.
  Set-ProbeFiles @{ 'swap_probe_20260804.jsonl' = @((New-ProbeLine -Taken '2026-08-04')) }
  $r = Invoke-Ref
  Check 'undated probe: refuses' $r.threw ("returned instead: " + $r.value)
  Check 'undated probe: emits no citation' ($null -eq $r.value) ("citation leaked: " + $r.value)

  # ---- 4. AMBIGUITY. Two valid probes for the same symbol+lane in one file is not one
  #        reference; the function must not silently pick one.
  Set-ProbeFiles @{ 'swap_probe_20260804.jsonl' = @((New-ProbeLine),
                                                    (New-ProbeLine -Taken '2026-08-04T12:00:00Z')) }
  $r = Invoke-Ref
  Check 'two matches in one file: refuses' $r.threw ("returned instead: " + $r.value)

  # ---- 5. wrong lane and wrong symbol are not matches.
  Set-ProbeFiles @{ 'swap_probe_20260804.jsonl' = @((New-ProbeLine -Lane 'MT5_LANE_2')) }
  Check 'wrong lane: refuses' (Invoke-Ref).threw ''
  Set-ProbeFiles @{ 'swap_probe_20260804.jsonl' = @((New-ProbeLine -Symbol 'ETHUSD')) }
  Check 'wrong symbol: refuses' (Invoke-Ref).threw ''

  # ---- 6. MULTI-FILE, newest first. The newest file holds only non-matching rows; the match
  #        lives in an older file. Proves the per-file accumulator is reset per file and that a
  #        non-matching newest file does not poison or short-circuit the walk.
  Set-ProbeFiles @{ 'swap_probe_20260812_ethusd.jsonl' = @((New-ProbeLine -Symbol 'ETHUSD'))
                    'swap_probe_20260804.jsonl'        = @((New-ProbeLine)) }
  $r = Invoke-Ref
  Check 'multi-file: older file supplies the match' `
    ($r.value -eq 'factory/runs/pilot/swap_probe/swap_probe_20260804.jsonl') `
    ("threw=" + $r.threw + " value=" + $r.value + " " + $r.message)

  # ---- 7. invalid JSON must REFUSE by name, not be skipped as "no match" (an unreadable input
  #        is not an absent one -- memory `unreadable-input-must-refuse-not-skip`).
  Set-ProbeFiles @{ 'swap_probe_20260804.jsonl' = @('{ this is not json') }
  $r = Invoke-Ref
  Check 'invalid JSON: refuses' $r.threw ''
  Check 'invalid JSON: names the file' ($r.message -match 'swap_probe_20260804\.jsonl') $r.message

  # ---- 8. STATIC REGRESSION GUARD. The automatic-variable collision must not silently return.
  #        Scans the function body only, so an unrelated legitimate $Matches read elsewhere in
  #        the file (Get-PilotCryptoFinancing) cannot satisfy or trip this check.
  $src  = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\lib\pilot_run.ps1') -Raw
  $body = ''
  if ($src -match '(?s)function\s+Get-PilotSwapModeProbeReference\b(.*?)\r?\nfunction\s') { $body = $Matches[1] }
  Check 'static: function body located for scanning' ($body -ne '') 'regex did not isolate the function'
  Check 'static: no assignment to the automatic $matches inside the function' `
    ($body -notmatch '(?im)^\s*\$matches\s*(=|\+=)') `
    'an accumulator named $matches aliases the automatic variable that -match overwrites'
  # A regex cannot decide this one: `@($x).Count` is the SAFE idiom and `($x).Count` is the bug,
  # and they differ only by the character before the matching open paren. So walk the parens.
  # (The first draft of this check used `\)\s*\.Count` and flagged the repaired, correct code --
  # a guard that cannot tell the fix from the defect is not a guard.)
  $unwrapped = @()
  for ($i = 0; $i -lt $body.Length; $i++) {
    if ($body[$i] -ne ')') { continue }
    if ($body.Substring($i) -notmatch '^\)\s*\.Count') { continue }
    $depth = 0; $open = -1
    for ($j = $i; $j -ge 0; $j--) {
      if ($body[$j] -eq ')') { $depth++ }
      elseif ($body[$j] -eq '(') { $depth--; if ($depth -eq 0) { $open = $j; break } }
    }
    if ($open -le 0) { $unwrapped += '(.Count at start of body)'; continue }
    if ($body[$open - 1] -ne '@') { $unwrapped += $body.Substring($open, [Math]::Min(40, $body.Length - $open)) }
  }
  Check 'static: no ($pipeline).Count on an unwrapped group in the function' `
    (@($unwrapped).Count -eq 0) `
    ("use @(...).Count -- (\$x).Count is \$null for a single result; found: " + ($unwrapped -join ' | '))
  # And the check itself must be able to fire: prove it flags the unsafe form.
  $probeBody = 'if (($files | Where-Object { $_ }).Count -eq 1) { }'
  $selfHits = @()
  for ($i = 0; $i -lt $probeBody.Length; $i++) {
    if ($probeBody[$i] -ne ')') { continue }
    if ($probeBody.Substring($i) -notmatch '^\)\s*\.Count') { continue }
    $depth = 0; $open = -1
    for ($j = $i; $j -ge 0; $j--) {
      if ($probeBody[$j] -eq ')') { $depth++ }
      elseif ($probeBody[$j] -eq '(') { $depth--; if ($depth -eq 0) { $open = $j; break } }
    }
    if ($open -gt 0 -and $probeBody[$open - 1] -ne '@') { $selfHits += 'hit' }
  }
  Check 'static: the .Count check is not inert (fires on a planted unsafe form)' `
    (@($selfHits).Count -eq 1) ("planted-defect hits: " + @($selfHits).Count)
}
finally {
  if (Test-Path -LiteralPath $tmp) { Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue }
}

Write-Output ''
Write-Output ("checks run: " + $checks + "  failures: " + @($failures).Count)
if (@($failures).Count -gt 0) {
  foreach ($f in $failures) { Write-Output ("  FAILED: " + $f) }
  Write-Output 'RESULT: FAIL'
  exit 1
}
Write-Output 'RESULT: PASS'
exit 0
