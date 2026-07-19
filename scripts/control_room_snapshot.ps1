<#
 control_room_snapshot.ps1 - CR-001a (ROADMAP Phase 4.5): ONE command -> ONE machine-readable
 picture of the whole system. READ-ONLY: reads DEPLOYMENTS.csv + live_deals collectors + artifact
 ages; writes ONLY portfolio\control_room_snapshot.json (a rebuildable read-only projection --
 NEVER a new owner; owners stay per PROJECT_STATE.md section 0.5).

 Sections:
   meta              schema/version, as-of, git HEAD, source file hashes
   system_health     per-account collector freshness (stale bar 30h, aligned with daily chain guard)
   deployments       inventory pass-through + gap lists (UNVERIFIED / missing kill_rule / judge_date)
   judge_readiness   per ACTIVE magic: closed-trade count vs the 30-trade decision bar
                     (CLAUDE.md demo->LIVE judge bar), days-to-judge, decision_capable flag
   summary           TODAY-style one-screen counts (also printed to console)

 Judge-readiness counting method (documented so numbers are reproducible):
   MT5: latest EA_LAB_deals_<acct>_*.csv per account (files are cumulative), closed trade =
        row with entry=1 and matching magic.
   MT4: latest EA_LAB_mt4_orders_<acct>_*.csv, closed trade = row with non-empty close_time
        and matching magic.
   No collector file for the account -> status DATA_INSUFFICIENT (missing sensor is a finding,
   not an error).
 ASCII-only on purpose (Windows PowerShell 5.1 reads scripts as ANSI).
#>
[CmdletBinding()]
param(
  [string]$Root = "",
  [string]$OutFile = ""
)
$ErrorActionPreference = 'Stop'
if ($Root -eq "") { $Root = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent }
$INV   = Join-Path $Root 'portfolio\DEPLOYMENTS.csv'
$DEALS = Join-Path $Root 'portfolio\live_deals'
$DASH  = Join-Path $Root 'portfolio\LIVE_DASHBOARD.html'
if ($OutFile -eq "") { $OutFile = Join-Path $Root 'portfolio\control_room_snapshot.json' }
$now = Get-Date

