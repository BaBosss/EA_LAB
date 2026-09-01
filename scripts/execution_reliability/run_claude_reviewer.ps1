<# Runs one exact-head Claude review from a file-backed prompt. #>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ClaudeExecutable,
  [Parameter(Mandatory=$true)][string]$PromptFile,
  [Parameter(Mandatory=$true)][string]$Worktree,
  [Parameter(Mandatory=$true)][string]$ExpectedHead,
  [Parameter(Mandatory=$true)][string]$OutputFile
)
$ErrorActionPreference='Stop'
function Resolve-Leaf([string]$Path,[string]$Name){
  if(-not [IO.Path]::IsPathRooted($Path)){ throw "$Name must be absolute: $Path" }
  $full=[IO.Path]::GetFullPath($Path)
  if(-not (Test-Path -LiteralPath $full -PathType Leaf)){ throw "$Name missing: $full" }
  return $full
}
if($ExpectedHead -notmatch '^[0-9a-f]{40}$'){ throw 'ExpectedHead must be a 40-char lowercase SHA' }
$claude=Resolve-Leaf $ClaudeExecutable 'Claude executable'
$promptPath=Resolve-Leaf $PromptFile 'prompt file'
$wt=[IO.Path]::GetFullPath($Worktree)
if(-not (Test-Path -LiteralPath $wt -PathType Container)){ throw "worktree missing: $wt" }
$out=[IO.Path]::GetFullPath($OutputFile)
if(Test-Path -LiteralPath $out){ throw "output already exists: $out" }
$head=(& git -C $wt rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0 -or $head -ne $ExpectedHead){ throw "review HEAD mismatch expected=$ExpectedHead actual=$head" }
$dirty=(& git -C $wt status --porcelain --untracked-files=no | Out-String).Trim()
if($dirty){ throw 'review worktree has tracked changes' }
$prompt=Get-Content -LiteralPath $promptPath -Raw
if([string]::IsNullOrWhiteSpace($prompt)){ throw 'prompt file is empty' }
$parent=Split-Path -Parent $out
if(-not (Test-Path -LiteralPath $parent)){ New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$lines=@()
$exitCode=1
Push-Location $wt
try {
  $lines=@($prompt | & $claude --print --permission-mode dontAsk --allowedTools Read Glob Grep 2>&1 | ForEach-Object { [string]$_ })
  $exitCode=$LASTEXITCODE
} finally { Pop-Location }
$utf8=New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($out,(($lines -join "`n")+"`n"),$utf8)
if($exitCode -ne 0){ throw "Claude reviewer failed exit=$exitCode output=$out" }
Write-Output "REVIEW_COMPLETE head=$ExpectedHead output=$out"
