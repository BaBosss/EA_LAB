<#
.SYNOPSIS
  Anti-drift guard for EA_LAB docs. ORDER-093 rewrite (2026-07-11, CODEX-AUDIT A2/C1):
  the deployment inventory portfolio\DEPLOYMENTS.csv is the machine-readable owner of
  "what runs where"; this script validates every other surface AGAINST it instead of
  checking that a few hardcoded legacy strings exist somewhere.
  Warn-only (exit 0) unless -Strict (used by .githooks\pre-commit).

.DESCRIPTION
  Checks:
   1. PROJECT_STATE.md exists and declares the DEPLOYMENTS.csv pointer (section 0.5)
   2. DEPLOYMENTS.csv parses, has required columns, no duplicate account|magic
   3. every account in the inventory appears in DEMO_DEPLOYMENT_PLAN.md
   4. every inventory row with a magic (status not UNVERIFIED) has a dashboard cohort
      map entry "account|magic" in scripts\live_dashboard.ps1
   5. every dashboard cohort map entry maps back to an inventory row (no ghost rows)
   6. every judge_date in the inventory appears in DEMO_DEPLOYMENT_PLAN.md
   7. no competing single-entry claim outside PROJECT_STATE (EN/TH needles)
   8. owner banner present on secondary owner docs
  ASCII-only on purpose (Windows PowerShell 5.1 reads scripts as ANSI).
  NOTE: data variable is $rows, NOT $inv - PS variables are case-insensitive and
  $inv would collide with the $INV path constant.
#>
[CmdletBinding()]
param(
  [string]$Root = $(if($PSScriptRoot){ (Resolve-Path (Join-Path $PSScriptRoot '..')).Path } else { (Get-Location).Path }),
  [switch]$Strict
)

$script:warn = 0
function Check($cond,$okMsg,$warnMsg){
  if($cond){ Write-Host "[OK]   $okMsg" -ForegroundColor Green }
  else     { Write-Host "[WARN] $warnMsg" -ForegroundColor Yellow; $script:warn++ }
}
function Has($file,$needle){ (Test-Path $file) -and ((Get-Content $file -Raw -Encoding UTF8 -ErrorAction SilentlyContinue) -match [regex]::Escape($needle)) }

$PS   = Join-Path $Root 'PROJECT_STATE.md'
$DEMO = Join-Path $Root 'DEMO_DEPLOYMENT_PLAN.md'
$BL   = Join-Path $Root 'MASTER_BACKLOG.md'
$SC   = Join-Path $Root 'EA_SCORECARD_AND_REGISTRY.md'
$INV  = Join-Path $Root 'portfolio\DEPLOYMENTS.csv'
$DASH = Join-Path $Root 'scripts\live_dashboard.ps1'

Write-Host "=== EA_LAB state consistency check (inventory-driven, ORDER-093) ===" -ForegroundColor Cyan

# 1. canonical entry + inventory pointer
Check (Test-Path $PS) "PROJECT_STATE.md exists (the entry point)" "PROJECT_STATE.md MISSING - canonical entry gone"
Check (Has $PS 'DEPLOYMENTS.csv') "PROJECT_STATE declares the DEPLOYMENTS.csv inventory pointer" "PROJECT_STATE does not reference portfolio\DEPLOYMENTS.csv (section 0.5 pointer missing)"

