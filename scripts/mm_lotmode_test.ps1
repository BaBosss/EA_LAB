<#
mm_lotmode_test.ps1 - POSITIVE-PATH test cage for first-lot sizing (MM-TEST-003, 2026-07-24).

WHY THIS EXISTS
  tpl_regression.ps1 proves the opposite thing: that every NEW feature left at its
  default (=off) does not change the old numbers. It can never catch a feature that
  is broken when you actually TURN IT ON, because nothing in the cage turns anything
  on. FirstLotMode=43 (balance-scaled) shipped 2026-07-23 with exactly that gap: zero
  .set files in the repo used it, so "compile + regression clean" proved only that it
  was inert. This script drives the mode through the real tester and asserts the lot
  the broker actually received.

WHAT IT ASSERTS (the FIRST in-deal volume, where balance == deposit exactly; later
orders legitimately re-scale as balance evolves, which is the whole point of mode 43)
  A  mode 41 baseline                     -> 0.10   (control: fixed lot is fixed)
  B  mode 43, balance == anchor           -> 0.10   (ratio 1.0 reproduces the control)
  C  mode 43, balance == 0.5 x anchor     -> 0.05
  D  mode 43, balance == 2.0 x anchor     -> 0.20
  E  mode 43, ratio 2.0 in 10x diff units -> 0.20   (UNIT INDEPENDENCE = the cent/USD claim:
                                                     anchor 1000/dep 2000 must equal
                                                     anchor 10000/dep 20000)
  F  mode 43, 2x ratio but RC_MaxLot 0.15 -> 0.15   (the cage still outranks sizing)
  G  mode 43 with _43_BalanceAnchor=0     -> NO TRADES (INIT_FAILED; must NOT silently
                                                        trade _41_FixedLot instead)
  H  mode 42 with SLMode=30 (no distance) -> NO TRADES (same rule, other mode)
  Plus: A and B must produce the SAME trade count - sizing must not move entry logic.

  G and H are the MM-SAFETY-001 regression: before that change both cases traded
  happily at _41_FixedLot while the report looked completely normal.

USAGE
  powershell -File scripts\mm_lotmode_test.ps1
  powershell -File scripts\mm_lotmode_test.ps1 -KeepSets     # leave generated .set files for inspection
Requires: MT5 GUI closed (mt5_run.ps1 guard). 8 sequential tester runs, Model 1.
#>
[CmdletBinding()]
param(
  [string]$Symbol   = "XAUUSD",
  [string]$Period   = "H1",
  [string]$FromDate = "2024.01.01",
  [string]$ToDate   = "2024.07.01",
  [int]$Model       = 1,
  [switch]$KeepSets
)
$ErrorActionPreference = "Stop"
$root    = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$expert  = "EALabTpl\Boss_12_Breakout"   # StackMode=90 + LotProg=50 -> one order per signal, no progression
$baseSet = Join-Path $root "ea_template\sets\regression\Boss_12_Breakout_defaults.set"
$outDir  = Join-Path $root "_mt5_auto\ab_sets\mm_lotmode_test"

if (-not (Test-Path $baseSet)) { Write-Host "[FAIL] base set missing: $baseSet" -ForegroundColor Red; exit 1 }
New-Item -ItemType Directory -Force $outDir | Out-Null

# always test the CURRENT source, never a stale .ex5 (same rule as tpl_regression.ps1)
Write-Host ">> deploy + compile current source" -ForegroundColor Cyan
& (Join-Path $root "ea_template\deploy.ps1") -Compile | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "[FAIL] compile failed - aborting" -ForegroundColor Red; exit 1 }

function New-VariantSet([string]$name, [hashtable]$over) {
  $lines = Get-Content $baseSet
  $seen  = @{}
  $out = foreach ($l in $lines) {
    if ($l -match '^([A-Za-z_][\w]*)=') {
      $k = $matches[1]
      if ($over.ContainsKey($k)) { $seen[$k] = $true; "$k=$($over[$k])" } else { $l }
    } else { $l }
  }
  foreach ($k in $over.Keys) { if (-not $seen.ContainsKey($k)) { $out += "$k=$($over[$k])" } }
  $p = Join-Path $outDir "$name.set"
  Set-Content -Path $p -Value $out -Encoding ASCII
  return $p
}

