<#
 control_room_snapshot.ps1 - CR-001a (ROADMAP Phase 4.5): ONE command -> ONE machine-readable
 picture of the whole system. READ-ONLY: reads DEPLOYMENTS.csv + live_deals collectors + artifact
 ages; writes ONLY portfolio\control_room_snapshot.json (a rebuildable read-only projection --
 NEVER a new owner; owners stay per PROJECT_STATE.md section 0.5).

 Sections:
   meta              schema/version, as-of, git HEAD, source file hashes
   system_health     per-account collector freshness (stale bar 30h, aligned with daily chain guard)
   deployments       inventory pass-through + explicit operational/verification states
                     and gap lists (UNVERIFIED / missing kill_rule / judge_date)
   judge_readiness   per non-REMOVED deployment: closed-trade count vs the 30-trade decision bar
                     (CLAUDE.md demo->LIVE judge bar), days-to-judge, decision_capable flag,
                     observed vs needed trades/week (CR-005-lite vertical slice)
   judge_cohorts     per-judge-date rollup (2026-10-09 / 2026-10-16 cohorts): capable now,
                     projected capable/shortfall at judge date, no-sensor magics
   attestation       CR-002: per non-REMOVED deployment, sha256 of the APPROVED
                     bundle artifacts (.ex5 + locked .set) from portfolio\ATTESTATION_MAP.csv
                     (owner of deployment->bundle expectations) vs what is on disk in
                     _vps_deploy. States: HASHED / PARTIAL (a mapped artifact slot is empty,
                     e.g. ambiguous set lineage) / FILE_MISSING / NO_BUNDLE / NO_MAP.
                     LOCAL attestation only - hashes prove what the repo says was approved;
                     comparing against the VPS terminal needs a VPS-side step (user).
   floating_risk     CR-002c: per account, newest EA_LAB_snapshot_<acct> from AccountSnapshot
                     Exporter (equity/balance/margin_level/floating_pl + per-magic open lots/
                     float_pl/oldest age). state=BLIND (no file) / STALE (>26h) / FRESH.
   unknown_magics    CR-002: closed-deal magics present in collector CSVs but absent from
                     DEPLOYMENTS.csv for that account (any status) - candidate ghosts or
                     un-enumerated user EAs. magic 0 (manual) excluded.
                     age_class = ACTIVE (last close within 14d) / HISTORICAL (older) /
                     UNCLASSIFIED (last_seen unparseable - see ClassifyUnknownAge).
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
$ACCTS = Join-Path $Root 'portfolio\ACCOUNTS.csv'
$STATUS = Join-Path $Root 'scripts\lib\deployment_status.ps1'
if ($OutFile -eq "") { $OutFile = Join-Path $Root 'portfolio\control_room_snapshot.json' }
$now = Get-Date
# The repo's pinned interpreter (see .githooks/pre-commit). Named once so the two invocations
# below cannot drift onto different pythons.
$PY = Join-Path $Root 'tools\python312\python.exe'
if (-not (Test-Path $PY)) { throw "control_room_snapshot: $PY is missing -- the snapshot cannot be validated, so it will not be written." }
if (-not (Test-Path $STATUS)) { throw "control_room_snapshot: deployment status contract is missing: $STATUS" }
. $STATUS
. (Join-Path $Root 'scripts\lib\runtime_identity.ps1')

