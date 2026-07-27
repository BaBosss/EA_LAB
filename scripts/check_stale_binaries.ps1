<#
check_stale_binaries.ps1 - ORDER-221: does every copy of a compiled EA still agree with its source?

WHY THIS EXISTS
  Compiled .ex5 binaries live in at least 4 places on this machine (ea_template\, ea_projects\,
  the D:\Meta 5b portable tester's MQL5\Experts\, and the roaming MT5 terminal data folder's
  MQL5\Experts\) and nothing forces them to agree. .ex5 is gitignored, so the repo itself is
  structurally blind to a stale binary - git status will never show you that a compiled copy
  fell behind its source.

  Measured 2026-07-25: two separate cases surfaced in one day. The ea_template\ copy of Boss_16
  predated 7 core .mqh edits and did not even contain the _16_BaseLotMode input - attaching that
  stale .ex5 with a balance-scaled .set would have silently run flat-lot mode instead, with no
  error, no log line, nothing to distinguish it from a correct attach.

WHAT THIS CHECKS
  1. Finds every .ex5 under a configurable list of roots (skips roots that do not exist on this
     machine, reporting that once rather than erroring).
  2. Groups copies by base file name and flags when two copies of the "same" EA have DIFFERENT
     SHA256 hashes (HASH_DIFFERS). ADVISORY ONLY - see the measured note at the hash check:
     the MQL5 compiler is not byte-reproducible, so this is NOT proof the code differs.
  3. For each .ex5, finds the matching .mq5 anywhere under D:\EA_LAB, walks its #include graph
     transitively (relative to the including file's folder, then ea_template\ / ea_template\modules
     as fallback roots, with a visited-set guard against include cycles), and compares the .ex5
     mtime against the newest mtime among the .mq5 + every reachable .mqh. Older binary => STALE,
     and the report NAMES the newer files - a bare "stale" line is what got ignored last time
     (2026-07-25 Boss_16), so this script refuses to emit one.
  4. Writes a JSON sidecar with the same findings for scripted / next-session consumption.

HOW MUCH A "STALE" LINE ACTUALLY MATTERS - triage before you panic
  It depends entirely on whether the consumer recompiles first.
    - tpl_regression.ps1 calls deploy.ps1 -Compile, which deletes the old .ex5 and rebuilds
      from current source before every run. Its test binaries showing STALE on disk is
      cosmetic - the cage never tests the file this script is looking at.
    - Anything ATTACHED to a chart, or run straight out of an Experts folder without a
      rebuild, is the real exposure. That is the Boss_16 case.
  The script deliberately does not try to guess which consumer will pick a binary up, so it
  reports both and names the newer source files; that judgement is yours.

  mtime is also a weaker signal than it looks: git operations rewrite it. Before treating a
  STALE line as an incident, check that the "newer" source files were newer because somebody
  EDITED them, not because a checkout touched them.

USAGE
  powershell -File scripts\check_stale_binaries.ps1
  powershell -File scripts\check_stale_binaries.ps1 -Roots "D:\EA_LAB\ea_template","D:\Meta 5b\MQL5\Experts"

EXIT CODES
  0 = every .ex5 found matches its source and its sibling copies
  2 = at least one STALE binary was found (HASH_DIFFERS alone never fails - it is advisory)
#>
[CmdletBinding()]
param(
  # SCOPE IS THE WHOLE DESIGN HERE. The first run of this script pointed the roaming path at
  # `Terminal\*\MQL5\Experts` and found 1313 binaries across 27 terminal folders: 709 with no
  # source in this repo (bought/downloaded EAs) and 502 hash-mismatching (the same EA name
  # compiled by different terminals at different times, which for a dead install is normal and
  # means nothing). 530 "findings" is not a detector, it is a wall - and this order exists
  # because a detector nobody reads is worthless. So the default is the FOUR locations a
  # binary can actually be attached or tested from, with the live terminal id pinned:
  #   9CA16B... is the data folder for the non-portable D:\Meta 5 install (memory:
  #   mt5-tester-experts-roaming). The other 26 terminal folders are dead installs.
  # Widen deliberately with -Roots or -AllTerminals when you are auditing rather than deploying.
  [string[]]$Roots = @(
    "D:\EA_LAB\ea_template",
    "D:\EA_LAB\ea_projects",
    "D:\Meta 5b\MQL5\Experts",
    "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts"
  ),
  [switch]$AllTerminals,        # expand to every roaming terminal-id folder (audit mode)
  [switch]$IncludeForeign,      # emit a record per no-source binary instead of one summary line
  [string]$RepoRoot = "D:\EA_LAB",
  [string]$JsonOut = "D:\EA_LAB\_mt5_auto\reports\stale_binaries_check.json"
)
$ErrorActionPreference = "Stop"

