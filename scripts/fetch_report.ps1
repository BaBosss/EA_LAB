<#
fetch_report.ps1 — ดึง MT5 report ที่ "Save as Report" เข้าโฟลเดอร์ EA_LAB
จัดเป็นโฟลเดอร์แยกตามชื่อ EA + แยก single/optimize + บันทึก RUN_LOG.csv อัตโนมัติ

โครงสร้างปลายทาง:
  _mt5_auto\EA_runs\<EA>\single\    <- .htm + รูป png ของ single test
  _mt5_auto\EA_runs\<EA>\optimize\  <- .xml ของ optimization

ขั้นตอนของคุณ: ใน MT5 -> คลิกขวาผลลัพธ์ -> Save as Report -> เซฟลง D:\EA_LAB\_inbox
แล้วเลือกวิธีใช้:

  โหมดดึงครั้งเดียว:
    & .\fetch_report.ps1                 # เมนู 1/2/3
    & .\fetch_report.ps1 -Mode both

  โหมดเฝ้าอัตโนมัติ (แนะนำเวลาเทสหลายตัวรวด):
    & .\fetch_report.ps1 -Watch          # เปิดค้างไว้ พอ save ลง _inbox ปุ๊บ จัดให้ทันที
                                          # หยุดด้วย Ctrl+C

ทุกโหมดอ่านชื่อ EA / Symbol / ช่วงวันจากในไฟล์เอง -> ไม่ต้องพิมพ์
#>
param(
  [ValidateSet("menu", "single", "optimize", "both", "1", "2", "3")]
  [string]$Mode = "menu",
  [switch]$Watch,               # เฝ้า _inbox อัตโนมัติ (วนลูป)
  [switch]$WatchOnce,           # สแกน _inbox รอบเดียวแล้วจบ (ใช้ debug/cron)
  [int]$IntervalSec = 5,        # รอบการเฝ้า (วินาที)
  [string]$Label = "",          # บังคับชื่อไฟล์ (โหมดเดียวเท่านั้น)
  [string]$ExpectEA = "",       # เตือนเมื่อ EA ในไฟล์ไม่ตรง
  [string]$Strategy = "default",# ส่งต่อ log_run.py สำหรับ scoring
  [string[]]$Source = @(),      # เพิ่ม folder สแกนเอง
  [switch]$Move,                # ย้ายไฟล์ต้นทางทิ้ง (default = copy). โหมด -Watch บังคับ move
  [switch]$NoLog                # ไม่บันทึก RUN_LOG.csv
)
$ErrorActionPreference = "Stop"

$Auto    = "D:\EA_LAB\_mt5_auto"
$Runs    = Join-Path $Auto "EA_runs"
$Inbox   = "D:\EA_LAB\_inbox"
$Mt5Data = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355"
$LogPy   = "D:\EA_LAB\scripts\log_run.py"
New-Item -ItemType Directory -Force $Runs, $Inbox | Out-Null

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
    Ok = ($title -match 'Strategy Tester Report' -and (_after "Expert:"))
    EA = (_after "Expert:"); Symbol = (_after "Symbol:")
    From = $(if ($dm.Success) { $dm.Groups[1].Value } else { "" })
    To   = $(if ($dm.Success) { $dm.Groups[2].Value } else { "" })
  }
}

function Get-OptInfo([string]$path) {
  $raw = Get-Content -Raw -LiteralPath $path
  $title = [regex]::Match($raw, '<Title>(.*?)</Title>', 'IgnoreCase').Groups[1].Value.Trim()
  $isOpt = ($raw -match 'office:spreadsheet' -and $title)
  $m = [regex]::Match($title, '^(.*?)\s+([A-Z0-9._]+),([A-Za-z0-9]+)\s+(\d{4}\.\d{2}\.\d{2})-(\d{4}\.\d{2}\.\d{2})')
  [pscustomobject]@{
    Ok = $isOpt
    EA = $(if ($m.Success) { $m.Groups[1].Value.Trim() } else { $title })
    Symbol = $(if ($m.Success) { $m.Groups[2].Value } else { "" })
    From = $(if ($m.Success) { $m.Groups[4].Value } else { "" })
    To   = $(if ($m.Success) { $m.Groups[5].Value } else { "" })
  }
}

