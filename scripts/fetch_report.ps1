<#
fetch_report.ps1 — ดึง MT5 report ตัวล่าสุดที่เพิ่ง "Save as Report" เข้าโฟลเดอร์ EA_LAB
แล้วบันทึกค่าลง master log (RUN_LOG.csv) อัตโนมัติ

ใช้ตอน test ผ่าน MT5 GUI เอง (manual) แล้วอยากให้ Claude เอาผลไปวิเคราะห์ต่อ
ขั้นตอนของคุณ: ใน MT5 -> คลิกขวาผลลัพธ์ -> Save as Report -> เซฟลงโฟลเดอร์ไหนก็ได้ที่สแกน
(แนะนำ: D:\EA_LAB\_inbox) แล้วรันสคริปต์นี้

  Mode 1 (single)   : ดึง backtest single-test .htm ตัวล่าสุด -> _mt5_auto\reports\
  Mode 2 (optimize) : ดึง optimization .xml ตัวล่าสุด        -> _mt5_auto\optimizations\
  Mode 3 (both)     : ดึงทั้ง single + optimize ตัวล่าสุด

ทุกโหมด: อ่านชื่อ EA / Symbol / ช่วงวัน จากในไฟล์เอง -> ตั้งชื่อไฟล์ + log ค่าให้
RUN_LOG.csv (เปิดใน Excel ได้) แล้วพิมพ์คำสั่ง analyze ตัวถัดไป

ตัวอย่าง:
  & .\fetch_report.ps1                      # เมนูถาม 1/2/3
  & .\fetch_report.ps1 -Mode both
  & .\fetch_report.ps1 -Mode optimize -Label EX197v8 -Strategy grid
  & .\fetch_report.ps1 -Mode single -ExpectEA "EX197" -Move -NoLog
#>
param(
  [ValidateSet("menu", "single", "optimize", "both", "1", "2", "3")]
  [string]$Mode = "menu",
  [string]$Label = "",          # ถ้าใส่ จะใช้เป็นชื่อไฟล์แทน auto-name (โหมดเดียวเท่านั้น)
  [string]$ExpectEA = "",       # ถ้าใส่ จะเตือนเมื่อ EA ในไฟล์ไม่ตรง
  [string]$Strategy = "default",# ส่งต่อให้ log_run.py สำหรับ scoring (default/grid/mean_reversion...)
  [string[]]$Source = @(),      # เพิ่ม folder สแกนเอง
  [switch]$Move,                # ย้ายไฟล์ต้นทางทิ้ง (default = copy ปลอดภัยกว่า)
  [switch]$NoLog                # ไม่บันทึกลง RUN_LOG.csv
)
$ErrorActionPreference = "Stop"

$Auto    = "D:\EA_LAB\_mt5_auto"
$Reports = Join-Path $Auto "reports"
$Opts    = Join-Path $Auto "optimizations"
$Inbox   = "D:\EA_LAB\_inbox"
$Mt5Data = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355"
$LogPy   = "D:\EA_LAB\scripts\log_run.py"
New-Item -ItemType Directory -Force $Reports, $Opts, $Inbox | Out-Null

$ScanDirs = @($Inbox, $Mt5Data, (Join-Path $Mt5Data "Tester\Reports"),
  (Join-Path $env:USERPROFILE "Downloads"), (Join-Path $env:USERPROFILE "Desktop")) + $Source
$ScanDirs = $ScanDirs | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

function Get-SafeName([string]$t) {
  if (-not $t) { return "EA" }
  $s = $t -replace '[\\/:*?"<>|()]+', '' -replace '\s+', '_'
  return $s.Trim('_')
}

