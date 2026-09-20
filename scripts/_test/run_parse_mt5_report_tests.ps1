[CmdletBinding()]
param(
  [string]$MainReport = '',
  [string]$BwdReport = ''
)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $root 'scripts\use_python.ps1')
$py=Assert-PortablePython -Root $root -Provision
$parser=Join-Path $root 'scripts\parse_mt5_report.py'
$script:fails=0
$script:ran=0

function Assert-Eq([string]$Name,$Actual,$Expected,[double]$Tol=0.0000001){
  $script:ran++
  $ok=$false
  if($Actual -is [double] -or $Actual -is [float] -or $Actual -is [decimal] -or $Actual -is [int] -or $Actual -is [long]){
    try{$ok=([math]::Abs(([double]$Actual)-([double]$Expected)) -le $Tol)}catch{$ok=$false}
  } else {$ok=([string]$Actual -ceq [string]$Expected)}
  if($ok){Write-Host ("  [PASS] {0} = {1}" -f $Name,$Actual) -ForegroundColor Green}
  else{Write-Host ("  [FAIL] {0}: actual=[{1}] expected=[{2}]" -f $Name,$Actual,$Expected) -ForegroundColor Red;$script:fails++}
}
function Parse([string]$Path){
  $out=& $py -B -X utf8 $parser $Path --json 2>&1
  if($LASTEXITCODE -ne 0){throw "parser exit $LASTEXITCODE for $Path :: $($out -join ' ')"}
  return (($out -join [Environment]::NewLine)|ConvertFrom-Json)
}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}

