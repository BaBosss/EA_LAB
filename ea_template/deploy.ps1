<#
deploy.ps1 - copy EA_LabTemplate into the LIVE MT5 data folder so MetaEditor
can compile it and Strategy Tester can run it.
  & .\deploy.ps1            # copy source -> Experts\EALabTpl
  & .\deploy.ps1 -Compile   # copy then compile (reads compile.log)
Expert name for tester / mt5_run.ps1 :  EALabTpl\EA_LabTemplate
NOTE: headless smoke/optimize (mt5_run.ps1) needs the MT5 GUI CLOSED.
      Compiling here does NOT require closing MT5.
#>
param([switch]$Compile)
$ErrorActionPreference = "Stop"

$src  = "D:\EA_LAB\ea_template"
$data = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355"
# robocopy's subdirectory-create (core\) intermittently fails when writing THROUGH the
# Roaming junction (found 2026-07-03) - resolve to the real target before copying.
$junc = Get-Item "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal" -Force -ErrorAction SilentlyContinue
if ($junc -and $junc.LinkType -and $junc.Target) {
  $data = Join-Path ([string]$junc.Target) "9CA16B8382AE4CF692710FB36B9DA355"
}
$meta = "D:\Meta 5\metaeditor64.exe"
$dst  = Join-Path $data "MQL5\Experts\EALabTpl"

# fast-fail robocopy (/R:1 /W:1) so a transient lock never hangs the mirror
robocopy "$src" "$dst" /MIR /R:1 /W:1 /XD .git /XF *.ex5 *.log /NFL /NDL /NJH /NJS | Out-Null
if($LASTEXITCODE -ge 8){ Write-Host "robocopy error ($LASTEXITCODE) - is MT5 locking the folder?" -ForegroundColor Red; exit 1 }
Write-Host "deployed -> $dst" -ForegroundColor Cyan

if ($Compile) {
  # V2 = four Boss wrappers; V1 EA_LabTemplate kept for reference
  $targets = @("Boss_11_GridTrend.mq5","Boss_12_Breakout.mq5","Boss_13_MeanRev.mq5","Boss_14_GridLog.mq5","EA_LabTemplate.mq5")
  foreach($t in $targets){
    $mq5 = Join-Path $dst $t
    if(-not (Test-Path $mq5)){ Write-Host "skip (missing): $t" -ForegroundColor DarkGray; continue }
    $log = Join-Path $dst ("compile_" + [IO.Path]::GetFileNameWithoutExtension($t) + ".log")
    if(Test-Path $log){ Remove-Item $log -Force }
    Start-Process -FilePath $meta -ArgumentList "/compile:`"$mq5`"","/log:`"$log`"" -Wait
    if(Test-Path $log){
      $txt = Get-Content -Raw -Encoding Unicode $log
      $res = ($txt -split "`r?`n" | Where-Object { $_ -match "Result:|error|warning" })
      Write-Host "[$t]" -ForegroundColor Cyan
      $res | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
    }
  }
}
Write-Host "Expert names: EALabTpl\Boss_11_GridTrend | Boss_12_Breakout | Boss_13_MeanRev | Boss_14_GridLog" -ForegroundColor Green
