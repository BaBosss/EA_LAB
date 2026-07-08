# quick data probe: which gold-like / commodity symbols have usable 2020-2023 history?
# short timeout so no-data symbols fail fast instead of hanging 30min.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$out = "D:\EA_LAB\_mt5_auto\METAL_PROBE.csv"
'"symbol","trades","note"' | Out-File $out -Encoding utf8
foreach($sym in 'XAGUSD','WTI','BRENT','XAUUSDMINI','USOIL','SILVER'){
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta 5\terminal64.exe' } | Stop-Process -Force -Confirm:$false; Start-Sleep 2
  $rep = "PROBE_$sym"
  & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "BRKXAU" -Symbol $sym -Period H1 -FromDate 2021.01.01 -ToDate 2023.01.01 -Model 4 -ReportName $rep -TimeoutSec 240 2>&1 | Out-Null
  $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
  if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
    $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
    "`"$sym`",$trd,ok"|Add-Content $out }
  else { "`"$sym`",,NO_DATA"|Add-Content $out }
}
"PROBE DONE"; Get-Content $out
