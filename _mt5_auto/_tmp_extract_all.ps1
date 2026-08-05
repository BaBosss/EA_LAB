$reports = @(
    @{Name="A_MAIN"; Path="D:\EA_LAB\_mt5_auto\reports\O236_XAU_A_MAIN.htm"},
    @{Name="A_BWD"; Path="D:\EA_LAB\_mt5_auto\reports\O236_XAU_A_BWD.htm"},
    @{Name="B_MAIN"; Path="D:\EA_LAB\_mt5_auto\reports\O236_XAU_B_MAIN.htm"},
    @{Name="B_BWD"; Path="D:\EA_LAB\_mt5_auto\reports\O236_XAU_B_BWD.htm"},
    @{Name="AB_MAIN"; Path="D:\EA_LAB\_mt5_auto\reports\O236_XAU_AB_MAIN.htm"},
    @{Name="AB_BWD"; Path="D:\EA_LAB\_mt5_auto\reports\O236_XAU_AB_BWD.htm"}
)

foreach ($r in $reports) {
    Write-Output "=== $r.Name ==="
    $html = Get-Content $r.Path -Raw -Encoding UTF8
    $text = $html -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>'
    
    $idx = $text.IndexOf("Total Net Profit")
    if ($idx -ge 0) {
        $start = [Math]::Max(0, $idx - 100)
        $end = [Math]::Min($text.Length, $idx + 1500)
        $section = $text.Substring($start, $end - $start)
        
        # Extract key values
        $fields = @("Profit Factor:", "Total Trades:", "Total Net Profit:", "Equity Drawdown Maximal:", "Balance Drawdown Maximal:")
        foreach ($f in $fields) {
            $fi = $section.IndexOf($f)
            if ($fi -ge 0) {
                $rest = $section.Substring($fi + $f.Length).Trim()
                $nl = $rest.IndexOf("`n")
                if ($nl -gt 0 -and $nl -lt 200) {
                    $val = $rest.Substring(0, $nl).Trim()
                } else {
                    $val = $rest.Substring(0, [Math]::Min(150, $rest.Length)).Trim()
                }
                Write-Output "  $f $val"
            }
        }
    }
    Write-Output ""
}
