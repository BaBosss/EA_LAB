param(
    [string]$Url = 'https://www.facebook.com/',
    [string]$ProfileRoot = 'D:\EA_LAB_CONTROL\browser-profiles\facebook-research',
    [int]$DebugPort = 9223,
    [switch]$StatusOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Result([hashtable]$Data) {
    $Data.checked_utc = [DateTimeOffset]::UtcNow.ToString('o')
    $Data.profile_root = $ProfileRoot
    $Data.debug_port = $DebugPort
    $Data | ConvertTo-Json -Depth 5
}

function Test-FacebookUrl([string]$Value) {
    try {
        $uri = [Uri]$Value
        if($uri.Scheme -ne 'https'){ return $false }
        return ($uri.Host -eq 'facebook.com' -or
                $uri.Host -eq 'www.facebook.com' -or
                $uri.Host.EndsWith('.facebook.com'))
    } catch { return $false }
}

if(-not (Test-FacebookUrl $Url)){
    throw 'FACEBOOK_RESEARCH[bad_url] only https://*.facebook.com URLs are allowed'
}

$endpoint = "http://127.0.0.1:$DebugPort"
$versionUri = "$endpoint/json/version"
$profileFull = [IO.Path]::GetFullPath($ProfileRoot)
$escapedProfile = [Regex]::Escape($profileFull)
$portLiteral = [Regex]::Escape("--remote-debugging-port=$DebugPort")

function Get-DebugVersion {
    try { return Invoke-RestMethod -Uri $versionUri -TimeoutSec 3 }
    catch { return $null }
}

function Get-DedicatedDebugOwners {
    return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -eq 'chrome.exe' -and
            $_.CommandLine -match $escapedProfile -and
            $_.CommandLine -match $portLiteral
        })
}

$version = Get-DebugVersion
$debugOwners = @(Get-DedicatedDebugOwners)
if($version -and $debugOwners.Count -eq 0){
    Write-Result @{
        state='BLOCKED_PORT_IDENTITY_MISMATCH'
        action='Port is live but not bound to the dedicated Facebook Research profile'
        session_persistence='CHROME_PROFILE_ONLY'
        login_state='NOT_PROBED'
    }
    exit 3
}

if($StatusOnly){
    if($version){
        Write-Result @{
            state='READY'
            browser=$version.Browser
            session_persistence='CHROME_PROFILE_ONLY'
            login_state='NOT_PROBED'
        }
        exit 0
    }
    $profileExists = Test-Path $profileFull
    Write-Result @{
        state=$(if($profileExists){'STOPPED_PROFILE_PRESENT'}else{'STOPPED_PROFILE_MISSING'})
        session_persistence='CHROME_PROFILE_ONLY'
        login_state='NOT_PROBED'
    }
    exit 0
}

if($version){
    $encoded = [Uri]::EscapeDataString($Url)
    try {
        Invoke-RestMethod -Method Put -Uri "$endpoint/json/new?$encoded" -TimeoutSec 5 | Out-Null
    } catch {
        throw "FACEBOOK_RESEARCH[existing_browser_target_open_failed] $($_.Exception.Message)"
    }
    Write-Result @{
        state='REUSED_RUNNING_PROFILE'
        browser=$version.Browser
        opened_url=$Url
        session_persistence='CHROME_PROFILE_ONLY'
        login_state='CHECK_IN_PAGE'
    }
    exit 0
}

$profileUsers = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq 'chrome.exe' -and $_.CommandLine -match $escapedProfile })

if($profileUsers.Count -gt 0){
    Write-Result @{
        state='BLOCKED_PROFILE_IN_USE_WITHOUT_CDP'
        process_count=$profileUsers.Count
        action='Close only the dedicated Facebook Research Chrome window, then rerun. Do not kill or clear the profile.'
        session_persistence='CHROME_PROFILE_ONLY'
        login_state='NOT_PROBED'
    }
    exit 2
}

$chromeCandidates = @(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
)
$chrome = $chromeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if(-not $chrome){ throw 'FACEBOOK_RESEARCH[chrome_missing] Chrome executable not found' }

New-Item -ItemType Directory -Path $profileFull -Force | Out-Null
$args = @(
    "--user-data-dir=$profileFull",
    "--remote-debugging-port=$DebugPort",
    '--disable-notifications',
    '--no-first-run',
    $Url
)
Start-Process -FilePath $chrome -ArgumentList $args | Out-Null

$deadline = (Get-Date).AddSeconds(15)
do {
    Start-Sleep -Milliseconds 500
    $version = Get-DebugVersion
} while(-not $version -and (Get-Date) -lt $deadline)

if(-not $version){ throw 'FACEBOOK_RESEARCH[debug_endpoint_timeout] Chrome started but CDP did not become ready' }

$debugOwners = @(Get-DedicatedDebugOwners)
if($debugOwners.Count -eq 0){
    throw 'FACEBOOK_RESEARCH[started_port_identity_mismatch] CDP became ready without the dedicated profile identity'
}

Write-Result @{
    state='STARTED_PERSISTENT_PROFILE'
    browser=$version.Browser
    opened_url=$Url
    session_persistence='CHROME_PROFILE_ONLY'
    login_state='CHECK_IN_PAGE'
    security='NO_PASSWORD_COOKIE_OR_TOKEN_EXPORT'
}
