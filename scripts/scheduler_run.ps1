<#
scheduler_run.ps1 - ORDER-1080 (slice S9). The DISPATCHER half of the recoverable, idempotent
scheduler. design 6.5 / 3.3 (= 20.8 Contract B).

WHAT THIS IS. A wrapper around scripts\mt5_run.ps1, never a replacement. mt5_run.ps1 keeps
everything it already owns - its own abort when an instance of this install is alive, the 1:N
leverage assertion and post-run check, the input-cache warning, the D3 stale-report clear, the
truncation sidecar. This script adds the one thing that runner cannot own: MEMORY ACROSS ITS OWN
DEATH. It observes, it dispatches, it appends. It decides NOTHING.

WHERE THE DECISIONS ARE. Every one is in _triage\factory_os\scheduler.py, which is pure and has
no clock, no process and no terminal. This file gathers the same observation set every iteration,
hands it to `scheduler.py plan`, and executes the ONE action that comes back. A resume loop split
across two languages is a resume loop with two state machines, and the second is always the one
nobody tests -- so run_scheduler_tests.py PART 4 asserts the switch below handles EXACTLY the
closed action set plan() can emit. A tenth action added to the planner reddens that cage; it does
not make this script silently stall.

WHY THE WORKER IS A SEPARATE PROCESS. mt5_run.ps1 blocks until the report appears, so a scheduler
that called it inline would hold no observable state for the minutes it takes - and a crash in
that window is the exact case the slice exists for. The worker is this same script re-invoked with
-WorkerMode; it writes its exit code and a stdout tail to a per-attempt sidecar. That sidecar
SURVIVES this process, which is what lets the freshness gate still have both of its halves (an
accepted exit code AND a report written after the run started) after a crash.

TWO MARKERS, BECAUSE ONE CANNOT ANSWER THE QUESTION. The spawn marker is written BEFORE
Start-Process, so its absence proves this attempt was never spawned and a launch is safe. The exit
sidecar is written by the worker at the end. Between them, "never started", "still running" and
"died writing nothing" are three distinguishable states rather than one ambiguous one. The
enumerated kill matrix found that hole: without the spawn marker the planner relaunched a dead
attempt IN PLACE, invisible in the manifest and unbounded by the attempt cap.

PROHIBITIONS HONOURED (design section 10, verbatim): no process kill, no -Force, no change to
tester safety. There is no Stop-Process and no .Kill() in this file, and PART 4 greps for both.

USAGE
  powershell -NoProfile -File scripts\scheduler_run.ps1 -Run RUN-20260802-001 `
      -Cell "B14-H01-r1/XAUUSD/H1/SMOKE" -KeyFile <execution_key.json> -SetFile <full.set> `
      -ReportName S9_SMOKE_001
  Queue it first with `scheduler.py queue` (that is where criterion 3 refuses a duplicate).