function SourceRow([string]$name, [string]$p, [bool]$mandatory){
  # ORDER-612 (S4). v5 source row. It carries BOTH identities and NO EVIDENCE.
  #   path      PHYSICAL identity - what gets hashed and stat-ed, and what a later reader resolves
  #   name      LOGICAL identity  - what meta.mandatory_sources enumerates and the reconciliation
  #                                 joins on, so a file RENAME does not read as a missing source
  #
  # read_ok / sha256 / mtime / age_hours / fresh are emitted as $null ON PURPOSE. They are DERIVED
  # from the file on disk by _triage\factory_os\snapshot_build.py, which REFUSES a builder claim
  # that contradicts the disk. This script therefore cannot assert evidence about a file it did
  # not read - which is precisely the document Codex audit 6 built and got accepted (every source
  # row pointed at a nonexistent drive with read_ok:true).
  #
  # v4 returned $null for a missing file and the caller filtered it out, so a missing source
  # VANISHED from the snapshot instead of being reported. The row is unconditional now: a file
  # that is not there comes back read_ok=false and earns MANDATORY_SOURCE_MISSING.
  return [ordered]@{
    name       = $name
    path       = $p.Replace($Root + '\','')
    mandatory  = $mandatory
    read_ok    = $null
    sha256     = $null
    mtime      = $null
    age_hours  = $null
    fresh      = $null
  }
}
function TryParseTradeTime([string]$s){
  # CR-002d: trade-time strings from MT5/MT4 reports look like "2026.05.07 07:12:09"
  # (dot-separated date). Normalize the date part to hyphens so [datetime]::TryParse
  # (culture-invariant enough for this fixed shape) can read it. Returns $null on any
  # unexpected shape - callers must treat $null as "could not classify" and stay safe.
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }
  $norm = $s.Trim() -replace '^(\d{4})\.(\d{2})\.(\d{2})','$1-$2-$3'
  $dt = [datetime]::MinValue
  if ([datetime]::TryParse($norm, [ref]$dt)) { return $dt }
  return $null
}
function ClassifyUnknownAge([string]$lastSeen, [datetime]$asOf, [int]$activeDays = 14){
  # Three-valued on purpose (2026-07-30, Stage 0B D5).
  #
  # This used to default to HISTORICAL and only promote to ACTIVE on a parseable recent
  # date, so an UNPARSEABLE last_seen landed in the quiet bucket. The comment at the call
  # site called that "the safer bucket (does not falsely raise an active unknown EA
  # alarm)". It is not safer: it silently converts "I cannot read this timestamp" into
  # "there is nothing here to look at", which is the difference between a finding and a
  # blind spot. An unreadable input is its own answer and gets its own bucket.
  #
  #   ACTIVE        parseable AND last close within $activeDays -> still trading
  #   HISTORICAL    parseable AND older than that               -> dormant / dead ghost
  #   UNCLASSIFIED  not parseable                               -> we do not know
  #
  # Lifted out of the unknown-magic loop so scripts\_test\run_monitor_integrity_tests.ps1
  # can drive it directly (this file cannot be dot-sourced -- loading it builds a snapshot).
  $dt = TryParseTradeTime $lastSeen
  if ($null -eq $dt) { return 'UNCLASSIFIED' }
  if (($asOf - $dt).TotalDays -le $activeDays) { return 'ACTIVE' }
  return 'HISTORICAL'
}
function LatestCollector([string]$acct){
  $mt5 = @(Get-ChildItem $DEALS -Filter ("EA_LAB_deals_" + $acct + "_*.csv") -ErrorAction SilentlyContinue | Sort-Object Name)
  $mt4 = @(Get-ChildItem $DEALS -Filter ("EA_LAB_mt4_orders_" + $acct + "_*.csv") -ErrorAction SilentlyContinue | Sort-Object Name)
  if ($mt5.Count -gt 0) { return @{ kind='MT5'; file=$mt5[-1] } }
  if ($mt4.Count -gt 0) { return @{ kind='MT4'; file=$mt4[-1] } }
  return $null
}

# --- deployments (single source: DEPLOYMENTS.csv) ---
$rows = @(Get-DeploymentMonitoringRows @(Import-Csv $INV))
$gapUnverified = @($rows | Where-Object { $_.verification_state -eq 'UNVERIFIED' })
$gapKill  = @($rows | Where-Object { $_.forward_observed -and (-not $_.kill_rule -or $_.kill_rule.Trim() -eq '') })
$gapJudge = @($rows | Where-Object { $_.forward_observed -and ($_.judge_date -notmatch '^\d{4}-\d{2}-\d{2}$') })

# --- system health: collector freshness per account in the inventory ---
$staleBarHours = 30
# CR-003b: account universe = union of portfolio\ACCOUNTS.csv (owner file for governance
# metadata) and DEPLOYMENTS.csv (so accounts pending their first deployment row, or
# deployments for an account not yet registered, both still show up). Falls back to the
# old DEPLOYMENTS-only behavior if ACCOUNTS.csv is missing (no crash).
$accountsFromDeployments = @($rows | Select-Object -ExpandProperty account -Unique)
$acctMeta = @{}
if (Test-Path $ACCTS) {
  $acctRows = @(Import-Csv $ACCTS)
  foreach($ar in $acctRows) { $acctMeta[$ar.account] = $ar }
  $accounts = @()
  $seenAcct = @{}
  foreach($a in ($acctRows | Select-Object -ExpandProperty account)) {
    if (-not $seenAcct.ContainsKey($a)) { $seenAcct[$a] = $true; $accounts += $a }
  }
  foreach($a in $accountsFromDeployments) {
    if (-not $seenAcct.ContainsKey($a)) { $seenAcct[$a] = $true; $accounts += $a }
  }
} else {
  $accounts = $accountsFromDeployments
}
# expected governance_scope values: LAB_MANAGED / USER_OBSERVED / ARCHIVED - anything else
# (typo, new value not yet documented) is passed through as-is rather than crashing.
$health = @()
foreach($a in $accounts){
  $scope = 'UNREGISTERED'
  if ($acctMeta.ContainsKey($a) -and $acctMeta[$a].governance_scope) { $scope = $acctMeta[$a].governance_scope }
  # unexpected values are kept as-is (not crashed on) - just noted, matching per CR-003b spec
  $c = LatestCollector $a
  if ($null -eq $c) {
    $health += [ordered]@{ account=$a; collector='NONE'; state='NO_SENSOR'; latest_file=$null; age_hours=$null; governance_scope=$scope }
    continue
  }
  $age = [math]::Round(($now - $c.file.LastWriteTime).TotalHours,1)
  $state = 'FRESH'; if ($age -gt $staleBarHours) { $state = 'STALE' }
  $health += [ordered]@{ account=$a; collector=$c.kind; state=$state; latest_file=$c.file.Name; age_hours=$age; governance_scope=$scope }
}

