$html = Get-Content "D:\EA_LAB\_mt5_auto\reports\O236_XAU_A_MAIN.htm" -Raw -Encoding UTF8
$text = $html -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>'
$idx = $text.IndexOf("Total Net Profit")
$section = $text.Substring([Math]::Max(0, $idx - 100), [Math]::Min(1600, $text.Length - $idx))
Write-Output "=== A_MAIN ==="
$fields = @("Profit Factor:", "Total Trades:", "Total Net Profit:", "Equity Drawdown Maximal:", "Balance Drawdown Maximal:")
foreach ($f in $fields) {
    $fi = $section.IndexOf($f)
    if ($fi -ge 0) {
        $rest = $section.Substring($fi + $f.Length).Trim()
        $nl = $rest.IndexOf("`n")
        $val = if ($nl -gt 0 -and $nl -lt 200) { $rest.Substring(0, $nl).Trim() } else { $rest.Substring(0, [Math]::Min(150, $rest.Length)).Trim() }
        Write-Output "  $f $val"
    }
}
