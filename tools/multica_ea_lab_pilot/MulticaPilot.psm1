Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:PolicyPath=Join-Path $PSScriptRoot 'pilot-policy.json'
$script:ProtectedPrimary=[IO.Path]::GetFullPath('D:\EA_LAB').TrimEnd('\')
$script:CageRoot=[IO.Path]::GetFullPath('D:\EA_LAB_CONTROL\multica-pilot\cages').TrimEnd('\')
function Assert-MulticaPilotSafePath {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Path)
    $full=[IO.Path]::GetFullPath($Path).TrimEnd('\')
    if($full.Equals($script:ProtectedPrimary,[StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($script:ProtectedPrimary+'\',[StringComparison]::OrdinalIgnoreCase)){
        throw "Protected dirty primary checkout is forbidden: $full"
    }
    return $full
}
function Assert-MulticaPilotResource {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][ValidateSet('github_repo','local_directory')][string]$ResourceType,
        [Parameter(Mandatory)][string]$Location,
        [string]$Ref
    )
    if($ResourceType -eq 'github_repo'){
        $repo=$Location.TrimEnd('/')
        if($repo -notin @('https://github.com/BaBosss/EA_LAB','https://github.com/BaBosss/EA_LAB.git')){ throw "Pilot github_repo must be BaBosss/EA_LAB: $Location" }
        if($Ref -cnotmatch '^[0-9a-f]{40}$'){ throw 'EA_LAB github_repo resource requires an exact lowercase 40-hex ref' }
        return [pscustomobject]@{type='github_repo';location=$repo;ref=$Ref;mode='EXACT_REF_ONLY'}
    }
    $full=Assert-MulticaPilotSafePath $Location
    if(-not ($full.Equals($script:CageRoot,[StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($script:CageRoot+'\',[StringComparison]::OrdinalIgnoreCase))){
        throw "local_directory is allowed only inside disposable cage root: $script:CageRoot"
    }
    return [pscustomobject]@{type='local_directory';location=$full;ref=$null;mode='DISPOSABLE_CAGE_ONLY'}
}
function Get-MulticaPilotPolicy {
    [CmdletBinding()] param()
    if(-not (Test-Path -LiteralPath $script:PolicyPath)){ throw "Missing pilot policy: $script:PolicyPath" }
    return (Get-Content -LiteralPath $script:PolicyPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}
function Get-MulticaInstallation {
    [CmdletBinding()] param()
    $exe=Join-Path $env:USERPROFILE '.multica\bin\multica.exe'
    if(-not (Test-Path -LiteralPath $exe)){ return [pscustomobject]@{found=$false;path=$exe;version=$null;sha256=$null} }
    $out=@(& $exe version 2>&1)
    if($LASTEXITCODE -ne 0){ throw 'multica version failed' }
    $text=($out | Out-String).Trim()
    $version=$null
    if($text -match 'multica\s+([0-9]+(?:\.[0-9]+)+)'){ $version=$Matches[1] }
    $sha=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToUpperInvariant()
    return [pscustomobject]@{found=$true;path=$exe;version=$version;sha256=$sha;raw=$text}
}
function Get-MulticaDaemonState {
    [CmdletBinding()] param()
    $i=Get-MulticaInstallation
    if(-not $i.found){ return [pscustomobject]@{state='NOT_INSTALLED';raw=''} }
    $out=@(& $i.path daemon status 2>&1)
    $text=($out | Out-String).Trim()
    if($text -match '(?im)^Daemon:\s*stopped\s*$'){ return [pscustomobject]@{state='STOPPED';raw=$text} }
    if($text -match '(?im)^Daemon:\s*running\s*$'){ return [pscustomobject]@{state='RUNNING';raw=$text} }
    return [pscustomobject]@{state='UNKNOWN';raw=$text}
}
function Get-MulticaPilotPreflight {
    [CmdletBinding()] param()
    $tools=[ordered]@{}
    foreach($name in @('git','claude','codex','qwen','agy')){
        $cmd=Get-Command $name -ErrorAction SilentlyContinue
        $tools[$name]=[pscustomobject]@{found=($null -ne $cmd);path=$(if($cmd){$cmd.Source}else{$null})}
    }
    [pscustomobject]@{timestamp=(Get-Date).ToString('o');tools=[pscustomobject]$tools;multica=(Get-MulticaInstallation);daemon=(Get-MulticaDaemonState)}
}
function Get-MulticaPilotRepoIdentity {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Path)
    $safe=Assert-MulticaPilotSafePath $Path
    $inside=(& git -C $safe rev-parse --is-inside-work-tree 2>$null)
    if($LASTEXITCODE -ne 0 -or ($inside|Out-String).Trim() -ne 'true'){ throw "Not a Git worktree: $safe" }
    $head=(& git -C $safe rev-parse HEAD).Trim()
    $branch=(& git -C $safe branch --show-current).Trim()
    $dirty=@(& git -C $safe status --porcelain)
    return [pscustomobject]@{path=$safe;head=$head;branch=$branch;clean=($dirty.Count -eq 0);dirty=@($dirty)}
}
Export-ModuleMember -Function Assert-MulticaPilotSafePath,Assert-MulticaPilotResource,Get-MulticaPilotPolicy,Get-MulticaInstallation,Get-MulticaDaemonState,Get-MulticaPilotPreflight,Get-MulticaPilotRepoIdentity