# --- CR-005-lite-b: expected-vs-actual reference (portfolio\expectations.csv is the owner of
# per-magic expected profile). We use it ONLY for a trade-RATE flag here (the cheapest, most
# actionable "has this EA gone silent?" signal) plus surfacing expected pf/dd95 for context.
# Live-PF-vs-band and DD-vs-dd95 comparison need per-magic profit summation and belong to the
# full CR-005 drift engine - deliberately NOT computed in this lite slice. Never touches the
# CLAUDE.md promotion bar (PF>=1.40 / >=30 trades / >=3 months) - advisory only.
$EXP = Join-Path $Root 'portfolio\expectations.csv'
$expMeta = @{}
if (Test-Path $EXP) { foreach($e in @(Import-Csv $EXP)) { $expMeta["$($e.account)|$($e.magic)"] = $e } }

# --- judge readiness per visible non-REMOVED row ---
$decisionBar = 30   # CLAUDE.md judge bar: PF>=1.40 at >=30 trades
$watchBar    = 15   # CLAUDE.md demo-kill floor sample
$jr = @()
$dealCache = @{}
foreach($r in ($rows | Where-Object { $_.operational_status -ne 'REMOVED' })){
  if ($r.magic -notmatch '^\d+$') {
    $jr += [ordered]@{ account=$r.account; magic=$r.magic; ea=$r.ea_name; symbol=$r.symbol; status=$r.status; operational_status=$r.operational_status; verification_state=$r.verification_state; forward_observed=$r.forward_observed; monitoring_visible=$r.monitoring_visible; attention=$r.attention; closed_trades=$null; days_active=$null; days_to_judge=$null; judge_date=$r.judge_date; readiness='NOT_MONITORABLE'; projected_trades_at_judge=$null; forecast='NOT_APPLICABLE'; obs_trades_per_week=$null; needed_trades_per_week=$null; expected_pf=$null; expected_dd95=$null; expected_trades_per_week=$null; rate_flag='NA' }
    continue
  }
  if (-not $r.forward_observed) {
    $jr += [ordered]@{ account=$r.account; magic=$r.magic; ea=$r.ea_name; symbol=$r.symbol; status=$r.status; operational_status=$r.operational_status; verification_state=$r.verification_state; forward_observed=$r.forward_observed; monitoring_visible=$r.monitoring_visible; attention=$r.attention; closed_trades=$null; days_active=$null; days_to_judge=$null; judge_date=$r.judge_date; readiness='NOT_FORWARD_OBSERVED'; projected_trades_at_judge=$null; forecast='NOT_APPLICABLE'; obs_trades_per_week=$null; needed_trades_per_week=$null; expected_pf=$null; expected_dd95=$null; expected_trades_per_week=$null; rate_flag='NA' }
    continue
  }
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
  # CR-005-lite forecast: project closed trades at judge_date from the observed rate since
  # start_date. Needs >=7 days of history to be meaningful; otherwise FORECAST_NA.
  $daysActive = $null
  if ($r.start_date -match '^\d{4}-\d{2}-\d{2}$') { $daysActive = [int]($now.Date - [datetime]$r.start_date).TotalDays }
  # observed weekly close rate only needs trades + >=7d history (NOT a judge_date), so it is
  # available for every deployment incl. non-cohort MT4 rows - the rate_flag below uses it.
  $obsWk = $null
  if ($null -ne $trades -and $null -ne $daysActive -and $daysActive -ge 7) { $obsWk = [math]::Round($trades * 7.0 / $daysActive, 1) }
  # forecast/projection additionally needs a judge_date (project trades AT the judge date).
  $proj = $null; $fstate = 'FORECAST_NA'
  if ($null -ne $obsWk -and $r.judge_date -match '^\d{4}-\d{2}-\d{2}$') {
    $daysTotal  = [int]([datetime]$r.judge_date - [datetime]$r.start_date).TotalDays
    if ($daysTotal -gt 0) {
      $proj = [int][math]::Round($trades * ($daysTotal / [double]$daysActive))
      if ($proj -ge $decisionBar) { $fstate = 'PROJECTED_CAPABLE' } else { $fstate = 'PROJECTED_SHORTFALL' }
    }
  }
  # vertical-slice extra: the weekly close rate this magic must sustain from TODAY to reach
  # the 30-trade decision bar by its judge date (null = already there / no judge date).
  $needWk = $null
  if ($null -ne $trades -and $null -ne $d2j -and $d2j -gt 0 -and $trades -lt $decisionBar) {
    $needWk = [math]::Round(($decisionBar - $trades) * 7.0 / $d2j, 1)
  }
  # CR-005-lite-b expected-vs-actual: attach expected profile + a trade-rate flag.
  # rate_flag = UNDER_RATE only when we have >=14d of history AND observed weekly close rate
  # is below half the expected rate (gone-quiet detector); ON_RATE when meeting it; NA otherwise
  # (too little history, no expectation row, or no numeric expected rate). Advisory only.
  $em = $expMeta["$($r.account)|$($r.magic)"]
  $expPf = $null; $expDd95 = $null; $expWk = $null; $rateFlag = 'NA'
  if ($null -ne $em) {
    $expPf   = $em.pf_expected
    $expDd95 = $em.dd95_expected
    $tpm = 0.0
    if ([double]::TryParse($em.trades_per_month_expected, [ref]$tpm) -and $tpm -gt 0) {
      $expWk = [math]::Round($tpm / 4.33, 1)
      if ($null -ne $obsWk -and $null -ne $daysActive -and $daysActive -ge 14) {
        if ($obsWk -lt (0.5 * $expWk)) { $rateFlag = 'UNDER_RATE' } else { $rateFlag = 'ON_RATE' }
      }
    }
  }
  $jr += [ordered]@{ account=$r.account; magic=$r.magic; ea=$r.ea_name; symbol=$r.symbol; status=$r.status; operational_status=$r.operational_status; verification_state=$r.verification_state; forward_observed=$r.forward_observed; monitoring_visible=$r.monitoring_visible; attention=$r.attention; closed_trades=$trades; days_active=$daysActive; days_to_judge=$d2j; judge_date=$r.judge_date; readiness=$state; projected_trades_at_judge=$proj; forecast=$fstate; obs_trades_per_week=$obsWk; needed_trades_per_week=$needWk; expected_pf=$expPf; expected_dd95=$expDd95; expected_trades_per_week=$expWk; rate_flag=$rateFlag }
}