if ($AllTerminals) {
  $Roots = @($Roots | Where-Object { $_ -notlike "*\Terminal\*" }) +
           @("C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\*\MQL5\Experts")
}

# ---------------------------------------------------------------------------
# 1. Resolve roots. The roaming terminal path has a wildcard terminal-id folder
#    (there can be 20+ on this machine) so it needs Resolve-Path, not Test-Path.
# ---------------------------------------------------------------------------
$resolvedRoots = New-Object System.Collections.Generic.List[string]
foreach ($root in $Roots) {
  if ($root -match '\*') {
    $hits = @()
    try { $hits = Resolve-Path -Path $root -ErrorAction SilentlyContinue } catch { $hits = @() }
    if (-not $hits -or $hits.Count -eq 0) {
      Write-Host "[SKIP] no match for wildcard root: $root" -ForegroundColor Yellow
      continue
    }
    foreach ($h in $hits) { $resolvedRoots.Add($h.Path) }
  }
  elseif (Test-Path -LiteralPath $root) {
    $resolvedRoots.Add($root)
  }
  else {
    Write-Host "[SKIP] root does not exist on this machine: $root" -ForegroundColor Yellow
  }
}
if ($resolvedRoots.Count -eq 0) {
  Write-Host "[FAIL] no roots resolved - nothing to check" -ForegroundColor Red
  exit 1
}

# ---------------------------------------------------------------------------
# 2. Collect every .ex5 under the resolved roots.
# ---------------------------------------------------------------------------
$ex5Files = New-Object System.Collections.Generic.List[System.IO.FileSystemInfo]
foreach ($r in $resolvedRoots) {
  $found = @()
  try {
    $found = Get-ChildItem -LiteralPath $r -Filter "*.ex5" -Recurse -File -ErrorAction SilentlyContinue
  } catch {
    Write-Host "[WARN] could not scan $r : $($_.Exception.Message)" -ForegroundColor Yellow
  }
  foreach ($f in $found) { $ex5Files.Add($f) }
}
if ($ex5Files.Count -eq 0) {
  Write-Host "[INFO] no .ex5 files found under any resolved root" -ForegroundColor Yellow
  exit 0
}

# ---------------------------------------------------------------------------
# 3. Hash every .ex5 (tolerate locked / access-denied files instead of aborting).
# ---------------------------------------------------------------------------
function Get-Ex5Hash {
  param([string]$Path)
  try {
    $h = Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop
    return $h.Hash
  } catch {
    return $null
  }
}

$records = New-Object System.Collections.Generic.List[object]
foreach ($f in $ex5Files) {
  $hash = Get-Ex5Hash -Path $f.FullName
  $records.Add([pscustomobject]@{
    Name  = $f.BaseName
    Path  = $f.FullName
    Mtime = $f.LastWriteTime
    Hash  = $hash
  })
}

# ---------------------------------------------------------------------------
# 4. Build the .mq5 -> transitive #include graph, on demand, memoised by path.
#    Relative includes resolve against the including file's own folder first;
#    if that misses, fall back to ea_template\ and ea_template\modules\ (the
#    two conventional include roots seen in this repo's EA sources).
# ---------------------------------------------------------------------------
$includeCache = @{}   # path -> resolved newest-mtime info already computed
$fallbackIncludeRoots = @(
  (Join-Path $RepoRoot "ea_template"),
  (Join-Path $RepoRoot "ea_template\modules")
)

function Resolve-IncludePath {
  param([string]$IncludeText, [string]$FromFolder)
  # Try relative to the including file first.
  $candidate = Join-Path $FromFolder $IncludeText
  if (Test-Path -LiteralPath $candidate) {
    return (Resolve-Path -LiteralPath $candidate).Path
  }
  foreach ($fr in $fallbackIncludeRoots) {
    $candidate2 = Join-Path $fr $IncludeText
    if (Test-Path -LiteralPath $candidate2) {
      return (Resolve-Path -LiteralPath $candidate2).Path
    }
  }
  return $null
}

