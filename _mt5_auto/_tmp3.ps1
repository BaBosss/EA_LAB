$html = Get-Content "D:\EA_LAB\_mt5_auto\reports\O236_XAU_CTRL_MAIN.htm" -Raw -Encoding UTF8
$text = $html -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>'

# Find the "Strategy Tester Report" section and extract from there
$idx = $text.IndexOf("Strategy Tester Report")
if ($idx -ge 0) {
    $report = $text.Substring($idx)
    # Get first ~5000 chars of the report section
    Write-Output $report.Substring(0, [Math]::Min(5000, $report.Length))
}