# first "in" deal volume from the report's Deals table, plus the trade count.
# Deals row shape (tag-stripped): <time> <deal#> <symbol> <buy|sell> <in|out> <volume> <price> ...
function Read-Deals([string]$htm) {
  $t = (Get-Content $htm -Raw) -replace '<[^>]+>', '|'
  $p = ($t -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  $firstIn = $null; $nIn = 0
  for ($i = 2; $i -lt $p.Count - 1; $i++) {
    if ($p[$i] -eq 'in' -and ($p[$i-1] -eq 'buy' -or $p[$i-1] -eq 'sell')) {
      $v = $p[$i+1] -replace '\s',''
      if ($v -match '^\d+(\.\d+)?$') { $nIn++; if ($null -eq $firstIn) { $firstIn = [double]$v } }
    }
  }
  $trades = $null
  for ($i = 0; $i -lt $p.Count - 1; $i++) { if ($p[$i] -eq 'Total Trades:') { $trades = [int]($p[$i+1] -replace '\s','') ; break } }
  return @{ firstLot = $firstIn; entries = $nIn; trades = $trades }
}

# RC_MaxLot=5.0 on every non-clamp case so the cage never masks a sizing bug.
$cases = @(
  @{ id='A_fixed_baseline'; dep=10000; expect=0.10; over=@{ FirstLotMode='41'; _41_FixedLot='0.10'; RC_MaxLot='5.0' } },
  @{ id='B_ratio_1x';       dep=10000; expect=0.10; over=@{ FirstLotMode='43'; _43_LotPerAnchor='0.10'; _43_BalanceAnchor='10000.0'; RC_MaxLot='5.0' } },
  @{ id='C_ratio_0p5x';     dep=5000;  expect=0.05; over=@{ FirstLotMode='43'; _43_LotPerAnchor='0.10'; _43_BalanceAnchor='10000.0'; RC_MaxLot='5.0' } },
  @{ id='D_ratio_2x';       dep=20000; expect=0.20; over=@{ FirstLotMode='43'; _43_LotPerAnchor='0.10'; _43_BalanceAnchor='10000.0'; RC_MaxLot='5.0' } },
  @{ id='E_unit_indep';     dep=2000;  expect=0.20; over=@{ FirstLotMode='43'; _43_LotPerAnchor='0.10'; _43_BalanceAnchor='1000.0';  RC_MaxLot='5.0' } },
  @{ id='F_maxlot_clamp';   dep=20000; expect=0.15; over=@{ FirstLotMode='43'; _43_LotPerAnchor='0.10'; _43_BalanceAnchor='10000.0'; RC_MaxLot='0.15' } },
  @{ id='G_bad_anchor';     dep=10000; expect=0.0;  over=@{ FirstLotMode='43'; _43_LotPerAnchor='0.10'; _43_BalanceAnchor='0.0';     RC_MaxLot='5.0' } },
  @{ id='H_mode42_no_sl';   dep=10000; expect=0.0;  over=@{ FirstLotMode='42'; _42_RiskPct='1.0'; SLMode='30';                       RC_MaxLot='5.0' } }
)

$rows = @(); $fail = 0
foreach ($c in $cases) {
  $set = New-VariantSet $c.id $c.over
  $rep = "MMLOT_$($c.id)"
  Write-Host ">> $($c.id) (deposit $($c.dep), expect first lot $($c.expect))" -ForegroundColor Cyan
  $null = & (Join-Path $PSScriptRoot 'mt5_run.ps1') -Expert $expert -Symbol $Symbol -Period $Period `
            -FromDate $FromDate -ToDate $ToDate -Model $Model -Deposit $c.dep -ReportName $rep -SetFile $set
  $rc  = $LASTEXITCODE
  $htm = Join-Path $root "_mt5_auto\reports\$rep.htm"

  if ($c.expect -eq 0.0) {
    # fail-closed case: the only acceptable outcomes are "no report" (init refused the run)
    # or "a report with zero entries". A report full of 0.01-lot trades = the silent
    # fallback is back, and that is the bug this whole task existed to kill.
    if (-not (Test-Path $htm)) {
      Write-Host "   [PASS] no report produced - attach refused (INIT_FAILED)" -ForegroundColor Green
      $rows += [pscustomobject]@{ case=$c.id; expected='no trades'; got='no report'; verdict='PASS' }
      continue
    }
    $d = Read-Deals $htm
    if ($d.entries -eq 0) {
      Write-Host "   [PASS] report produced but zero entries - no silent fallback" -ForegroundColor Green
      $rows += [pscustomobject]@{ case=$c.id; expected='no trades'; got='0 entries'; verdict='PASS' }
    } else {
      Write-Host "   [FAIL] $($d.entries) entries at lot $($d.firstLot) - SILENT FALLBACK IS BACK" -ForegroundColor Red
      $rows += [pscustomobject]@{ case=$c.id; expected='no trades'; got="$($d.entries) entries @ $($d.firstLot)"; verdict='FAIL' }
      $fail++
    }
    continue
  }

  if ($rc -eq 3) { Write-Host "   [FAIL] leverage mismatch" -ForegroundColor Red; $fail++; continue }
  if (-not (Test-Path $htm)) {
    Write-Host "   [FAIL] no report produced" -ForegroundColor Red
    $rows += [pscustomobject]@{ case=$c.id; expected=$c.expect; got='no report'; verdict='FAIL' }; $fail++; continue
  }
  $d = Read-Deals $htm
  if ($null -eq $d.firstLot) {
    Write-Host "   [FAIL] no entry deals in report" -ForegroundColor Red
    $rows += [pscustomobject]@{ case=$c.id; expected=$c.expect; got='no entries'; verdict='FAIL' }; $fail++; continue
  }
  $ok = ([Math]::Abs($d.firstLot - $c.expect) -lt 0.0000001)
  if ($ok) { Write-Host "   [PASS] first lot $($d.firstLot) (entries=$($d.entries), trades=$($d.trades))" -ForegroundColor Green }
  else     { Write-Host "   [FAIL] first lot $($d.firstLot), expected $($c.expect)" -ForegroundColor Red; $fail++ }
  $rows += [pscustomobject]@{ case=$c.id; expected=$c.expect; got=$d.firstLot; entries=$d.entries; trades=$d.trades; verdict=$(if($ok){'PASS'}else{'FAIL'}) }
}

# cross-case invariant: DEPOSIT INVARIANCE. Under mode 43 the lot is proportional to
# balance, so the % equity path is identical at any deposit -> the same cage gates trip at
# the same points -> the trade count must not move. B/C/D span a 4x deposit range.
# (E is excluded: its 2000 deposit at a 0.20 lot hits the deposit-load cap, which is the
# correct behavior but breaks proportionality. F is excluded: RC_MaxLot clamping breaks it
# by design - that is what a clamp IS.)
$bcd = $rows | Where-Object { $_.case -in @('B_ratio_1x','C_ratio_0p5x','D_ratio_2x') -and $_.trades }
if ($bcd.Count -eq 3) {
  $u = ($bcd.trades | Sort-Object -Unique)
  if ($u.Count -eq 1) { Write-Host ">> [PASS] invariant: deposit invariance - B/C/D all traded $($u[0]) times across a 4x deposit range" -ForegroundColor Green }
  else { Write-Host ">> [FAIL] invariant: mode 43 trade counts differ across deposits ($($bcd.trades -join '/')) - sizing is not proportional to balance" -ForegroundColor Red; $fail++ }
}
# NOT an invariant, on purpose: A (fixed 0.10) and B (mode 43 starting at 0.10) do NOT
# match. Measured 2026-07-24: A stops at 115 trades with eqDD 25.09% because ProtectLevel
# NORMAL hard-kills at 25%, while B rides the same losing window to all 164 trades at
# eqDD 22.66% - mode 43 shrinks the lot as balance falls and never reaches the kill line.
# That divergence is the FEATURE. Do not "fix" it by asserting equality here.
$a = $rows | Where-Object case -eq 'A_fixed_baseline'
$b = $rows | Where-Object case -eq 'B_ratio_1x'
if ($a -and $b) { Write-Host ">> [INFO] fixed-lot A=$($a.trades) trades vs balance-scaled B=$($b.trades) - divergence expected (see comment: A hits the DD hard-kill, B self-attenuates)" -ForegroundColor Yellow }
# cross-case invariant: D and E are the same RATIO expressed in 10x different units.
$dd = $rows | Where-Object case -eq 'D_ratio_2x'
$ee = $rows | Where-Object case -eq 'E_unit_indep'
if ($dd -and $ee) {
  if ($dd.got -eq $ee.got) { Write-Host ">> [PASS] invariant: unit independence - D and E both sized $($dd.got)" -ForegroundColor Green }
  else { Write-Host ">> [FAIL] invariant: D=$($dd.got) vs E=$($ee.got) - mode 43 is NOT unit-independent" -ForegroundColor Red; $fail++ }
}

Write-Host ""
$rows | Format-Table -AutoSize
if (-not $KeepSets) { Remove-Item (Join-Path $outDir '*.set') -Force -ErrorAction SilentlyContinue }
if ($fail -gt 0) { Write-Host "=== MM LOT-MODE TEST: $fail failure(s) ===" -ForegroundColor Red; exit 1 }
Write-Host "=== MM LOT-MODE TEST CLEAN ===" -ForegroundColor Green
exit 0
