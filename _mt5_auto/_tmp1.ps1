$html = Get-Content "D:\EA_LAB\_mt5_auto\reports\O236_XAU_CTRL_MAIN.htm" -Raw -Encoding UTF8
$text = $html -replace "<[^>]+>", "" -replace "&nbsp;", " " -replace "&amp;", "&" -replace "&lt;", "<" -replace "&gt;", ">"
Write-Output $text.Substring(0, [Math]::Min(3000, $text.Length))