# --- CR-005-lite vertical slice: per-judge-date cohort rollup ---
$cohorts = @()
foreach($g in ($jr | Where-Object { $_.forward_observed -and $_.magic -match '^\d+$' -and $_.judge_date -match '^\d{4}-\d{2}-\d{2}$' } | Group-Object { $_.judge_date } | Sort-Object Name)){
  $cg = @($g.Group)
  $noSensor = @($cg | Where-Object { $_.readiness -eq 'DATA_INSUFFICIENT' })
  $short    = @($cg | Where-Object { $_.forecast -eq 'PROJECTED_SHORTFALL' })
  $cohorts += [ordered]@{
    judge_date            = $g.Name
    days_to_judge         = ($cg | Select-Object -First 1).days_to_judge
    deployments           = $cg.Count
    decision_capable_now  = @($cg | Where-Object { $_.readiness -eq 'DECISION_CAPABLE' }).Count
    projected_capable     = @($cg | Where-Object { $_.forecast -eq 'PROJECTED_CAPABLE' }).Count
    projected_shortfall   = $short.Count
    no_sensor             = $noSensor.Count
    no_sensor_magics      = @($noSensor | ForEach-Object { "$($_.account)|$($_.magic)" })
    shortfall_detail      = @($short | ForEach-Object { "$($_.account)|$($_.magic) $($_.ea) $($_.symbol): $($_.closed_trades)t, obs $($_.obs_trades_per_week)/wk, needs $($_.needed_trades_per_week)/wk" })
  }
}