# ===== จัดไฟล์ 1 ไฟล์เข้าโฟลเดอร์ EA + log. คืน $dest หรือ $null =====
function Process-File([System.IO.FileInfo]$file, [string]$forceLabel) {
  $isXml = ($file.Extension -ieq ".xml")
  $info = if ($isXml) { Get-OptInfo $file.FullName } else { Get-SingleInfo $file.FullName }
  if (-not $info.Ok) { return $null }
  $mode = if ($isXml) { "optimize" } else { "single" }

  Write-Host ""
  Write-Host "  [$mode] $($info.EA)  |  $($info.Symbol)  |  $($info.From) - $($info.To)" -ForegroundColor Green
  Write-Host "         src: $($file.FullName)" -ForegroundColor DarkGray
  if ($ExpectEA -and ($info.EA -notlike "*$ExpectEA*")) {
    Write-Host "  !! เตือน: EA ('$($info.EA)') ไม่ตรงกับที่คาด ('$ExpectEA')" -ForegroundColor Yellow
  }

  $eaSafe = Get-SafeName $info.EA; $symSafe = Get-SafeName $info.Symbol
  $destDir = Join-Path (Join-Path $Runs $eaSafe) $mode
  New-Item -ItemType Directory -Force $destDir | Out-Null

  if ($mode -eq "single") {
    $name = if ($forceLabel) { $forceLabel } else { "{0}_{1}-{2}" -f $symSafe, ($info.From -replace '\.', ''), ($info.To -replace '\.', '') }
    $ext = ".htm"
  } else {
    $name = if ($forceLabel) { ($forceLabel -replace '^OPT_', '') } else { $symSafe }
    $name = "OPT_$name"; $ext = ".xml"
  }
  $dest = Join-Path $destDir "$name$ext"
  if (Test-Path $dest) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $dest = Join-Path $destDir "${name}_$stamp$ext"
  }
  $finalBase = [IO.Path]::GetFileNameWithoutExtension($dest)

  $copy = { param($s, $d) if ($Move -or $Watch) { Move-Item -LiteralPath $s -Destination $d -Force } else { Copy-Item -LiteralPath $s -Destination $d -Force } }
  & $copy $file.FullName $dest

  # single: เก็บรูป png/gif ที่ชื่อขึ้นต้นเดียวกัน (X.png, X-holding.png, ...) ไปด้วย
  if ($mode -eq "single") {
    $srcBase = $file.BaseName
    Get-ChildItem -LiteralPath $file.DirectoryName -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -in @(".png", ".gif") -and ($_.BaseName -eq $srcBase -or $_.BaseName -like "$srcBase-*") } |
      ForEach-Object {
        $suffix = $_.BaseName.Substring($srcBase.Length)   # "" หรือ "-holding"
        & $copy $_.FullName (Join-Path $destDir "$finalBase$suffix$($_.Extension)")
      }
  }
  Write-Host "  -> $dest" -ForegroundColor Cyan

  if (-not $NoLog -and (Test-Path $LogPy)) {
    try { & python $LogPy "$dest" --type $mode --strategy $Strategy 2>&1 | Out-Host }
    catch { Write-Host "  (log ไม่สำเร็จ: $($_.Exception.Message))" -ForegroundColor DarkYellow }
  }
  return $dest
}

# ===== ดึงตัวล่าสุดของโหมดที่ระบุ (single/optimize) =====
function Invoke-Fetch([string]$mode) {
  $ext = if ($mode -eq "single") { @("*.htm", "*.html") } else { @("*.xml") }
  $cands = foreach ($d in $ScanDirs) {
    foreach ($p in $ext) { Get-ChildItem -LiteralPath $d -Filter $p -File -ErrorAction SilentlyContinue }
  }
  $cands = $cands | Where-Object { $_.FullName -notlike "$Runs*" } | Sort-Object LastWriteTime -Descending
  if (-not $cands) { Write-Host "[$mode] ไม่เจอไฟล์ $($ext -join '/') ในโฟลเดอร์ที่สแกน" -ForegroundColor Red; return $null }
  foreach ($f in $cands) {
    $r = Process-File $f $Label
    if ($r) { return $r }
  }
  Write-Host "[$mode] เจอไฟล์แต่ไม่มีตัวไหนเป็น $mode report ที่อ่านได้ (ใหม่สุด: $($cands[0].Name))" -ForegroundColor Red
  return $null
}

