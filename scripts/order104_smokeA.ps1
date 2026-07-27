# =============================== HOLDOUT-BURNED ===============================
# ORDER-238 (2026-07-27). One or more test windows in this file end after
# 2025.12.31 -- that is, inside the 2026H1 holdout. They are deliberately LEFT
# AS-IS: they record what past runs actually did, and rewriting them would
# misrepresent that history.
#
# Therefore: do NOT re-run this script to produce selection evidence, and do NOT
# copy its window into new work. A holdout is spent the first time it is touched.
# The current MAIN window is pinned in the VERDICT GATE section of CLAUDE.md.
# ==============================================================================
<#
order104_smokeA.ps1 — ORDER-104 SSRN-151 W1 probe, Smoke Stage A launcher.

Runs the 32-run A/B matrix for (TRD)_Probe_MAHP_TanhVol_rev01:
  4 toggle-combos × {XAUUSD,EURUSD} × {H1,H4} × {BWD 2020-22, REC 2023-26}.
Writes one .set per combo, calls scripts\mt5_run.ps1 sequentially, then scrapes
Profit Factor + Total Trades from each report into _mt5_auto\reports\P104_summary.csv.

PREREQS (must be true or it aborts):
  • MT5 GUI CLOSED (mt5_run guards; it will abort if terminal64.exe of this install is up).
  • ex5 present at  D:\Meta 5\MQL5\Experts\(TRD)_Probe_MAHP_TanhVol_rev01.ex5  (already copied 2026-07-13).

USAGE (unattended, ~run for a while):
  cd D:\EA_LAB ; powershell -ExecutionPolicy Bypass -File scripts\order104_smokeA.ps1

Model 2 (control points) = fast smoke. SURVIVORS get a Model 4 (real-tick) confirm next.
Lambda fixed 14400 here; lambda sweep {1600,129600} = Stage A2 follow-up (edit $combos).
#>
$ErrorActionPreference = "Stop"
$root   = "D:\EA_LAB"
$runner = "$root\scripts\mt5_run.ps1"
$setDir = "$root\_mt5_auto\ab_sets\order104"
$repDir = "$root\_mt5_auto\reports"
New-Item -ItemType Directory -Force $setDir, $repDir | Out-Null

$expert = "(TRD)_Probe_MAHP_TanhVol_rev01"

# combo = name; HP on/off; lambda; tanh on/off
$combos = @(
  @{ n="base"; hp="false"; lam=14400; tanh="false" },
  @{ n="hp";   hp="true";  lam=14400; tanh="false" },
  @{ n="tanh"; hp="false"; lam=14400; tanh="true"  },
  @{ n="both"; hp="true";  lam=14400; tanh="true"  }
)
$symbols = @("XAUUSD","EURUSD")
$periods = @("H1","H4")
$windows = @(
  @{ n="BWD"; from="2020.01.01"; to="2022.12.31" },
  @{ n="REC"; from="2023.01.01"; to="2026.06.01" }
)

# write one .set per combo (only the differing inputs; everything else = EA defaults)
foreach ($c in $combos) {
  $lines = @(
    "_02_UseHPFilter=$($c.hp)",
    "_02_HP_Window=120",
    "_02_HP_Lambda=$($c.lam)",
    "_03_UseTanhVol=$($c.tanh)",
    "_05_LotSize=0.01",
    "_07_AllowLive=false"
  )
  Set-Content -Path "$setDir\$($c.n).set" -Value $lines -Encoding ASCII
}

$total = $combos.Count * $symbols.Count * $periods.Count * $windows.Count
$i = 0
$rows = @()
foreach ($c in $combos) {
  foreach ($sym in $symbols) {
    foreach ($tf in $periods) {
      foreach ($w in $windows) {
        $i++
        $rep = "P104_$($c.n)_${sym}_${tf}_$($w.n)"
        Write-Output "[$i/$total] $rep ..."
        & $runner -Expert $expert -Symbol $sym -Period $tf `
                  -FromDate $w.from -ToDate $w.to -Model 2 `
                  -SetFile "$setDir\$($c.n).set" -ReportName $rep
        # best-effort scrape
        $htm = "$repDir\$rep.htm"
        $pf = ""; $tr = ""
        if (Test-Path $htm) {
          $txt = Get-Content $htm -Raw -Encoding UTF8
          if ($txt -match 'Profit factor[^0-9\-]*([0-9]+\.[0-9]+)') { $pf = $matches[1] }
          if ($txt -match 'Total trades[^0-9\-]*([0-9]+)')          { $tr = $matches[1] }
        }
        $rows += [PSCustomObject]@{ combo=$c.n; symbol=$sym; tf=$tf; window=$w.n; PF=$pf; trades=$tr; report=$rep }
      }
    }
  }
}
$csv = "$repDir\P104_summary.csv"
$rows | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
Write-Output ""
Write-Output "DONE $total runs. Summary -> $csv"
$rows | Format-Table -AutoSize
