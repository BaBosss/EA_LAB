[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$hub = Join-Path $root 'mobile_report_hub'
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Read-Text {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path)
}

$required = @(
    'index.html', 'app.js', 'styles.css', 'manifest.webmanifest', 'sw.js', 'icon.svg', 'fixture\report_index.json'
)
foreach ($relative in $required) {
    Assert-True (Test-Path (Join-Path $hub $relative) -PathType Leaf) "Missing static asset: mobile_report_hub/$relative"
}

if ($failures.Count -eq 0) {
    $html = Read-Text (Join-Path $hub 'index.html')
    $app = Read-Text (Join-Path $hub 'app.js')
    $css = Read-Text (Join-Path $hub 'styles.css')
    $sw = Read-Text (Join-Path $hub 'sw.js')
    $manifest = Get-Content -Raw (Join-Path $hub 'manifest.webmanifest') | ConvertFrom-Json
    $fixture = Get-Content -Raw (Join-Path $hub 'fixture\report_index.json') | ConvertFrom-Json

    Assert-True ($html -match 'manifest\.webmanifest') 'index.html must reference the web manifest.'
    Assert-True ($html -match 'viewport') 'index.html must include a mobile viewport declaration.'
    Assert-True ($html -match 'aria-label') 'index.html must expose accessible navigation labels.'
    Assert-True ($manifest.display -eq 'standalone') 'Manifest must support add-to-home-screen standalone display.'
    Assert-True ($manifest.start_url -match 'index\.html#home') 'Manifest start URL must open the report hub home.'
    Assert-True ($manifest.icons.Count -gt 0 -and $manifest.icons[0].src -eq 'icon.svg') 'Manifest must include a local app icon.'
    Assert-True ($app -match 'REPORT_INDEX_URL\s*=\s*["'']\./report_index\.json') 'App must consume the generated root report_index.json first.'
    Assert-True ($app -match 'FIXTURE_INDEX_URL\s*=\s*["'']\./fixture/report_index\.json') 'Explicit fixture mode must resolve the local fixture index.'
    Assert-True ($app -match 'fixture_only') 'App must visibly distinguish fixture-only data.'
    Assert-True ($app -match 'URLSearchParams' -and $app -match 'get\("fixture"\) === "1"') 'Fixture data must require explicit ?fixture=1 mode.'
    Assert-True (-not ($app -match 'catch\s*\{[^}]*FIXTURE_INDEX_URL')) 'Production report-index failure must not silently fall back to fixture data.'
    Assert-True ($fixture.fixture_only -eq $true) 'Fixture must declare fixture_only=true.'
    Assert-True ($fixture.generator -match 'not production SOT') 'Fixture must state that it is not production SOT.'
    Assert-True ($fixture.project.data_status -eq 'STALE') 'Fixture must exercise stale data presentation.'

    $b16 = @($fixture.eas | Where-Object { $_.id -eq 'B16-H03' })[0]
    Assert-True ($null -ne $b16) 'Fixture must include B16 H03.'
    if ($null -ne $b16) {
        Assert-True ($b16.status -eq 'DONE') 'B16 H03 fixture status must be DONE.'
        Assert-True ($b16.verdict -eq 'POSITION_ENGINE_DEPENDENT_OR_UNKNOWN') 'B16 H03 fixture verdict must preserve the required state.'
        Assert-True ($b16.evidence.main.pf -eq 4.08 -and $b16.evidence.bwd.pf -eq 1.44) 'B16 H03 fixture must contain the required MAIN/BWD PF values.'
        Assert-True ($b16.evidence.main.cycles -eq 42 -and $b16.evidence.bwd.cycles -eq 70) 'B16 H03 fixture must contain required cycle values.'
    }
    $p4b = @($fixture.eas | Where-Object { $_.id -eq 'B19-P4B' })[0]
    Assert-True ($null -ne $p4b -and $p4b.blocker_type -eq 'ENVIRONMENT') 'Fixture must include the Boss19 environment blocker.'
    Assert-True ($null -ne @($fixture.eas | Where-Object { $_.id -eq 'MISSING-FIELDS' })[0]) 'Fixture must include a missing-fields record.'
    $h02 = @($fixture.eas | Where-Object { $_.evidence.basis_id -eq 'H02_LITERAL_PORTABILITY_MODEL1' })
    Assert-True ($h02.Count -eq 2) 'Fixture must include exactly two compatible H02 comparison records.'
    Assert-True ((@($h02 | Where-Object { $_.lifecycle -ne 'Research' -or $_.verdict -ne 'NON_AUTHORITATIVE_SCREEN' })).Count -eq 0) 'H02 fixture records must remain Research screening, never Candidate.'
    $h02xau = @($h02 | Where-Object { $_.id -eq 'B16-XAUUSD-H4-H02' })[0]
    $h02jpy = @($h02 | Where-Object { $_.id -eq 'B16-USDJPY-H1-H02' })[0]
    Assert-True ($h02xau.evidence.main.pf -eq '4.08' -and $h02xau.evidence.bwd.pf -eq '1.44') 'H02 XAU fixture must preserve accepted screen PF values.'
    Assert-True ($h02jpy.evidence.main.pf -eq '1.53' -and $h02jpy.evidence.bwd.pf -eq '1.11') 'H02 USDJPY fixture must preserve accepted screen PF values.'

    $allHubText = Get-ChildItem -Path $hub -Recurse -File | ForEach-Object { Read-Text $_.FullName }
    Assert-True (-not ($allHubText -match '(?i)(?:src|href)\s*=\s*["''](?:https?:)?//|@import\s+url\(\s*["'']?(?:https?:)?//|(?:cdnjs|unpkg|jsdelivr)')) 'Mobile hub must not include external URLs or CDNs.'
    $forbidden = 'BUY|SELL|CLOSE|HEDGE|RECOVERY|CHANGE LOT|CHANGE RISK|ATTACH|DETACH|START LIVE|PROMOTE LIVE'
    Assert-True (-not ($html + "`n" + $app -match "(?i)$forbidden")) 'Hub must not expose forbidden trading controls or labels.'
    Assert-True (-not ($app -match '4\.08|6\.27|79\.80|87\.89|8\.29|\b148\b')) 'app.js must not hardcode fixture or canonical performance numbers.'

    Assert-True ($app -match 'basis_id' -and $app -match 'DIFFERENT BASIS' -and $app -match 'selected\.length !== 2') 'Compare source must enforce exactly two records and basis compatibility.'
    Assert-True ($app -match 'valueOf' -and $app -match 'metricValue') 'App must render missing values explicitly.'
    Assert-True ($app -match 'record\.next_action') 'Detail view must render a supported next action when present.'
    Assert-True ($app -match 'navigator\.onLine' -and $app -match 'CACHED DATA' -and $app -match 'STALE DATA') 'App must show offline/cached/stale warning states.'
    Assert-True ($sw -match 'X-EA-LAB-Cache' -and $sw -match 'report_index\.json' -and $sw -match 'cache\.put') 'Service worker must cache and identify a cached report index.'
    Assert-True ($sw -match 'fixture/' -and $sw -match '!url\.pathname\.includes') 'Service worker must not cache fixture report data as the production index.'
    Assert-True ($css -match '@media \(max-width: 390px\)' -and $css -match 'orientation: landscape') 'CSS must include 390px portrait and landscape handling.'
    Assert-True ($css -match 'min-height: 44px') 'CSS must include practical 44px touch targets.'
    Assert-True ($css -match '\.record-card\s*\{[^}]*min-width:\s*0;[^}]*overflow-wrap:\s*anywhere;' ) 'Record cards must shrink and wrap long canonical state tokens on phone widths.'
    Assert-True ($app -match 'safeRelativeHref' -and $app -match 'full_report') 'Links must be safe relative report links only.'
    Assert-True ($app -match 'INVENTORY_ONLY' -and $app -match 'const recent = records\.filter') 'Latest/recent must exclude inventory-only records.'
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'PASS mobile_report_hub static UI checks'
