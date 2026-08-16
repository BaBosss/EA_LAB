<#
Expectation semantics regression for the control-room rate monitor.

This is an offline seam test. It does not run MT5, read the live account, or
write a snapshot. The public seam is the expectation-assessment library used
by control_room_snapshot.ps1.
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

$lib = Join-Path $RepoRoot 'scripts\lib\expectation_semantics.ps1'
if (-not (Test-Path $lib)) { throw "missing: $lib" }
. $lib

$script:pass = 0
$script:fail = 0
function Assert-Equal {
  param([string]$What, $Expected, $Actual)
  if ("$Expected" -eq "$Actual") {
    $script:pass++
    Write-Host ("   [PASS] {0}" -f $What) -ForegroundColor Green
  } else {
    $script:fail++
    Write-Host ("   [FAIL] {0}; expected={1}; actual={2}" -f $What, $Expected, $Actual) -ForegroundColor Red
  }
}
function Assert-True {
  param([string]$What, $Condition)
  Assert-Equal $What $true ([bool]$Condition)
}
function Assert-Null {
  param([string]$What, $Actual)
  Assert-True $What ($null -eq $Actual)
}

Write-Host '=== expectation semantics: basket versus magic ==='

$expectations = @(
  [pscustomobject]@{ account='463666728'; magic='990066'; basket_id='IchiADX_USDJPY_basket'; trades_per_month_expected='4.58'; source_evidence='merged basket'; notes='NOT separable per single magic' },
  [pscustomobject]@{ account='463666728'; magic='990067'; basket_id='IchiADX_USDJPY_basket'; trades_per_month_expected='4.58'; source_evidence='merged basket'; notes='NOT separable per single magic' },
  [pscustomobject]@{ account='463666728'; magic='990068'; basket_id='IchiADX_XAU_basket'; trades_per_month_expected='4.32'; source_evidence='combined basket'; notes='NOT separable per single magic' },
  [pscustomobject]@{ account='463666728'; magic='990069'; basket_id='IchiADX_XAU_basket'; trades_per_month_expected='4.32'; source_evidence='combined basket'; notes='NOT separable per single magic' },
  [pscustomobject]@{ account='100000001'; magic='900001'; basket_id=''; trades_per_month_expected='4.33'; source_evidence='standalone backtest'; notes='' }
)

$observations = @(
  [pscustomobject]@{ account='463666728'; magic='990066'; closed_trades=0; days_active=28; start_date='2026-07-01'; forward_observed=$true },
  [pscustomobject]@{ account='463666728'; magic='990067'; closed_trades=3; days_active=28; start_date='2026-07-01'; forward_observed=$true },
  [pscustomobject]@{ account='463666728'; magic='990068'; closed_trades=0; days_active=28; start_date='2026-07-01'; forward_observed=$true },
  [pscustomobject]@{ account='463666728'; magic='990069'; closed_trades=0; days_active=28; start_date='2026-07-01'; forward_observed=$true },
  [pscustomobject]@{ account='100000001'; magic='900001'; closed_trades=0; days_active=28; start_date='2026-07-01'; forward_observed=$true }
)

$result = Get-ExpectationRateAssessments -Observations $observations -Expectations $expectations
$legs = @($result.legs)
$baskets = @($result.baskets)

foreach ($m in @('990066','990067','990068','990069')) {
  $leg = $legs | Where-Object { $_.magic -eq $m } | Select-Object -First 1
  Assert-Equal "IchiADX $m does not emit a per-magic rate flag" 'NOT_SEPARABLE' $leg.rate_flag
  Assert-Equal "IchiADX $m expectation unit is basket" 'BASKET' $leg.expectation_unit
  Assert-Null "IchiADX $m does not copy basket rate to the magic" $leg.expected_trades_per_week
  Assert-Equal "IchiADX $m keeps observation count" $(if ($m -eq '990067') { 3 } else { 0 }) $leg.closed_trades
}

$usd = $baskets | Where-Object { $_.basket_id -eq 'IchiADX_USDJPY_basket' } | Select-Object -First 1
$xau = $baskets | Where-Object { $_.basket_id -eq 'IchiADX_XAU_basket' } | Select-Object -First 1
Assert-Equal 'USDJPY basket has two members' 2 @($usd.member_magics).Count
Assert-Equal 'USDJPY basket aggregates observations' 3 $usd.observed_trades
Assert-Equal 'one quiet leg does not make the basket under-rate' 'ON_RATE' $usd.rate_flag
Assert-Equal 'XAU basket has two members' 2 @($xau.member_magics).Count
Assert-Equal 'XAU basket aggregates zero observations' 0 $xau.observed_trades
Assert-Equal 'actual basket inactivity raises the warning' 'UNDER_RATE' $xau.rate_flag
Assert-Equal 'basket warning is an expectation violation' 'EXPECTATION_VIOLATION' $xau.expectation_violation

$standalone = $legs | Where-Object { $_.magic -eq '900001' } | Select-Object -First 1
Assert-Equal 'unrelated standalone deployment keeps magic unit' 'MAGIC' $standalone.expectation_unit
Assert-Equal 'unrelated standalone deployment keeps per-magic warning' 'UNDER_RATE' $standalone.rate_flag
Assert-Equal 'unrelated standalone deployment keeps expected rate' 1.0 $standalone.expected_trades_per_week

$fourLegExpectations = @(
  1..4 | ForEach-Object {
    [pscustomobject]@{ account='200000001'; magic=("91{0:D4}" -f $_); basket_id='FOUR_LEG'; trades_per_month_expected='4.00'; source_evidence='combined basket'; notes='NOT separable per single magic' }
  }
)
$fourLegObservations = @(
  1..4 | ForEach-Object {
    [pscustomobject]@{ account='200000001'; magic=("91{0:D4}" -f $_); closed_trades=$(if ($_ -eq 1) { 0 } else { 1 }); days_active=28; start_date='2026-07-01'; forward_observed=$true }
  }
)
$fourLeg = Get-ExpectationRateAssessments -Observations $fourLegObservations -Expectations $fourLegExpectations
$fourBasket = @($fourLeg.baskets) | Select-Object -First 1
Assert-Equal 'four-leg basket remains one expectation unit' 1 @($fourLeg.baskets).Count
Assert-Equal 'four-leg basket evaluates all members together' 4 @($fourBasket.member_magics).Count
Assert-Equal 'four-leg basket is on rate from aggregate activity' 'ON_RATE' $fourBasket.rate_flag

Write-Host ("RESULT {0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail -ne 0) { exit 1 }
