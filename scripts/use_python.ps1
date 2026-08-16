# use_python.ps1 - make repo-local Python available for THIS process only.
# The box has no system Python; a portable embeddable build lives in tools\python312.
# Dot-source before any script that calls bare `python`:
#     . D:\EA_LAB\scripts\use_python.ps1
# (Process-scoped on purpose - do NOT persist to user/system PATH.)
$py = Join-Path (Split-Path $PSScriptRoot -Parent) 'tools\python312'

function Assert-PortablePython {
  [CmdletBinding()]
  param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent),
    [switch]$Provision
  )

  $runtime = Join-Path $Root 'tools\python312'
  $exe = Join-Path $runtime 'python.exe'
  $stdlib = Join-Path $runtime 'python312.zip'
  if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw "portable Python executable missing at $exe"
  }

  if (-not (Test-Path -LiteralPath $stdlib -PathType Leaf) -and $Provision) {
    $common = (& git --no-optional-locks -C $Root rev-parse --git-common-dir 2>$null |
      Select-Object -Last 1).ToString().Trim()
    if ($common) {
      if (-not [System.IO.Path]::IsPathRooted($common)) {
        $common = Join-Path $Root ($common -replace '/', '\')
      }
      try {
        $commonRoot = Split-Path -Parent (Resolve-Path -LiteralPath $common -ErrorAction Stop).Path
        $approved = Join-Path $commonRoot 'tools\python312\python312.zip'
        if ((Test-Path -LiteralPath $approved -PathType Leaf) -and
            ((Resolve-Path -LiteralPath $approved).Path -ne
             (Resolve-Path -LiteralPath $stdlib -ErrorAction SilentlyContinue).Path)) {
          New-Item -ItemType Directory -Path $runtime -Force -ErrorAction Stop | Out-Null
          Copy-Item -LiteralPath $approved -Destination $stdlib -Force -ErrorAction Stop
        }
      } catch {
        # The final error below names the exact missing prerequisite and source lookup.
      }
    }
  }

  if (-not (Test-Path -LiteralPath $stdlib -PathType Leaf)) {
    throw "portable Python stdlib archive missing at $stdlib; restore tools/python312/python312.zip in the source checkout or provision the approved local runtime"
  }

  $probe = @(& $exe -c 'import encodings' 2>&1)
  if ($LASTEXITCODE -ne 0) {
    $detail = (($probe | Select-Object -Last 3) -join ' ').Trim()
    throw "portable Python at $exe cannot load its stdlib archive $stdlib; $detail"
  }
  if ($env:Path -notlike "*$runtime*") { $env:Path = "$runtime;$env:Path" }
  return $exe
}

if (-not (Test-Path -LiteralPath (Join-Path $py 'python.exe') -PathType Leaf)) {
  Write-Warning "portable python missing at $py - re-download python-3.12 embed-amd64 zip"
} elseif ($env:Path -notlike "*$py*") {
  $env:Path = "$py;$env:Path"
}
