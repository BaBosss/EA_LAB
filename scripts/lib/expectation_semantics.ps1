<#
Expectation-rate semantics shared by the control-room snapshot.

The expectations CSV is one row per magic for inventory coverage, but a row can
carry a basket-level, non-separable rate. Such a rate is an expectation of the
economic basket, not of each constituent magic. This library keeps the raw
per-magic observation while emitting any expectation violation only for the
correct unit.
#>

function Test-NonSeparableExpectation {
  param([object]$Expectation)
  if ($null -eq $Expectation) { return $false }
  $text = "$($Expectation.source_evidence) $($Expectation.notes)"
  return ($text -match '(?i)NOT\s+separable\s+per\s+single\s+magic')
}

function Get-ExpectedWeeklyRate {
  param([object]$Expectation)
  if ($null -eq $Expectation) { return $null }
  $monthly = 0.0
  if (-not [double]::TryParse("$($Expectation.trades_per_month_expected)", [ref]$monthly)) { return $null }
  if ($monthly -le 0) { return $null }
  return [math]::Round($monthly / 4.33, 1)
}

function Get-ExpectationRateStatus {
  param(
    [object]$ObservedTrades,
    [object]$DaysActive,
    [object]$ExpectedWeeklyRate,
    [int]$MinimumDays = 14
  )

  $status = [ordered]@{
    observed_trades = $null
    days_active = $null
    observed_trades_per_week = $null
    rate_flag = 'NA'
    expectation_violation = 'NOT_EVALUATED'
    status_reason = 'NO_EXPECTATION'
  }
  if ($null -eq $ExpectedWeeklyRate) { return [pscustomobject]$status }

  $trades = 0.0
  $days = 0.0
  if (-not [double]::TryParse("$ObservedTrades", [ref]$trades)) {
    $status.status_reason = 'OBSERVATION_UNAVAILABLE'
    return [pscustomobject]$status
  }
  if (-not [double]::TryParse("$DaysActive", [ref]$days) -or $days -lt $MinimumDays) {
    $status.observed_trades = [int]$trades
    $status.days_active = if ($days -gt 0) { [int]$days } else { $null }
    $status.status_reason = 'INSUFFICIENT_HISTORY'
    return [pscustomobject]$status
  }

  $observedWeekly = [math]::Round($trades * 7.0 / $days, 1)
  $status.observed_trades = [int]$trades
  $status.days_active = [int]$days
  $status.observed_trades_per_week = $observedWeekly
  if ($observedWeekly -lt (0.5 * [double]$ExpectedWeeklyRate)) {
    $status.rate_flag = 'UNDER_RATE'
    $status.expectation_violation = 'EXPECTATION_VIOLATION'
    $status.status_reason = 'OBSERVED_BELOW_HALF_EXPECTED'
  } else {
    $status.rate_flag = 'ON_RATE'
    $status.expectation_violation = 'NONE'
    $status.status_reason = 'OBSERVED_AT_OR_ABOVE_HALF_EXPECTED'
  }
  return [pscustomobject]$status
}