function Get-IncludeLines {
  param([string]$FilePath)
  $lines = @()
  try {
    $lines = Get-Content -LiteralPath $FilePath -ErrorAction Stop
  } catch {
    return @()
  }
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($ln in $lines) {
    # matches #include "foo.mqh" and #include <foo.mqh>
    $m = [regex]::Match($ln, '^\s*#include\s+["<]([^">]+)[">]')
    if ($m.Success) { $out.Add($m.Groups[1].Value) }
  }
  return $out
}

function Get-TransitiveSourceInfo {
  # Walks a .mq5 (or .mqh) file's include graph and returns:
  #   @{ NewestMtime = <datetime>; NewestFile = <path>; Files = <list of every file visited> }
  param([string]$RootFile)
  $visited = New-Object System.Collections.Generic.HashSet[string]
  $queue = New-Object System.Collections.Generic.Queue[string]
  $queue.Enqueue($RootFile)
  $newestMtime = [datetime]::MinValue
  $newestFile = $null
  $allFiles = New-Object System.Collections.Generic.List[string]
  $unresolved = New-Object System.Collections.Generic.List[string]

  while ($queue.Count -gt 0) {
    $cur = $queue.Dequeue()
    $curKey = $cur.ToLowerInvariant()
    if ($visited.Contains($curKey)) { continue }
    [void]$visited.Add($curKey)
    if (-not (Test-Path -LiteralPath $cur)) { continue }
    $fi = Get-Item -LiteralPath $cur
    $allFiles.Add($cur)
    if ($fi.LastWriteTime -gt $newestMtime) {
      $newestMtime = $fi.LastWriteTime
      $newestFile = $cur
    }
    $folder = [System.IO.Path]::GetDirectoryName($cur)
    $incs = Get-IncludeLines -FilePath $cur
    foreach ($inc in $incs) {
      $resolved = Resolve-IncludePath -IncludeText $inc -FromFolder $folder
      if ($resolved) {
        if (-not $visited.Contains($resolved.ToLowerInvariant())) {
          $queue.Enqueue($resolved)
        }
      } else {
        $unresolved.Add($inc)
      }
    }
  }
  return [pscustomobject]@{
    NewestMtime = $newestMtime
    NewestFile  = $newestFile
    Files       = $allFiles
    Unresolved  = $unresolved
  }
}

function Find-Ex5Source {
  # Best-effort: search the whole repo for a .mq5 whose base name matches. When more than
  # one turns up (rare - a couple of EAs have same-named forks in different folders) the
  # first match is used and every path found is still recorded in Unresolved-style detail
  # via the caller, since ambiguity is itself worth knowing about.
  #
  # Excludes .claude\worktrees\* : those are transient git worktree checkouts of this same
  # repo, and a checkout stamps every file with the checkout time, not its real edit history.
  # Without this exclusion, every .mq5/.mqh in a worktree looks "just edited" and makes every
  # .ex5 in the real ea_template\ falsely report STALE - found while verifying this script.
  param([string]$BaseName, [string]$SearchRoot)
  $hits = Get-ChildItem -LiteralPath $SearchRoot -Filter "$BaseName.mq5" -Recurse -File -ErrorAction SilentlyContinue
  $hits = $hits | Where-Object { $_.FullName -notmatch '\\\.claude\\worktrees\\' }
  return $hits
}

# ---------------------------------------------------------------------------
# 5. Evaluate each .ex5: hash-mismatch within its name-group, then staleness
#    against its resolved source graph.
# ---------------------------------------------------------------------------
$groups = $records | Group-Object -Property Name
$results = New-Object System.Collections.Generic.List[object]
$anyBad = $false
$foreignCount = 0

Write-Host ("Scanned {0} root(s), found {1} .ex5 file(s) in {2} name group(s)." -f $resolvedRoots.Count, $ex5Files.Count, $groups.Count)
Write-Host ""

$sourceInfoCache = @{}

