[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$Root='D:\EA_LAB_CONTROL\lnwjud-write-v1-20260928'
$Canonical=Join-Path $Root 'canonical'
$Workspace=Join-Path $Root 'workspace'
$Builder=Join-Path $Root 'build_snapshot.py'
$Python=Join-Path $Canonical 'tools\python312\python.exe'
$LockPath=Join-Path $Root '.write-mutation.lock'
$Evidence='D:\EA_LAB_CONTROL\evidence\lnwjud-write-v1-20260928\LNWJUD_WRITE_V1_REFRESH_LAST.json'
$Utf8NoBom=New-Object Text.UTF8Encoding($false)

$lock=$null
try{
  try{
    $lock=[IO.File]::Open($LockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes(("{0}|{1}" -f $PID,[DateTimeOffset]::UtcNow.ToString('o')))
    $lock.Write($bytes,0,$bytes.Length);$lock.Flush($true)
  }
  catch [IO.IOException]{Write-Output 'REFRESH_SKIPPED_MUTATION_LOCK_PRESENT';exit 0}

  $canonTracked=(git -C $Canonical status --porcelain=v1 --untracked-files=no|Out-String).Trim()
  if($canonTracked){throw 'canonical read worktree has tracked changes'}
  git -C $Canonical fetch origin master
  if($LASTEXITCODE-ne0){throw 'fetch failed'}
  $origin=(git -C $Canonical rev-parse origin/master).Trim()
  $remote=((git -C $Canonical ls-remote origin refs/heads/master)-split '\s+')[0]
  if($origin-ne$remote){throw "origin/master != ls-remote: $origin / $remote"}
  $before=(git -C $Canonical rev-parse HEAD).Trim()
  if($before-ne$origin){
    git -C $Canonical checkout --detach $origin
    if($LASTEXITCODE-ne0){throw 'canonical detached checkout failed'}
  }

  $workspaceAction='PRESERVED'
  $wsDirty=(git -C $Workspace status --porcelain=v1 --untracked-files=all|Out-String).Trim()
  $wsBefore=(git -C $Workspace rev-parse HEAD).Trim()
  if(-not$wsDirty -and $wsBefore-ne$origin){
    git -C $Workspace merge-base --is-ancestor $wsBefore $origin
    if($LASTEXITCODE-eq0){
      git -C $Workspace merge --ff-only origin/master
      if($LASTEXITCODE-ne0){throw 'clean write workspace ff-only failed'}
      $workspaceAction='FF_ONLY'
    }else{
      $workspaceAction='CLEAN_DIVERGED_PRESERVED'
    }
  }elseif($wsDirty){
    $workspaceAction='DIRTY_PRESERVED'
  }else{
    $workspaceAction='ALREADY_CURRENT'
  }

  & $Python $Builder
  if($LASTEXITCODE-ne0){throw "snapshot builder failed rc=$LASTEXITCODE"}
  $seal=Get-Content -LiteralPath (Join-Path $Root 'snapshot\snapshot_seal.json') -Raw -Encoding UTF8|ConvertFrom-Json
  if([string]$seal.canonical_head-ne$origin){throw 'snapshot postcondition canonical mismatch'}
  $obj=[ordered]@{
    result='PASS';refreshed_at=[DateTimeOffset]::Now.ToString('o')
    previous_canonical_head=$before;canonical_head=$origin;ls_remote=$remote
    snapshot_id=$seal.snapshot_id;captured_at_utc=$seal.captured_at_utc
    workspace_action=$workspaceAction;workspace_head=(git -C $Workspace rev-parse HEAD).Trim()
    workspace_dirty=(-not[string]::IsNullOrWhiteSpace((git -C $Workspace status --porcelain=v1 --untracked-files=all|Out-String)))
  }
  [IO.File]::WriteAllText($Evidence,($obj|ConvertTo-Json -Depth 6),$Utf8NoBom)
  $obj|ConvertTo-Json -Compress
}finally{
  if($null-ne$lock){
    $lock.Dispose()
    Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
  }
}
