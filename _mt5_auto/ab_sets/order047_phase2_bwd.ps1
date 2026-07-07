# ORDER-047 phase 2 — BWD-OOS 2020-22 confirm of breadth winners (kills regime-luck
# before spending optimizer compute). Lane 1 (D:\Meta4), Model 1, H1, default params
# (RSI) / swb_flat.set (swb). Symbols with meaningful forward sample only.
# Preflight waits for the RSI breadth run to free lane 1. lot-check each report.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$dd = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts"
$rsi_src = "D:\Forex\10_EA_PROJECTS\2. wait for test\wait for test\RSI from pips_EA.ex4"
$swb_src = "D:\Forex\10_EA_PROJECTS\2. wait for test\2024-06\FREE EA-20240608T074321Z-001\FREE EA\swb grid 4.1.0.3_h.ex4"
$swb_set = "D:\EA_LAB\_mt5_auto\ab_sets\swb_flat.set"
$out = "D:\EA_LAB\_mt5_auto\ORDER047_BWD.csv"
$log = "D:\EA_LAB\_mt5_auto\order047_phase2.log"
'"ea","symbol","full_pf","full_trades","full_net","full_dd_pct","note"' | Out-File $out -Encoding utf8
Copy-Item -LiteralPath $rsi_src -Destination (Join-Path $dd "RSI from pips_EA.ex4") -Force
Copy-Item -LiteralPath $swb_src -Destination (Join-Path $dd "swb grid 4.1.0.3_h.ex4") -Force

$deadline=(Get-Date).AddMinutes(20)
while((Get-Date) -lt $deadline){ $z=Get-Process terminal -ErrorAction SilentlyContinue|?{$_.Path -eq 'D:\Meta4\terminal.exe'}; if(-not $z){break}; Start-Sleep 15 }
Get-Process terminal -ErrorAction SilentlyContinue|?{$_.Path -eq 'D:\Meta4\terminal.exe'}|%{ Stop-Process -Id $_.Id -Force -Confirm:$false }

function Run-BWD { param([string]$Ea,[string]$Sym,[string]$SetFile,[string]$Tag)
  $safe=($Ea -replace '[^A-Za-z0-9]','_'); if($safe.Length -gt 24){$safe=$safe.Substring(0,24)}
  $rep="O47BWD_${safe}_${Sym}"
  "[$(Get-Date -Format s)] $Ea $Sym" | Tee-Object $log -Append
  $args=@('-File','D:\EA_LAB\scripts\mt4_run.ps1','-Expert',$Ea,'-Symbol',$Sym,'-Period','H1','-FromDate','2020.01.01','-ToDate','2023.01.01','-Model','1','-ReportName',$rep,'-TimeoutSec','1800')
  if($SetFile){ $args+=@('-SetFile',$SetFile) }
  powershell @args | Tee-Object $log -Append
  $htm="D:\EA_LAB\_mt4_auto\reports\$rep.htm"
  if(-not(Test-Path $htm)){ "`"$Ea`",`"$Sym`",,,,,NO_REPORT-$Tag"|Add-Content $out; return }
  try{ $j=python D:\EA_LAB\scripts\parse_mt4_report.py $htm|ConvertFrom-Json
    "`"$Ea`",`"$Sym`",$($j.profit_factor),$($j.total_trades),$($j.net_profit),$($j.max_drawdown_pct),$Tag"|Add-Content $out
  }catch{ "`"$Ea`",`"$Sym`",,,,,PARSE_ERR-$Tag"|Add-Content $out }
  powershell -File D:\EA_LAB\scripts\mt4_lotcheck.ps1 -Report $htm | Tee-Object $log -Append
}

# RSI winners (forward sample >=70 trades or the validated EURUSD)
foreach($s in 'EURUSD','GBPUSD','AUDUSD','AUDCAD','XAUUSD'){ Run-BWD "RSI from pips_EA" $s "" "RSI" }
# swb reserve best new symbols (see if any gives Model-0-survivable DD later)
foreach($s in 'AUDUSD','AUDCAD','CHFJPY','XAUUSD'){ Run-BWD "swb grid 4.1.0.3_h" $s $swb_set "SWB-FLAT" }

"[$(Get-Date -Format s)] ORDER-047 phase 2 DONE -> $out" | Tee-Object $log -Append
