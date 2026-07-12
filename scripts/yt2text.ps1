<#
  yt2text.ps1 — YouTube link -> transcript .txt (for strategy mining)

  Pipeline:
    1) yt-dlp: try to pull existing subtitles (manual, then auto). Fast, free, no GPU.
    2) If no subs -> download bestaudio + transcribe with Whisper on the RTX 3060 (CUDA).
  Output: a plain-text transcript file whose path is printed on the last line.
  Hand that .txt to Claude to extract the trading strategy (entry/exit/lot/risk).

  Stack lives in an external venv (kept out of git): C:\Users\patip\tools\yt-whisper
  Built 2026-07-12: Python 3.12.13 (uv) + yt-dlp + torch 2.5.1+cu121 + openai-whisper + ffmpeg 8.1.

  Usage:
    powershell scripts\yt2text.ps1 -Url "https://youtu.be/XXXX"
    powershell scripts\yt2text.ps1 -Url "..." -Model large-v3 -Lang th
    powershell scripts\yt2text.ps1 -Url "..." -ForceWhisper   # skip subtitles, always transcribe
#>
param(
  [Parameter(Mandatory=$true)][string]$Url,
  [string]$Model = "medium",           # tiny|base|small|medium|large-v3  (medium = good on 12GB 3060)
  [string]$Lang  = "",                 # "" = auto-detect; or "en","th",...
  [string]$OutDir = "$PSScriptRoot\..\_triage\yt_transcripts",
  [switch]$ForceWhisper
)

# Continue (not Stop): yt-dlp/whisper write warnings to stderr, which under Stop
# PowerShell turns into terminating NativeCommandError. We gate on file existence +
# $LASTEXITCODE + explicit throws instead, so warnings never abort the run.
$ErrorActionPreference = "Continue"
$TOOLS   = "C:\Users\patip\tools\yt-whisper"
$SCRIPTS = "$TOOLS\Scripts"
$PY      = "$SCRIPTS\python.exe"
$YTDLP   = "$SCRIPTS\yt-dlp.exe"
if (-not (Test-Path $PY))    { throw "venv python not found at $PY - re-run the install." }
if (-not (Test-Path $YTDLP)) { throw "yt-dlp not found at $YTDLP" }
$env:PATH = "$SCRIPTS;$env:PATH"    # so whisper finds ffmpeg/ffprobe

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$work  = Join-Path $OutDir "job_$stamp"
New-Item -ItemType Directory -Force -Path $work | Out-Null
Write-Host "[yt2text] work dir: $work"

# --- helper: VTT/SRT -> clean deduped plain text ---
function Convert-SubToText($subPath, $txtPath) {
  $lines = Get-Content $subPath -Encoding UTF8
  $out = New-Object System.Collections.Generic.List[string]
  $last = ""
  foreach ($ln in $lines) {
    if ($ln -match '-->') { continue }                         # timestamp cue
    if ($ln -match '^\s*$') { continue }                       # blank
    if ($ln -match '^\d+\s*$') { continue }                    # srt index
    if ($ln -match '^(WEBVTT|Kind:|Language:)') { continue }   # vtt header
    $t = $ln -replace '<[^>]+>',''                             # strip <c>/<00:..> tags
    $t = $t -replace '&nbsp;',' ' -replace '&amp;','&' -replace '&#39;',"'" -replace '&quot;','"'
    $t = $t.Trim()
    if ($t -eq '') { continue }
    if ($t -eq $last) { continue }                             # collapse rolling-caption dupes
    $out.Add($t); $last = $t
  }
  ($out -join "`n") | Set-Content -Path $txtPath -Encoding UTF8
  return $out.Count
}

$finalTxt = $null

if (-not $ForceWhisper) {
  Write-Host "[yt2text] step 1: trying subtitles via yt-dlp..."
  $subLangs = if ($Lang) { "$Lang,en,en-orig,th" } else { "en,en-orig,th" }
  & $YTDLP --skip-download --write-subs --write-auto-subs --sub-langs $subLangs `
           --sub-format "vtt" --convert-subs vtt `
           -o "$work\%(id)s.%(ext)s" $Url 2>&1 | Write-Host
  $vtt = Get-ChildItem "$work\*.vtt" -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1
  if ($vtt) {
    $finalTxt = Join-Path $OutDir "transcript_$stamp.txt"
    $n = Convert-SubToText $vtt.FullName $finalTxt
    Write-Host "[yt2text] subtitles found ($($vtt.Name)) -> $n lines"
  } else {
    Write-Host "[yt2text] no subtitles available; falling back to Whisper."
  }
}

if (-not $finalTxt) {
  Write-Host "[yt2text] step 2: downloading audio..."
  & $YTDLP -f bestaudio -x --audio-format m4a -o "$work\audio.%(ext)s" $Url 2>&1 | Write-Host
  $audio = Get-ChildItem "$work\audio.*" -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $audio) { throw "audio download failed" }
  Write-Host "[yt2text] step 3: transcribing with Whisper (model=$Model, GPU)..."
  $langArg = if ($Lang) { @("--language", $Lang) } else { @() }
  & $PY -m whisper $audio.FullName --model $Model --device cuda --output_format txt --output_dir $work @langArg 2>&1 | Write-Host
  $wtxt = Get-ChildItem "$work\audio.txt" -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $wtxt) { throw "whisper produced no txt" }
  $finalTxt = Join-Path $OutDir "transcript_$stamp.txt"
  Copy-Item $wtxt.FullName $finalTxt -Force
}

Write-Host ""
Write-Host "[yt2text] DONE. Transcript:"
Write-Output $finalTxt
