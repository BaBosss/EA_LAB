# cot_pull.ps1 - pull CFTC legacy futures-only COT for GOLD (COMEX 088691) via Socrata API
# Output: _mt5_auto\cot_gold.csv  (report_date, net_noncomm, oi, net_pct_3y = percentile rank of
# net_noncomm within trailing 156 weekly reports). Research data for gold regime-filter idea
# (FB post 2026-07-09). No API key needed; full pull is ~370 rows since 2019 = one request.
param(
    [string]$OutFile = "D:\EA_LAB\_mt5_auto\cot_gold.csv",
    [string]$Since   = "2019-01-01"
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$base = "https://publicreporting.cftc.gov/resource/6dca-aqww.json"
$q = "?`$limit=5000&`$where=cftc_contract_market_code='088691' AND report_date_as_yyyy_mm_dd>='" + $Since + "'&`$order=report_date_as_yyyy_mm_dd ASC&`$select=report_date_as_yyyy_mm_dd,open_interest_all,noncomm_positions_long_all,noncomm_positions_short_all,comm_positions_long_all,comm_positions_short_all"
$rows = Invoke-RestMethod -Uri ($base + $q) -TimeoutSec 60
if ($rows.Count -lt 100) { throw "Suspiciously few rows: $($rows.Count)" }

$parsed = foreach ($r in $rows) {
    $netNC = [int]$r.noncomm_positions_long_all - [int]$r.noncomm_positions_short_all
    $netC  = [int]$r.comm_positions_long_all - [int]$r.comm_positions_short_all
    [pscustomobject]@{
        report_date = ([datetime]$r.report_date_as_yyyy_mm_dd).ToString('yyyy-MM-dd')
        open_interest = [int]$r.open_interest_all
        net_noncomm = $netNC
        net_comm    = $netC
    }
}
# trailing-156-report percentile rank of net_noncomm (needs >= 52 reports of history, else blank)
$out = for ($i = 0; $i -lt $parsed.Count; $i++) {
    $row = $parsed[$i]
    $lo = [Math]::Max(0, $i - 155)
    $win = $parsed[$lo..$i] | ForEach-Object { $_.net_noncomm }
    $pct = ''
    if ($win.Count -ge 52) {
        $below = ($win | Where-Object { $_ -le $row.net_noncomm }).Count
        $pct = [Math]::Round(100.0 * $below / $win.Count, 1)
    }
    $row | Add-Member -NotePropertyName net_pct_3y -NotePropertyValue $pct -PassThru
}
$out | Export-Csv -Path $OutFile -NoTypeInformation -Encoding utf8
Write-Host ("rows={0} first={1} last={2} -> {3}" -f $out.Count, $out[0].report_date, $out[-1].report_date, $OutFile)
