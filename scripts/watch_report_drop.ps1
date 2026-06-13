param(
    [string]$Project = "",
    [ValidateSet("auto", "baseline", "risk_cap_validation", "optimization", "oos")]
    [string]$RunType = "auto",
    [string]$DropFolder = "",
    [int]$IntervalSeconds = 10,
    [switch]$Once,
    [switch]$AllowSingleProjectFallback
)

$ErrorActionPreference = "Stop"

function Get-SafeName {
    param([string]$Text)
    if (-not $Text) { return "unknown" }
    $safe = $Text -replace '[\\/:*?"<>|,\s]+', '_'
    $safe = $safe.Trim('_')
    if ($safe.Length -gt 60) { $safe = $safe.Substring(0, 60).Trim('_') }
    return $safe
}

function Get-HtmlCells {
    param([string]$Path)
    $raw = Get-Content -Raw -LiteralPath $Path
    $matches = [regex]::Matches($raw, '<t[dh][^>]*>(.*?)</t[dh]>', 'Singleline,IgnoreCase')
    $cells = New-Object System.Collections.Generic.List[string]
    foreach ($match in $matches) {
        $cell = $match.Groups[1].Value
        $cell = $cell -replace '<[^>]+>', ' '
        $cell = $cell -replace '&nbsp;', ' '
        $cell = $cell -replace '&amp;', '&'
        $cell = $cell -replace '\s+', ' '
        $cell = $cell.Trim()
        if ($cell) { $cells.Add($cell) }
    }
    return $cells
}

function Get-CellMetric {
    param(
        [System.Collections.Generic.List[string]]$Cells,
        [string]$Label
    )
    for ($i = 0; $i -lt $Cells.Count - 1; $i++) {
        if ($Cells[$i] -eq $Label) { return $Cells[$i + 1] }
    }
    return ""
}

function Get-EaNameFromReport {
    param([System.IO.FileInfo]$File)

    if ($File.Extension -in @(".html", ".htm")) {
        try {
            $cells = Get-HtmlCells -Path $File.FullName
            $expert = Get-CellMetric -Cells $cells -Label "Expert:"
            if ($expert) { return $expert }
        }
        catch {}
    }
    if ($File.Extension -eq ".xml") {
        try {
            $text = Get-Content -Raw -LiteralPath $File.FullName
            $match = [regex]::Match($text, '<Title>(.*?)</Title>')
            if ($match.Success) {
                return (($match.Groups[1].Value -replace '\s+[A-Z0-9._-]+,[A-Z0-9]+\s+.*$', '').Trim())
            }
        }
        catch {}
    }
    return ""
}

function Get-DetectedRunType {
    param(
        [System.IO.FileInfo]$File,
        [string]$RequestedRunType
    )
    if ($RequestedRunType -ne "auto") { return $RequestedRunType }
    if ($File.Name -like "ReportOptimizer*.xml" -or $File.Name -match "optimizer|optimization") {
        return "optimization"
    }
    if ($File.FullName -match '\\oos\\') { return "oos" }
    if ($File.FullName -match '\\single\\') { return "risk_cap_validation" }
    return "baseline"
}

function Resolve-ProjectForFile {
    param(
        [string]$Root,
        [string]$RequestedProject,
        [string]$EaName
    )
    $projectsRoot = Join-Path $Root "ea_projects"
    $projects = @(Get-ChildItem -LiteralPath $projectsRoot -Directory |
        Where-Object { $_.Name -ne "_template" } |
        Sort-Object Name)

    if ($RequestedProject) {
        $path = Join-Path $projectsRoot $RequestedProject
        if (Test-Path -LiteralPath $path -PathType Container) { return $RequestedProject }
        throw "Requested project not found: $RequestedProject"
    }

    if ($EaName) {
        foreach ($project in $projects) {
            if ($project.Name -eq $EaName -or $project.Name -like "*$EaName*" -or $EaName -like "*$($project.Name)*") {
                return $project.Name
            }
            $mq5Match = Get-ChildItem -LiteralPath $project.FullName -Recurse -File -Filter "*.mq5" -ErrorAction SilentlyContinue |
                Where-Object { $_.BaseName -eq $EaName -or $_.Name -like "*$EaName*" } |
                Select-Object -First 1
            if ($mq5Match) { return $project.Name }
        }
    }

    if ($AllowSingleProjectFallback -and $projects.Count -eq 1) {
        return $projects[0].Name
    }

    return ""
}

function Get-StateKey {
    param([System.IO.FileInfo]$File)
    return "$($File.FullName)|$($File.Length)|$($File.LastWriteTimeUtc.ToString('o'))"
}

function Load-State {
    param([string]$Path)
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    if (Test-Path -LiteralPath $Path) {
        foreach ($line in Get-Content -LiteralPath $Path) {
            if ($line) { [void]$set.Add($line) }
        }
    }
    return $set
}

function Save-StateKey {
    param([string]$Path, [string]$Key)
    Add-Content -LiteralPath $Path -Value $Key -Encoding UTF8
}

