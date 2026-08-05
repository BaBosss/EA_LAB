$reports = Get-ChildItem "D:\EA_LAB\_mt5_auto\reports\O1420_*_SHORT.htm" -ErrorAction SilentlyContinue
foreach ($r in $reports) {
    $lines = Get-Content $r.FullName -Encoding unicode
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '_14_Direction') {
            Write-Output ($r.Name + " -> " + $lines[$i].Trim())
            break
        }
    }
}