foreach ($g in $groups) {
  $name = $g.Name
  $copies = $g.Group
  Write-Host ("== {0} ({1} {2}) ==" -f $name, $copies.Count, $(if ($copies.Count -eq 1) { "copy" } else { "copies" }))

  $distinctHashes = ($copies | Where-Object { $_.Hash } | Select-Object -ExpandProperty Hash -Unique)
  $hashMismatch = ($distinctHashes.Count -gt 1)
  # NOT $anyBad: a hash difference is advisory (non-reproducible compiler), never a failure.

  # Resolve source once per name (cache), so multiple copies of the same EA don't repeat the walk.
  if (-not $sourceInfoCache.ContainsKey($name)) {
    $srcHits = Find-Ex5Source -BaseName $name -SearchRoot $RepoRoot
    if (-not $srcHits -or $srcHits.Count -eq 0) {
      $sourceInfoCache[$name] = [pscustomobject]@{ Found = $false; Info = $null; SourcePath = $null; Ambiguous = $false }
    } else {
      $primary = $srcHits[0]
      $info = Get-TransitiveSourceInfo -RootFile $primary.FullName
      $sourceInfoCache[$name] = [pscustomobject]@{
        Found      = $true
        Info       = $info
        SourcePath = $primary.FullName
        Ambiguous  = ($srcHits.Count -gt 1)
        AllHits    = $srcHits
      }
    }
  }
  $src = $sourceInfoCache[$name]

  foreach ($c in $copies) {
    $status = "OK"
    $detailParts = New-Object System.Collections.Generic.List[string]

    if (-not $c.Hash) {
      $status = "NO_SOURCE"
      $detailParts.Add("could not hash the file (locked / access denied)")
    }

    # MEASURED 2026-07-26, ORDER-221: the MQL5 compiler is NOT byte-deterministic. Compiling
    # ea_template\tests\AcctGate_Test.mq5 five times from unchanged source produced five
    # different SHA256s AND five different file sizes (60870 / 60076 / 60802 / 60258 / 60950
    # bytes). So a hash difference between two copies is NOT evidence that they are different
    # code - it is the expected result of compiling twice. Reporting it as a failure would
    # manufacture ~111 findings a day out of nothing, which is how a detector gets ignored.
    #
    # The hash is still worth recording, for the one thing it CAN do: prove that the exact
    # file you are about to drag onto a chart is bit-identical to the one that was tested.
    # That is the ORDER-213 README precedent and it survives intact - it compares a file to
    # ITSELF across a copy, never one build to another build.
    # ORDER-341 (2026-07-27): this used to be a first-wins race for a single $status
    # slot, and HASH_DIFFERS was assigned BEFORE the staleness check below. Since MQL5
    # compilation is not byte-reproducible, EVERY EA with more than one copy mismatches
    # by hash -- so `if ($status -eq "OK") { $status = "STALE" }` could never fire for
    # any multi-copy EA, and that is all of them. Measured on the real tree: 8 binaries
    # were labelled STALE while 48 more were genuinely older than their source graph and
    # wore the advisory HASH_DIFFERS label instead. The whole Boss_11..18 chassis family
    # was masked, including the copy in the lane a live A/B was about to run on.
    # The staleness text was still appended to $detail, so the information was present
    # and nobody could see it -- the failing label is what makes a human look.
    # Fixed by ranking: STALE outranks HASH_DIFFERS, which outranks OK.
    $hashDiffersHere = $false
    if ($hashMismatch -and $c.Hash) {
      $hashDiffersHere = $true
      if ($status -eq "OK") { $status = "HASH_DIFFERS" }
      $others = $copies | Where-Object { $_.Path -ne $c.Path }
      $otherDesc = ($others | ForEach-Object { "$($_.Path) [$($_.Hash)]" }) -join "; "
      $detailParts.Add("SHA256 differs from other copy(ies) of '$name': $otherDesc -- ADVISORY ONLY: MQL5 compilation is not byte-reproducible (measured 5/5 distinct hashes from identical source), so this does not by itself mean the code differs. Judge by the STALE check and by mtime, or diff the sources")
    }

    if (-not $src.Found) {
      if ($status -eq "OK") { $status = "NO_SOURCE" }
      $detailParts.Add("no .mq5 named '$name.mq5' found anywhere under $RepoRoot - cannot verify staleness")
    } else {
      if ($src.Ambiguous) {
        $allPaths = ($src.AllHits | ForEach-Object { $_.FullName }) -join "; "
        $detailParts.Add("AMBIGUOUS SOURCE: multiple '$name.mq5' found, used $($src.SourcePath): $allPaths")
      }
      $info = $src.Info
      if ($info.NewestMtime -gt $c.Mtime) {
        # ORDER-341: STALE outranks HASH_DIFFERS unconditionally. Being older than your
        # own source is a fact about the code; a hash difference is an artifact of a
        # non-deterministic compiler. The blocking label must not lose to the advisory one.
        if ($status -eq "OK" -or $status -eq "HASH_DIFFERS") { $status = "STALE" }
        $anyBad = $true
        # Name every source-side file newer than the binary - that is the whole point.
        $newerFiles = $info.Files | Where-Object {
          (Get-Item -LiteralPath $_).LastWriteTime -gt $c.Mtime
        } | ForEach-Object {
          "{0} ({1})" -f $_, (Get-Item -LiteralPath $_).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        }
        $detailParts.Add("binary mtime $($c.Mtime.ToString('yyyy-MM-dd HH:mm:ss')) is OLDER than: " + ($newerFiles -join "; "))
      }
      if ($info.Unresolved.Count -gt 0) {
        $detailParts.Add("best-effort include resolution could not find: " + (($info.Unresolved | Select-Object -Unique) -join ", ") + " (may be a standard-library <...> include outside this repo - not counted as a staleness signal)")
      }
    }

    if ($status -eq "OK" -and $detailParts.Count -eq 0) {
      $detailParts.Add("hash matches sibling copies (if any) and binary is newer than or equal to all reachable source files")
    }

    $detail = ($detailParts -join " | ")

    # A binary with no .mq5 in this repo is somebody else's EA (bought, downloaded, a course
    # file). This script cannot say anything about it - there is no source to be stale against -
    # so by default it is counted, not listed. Listing 709 of them buries the 10 that matter.
    if ($status -eq "NO_SOURCE" -and -not $IncludeForeign) {
      $foreignCount++
      continue
    }

    $color = "Green"
    if ($status -eq "STALE") { $color = "Red" }
    elseif ($status -eq "HASH_DIFFERS") { $color = "DarkYellow" }
    elseif ($status -eq "NO_SOURCE") { $color = "Yellow" }

    Write-Host ("  [{0}] {1}" -f $status, $c.Path) -ForegroundColor $color
    Write-Host ("        mtime={0} sha256={1}" -f $c.Mtime.ToString("yyyy-MM-dd HH:mm:ss"), $(if ($c.Hash) { $c.Hash } else { "<unavailable>" }))
    if ($detail) { Write-Host ("        $detail") }

    $results.Add([pscustomobject]@{
      name   = $name
      path   = $c.Path
      mtime  = $c.Mtime.ToString("yyyy-MM-ddTHH:mm:ss")
      sha256 = $c.Hash
      status = $status
      # ORDER-341: recorded separately now that STALE outranks HASH_DIFFERS in `status`,
      # so the advisory signal is not lost on rows where the blocking one won.
      hash_differs = $hashDiffersHere
      detail = $detail
    })
  }
  Write-Host ""
}

