param([string]$ReportPath)

$lines = Get-Content $ReportPath -Encoding unicode
$pf = ""; $trades = ""; $dd = ""; $net = ""; $shortT = ""; $longT = ""

for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    $next = if ($i + 1 -lt $lines.Length) { $lines[$i + 1] } else { "" }

    if ($line -match 'Profit Factor:') {
        if ($next -match '>([\d.]+)<') { $pf = $Matches[1] }
    }
    if ($line -match 'Total Trades:') {
        if ($next -match '>(\d+)<') { $trades = $Matches[1] }
    }
    if ($line -match 'Balance Drawdown Maximal:') {
        if ($next -match '\(([\d.]+)%\)') { $dd = $Matches[1] }
    }
    if ($line -match 'Total Net Profit:') {
        if ($next -match '>(-?[\d,. ]+)<') { $net = ($Matches[1] -replace ' ', '') }
    }
    if ($line -match 'Short Trades') {
        if ($next -match '>(\d+)\s') { $shortT = $Matches[1] }
    }
    if ($line -match 'Long Trades') {
        if ($next -match '>(\d+)\s') { $longT = $Matches[1] }
    }
}

Write-Output "PF=$pf"
Write-Output "Trades=$trades"
Write-Output "DD=$dd"
Write-Output "Net=$net"
Write-Output "Short=$shortT"
Write-Output "Long=$longT"