function Get-ExpectationRateAssessments {
  param(
    [object[]]$Observations,
    [object[]]$Expectations,
    [int]$MinimumDays = 14
  )

  $expByKey = @{}
  foreach ($e in @($Expectations)) {
    if ($null -eq $e -or -not $e.account -or -not $e.magic) { continue }
    $expByKey["$($e.account)|$($e.magic)"] = $e
  }

  $legs = @()
  $basketGroups = @{}
  foreach ($o in @($Observations)) {
    if ($null -eq $o -or -not $o.account -or -not $o.magic) { continue }
    $key = "$($o.account)|$($o.magic)"
    $e = $expByKey[$key]
    $isBasket = (Test-NonSeparableExpectation $e) -and (-not [string]::IsNullOrWhiteSpace("$($e.basket_id)"))
    $unit = if ($isBasket) { 'BASKET' } else { 'MAGIC' }
    $expectationKey = if ($isBasket) { "$($o.account)|$($e.basket_id)" } else { $key }
    $expectedWeekly = Get-ExpectedWeeklyRate $e
    $status = if ($isBasket) {
      [pscustomobject]@{
        observed_trades = $null
        days_active = $null
        observed_trades_per_week = $null
        rate_flag = 'NOT_SEPARABLE'
        expectation_violation = 'NOT_EVALUATED'
        status_reason = 'BASKET_EXPECTATION'
      }
    } else {
      Get-ExpectationRateStatus $o.closed_trades $o.days_active $expectedWeekly $MinimumDays
    }

    $leg = [ordered]@{
      account = $o.account
      magic = $o.magic
      closed_trades = $o.closed_trades
      days_active = $o.days_active
      expectation_unit = $unit
      expectation_key = $expectationKey
      expected_trades_per_week = if ($isBasket) { $null } else { $expectedWeekly }
      observed_trades_per_week = if ($isBasket) { $null } else { $status.observed_trades_per_week }
      rate_flag = $status.rate_flag
      expectation_violation = $status.expectation_violation
      expectation_status_reason = $status.status_reason
    }
    $legs += $leg

    if ($isBasket) {
      $groupKey = $expectationKey
      if (-not $basketGroups.ContainsKey($groupKey)) { $basketGroups[$groupKey] = @() }
      $basketGroups[$groupKey] += [pscustomobject]@{
        expectation = $e
        leg = $leg
        observation = $o
        expected_weekly = $expectedWeekly
      }
    }
  }

  $baskets = @()
  foreach ($groupKey in @($basketGroups.Keys | Sort-Object)) {
    $members = @($basketGroups[$groupKey])
    $expectedRates = @($members | Where-Object { $null -ne $_.expected_weekly } | Select-Object -ExpandProperty expected_weekly -Unique)
    $account = $members[0].observation.account
    $basketId = $members[0].expectation.basket_id
    $base = [ordered]@{
      account = $account
      basket_id = $basketId
      expectation_unit = 'BASKET'
      expectation_key = $groupKey
      member_magics = @($members | ForEach-Object { $_.observation.magic } | Sort-Object)
      expected_trades_per_week = $null
      observed_trades = $null
      days_active = $null
      observed_trades_per_week = $null
      rate_flag = 'NA'
      expectation_violation = 'NOT_EVALUATED'
      status_reason = 'NO_EXPECTATION'
    }

    if ($expectedRates.Count -ne 1) {
      $base.status_reason = if ($expectedRates.Count -gt 1) { 'CONFLICTING_EXPECTATIONS' } else { 'NO_EXPECTATION' }
    } else {
      $sameStart = @($members | ForEach-Object { "$($_.observation.start_date)" } | Select-Object -Unique).Count -eq 1
      $validObservations = @($members | Where-Object {
        $trade = 0.0
        $day = 0.0
        [double]::TryParse("$($_.observation.closed_trades)", [ref]$trade) -and
          [double]::TryParse("$($_.observation.days_active)", [ref]$day) -and
          $day -gt 0
      })
      if (-not $sameStart) {
        $base.status_reason = 'INCOMPARABLE_WINDOWS'
      } elseif ($validObservations.Count -ne $members.Count) {
        $base.status_reason = 'OBSERVATION_UNAVAILABLE'
      } else {
        $tradeSum = [int](($validObservations | ForEach-Object { [double]$_.observation.closed_trades } | Measure-Object -Sum).Sum)
        $dayValues = @($validObservations | ForEach-Object { [int]$_.observation.days_active })
        $commonDays = ($dayValues | Measure-Object -Minimum).Minimum
        $status = Get-ExpectationRateStatus $tradeSum $commonDays $expectedRates[0] $MinimumDays
        $base.expected_trades_per_week = $expectedRates[0]
        $base.observed_trades = $status.observed_trades
        $base.days_active = $status.days_active
        $base.observed_trades_per_week = $status.observed_trades_per_week
        $base.rate_flag = $status.rate_flag
        $base.expectation_violation = $status.expectation_violation
        $base.status_reason = $status.status_reason
      }
    }
    $baskets += [pscustomobject]$base

    foreach ($member in $members) {
      $member.leg.expected_trades_per_week = $null
      $member.leg.observed_trades_per_week = $null
      $member.leg.rate_flag = 'NOT_SEPARABLE'
      $member.leg.expectation_violation = 'NOT_EVALUATED'
      $member.leg.expectation_status_reason = 'BASKET_EXPECTATION'
    }
  }

  return [ordered]@{
    legs = @($legs)
    baskets = @($baskets)
    standalone_under_rate = @($legs | Where-Object { $_.expectation_unit -eq 'MAGIC' -and $_.rate_flag -eq 'UNDER_RATE' }).Count
    basket_under_rate = @($baskets | Where-Object { $_.rate_flag -eq 'UNDER_RATE' }).Count
  }
}
