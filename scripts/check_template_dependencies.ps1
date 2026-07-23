<#
check_template_dependencies.ps1 - ORDER-163 clean-room dependency audit (CORE-002).

Purpose: prove, mechanically and repeatably, that Boss V2 (ea_template\) does NOT
depend on EA_CORE V1 (D:\EA_Project\...) or any archive path via #include. This is
the automated check that was missing after the MERGE track decided Boss V2 is the
sole chassis going forward (PROJECT_STATE.md) - nobody had ever proven it stays true
as the codebase changes.

WHAT IT DOES
  1. Recursively scans every *.mq5 and *.mqh under ea_template\ (Boss_11..18,
     EA_LabTemplate.mq5, core\, core\entries\, modules\, modules\entries\,
     tests\).
  2. Parses every #include directive (both "quoted" and <angle> forms).
  3. Resolves each quoted include: first relative to the including file's own
     directory (MQL5's actual search order), then relative to ea_template\ root.
     <angle> includes are treated as MQL5 standard-library includes (they resolve
     under the MetaQuotes Include tree, never under this repo) and are always OK.
  4. Classifies every include:
       OK                    - quoted, resolves inside ea_template\
       OK-STDLIB             - <angle>, MetaQuotes standard library
       OK-TEST-SUPPORT       - quoted, file is under ea_template\tests\, resolves
                                OUTSIDE ea_template\ but still inside this repo
                                (D:\EA_LAB) and does not touch a forbidden marker -
                                this is the documented pattern where NewsGuard_Test /
                                AcctSnapshot_Test include a canonical copy from
                                ea_projects\ or tools\ that run_tests.ps1 stages
                                next to the test at run time (see that script).
       UNRESOLVED            - quoted, runtime scope, not found on disk relative to
                                the file or to ea_template\ root, and the literal
                                include string does not reference a forbidden
                                marker. This is a potential compile-time bug, not an
                                architecture leak - reported for visibility, does
                                NOT by itself fail the script (compile check catches
                                real breakage).
       UNRESOLVED-TEST-SUPPORT - same as UNRESOLVED but scope=test-support (the
                                NewsGuard/AcctSnapshot pattern above lands here too
                                when this script is run without a prior deploy).
       FORBIDDEN              - any of:
                                (a) resolved path contains a forbidden marker
                                    (EA_CORE, EA_Project, CURRENT_BUILD, archive)
                                (b) resolved path is a RUNTIME-scope file (i.e. NOT
                                    under ea_template\tests\) that resolves outside
                                    ea_template\ at all, marker or not - runtime
                                    scope must stay entirely inside ea_template\
                                (c) resolved path is a TEST-SUPPORT-scope file that
                                    resolves outside ea_template\ AND touches a
                                    forbidden marker
                                (d) unresolved (file not found) but the literal
                                    include string itself references a forbidden
                                    marker
  5. Prints a summary and, when any FORBIDDEN entries exist, a clear
     file:line -> include path -> reason list, then exits 1.
     Exits 0 with a clean summary when there are none.
  6. Writes the full dependency graph (every scanned file -> its full include
     list, each with resolution + status) to _triage\ORDER163_DEPENDENCY_GRAPH.md.

This script is DETECTION ONLY. It never edits, moves, or deletes anything under
ea_template\, EA_CORE, or D:\EA_Project. If it finds a violation, fix it in a
separate order - do not patch this script to "make it pass".

Usage:
  powershell -File scripts\check_template_dependencies.ps1
  powershell -File scripts\check_template_dependencies.ps1 -Quiet   # summary only, no full graph on stdout
#>
[CmdletBinding()]
param(
  [string]$TemplateRoot = '',
  [string]$GraphReport  = '',
  [switch]$Quiet
)
$ErrorActionPreference = "Stop"

# $PSScriptRoot can be empty depending on how the script was invoked (e.g. some
# -File launch paths) - fall back to $MyInvocation.MyCommand.Path, then to the
# known repo layout relative to the current directory as a last resort.
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptDir)) {
  if ($MyInvocation.MyCommand.Path) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  } else {
    $scriptDir = (Get-Location).Path
  }
}
if ([string]::IsNullOrEmpty($TemplateRoot)) { $TemplateRoot = Join-Path $scriptDir '..\ea_template' }
if ([string]::IsNullOrEmpty($GraphReport))  { $GraphReport  = Join-Path $scriptDir '..\_triage\ORDER163_DEPENDENCY_GRAPH.md' }