function Get-SingleInfo([string]$path) {
  $raw = Get-Content -Raw -LiteralPath $path
  $title = [regex]::Match($raw, '<title>(.*?)</title>', 'IgnoreCase').Groups[1].Value.Trim()
  $cells = @()
  foreach ($x in [regex]::Matches($raw, '<t[dh][^>]*>(.*?)</t[dh]>', 'Singleline,IgnoreCase')) {
    $c = $x.Groups[1].Value -replace '<[^>]+>', ' ' -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '\s+', ' '
    $c = $c.Trim(); if ($c) { $cells += $c }
  }
  function _after($label) {
    for ($i = 0; $i -lt $cells.Count - 1; $i++) { if ($cells[$i] -eq $label) { return $cells[$i + 1] } }
    return ""
  }
  $period = _after "Period:"
  $dm = [regex]::Match($period, '(\d{4}\.\d{2}\.\d{2})\s*-\s*(\d{4}\.\d{2}\.\d{2})')
  [pscustomobject]@{
    Ok     = ($title -match 'Strategy Tester Report' -and (_after "Expert:"))
    EA     = (_after "Expert:")
    Symbol = (_after "Symbol:")
    From   = $(if ($dm.Success) { $dm.Groups[1].Value } else { "" })
    To     = $(if ($dm.Success) { $dm.Groups[2].Value } else { "" })
  }
}

function Get-OptInfo([string]$path) {
  $raw = Get-Content -Raw -LiteralPath $path
  $title = [regex]::Match($raw, '<Title>(.*?)</Title>', 'IgnoreCase').Groups[1].Value.Trim()
  $isOpt = ($raw -match 'office:spreadsheet' -and $title)
  $m = [regex]::Match($title, '^(.*?)\s+([A-Z0-9._]+),([A-Za-z0-9]+)\s+(\d{4}\.\d{2}\.\d{2})-(\d{4}\.\d{2}\.\d{2})')
  [pscustomobject]@{
    Ok     = $isOpt
    EA     = $(if ($m.Success) { $m.Groups[1].Value.Trim() } else { $title })
    Symbol = $(if ($m.Success) { $m.Groups[2].Value } else { "" })
    From   = $(if ($m.Success) { $m.Groups[4].Value } else { "" })
    To     = $(if ($m.Success) { $m.Groups[5].Value } else { "" })
  }
}

# ===== ฟังก์ชันดึง 1 โหมด คืน path ปลายทาง (หรือ $null ถ้าไม่เจอ) =====
function Invoke-Fetch([string]$mode) {
  $ext = if ($mode -eq "single") { @("*.htm", "*.html") } else { @("*.xml") }
  $cands = foreach ($d in $ScanDirs) {
    foreach ($p in $ext) { Get-ChildItem -LiteralPath $d -Filter $p -File -ErrorAction SilentlyContinue }
  }
  $cands = $cands | Where-Object { $_.DirectoryName -ne $Reports -and $_.DirectoryName -ne $Opts } |
    Sort-Object LastWriteTime -Descending
  if (-not $cands) { Write-Host "[$mode] ไม่เจอไฟล์ $($ext -join '/') ในโฟลเดอร์ที่สแกน" -ForegroundColor Red; return $null }

  $picked = $null; $info = $null
  foreach ($f in $cands) {
    try {
      $i = if ($mode -eq "single") { Get-SingleInfo $f.FullName } else { Get-OptInfo $f.FullName }
      if ($i.Ok) { $picked = $f; $info = $i; break }
    } catch {}
  }
  if (-not $picked) {
    Write-Host "[$mode] เจอไฟล์แต่ไม่มีตัวไหนเป็น $mode report ที่อ่านได้ (ใหม่สุด: $($cands[0].Name))" -ForegroundColor Red
    return $null
  }

  Write-Host ""
  Write-Host "  [$mode] EA ที่เทสล่าสุด : $($info.EA)" -ForegroundColor Green
  Write-Host "         Symbol         : $($info.Symbol)"
  Write-Host "         ช่วงวัน         : $($info.From) - $($info.To)"
  Write-Host "         ไฟล์ต้นทาง       : $($picked.FullName)"
  Write-Host "         เวลาเซฟ         : $($picked.LastWriteTime)"
  if ($ExpectEA -and ($info.EA -notlike "*$ExpectEA*")) {
    Write-Host "  !! เตือน: EA ในไฟล์ ('$($info.EA)') ไม่ตรงกับที่คาด ('$ExpectEA') — เช็คก่อนใช้ผล" -ForegroundColor Yellow
  }

  $eaSafe = Get-SafeName $info.EA; $symSafe = Get-SafeName $info.Symbol
  if ($mode -eq "single") {
    $name = if ($Label) { $Label } else { "{0}_{1}_{2}-{3}" -f $eaSafe, $symSafe, ($info.From -replace '\.', ''), ($info.To -replace '\.', '') }
    $dest = Join-Path $Reports "$name.htm"
  } else {
    $name = if ($Label) { ($Label -replace '^OPT_', '') } else { "{0}_{1}" -f $eaSafe, $symSafe }
    $dest = Join-Path $Opts "OPT_$name.xml"
  }
  if (Test-Path $dest) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $b = [IO.Path]::GetFileNameWithoutExtension($dest); $e = [IO.Path]::GetExtension($dest)
    $dest = Join-Path (Split-Path $dest) "${b}_$stamp$e"
  }
  if ($Move) { Move-Item -LiteralPath $picked.FullName -Destination $dest -Force }
  else { Copy-Item -LiteralPath $picked.FullName -Destination $dest -Force }
  Write-Host "  OK -> $dest" -ForegroundColor Cyan

  # บันทึกลง RUN_LOG.csv
  if (-not $NoLog -and (Test-Path $LogPy)) {
    try { & python $LogPy "$dest" --type $mode --strategy $Strategy 2>&1 | Out-Host }
    catch { Write-Host "  (log ไม่สำเร็จ: $($_.Exception.Message))" -ForegroundColor DarkYellow }
  }

  Write-Host "  ขั้นต่อไป (ให้ Claude รัน):" -ForegroundColor White
  if ($mode -eq "single") {
    Write-Host "    python D:\EA_LAB\scripts\_show_rows.py `"$eaSafe`"" -ForegroundColor Gray
  } else {
    Write-Host "    python D:\EA_LAB\scripts\select_robust_pass.py `"$dest`"" -ForegroundColor Gray
  }
  return $dest
}