function Get-MainReportFiles {
    param([string]$Folder)
    $patterns = @("ReportTester*.html", "report.html", "ReportOptimizer*.xml", "*optimizer*.xml", "*optimizer*.csv", "*optimization*.csv")
    $files = foreach ($pattern in $patterns) {
        Get-ChildItem -LiteralPath $Folder -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue
    }
    return @($files | Where-Object { $_.FullName -notmatch '\\_needs_project\\' -and $_.FullName -notmatch '\\_logs\\' } | Sort-Object LastWriteTime)
}

function Register-NeedsProject {
    param(
        [string]$DropFolder,
        [System.IO.FileInfo]$File,
        [string]$EaName
    )
    $needs = Join-Path $DropFolder "_needs_project"
    New-Item -ItemType Directory -Force -Path $needs | Out-Null
    $note = Join-Path $needs ("NEEDS_PROJECT_{0}_{1}.txt" -f (Get-SafeName $File.BaseName), (Get-Date -Format "yyyyMMdd_HHmmss"))
    @"
EA_LAB could not infer the target project.

file: $($File.FullName)
ea_name_detected: $EaName

Run manually:
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\collect_mt5_reports.ps1" -Project "PROJECT_NAME" -RunId "manual_RUN_ID" -RunType baseline -SourceFolder "$($File.DirectoryName)"
"@ | Set-Content -LiteralPath $note -Encoding UTF8
    return $note
}

$Root = Split-Path -Parent $PSScriptRoot
if (-not $DropFolder) {
    $DropFolder = Join-Path $Root "_mt5_report_drop"
}
New-Item -ItemType Directory -Force -Path $DropFolder | Out-Null
foreach ($sub in @("single", "optimization", "oos", "_needs_project", "_logs")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $DropFolder $sub) | Out-Null
}

$StatePath = Join-Path $DropFolder "_logs\watch_state.txt"
if (-not (Test-Path -LiteralPath $StatePath)) {
    New-Item -ItemType File -Force -Path $StatePath | Out-Null
}
$HeartbeatPath = Join-Path $DropFolder "_logs\watch_heartbeat.txt"
Write-Host "EA_LAB Report Drop Watcher"
Write-Host "Drop folder: $DropFolder"
Write-Host "Project: $(if ($Project) { $Project } else { 'auto-detect' })"
Write-Host "Run type: $RunType"
Write-Host "Interval seconds: $IntervalSeconds"
Write-Host "Mode: $(if ($Once) { 'one scan' } else { 'watch loop' })"
Write-Host "Waiting for: ReportTester*.html, report.html, ReportOptimizer*.xml, optimizer CSV"
Write-Host "Put files into: single\, optimization\, or oos\ under the drop folder"
Write-Host "Stop watcher: Ctrl+C"
Write-Host ""

do {
    $state = Load-State -Path $StatePath
    $files = Get-MainReportFiles -Folder $DropFolder
    $newFiles = @($files | Where-Object { -not $state.Contains((Get-StateKey -File $_)) })
    $heartbeat = "{0} waiting; known_files={1}; new_files={2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $files.Count, $newFiles.Count
    $heartbeat | Set-Content -LiteralPath $HeartbeatPath -Encoding UTF8
    if ($newFiles.Count -eq 0) {
        Write-Host $heartbeat
    }
    foreach ($file in $newFiles) {
        $key = Get-StateKey -File $file

        $eaName = Get-EaNameFromReport -File $file
        $targetProject = Resolve-ProjectForFile -Root $Root -RequestedProject $Project -EaName $eaName
        if (-not $targetProject) {
            $note = Register-NeedsProject -DropFolder $DropFolder -File $file -EaName $eaName
            Save-StateKey -Path $StatePath -Key $key
            Write-Host "Needs project: $($file.Name)"
            Write-Host "Note: $note"
            continue
        }

        $detectedRunType = Get-DetectedRunType -File $file -RequestedRunType $RunType
        $summaryMode = if ($detectedRunType -eq "optimization") { "optimization" } else { "single" }
        $runId = "auto_{0}_{1}_{2}" -f $detectedRunType, (Get-Date -Format "yyyyMMdd_HHmmss"), (Get-SafeName $eaName)

        Write-Host "Collecting: $($file.FullName)"
        Write-Host "Target project: $targetProject"
        Write-Host "Run ID: $runId"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "collect_mt5_reports.ps1") `
            -Project $targetProject `
            -RunId $runId `
            -RunType $detectedRunType `
            -SourceFolder $file.DirectoryName `
            -ReportPath $file.FullName `
            -Notes "Auto-collected by watch_report_drop.ps1" `
            -Force | Out-Host

        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "quick_report_collector.ps1") `
            -Project $targetProject `
            -Mode $summaryMode | Out-Host

        Save-StateKey -Path $StatePath -Key $key
        Write-Host "Done: $($file.Name)"
        Write-Host ""
    }

    if (-not $Once) {
        Start-Sleep -Seconds $IntervalSeconds
    }
} while (-not $Once)