if (-not (Test-Path -LiteralPath $TemplateRoot)) {
  Write-Host "FATAL: TemplateRoot not found: $TemplateRoot" -ForegroundColor Red
  exit 2
}
$TemplateRoot = (Resolve-Path -LiteralPath $TemplateRoot).Path.TrimEnd('\')
$repoRoot     = (Resolve-Path -LiteralPath (Join-Path $TemplateRoot '..')).Path.TrimEnd('\')
$testsDir     = Join-Path $TemplateRoot 'tests'

# Markers that, anywhere in a RESOLVED path or an UNRESOLVED literal include
# string, prove the include is reaching into the frozen V1 archive or an
# archive-like path. Case-insensitive substring match.
$forbiddenMarkers = @('EA_CORE', 'EA_Project', 'CURRENT_BUILD', 'archive')

function Test-ForbiddenMarker {
  param([string]$text)
  foreach ($m in $forbiddenMarkers) {
    if ($text -match [regex]::Escape($m)) { return $m }
  }
  return $null
}

function Get-Scope {
  param([string]$fullPath)
  $p = $fullPath.ToLowerInvariant()
  $t = ($testsDir.ToLowerInvariant() + '\')
  if ($p.StartsWith($t) -or $p -eq $testsDir.ToLowerInvariant()) { return 'test-support' }
  return 'runtime'
}

# --- gather files -----------------------------------------------------------
$mq5Files = Get-ChildItem -Path $TemplateRoot -Recurse -Filter '*.mq5' -File
$mqhFiles = Get-ChildItem -Path $TemplateRoot -Recurse -Filter '*.mqh' -File
$allFiles = @($mq5Files) + @($mqhFiles) | Sort-Object FullName

$includeRegex = [regex]'#include\s*([<"])([^">]+)[">]'

$graph = New-Object System.Collections.Generic.List[object]
$violations = New-Object System.Collections.Generic.List[object]
$statusCounts = @{}
$totalIncludes = 0

foreach ($f in $allFiles) {
  $scope = Get-Scope $f.FullName
  $relFile = $f.FullName.Substring($repoRoot.Length + 1)
  $lines = Get-Content -LiteralPath $f.FullName
  $entries = New-Object System.Collections.Generic.List[object]

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $m = $includeRegex.Match($lines[$i])
    if (-not $m.Success) { continue }
    $totalIncludes++
    $lineNo   = $i + 1
    $delim    = $m.Groups[1].Value
    $incPath  = $m.Groups[2].Value.Trim()
    $kind     = if ($delim -eq '<') { 'angle' } else { 'quoted' }

    $status = $null
    $reason = $null
    $resolvedPath = $null

    if ($kind -eq 'angle') {
      $status = 'OK-STDLIB'
      $reason = 'angle-include: MQL5 standard library (resolves under MetaQuotes\Terminal\...\MQL5\Include, never under this repo)'
    } else {
      # resolve: (1) relative to including file's own directory (real MQL5 order),
      # then (2) relative to ea_template\ root (a few legacy-style includes use this).
      $cand1 = Join-Path $f.DirectoryName $incPath
      $cand2 = Join-Path $TemplateRoot $incPath
      if (Test-Path -LiteralPath $cand1) {
        $resolvedPath = (Resolve-Path -LiteralPath $cand1).Path
      } elseif (Test-Path -LiteralPath $cand2) {
        $resolvedPath = (Resolve-Path -LiteralPath $cand2).Path
      }

      if ($resolvedPath) {
        $marker = Test-ForbiddenMarker $resolvedPath
        $insideTemplate = $resolvedPath.ToLowerInvariant().StartsWith($TemplateRoot.ToLowerInvariant() + '\') -or
                          $resolvedPath.ToLowerInvariant() -eq $TemplateRoot.ToLowerInvariant()
        if ($marker) {
          $status = 'FORBIDDEN'
          $reason = "resolved path touches forbidden marker '$marker': $resolvedPath"
        } elseif ($insideTemplate) {
          $status = 'OK'
          $reason = "resolves inside ea_template: $($resolvedPath.Substring($repoRoot.Length + 1))"
        } elseif ($scope -eq 'runtime') {
          $status = 'FORBIDDEN'
          $reason = "runtime-scope file resolves OUTSIDE ea_template\ (must stay inside): $resolvedPath"
        } else {
          # test-support, resolves outside ea_template but inside repo, no forbidden marker
          $status = 'OK-TEST-SUPPORT'
          $reason = "test-support include resolves outside ea_template but inside repo (documented copy-at-deploy-time pattern, see run_tests.ps1): $($resolvedPath.Substring($repoRoot.Length + 1))"
        }
      } else {
        $marker = Test-ForbiddenMarker $incPath
        if ($marker) {
          $status = 'FORBIDDEN'
          $reason = "unresolved on disk, but literal include string references forbidden marker '$marker': $incPath"
        } elseif ($scope -eq 'test-support') {
          $status = 'UNRESOLVED-TEST-SUPPORT'
          $reason = "not found relative to file or ea_template root at scan time - expected for tests\ helper files staged only at deploy time (run_tests.ps1 copies NewsGuard_Core.mqh / AccountSnapshot_Core.mqh in); literal string is clean"
        } else {
          $status = 'UNRESOLVED'
          $reason = "not found relative to file or ea_template root - compile-time concern, not a boundary violation (literal string is clean)"
        }
      }
    }

    $statusCounts[$status] = ($statusCounts[$status] | ForEach-Object { $_ }) + 1
    if (-not $statusCounts[$status]) { $statusCounts[$status] = 1 }

    $entry = [pscustomobject]@{
      File    = $relFile
      Line    = $lineNo
      Include = $incPath
      Kind    = $kind
      Status  = $status
      Reason  = $reason
    }
    $entries.Add($entry) | Out-Null

    if ($status -eq 'FORBIDDEN') {
      $violations.Add($entry) | Out-Null
    }
  }

  $graph.Add([pscustomobject]@{
    File    = $relFile
    Scope   = $scope
    Entries = $entries
  }) | Out-Null
}

# --- console summary ---------------------------------------------------------
Write-Host "=== ORDER-163 dependency audit: ea_template\ ===" -ForegroundColor Cyan
Write-Host "Template root : $TemplateRoot"
Write-Host "Files scanned : $($allFiles.Count) ($($mq5Files.Count) .mq5, $($mqhFiles.Count) .mqh)"
Write-Host "Includes found: $totalIncludes"
Write-Host ""
Write-Host "-- status breakdown --"
foreach ($k in ($statusCounts.Keys | Sort-Object)) {
  Write-Host ("  {0,-26} {1}" -f $k, $statusCounts[$k])
}
Write-Host ""

if (-not $Quiet) {
  Write-Host "-- full include list --"
  foreach ($g in $graph) {
    if ($g.Entries.Count -eq 0) { continue }
    Write-Host "[$($g.Scope)] $($g.File)" -ForegroundColor DarkCyan
    foreach ($e in $g.Entries) {
      $color = switch ($e.Status) {
        'FORBIDDEN' { 'Red' }
        { $_ -like 'OK*' } { 'Green' }
        default { 'Yellow' }
      }
      Write-Host ("    L{0,-4} {1,-12} {2}" -f $e.Line, $e.Status, $e.Include) -ForegroundColor $color
    }
  }
  Write-Host ""
}

if ($violations.Count -gt 0) {
  Write-Host "=== FORBIDDEN DEPENDENCIES FOUND: $($violations.Count) ===" -ForegroundColor Red
  foreach ($v in $violations) {
    Write-Host ("  {0}:{1}  ->  #include ""{2}""" -f $v.File, $v.Line, $v.Include) -ForegroundColor Red
    Write-Host ("      reason: {0}" -f $v.Reason) -ForegroundColor Red
  }
} else {
  Write-Host "=== CLEAN: 0 forbidden dependencies. Boss V2 (ea_template\) does not depend on EA_CORE V1 / D:\EA_Project / any archive path. ===" -ForegroundColor Green
}

# --- dependency graph report --------------------------------------------------
$reportDir = Split-Path -Parent $GraphReport
if (-not (Test-Path -LiteralPath $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }

$bt = [char]96   # backtick, built at runtime so it is never treated as a PowerShell escape char in a "..." literal
$nowStr = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# ORDER-163 Dependency Graph - ea_template\ (Boss V2)')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Generated by ' + $bt + 'scripts/check_template_dependencies.ps1' + $bt + ' - ' + $nowStr)
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Audit-only report (CORE-002 / ORDER-163). Every ' + $bt + '.mq5' + $bt + '/' + $bt + '.mqh' + $bt + ' under ' + $bt + 'ea_template\' + $bt + ' mapped to its full ' + $bt + '#include' + $bt + ' list, resolution, and classification. No files were modified to produce this report.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('**Summary:** ' + $allFiles.Count + ' files scanned (' + $mq5Files.Count + ' .mq5, ' + $mqhFiles.Count + ' .mqh), ' + $totalIncludes + ' include directives, **' + $violations.Count + ' FORBIDDEN**.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Status legend: ' + $bt + 'OK' + $bt + '/' + $bt + 'OK-STDLIB' + $bt + '/' + $bt + 'OK-TEST-SUPPORT' + $bt + ' = clean; ' + $bt + 'UNRESOLVED' + $bt + '/' + $bt + 'UNRESOLVED-TEST-SUPPORT' + $bt + ' = not found on disk at scan time, literal string clean (compile-time concern, not a boundary leak); ' + $bt + 'FORBIDDEN' + $bt + ' = touches EA_CORE / D:\EA_Project / archive, or a runtime-scope file reaching outside ' + $bt + 'ea_template\' + $bt + '.')
[void]$sb.AppendLine('')

if ($violations.Count -gt 0) {
  [void]$sb.AppendLine("## FORBIDDEN dependencies")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("| File | Line | Include | Reason |")
  [void]$sb.AppendLine("|---|---|---|---|")
  foreach ($v in $violations) {
    [void]$sb.AppendLine('| ' + $bt + $v.File + $bt + ' | ' + $v.Line + ' | ' + $bt + $v.Include + $bt + ' | ' + $v.Reason + ' |')
  }
  [void]$sb.AppendLine("")
} else {
  [void]$sb.AppendLine("## FORBIDDEN dependencies")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine('None found. Boss V2 (' + $bt + 'ea_template\' + $bt + ') does not depend on EA_CORE V1, ' + $bt + 'D:\EA_Project' + $bt + ', or any archive path.')
  [void]$sb.AppendLine("")
}

[void]$sb.AppendLine("## Full graph")
[void]$sb.AppendLine("")
foreach ($g in $graph) {
  [void]$sb.AppendLine('### [' + $g.Scope + '] ' + $bt + $g.File + $bt)
  if ($g.Entries.Count -eq 0) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("_no #include directives_")
    [void]$sb.AppendLine("")
    continue
  }
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("| Line | Kind | Include | Status | Reason |")
  [void]$sb.AppendLine("|---|---|---|---|---|")
  foreach ($e in $g.Entries) {
    [void]$sb.AppendLine('| ' + $e.Line + ' | ' + $e.Kind + ' | ' + $bt + $e.Include + $bt + ' | ' + $e.Status + ' | ' + $e.Reason + ' |')
  }
  [void]$sb.AppendLine("")
}

Set-Content -LiteralPath $GraphReport -Value $sb.ToString() -Encoding UTF8
Write-Host ""
Write-Host "Dependency graph written -> $GraphReport" -ForegroundColor Cyan

if ($violations.Count -gt 0) { exit 1 }
exit 0
