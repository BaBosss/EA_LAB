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

$repoRoot = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $repoRoot "ea_template"
$receiptRegistry = Join-Path $repoRoot "portfolio\build_receipts.jsonl"
. (Join-Path $repoRoot "scripts\lib\build_receipt.ps1")
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

$compileFailed = $false
if ($Compile) {
  # ORDER-129: dynamic discovery — the old static list silently omitted Boss_17_Wave5
  # (Codex system review 2026-07-18), leaving a stale binary deployable. Every Boss_*.mq5
  # in the template root now compiles; V1 EA_LabTemplate kept for reference.
  $targets = @(Get-ChildItem (Join-Path $src "Boss_*.mq5") | Sort-Object Name | ForEach-Object { $_.Name }) + @("EA_LabTemplate.mq5")
  foreach($t in $targets){
    $mq5 = Join-Path $dst $t
    if(-not (Test-Path $mq5)){ Write-Host "skip (missing): $t" -ForegroundColor DarkGray; continue }
    $targetFailed = $false
    $sourceText = Get-Content -LiteralPath $mq5 -Raw
    $logical = [IO.Path]::GetFileNameWithoutExtension($t)
    if($sourceText -match '#define\s+LAB_ENTRY_TAG\s+"([^"]+)"'){ $logical = $Matches[1] }
    $receipt = New-BuildReceiptToken
    Write-BuildReceiptHeader -HeaderPath (Join-Path $dst "core\BuildReceipt_gen.mqh") -Receipt $receipt
    $ex5 = Join-Path $dst ([IO.Path]::GetFileNameWithoutExtension($t) + ".ex5")
    # D6 fix (ORDER-094): delete the OLD .ex5 before compiling so a compile that fails this run
    # cannot leave a stale, previously-good binary behind looking like a fresh clean build.
    if(Test-Path $ex5){ Remove-Item $ex5 -Force }
    $log = Join-Path $dst ("compile_" + [IO.Path]::GetFileNameWithoutExtension($t) + ".log")
    if(Test-Path $log){ Remove-Item $log -Force }
    Start-Process -FilePath $meta -ArgumentList "/compile:`"$mq5`"","/log:`"$log`"" -Wait
    if(Test-Path $log){
      $txt = Get-Content -Raw -Encoding Unicode $log
      $res = ($txt -split "`r?`n" | Where-Object { $_ -match "Result:|error|warning" })
      Write-Host "[$t]" -ForegroundColor Cyan
      $res | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
      # D6 fix (ORDER-094): actually parse the Result line instead of just printing it. MetaEditor
      # exits 0 regardless of compile errors, and a failed compile does not always skip writing an
      # .ex5 (stale one could remain pre-fix) - the Result line is the only reliable pass/fail signal.
      $resultLine = $txt -split "`r?`n" | Where-Object { $_ -match "Result:\s*\d+\s+errors?" } | Select-Object -Last 1
      if ($resultLine -and ($resultLine -match "Result:\s*(\d+)\s+errors?(?:,\s*(\d+)\s+warnings?)?")) {
        # ORDER-129b (Codex audit): enforce the 0/0 policy - warnings used to pass silently
        $warn = if ($Matches[2]) { [int]$Matches[2] } else { 0 }
        if ([int]$Matches[1] -gt 0 -or $warn -gt 0) {
          Write-Host "  ** COMPILE FAIL: $t ($([int]$Matches[1]) errors, $warn warnings - 0/0 required) **" -ForegroundColor Red
          $compileFailed = $true; $targetFailed = $true
        }
      } else {
        Write-Host "  ** COMPILE FAIL: $t (no Result: line found in log) **" -ForegroundColor Red
        $compileFailed = $true; $targetFailed = $true
      }
      if (-not (Test-Path $ex5)) {
        Write-Host "  ** COMPILE FAIL: $t (no .ex5 produced) **" -ForegroundColor Red
        $compileFailed = $true; $targetFailed = $true
      }
    } else {
      Write-Host "  ** COMPILE FAIL: $t (no log produced) **" -ForegroundColor Red
      $compileFailed = $true; $targetFailed = $true
    }
    if(-not $targetFailed -and (Test-Path $ex5)) {
      Write-BuildReceiptRecord -RegistryPath $receiptRegistry -Receipt $receipt `
        -ArtifactPath $ex5 -SourcePath $mq5 -EaLogicalIdentity $logical
      Write-Host "  build receipt recorded -> $receipt" -ForegroundColor Green
      if ($t -ieq 'Boss_14_GridLog.mq5') {
        $compat = Join-Path (Split-Path -Parent $dst) 'Boss_14_GridLog.ex5'
        Sync-ManagedCompatibilityArtifact -CanonicalArtifactPath $ex5 -CompatibilityArtifactPath $compat | Out-Null
        Write-Host "  managed compatibility copy refreshed -> $compat" -ForegroundColor Green
      }
    }
  }
}
# lane 2: mirror compiled EAs (+source for reference) to the portable 2nd tester
# (D:\Meta 5b, /portable mode) so oc-btest can run its own lane without touching
# the main instance. .ex5 INCLUDED here on purpose (5b has no compiler wired up).
# D6 fix (ORDER-094): never mirror when any compile failed this run - a stale/missing .ex5
# reaching lane2 would let oc-btest silently run old or broken binaries.
if ($compileFailed) {
  Write-Host "skip lane2 mirror: compile failure(s) this run" -ForegroundColor Yellow
} else {
  $dst2 = "D:\Meta 5b\MQL5\Experts\EALabTpl"
  if (Test-Path "D:\Meta 5b\terminal64.exe") {
    robocopy "$dst" "$dst2" /MIR /R:1 /W:1 /XF *.log /NFL /NDL /NJH /NJS | Out-Null
    if($LASTEXITCODE -lt 8){ Write-Host "deployed lane2 -> $dst2" -ForegroundColor Cyan }
    else { Write-Host "lane2 robocopy error ($LASTEXITCODE)" -ForegroundColor Yellow }
    $canonical2 = Join-Path $dst2 'Boss_14_GridLog.ex5'
    if (Test-Path -LiteralPath $canonical2) {
      $compat2 = Join-Path (Split-Path -Parent $dst2) 'Boss_14_GridLog.ex5'
      Sync-ManagedCompatibilityArtifact -CanonicalArtifactPath $canonical2 -CompatibilityArtifactPath $compat2 | Out-Null
      Write-Host "managed compatibility lane2 copy refreshed -> $compat2" -ForegroundColor Green
    }
  }
}

Write-Host "Expert names: EALabTpl\Boss_11_GridTrend | EALabTpl\Boss_12_Breakout | EALabTpl\Boss_13_MeanRev | EALabTpl\Boss_14_GridLog | EALabTpl\Boss_15_ST03" -ForegroundColor Green
if ($compileFailed) { Write-Host "=== DEPLOY: compile failure(s) - see COMPILE FAIL lines above ===" -ForegroundColor Red; exit 1 }
exit 0
