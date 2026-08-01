<#
verify_config_fingerprint.ps1 - ORDER-710. Does the EA's [CFG] fingerprint equal the compiler's?

WHAT IT PROVES, and why nothing cheaper proves it. `_triage\factory_os\preset.py` hashes a
preimage in Python; `ea_template\core\InputSurface_gen.mqh` builds the same preimage in MQL5 and
hashes it with CryptEncode(CRYPT_HASH_SHA256). The python cage
(run_input_surface_tests.py) proves the two DESCRIPTIONS agree - same inputs, same order, same
canonicaliser - by reading the emitted MQL5 back. It cannot prove the two IMPLEMENTATIONS agree,
because it does not execute MQL5. Only a tester run does that, and this is the run.

TWO RUNS, NOT ONE, and the second is the point. A single matching run is also what you would see
if the EA printed a constant, or hashed something it computed from the source rather than from
its live inputs. So this runs the same build twice with DIFFERENT .set files and requires:

  1. run A's logged hash == the compiler's hash for A     (they agree)
  2. run B's logged hash == the compiler's hash for B     (they agree again)
  3. A != B                                                (the values reach the hash at all)

Failing 3 while passing 1 and 2 is the interesting failure: it means both sides are computing
something stable and neither is computing the configuration.

REQUIRES: MT5 GUI closed (mt5_run.ps1's guard), and a compiled binary in the lane being measured
- run ea_template\deploy.ps1 -Compile first. This is a MANUAL evidence tool, like
tpl_regression.ps1: it costs two tester runs and is not in the pre-commit tier.

USAGE  powershell -NoProfile -File scripts\verify_config_fingerprint.ps1
ASCII only (PS 5.1 reads a BOM-less .ps1 as ANSI).
#>
[CmdletBinding()]
param(
  [string]$BuildTag = 'LAB_ENTRY_16',
  [string]$Expert   = 'EALabTpl\Boss_16_KangarooGrid',
  [string]$Symbol   = 'XAUUSD',
  [string]$Period   = 'H1',
  [string]$FromDate = '2024.01.01',
  [string]$ToDate   = '2024.01.15',
  [int]$Model       = 1,
  # lane 1, pinned EXPLICITLY and not inherited (Decision log 2026-07-30: a cage that inherits
  # mt5_run.ps1's default compiled one install and measured another).
  [string]$Terminal = 'D:\Meta 5\terminal64.exe',
  [string]$DataDir  = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
  # The agent logs live under the TESTER tree, not the terminal data folder.
  [string]$AgentRoot = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Tester\9CA16B8382AE4CF692710FB36B9DA355'
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$py = Join-Path $root 'tools\python312\python.exe'
$genPreset = Join-Path $root '_triage\factory_os\gen_default_preset.py'
$work = Join-Path $env:TEMP ('o710_fp_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force $work | Out-Null

function Fail([string]$msg) {
  Write-Host ("[FAIL] " + $msg) -ForegroundColor Red
  exit 1
}

# The EA prints one line per attach; the LAST one after a run's start is that run's.
$FP_LINE = '\[CFG\] input surface: build=(\S+) keys=(\d+) scope=(\S+) effective_config_hash=([0-9a-f]{64})'

function Get-LoggedFingerprint([datetime]$since) {
  $logs = Get-ChildItem -Path $AgentRoot -Recurse -Filter '*.log' -ErrorAction SilentlyContinue |
          Where-Object { $_.LastWriteTime -ge $since.AddSeconds(-5) }
  if (-not $logs) { return $null }
  $best = $null
  foreach ($l in $logs) {
    # MT5 writes its logs UTF-16LE. Reading them as UTF-8 finds zero matches and reports it as
    # "the EA printed nothing" (memory prove-the-instrument-can-see-the-file).
    $text = Get-Content -LiteralPath $l.FullName -Encoding Unicode -ErrorAction SilentlyContinue
    foreach ($line in $text) {
      if ($line -match $FP_LINE) {
        $best = [pscustomobject]@{
          Build = $Matches[1]; Keys = [int]$Matches[2]; Scope = $Matches[3]
          Hash = $Matches[4];  Log = $l.FullName
        }
      }
    }
  }
  return $best
}

function New-Preset([string]$name, [string[]]$overrides) {
  $out = Join-Path $work ($name + '.set')
  $args = @($genPreset, '--build', $BuildTag, '--out', $out)
  foreach ($o in $overrides) { $args += @('--override', $o) }
  $lines = & $py $args
  if ($LASTEXITCODE -ne 0) { Fail ("gen_default_preset.py failed for " + $name + ": " + ($lines -join ' ')) }
  $h = @{}
  foreach ($l in $lines) { $kv = $l -split '=', 2; if ($kv.Count -eq 2) { $h[$kv[0]] = $kv[1] } }
  return [pscustomobject]@{ Set = $out; Hash = $h['expected_hash']; Keys = [int]$h['keys']; Scope = $h['scope'] }
}

function Invoke-Run([string]$tag, [string]$setFile) {
  $started = Get-Date
  Write-Host (">> tester run " + $tag + " (" + $Symbol + " " + $Period + " " + $FromDate + ".." + $ToDate + ", model " + $Model + ")") -ForegroundColor Cyan
  & (Join-Path $PSScriptRoot 'mt5_run.ps1') -Expert $Expert -Symbol $Symbol -Period $Period `
      -FromDate $FromDate -ToDate $ToDate -SetFile $setFile -Model $Model `
      -ReportName ("O710_FP_" + $tag) -Terminal $Terminal -DataDir $DataDir | Out-Null
  $got = Get-LoggedFingerprint $started
  if (-not $got) {
    Fail ("run " + $tag + ": no '[CFG] input surface:' line in any agent log written after " + $started.ToString('HH:mm:ss') + ". Either the EA did not attach, or the enumeration is not wired into this binary. Agent root: " + $AgentRoot)
  }
  return $got
}

Write-Host (">> LANE: " + $Terminal) -ForegroundColor Cyan
if (-not (Test-Path $Terminal)) { Fail ("terminal not found on the pinned lane: " + $Terminal) }
$ex5 = Join-Path $DataDir ('MQL5\Experts\' + $Expert + '.ex5')
if (-not (Test-Path $ex5)) { Fail ("no compiled binary at " + $ex5 + " - run ea_template\deploy.ps1 -Compile first. A run against an absent or stale .ex5 measures some other source tree.") }
Write-Host (">> binary: " + $ex5 + "  (built " + (Get-Item $ex5).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') + ")") -ForegroundColor DarkGray

$A = New-Preset 'A_defaults' @()
# B differs from A in one double and one bool. Both are inside build 16's surface; a name that is
# not would be REFUSED by the compiler rather than silently ignored, which is why the override
# goes through it instead of being sed'ed into the file.
$B = New-Preset 'B_perturbed' @('_9_StepPoints=444.0', 'DryRun=true')

Write-Host (">> compiler A: " + $A.Hash + " (" + $A.Keys + " keys, " + $A.Scope + ")") -ForegroundColor DarkGray
Write-Host (">> compiler B: " + $B.Hash) -ForegroundColor DarkGray
if ($A.Hash -eq $B.Hash) { Fail "the compiler produced the SAME hash for two different configurations - the rest of this run would be meaningless" }

$gotA = Invoke-Run 'A' $A.Set
$gotB = Invoke-Run 'B' $B.Set

Write-Host ""
Write-Host ">> RESULT" -ForegroundColor Cyan
Write-Host ("   A  compiler " + $A.Hash)
Write-Host ("   A  EA       " + $gotA.Hash + "  build=" + $gotA.Build + " keys=" + $gotA.Keys + " scope=" + $gotA.Scope)
Write-Host ("   B  compiler " + $B.Hash)
Write-Host ("   B  EA       " + $gotB.Hash + "  build=" + $gotB.Build + " keys=" + $gotB.Keys + " scope=" + $gotB.Scope)
Write-Host ("   log        " + $gotB.Log)

$bad = @()
if ($gotA.Hash -ne $A.Hash) { $bad += "run A: the EA hashed " + $gotA.Hash + ", the compiler " + $A.Hash }
if ($gotB.Hash -ne $B.Hash) { $bad += "run B: the EA hashed " + $gotB.Hash + ", the compiler " + $B.Hash }
if ($gotA.Hash -eq $gotB.Hash) { $bad += "the EA printed the SAME hash for two different .set files - the values are not reaching the digest" }
if ($gotA.Build -ne $BuildTag) { $bad += "the EA reports build=" + $gotA.Build + ", not " + $BuildTag }
if ($gotA.Keys -ne $A.Keys) { $bad += "the EA enumerated " + $gotA.Keys + " keys, the compiler " + $A.Keys }
if ($gotA.Scope -ne $A.Scope) { $bad += "scope disagrees: EA " + $gotA.Scope + " vs compiler " + $A.Scope }

if ($bad.Count -gt 0) {
  Write-Host ""
  foreach ($b in $bad) { Write-Host ("  - " + $b) -ForegroundColor Red }
  Fail "the EA and the compiler do not agree"
}
Write-Host ""
Write-Host ">> CLEAN - the EA and the compiler agree on both configurations, and disagree between them" -ForegroundColor Green
Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
exit 0