# --- CR-002 attestation: hash the APPROVED bundle artifacts per deployment ---
$ATT = Join-Path $Root 'portfolio\ATTESTATION_MAP.csv'
$gitTracked = @{}
foreach($f in @(git -C $Root ls-files 2>$null)) { $gitTracked[$f] = $true }
$attMap = @{}
if (Test-Path $ATT) { foreach($m in @(Import-Csv $ATT)) { $attMap["$($m.account)|$($m.magic)"] = $m } }
function ArtifactMeta([string]$bundleDir,[string]$fileName){
  if (-not $fileName) { return $null }
  $rel = ($bundleDir.TrimEnd('/')) + '/' + $fileName
  $p = Join-Path $Root ($rel -replace '/','\')
  if (-not (Test-Path $p)) { return [ordered]@{ file=$rel; sha256=$null; missing=$true; git_tracked=$false } }
  return [ordered]@{ file=$rel; sha256=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower(); missing=$false; git_tracked=[bool]$gitTracked[$rel] }
}
$attest = @()
foreach($r in ($rows | Where-Object { $_.operational_status -ne 'REMOVED' })){
  $key = "$($r.account)|$($r.magic)"
  $m = $attMap[$key]
  $state = 'NO_MAP'; $ex5 = $null; $set = $null; $conf = $null; $note = $null
  if ($null -ne $m) {
    $conf = $m.confidence; $note = $m.notes
    if (-not $m.bundle_dir) { $state = 'NO_BUNDLE' }
    else {
      $ex5 = ArtifactMeta $m.bundle_dir $m.ex5_file
      $set = ArtifactMeta $m.bundle_dir $m.set_file
      $state = 'HASHED'
      if (($null -ne $ex5 -and $ex5.missing) -or ($null -ne $set -and $set.missing)) { $state = 'FILE_MISSING' }
      elseif ($null -eq $ex5 -or $null -eq $set) { $state = 'PARTIAL' }   # a mapped slot is empty (e.g. ambiguous set)
    }
  }
  $attest += [ordered]@{ account=$r.account; magic=$r.magic; ea=$r.ea_name; status=$r.status; operational_status=$r.operational_status; verification_state=$r.verification_state; attention=$r.attention; state=$state; confidence=$conf; ex5=$ex5; set=$set; note=$note }
}
$attHashed = @($attest | Where-Object { $_.state -eq 'HASHED' -and $_.confidence -eq 'high' })
$attGaps   = @($attest | Where-Object { -not ($_.state -eq 'HASHED' -and $_.confidence -eq 'high') })

# --- CR-002 unknown-magic detection: collector magics absent from the inventory ---
$knownKeys = @{}
foreach($r in ($rows | Where-Object { $_.magic -match '^\d+$' })) { $knownKeys["$($r.account)|$($r.magic)"] = $true }
$unknown = @()
foreach($a in $accounts){
  $c = LatestCollector $a
  if ($null -eq $c) { continue }
  $key = $c.file.FullName
  if (-not $dealCache.ContainsKey($key)) { $dealCache[$key] = @(Import-Csv $key) }
  foreach($g in ($dealCache[$key] | Where-Object { $_.magic -match '^\d+$' -and $_.magic -ne '0' } | Group-Object magic)){
    if ($knownKeys.ContainsKey("$a|$($g.Name)")) { continue }
    if ($c.kind -eq 'MT5') { $t = @($g.Group | Where-Object { $_.entry -eq '1' }); $timeCol = 'time' }
    else                   { $t = @($g.Group | Where-Object { $_.close_time -and $_.close_time.Trim() -ne '' }); $timeCol = 'close_time' }
    if ($t.Count -eq 0) { continue }
    $times = @($t | ForEach-Object { $_.$timeCol } | Sort-Object)
    # CR-002d: ACTIVE = still trading recently (last close within 14d) vs HISTORICAL
    # (dormant/dead ghost magic) vs UNCLASSIFIED (last_seen could not be parsed - see
    # ClassifyUnknownAge for why that is NOT folded into HISTORICAL).
    $ageClass = ClassifyUnknownAge $times[-1] $now
    $unknown += [ordered]@{ account=$a; magic=$g.Name; closed_trades=$t.Count; first_seen=$times[0]; last_seen=$times[-1]; age_class=$ageClass; symbols=(@($g.Group | Select-Object -ExpandProperty symbol -Unique | Where-Object { $_ }) -join '+') }
  }
}

# --- CR-002c floating risk: newest EA_LAB_snapshot_<acct>_*.csv per account, written by
# AccountSnapshotExporter (tools\AccountSnapshot\AccountSnapshot_Core.mqh). Layout is one
# ACCOUNT row (login/equity/balance/margin/margin_level_pct, magic columns blank) plus one
# MAGIC row per magic with open positions/pendings (float_pl/open_lots/open_positions/
# oldest_open_hours). Stale bar mirrors collect_live_deals.ps1's snapshot guard (26h - the
# exporter rewrites every 60s while attached, so a few stale hours already means it's dead).
$floatStaleHours = 26
function LatestFloatSnapshot([string]$acct){
  $f = @(Get-ChildItem $DEALS -Filter ("EA_LAB_snapshot_" + $acct + "_*.csv") -ErrorAction SilentlyContinue | Sort-Object Name)
  if ($f.Count -eq 0) { return $null }
  return $f[-1]
}
$floating = @()
foreach($a in $accounts){
  $fsFile = LatestFloatSnapshot $a
  if ($null -eq $fsFile) {
    $floating += [ordered]@{ account=$a; state='BLIND'; age_hours=$null; equity=$null; balance=$null; margin_level=$null; floating_pl=$null; magics=@() }
    continue
  }
  $ageH = [math]::Round(($now - $fsFile.LastWriteTime).TotalHours,1)
  if ($ageH -gt $floatStaleHours) {
    $floating += [ordered]@{ account=$a; state='STALE'; age_hours=$ageH; equity=$null; balance=$null; margin_level=$null; floating_pl=$null; magics=@() }
    continue
  }
  try {
    $srows = @(Import-Csv $fsFile.FullName)
  } catch {
    # unreadable/corrupt csv - treat like BLIND rather than crashing the whole snapshot
    $floating += [ordered]@{ account=$a; state='BLIND'; age_hours=$ageH; equity=$null; balance=$null; margin_level=$null; floating_pl=$null; magics=@() }
    continue
  }
  $acctRow = $srows | Where-Object { $_.row_type -eq 'ACCOUNT' } | Select-Object -First 1
  if ($null -eq $acctRow) {
    $floating += [ordered]@{ account=$a; state='BLIND'; age_hours=$ageH; equity=$null; balance=$null; margin_level=$null; floating_pl=$null; magics=@() }
    continue
  }
  $eq = [double]$acctRow.equity; $bal = [double]$acctRow.balance
  # floating_pl derived from the ACCOUNT row's equity/balance (the row's own float_pl
  # column is blank by design - that field only carries a value on MAGIC/SYMBOL rows).
  $floatPl = [math]::Round($eq - $bal, 2)
  $magicRows = @($srows | Where-Object { $_.row_type -eq 'MAGIC' })
  $magics = @($magicRows | ForEach-Object {
    [ordered]@{ magic=$_.magic; floating_pl=[double]$_.float_pl; open_lots=[double]$_.open_lots; pos_count=[int]$_.open_positions; oldest_age_h=[double]$_.oldest_open_hours }
  })
  $floating += [ordered]@{ account=$a; state='FRESH'; age_hours=$ageH; equity=$eq; balance=$bal; margin_level=[double]$acctRow.margin_level_pct; floating_pl=$floatPl; magics=$magics }
}

# --- summary (TODAY block) ---
$freshN = @($health | Where-Object { $_.state -eq 'FRESH' }).Count
$sum = [ordered]@{
  accounts_total        = $accounts.Count
  accounts_fresh        = $freshN
  accounts_stale_or_no_sensor = $accounts.Count - $freshN
  deployments_total     = $rows.Count
  deployments_active    = @($rows | Where-Object { $_.status -eq 'ACTIVE' }).Count
  deployments_forward_observed = @($rows | Where-Object { $_.forward_observed }).Count
  deployments_pending_verification = @($rows | Where-Object { $_.verification_state -eq 'PENDING' }).Count
  deployments_unverified = @($rows | Where-Object { $_.verification_state -eq 'UNVERIFIED' }).Count
  gaps_unverified       = $gapUnverified.Count
  gaps_missing_kill     = $gapKill.Count
  gaps_missing_judge    = $gapJudge.Count
  judge_decision_capable = @($jr | Where-Object { $_.readiness -eq 'DECISION_CAPABLE' }).Count
  judge_partial          = @($jr | Where-Object { $_.readiness -eq 'PARTIAL' }).Count
  judge_data_collection  = @($jr | Where-Object { $_.readiness -eq 'DATA_COLLECTION' }).Count
  judge_data_insufficient = @($jr | Where-Object { $_.readiness -eq 'DATA_INSUFFICIENT' }).Count
  judge_projected_capable   = @($jr | Where-Object { $_.forecast -eq 'PROJECTED_CAPABLE' }).Count
  judge_projected_shortfall = @($jr | Where-Object { $_.forecast -eq 'PROJECTED_SHORTFALL' }).Count
  attestation_ok            = $attHashed.Count
  attestation_gaps          = $attGaps.Count
  unknown_magics            = $unknown.Count
  unknown_magics_active     = @($unknown | Where-Object { $_.age_class -eq 'ACTIVE' }).Count
  unknown_magics_historical = @($unknown | Where-Object { $_.age_class -eq 'HISTORICAL' }).Count
  # A non-zero value here means the collector wrote a last_seen this script cannot read.
  # It is deliberately NOT added into either of the two counters above: folding it into
  # historical is the exact defect this counter exists to make impossible to repeat.
  unknown_magics_unclassified = @($unknown | Where-Object { $_.age_class -eq 'UNCLASSIFIED' }).Count
  accounts_floating_blind   = @($floating | Where-Object { $_.state -ne 'FRESH' }).Count
  judge_under_rate          = @($jr | Where-Object { $_.rate_flag -eq 'UNDER_RATE' }).Count
}

# Runtime identity is a separate trust domain from config fingerprint and from the
# deployment-status vocabulary. The validator annotates each collected sidecar; an empty
# collection is an explicit LEGACY_UNVERIFIED result, never an all-clear default.
$runtimeRecordsRaw = @(Get-RuntimeIdentityRecords -DealsRoot $DEALS)
$runtimeValidation = Get-RuntimeIdentityValidation -RepoRoot $Root -Records $runtimeRecordsRaw
$runtimeIdentity = if ($null -eq $runtimeValidation.identity) { @() } else { @($runtimeValidation.identity) }
$runtimeIdentitySummary = [ordered]@{
  state = "$($runtimeValidation.state)"
  records = $runtimeIdentity.Count
  # `identity_findings` is transient builder input. snapshot_validator renames it to the
  # persisted `reasons` field after computing the document, so the recursive verdict-key
  # refusal cannot mistake this derived identity detail for a supplied reconciliation answer.
  identity_findings = @($runtimeValidation.reasons)
}

$snapshot = [ordered]@{
  entity = 'SnapshotBuilderInput'
  meta = [ordered]@{
    schema  = 'ControlRoomSnapshot'
    # v4 (Stage 0B D5, 2026-07-30): unknown_magics[].age_class gains a third value
    # UNCLASSIFIED (last_seen unparseable), and summary gains unknown_magics_unclassified.
    # ADDITIVE in the same sense the earlier bumps were - no field removed, no field
    # renamed - but note the widened ENUM: a v3 reader that switches on age_class and
    # assumes exactly {ACTIVE, HISTORICAL} will fall through on the new value. That is
    # the intended failure direction: falling through is visible, and the alternative
    # (keeping unreadable rows labelled HISTORICAL) is the defect being fixed.
    # v3 (CR-003b/002c/002d/005-lite-b): +governance_scope, +floating_risk, +unknown age_class, +judge rate_flag/expected_*.
    # v5 (ORDER-612 / S4, 2026-07-31): this script no longer writes the snapshot. It writes a
    # SnapshotBuilderInput, and _triage\factory_os\snapshot_build.py derives the source evidence
    # from disk, computes the verdict, validates against ControlRoomSnapshotV5 and replaces the
    # canonical file atomically. New in v5: root `entity` + `verdict`, meta.build_id +
    # mandatory_sources + reconciliation, and source rows carrying name/mandatory/read_ok/fresh.
    # v4 is NOT reused: v4 is a different, incompatible shape that shipped, and two shapes sharing
    # a version number is how a reader picks the wrong parser.
    version = 5
    generated_at = $now.ToString('s')
    git_head = (git -C $Root rev-parse --short HEAD 2>$null)
    stale_bar_hours = $staleBarHours
    decision_bar_trades = $decisionBar
    runtime_identity_required = $true
    # The REGISTRY of what must be present, by LOGICAL name, kept separate from what was
    # discovered. Without it a missing source is indistinguishable from one never expected --
    # which is how the original reconciliation satisfied its equation with 0 == 0.
    mandatory_sources = @('deployments_inventory','live_dashboard','attestation_map')
    sources = @(
      (SourceRow 'deployments_inventory' $INV  $true),
      (SourceRow 'live_dashboard'        $DASH $true),
      (SourceRow 'attestation_map'       $ATT  $true)
    )
    # meta.reconciliation is DELIBERATELY ABSENT. snapshot_build.py derives it from the two
    # taskboards and factory/coverage.jsonl and fills it in. This script does not compute it, does
    # not carry it, and therefore CANNOT misstate it -- which is stronger than computing it here
    # and having the builder check the answer. Found by probing the first version of this pipeline
    # (ORDER-612 round 1): the source rows were authenticated and the counts were accepted on
    # trust, so an all-zero claim produced reconciliation_clear=true.
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
  judge_cohorts   = $cohorts
  attestation     = $attest
  unknown_magics  = $unknown
  floating_risk   = $floating
  runtime_identity_summary = $runtimeIdentitySummary
  summary         = $sum
}
if ($runtimeIdentity.Count -gt 0) { $snapshot.runtime_identity = $runtimeIdentity }

# --- ORDER-612 (S4) build->validate->replace. This script never writes $OutFile itself. -------
# The builder input goes to a sibling temp file; snapshot_build.py derives the evidence, computes
# the verdict, validates against ControlRoomSnapshotV5, and only then os.replace()s the canonical
# path. If ANY of that fails, $OutFile is left byte-for-byte unchanged and this script exits
# non-zero. A half-migrated snapshot is the one outcome the order forbids outright.
# INVOCATION-UNIQUE. A blind audit ran two snapshot builds against the same -OutFile and
# reproduced a JSON decode error, a missing file and a WriteAllText sharing violation, because both
# used this one fixed name. The daily monitor chain and a manual run can overlap on this machine.
$builderTmp = Join-Path (Split-Path $OutFile -Parent) (".control_room_builder_input.$PID." + [guid]::NewGuid().ToString('N').Substring(0,8) + '.json')
$json = $snapshot | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($builderTmp, $json, (New-Object System.Text.UTF8Encoding($false)))
try {
  & $PY (Join-Path $Root '_triage\factory_os\snapshot_build.py') build $builderTmp $OutFile
  $buildRc = $LASTEXITCODE
} finally {
  Remove-Item $builderTmp -ErrorAction SilentlyContinue
}
if ($buildRc -ne 0) {
  throw "control_room_snapshot: snapshot_build.py refused this build (exit $buildRc). $OutFile was NOT replaced and still holds the previous validated snapshot."
}

Write-Host "=== CONTROL ROOM TODAY ($($now.ToString('yyyy-MM-dd HH:mm'))) ==="
Write-Host ("SYSTEM   {0}/{1} accounts fresh ({2} stale/no-sensor, bar {3}h)" -f $sum.accounts_fresh, $sum.accounts_total, $sum.accounts_stale_or_no_sensor, $staleBarHours)
Write-Host ("FLEET    {0} rows, {1} ACTIVE, {2} forward-observed | verification: {3} pending, {4} UNVERIFIED | gaps: {5} no-kill, {6} no-judge" -f $sum.deployments_total, $sum.deployments_active, $sum.deployments_forward_observed, $sum.deployments_pending_verification, $sum.deployments_unverified, $sum.gaps_missing_kill, $sum.gaps_missing_judge)
Write-Host ("JUDGE    {0} decision-capable | {1} partial | {2} collecting | {3} no-data" -f $sum.judge_decision_capable, $sum.judge_partial, $sum.judge_data_collection, $sum.judge_data_insufficient)
Write-Host ("FORECAST {0} projected-capable at judge date | {1} projected SHORTFALL (<30 trades)" -f $sum.judge_projected_capable, $sum.judge_projected_shortfall)
Write-Host ("RATE     {0} magic(s) UNDER_RATE (obs weekly closes < 50% of expectations.csv, >=14d history)" -f $sum.judge_under_rate)
foreach($cRoll in $cohorts){
  Write-Host ("COHORT   judge {0} ({1}d): {2} EAs | capable-now {3} | proj-capable {4} | proj-shortfall {5} | no-sensor {6}" -f $cRoll.judge_date, $cRoll.days_to_judge, $cRoll.deployments, $cRoll.decision_capable_now, $cRoll.projected_capable, $cRoll.projected_shortfall, $cRoll.no_sensor)
}
Write-Host ("ATTEST   {0} fully hashed (high-confidence) | {1} gaps (NO_BUNDLE/PARTIAL/FILE_MISSING/low-conf)" -f $sum.attestation_ok, $sum.attestation_gaps)
Write-Host ("UNKNOWN  {0} collector magic(s) not in DEPLOYMENTS.csv ({1} active, {2} historical, {3} unclassified)" -f $sum.unknown_magics, $sum.unknown_magics_active, $sum.unknown_magics_historical, $sum.unknown_magics_unclassified)
if ($sum.unknown_magics_unclassified -gt 0) {
  # Printed on its own line, in red, because the whole point of the UNCLASSIFIED bucket is
  # that it must not be absorbed into a count someone reads past.
  Write-Host ("UNKNOWN  !! {0} magic(s) UNCLASSIFIED - last_seen could not be parsed, so age is UNKNOWN, not 'historical': {1}" -f $sum.unknown_magics_unclassified, ((@($unknown | Where-Object { $_.age_class -eq 'UNCLASSIFIED' } | ForEach-Object { "$($_.account)|$($_.magic) last_seen='$($_.last_seen)'" })) -join '; ')) -ForegroundColor Red
}
Write-Host ("FLOATING {0}/{1} account(s) blind (no/stale AccountSnapshotExporter data)" -f $sum.accounts_floating_blind, $sum.accounts_total)
Write-Host ("OUTPUT   {0}" -f $OutFile)
