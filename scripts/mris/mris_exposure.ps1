# mris_exposure.ps1 - MRIS portfolio exposure map (ORDER-073 Phase-2 macro layer)
# Joins the live deployment inventory (DEPLOYMENTS.csv) to a carry/JPY/risk-on
# tag set, so a RISK_OFF state can point at the exact legs to reduce/watch
# BEFORE a forced-unwind. Read-only: it never touches a terminal or an order.
#
# Tagging is by symbol + strategy family, kept in $rules below (edit as the
# portfolio changes). Output = which magics are directly carry-exposed, plus a
# per-state action hint (reduce-lot / block-new / watch) - NEVER auto-close
# (user rule: correlation/risk -> reduce lot, not cut).
[CmdletBinding()]
param(
  [string]$Deployments = "D:\EA_LAB\portfolio\DEPLOYMENTS.csv",
  [string]$StateJson   = "D:\EA_LAB\portfolio\mris\regime_state.json",
  [string]$OutJson     = "D:\EA_LAB\portfolio\mris\exposure_map.json"
)
$ErrorActionPreference = "Stop"
if (!(Test-Path $Deployments)) { throw "DEPLOYMENTS.csv not found: $Deployments" }

$dep = Import-Csv $Deployments
$state = $null
if (Test-Path $StateJson) { $state = Get-Content $StateJson -Raw | ConvertFrom-Json }

# --- carry / risk exposure tagging ---
# tier: DIRECT_CARRY = JPY-cross grid (loses first in a carry-unwind)
#       RISK_ON      = leverage/risk-beta that bleeds in a broad risk-off
#       HEDGE        = tends to benefit or hold in risk-off (gold longs) -> do NOT gate
#       NEUTRAL_FX   = non-JPY, non-risk-beta -> minimal macro handle
function Get-CarryTag($symbol, $ea) {
  $s = "$symbol".ToUpper()
  $isJpy = ($s -match 'JPY')
  $isGold = ($s -match 'XAU')
  if ($isJpy) { return "DIRECT_CARRY" }
  if ($isGold) {
    # gold breakout/trend longs are a partial risk-off hedge; grids on gold still carry gap risk
    if ("$ea" -match 'Grid|Hedge|Kangaroo|Zeus') { return "RISK_ON" }
    return "HEDGE"
  }
  if ($s -match 'US30|NAS|SPX|US500|BTC|XAG') { return "RISK_ON" }
  return "NEUTRAL_FX"
}

# state -> action per tier (proposal only; user decides)
$actionByState = @{
  "RISK_ON"  = @{ DIRECT_CARRY="normal"; RISK_ON="normal"; HEDGE="normal"; NEUTRAL_FX="normal" }
  "NEUTRAL"  = @{ DIRECT_CARRY="watch";  RISK_ON="watch";  HEDGE="normal"; NEUTRAL_FX="normal" }
  "RISK_OFF" = @{ DIRECT_CARRY="reduce-lot x0.5 + block-new"; RISK_ON="reduce-lot x0.5"; HEDGE="normal"; NEUTRAL_FX="watch" }
  "STRESS"   = @{ DIRECT_CARRY="reduce-lot x0.5 + block-new (consider manual flatten)"; RISK_ON="reduce-lot x0.5 + block-new"; HEDGE="watch"; NEUTRAL_FX="reduce-lot x0.5" }
}
$curState = if ($state) { "$($state.state)" } else { "UNKNOWN" }
$actions = if ($actionByState.ContainsKey($curState)) { $actionByState[$curState] } else { $actionByState["NEUTRAL"] }

$rows = @()
foreach ($d in $dep) {
  if ("$($d.magic)".Trim() -eq "") { continue }   # skip unenumerated
  $tag = Get-CarryTag $d.symbol $d.ea_name
  $act = if ($actions.ContainsKey($tag)) { $actions[$tag] } else { "watch" }
  $rows += [pscustomobject]@{
    account=$d.account; ea=$d.ea_name; magic=$d.magic; symbol=$d.symbol
    type=$d.type; status=$d.status; carry_tag=$tag; suggested_action=$act
  }
}

$direct = @($rows | Where-Object { $_.carry_tag -eq "DIRECT_CARRY" })
$riskon = @($rows | Where-Object { $_.carry_tag -eq "RISK_ON" })

$out = [ordered]@{
  generated_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  state = $curState
  note  = "PROPOSAL ONLY - reduce-lot not cut (user rule). No terminal action taken."
  direct_carry_legs = @($direct | ForEach-Object { "$($_.ea) [$($_.magic)] $($_.symbol) ($($_.type)) -> $($_.suggested_action)" })
  risk_on_legs      = @($riskon | ForEach-Object { "$($_.ea) [$($_.magic)] $($_.symbol) ($($_.type)) -> $($_.suggested_action)" })
  all = $rows
}
$dir = Split-Path $OutJson -Parent
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$out | ConvertTo-Json -Depth 6 | Set-Content -Path $OutJson -Encoding UTF8

Write-Host "MRIS exposure @ state=$curState : DIRECT_CARRY=$($direct.Count) RISK_ON=$($riskon.Count) (of $($rows.Count) enumerated legs)"
foreach ($l in $out.direct_carry_legs) { Write-Host "  [carry] $l" }
Write-Host "-> $OutJson"
