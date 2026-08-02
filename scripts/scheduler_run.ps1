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
  # DEFAULTS TO THE RUN ID, /scrutinize round 4. It was a free-form mandatory parameter, and
  # mt5_run.ps1 CLEARS `<ReportName>*` from both the tester data dir and _mt5_auto\reports before
  # every launch -- so two runs handed the same name on one lane delete each other's evidence, and
  # the ExecutionKey does not contain the report name, so criterion 3 cannot see the collision.
  # Deriving it from the run id makes the collision impossible for anyone who does not go out of
  # their way to cause one.
  [string]$ReportName = '',
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

if (-not $ReportName) { $ReportName = ($Run -replace '[^A-Za-z0-9]', '_') }
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
function Get-Observation([int]$attempt, $journal) {
  # THE RUN START COMES FROM THE MANIFEST, not from a sidecar and never from a default.
  # /scrutinize round 1: this used the spawn marker's copy with `else { [datetime]'1970-01-01' }`,
  # so an attempt whose marker was missing put RunStart at the epoch -- and Test-ReportIsFresh's
  # mtime half then accepts ANY report on disk. That is the precise inference the guard exists to
  # refuse ("the .htm exists is NOT evidence that THIS invocation produced it"), reintroduced by
  # its own caller, in the branch that only runs after a crash. The manifest's LAUNCH_INTENT line
  # is the authority: it is append-only, it is written before the spawn, and if it is absent then
  # freshness is UNPROVABLE and must read false rather than default to permissive.
  $intentAt = ($journal.attempts |
               Where-Object { $_.attempt -eq $attempt -and $_.launch_intent_at } |
               Select-Object -Last 1).launch_intent_at
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
    if (-not $intentAt) {
      # No recorded run start => no way to tell this run's report from last week's. REFUSE, which
      # routes to FAILED(TESTER_ERROR) and a retry, rather than passing a report nothing dates.
      Write-Host "   [STALE-GUARD] attempt $attempt has an exit record but the manifest holds no launch_intent_at - freshness is UNPROVABLE, refusing." -ForegroundColor Red
      $fresh = $false
    } else {
      $runStart = [datetime]::Parse($intentAt).ToUniversalTime()
      $fresh = [bool](Test-ReportIsFresh -Htm $htm -RunStart $runStart -RunnerExit ([int]$exitRec.exit_code) -Label $ReportName -Quiet)
    }
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
    # 🔴 /scrutinize round 4: ONE of the ways this refusal happens is not a bug at all. A SECOND
    # driver started against the same run id reads the same journal, plans the same action, and
    # loses the race to append -- and S4 (this (attempt, transition) is already recorded) is the
    # correct answer, not a defect. Reporting it as "[BUG] ... a line this dispatcher built" sends
    # the reader hunting for a code fault instead of for the other process. The lane lease guards
    # the LANE; nothing guards a run against a second driver of itself, and S4 is what catches it.
    if ($raw -match '"S4 ') {
      Write-Host ("[STOP] another driver is already advancing " + $Run + " -- its line landed " +
                  "first and this one was refused as a duplicate. That is the append-only store " +
                  "doing its job; stop one of the two drivers.") -ForegroundColor Yellow
      exit 1
    }
    # Everything else IS a defect in the DISPATCHER, and it must never share an exit path with a
    # scheduling outcome: a resume that treated an invalid line as a failed attempt would retry
    # into the same invalid line forever.
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
  $act = Invoke-Plan (Get-Observation $attempt $journal)
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
      #
      # 🔴 /scrutinize round 1: THAT PARAGRAPH WAS TRUE OF THE DESIGN AND FALSE OF THE CODE. The
      # marker was written AFTER Start-Process, because it carries the pid -- so the crash window
      # between the spawn and the marker left NO marker, and the resume read "never spawned" and
      # LAUNCHED AGAIN. The one defect the marker exists to prevent, reintroduced by the write
      # order, underneath a comment asserting the opposite. Two writes now: an intent marker with
      # no pid BEFORE the spawn, then the pid once it is known. A marker with a null pid means
      # "a spawn may have happened", which the planner already treats as spawned.
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
      [PSCustomObject]@{ pid = $null; started_at = $null
                         launch_intent_at = $intent; at = (Now-Stamp) } |
        ConvertTo-Json | Set-Content -LiteralPath (Spawn-Marker $a) -Encoding UTF8
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
      # 🔴 /scrutinize round 3: THE ID WRITTEN INTO THE MANIFEST WAS HASHED FROM A DIFFERENT FILE
      # THAN THE ONE REGISTERED. The utility was handed $rel (-EvidencePath, a committed copy) and
      # the EVIDENCE_REGISTERED line carried the sha256 of $htm (the runner's own report). Point
      # them at two different files and the manifest names an evidence record that was never
      # created -- and the crash reconcile hashes $htm too, so it looks for the same wrong id and
      # REGISTERS A SECOND TIME. "Duplicates no event" would have failed on exactly the input the
      # -EvidencePath parameter exists to accept.
      #
      # Closed at the root rather than by hashing the right file: the registered artifact must BE
      # the report this run produced, so the two are compared and a mismatch is REFUSED. With that
      # invariant, hashing either one is the same answer, which is what makes the reconcile above
      # sound even before the copy exists.
      $absRel = Join-Path $root ($rel -replace '/', '\')
      if (-not (Test-Path $absRel)) {
        Write-Host ("[STOP] -EvidencePath " + $rel + " does not exist. The manifest records " +
                    "COMMITTED Git artifacts only (design 4.5), and _mt5_auto/reports/ is " +
                    "gitignored -- copy the report somewhere committed and re-invoke.") -ForegroundColor Yellow
        exit 1
      }
      $relSha = (Get-FileHash -LiteralPath $absRel -Algorithm SHA256).Hash.ToLower()
      $htmSha = (Get-FileHash -LiteralPath $htm -Algorithm SHA256).Hash.ToLower()
      if ($relSha -ne $htmSha) {
        Write-Host ("[STOP] " + $rel + " is NOT byte-identical to the report this run produced " +
                    "(" + $relSha.Substring(0,12) + " vs " + $htmSha.Substring(0,12) + "). " +
                    "Registering it would file one run's evidence under another artifact's id.") -ForegroundColor Red
        exit 1
      }
      # TWO CORRECTIONS, BOTH MEASURED AGAINST THE UTILITY RATHER THAN ASSUMED.
      #
      # (1) THE PARAMETER NAMES. `-Command RegisterEvidence` reads -ArtifactPath / -CommitOid /
      #     -MediaType. The `-RegisterEvidence*` trio belongs to `-Command Append`'s inline
      #     registration and is ignored here -- so the first version supplied a media type the
      #     command never looked at and was told "MediaType is required" while holding one.
      #
      # (2) THE CAPTURE. The utility reports through [Console]::Out.WriteLine, which bypasses
      #     EVERY PowerShell stream -- worse than the Write-Host/stream-6 trap this repo already
      #     paid for (memory writehost-stream6-swallows-detail), because `2>&1 6>&1` does not
      #     reach it either. Its output is capturable only when it is a CHILD PROCESS whose
      #     stdout is a pipe. Hence powershell.exe here rather than a dot-call: the refusal text
      #     is the whole value of this branch, and the first version printed an empty string.
      #
      # (3) THE MEDIA TYPE. `text/html` is NOT in evidence-v1.schema.json's enum, and the answer
      #     was read off the three .htm rows already in the manifest (ORDER098B) rather than
      #     chosen: they are `application/octet-stream`, which is also honest -- an MT5 report is
      #     UTF-16LE and is not plain text by any reader's definition (memory
      #     prove-the-instrument-can-see-the-file).
      $ps = (Get-Command powershell.exe).Source
      $res = & $ps -NoProfile -ExecutionPolicy Bypass `
                -File (Join-Path $PSScriptRoot 'experiment_event_log.ps1') `
                -Command RegisterEvidence -RepoRoot $root -ArtifactPath $rel `
                -CommitOid HEAD -MediaType 'application/octet-stream' 2>&1 | Out-String
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
      # THE ID COMES FROM THE UTILITY'S OWN RECORD, not from a second computation of what it
      # should have been. Recomputing it here is how the two halves drifted in the first place.
      # The local sha is the fallback only, and it is only equal to the right answer because the
      # byte-identity check above already refused every case where it would not be.
      $evId = $null
      $lastLine = ($res -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 1)
      try { $evId = ($lastLine | ConvertFrom-Json).details.evidence_id } catch { $evId = $null }
      if (-not $evId) { $evId = 'evd_sha256_' + $relSha }
      Invoke-Append (New-Line 'EVIDENCE_REGISTERED' $a @{ event_id = $evId })
    }
    'ADOPT_EVIDENCE' {
      Invoke-Append (New-Line 'EVIDENCE_REGISTERED' $a @{ event_id = $act.event_id })
    }
    'RENEW_LEASE' {
      # A HEARTBEAT, not a new lease: the id and the owner are preserved so the lane's history is
      # one lease held continuously, not a series of re-acquisitions that would each look like a
      # fresh claim to anyone reading the file.
      $lease = Get-Content -LiteralPath $leaseFile -Raw | ConvertFrom-Json
      [ordered]@{ lease_id = $lease.lease_id; owner = $lease.owner
                  expires_at = $act.expires_at } |
        ConvertTo-Json | Set-Content -LiteralPath $leaseFile -Encoding UTF8
      Say ("renewed lane " + $key.lane + " until " + $act.expires_at) 'DarkGray'
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
