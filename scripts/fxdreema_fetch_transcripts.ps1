<#
  fxdreema_fetch_transcripts.ps1 — batch-pull Thai auto-caption transcripts for the
  whole @fxdreemalearner channel, throttled to survive YouTube HTTP 429.

  Resumable: skips videos whose transcript .txt already exists, so it can be run
  "เรื่อยๆ" across days / restarted after a 429 cooldown without redoing work.

  Reads : _triage/fxdreema_youtube/channel_inventory.csv  (duration_sec,duration_hms,video_id,title)
  Writes: _triage/fxdreema_youtube/transcripts/<TAG>__<id>.txt   (clean deduped Thai text)
          _triage/fxdreema_youtube/fetch_log.csv                 (id,tag,status,lines,ts)

  Usage:
    scripts\fxdreema_fetch_transcripts.ps1                # all remaining, 8s throttle
    scripts\fxdreema_fetch_transcripts.ps1 -SleepSec 10   # gentler
    scripts\fxdreema_fetch_transcripts.ps1 -Limit 20      # do 20 then stop (test)
    scripts\fxdreema_fetch_transcripts.ps1 -Lang en       # English auto-translated instead of th
#>
param(
  [int]$SleepSec = 8,
  [int]$Limit = 0,           # 0 = no limit (do all remaining)
  [string]$Lang = "th"
)

$ErrorActionPreference = "Continue"
$SCRIPTS = "C:\Users\patip\tools\yt-whisper\Scripts"
$YTDLP   = "$SCRIPTS\yt-dlp.exe"
$env:PATH = "$SCRIPTS;$env:PATH"

$root    = "D:\EA_LAB\_triage\fxdreema_youtube"
$csv     = Join-Path $root "channel_inventory.csv"
$tdir    = Join-Path $root "transcripts"
$logcsv  = Join-Path $root "fetch_log.csv"
New-Item -ItemType Directory -Force -Path $tdir | Out-Null
if (-not (Test-Path $csv)) { throw "inventory not found: $csv" }
if (-not (Test-Path $logcsv)) { "video_id,tag,status,lines,ts" | Set-Content $logcsv -Encoding UTF8 }

function Get-Tag($title, $id) {
  if ($title -match 'EX\s*0*([0-9]+)') { return "EX{0:D3}" -f [int]$Matches[1] }
  $slug = ($title -replace '[^\w]+','_').Trim('_')
  if ($slug.Length -gt 30) { $slug = $slug.Substring(0,30) }
  if ([string]::IsNullOrWhiteSpace($slug)) { $slug = "vid" }
  return $slug
}

function Convert-VttToText($subPath, $txtPath) {
  $lines = Get-Content $subPath -Encoding UTF8
  $out = New-Object System.Collections.Generic.List[string]
  $last = ""
  foreach ($ln in $lines) {
    if ($ln -match '-->') { continue }
    if ($ln -match '^\s*$') { continue }
    if ($ln -match '^\d+\s*$') { continue }
    if ($ln -match '^(WEBVTT|Kind:|Language:)') { continue }
    $t = ($ln -replace '<[^>]+>','') -replace '&nbsp;',' ' -replace '&amp;','&' -replace '&#39;',"'" -replace '&quot;','"'
    $t = $t.Trim()
    if ($t -eq '' -or $t -eq $last) { continue }
    $out.Add($t); $last = $t
  }
  ($out -join "`n") | Set-Content -Path $txtPath -Encoding UTF8
  return $out.Count
}

$rows = Import-Csv $csv
Write-Host "[fetch] inventory: $($rows.Count) videos | lang=$Lang | throttle=${SleepSec}s"
$done = 0; $skip = 0; $fail = 0; $processed = 0

foreach ($r in $rows) {
  $id = $r.video_id; $title = $r.title
  $tag = Get-Tag $title $id
  $txt = Join-Path $tdir "$tag`__$id.txt"
  if (Test-Path $txt) { $skip++; continue }
  if ($Limit -gt 0 -and $processed -ge $Limit) { break }
  $processed++

  $work = Join-Path $tdir "_tmp_$id"
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  Write-Host "[fetch] $tag ($id) : $title"

  $attempt = 0; $ok = $false
  while ($attempt -lt 3 -and -not $ok) {
    $attempt++
    $raw = & $YTDLP --skip-download --write-auto-subs --sub-langs $Lang --sub-format vtt --convert-subs vtt `
                    -o "$work\%(id)s.%(ext)s" "https://www.youtube.com/watch?v=$id" 2>&1
    if ($raw -match '429|Too Many Requests') {
      $back = 60 * $attempt
      Write-Host "[fetch]   429 rate-limit -> backing off ${back}s (attempt $attempt/3)"
      Start-Sleep -Seconds $back
      continue
    }
    $vtt = Get-ChildItem "$work\*.vtt" -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1
    if ($vtt) {
      $n = Convert-VttToText $vtt.FullName $txt
      "$id,$tag,ok,$n,$(Get-Date -Format s)" | Add-Content $logcsv -Encoding UTF8
      Write-Host "[fetch]   ok -> $n lines"
      $done++; $ok = $true
    } else {
      Write-Host "[fetch]   no $Lang subs for $id"
      "$id,$tag,no_subs,0,$(Get-Date -Format s)" | Add-Content $logcsv -Encoding UTF8
      $fail++; $ok = $true   # not retryable
    }
  }
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds $SleepSec
}

Write-Host ""
Write-Host "[fetch] DONE this run: fetched=$done  no_subs=$fail  already_had=$skip"
$total = (Get-ChildItem "$tdir\*.txt" -ErrorAction SilentlyContinue).Count
Write-Host "[fetch] transcripts on disk: $total / $($rows.Count)"
