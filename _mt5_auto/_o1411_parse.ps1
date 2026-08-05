$slValues = @(1.0, 1.5, 2.0, 2.5, 3.0)
$atrValues = @(7, 10, 14, 20, 28)
$reportDir = "D:\EA_LAB\_mt5_auto"
$reportsFolder = "D:\EA_LAB\_mt5_auto\reports"
$parseScript = "D:\EA_LAB\tools\python312\python.exe"
$parseArg = "D:\EA_LAB\scripts\parse_mt5_report.py"

# Read existing content (header + any rows already written)
$mdPath = "$reportDir\O1411_CELL2.md"
$existing = Get-Content $mdPath -Raw

foreach ($sl in $slValues) {
    foreach ($atr in $atrValues) {
        $rptName = "O1411_PVT2_Sl${sl}_Atr${atr}"
        $rptPath = "$reportsFolder\$rptName.htm"
        if (Test-Path $rptPath) {
            $result = & $parseScript $parseArg $rptPath
            Write-Host "$rptName -> $result"
            # Check if this row already exists to avoid duplicates
            $row = "| $sl | $atr | $result |"
            if (-not ($existing -match [regex]::Escape($row))) {
                Add-Content -Path $mdPath -Value $row
            } else {
                Write-Host "  (already in file, skipping)"
            }
        } else {
            Write-Host "$rptName -> REPORT NOT FOUND"
        }
    }
}
Write-Host "PARSING DONE"