# ---------------------------------------------------------------------------
# 6. JSON sidecar.
# ---------------------------------------------------------------------------
$jsonDir = [System.IO.Path]::GetDirectoryName($JsonOut)
if (-not (Test-Path -LiteralPath $jsonDir)) {
  New-Item -ItemType Directory -Path $jsonDir -Force | Out-Null
}
$results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $JsonOut -Encoding UTF8
Write-Host "Wrote $($results.Count) record(s) to $JsonOut"
if ($foreignCount -gt 0) {
  Write-Host ("({0} binary(ies) with no .mq5 in this repo were counted but not listed - they are not ours to judge. -IncludeForeign lists them.)" -f $foreignCount) -ForegroundColor DarkGray
}

$badCount  = ($results | Where-Object { $_.status -eq "STALE" }).Count
$diffCount = ($results | Where-Object { $_.hash_differs }).Count
if ($diffCount -gt 0) {
  Write-Host ("[INFO] {0} copy(ies) differ by hash from a sibling - advisory only, the compiler is not byte-reproducible" -f $diffCount) -ForegroundColor DarkYellow
}
if ($badCount -gt 0) {
  Write-Host ("[FAIL] {0} binary(ies) are OLDER than their source - rebuild before attaching or testing these" -f $badCount) -ForegroundColor Red
  exit 2
}
Write-Host "[OK] every .ex5 found matches its source and its sibling copies" -ForegroundColor Green
exit 0
