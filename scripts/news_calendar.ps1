# news_calendar.ps1 - daily economic-calendar brief (ORDER-073 Phase 1)
# Pulls the ForexFactory weekly calendar feed, filters HIGH-impact events for the portfolio
# currencies, writes (1) an HTML fragment the dashboard embeds -> shows on the phone gist,
# and (2) news_week.csv = machine-readable file for the future NewsGuard watchdog EA (Phase 2).
# Zero LLM tokens - pure script, runs in the daily 07:30 chain.
[CmdletBinding()]
param(
  [string]$OutHtml = '',
  [string]$OutCsv  = '',
  [string[]]$Currencies = @('USD','GBP','EUR','JPY','AUD','NZD','CAD','CHF')
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'lib\repo_paths.ps1')
$RepoRoot = Resolve-EaLabRepoRoot -AnchorPath $PSCommandPath
if (-not $OutHtml) { $OutHtml = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\news_today.html' }
if (-not $OutCsv) { $OutCsv = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\news_week.csv' }
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
$url = 'https://nfs.faireconomy.media/ff_calendar_thisweek.xml'
$cache = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\news_feed_cache.xml'
$raw = $null
try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $raw = (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 30).Content
  [System.IO.File]::WriteAllText($cache, $raw, (New-Object System.Text.UTF8Encoding($false)))
} catch {
  # feed rate-limits (429) aggressively - fall back to cache if fresh enough (<20h)
  if ((Test-Path $cache) -and ((Get-Date) - (Get-Item $cache).LastWriteTime).TotalHours -lt 20) {
    Write-Host "news fetch failed ($($_.Exception.Message)) - using cache $(Get-Item $cache | Select-Object -ExpandProperty LastWriteTime)"
    $raw = [System.IO.File]::ReadAllText($cache)
  } else {
    Write-Host "news fetch FAILED, no fresh cache: $($_.Exception.Message)"
    exit 1
  }
}
$xml = [xml]$raw

$tzEast = [TimeZoneInfo]::FindSystemTimeZoneById('Eastern Standard Time')  # feed times are US-Eastern
$tzBkk  = [TimeZoneInfo]::FindSystemTimeZoneById('SE Asia Standard Time')
$rows = @()
foreach ($e in $xml.SelectNodes('//event')) {
  # fields are CDATA-wrapped -> InnerText is the only reliable accessor
  $impact  = $e.SelectSingleNode('impact').InnerText.Trim()
  $country = $e.SelectSingleNode('country').InnerText.Trim()
  if ($impact -ne 'High') { continue }
  if ($Currencies -notcontains $country) { continue }
  $dateS = $e.SelectSingleNode('date').InnerText.Trim()
  $timeS = $e.SelectSingleNode('time').InnerText.Trim()
  $bkk = $null
  if ($dateS -match '^\d{2}-\d{2}-\d{4}$' -and $timeS -match '^\d{1,2}:\d{2}(am|pm)$') {
    try {
      $et  = [datetime]::ParseExact("$dateS $timeS", 'MM-dd-yyyy h:mmtt', [Globalization.CultureInfo]::InvariantCulture)
      $bkk = [TimeZoneInfo]::ConvertTime($et, $tzEast, $tzBkk)
    } catch {}
  }
  $fc = ''; $pv = ''
  $n = $e.SelectSingleNode('forecast'); if ($n) { $fc = $n.InnerText.Trim() }
  $n = $e.SelectSingleNode('previous'); if ($n) { $pv = $n.InnerText.Trim() }
  $rows += [pscustomobject]@{
    BkkTime  = $bkk
    Currency = $country
    Title    = $e.SelectSingleNode('title').InnerText.Trim()
    TimeRaw  = "$dateS $timeS ET"
    Forecast = $fc
    Previous = $pv
  }
}

# CSV for the NewsGuard EA (ORDER-083): full filtered week. BkkTime is written
# as 'yyyy.MM.dd HH:mm' so MQL5 StringToTime() parses it directly (the EA also
# keeps a fallback parser for the old US-culture datetime format).
$rows | Sort-Object BkkTime |
  Select-Object @{n='BkkTime';e={ if ($_.BkkTime) { $_.BkkTime.ToString('yyyy.MM.dd HH:mm') } else { '' } }},
                Currency, Title, TimeRaw, Forecast, Previous |
  Export-Csv $OutCsv -NoTypeInformation -Encoding UTF8

# HTML fragment: today + tomorrow (Bangkok)
$today = (Get-Date).Date
$sel = $rows | Where-Object { $_.BkkTime -and $_.BkkTime.Date -ge $today -and $_.BkkTime.Date -le $today.AddDays(1) } | Sort-Object BkkTime
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('<div class="card" id="news-card">')
[void]$sb.AppendLine("<b>&#128680; High-impact news (today + tomorrow, Bangkok time)</b> <span style=`"font-size:11px;color:#888`">updated $(Get-Date -Format 'yyyy-MM-dd HH:mm') &middot; source: ForexFactory feed</span><br>")
if (-not $sel) {
  [void]$sb.AppendLine('<span style="font-size:13px">No high-impact events in the next 2 days for portfolio currencies.</span>')
} else {
  [void]$sb.AppendLine('<table style="font-size:12px"><tr><th>Bangkok</th><th>CCY</th><th>Event</th><th>F&#39;cast</th><th>Prev</th></tr>')
  foreach ($r in $sel) {
    $hl = ''
    if ($r.BkkTime.Date -eq $today) { $hl = ' style="font-weight:600"' }
    [void]$sb.AppendLine("<tr$hl><td>$($r.BkkTime.ToString('ddd HH:mm'))</td><td>$($r.Currency)</td><td style=`"text-align:left`">$([System.Web.HttpUtility]::HtmlEncode($r.Title))</td><td>$($r.Forecast)</td><td>$($r.Previous)</td></tr>")
  }
  [void]$sb.AppendLine('</table>')
}
[void]$sb.AppendLine('</div>')
[System.IO.File]::WriteAllText($OutHtml, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "news brief: $($sel.Count) events today+tomorrow ($($rows.Count) high-impact this week) -> $OutHtml"
