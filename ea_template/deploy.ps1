<#
deploy.ps1 - ทำให้ MetaEditor เห็น EA_LabTemplate เพื่อ compile/test
ค่า default = junction (ลิงก์ ea_template เข้า MQL5\Experts\ -> แก้ที่ EA_LAB ที่เดียว, git ตามได้)
  & .\deploy.ps1            # สร้าง junction
  & .\deploy.ps1 -Copy      # ก๊อปจริง (ถ้าไม่อยากใช้ junction)
  & .\deploy.ps1 -Compile   # deploy แล้ว compile ต่อเลย
Expert name สำหรับ tester/mt5_run.ps1:  EA_LabTemplate\EA_LabTemplate
#>
param([switch]$Copy, [switch]$Compile)
$ErrorActionPreference = "Stop"

$src = "D:\EA_LAB\ea_template"
$mt5 = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355"
$meta= "D:\Meta 5\metaeditor64.exe"
$dst = Join-Path $mt5 "MQL5\Experts\EA_LabTemplate"

if ($Copy) {
  robocopy $src $dst /MIR /XD .git /XF *.ex5 *.log | Out-Null
  Write-Host "copied -> $dst" -ForegroundColor Cyan
}
elseif (Test-Path $dst) {
  Write-Host "already deployed: $dst" -ForegroundColor DarkGray
}
else {
  & cmd /c mklink /J "$dst" "$src" | Out-Host
  Write-Host "junction -> $dst" -ForegroundColor Cyan
}

if ($Compile) {
  $mq5 = Join-Path $dst "EA_LabTemplate.mq5"
  $log = Join-Path $dst "compile.log"
  Write-Host "compiling..." -ForegroundColor DarkGray
  Start-Process -FilePath $meta -ArgumentList "/compile:`"$mq5`"","/log:`"$log`"" -Wait
  if (Test-Path $log) { Get-Content -Raw -Encoding Unicode $log | Write-Host }
}
Write-Host "Expert name for tester: EA_LabTemplate\EA_LabTemplate" -ForegroundColor Green
