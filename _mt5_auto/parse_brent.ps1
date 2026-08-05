[xml]$xml = Get-Content "D:\EA_LAB\_mt5_auto\optimizations\O542_BRENT_coarse.xml"
$ns = New-Object Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace("ss", "urn:schemas-microsoft-com:office:spreadsheet")
$rows = $xml.SelectNodes("//ss:Row", $ns)

$top = @()
for ($i = 1; $i -lt $rows.Count; $i++) {
    $cells = $rows[$i].SelectNodes("ss:Cell", $ns)
    $vals = @()
    foreach ($c in $cells) { $v = $c.InnerText.Trim(); $v = $v -replace '<[^>]+>',''; $vals += $v }
    if ($vals.Count -gt 15) {
        $pf = 0; $tr = 0; $dd = 0; $pr = 0
        if ($vals[4] -match '^\d') { $pf = [double]$vals[4] }
        if ($vals[9] -match '^\d') { $tr = [int]$vals[9] }
        if ($vals[8] -match '^\d') { $dd = [double]$vals[8] }
        if ($vals[2] -match '^\d') { $pr = [double]$vals[2] }
        $top += [PSCustomObject]@{ PF=$pf; Trades=$tr; DD=$dd; Profit=$pr; AtrPeriod=$vals[10]; Mult=$vals[11]; ExitMode=$vals[12]; TpAtrMult=$vals[13]; SlAtrMult=$vals[14]; UseEma=$vals[15]; EmaPeriod=$vals[16] }
    }
}
$sorted = $top | Sort-Object PF -Descending
Write-Output "Top 10 by PF:"
for ($i = 0; $i -lt 10 -and $i -lt $sorted.Count; $i++) {
    $r = $sorted[$i]
    Write-Output ("PF=" + $r.PF + " Profit=" + $r.Profit + " Trades=" + $r.Trades + " DD=" + $r.DD + "% | AtrP=" + $r.AtrPeriod + " Mult=" + $r.Mult + " Exit=" + $r.ExitMode + " TpAtr=" + $r.TpAtrMult + " SlAtr=" + $r.SlAtrMult + " UseEma=" + $r.UseEma + " EmaP=" + $r.EmaPeriod)
}
