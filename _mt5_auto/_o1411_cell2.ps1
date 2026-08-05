$slValues = @(1.0, 1.5, 2.0, 2.5, 3.0)
$atrValues = @(7, 10, 14, 20, 28)
$baseSet = "D:\EA_LAB\_mt5_auto\ab_sets\o1411\PVT_base.set"
$workDir = "D:\EA_LAB\_mt5_auto\ab_sets\o1411"
$reportDir = "D:\EA_LAB\_mt5_auto"
$mt5 = "D:\Meta 5c\terminal64.exe"
$dataDir = "D:\Meta 5c"
$mt5Script = "D:\EA_LAB\scripts\mt5_run.ps1"

foreach ($sl in $slValues) {
    foreach ($atr in $atrValues) {
        $rptName = "O1411_PVT2_Sl${sl}_Atr${atr}"
        $copySet = "$workDir\$rptName.set"
        Copy-Item $baseSet $copySet -Force
        $lines = Get-Content $copySet
        $lines = $lines -replace '_02_SlAtrMult\s*=\s*\S+', "_02_SlAtrMult=$sl"
        $lines = $lines -replace '_01_AtrPeriod\s*=\s*\S+', "_01_AtrPeriod=$atr"
        $lines | Set-Content $copySet
        Write-Host "RUN: $rptName (Sl=$sl, Atr=$atr)"
        $verif = Get-Content $copySet | Select-String "SlAtrMult|AtrPeriod"
        Write-Host "  VERIFY: $verif"
        & $mt5Script -Expert "PivotBreakout_XAU" -Symbol "USDJPY" -Period "H4" -FromDate "2023.01.01" -ToDate "2025.12.31" -Model 1 -SetFile $copySet -ReportName $rptName -Terminal $mt5 -DataDir $dataDir -Portable
        $rptPath = "$reportDir\reports\$rptName.htm"
        if (Test-Path $rptPath) {
            Write-Host "  OK REPORT: $rptPath"
        } else {
            Write-Host "  REPORT NOT FOUND: $rptPath"
        }
    }
}
Write-Host "ALL RUNS DONE"
