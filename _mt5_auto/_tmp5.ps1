$html = Get-Content "D:\EA_LAB\_mt5_auto\reports\O236_XAU_CTRL_BWD.htm" -Raw -Encoding UTF8
$text = $html -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>'

$idx = $text.IndexOf("Total Net Profit")
if ($idx -ge 0) {
    $start = [Math]::Max(0, $idx - 200)
    $end = [Math]::Min($text.Length, $idx + 2000)
    Write-Output $text.Substring($start, $end - $start)
}
