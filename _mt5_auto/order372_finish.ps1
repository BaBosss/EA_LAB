<#
ORDER-372 finish-up: works around a pre-existing bug in scripts\order222_cutloss_probe.ps1
(Invoke-Probe calls mt5_run.ps1 without capturing its output, so mt5_run.ps1's Write-Output
lines leak into the function's own return value; when that value later gets piped into
Add-Member with a stray $null in it, the whole script crashes with a null InputObject error
before ever printing mt5_run.ps1's real diagnostic). This script does NOT edit that file.

Step 1: the cut30 leg's tester run already completed for real (verified: metatester64.exe
was actively crunching after the wrapper falsely reported FAIL, and its report has since
landed in the terminal's DataDir) - this step just does what mt5_run.ps1 itself would have
done with that report: move it into _mt5_auto\reports, run the truncation check, write the
leverage sidecar.

Step 2: run the cut100 leg directly via mt5_run.ps1 (correctly - its own console output is
allowed to reach this script's own output, not swallowed).

Step 3: parse both reports with the exact same field-extraction logic as
order222_cutloss_probe.ps1's Read-Result function, and print the same results table.
#>
$ErrorActionPreference = "Stop"
$root = "D:\EA_LAB"
$auto = "$root\_mt5_auto"
$reports = "$auto\reports"
$dataDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355"

# ---------- Step 1: finish the cut30 leg by hand ----------
$name30 = "O222_S2_ld125000_cut30"
$srcHtm = Join-Path $dataDir "$name30.htm"
$destHtm = Join-Path $reports "$name30.htm"
if (-not (Test-Path $destHtm)) {
  if (-not (Test-Path $srcHtm)) { throw "cut30 report not found at $srcHtm - it should already exist" }
  Move-Item $srcHtm $destHtm -Force
  Get-ChildItem $dataDir -Filter "$name30*.png" -File -ErrorAction SilentlyContinue | Move-Item -Destination $reports -Force
  Write-Output "moved cut30 report into place"
} else {
  Write-Output "cut30 report already in place"
}
$truncOut = ""; $truncCode = 0
try {
  $truncOut  = & (Join-Path $root 'scripts\check_truncated_run.ps1') -Report $destHtm -FromDate 2022.01.01 -ToDate 2023.07.01 2>&1 6>&1 | Out-String
  $truncCode = $LASTEXITCODE
} catch { $truncOut = "truncation check failed: $_"; $truncCode = -1 }
[PSCustomObject]@{ report_name=$name30; truncated=($truncCode -eq 2); detail=$truncOut.Trim() } |
  ConvertTo-Json | Set-Content "$reports\$name30.truncation_check.json" -Encoding utf8
Write-Output "cut30 truncation check: code=$truncCode"

# ---------- Step 2: run cut100 leg for real, output NOT swallowed ----------
$name100 = "O222_S2_ld125000_cut100"
$set100 = "$auto\ab_sets\order222\O222_ld125000_cut100.set"
if (-not (Test-Path $set100)) { throw "expected set file missing: $set100" }
Write-Output ""
Write-Output "=== running cut100 leg ==="
& (Join-Path $root 'scripts\mt5_run.ps1') -Expert "(NuiIndy) Dynamic RSI+ADX Style (4)" -Symbol EURUSD `
  -Period H1 -FromDate 2022.01.01 -ToDate 2023.07.01 -Model 4 -Deposit 10000 -Leverage 100 `
  -SetFile $set100 -ReportName $name100 -TimeoutSec 3600
Write-Output "cut100 mt5_run.ps1 exit code: $LASTEXITCODE"

# ---------- Step 3: parse both reports (same logic as order222_cutloss_probe.ps1 Read-Result) ----------
function Read-Result([string]$reportName) {
  $htm = Join-Path $reports "$reportName.htm"
  if (-not (Test-Path $htm)) { return $null }
  $flat  = (Get-Content $htm -Raw) -replace '<[^>]+>', '|'
  $parts = ($flat -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  function Field($label) {
    for ($i = 0; $i -lt $parts.Count - 1; $i++) { if ($parts[$i] -eq $label) { return $parts[$i+1] } }
    return $null
  }
  $eqdd = $null
  $raw = Field 'Equity Drawdown Maximal:'
  if ($raw) { $m = [regex]::Match($raw, '\((\d+(?:\.\d+)?)%\)'); if ($m.Success) { $eqdd = [double]$m.Groups[1].Value } }
  $pf = Field 'Profit Factor:'
  $tr = Field 'Total Trades:'
  $np = Field 'Total Net Profit:'
  $lev = $null
  $lm = [regex]::Match(($flat -replace '\|', ' '), 'Leverage:\s*1:(\d+)'); if ($lm.Success) { $lev = [int]$lm.Groups[1].Value }
  $trunc = $null
  $ts = Join-Path $reports "$reportName.truncation_check.json"
  if (Test-Path $ts) { $trunc = (Get-Content $ts -Raw | ConvertFrom-Json) }
  return [PSCustomObject]@{
    report = $reportName; pf = $pf; trades = $tr; net = $np; eqdd_pct = $eqdd; leverage = $lev
    truncated = $(if ($trunc) { $trunc.truncated } else { $null })
    trunc_detail = $(if ($trunc) { $trunc.detail } else { '' })
  }
}

$r30 = Read-Result $name30
$r100 = Read-Result $name100
Write-Output ""
Write-Output "=== RESULTS ==="
@($r30, $r100) | Where-Object { $_ } | Format-Table report, pf, trades, net, eqdd_pct, leverage, truncated -AutoSize | Out-String -Width 200 | Write-Output
if ($r30) { Write-Output "cut30 trunc_detail: $($r30.trunc_detail)" }
if ($r100) { Write-Output "cut100 trunc_detail: $($r100.trunc_detail)" }
if ($r30 -and $r100) {
  if (($r30.net -eq $r100.net) -and ($r30.trades -eq $r100.trades)) {
    Write-Output ">> [INCONCLUSIVE] both arms are identical - the kill STILL never fired."
  } else {
    Write-Output ">> the arms diverge, so the switch did something."
  }
}
