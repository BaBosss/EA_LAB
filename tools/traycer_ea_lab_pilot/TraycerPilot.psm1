Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert-TraycerPilotSafePath {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Path)
    $full=[IO.Path]::GetFullPath($Path).TrimEnd('\')
    $protected=[IO.Path]::GetFullPath('D:\EA_LAB').TrimEnd('\')
    if($full.Equals($protected,[StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($protected+'\',[StringComparison]::OrdinalIgnoreCase)){
        throw "Protected dirty primary checkout is forbidden: $full"
    }
    return $full
}
function Get-TraycerInstallation {
    [CmdletBinding()] param()
    $exe=Join-Path $env:LOCALAPPDATA 'Programs\traycer\Traycer.exe'
    $cli=Join-Path $env:LOCALAPPDATA 'Programs\traycer\resources\cli\win32-x64\traycer.exe'
    if(-not (Test-Path -LiteralPath $exe)){
        return [pscustomobject]@{found=$false;path=$exe;cli_path=$cli;version=$null;signature_status=$null;signer_subject=$null}
    }
    $item=Get-Item -LiteralPath $exe
    $sig=Get-AuthenticodeSignature -FilePath $exe
    [pscustomobject]@{found=$true;path=$exe;cli_path=$cli;version=$item.VersionInfo.FileVersion;signature_status=[string]$sig.Status;signer_subject=$(if($sig.SignerCertificate){$sig.SignerCertificate.Subject}else{''})}
}
function Get-TraycerPilotPreflight {
    [CmdletBinding()] param()
    $tools=[ordered]@{}
    foreach($name in @('git','claude','codex','qwen','gemini')){
        $cmd=Get-Command $name -ErrorAction SilentlyContinue
        $tools[$name]=[pscustomobject]@{found=($null -ne $cmd);path=$(if($cmd){$cmd.Source}else{$null})}
    }
    [pscustomobject]@{timestamp=(Get-Date).ToString('o');tools=[pscustomobject]$tools;traycer=(Get-TraycerInstallation)}
}function Get-TraycerPilotRepoIdentity {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Path)
    $safe=Assert-TraycerPilotSafePath $Path
    $inside=(& git -C $safe rev-parse --is-inside-work-tree 2>$null)
    if($LASTEXITCODE -ne 0 -or $inside.Trim() -ne 'true'){ throw "Not a Git worktree: $safe" }
    $head=(& git -C $safe rev-parse HEAD).Trim()
    $branch=(& git -C $safe branch --show-current).Trim()
    $dirty=@(& git -C $safe status --porcelain)
    [pscustomobject]@{path=$safe;head=$head;branch=$branch;clean=($dirty.Count -eq 0);dirty=@($dirty)}
}
function New-TraycerPilotCage {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Name)
    $safeRoot=Assert-TraycerPilotSafePath $Root
    $path=Assert-TraycerPilotSafePath (Join-Path $safeRoot $Name)
    if(Test-Path -LiteralPath $path){ throw "Cage already exists: $path" }
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    & git -C $path init -q
    if($LASTEXITCODE -ne 0){ throw 'git init failed' }
    & git -C $path config core.autocrlf false
    & git -C $path config user.name 'EA_LAB Traycer Pilot'
    & git -C $path config user.email 'traycer-pilot@local.invalid'
    Set-Content -LiteralPath (Join-Path $path 'README.md') -Encoding UTF8 -Value "# Disposable Traycer Pilot Cage`n`nNo EA_LAB canonical authority."
    & git -C $path add README.md
    if($LASTEXITCODE -ne 0){ throw 'git add failed' }
    & git -C $path commit -q -m 'init disposable traycer cage'
    if($LASTEXITCODE -ne 0){ throw 'git commit failed' }
    $dirty=@(& git -C $path status --porcelain)
    [pscustomobject]@{path=$path;clean=($dirty.Count -eq 0);head=(& git -C $path rev-parse HEAD).Trim()}
}
Export-ModuleMember -Function Assert-TraycerPilotSafePath,Get-TraycerInstallation,Get-TraycerPilotPreflight,Get-TraycerPilotRepoIdentity,New-TraycerPilotCage