# ===== โหมดเฝ้าอัตโนมัติ =====
function Start-Watch {
  Write-Host ""
  Write-Host "  WATCH: เฝ้า $Inbox — Save as Report ลงที่นี่ได้เลย (Ctrl+C เพื่อหยุด)" -ForegroundColor Cyan
  Write-Host "  ไฟล์ใหม่จะถูกย้ายเข้า EA_runs\<EA>\single|optimize + log ให้อัตโนมัติ" -ForegroundColor DarkGray
  $seen = @{}
  while ($true) {
    Invoke-WatchPass $seen
    Start-Sleep -Seconds $IntervalSec
  }
}

function Invoke-WatchPass($seen) {
  $files = @(Get-ChildItem -LiteralPath $Inbox -File -ErrorAction SilentlyContinue |
    Where-Object { @(".htm", ".html", ".xml") -contains $_.Extension.ToLower() } | Sort-Object LastWriteTime)
  foreach ($f in $files) {
    $key = "$($f.FullName)|$($f.Length)|$($f.LastWriteTimeUtc.Ticks)"
    if ($seen.ContainsKey($key)) { continue }
    # รอให้ไฟล์เขียนเสร็จ (ขนาดนิ่ง) กันจับตอนยังเซฟไม่จบ
    Start-Sleep -Milliseconds 400
    $now = Get-Item -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $now -or $now.Length -ne $f.Length) { continue }
    Process-File $now $Label | Out-Null
    $seen[$key] = $true
  }
}

# ===== resolve โหมด / เมนู =====
if ($WatchOnce) { Invoke-WatchPass @{}; return }
if ($Watch) { Start-Watch; return }

if ($Mode -eq "menu") {
  Write-Host ""
  Write-Host "  MT5 report fetcher" -ForegroundColor Cyan
  Write-Host "  1) single   = ดึง single-test .htm ตัวล่าสุด"
  Write-Host "  2) optimize = ดึง optimization .xml ตัวล่าสุด"
  Write-Host "  3) both     = ดึงทั้งสองอย่าง"
  Write-Host "  4) watch    = เฝ้า _inbox อัตโนมัติ (เทสหลายตัวรวด)"
  $ans = (Read-Host "เลือก (1/2/3/4)").Trim()
  if ($ans -eq "4") { Start-Watch; return }
  $Mode = switch ($ans) { "1" { "single" } "2" { "optimize" } "3" { "both" } default { $ans } }
}
switch ($Mode) { "1" { $Mode = "single" }; "2" { $Mode = "optimize" }; "3" { $Mode = "both" } }
if ($Mode -notin @("single", "optimize", "both")) { Write-Host "ABORT: Mode ไม่ถูกต้อง ($Mode)" -ForegroundColor Red; exit 2 }

Write-Host ""
Write-Host "scan: $($ScanDirs -join '  |  ')" -ForegroundColor DarkGray
if ($Mode -eq "both" -and $Label) { Write-Host "(โหมด both ตั้งชื่ออัตโนมัติ — -Label ถูกข้าม)" -ForegroundColor DarkYellow; $Label = "" }

$results = @()
if ($Mode -eq "both") { $results += Invoke-Fetch "single"; $results += Invoke-Fetch "optimize" }
else { $results += Invoke-Fetch $Mode }

$ok = @($results | Where-Object { $_ })
Write-Host ""
if ($ok.Count -gt 0) { Write-Host "เสร็จ $($ok.Count) ไฟล์ — บอก Claude ได้เลย (ดู RUN_LOG.csv ได้ด้วย)" -ForegroundColor Green }
else { Write-Host "ไม่ได้ไฟล์ — เช็คว่า Save as Report ลงโฟลเดอร์ที่สแกนหรือยัง" -ForegroundColor Red }
