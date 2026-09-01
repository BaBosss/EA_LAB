<# Launches a detached read-only Claude review on one frozen exact HEAD. #>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ClaudeExecutable,
  [Parameter(Mandatory=$true)][string]$PromptFile,
  [Parameter(Mandatory=$true)][string]$JobId,
  [Parameter(Mandatory=$true)][string]$Worktree,
  [Parameter(Mandatory=$true)][string]$ExpectedHead,
  [Parameter(Mandatory=$true)][string]$OutputFile,
  [string]$ExpectedHooksPath='.githooks',
  [int]$TimeoutSec=1800,
  [int]$HeartbeatSec=5,
  [string]$JobsRoot='D:\EA_LAB_CONTROL\jobs',
  [switch]$Json
)
$ErrorActionPreference='Stop'
if($ExpectedHead -notmatch '^[0-9a-f]{40}$'){ throw 'ExpectedHead must be a 40-char lowercase SHA' }
foreach($p in @($ClaudeExecutable,$PromptFile,$Worktree,$OutputFile,$JobsRoot)){
  if(-not [IO.Path]::IsPathRooted($p)){ throw "absolute path required: $p" }
}
$wt=[IO.Path]::GetFullPath($Worktree).TrimEnd('\')
$out=[IO.Path]::GetFullPath($OutputFile)
$prefix=$wt+'\'
if($out.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){ throw 'review output must be outside the reviewed worktree' }
if(Test-Path -LiteralPath $out){ throw "review output already exists: $out" }
$bootstrap=Join-Path $PSScriptRoot 'bootstrap_worktree.ps1'
& $bootstrap -Worktree $wt -ExpectedHead $ExpectedHead -ExpectedHooksPath $ExpectedHooksPath -Json | Out-Null
$runner=Join-Path $PSScriptRoot 'run_claude_reviewer.ps1'
$longJob=Join-Path (Split-Path -Parent $PSScriptRoot) 'long_jobs\start_long_job.ps1'
$args=@(
 '-NoProfile','-ExecutionPolicy','Bypass','-File',$runner,
 '-ClaudeExecutable',[IO.Path]::GetFullPath($ClaudeExecutable),
 '-PromptFile',[IO.Path]::GetFullPath($PromptFile),
 '-Worktree',$wt,'-ExpectedHead',$ExpectedHead,'-OutputFile',$out
)
$start=@{
 FilePath=(Join-Path $PSHOME 'powershell.exe'); ArgumentList=$args; JobId=$JobId;
 TimeoutSec=$TimeoutSec; HeartbeatSec=$HeartbeatSec; Worktree=$wt; BaseSha=$ExpectedHead;
 Stage='REVIEW_CLAUDE_READONLY'; JobsRoot=[IO.Path]::GetFullPath($JobsRoot); Json=$Json
}
& $longJob @start
