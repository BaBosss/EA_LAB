# use_python.ps1 - make repo-local Python available for THIS process only.
# The box has no system Python; a portable embeddable build lives in tools\python312.
# Dot-source before any script that calls bare `python`:
#     . D:\EA_LAB\scripts\use_python.ps1
# (Process-scoped on purpose - do NOT persist to user/system PATH.)
$py = Join-Path (Split-Path $PSScriptRoot -Parent) 'tools\python312'
if (-not (Test-Path (Join-Path $py 'python.exe'))) {
  Write-Warning "portable python missing at $py - re-download python-3.12 embed-amd64 zip"
} elseif ($env:Path -notlike "*$py*") {
  $env:Path = "$py;$env:Path"
}
