param(
    [string]$LabRoot = "D:\EA_LAB",
    [string]$ProjectName = "",
    [switch]$Execute,
    [switch]$IncludeRejected,
    [switch]$CompressArchive,
    [int]$KeepLatestPerKind = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[cleanup] $Message"
}

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        if ($Execute) {
            New-Item -ItemType Directory -Force -Path $Path | Out-Null
        }
        Write-Step "mkdir $Path"
    }
}

function Copy-Safe {
    param(
        [string]$Source,
        [string]$Destination
    )
    Ensure-Dir (Split-Path -Parent $Destination)
    if ($Execute) {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
    Write-Step "copy `"$Source`" -> `"$Destination`""
}

function Move-Safe {
    param(
        [string]$Source,
        [string]$Destination
    )
    Ensure-Dir (Split-Path -Parent $Destination)
    if ($Execute) {
        if (Test-Path -LiteralPath $Destination) {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($Destination)
            $ext = [System.IO.Path]::GetExtension($Destination)
            $dir = Split-Path -Parent $Destination
            $Destination = Join-Path $dir ("{0}_{1}{2}" -f $base, (Get-Date -Format "HHmmssfff"), $ext)
        }
        Move-Item -LiteralPath $Source -Destination $Destination
    }
    Write-Step "archive `"$Source`" -> `"$Destination`""
}

function Remove-Safe {
    param([string]$Path)
    if ($Execute) {
        Remove-Item -LiteralPath $Path -Force
    }
    Write-Step "remove duplicate `"$Path`""
}

function Get-ProjectList {
    param([string]$Root, [string]$Name)
    $projectsRoot = Join-Path $Root "ea_projects"
    if (-not (Test-Path -LiteralPath $projectsRoot)) {
        throw "Missing ea_projects folder: $projectsRoot"
    }
    if ($Name.Trim().Length -gt 0) {
        $projectPath = Join-Path $projectsRoot $Name
        if (-not (Test-Path -LiteralPath $projectPath)) {
            throw "Project not found: $projectPath"
        }
        return @(Get-Item -LiteralPath $projectPath)
    }
    return @(Get-ChildItem -LiteralPath $projectsRoot -Directory | Where-Object { $_.Name -ne "_template" })
}

function Get-ReportKind {
    param([System.IO.FileInfo]$File)
    $path = $File.FullName.ToLowerInvariant()
    if ($path -match "forward") { return "forward" }
    if ($path -match "oos") { return "oos" }
    if ($path -match "backtest|manual_runs|single|run_") { return "backtest" }
    return "report"
}

function Get-LatestReports {
    param([string]$ProjectPath)
    $reportFiles = Get-ChildItem -LiteralPath $ProjectPath -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in @(".html", ".htm") -and
            $_.Name -match "ReportTester|StrategyTester|report" -and
            $_.FullName -notmatch "\\ARCHIVE\\|\\ACTIVE\\|\\SYSTEM\\|\\portfolio\\candidates\\|\\reports\\latest\\"
        }

    $latest = @{}
    foreach ($file in $reportFiles) {
        $kind = Get-ReportKind $file
        if (-not $latest.ContainsKey($kind)) {
            $latest[$kind] = @()
        }
        $latest[$kind] += $file
    }
    return $latest
}

function Get-CurrentSetFiles {
    param([string]$ProjectPath)
    $candidateSets = Get-ChildItem -LiteralPath $ProjectPath -Recurse -File -Filter "*.set" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -match "\\portfolio\\candidates\\|\\set\\" -and
            $_.FullName -notmatch "\\ARCHIVE\\|\\ACTIVE\\|\\SYSTEM\\"
        } |
        Sort-Object LastWriteTime -Descending
    return @($candidateSets)
}

function Copy-ActiveSnapshot {
    param(
        [System.IO.DirectoryInfo]$Project,
        [string]$ActiveRoot
    )
    $projectActive = Join-Path $ActiveRoot ("projects\" + $Project.Name)
    Ensure-Dir $projectActive
    foreach ($sub in @("reports", "sets", "source", "candidates", "summaries")) {
        Ensure-Dir (Join-Path $projectActive $sub)
    }

    $latestByKind = Get-LatestReports $Project.FullName
    foreach ($kind in @("backtest", "forward", "oos")) {
        if ($latestByKind.ContainsKey($kind)) {
            $selected = @($latestByKind[$kind] | Sort-Object LastWriteTime -Descending | Select-Object -First $KeepLatestPerKind)
            if ($selected.Count -gt 0) {
                $destName = switch ($kind) {
                    "backtest" { "latest_backtest.html" }
                    "forward" { "latest_forward.html" }
                    "oos" { "latest_oos.html" }
                    default { "latest_report.html" }
                }
                Copy-Safe $selected[0].FullName (Join-Path $projectActive ("reports\" + $destName))
            }
        }
    }

    if (-not $latestByKind.ContainsKey("oos") -and $latestByKind.ContainsKey("forward")) {
        $selectedForward = @($latestByKind["forward"] | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
        if ($selectedForward.Count -gt 0) {
            Copy-Safe $selectedForward[0].FullName (Join-Path $projectActive "reports\latest_oos.html")
        }
    }

    $sets = Get-CurrentSetFiles $Project.FullName
    foreach ($set in $sets) {
        if ($set.FullName -match "\\portfolio\\candidates\\" -or $set.Name -match "opt|current|validated|oos|run004|run_004") {
            Copy-Safe $set.FullName (Join-Path $projectActive ("sets\" + $set.Name))
        }
    }

    $sourceTokens = @($sets | ForEach-Object {
        ([System.IO.Path]::GetFileNameWithoutExtension($_.Name) -replace "_opt\d+$", "" -replace "_current$", "")
    } | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -Unique)
    $sourceFiles = Get-ChildItem -LiteralPath $Project.FullName -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in @(".mq5", ".mq4", ".ex5", ".ex4") -and
            $_.FullName -notmatch "\\ARCHIVE\\|\\ACTIVE\\|\\SYSTEM\\|\\portfolio\\candidates\\" -and
            (
                $sourceTokens.Count -eq 0 -or
                $sourceTokens -contains [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            )
        }
    foreach ($source in $sourceFiles) {
        Copy-Safe $source.FullName (Join-Path $projectActive ("source\" + $source.Name))
    }

    $candidateDirs = Get-ChildItem -LiteralPath (Join-Path $Project.FullName "portfolio\candidates") -Directory -ErrorAction SilentlyContinue
    foreach ($candidate in $candidateDirs) {
        if ($candidate.Name -match "VALIDATED|RUN|CURRENT|LIVE|APPROVED") {
            $dest = Join-Path $projectActive ("candidates\" + $candidate.Name)
            Ensure-Dir $dest
            if ($Execute) {
                Get-ChildItem -LiteralPath $candidate.FullName -Force |
                    Copy-Item -Destination $dest -Recurse -Force
            }
            Write-Step "copy candidate `"$($candidate.FullName)`" -> `"$dest`""
        }
    }

    $summaryCandidates = Get-ChildItem -LiteralPath $Project.FullName -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -eq ".md" -and
            $_.Name -match "summary|README|status|decision|review|next_steps" -and
            $_.FullName -notmatch "\\ARCHIVE\\|\\ACTIVE\\|\\SYSTEM\\"
        } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    foreach ($summary in $summaryCandidates) {
        Copy-Safe $summary.FullName (Join-Path $projectActive "summaries\latest_summary.md")
    }
}