ASCII only (PS 5.1 reads a BOM-less .ps1 as ANSI).
#>
[CmdletBinding()]
param(
  [string]$Run,
  [string]$Cell,
  [string]$KeyFile,
  [string]$SetFile = '',
  [string]$ReportName,
  # The repo-relative path the evidence event points at. It DEFAULTS to the report the runner
  # wrote, and that default cannot succeed: `_mt5_auto/reports/` is gitignored (.gitignore:70) and
  # the manifest records committed Git artifacts only (design 4.5). So the real value is a
  # committed COPY, and the default is left pointing at the truth rather than at something that
  # happens to work -- the utility's refusal is then a correct answer, not a puzzle.
  [string]$EvidencePath = '',
  [string]$Terminal = 'D:\Meta 5\terminal64.exe',
  [string]$DataDir  = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
  [int]$PollSeconds = 5,
  [int]$MaxIterations = 4000,
  [int]$LeaseMinutes = 240,
  # -WorkerMode is the re-invocation that owns ONE tester run. It is not a user-facing switch.
  [switch]$WorkerMode,
  [int]$Attempt = 1
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$py   = Join-Path $root 'tools\python312\python.exe'
$sched = Join-Path $root '_triage\factory_os\scheduler.py'
$runsDir  = Join-Path $root 'factory\runs'
$leaseDir = Join-Path $root 'factory\leases'
# Written without -Force deliberately. design section 10's prohibition names -Force, and the
# cage greps for it; a directory-create is not what that prohibition is about, but a file whose
# compliance depends on the reader knowing which -Force was meant is a file that will be edited
# wrongly later. There is no -Force anywhere in this script, and no Remove-Item either: a
# scheduler that deletes is a scheduler that can lose the evidence it exists to protect.
foreach ($d in @($runsDir, $leaseDir)) {
  if (-not (Test-Path $d)) { New-Item -ItemType Directory $d | Out-Null }
}

# The shared report-freshness gate. run_report_freshness_tests PART 5 refuses any script that
# calls a runner and then reads a report without it, and parity_run.ps1 paid that toll on its
# first commit. It is not a formality here: "the .htm exists" is precisely the inference a
# RESUMING scheduler is most likely to make and least able to check by hand.
. (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')

function Now-Stamp { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
function Stamp([datetime]$d) { $d.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
function Say([string]$m, [string]$c = 'Gray') { Write-Host ("   " + $m) -ForegroundColor $c }

$key = Get-Content -LiteralPath $KeyFile -Raw | ConvertFrom-Json
$laneTag  = ($key.lane -replace '[^A-Za-z0-9]', '_')
$leaseFile = Join-Path $leaseDir ($laneTag + '.json')
$htm = Join-Path $root ('_mt5_auto\reports\' + $ReportName + '.htm')
function Spawn-Marker([int]$a) { Join-Path $runsDir ($Run + '.a' + $a + '.spawn.json') }
function Exit-Sidecar([int]$a)  { Join-Path $runsDir ($Run + '.a' + $a + '.exit.json') }

# =================================================================================================
# WORKER MODE - owns exactly one tester run and one sidecar. No scheduler state is touched here.
# =================================================================================================
if ($WorkerMode) {
  $out = ''
  $code = -1
  try {
    $out = & (Join-Path $PSScriptRoot 'mt5_run.ps1') -Expert $key.expert -Symbol $key.symbol `
             -Period $key.tf -FromDate $key.from_date -ToDate $key.to_date -SetFile $SetFile `
             -Model ([int]$key.model) -Deposit ([int]$key.deposit) `
             -Leverage ([int]$key.leverage) -ReportName $ReportName -Terminal $Terminal `
             -DataDir $DataDir 2>&1 | Out-String
    $code = $LASTEXITCODE
  } catch {
    $out = "worker exception: $_"
    $code = -1
  }
  # PERSISTED IMMEDIATELY ON RECEIPT, which is what schemas.json says about exit_code: the
  # freshness guard needs 0/3 and cannot reconstruct it. The stdout tail travels with it because
  # mt5_run.ps1's TIMEOUT path exits 1 exactly like an ordinary no-report failure, and only its
  # text distinguishes them.
  $tail = $out
  if ($tail.Length -gt 2000) { $tail = $tail.Substring($tail.Length - 2000) }
  [PSCustomObject]@{ exit_code = $code; at = (Now-Stamp); stdout_tail = $tail } |
    ConvertTo-Json | Set-Content -LiteralPath (Exit-Sidecar $Attempt) -Encoding UTF8
  exit 0
}

# =================================================================================================
# OBSERVE - the SAME set every iteration, unconditionally. A driver that chose which observations
# to take would be making the decision the planner exists to own.
# =================================================================================================
function Get-Observation([int]$attempt) {
  $lease = $null
  if (Test-Path $leaseFile) {
    $lease = Get-Content -LiteralPath $leaseFile -Raw | ConvertFrom-Json
  }
  $spawn = $null
  if (Test-Path (Spawn-Marker $attempt)) {
    $spawn = Get-Content -LiteralPath (Spawn-Marker $attempt) -Raw | ConvertFrom-Json
  }
  $childRunning = $false
  if ($spawn -and $spawn.pid) {
    $p = Get-Process -Id ([int]$spawn.pid) -ErrorAction SilentlyContinue
    # A pid alone is not identity - Windows reuses them. The start time pins it to the process we
    # actually spawned, so an unrelated program that inherited the number cannot read as our
    # worker still being alive.
    if ($p -and (Stamp $p.StartTime) -eq $spawn.started_at) { $childRunning = $true }
  }
  $termPath = (Resolve-Path $Terminal -ErrorAction SilentlyContinue).Path
  $testerRunning = [bool](Get-Process terminal64 -ErrorAction SilentlyContinue |
                          Where-Object { $_.Path -eq $termPath })

  $exitRec = $null; $fresh = $null; $mtime = $null
  if (Test-Path (Exit-Sidecar $attempt)) {
    $exitRec = Get-Content -LiteralPath (Exit-Sidecar $attempt) -Raw | ConvertFrom-Json
    $runStart = if ($spawn) { [datetime]::Parse($spawn.launch_intent_at).ToUniversalTime() } else { [datetime]'1970-01-01' }
    $fresh = [bool](Test-ReportIsFresh -Htm $htm -RunStart $runStart -RunnerExit ([int]$exitRec.exit_code) -Label $ReportName -Quiet)
    if (Test-Path $htm) { $mtime = Stamp (Get-Item $htm).LastWriteTimeUtc }
  }
  # THE EVENT-STORE RECONCILE, and it is a real read rather than a remembered flag. The evidence
  # id is content-addressed (evd_sha256_<sha256 of the artifact>), so after a crash the store can
  # be asked whether THIS report's evidence already landed - which is the only way "duplicates no
  # event" survives a death between the store append and the manifest line.
  $evidence = $null
  if (Test-Path $htm) {
    $sha = (Get-FileHash -LiteralPath $htm -Algorithm SHA256).Hash.ToLower()
    $evId = 'evd_sha256_' + $sha
    $man = Join-Path $root 'docs\memory_control\experiment_events\evidence-manifest.jsonl'
    if (Test-Path $man) {
      $found = Select-String -LiteralPath $man -SimpleMatch $evId -List
      if ($found) { $evidence = @{ event_id = $evId; evidence_id = $evId } }
    }
  }
  return @{
    now            = (Now-Stamp)
    lease          = $lease
    child_running  = $childRunning
    tester_running = $testerRunning
    spawn_marker   = [bool]$spawn
    exit_record    = $exitRec
    report_fresh   = $fresh
    report_path    = ('_mt5_auto/reports/' + $ReportName + '.htm')
    report_mtime   = $mtime
    evidence       = $evidence
  }
}

# =================================================================================================
# THE TWO CALLS INTO THE PLANNER. JSON travels by FILE in both directions - PS 5.1 re-parses a
# quoted argument on its way to a native process, and a JSON object that survives one shape of
# quoting loses its quotes in another.
# =================================================================================================
$tmp = Join-Path $env:TEMP ('sched_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory $tmp | Out-Null

function Invoke-Plan($obs) {
  $f = Join-Path $tmp 'obs.json'
  ($obs | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $f -Encoding UTF8
  $raw = & $py $sched plan "--run=$Run" "--obs-file=$f" "--root=$root"
  return ($raw | ConvertFrom-Json)
}

function Invoke-Append($line) {
  $f = Join-Path $tmp 'line.json'
  ($line | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $f -Encoding UTF8
  $raw = & $py $sched append "--run=$Run" "--line-file=$f" "--root=$root"
  if ($LASTEXITCODE -ne 0) {
    # The validator refused the line this script proposed. That is a defect in the DISPATCHER, not
    # a scheduling outcome, and the two must never share an exit path: a resume that treated an
    # invalid line as a failed attempt would retry into the same invalid line forever.
    Write-Host ("[BUG] the monotonic validator refused a line this dispatcher built: " + $raw) -ForegroundColor Red
    exit 2
  }
  Say ("appended " + $line.transition + " (attempt " + $line.attempt + ")") 'DarkGray'
}

function New-Line([string]$transition, [int]$attempt, $record) {
  $at = Now-Stamp
  $line = [ordered]@{ entity = 'RunTransition'; run_id = $Run; cell_id = $Cell
                      attempt = $attempt; transition = $transition; at = $at }
  if ($record) {
    $record['attempt'] = $attempt; $record['transition'] = $transition; $record['at'] = $at
    $line['record'] = $record
  }
  return $line
}

# =================================================================================================
# THE LOOP. Dispatch only - every branch performs one effect and appends what the planner named.
# =================================================================================================
Write-Host (">> scheduler " + $Run + " on lane " + $key.lane) -ForegroundColor Cyan
for ($i = 0; $i -lt $MaxIterations; $i++) {
  $journalRaw = & $py $sched journal "--run=$Run" "--root=$root"
  $journal = $journalRaw | ConvertFrom-Json
  if (-not $journal.attempts) {
    Write-Host "[REFUSE] no manifest for $Run - queue it first (that is where criterion 3 lives)." -ForegroundColor Red
    exit 1
  }
  $attempt = ($journal.attempts | Select-Object -Last 1).attempt
  $act = Invoke-Plan (Get-Observation $attempt)
  Say ($act.action + " - " + $act.why)
  $a = if ($act.attempt) { [int]$act.attempt } else { [int]$attempt }

  switch ($act.action) {
    'ACQUIRE_LEASE' {
      $lease = [ordered]@{ lease_id = ('L-' + $Run + '-' + $a); owner = $Run
                           expires_at = (Stamp (Get-Date).AddMinutes($LeaseMinutes)) }
      ($lease | ConvertTo-Json) | Set-Content -LiteralPath $leaseFile -Encoding UTF8
      Invoke-Append (New-Line 'LEASED' $a @{ lease = $lease })
    }
    'ADOPT_LEASE' {
      $lease = Get-Content -LiteralPath $leaseFile -Raw | ConvertFrom-Json
      Invoke-Append (New-Line 'LEASED' $a @{ lease = @{ lease_id = $lease.lease_id
                                                        owner = $lease.owner
                                                        expires_at = $lease.expires_at } })
    }
    'DECLARE_LAUNCH_INTENT' {
      Invoke-Append (New-Line 'LAUNCH_INTENT' $a @{ launch_intent_at = (Now-Stamp) })
    }
    'LAUNCH' {
      # THE MARKER IS WRITTEN FIRST, and the order is the whole point: absence of the marker is
      # the only proof that no spawn happened. The residual window - marker written, spawn
      # refused - fails SAFE, into FAILED(KILLED) and a fresh attempt, never a silent relaunch.
      $intent = ($journal.attempts | Where-Object { $_.attempt -eq $a -and $_.launch_intent_at } |
                 Select-Object -Last 1).launch_intent_at
      # 🔴 EVERY PATH IS QUOTED, and the variable is not called $args. The first wiring run on a
      # real lane failed three attempts in a row this way: `-ArgumentList` joins an array with
      # SPACES and quotes nothing, so `-Terminal D:\Meta 5\terminal64.exe` reached the worker as
      # two arguments, PowerShell refused to bind them, and the worker died before it could write
      # the sidecar that says why. The state machine handled it exactly right -- three
      # RECONCILE_ORPHAN(KILLED) records and then ATTEMPTS_EXHAUSTED -- which is how the defect
      # was legible at all, but it was a defect in THIS file. ($args is also an automatic
      # variable; assigning to it is asking for the second bug on top of the first.)
      $wargs = @('-NoProfile', '-ExecutionPolicy', 'Bypass',
                 '-File', ('"' + $PSCommandPath + '"'), '-WorkerMode',
                 '-Run', $Run, '-Cell', ('"' + $Cell + '"'), '-KeyFile', ('"' + $KeyFile + '"'),
                 '-SetFile', ('"' + $SetFile + '"'), '-ReportName', $ReportName,
                 '-Terminal', ('"' + $Terminal + '"'), '-DataDir', ('"' + $DataDir + '"'),
                 '-Attempt', $a)
      # A worker that dies BEFORE its sidecar exists leaves nothing to read, and "it was killed"
      # is then the only honest reading available to the planner. These two transcripts are what
      # turn that correct-but-opaque verdict into a diagnosable one.
      $wout = Join-Path $runsDir ($Run + '.a' + $a + '.worker.out.log')
      $werr = Join-Path $runsDir ($Run + '.a' + $a + '.worker.err.log')
      $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $wargs -PassThru `
                -NoNewWindow -RedirectStandardOutput $wout -RedirectStandardError $werr
      [PSCustomObject]@{ pid = $proc.Id; started_at = (Stamp $proc.StartTime)
                         launch_intent_at = $intent; at = (Now-Stamp) } |
        ConvertTo-Json | Set-Content -LiteralPath (Spawn-Marker $a) -Encoding UTF8
      Say ("worker pid " + $proc.Id) 'DarkGray'
    }
    'ADOPT_PROCESS' {
      $spawn = $null
      if (Test-Path (Spawn-Marker $a)) { $spawn = Get-Content -LiteralPath (Spawn-Marker $a) -Raw | ConvertFrom-Json }
      $pidVal = if ($spawn) { [int]$spawn.pid } else { 0 }
      Invoke-Append (New-Line 'PROCESS_OBSERVED' $a @{
        process_observed = @{ pid = $pidVal; observed_at = (Now-Stamp)
                              process_fingerprint = $key.lane } })
    }
    'OBSERVE_RUNNING' { Invoke-Append (New-Line 'RUNNING' $a $null) }
    'WAIT'            { Start-Sleep -Seconds $PollSeconds }
    'RECORD_COMPLETED' {
      Invoke-Append (New-Line 'COMPLETED' $a @{
        exit_code = [int]$act.exit_code; failure_class = 'NONE'
        report_fresh_proof = @{ fresh = $true; runner_exit = [int]$act.proof.runner_exit
                                report_path = $act.proof.report_path
                                report_mtime = $act.proof.report_mtime
                                run_start = $act.proof.run_start } })
    }
    'RECORD_FAILED' {
      $ec = $null; if ($null -ne $act.exit_code) { $ec = [int]$act.exit_code }
      Invoke-Append (New-Line 'FAILED' $a @{ exit_code = $ec; failure_class = $act.failure_class })
    }
    'RECONCILE_ORPHAN' {
      Invoke-Append (New-Line 'FAILED' $a @{ exit_code = $null; failure_class = $act.failure_class })
    }
    'REGISTER_EVIDENCE' {
      # Through the EXISTING utility and into the EXISTING manifest - design 4.5 is explicit that
      # no parallel evidence store exists. It is content-addressed and therefore idempotent on its
      # own; this script's reconcile is the first guard, not the only one.
      $rel = if ($EvidencePath) { $EvidencePath } else { '_mt5_auto/reports/' + $ReportName + '.htm' }
      # 6>&1 is load-bearing (ORDER-219, memory writehost-stream6-swallows-detail): Write-Host
      # goes to the INFORMATION stream in PS 5.0+, so `2>&1 | Out-String` alone captured NOTHING
      # and this branch printed an empty reason next to a sentence guessing at the cause.
      $res = & (Join-Path $PSScriptRoot 'experiment_event_log.ps1') -Command RegisterEvidence `
                -RepoRoot $root -RegisterEvidencePath $rel -RegisterEvidenceCommitOid HEAD `
                -RegisterEvidenceMediaType 'text/html' 2>&1 6>&1 | Out-String
      $rc = $LASTEXITCODE
      if ($rc -ne 0) {
        # QUOTE THE UTILITY, DO NOT EXPLAIN IT. The first version of this branch asserted a cause
        # it had not checked ("the artifact is not committed yet") and the real refusal was a
        # missing MediaType -- a diagnosis that sends the reader to the wrong place is worse than
        # none (memory instrument-what-the-guard-actually-reads).
        Write-Host ("[STOP] the evidence utility refused: " + $res.Trim()) -ForegroundColor Yellow
        Write-Host ("       the run is COMPLETED and its report stands; only registration is " +
                    "owed. Re-invoke this script once the cause above is fixed -- the manifest " +
                    "resumes at REGISTER_EVIDENCE, which is the whole point of it.") -ForegroundColor Yellow
        exit 1
      }
      $evId = 'evd_sha256_' + (Get-FileHash -LiteralPath $htm -Algorithm SHA256).Hash.ToLower()
      Invoke-Append (New-Line 'EVIDENCE_REGISTERED' $a @{ event_id = $evId })
    }
    'ADOPT_EVIDENCE' {
      Invoke-Append (New-Line 'EVIDENCE_REGISTERED' $a @{ event_id = $act.event_id })
    }
    'RELEASE_LEASE' {
      # WRITTEN EXPIRED, NOT DELETED. This script owns no delete (PART 4 greps for Remove-Item),
      # and an expired lease is a record that the lane was held and handed back; an absent file
      # is only the absence of a record. lease_is_free() treats expires_at <= now as free, so the
      # next run may take the lane on its very next observation.
      $lease = Get-Content -LiteralPath $leaseFile -Raw | ConvertFrom-Json
      [ordered]@{ lease_id = $lease.lease_id; owner = $lease.owner; expires_at = (Now-Stamp) } |
        ConvertTo-Json | Set-Content -LiteralPath $leaseFile -Encoding UTF8
      Say ("released lane " + $key.lane + " (next: " + $act.next_action + ")") 'DarkGray'
    }
    'ABANDON' {
      Invoke-Append (New-Line 'ABANDONED' $a @{ failure_class = $act.failure_class })
    }
    'DONE' {
      Write-Host (">> " + $Run + " complete: evidence registered.") -ForegroundColor Green
      exit 0
    }
    'REFUSE' {
      Write-Host ("[REFUSE " + $act.code + "] " + $act.why) -ForegroundColor Red
      if ($act.cached_run) { Write-Host ("   cached evidence: run " + $act.cached_run + " (" + $act.cached_event_id + ")") -ForegroundColor Yellow }
      exit 1
    }
    default {
      # Unreachable while PART 4 holds: it asserts this switch covers the planner's closed action
      # set exactly. If it ever fires, the cage was deleted, not outgrown.
      Write-Host ("[BUG] no dispatcher branch for action " + $act.action) -ForegroundColor Red
      exit 2
    }
  }
}
Write-Host ("[STOP] " + $MaxIterations + " iterations without reaching a terminal state.") -ForegroundColor Red
exit 1
