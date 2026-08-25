# Deterministic cage for lab->staging->VPS guard-feed transport.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$publisher = Join-Path $root 'scripts\publish_guard_feeds_to_vps.ps1'
$vpsPull = Join-Path $root 'ea_projects\(Boss)_NewsGuard\vps_rclone\pull_guard_feeds.ps1'
$daily = Join-Path $root 'scripts\daily_monitor.ps1'
$t = Join-Path $env:TEMP ('ea_lab_guard_feed_test_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $t | Out-Null
try {
  $src = Join-Path $t 'src'; $common = Join-Path $t 'common'; $stage = Join-Path $t 'stage'
  $vpsStage = Join-Path $t 'vpsstage'; $vpsCommon = Join-Path $t 'vpscommon'; $logs = Join-Path $t 'logs'
  New-Item -ItemType Directory -Path $src,$common,$stage,$vpsStage,$vpsCommon,$logs -Force | Out-Null
  $news = Join-Path $src 'news.csv'; $regime = Join-Path $src 'regime.csv'
  @('BkkTime,Currency,Title,TimeRaw,Forecast,Previous','2026.08.23 18:00,USD,CPI,raw,,') | Set-Content $news -Encoding UTF8
  @('datetime,state,ri,flags','2026.08.22 09:00,NEUTRAL,0.1,""','2026.08.23 09:00,RISK_OFF,-0.3,""') | Set-Content $regime -Encoding UTF8

  & $publisher -NewsCsv $news -RegimeCsv $regime -CommonDir $common -StagingDir $stage -NewsMaxAgeHours 100 -RegimeMaxAgeHours 100
  if ($LASTEXITCODE -ne 0) { throw 'valid lab publish failed' }
  foreach($n in @('EA_LAB_news_week.csv','EA_LAB_mris_regime.csv')) {
    if (-not (Test-Path (Join-Path $common $n)) -or -not (Test-Path (Join-Path $stage $n))) { throw "missing published $n" }
  }
  $regDest = Join-Path $stage 'EA_LAB_mris_regime.csv'
  $before = (Get-FileHash $regDest).Hash
  @('datetime,state,ri,flags','BAD') | Set-Content $regime -Encoding UTF8
  & $publisher -NewsCsv $news -RegimeCsv $regime -CommonDir $common -StagingDir $stage -NewsMaxAgeHours 100 -RegimeMaxAgeHours 100
  if ($LASTEXITCODE -ne 1) { throw 'invalid regime must make lab publisher exit 1' }
  if ((Get-FileHash $regDest).Hash -ne $before) { throw 'invalid regime overwrote last-good staging file' }

  Copy-Item (Join-Path $stage 'EA_LAB_news_week.csv') (Join-Path $vpsStage 'EA_LAB_news_week.csv') -Force
  Copy-Item $regDest (Join-Path $vpsStage 'EA_LAB_mris_regime.csv') -Force
  & $vpsPull -SkipFetch -LocalStagingDir $vpsStage -CommonDir $vpsCommon -LogFile (Join-Path $logs 'pull.log') -NewsMaxAgeHours 100 -RegimeMaxAgeHours 100
  if ($LASTEXITCODE -ne 0) { throw 'valid VPS publish failed' }
  $vpsReg = Join-Path $vpsCommon 'EA_LAB_mris_regime.csv'
  $vpsBefore = (Get-FileHash $vpsReg).Hash

  # DEMO-safe regime-only mode must publish MacroGate without touching NewsGuard.
  $regOnlyCommon = Join-Path $t 'regonlycommon'
  New-Item -ItemType Directory -Path $regOnlyCommon -Force | Out-Null
  $regOnlyNews = Join-Path $regOnlyCommon 'EA_LAB_news_week.csv'
  'KEEP_NEWS_UNCHANGED' | Set-Content $regOnlyNews -Encoding UTF8
  $regOnlyNewsHash = (Get-FileHash $regOnlyNews).Hash
  @('BkkTime,Currency,Title','BAD') | Set-Content (Join-Path $vpsStage 'EA_LAB_news_week.csv') -Encoding UTF8
  Copy-Item $regDest (Join-Path $vpsStage 'EA_LAB_mris_regime.csv') -Force
  & $vpsPull -RegimeOnly -SkipFetch -LocalStagingDir $vpsStage -CommonDir $regOnlyCommon -LogFile (Join-Path $logs 'pull-regime-only.log') -RegimeMaxAgeHours 100
  if ($LASTEXITCODE -ne 0) { throw 'regime-only VPS publish failed' }
  if ((Get-FileHash $regOnlyNews).Hash -ne $regOnlyNewsHash) { throw 'regime-only mode touched NewsGuard Common file' }
  if (-not (Test-Path (Join-Path $regOnlyCommon 'EA_LAB_mris_regime.csv'))) { throw 'regime-only mode did not publish MacroGate feed' }
  # RegimeOnly fetch must request only the regime object and leave staged news untouched.
  $fetchArgs = Join-Path $t 'regime-fetch-args.txt'
  $fakeRegimeRclone = Join-Path $t 'fake-regime-rclone.cmd'
  $stagedNews = Join-Path $vpsStage 'EA_LAB_news_week.csv'
  'KEEP_STAGED_NEWS' | Set-Content $stagedNews -Encoding UTF8
  $stagedNewsHash = (Get-FileHash $stagedNews).Hash
  @('@echo off',('echo %* > "{0}"' -f $fetchArgs),('copy /y "{0}" "{1}" >nul' -f $regDest,(Join-Path $vpsStage 'EA_LAB_mris_regime.csv')),'exit /b 0') | Set-Content -LiteralPath $fakeRegimeRclone -Encoding ASCII
  & $vpsPull -RegimeOnly -RcloneExe $fakeRegimeRclone -RcloneConfig (Join-Path $t 'none.conf') -RemoteDir 'fake:remote' -LocalStagingDir $vpsStage -CommonDir $regOnlyCommon -LogFile (Join-Path $logs 'pull-regime-fetch.log') -RegimeMaxAgeHours 100
  if ($LASTEXITCODE -ne 0) { throw 'regime-only fetch path failed' }
  $fetchArgText = Get-Content -Raw -LiteralPath $fetchArgs
  if ($fetchArgText -notmatch 'EA_LAB_mris_regime\.csv') { throw 'regime-only fetch did not request regime object' }
  if ($fetchArgText -match 'EA_LAB_news_week\.csv') { throw 'regime-only fetch requested NewsGuard object' }
  if ((Get-FileHash $stagedNews).Hash -ne $stagedNewsHash) { throw 'regime-only fetch touched staged NewsGuard file' }
  @('datetime,state,ri,flags','BAD') | Set-Content (Join-Path $vpsStage 'EA_LAB_mris_regime.csv') -Encoding UTF8
  & $vpsPull -SkipFetch -LocalStagingDir $vpsStage -CommonDir $vpsCommon -LogFile (Join-Path $logs 'pull-neg.log') -NewsMaxAgeHours 100 -RegimeMaxAgeHours 100
  if ($LASTEXITCODE -ne 1) { throw 'invalid VPS regime must exit 1' }
  if ((Get-FileHash $vpsReg).Hash -ne $vpsBefore) { throw 'invalid VPS regime overwrote last-good Common file' }

  # A successful rclone exit with missing remote files must not reuse old local staging.
  Copy-Item (Join-Path $stage 'EA_LAB_news_week.csv') (Join-Path $vpsStage 'EA_LAB_news_week.csv') -Force
  Copy-Item $regDest (Join-Path $vpsStage 'EA_LAB_mris_regime.csv') -Force
  $newsBefore = (Get-FileHash (Join-Path $vpsCommon 'EA_LAB_news_week.csv')).Hash
  $fakeRclone = Join-Path $t 'fake_rclone.cmd'
  '@echo off' | Set-Content -LiteralPath $fakeRclone -Encoding ASCII
  'exit /b 0' | Add-Content -LiteralPath $fakeRclone -Encoding ASCII
  & $vpsPull -RcloneExe $fakeRclone -RcloneConfig (Join-Path $t 'none.conf') -RemoteDir 'fake:remote' `
    -LocalStagingDir $vpsStage -CommonDir $vpsCommon -LogFile (Join-Path $logs 'pull-missing.log') `
    -NewsMaxAgeHours 100 -RegimeMaxAgeHours 100
  if ($LASTEXITCODE -ne 1) { throw 'missing remote files must make VPS worker exit 1' }
  if (Test-Path (Join-Path $vpsStage 'EA_LAB_news_week.csv')) { throw 'pre-fetch news staging was incorrectly reused' }
  if (Test-Path (Join-Path $vpsStage 'EA_LAB_mris_regime.csv')) { throw 'pre-fetch regime staging was incorrectly reused' }
  if ((Get-FileHash (Join-Path $vpsCommon 'EA_LAB_news_week.csv')).Hash -ne $newsBefore) { throw 'missing remote changed last-good news' }
  if ((Get-FileHash $vpsReg).Hash -ne $vpsBefore) { throw 'missing remote changed last-good regime' }

  $dm = Get-Content -Raw -LiteralPath $daily
  $iExport = $dm.IndexOf("Step 'export-regime'")
  $iPublish = $dm.IndexOf("Step 'guard-feeds'")
  if ($iExport -lt 0 -or $iPublish -lt 0 -or $iExport -ge $iPublish) { throw 'daily monitor must export regime before guard publish' }
  if ($dm -notmatch 'publish_guard_feeds_to_vps\.ps1') { throw 'daily monitor not wired to unified publisher' }

  $cmd = Get-Content -Raw -LiteralPath (Join-Path $root 'ea_projects\(Boss)_NewsGuard\vps_rclone\pull_news.cmd')
  if ($cmd -notmatch 'pull_guard_feeds\.ps1') { throw 'compatibility pull_news.cmd not wired to unified VPS worker' }
  $regCmd = Get-Content -Raw -LiteralPath (Join-Path $root 'ea_projects\(Boss)_NewsGuard\vps_rclone\pull_regime.cmd')
  if ($regCmd -notmatch 'pull_guard_feeds\.ps1' -or $regCmd -notmatch 'RegimeOnly') { throw 'pull_regime.cmd not wired to regime-only worker mode' }

  Write-Host '[PASS] guard feed pipeline: valid, malformed-preserve, VPS atomic, and daily ordering checks passed'
  exit 0
}
finally {
  Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
}
