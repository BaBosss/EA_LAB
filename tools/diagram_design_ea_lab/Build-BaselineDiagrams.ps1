$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$moduleRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
$manifest = Get-Content -LiteralPath (Join-Path $moduleRoot 'workflow_manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Encode-Html([string]$Value) { return [System.Net.WebUtility]::HtmlEncode($Value) }

function New-Page {
    param([string]$Title, [string]$Profile, [string]$Svg)
    $css = @'
*{box-sizing:border-box}body{margin:0;background:#f5f5f5;color:#2d3142;font-family:Arial,sans-serif}main{max-width:1480px;margin:0 auto;padding:40px 32px}.eyebrow,.meta,footer{font-family:Consolas,monospace;letter-spacing:.08em;text-transform:uppercase}.eyebrow{font-size:12px;color:#4f5d75;margin:0 0 12px}.badge{display:inline-block;border:1px solid #eb6c36;border-radius:4px;color:#9e3c18;padding:6px 8px;font:600 11px Consolas,monospace;letter-spacing:.06em}h1{font:400 40px Georgia,serif;margin:16px 0 8px}.meta{font-size:12px;color:#4f5d75;margin:0 0 28px}.diagram{overflow-x:auto}svg{display:block;width:100%;min-width:900px;height:auto}footer{border-top:1px solid rgba(45,49,66,.16);margin-top:28px;padding-top:16px;color:#4f5d75;font-size:11px;line-height:1.5}.note{font-family:Arial,sans-serif;letter-spacing:0;text-transform:none}
'@
    return "<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>$(Encode-Html $Title)</title><style>$css</style></head><body><main><span class='badge'>VISUAL_ONLY_NO_AUTHORITY</span><p class='eyebrow'>EA_LAB workflow documentation</p><h1>$(Encode-Html $Title)</h1><p class='meta'>profile: $(Encode-Html $Profile) | offline baseline</p><div class='diagram'>$Svg</div><footer>Provenance: tools/diagram_design_ea_lab/workflow_manifest.json | <span class='note'>Visual documentation only. Runtime, Git, governance, strategy specifications, risk policy and owner approvals remain authoritative elsewhere.</span></footer></main></body></html>"
}

function New-SvgStart([string]$Slug, [string]$Title, [string]$Description, [int]$Width, [int]$Height) {
    return "<svg viewBox='0 0 $Width $Height' role='img' aria-labelledby='$Slug-title $Slug-desc' xmlns='http://www.w3.org/2000/svg'><title id='$Slug-title'>$(Encode-Html $Title)</title><desc id='$Slug-desc'>$(Encode-Html $Description)</desc><defs><marker id='$Slug-arrow' markerWidth='8' markerHeight='6' refX='7' refY='3' orient='auto'><polygon points='0 0,8 3,0 6' fill='#4f5d75'/></marker><marker id='$Slug-arrow-accent' markerWidth='8' markerHeight='6' refX='7' refY='3' orient='auto'><polygon points='0 0,8 3,0 6' fill='#eb6c36'/></marker></defs><rect width='100%' height='100%' fill='#f5f5f5'/>"
}

function New-Node([int]$X, [int]$Y, [int]$W, [int]$H, [string]$Label, [bool]$Focal = $false) {
    $fill = if ($Focal) { '#fff0e9' } else { '#ffffff' }
    $stroke = if ($Focal) { '#eb6c36' } else { '#4f5d75' }
    $tag = if ($Focal) { 'GATE' } else { 'STEP' }
    $cx = $X + [int]($W / 2)
    $name = Encode-Html $Label
    return "<rect x='$X' y='$Y' width='$W' height='$H' rx='8' fill='$fill' stroke='$stroke' stroke-width='1'/><rect x='$($X + 8)' y='$($Y + 8)' width='32' height='12' rx='2' fill='none' stroke='$stroke' stroke-width='.8'/><text x='$($X + 24)' y='$($Y + 17)' text-anchor='middle' fill='$stroke' font-family='Consolas,monospace' font-size='8'>$tag</text><text x='$cx' y='$($Y + 48)' text-anchor='middle' fill='#2d3142' font-family='Arial,sans-serif' font-size='12' font-weight='600'>$name</text>"
}

function Render-Process {
    param($Profile, [string]$Slug)
    $stages = @($Profile.stages)
    $width = [Math]::Max(1040, 96 + ($stages.Count * 132))
    $height = 300
    $svg = New-SvgStart $Slug $Profile.title 'Ordered EA_LAB workflow stages with a non-authoritative endpoint.' $width $height
    $svg += "<text x='32' y='36' fill='#4f5d75' font-family='Consolas,monospace' font-size='12' letter-spacing='1'>ORDERED WORKFLOW</text>"
    for ($i = 0; $i -lt $stages.Count; $i++) {
        $x = 32 + ($i * 132); $y = 112; $focal = ($i -eq ($stages.Count - 1))
        if ($i -gt 0) { $svg += "<line x1='$($x - 20)' y1='160' x2='$($x - 4)' y2='160' stroke='#4f5d75' stroke-width='1.2' marker-end='url(#$Slug-arrow)'/>" }
        $svg += New-Node $x $y 112 96 ([string]$stages[$i]) $focal
        $svg += "<text x='$($x + 56)' y='232' text-anchor='middle' fill='#4f5d75' font-family='Consolas,monospace' font-size='8'>$(($i + 1).ToString('00'))</text>"
    }
    return "$svg<line x1='32' y1='260' x2='$($width - 32)' y2='260' stroke='rgba(45,49,66,.18)'/><text x='32' y='284' fill='#4f5d75' font-family='Consolas,monospace' font-size='10'>LEGEND</text><text x='128' y='284' fill='#4f5d75' font-family='Arial,sans-serif' font-size='10'>standard workflow step</text><rect x='280' y='272' width='16' height='12' rx='2' fill='#fff0e9' stroke='#eb6c36'/><text x='308' y='284' fill='#4f5d75' font-family='Arial,sans-serif' font-size='10'>owner or authority gate</text></svg>"
}

function Render-Architecture {
    param($Profile, [string]$Slug)
    $groups = @($Profile.groups)
    $width = 1360; $height = 540
    $svg = New-SvgStart $Slug $Profile.title 'EA_LAB tooling groups arranged as a non-authoritative architecture overview.' $width $height
    $svg += "<text x='32' y='36' fill='#4f5d75' font-family='Consolas,monospace' font-size='12' letter-spacing='1'>TOOLCHAIN OVERVIEW</text>"
    for ($g = 0; $g -lt $groups.Count; $g++) {
        $group = @($groups[$g]); $label = [string]$group[0]; $items = @($group | Select-Object -Skip 1)
        $y = 64 + ($g * 84); $svg += "<rect x='24' y='$y' width='1312' height='72' rx='8' fill='rgba(45,49,66,.02)' stroke='rgba(45,49,66,.14)'/><text x='40' y='$($y + 24)' fill='#4f5d75' font-family='Consolas,monospace' font-size='9' letter-spacing='1'>$(Encode-Html $label)</text>"
        $count = [Math]::Min($items.Count, 6); $itemWidth = [int](1120 / $count)
        for ($i = 0; $i -lt $count; $i++) { $x = 184 + ($i * $itemWidth); $focal = ($label -eq 'Authority & truth' -and $i -eq 0); $svg += New-Node $x ($y + 20) ($itemWidth - 16) 40 ([string]$items[$i]) $focal }
    }
    return "$svg<line x1='32' y1='492' x2='1328' y2='492' stroke='rgba(45,49,66,.18)'/><text x='32' y='516' fill='#4f5d75' font-family='Consolas,monospace' font-size='10'>LEGEND</text><text x='128' y='516' fill='#4f5d75' font-family='Arial,sans-serif' font-size='10'>system group | no operational command or authority delegation</text></svg>"
}

function Render-Swimlane {
    param($Profile, [string]$Slug)
    $lanes = @($Profile.lanes); $width = 1220; $height = 120 + ($lanes.Count * 64)
    $svg = New-SvgStart $Slug $Profile.title 'EA_LAB workflow ownership lanes ending at an explicit runtime gate.' $width $height
    $svg += "<text x='32' y='36' fill='#4f5d75' font-family='Consolas,monospace' font-size='12' letter-spacing='1'>OWNERSHIP HANDOFFS</text>"
    for ($i = 0; $i -lt $lanes.Count; $i++) {
        $y = 56 + ($i * 64); $focal = ($i -eq ($lanes.Count - 1)); $svg += "<rect x='24' y='$y' width='1172' height='64' fill='$(if ($i % 2 -eq 0) { 'rgba(45,49,66,.02)' } else { '#f5f5f5' })' stroke='rgba(45,49,66,.14)'/><text x='40' y='$($y + 36)' fill='#4f5d75' font-family='Consolas,monospace' font-size='10'>$(Encode-Html ([string]$lanes[$i]))</text>"
        if ($i -gt 0) { $svg += "<path d='M 520,$($y - 18) H 632 Q 640,$($y - 18) 640,$($y - 10) V $y' fill='none' stroke='#4f5d75' stroke-width='1.2' marker-end='url(#$Slug-arrow)'/>" }
        $step = if ($focal) { 'Authority boundary' } else { 'Scoped handoff' }; $svg += New-Node 520 ($y + 12) 240 40 $step $focal
    }
    $legendY = $height - 28
    return "$svg<line x1='32' y1='$($legendY - 20)' x2='1188' y2='$($legendY - 20)' stroke='rgba(45,49,66,.18)'/><text x='32' y='$legendY' fill='#4f5d75' font-family='Consolas,monospace' font-size='10'>LEGEND</text><text x='128' y='$legendY' fill='#4f5d75' font-family='Arial,sans-serif' font-size='10'>handoff direction | runtime action remains outside this visual</text></svg>"
}

foreach ($property in $manifest.profiles.PSObject.Properties) {
    $profileName = $property.Name; $profile = $property.Value; $slug = $profileName -replace '[^a-z0-9-]', '-'
    $svg = switch ($profile.type) {
        'architecture' { Render-Architecture $profile $slug }
        'swimlane' { Render-Swimlane $profile $slug }
        default { Render-Process $profile $slug }
    }
    $html = New-Page $profile.title $profileName $svg
    $outputPath = Join-Path $repoRoot $profile.output
    $outputDir = Split-Path -Parent $outputPath
    if (-not (Test-Path -LiteralPath $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }
    [System.IO.File]::WriteAllText($outputPath, $html, $utf8)
    Write-Output $profile.output
}