function FileMeta([string]$p){
  if (-not (Test-Path $p)) { return $null }
  $fi = Get-Item $p
  return [ordered]@{ path = $p.Replace($Root + '\','' ); sha256 = (Get-FileHash $p -Algorithm SHA256).Hash.ToLower(); mtime = $fi.LastWriteTime.ToString('s'); age_hours = [math]::Round(($now - $fi.LastWriteTime).TotalHours,1) }
}
function LatestCollector([string]$acct){
  $mt5 = @(Get-ChildItem $DEALS -Filter ("EA_LAB_deals_" + $acct + "_*.csv") -ErrorAction SilentlyContinue | Sort-Object Name)
  $mt4 = @(Get-ChildItem $DEALS -Filter ("EA_LAB_mt4_orders_" + $acct + "_*.csv") -ErrorAction SilentlyContinue | Sort-Object Name)
  if ($mt5.Count -gt 0) { return @{ kind='MT5'; file=$mt5[-1] } }
  if ($mt4.Count -gt 0) { return @{ kind='MT4'; file=$mt4[-1] } }
  return $null
}

# --- deployments (single source: DEPLOYMENTS.csv) ---
$rows = @(Import-Csv $INV)
$gapUnverified = @($rows | Where-Object { $_.status -match 'UNVERIFIED' })
$gapKill  = @($rows | Where-Object { $_.status -eq 'ACTIVE' -and (-not $_.kill_rule -or $_.kill_rule.Trim() -eq '') })
$gapJudge = @($rows | Where-Object { $_.status -eq 'ACTIVE' -and ($_.judge_date -notmatch '^\d{4}-\d{2}-\d{2}$') })

# --- system health: collector freshness per account in the inventory ---
$staleBarHours = 30
$accounts = @($rows | Select-Object -ExpandProperty account -Unique)
$health = @()
foreach($a in $accounts){
  $c = LatestCollector $a
  if ($null -eq $c) {
    $health += [ordered]@{ account=$a; collector='NONE'; state='NO_SENSOR'; latest_file=$null; age_hours=$null }
    continue
  }
  $age = [math]::Round(($now - $c.file.LastWriteTime).TotalHours,1)
  $state = 'FRESH'; if ($age -gt $staleBarHours) { $state = 'STALE' }
  $health += [ordered]@{ account=$a; collector=$c.kind; state=$state; latest_file=$c.file.Name; age_hours=$age }
}

# --- judge readiness per ACTIVE row with a magic ---
$decisionBar = 30   # CLAUDE.md judge bar: PF>=1.40 at >=30 trades
$watchBar    = 15   # CLAUDE.md demo-kill floor sample
$jr = @()
$dealCache = @{}
foreach($r in ($rows | Where-Object { $_.status -eq 'ACTIVE' -and $_.magic -match '^\d+$' })){
  $c = LatestCollector $r.account
  $trades = $null; $state = 'DATA_INSUFFICIENT'
  if ($null -ne $c) {
    $key = $c.file.FullName
    if (-not $dealCache.ContainsKey($key)) { $dealCache[$key] = @(Import-Csv $key) }
    $d = $dealCache[$key]
    if ($c.kind -eq 'MT5') { $trades = @($d | Where-Object { $_.magic -eq $r.magic -and $_.entry -eq '1' }).Count }
    else                   { $trades = @($d | Where-Object { $_.magic -eq $r.magic -and $_.close_time -and $_.close_time.Trim() -ne '' }).Count }
    if     ($trades -ge $decisionBar) { $state = 'DECISION_CAPABLE' }
    elseif ($trades -ge $watchBar)    { $state = 'PARTIAL' }
    else                              { $state = 'DATA_COLLECTION' }
  }
  $d2j = $null
  if ($r.judge_date -match '^\d{4}-\d{2}-\d{2}$') { $d2j = [int]([datetime]$r.judge_date - $now.Date).TotalDays }
  $jr += [ordered]@{ account=$r.account; magic=$r.magic; ea=$r.ea_name; symbol=$r.symbol; closed_trades=$trades; days_to_judge=$d2j; judge_date=$r.judge_date; readiness=$state }
}

# --- summary (TODAY block) ---
$freshN = @($health | Where-Object { $_.state -eq 'FRESH' }).Count
$sum = [ordered]@{
  accounts_total        = $accounts.Count
  accounts_fresh        = $freshN
  accounts_stale_or_no_sensor = $accounts.Count - $freshN
  deployments_total     = $rows.Count
  deployments_active    = @($rows | Where-Object { $_.status -eq 'ACTIVE' }).Count
  gaps_unverified       = $gapUnverified.Count
  gaps_missing_kill     = $gapKill.Count
  gaps_missing_judge    = $gapJudge.Count
  judge_decision_capable = @($jr | Where-Object { $_.readiness -eq 'DECISION_CAPABLE' }).Count
  judge_partial          = @($jr | Where-Object { $_.readiness -eq 'PARTIAL' }).Count
  judge_data_collection  = @($jr | Where-Object { $_.readiness -eq 'DATA_COLLECTION' }).Count
  judge_data_insufficient = @($jr | Where-Object { $_.readiness -eq 'DATA_INSUFFICIENT' }).Count
}

$snapshot = [ordered]@{
  meta = [ordered]@{
    schema  = 'ControlRoomSnapshot'
    version = 1
    generated_at = $now.ToString('s')
    git_head = (git -C $Root rev-parse --short HEAD 2>$null)
    stale_bar_hours = $staleBarHours
    decision_bar_trades = $decisionBar
    sources = @((FileMeta $INV), (FileMeta $DASH)) | Where-Object { $_ }
    counting_method = 'MT5: latest cumulative deals csv, entry=1 rows per magic. MT4: latest orders csv, non-empty close_time per magic.'
  }
  system_health   = $health
  deployments     = [ordered]@{
    rows = $rows
    gaps = [ordered]@{
      unverified   = @($gapUnverified | ForEach-Object { $_.account + '|' + $_.magic })
      missing_kill = @($gapKill  | ForEach-Object { $_.account + '|' + $_.magic })
      missing_judge= @($gapJudge | ForEach-Object { $_.account + '|' + $_.magic })
    }
  }
  judge_readiness = $jr
  summary         = $sum
}

$json = $snapshot | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($OutFile, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "=== CONTROL ROOM TODAY ($($now.ToString('yyyy-MM-dd HH:mm'))) ==="
Write-Host ("SYSTEM   {0}/{1} accounts fresh ({2} stale/no-sensor, bar {3}h)" -f $sum.accounts_fresh, $sum.accounts_total, $sum.accounts_stale_or_no_sensor, $staleBarHours)
Write-Host ("FLEET    {0} rows, {1} ACTIVE | gaps: {2} UNVERIFIED, {3} no-kill, {4} no-judge" -f $sum.deployments_total, $sum.deployments_active, $sum.gaps_unverified, $sum.gaps_missing_kill, $sum.gaps_missing_judge)
Write-Host ("JUDGE    {0} decision-capable | {1} partial | {2} collecting | {3} no-data" -f $sum.judge_decision_capable, $sum.judge_partial, $sum.judge_data_collection, $sum.judge_data_insufficient)
Write-Host ("OUTPUT   {0}" -f $OutFile)