function Archive-OldArtifacts {
    param(
        [System.IO.DirectoryInfo]$Project,
        [string]$ArchiveRoot
    )
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $projectArchive = Join-Path $ArchiveRoot ("projects\" + $Project.Name + "\" + $stamp)
    $archivedAny = $false

    $archivePatterns = @(
        "\\optimization\\raw_results\\",
        "\\optimization\\analyzed\\",
        "\\optimization\\candidates\\",
        "\\backtest\\manual_runs\\run_",
        "\\reports\\collected\\",
        "\\reports\\latest\\",
        "\\reports\\run_",
        "\\Forward test\\"
    )

    $artifactExtensions = @(".html", ".htm", ".xlsx", ".xml", ".png", ".gif", ".csv", ".log", ".txt", ".json")
    $files = Get-ChildItem -LiteralPath $Project.FullName -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in $artifactExtensions -and
            $_.FullName -notmatch "\\ARCHIVE\\|\\ACTIVE\\|\\SYSTEM\\|\\portfolio\\candidates\\" -and
            $_.FullName -notmatch "\\source\\"
        }

    foreach ($file in $files) {
        $shouldArchive = $false
        foreach ($pattern in $archivePatterns) {
            if ($file.FullName -match $pattern) {
                $shouldArchive = $true
                break
            }
        }
        if (-not $shouldArchive -and $file.Name -match "ReportTester|ReportOptimizer|StrategyTester|testergraph") {
            $shouldArchive = $true
        }
        if ($shouldArchive) {
            $relative = $file.FullName.Substring($Project.FullName.Length).TrimStart("\")
            $dest = Join-Path $projectArchive $relative
            $archivedAny = $true
            Move-Safe $file.FullName $dest
        }
    }

    if ($IncludeRejected) {
        $rejectedDirs = Get-ChildItem -LiteralPath (Join-Path $Project.FullName "portfolio\candidates") -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "REJECT|FAILED|WATCH" }
        foreach ($dir in $rejectedDirs) {
            $dest = Join-Path $projectArchive ("rejected_candidates\" + $dir.Name)
            $archivedAny = $true
            Move-Safe $dir.FullName $dest
        }
    }

    if ($archivedAny) {
        return $projectArchive
    }

    Write-Step "archive empty: no old artifacts found for $($Project.Name)"
    return $null
}

function Compress-ArchiveBatch {
    param([string]$ArchivePath)
    if (-not $CompressArchive) { return }
    if ([string]::IsNullOrWhiteSpace($ArchivePath)) { return }
    $zipPath = "$ArchivePath.zip"
    if ($Execute -and (Test-Path -LiteralPath $ArchivePath)) {
        Compress-Archive -LiteralPath $ArchivePath -DestinationPath $zipPath -Force
        Write-Step "compressed archive batch -> `"$zipPath`""
    } else {
        Write-Step "compress archive batch -> `"$zipPath`""
    }
}

function Remove-DuplicateReportsInArchive {
    param([string]$ArchiveRoot)
    if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) { return }
    if (-not (Test-Path -LiteralPath $ArchiveRoot)) { return }
    $groups = Get-ChildItem -LiteralPath $ArchiveRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @(".html", ".htm", ".xlsx", ".xml", ".png", ".csv") } |
        Get-FileHash -Algorithm SHA1 |
        Group-Object Hash |
        Where-Object { $_.Count -gt 1 }

    foreach ($group in $groups) {
        $items = @($group.Group | Sort-Object Path)
        $keeper = $items[0]
        foreach ($dupe in $items | Select-Object -Skip 1) {
            Remove-Safe $dupe.Path
        }
        Write-Step "kept duplicate source `"$($keeper.Path)`""
    }
}

function Write-Manifest {
    param(
        [string]$Root,
        [System.IO.DirectoryInfo[]]$Projects
    )
    $manifestPath = Join-Path $Root ("SYSTEM\manifests\cleanup_manifest_{0}.csv" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
    $rows = foreach ($project in $Projects) {
        $activePath = Join-Path $Root ("ACTIVE\projects\" + $project.Name)
        [PSCustomObject]@{
            project = $project.Name
            active_path = $activePath
            active_reports = @(Get-ChildItem -LiteralPath (Join-Path $activePath "reports") -File -ErrorAction SilentlyContinue).Count
            active_sets = @(Get-ChildItem -LiteralPath (Join-Path $activePath "sets") -File -ErrorAction SilentlyContinue).Count
            active_candidates = @(Get-ChildItem -LiteralPath (Join-Path $activePath "candidates") -Directory -ErrorAction SilentlyContinue).Count
            generated_at = (Get-Date).ToString("s")
        }
    }
    if ($Execute) {
        $rows | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8
    }
    Write-Step "manifest $manifestPath"
}

$LabRoot = (Resolve-Path -LiteralPath $LabRoot).Path
$activeRoot = Join-Path $LabRoot "ACTIVE"
$archiveRoot = Join-Path $LabRoot "ARCHIVE"
$systemRoot = Join-Path $LabRoot "SYSTEM"

foreach ($dir in @($activeRoot, $archiveRoot, $systemRoot, (Join-Path $systemRoot "rules"), (Join-Path $systemRoot "logs"), (Join-Path $systemRoot "manifests"))) {
    Ensure-Dir $dir
}

$projects = Get-ProjectList $LabRoot $ProjectName
Write-Step ("mode: " + ($(if ($Execute) { "EXECUTE" } else { "DRY-RUN" })))
Write-Step ("projects: " + (($projects | ForEach-Object { $_.Name }) -join ", "))

foreach ($project in $projects) {
    Write-Step "processing project $($project.Name)"
    Copy-ActiveSnapshot $project $activeRoot
    $archivePath = Archive-OldArtifacts $project $archiveRoot
    Remove-DuplicateReportsInArchive $archivePath
    Compress-ArchiveBatch $archivePath
}

Write-Manifest $LabRoot $projects

if (-not $Execute) {
    Write-Host ""
    Write-Host "Dry-run only. Re-run with -Execute to copy ACTIVE snapshots, archive old artifacts, and remove exact duplicates inside ARCHIVE."
}