# 2. inventory parses + shape
$rows = $null
if (Test-Path $INV) { try { $rows = @(Import-Csv $INV -Encoding UTF8) } catch { $rows = $null } }
Check ($null -ne $rows -and $rows.Count -gt 0) "DEPLOYMENTS.csv parses ($(if($rows){$rows.Count}else{0}) rows)" "portfolio\DEPLOYMENTS.csv missing or unparseable"
if ($null -ne $rows -and $rows.Count -gt 0) {
  $required = @('account','ea_name','magic','symbol','status','judge_date')
  $cols = $rows[0].PSObject.Properties.Name
  $missingCols = @($required | Where-Object { $cols -notcontains $_ })
  Check ($missingCols.Count -eq 0) "inventory has all required columns" ("inventory missing columns: " + ($missingCols -join ', '))

  $withMagic = @($rows | Where-Object { $_.magic -match '^\d+$' })
  $dups = @($withMagic | Group-Object { "$($_.account)|$($_.magic)" } | Where-Object Count -gt 1)
  Check ($dups.Count -eq 0) "no duplicate account|magic in inventory" ("duplicate account|magic: " + (($dups | ForEach-Object Name) -join ', '))

  # 3. accounts present in the deployment narrative doc
  $demoRaw = if (Test-Path $DEMO) { Get-Content $DEMO -Raw -Encoding UTF8 } else { '' }
  $accts = @($rows | Select-Object -ExpandProperty account -Unique)
  $missA = @($accts | Where-Object { $demoRaw -notmatch [regex]::Escape($_) })
  Check ($missA.Count -eq 0) "all $($accts.Count) inventory accounts present in DEMO_DEPLOYMENT_PLAN" ("accounts missing from DEMO plan: " + ($missA -join ', '))

  # 4/5. dashboard cohort map <-> inventory (bidirectional)
  $dashRaw = if (Test-Path $DASH) { Get-Content $DASH -Raw -Encoding UTF8 } else { '' }
  $mapKeys = @([regex]::Matches($dashRaw,'"(\d+)\|(\d+)"\s*=') | ForEach-Object { "$($_.Groups[1].Value)|$($_.Groups[2].Value)" })
  $invKeys = @($withMagic | Where-Object { $_.status -ne 'UNVERIFIED' } | ForEach-Object { "$($_.account)|$($_.magic)" })
  $notMapped = @($invKeys | Where-Object { $mapKeys -notcontains $_ })
  Check ($notMapped.Count -eq 0) "all $($invKeys.Count) inventory magics mapped in dashboard cohort" ("inventory rows with NO dashboard map entry (unmonitored magic - audit A5): " + ($notMapped -join ', '))
  $ghost = @($mapKeys | Where-Object { $k = $_; -not ($withMagic | Where-Object { "$($_.account)|$($_.magic)" -eq $k }) })
  Check ($ghost.Count -eq 0) "no ghost dashboard map entries (all $($mapKeys.Count) map keys exist in inventory)" ("dashboard map entries NOT in inventory (stale map or missing inventory row): " + ($ghost -join ', '))

  # 6. judge dates in narrative doc
  $judges = @($rows | Where-Object { $_.judge_date -match '^\d{4}-\d{2}-\d{2}$' } | Select-Object -ExpandProperty judge_date -Unique)
  $missJ = @($judges | Where-Object { $demoRaw -notmatch [regex]::Escape($_) })
  Check ($missJ.Count -eq 0) "all judge dates ($($judges -join ', ')) present in DEMO plan" ("judge dates missing from DEMO plan: " + ($missJ -join ', '))
}

# 7. no competing single-entry claim (English OR Thai) outside PROJECT_STATE
$thaiOnly = -join (0x0E44,0x0E1F,0x0E25,0x0E4C,0x0E40,0x0E14,0x0E35,0x0E22,0x0E27 | ForEach-Object {[char]$_})
$rivals = Get-ChildItem $Root -Filter *.md | Where-Object { $_.Name -ne 'PROJECT_STATE.md' -and $_.Name -notmatch 'RESUME|RUN_REGISTRY' } |
  Where-Object { $c = (Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue); ($c -match 'single source of truth') -or ($c -match [regex]::Escape($thaiOnly)) }
Check ($rivals.Count -eq 0) "no competing single-entry claim (EN/TH)" ("competing entry claim in: " + (($rivals | ForEach-Object Name) -join ', '))

# 8. owner banner present on the secondary owners
foreach($f in @($DEMO,$BL,$SC)){
  $n = Split-Path $f -Leaf
  Check (Has $f 'canonical entry =') "$n has owner banner" "$n missing 'canonical entry =' banner"
}

if($script:warn -eq 0){ Write-Host "=== CLEAN - no drift detected ===" -ForegroundColor Green }
else { Write-Host ("=== {0} WARNING(s) - fix the drift above ===" -f $script:warn) -ForegroundColor Yellow }
if($Strict -and $script:warn -gt 0){ exit 1 }
exit 0
