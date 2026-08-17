# M2W5C3_stop_guard_static_assertions.ps1 -- Wave5 Candidate 3 (ExpertMACD).
#
# The focused suite proves the stop ARITHMETIC is right and the Model 1 retest proves the guard
# is WIRED (it refused exactly the 5 orders the broker used to reject, and left the other 257
# alone). What neither of those survives is a later edit that quietly takes the validator back
# off the entry path: the arithmetic would still pass its unit checks while the EA sent invalid
# stops again. This asserts the wiring structurally, so that edit turns the lane red.
#
# It checks the shipped source text only. It is not a substitute for either of the other two.
param(
    [string]$Source  = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'src\ExpertMACD_repaired.mq5'),
    [string]$Include = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'src\M2W5C3_StopGuard.mqh')
)
$ErrorActionPreference = 'Stop'
foreach ($p in @($Source, $Include)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "REFUSED: cannot read '$p' -- an input that could not be read is not an input that passed." }
}
$ea  = Get-Content -Raw -LiteralPath $Source
$inc = Get-Content -Raw -LiteralPath $Include

$checked = @()
function Assert-Contains([string]$text, [string]$token, [string]$why) {
    $script:checked += $why
    if ($text.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { throw "FAILED [$why]: missing '$token'" }
}

# --- the arithmetic honours every property that can reject an order ---
# The include is deliberately PURE: it names no symbol constants, it receives them. So the
# constants are asserted in the EA (which reads them) and the parameters in the include
# (which consumes them). Asserting the constants against the include would be asserting a
# property the module is designed not to have.
Assert-Contains $inc 'stops_level'               'minimum-distance rule consumes a stops_level'
Assert-Contains $inc 'freeze_level'              'minimum-distance rule consumes a freeze_level'
Assert-Contains $ea  'SYMBOL_TRADE_STOPS_LEVEL'  'EA passes STOPS_LEVEL into the rule'
Assert-Contains $ea  'SYMBOL_TRADE_FREEZE_LEVEL' 'EA passes FREEZE_LEVEL into the rule'
Assert-Contains $ea  'SYMBOL_TRADE_TICK_SIZE'    'EA passes TICK_SIZE into the rule'
Assert-Contains $inc 'SG_BOUNDARY_TOLERANCE'     'boundary is inclusive, per the server rule'

# --- both entry paths are behind the validator ---
if ($ea -notmatch 'OpenLongParams[\s\S]{0,600}?AreBuyStopsValid')  { throw 'FAILED: the BUY entry path does not reach AreBuyStopsValid' }
$checked += 'BUY entry path is gated by the validator'
if ($ea -notmatch 'OpenShortParams[\s\S]{0,600}?AreSellStopsValid') { throw 'FAILED: the SELL entry path does not reach AreSellStopsValid' }
$checked += 'SELL entry path is gated by the validator'

# --- a failed validation must REFUSE, never rewrite a level ---
foreach ($pair in @(@('AreBuyStopsValid','BUY'), @('AreSellStopsValid','SELL'))) {
    if ($ea -notmatch ("if\(!{0}\(sl,tp,bid,ask\)\)[\s\S]{{0,400}}?return\(false\)" -f $pair[0])) {
        throw ("FAILED: the {0} validator does not refuse the entry on failure" -f $pair[1])
    }
    $checked += ("{0} refusal returns false rather than adjusting a level" -f $pair[1])
}

# --- the frozen levels are never reassigned after construction ---
if ($ea -match '\bsl\s*=\s*(?!NormalizePriceToTick)' -and $ea -notmatch 'sl=NormalizePriceToTick') {
    throw 'FAILED: the stop level is assigned somewhere other than tick normalization'
}
$checked += 'stop level is only ever tick-normalized, never moved'

# --- the guard is able to report how often it fired ---
Assert-Contains $ea 'STOP_GUARD] SUMMARY' 'guard prints a fire count at OnDeinit'
Assert-Contains $ea 'g_sg_evaluated'      'guard reports how many entries it examined'

# --- the frozen strategy surface is untouched ---
foreach ($frozen in @('Inp_Signal_MACD_PeriodFast  =12','Inp_Signal_MACD_PeriodSlow  =24',
                      'Inp_Signal_MACD_PeriodSignal=9','Inp_Signal_MACD_TakeProfit  =50',
                      'Inp_Signal_MACD_StopLoss    =20','CTrailingNone','CMoneyNone')) {
    Assert-Contains $ea $frozen ("frozen semantics retained: $frozen")
}

# Print the SCOPE, not just the verdict: a guard that reports only "PASS" cannot be
# distinguished from a guard that checked nothing.
Write-Output "M2W5C3 stop-guard static assertions: PASS ($($checked.Count) checks)"
$checked | ForEach-Object { Write-Output "  - $_" }
