param([string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('status-authority-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$fixture/scripts/lib","$fixture/portfolio","$fixture/.git" | Out-Null
foreach ($name in @('make_status_html.ps1','status_template.html','lib/repo_paths.ps1')) {
  Copy-Item -LiteralPath (Join-Path "$RepoRoot/scripts" $name) -Destination (Join-Path "$fixture/scripts" $name)
}
# Stub only unrelated monitoring readers; the deployment generator and template are real.
@'
function Get-VerifiedSnapshot { return [pscustomobject]@{State='UNAVAILABLE';Age=$null} }
function Format-ControlRoomHtml { return 'UNAVAILABLE' }
'@ | Set-Content "$fixture/scripts/lib/snapshot_reader.ps1"
@'
function Get-MonitorChainHealth { return $null }
function Format-MonitorChainHtml { return 'UNAVAILABLE' }
'@ | Set-Content "$fixture/scripts/lib/monitor_coverage.ps1"
@'
## 4. Historical live table
| 1 | ST_EA03 MACD | USDCAD | 9398 | 2.62 | LIVE |
| 2 | Bars8 | XAUUSD | 991002 | 3.92 | LIVE |
'@ | Set-Content "$fixture/PROJECT_STATE.md"
@'
| # | Symbol | Magic | x | PF | note |
|---|---|---|---|---|---|
| 1 | XAUUSD | 991002 | x | 3.92 | LIVE |
'@ | Set-Content "$fixture/DEMO_DEPLOYMENT_PLAN.md"
'' | Set-Content "$fixture/AGENT_TASKBOARD.md"
$csv = @'
account,ea_name,magic,symbol,type,status
159475669,ST_EA03 MACD,9398,USDCAD,REAL_CENT,REMOVED
159475669,Bars8,991002,XAUUSD,REAL_CENT,REMOVED
159503454,TrendlineBreakout,991002,XAUUSD,REAL_CENT,ACTIVE
123,PositiveControl,42,EURUSD,DEMO,ACTIVE
69424711,ClevrFX_EA,,EURUSD,DEMO,UNVERIFIED
'@
$csv | Set-Content "$fixture/portfolio/DEPLOYMENTS.csv"
$script:passed = 0
function Check($name, $condition) {
  if (-not $condition) { throw "FAIL: $name" }
  $script:passed++; Write-Host "PASS: $name"
}
function Generate {
  $saved = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { & "$fixture/scripts/make_status_html.ps1" -RepoRoot $fixture -IsPrimaryWorkspace $false 2>$null | Out-Null }
  finally { $ErrorActionPreference = $saved }
  return [IO.File]::ReadAllText("$fixture/STATUS.html")
}
$html = Generate
Check '9398 removed despite historical LIVE' ($html.Contains('data-magic="9398" data-status="REMOVED"') -and -not $html.Contains('data-magic="9398" data-status="ACTIVE"'))
Check 'Bars8 991002 removed despite historical LIVE' $html.Contains('data-account="159475669" data-magic="991002" data-status="REMOVED"')
Check '991002 other account positive preserved' $html.Contains('data-account="159503454" data-magic="991002" data-status="ACTIVE"')
Check 'current ACTIVE positive control' $html.Contains('data-magic="42" data-status="ACTIVE"')
Check 'unverified missing magic remains explicit' $html.Contains('data-account="69424711" data-magic="" data-status="UNVERIFIED"')
Check 'historical sections explicitly noncurrent' $html.Contains('Historical / REMOVED deployments (noncurrent)')
Check 'historical table never rendered' (-not $html.Contains('3.92') -and -not $html.Contains('2.62'))
Check 'no hardcoded current LIVE assertion' (-not $html.Contains('9 EA live') -and -not $html.Contains('Live portfolio'))
$expectedHash = (Get-FileHash "$fixture/portfolio/DEPLOYMENTS.csv" -Algorithm SHA256).Hash.ToLowerInvariant()
Check 'exact owner bytes bound' $html.Contains("portfolio/DEPLOYMENTS.csv SHA256 $expectedHash")
Check 'generation not observation' $html.Contains('generation time is not runtime observation time')
Check 'Git outranks generated copy' $html.Contains('Git canonical owners outrank this generated copy')
# An unavailable or ambiguous owner must never fall back to historical prose.
'account,ea_name,magic,symbol,type,status' | Set-Content "$fixture/portfolio/DEPLOYMENTS.csv"
$html = Generate
Check 'empty inventory unknown' ($html.Contains('UNKNOWN') -and -not $html.Contains('data-status='))
($csv + "`n159475669,Duplicate,9398,USDCAD,REAL_CENT,ACTIVE") | Set-Content "$fixture/portfolio/DEPLOYMENTS.csv"
$html = Generate
Check 'conflicting duplicate identity refuses all claims' ($html.Contains('UNKNOWN') -and -not $html.Contains('data-status='))
Write-Host "STATUS DEPLOYMENT AUTHORITY: $script:passed/13 PASS; fixture=$fixture"
