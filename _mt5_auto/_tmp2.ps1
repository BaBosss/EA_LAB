$html = Get-Content "D:\EA_LAB\_mt5_auto\reports\O236_XAU_CTRL_MAIN.htm" -Raw -Encoding UTF8
$text = $html -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '\s+', ' '

$patterns = @{
    "Profit Factor" = "Profit Factor:"
    "Total Trades" = "Total Trades:"
    "Total Net Profit" = "Total Net Profit:"
    "Gross Profit" = "Gross Profit:"
    "Gross Loss" = "Gross Loss:"
    "Equity Drawdown Maximal" = "Equity Drawdown Maximal:"
    "Leverage" = "Leverage:"
    "Expected Payoff" = "Expected Payoff:"
    "Sharpe Ratio" = "Sharpe Ratio:"
    "Recovery Factor" = "Recovery Factor:"
    "Total Deals" = "Total Deals:"
    "Short Trades" = "Short Trades (won %):"
    "Long Trades" = "Long Trades (won %):"
    "Profit Trades" = "Profit Trades (% of total):"
    "Loss Trades" = "Loss Trades (% of total):"
    "Largest Profit" = "Largest profit trade:"
    "Largest Loss" = "Largest loss trade:"
    "Avg Profit Trade" = "Avg profit trade:"
    "Avg Loss Trade" = "Avg loss trade:"
}

foreach ($key in $patterns.Keys) {
    $pattern = $patterns[$key]
    $idx = $text.IndexOf($pattern)
    if ($idx -ge 0) {
        $rest = $text.Substring($idx + $pattern.Length).Trim()
        $nl = $rest.IndexOf(" ")
        if ($nl -gt 0 -and $nl -lt 200) {
            $val = $rest.Substring(0, $nl).Trim()
        } else {
            $val = $rest.Substring(0, [Math]::Min(150, $rest.Length)).Trim()
        }
        Write-Output "$key : $val"
    } else {
        Write-Output "$key : NOT FOUND"
    }
}
