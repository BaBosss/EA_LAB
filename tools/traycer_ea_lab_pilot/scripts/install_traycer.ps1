param([string]$Version='1.2.0',[string]$DownloadRoot='D:\EA_LAB_CONTROL\traycer-pilot\downloads',[switch]$Reinstall)
$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'TraycerPilot.psm1') -Force
$current=Get-TraycerInstallation
if($current.found -and -not $Reinstall -and $current.version -like "$Version*" -and $current.signature_status -eq 'Valid' -and $current.signer_subject -match 'TRAYCER AI INC'){
  [pscustomobject]@{result='ALREADY_INSTALLED';installation=$current} | ConvertTo-Json -Depth 5; exit 0
}
New-Item -ItemType Directory -Force -Path $DownloadRoot | Out-Null
$file=Join-Path $DownloadRoot "traycer-desktop-windows-x64-$Version.exe"
$url="https://github.com/traycerai/traycer/releases/download/desktop-v$Version/traycer-desktop-windows-x64.exe"
if(-not (Test-Path $file)){
  & curl.exe -L --fail --ssl-revoke-best-effort --retry 5 --retry-delay 2 --retry-all-errors -o $file $url
  if($LASTEXITCODE -ne 0){ throw "Download failed exit=$LASTEXITCODE" }
}
$sig=Get-AuthenticodeSignature $file
if($sig.Status -ne 'Valid'){ throw "Installer signature invalid: $($sig.Status)" }
if($sig.SignerCertificate.Subject -notmatch 'TRAYCER AI INC'){ throw "Unexpected installer signer: $($sig.SignerCertificate.Subject)" }
$hash=(Get-FileHash $file -Algorithm SHA256).Hash.ToLowerInvariant()
$p=Start-Process -FilePath $file -ArgumentList '/S' -Wait -PassThru
if($p.ExitCode -ne 0){ throw "Installer exit=$($p.ExitCode)" }
$installed=Get-TraycerInstallation
if(-not $installed.found -or $installed.signature_status -ne 'Valid'){ throw 'Installed Traycer verification failed' }
[pscustomobject]@{result='INSTALLED';installer=$file;sha256=$hash;installation=$installed} | ConvertTo-Json -Depth 6
