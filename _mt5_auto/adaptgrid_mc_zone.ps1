<#
adaptgrid_mc_zone.ps1 - PowerShell port of adaptgrid_mc_zone.py (offline MC block-bootstrap
zone generator for (EXP)_AdaptGridMC_rev01), written because this box has no Python install
(2026-07-23 - ORDER-142, python/py/python3 all absent, confirmed via Get-Command).

Method (FINDYOUR8 catalog #1, Adaptive Grid: Zero to Hero) - unchanged from the .py original:
  - input: CSV of D1 bars (MT5 export uses TAB delimiter, not comma - the .py's comma/semicolon
    sniff would have silently mis-parsed real MT5 exports; this port auto-detects tab too)
  - last -Hist rows used (if fewer rows exist than -Hist, uses all of them - no error)
  - -Paths paths x -Horizon days, sampled as -Block-day blocks of log-returns (block bootstrap
    preserves vol clustering / momentum autocorrelation)
  - pool ALL simulated prices across paths+days -> ZoneLo = P10, ZoneHi = P90
  - ATR(30) RMA over real bars (true range if high/low present, else |dClose| proxy)
  - spacing = SpacingAtrMult * ATR ; N = floor((ZoneHi-ZoneLo)/spacing) clamped to [2,40]
  - emits a .set snippet for the EA

⚠️ NO-LOOKAHEAD WARNING (read before trusting a BWD-window result):
  This script only ever reads the CSV you hand it and takes the LAST -Hist rows. For a
  walk-forward-honest zone, pre-slice the CSV to end BEFORE the test window starts (e.g. for
  the MAIN 2023.01-2025.12 window, feed only rows before 2023-01-01). Feeding the FULL
  2020-2026 file and then backtesting BWD 2020-2022 with that zone is lookahead bias - the
  zone would already "know" the 2023-2026 price action.

usage: pwsh adaptgrid_mc_zone.ps1 -Csv BTCUSD_D1.csv [-Paths 10000] [-Horizon 60] [-Block 24]
       [-Hist 1000] [-SpacingAtr 0.3] [-Seed 42] [-Out zone.set]
#>
param(
    [Parameter(Mandatory=$true)][string]$Csv,
    [int]$Paths = 10000,
    [int]$Horizon = 60,
    [int]$Block = 24,
    [int]$Hist = 1000,
    [double]$SpacingAtr = 0.3,
    [int]$Seed = 42,
    [string]$Out = $null
)

function Read-Bars([string]$path) {
    $raw = Get-Content -LiteralPath $path -Raw
    $lines = $raw -split "`r`n|`n|`r" | Where-Object { $_.Length -gt 0 }
    if ($lines.Count -lt 2) { throw "empty csv" }
    $header = $lines[0]
    $delim = "`t"
    if (($header.ToCharArray() | Where-Object { $_ -eq ',' }).Count -gt ($header.ToCharArray() | Where-Object { $_ -eq "`t" }).Count -and
        ($header.ToCharArray() | Where-Object { $_ -eq ',' }).Count -gt ($header.ToCharArray() | Where-Object { $_ -eq ';' }).Count) { $delim = ',' }
    elseif (($header.ToCharArray() | Where-Object { $_ -eq ';' }).Count -gt ($header.ToCharArray() | Where-Object { $_ -eq "`t" }).Count) { $delim = ';' }

    $cols = $header.Split($delim) | ForEach-Object { $_.Trim().Trim('<','>').ToLower() }
    $ci = @{}
    for ($i = 0; $i -lt $cols.Count; $i++) { $ci[$cols[$i]] = $i }
    if (-not $ci.ContainsKey('close')) { throw "no close column" }

    $bars = New-Object System.Collections.Generic.List[object]
    for ($li = 1; $li -lt $lines.Count; $li++) {
        $f = $lines[$li].Split($delim)
        if ($f.Count -le $ci['close']) { continue }
        $c = 0.0
        if (-not [double]::TryParse($f[$ci['close']], [ref]$c)) { continue }
        $h = $c; $l = $c
        if ($ci.ContainsKey('high') -and $f.Count -gt $ci['high']) { [double]::TryParse($f[$ci['high']], [ref]$h) | Out-Null }
        if ($ci.ContainsKey('low')  -and $f.Count -gt $ci['low'])  { [double]::TryParse($f[$ci['low']],  [ref]$l) | Out-Null }
        $bars.Add([pscustomobject]@{ H = $h; L = $l; C = $c })
    }
    return $bars
}

function Get-AtrRma($bars, [int]$period = 30) {
    $trs = New-Object System.Collections.Generic.List[double]
    for ($i = 1; $i -lt $bars.Count; $i++) {
        $pc = $bars[$i-1].C
        $tr = [Math]::Max($bars[$i].H - $bars[$i].L, [Math]::Max([Math]::Abs($bars[$i].H - $pc), [Math]::Abs($bars[$i].L - $pc)))
        $trs.Add($tr)
    }
    if ($trs.Count -lt $period) { throw "not enough bars for ATR" }
    $sum = 0.0
    for ($i = 0; $i -lt $period; $i++) { $sum += $trs[$i] }
    $a = $sum / $period
    for ($i = $period; $i -lt $trs.Count; $i++) { $a = ($a * ($period - 1) + $trs[$i]) / $period }
    return $a
}

$allBars = Read-Bars $Csv
$bars = if ($allBars.Count -gt $Hist) { $allBars.GetRange($allBars.Count - $Hist, $Hist) } else { $allBars }
$closes = $bars | ForEach-Object { $_.C }
if ($closes.Count -lt ($Block + 2)) { throw "history too short: $($closes.Count) bars, need > $($Block+2)" }

$rets = New-Object System.Collections.Generic.List[double]
for ($i = 1; $i -lt $closes.Count; $i++) { $rets.Add([Math]::Log($closes[$i] / $closes[$i-1])) }
$last = $closes[$closes.Count - 1]
$atr = Get-AtrRma $bars 30

$rng = [System.Random]::new($Seed)
$maxStart = $rets.Count - $Block
$pooled = New-Object System.Collections.Generic.List[double]
for ($p = 0; $p -lt $Paths; $p++) {
    $px = $last; $steps = 0
    while ($steps -lt $Horizon) {
        $s = $rng.Next(0, $maxStart + 1)
        for ($k = $s; $k -lt ($s + $Block) -and $steps -lt $Horizon; $k++) {
            $px = $px * [Math]::Exp($rets[$k]); $pooled.Add($px); $steps++
        }
    }
}
$sorted = $pooled | Sort-Object
function Pct([double]$q) { $idx = [Math]::Min($sorted.Count - 1, [int]($q * $sorted.Count)); return $sorted[$idx] }
$lo = Pct 0.10; $hi = Pct 0.90
$spacing = $SpacingAtr * $atr
$n = [Math]::Max(2, [Math]::Min(40, [int](($hi - $lo) / $spacing)))

Write-Host ("last_close={0:F2}  ATR30(RMA)={1:F2}  bars_used={2}" -f $last, $atr, $bars.Count)
Write-Host ("ZoneLo(P10)={0:F2}  ZoneHi(P90)={1:F2}  width={2:F2}" -f $lo, $hi, ($hi - $lo))
Write-Host ("spacing({0}xATR)={1:F2}  N_levels={2} (clamp<=40)" -f $SpacingAtr, $spacing, $n)
$snippet = "_01_ZoneLo=$('{0:F2}' -f $lo)`n_01_ZoneHi=$('{0:F2}' -f $hi)`n_01_SpacingAtrMult=$SpacingAtr`n_01_MaxLevels=$n`n"
if ($Out) {
    Set-Content -LiteralPath $Out -Value $snippet -Encoding ascii -NoNewline
    Write-Host "wrote $Out"
} else {
    Write-Host "--- .set snippet ---`n$snippet"
}
