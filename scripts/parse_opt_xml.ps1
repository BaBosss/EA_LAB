# parse_opt_xml.ps1 — read MT5 optimizer XML (SpreadsheetML), emit passes as objects.
param(
  [Parameter(Mandatory)][string]$Path,
  [double]$MinPF = 0,
  [int]$MinTrades = 0,
  [string]$SortBy = "PF",
  [int]$Top = 30
)
[xml]$doc = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
$ns = New-Object Xml.XmlNamespaceManager($doc.NameTable)
$ns.AddNamespace('ss','urn:schemas-microsoft-com:office:spreadsheet')
$rows = $doc.SelectNodes('//ss:Table/ss:Row', $ns)
# header
$hdr = @()
foreach ($c in $rows[0].SelectNodes('ss:Cell', $ns)) {
  $d = $c.SelectSingleNode('ss:Data', $ns)
  $hdr += if ($d) { $d.InnerText } else { '' }
}
$out = @()
for ($i=1; $i -lt $rows.Count; $i++) {
  $cells = $rows[$i].SelectNodes('ss:Cell', $ns)
  $vals = @{}
  $col = 0
  foreach ($c in $cells) {
    # honor ss:Index gaps
    $idxAttr = $c.GetAttribute('Index','urn:schemas-microsoft-com:office:spreadsheet')
    if ($idxAttr) { $col = [int]$idxAttr - 1 }
    $d = $c.SelectSingleNode('ss:Data', $ns)
    if ($col -lt $hdr.Count) { $vals[$hdr[$col]] = if ($d) { $d.InnerText } else { '' } }
    $col++
  }
  $out += [PSCustomObject]$vals
}
# normalize common columns
$norm = $out | ForEach-Object {
  [PSCustomObject]@{
    Pass   = $_.Pass
    PF     = [double]($_.'Profit Factor')
    Trades = [int]($_.'Trades')
    DD     = [double]($_.'Equity DD %')
    Sharpe = [double]($_.'Sharpe Ratio')
    Result = $_.Result
    StartHour    = $_.'_01_StartHour'
    RangeHours   = $_.'_01_RangeHours'
    TradeEndHour = $_.'_01_TradeEndHour'
    SlAtrMult    = $_.'_02_SlAtrMult'
    TpAtrMult    = $_.'_02_TpAtrMult'
  }
}
$filt = $norm | Where-Object { $_.PF -ge $MinPF -and $_.Trades -ge $MinTrades }
Write-Output ("TOTAL passes: {0} | after filter(PF>={1},Trades>={2}): {3}" -f $norm.Count, $MinPF, $MinTrades, $filt.Count)
$filt | Sort-Object -Property $SortBy -Descending | Select-Object -First $Top | Format-Table -AutoSize