# ===== เมนู / resolve mode =====
if ($Mode -eq "menu") {
  Write-Host ""
  Write-Host "  MT5 report fetcher" -ForegroundColor Cyan
  Write-Host "  1) single   = ดึง backtest single-test .htm ตัวล่าสุด"
  Write-Host "  2) optimize = ดึง optimization .xml ตัวล่าสุด"
  Write-Host "  3) both     = ดึงทั้งสองอย่าง"
  $ans = (Read-Host "เลือก (1/2/3)").Trim()
  $Mode = switch ($ans) { "1" { "single" } "2" { "optimize" } "3" { "both" } default { $ans } }
}
switch ($Mode) { "1" { $Mode = "single" }; "2" { $Mode = "optimize" }; "3" { $Mode = "both" } }
if ($Mode -notin @("single", "optimize", "both")) { Write-Host "ABORT: Mode ไม่ถูกต้อง ($Mode)" -ForegroundColor Red; exit 2 }

Write-Host ""
Write-Host "scan: $($ScanDirs -join '  |  ')" -ForegroundColor DarkGray
if ($Mode -eq "both" -and $Label) { Write-Host "(หมายเหตุ: -Label ใช้ได้เฉพาะโหมดเดียว — โหมด both จะตั้งชื่ออัตโนมัติ)" -ForegroundColor DarkYellow; $Label = "" }

$results = @()
if ($Mode -eq "both") {
  $results += Invoke-Fetch "single"
  $results += Invoke-Fetch "optimize"
} else {
  $results += Invoke-Fetch $Mode
}

$ok = @($results | Where-Object { $_ })
Write-Host ""
if ($ok.Count -gt 0) {
  Write-Host "เสร็จ $($ok.Count) ไฟล์ — บอก Claude ได้เลยว่าดึงผลมาแล้ว (ดู RUN_LOG.csv ได้ด้วย)" -ForegroundColor Green
} else {
  Write-Host "ไม่ได้ไฟล์ — เช็คว่า Save as Report ลงโฟลเดอร์ที่สแกนหรือยัง" -ForegroundColor Red
}