$tmp=Join-Path $env:TEMP ("ea_lab_parse_report_"+$PID)
New-Item -ItemType Directory -Force $tmp|Out-Null
try{
  $synthetic=Join-Path $tmp 'synthetic.htm'
  $html=@'
<html><head><title>Strategy Tester Report Build 6090</title></head><body><table>
<tr><td>Expert:</td><td><b>FixtureEA</b></td></tr>
<tr><td>Company:</td><td><b>Fixture Broker</b></td></tr>
<tr><td>Symbol:</td><td><b>XAUUSD</b></td></tr>
<tr><td>Period:</td><td><b>H1 (2023.01.01 - 2025.12.31)</b></td></tr>
<tr><td>Currency:</td><td><b>USD</b></td></tr>
<tr><td>Initial Deposit:</td><td><b>10 000.00</b></td></tr>
<tr><td>Leverage:</td><td><b>1:100</b></td></tr>
<tr><td>Bars:</td><td><b>17 720</b></td><td>Ticks:</td><td><b>4,238,991</b></td><td>Symbols:</td><td><b>1</b></td></tr>
<tr><td>Total Net Profit:</td><td><b>696.95</b></td><td>Balance Drawdown Absolute:</td><td><b>1 790.41</b></td><td>Equity Drawdown Absolute:</td><td><b>1 796.64</b></td></tr>
<tr><td>Gross Profit:</td><td><b>24 558.74</b></td><td>Balance Drawdown Maximal:</td><td><b>1 847.36 (18.37%)</b></td><td>Equity Drawdown Maximal:</td><td><b>1 878.51 (18.63%)</b></td></tr>
<tr><td>Gross Loss:</td><td><b>-23 861.79</b></td><td>Balance Drawdown Relative:</td><td><b>18.37% (1 847.36)</b></td><td>Equity Drawdown Relative:</td><td><b>18.63% (1 878.51)</b></td></tr>
<tr><td>Profit Factor:</td><td><b>1.03</b></td><td>AHPR:</td><td><b>1.0000 (0.00%)</b></td><td>GHPR:</td><td><b>1.0000 (0.00%)</b></td></tr>
<tr><td>Total Trades:</td><td><b>2822</b></td><td>Total Deals:</td><td><b>5644</b></td></tr>
<tr><td>Short Trades (won %):</td><td><b>1 034 (35.59%)</b></td><td>Long Trades (won %):</td><td><b>1,788 (43.85%)</b></td></tr>
<tr><td>Profit Trades (% of total):</td><td><b>1 152 (40.82%)</b></td><td>Loss Trades (% of total):</td><td><b>1,670 (59.18%)</b></td></tr>
<tr><td>Average profit trade:</td><td><b>21.32</b></td><td>Average loss trade:</td><td><b>-14.29</b></td></tr>
<tr><td>Largest profit trade:</td><td><b>111.70</b></td><td>Largest loss trade:</td><td><b>-81.86</b></td></tr>
<tr><td>Average consecutive wins:</td><td><b>3</b></td><td>Average consecutive losses:</td><td><b>4</b></td></tr>
<tr><td>Maximum consecutive wins ($):</td><td><b>14 (194.67)</b></td><td>Maximum consecutive losses ($):</td><td><b>31 (-344.99)</b></td></tr>
</table></body></html>
'@
  [IO.File]::WriteAllText($synthetic,$html,[Text.Encoding]::Unicode)
  Write-Host 'parse_mt5_report.py - synthetic grouped-number fixture' -ForegroundColor Cyan
  $s=Parse $synthetic
  Assert-Eq 'synthetic.initial_deposit' $s.initial_deposit 10000.0
  Assert-Eq 'synthetic.bars' $s.bars 17720.0
  Assert-Eq 'synthetic.ticks' $s.ticks 4238991.0
  Assert-Eq 'synthetic.symbols_count' $s.symbols_count 1
  Assert-Eq 'synthetic.gross_profit' $s.gross_profit 24558.74
  Assert-Eq 'synthetic.gross_loss' $s.gross_loss -23861.79
  Assert-Eq 'synthetic.balance_drawdown_abs' $s.balance_drawdown_abs 1790.41
  Assert-Eq 'synthetic.equity_drawdown_abs' $s.equity_drawdown_abs 1796.64
  Assert-Eq 'synthetic.balance_drawdown_maximal_abs' $s.balance_drawdown_maximal_abs 1847.36
  Assert-Eq 'synthetic.balance_drawdown_maximal_pct' $s.balance_drawdown_maximal_pct 18.37
  Assert-Eq 'synthetic.equity_drawdown_maximal_abs' $s.equity_drawdown_maximal_abs 1878.51
  Assert-Eq 'synthetic.equity_drawdown_maximal_pct' $s.equity_drawdown_maximal_pct 18.63
  Assert-Eq 'synthetic.ahpr' $s.ahpr 1.0
  Assert-Eq 'synthetic.ghpr' $s.ghpr 1.0
  Assert-Eq 'synthetic.short_trades' $s.short_trades 1034
  Assert-Eq 'synthetic.long_trades' $s.long_trades 1788
  Assert-Eq 'synthetic.profit_trades' $s.profit_trades 1152
  Assert-Eq 'synthetic.loss_trades' $s.loss_trades 1670
  Assert-Eq 'synthetic.avg_profit_trade' $s.avg_profit_trade 21.32
  Assert-Eq 'synthetic.avg_loss_trade' $s.avg_loss_trade -14.29
  Assert-Eq 'synthetic.avg_consecutive_wins' $s.avg_consecutive_wins 3
  Assert-Eq 'synthetic.avg_consecutive_losses' $s.avg_consecutive_losses 4
  Assert-Eq 'synthetic.max_consecutive_wins' $s.max_consecutive_wins 14
  Assert-Eq 'synthetic.max_consecutive_losses' $s.max_consecutive_losses 31

  if($MainReport){
    if((Sha $MainReport) -ne 'f4775e102c62cdd3b205bc4b3350b7159cb76820f84312a81830cf9d88c76f2b'){throw 'MAIN raw report hash mismatch'}
    Write-Host 'parse_mt5_report.py - immutable B11 MAIN defect fixture' -ForegroundColor Cyan
    $m=Parse $MainReport
    Assert-Eq 'MAIN.symbols_count' $m.symbols_count 1
    Assert-Eq 'MAIN.gross_profit' $m.gross_profit 24558.74
    Assert-Eq 'MAIN.gross_loss' $m.gross_loss -23861.79
    Assert-Eq 'MAIN.balance_drawdown_abs' $m.balance_drawdown_abs 1790.41
    Assert-Eq 'MAIN.equity_drawdown_abs' $m.equity_drawdown_abs 1796.64
    Assert-Eq 'MAIN.balance_drawdown_maximal_abs' $m.balance_drawdown_maximal_abs 1847.36
    Assert-Eq 'MAIN.equity_drawdown_maximal_abs' $m.equity_drawdown_maximal_abs 1878.51
    Assert-Eq 'MAIN.avg_profit_trade' $m.avg_profit_trade 21.32
    Assert-Eq 'MAIN.avg_loss_trade' $m.avg_loss_trade -14.29
  }
  if($BwdReport){
    if((Sha $BwdReport) -ne '65cde7679c7a811a7be7c3b436146a170938111c004beddb378b32e8d4ba1dce'){throw 'BWD raw report hash mismatch'}
    Write-Host 'parse_mt5_report.py - immutable B11 BWD defect fixture' -ForegroundColor Cyan
    $b=Parse $BwdReport
    Assert-Eq 'BWD.symbols_count' $b.symbols_count 1
    Assert-Eq 'BWD.net_profit' $b.net_profit -1878.63
    Assert-Eq 'BWD.gross_profit' $b.gross_profit 14806.75
    Assert-Eq 'BWD.gross_loss' $b.gross_loss -16685.38
    Assert-Eq 'BWD.balance_drawdown_abs' $b.balance_drawdown_abs 1986.52
    Assert-Eq 'BWD.equity_drawdown_abs' $b.equity_drawdown_abs 1995.30
    Assert-Eq 'BWD.balance_drawdown_maximal_abs' $b.balance_drawdown_maximal_abs 2124.64
    Assert-Eq 'BWD.equity_drawdown_maximal_abs' $b.equity_drawdown_maximal_abs 2214.70
    Assert-Eq 'BWD.avg_profit_trade' $b.avg_profit_trade 14.66
    Assert-Eq 'BWD.avg_loss_trade' $b.avg_loss_trade -10.13
  }

  Write-Host 'parse_mt5_report.py - adversarial adjacent-cell containment' -ForegroundColor Cyan
  $missing=Join-Path $tmp 'missing.htm'
  $htmlMissing=@'
<html><body><table>
<tr><td>Gross Profit:</td><td></td><td>Gross Loss:</td><td><b>-10.00</b></td></tr>
<tr><td>Symbols:</td><td><b>1</b></td></tr>
</table></body></html>
'@
  [IO.File]::WriteAllText($missing,$htmlMissing,[Text.Encoding]::Unicode)
  $mv=Parse $missing
  Assert-Eq 'missing.gross_profit stays default' $mv.gross_profit 0
  Assert-Eq 'missing.gross_loss stays own value' $mv.gross_loss -10.0
  Assert-Eq 'missing.symbols_count' $mv.symbols_count 1

  Write-Host 'parse_mt5_report.py - adversarial malformed grouping' -ForegroundColor Cyan
  $malformed=Join-Path $tmp 'malformed.htm'
  $htmlMalformed=@'
<html><body><table>
<tr><td>Initial Deposit:</td><td><b>12 34.56</b></td></tr>
<tr><td>Total Net Profit:</td><td><b>1,2,3</b></td></tr>
<tr><td>Gross Profit:</td><td><b>1,234 567.89</b></td></tr>
<tr><td>Gross Loss:</td><td><b>-12 345.67</b></td></tr>
<tr><td>Balance Drawdown Absolute:</td><td><b>12,345.67</b></td></tr>
<tr><td>Equity Drawdown Absolute:</td><td><b>12345.67</b></td></tr>
</table></body></html>
'@
  [IO.File]::WriteAllText($malformed,$htmlMalformed,[Text.Encoding]::Unicode)
  $iv=Parse $malformed
  Assert-Eq 'malformed.initial_deposit rejected' $iv.initial_deposit 0
  Assert-Eq 'malformed.net_profit rejected' $iv.net_profit 0
  Assert-Eq 'malformed.mixed_grouping rejected' $iv.gross_profit 0
  Assert-Eq 'valid.space_grouping negative' $iv.gross_loss -12345.67
  Assert-Eq 'valid.comma_grouping' $iv.balance_drawdown_abs 12345.67
  Assert-Eq 'valid.ungrouped' $iv.equity_drawdown_abs 12345.67

  Write-Host 'parse_mt5_report.py - adversarial absent adjacent cell' -ForegroundColor Cyan
  $absent=Join-Path $tmp 'absent_adjacent.htm'
  $htmlAbsent=@'
<html><body><table>
<tr><td>Gross Profit:</td></tr>
<tr><td>-99.00</td></tr>
<tr><td>Gross Loss:</td><td><b>-10.00</b></td></tr>
</table></body></html>
'@
  [IO.File]::WriteAllText($absent,$htmlAbsent,[Text.Encoding]::Unicode)
  $av=Parse $absent
  Assert-Eq 'absent.gross_profit stays default' $av.gross_profit 0
  Assert-Eq 'absent.gross_loss stays own value' $av.gross_loss -10.0

  Write-Host 'parse_mt5_report.py - legacy plain-text isolation' -ForegroundColor Cyan
  $plainCross=Join-Path $tmp 'plain_cross.txt'
  $plainCrossText=@'
Expert:
Symbol: XAUUSD
Initial Deposit: 10 000.00
'@
  [IO.File]::WriteAllText($plainCross,$plainCrossText,[Text.Encoding]::Unicode)
  $pv=Parse $plainCross
  Assert-Eq 'plain_cross.expert rejected labeled next field' $pv.ea_name ''
  Assert-Eq 'plain_cross.symbol own value' $pv.symbol 'XAUUSD'
  Assert-Eq 'plain_cross.deposit' $pv.initial_deposit 10000.0

  $plainInline=Join-Path $tmp 'plain_inline.txt'
  $plainInlineText=@'
Expert: PlainEA
Symbol: XAUUSD
Initial Deposit: 10000.00
'@
  [IO.File]::WriteAllText($plainInline,$plainInlineText,[Text.Encoding]::Unicode)
  $pi=Parse $plainInline
  Assert-Eq 'plain_inline.expert' $pi.ea_name 'PlainEA'
  Assert-Eq 'plain_inline.symbol' $pi.symbol 'XAUUSD'
  Assert-Eq 'plain_inline.deposit' $pi.initial_deposit 10000.0

  $plainNext=Join-Path $tmp 'plain_next.txt'
  $plainNextText=@'
Expert:
PlainEA
Symbol:
XAUUSD
'@
  [IO.File]::WriteAllText($plainNext,$plainNextText,[Text.Encoding]::Unicode)
  $pnv=Parse $plainNext
  Assert-Eq 'plain_next.expert' $pnv.ea_name 'PlainEA'
  Assert-Eq 'plain_next.symbol' $pnv.symbol 'XAUUSD'

  Write-Host 'parse_mt5_report.py - alias fallback must preserve matched-empty/absent' -ForegroundColor Cyan
  $aliasEmpty=Join-Path $tmp 'alias_empty.htm'
  $aliasEmptyHtml=@'
<html><body><table>
<tr><td>Average profit trade:</td><td></td></tr>
<tr><td>Avg profit trade:</td><td><b>99.00</b></td></tr>
</table></body></html>
'@
  [IO.File]::WriteAllText($aliasEmpty,$aliasEmptyHtml,[Text.Encoding]::Unicode)
  $ae=Parse $aliasEmpty
  Assert-Eq 'alias_empty.preferred label blocks fallback' $ae.avg_profit_trade 0

  $aliasAbsent=Join-Path $tmp 'alias_absent.htm'
  $aliasAbsentHtml=@'
<html><body><table>
<tr><td>Average profit trade:</td></tr>
<tr><td>Avg profit trade:</td><td><b>88.00</b></td></tr>
</table></body></html>
'@
  [IO.File]::WriteAllText($aliasAbsent,$aliasAbsentHtml,[Text.Encoding]::Unicode)
  $aa=Parse $aliasAbsent
  Assert-Eq 'alias_absent.preferred label blocks fallback' $aa.avg_profit_trade 0

  Write-Host 'parse_mt5_report.py - inline cross-label refusal' -ForegroundColor Cyan
  $plainInlineCross=Join-Path $tmp 'plain_inline_cross.txt'
  $plainInlineCrossText=@'
Expert: Symbol: XAUUSD
Symbol: XAUUSD
Initial Deposit: 10000.00
'@
  [IO.File]::WriteAllText($plainInlineCross,$plainInlineCrossText,[Text.Encoding]::Unicode)
  $pic=Parse $plainInlineCross
  Assert-Eq 'plain_inline_cross.expert rejected labeled inline value' $pic.ea_name ''
  Assert-Eq 'plain_inline_cross.symbol own value' $pic.symbol 'XAUUSD'
} finally {Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host ''
if($script:fails){Write-Host ("RESULT: {0}/{1} FAILED" -f $script:fails,$script:ran) -ForegroundColor Red;exit 1}
Write-Host ("RESULT: all {0} passed" -f $script:ran) -ForegroundColor Green
exit 0
