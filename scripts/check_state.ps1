<#
.SYNOPSIS
  Anti-drift guard for EA_LAB docs. Checks the INVARIANTS declared in
  PROJECT_STATE.md against the owner docs and warns on any mismatch.
  Warn-only (exit 0) - it never blocks; it just surfaces drift before commit.

.DESCRIPTION
  Root cause of "re-read never matches last read" = same fact restated in many
  docs + manual updates. This script encodes the few hard invariants ONCE (here)
  and flags any doc that contradicts or is missing them. Run before each commit:
      powershell -File D:\EA_LAB\scripts\check_state.ps1
  Update the invariants below whenever PROJECT_STATE section 0.5 changes.
  ASCII-only on purpose (Windows PowerShell 5.1 reads scripts as ANSI).
#>
[CmdletBinding()]
param(
  [string]$Root = 'D:\EA_LAB',
  [switch]$Strict   # exit 1 on any warning (used by the git pre-commit hook)
)

# ---- INVARIANTS (mirror PROJECT_STATE.md section 0.5) ----
$JUDGE   = '2026-09-22'
$ACCOUNT = '10,000 cent'
$MAGICS  = '1524','9397','9398','990005','990010','991001','991002'

$script:warn = 0
function Has($file,$needle){ (Test-Path $file) -and ((Get-Content $file -Raw -ErrorAction SilentlyContinue) -match [regex]::Escape($needle)) }
function Check($cond,$okMsg,$warnMsg){
  if($cond){ Write-Host "[OK]   $okMsg" -ForegroundColor Green }
  else     { Write-Host "[WARN] $warnMsg" -ForegroundColor Yellow; $script:warn++ }
}

$PS   = Join-Path $Root 'PROJECT_STATE.md'
$DEMO = Join-Path $Root 'DEMO_DEPLOYMENT_PLAN.md'
$BL   = Join-Path $Root 'MASTER_BACKLOG.md'
$SC   = Join-Path $Root 'EA_SCORECARD_AND_REGISTRY.md'

Write-Host "=== EA_LAB state consistency check ===" -ForegroundColor Cyan
Check (Test-Path $PS) "PROJECT_STATE.md exists (the entry point)" "PROJECT_STATE.md MISSING - canonical entry gone"

# 1. judge date present in the two status owners
Check ((Has $PS $JUDGE) -and (Has $DEMO $JUDGE)) "judge date $JUDGE consistent in PROJECT_STATE + DEMO" "judge date $JUDGE missing from PROJECT_STATE or DEMO_DEPLOYMENT_PLAN"

# 2. account size present in both
Check ((Has $PS $ACCOUNT) -and (Has $DEMO $ACCOUNT)) "account '$ACCOUNT' consistent" "account '$ACCOUNT' missing from PROJECT_STATE or DEMO"

# 3. no competing 'single source of truth' claim outside PROJECT_STATE
$rivals = Get-ChildItem $Root -Filter *.md | Where-Object { $_.Name -ne 'PROJECT_STATE.md' -and $_.Name -notmatch 'RESUME|RUN_REGISTRY' } |
  Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match 'single source of truth' }
Check ($rivals.Count -eq 0) "no competing 'single source of truth' claims" ("competing entry claim in: " + (($rivals | ForEach-Object Name) -join ', '))

# 4. owner banner present on the secondary owners
foreach($f in @($DEMO,$BL,$SC)){
  $n = Split-Path $f -Leaf
  Check (Has $f 'canonical entry =') "$n has owner banner" "$n missing 'canonical entry =' banner"
}

# 5. every magic in the map appears in the live portfolio owner
$missing = $MAGICS | Where-Object { -not (Has $DEMO $_) }
Check ($missing.Count -eq 0) "all $($MAGICS.Count) magics present in DEMO_DEPLOYMENT_PLAN" ("magics missing from DEMO: " + ($missing -join ', '))

if($script:warn -eq 0){ Write-Host "=== CLEAN - no drift detected ===" -ForegroundColor Green }
else { Write-Host ("=== {0} WARNING(s) - fix the drift above ===" -f $script:warn) -ForegroundColor Yellow }
if($Strict -and $script:warn -gt 0){ exit 1 }
exit 0
