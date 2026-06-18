<#
smoke_all.ps1 — Sequential smoke test of all untested EAs
Each test: 2023.01.01-2026.06.01, Model=1 (OHLC fast), default params.
Results land in _mt5_auto/reports/SMOKE_<code>.htm and are scored at end.
#>
$ErrorActionPreference = "Continue"
$run  = "D:\EA_LAB\scripts\mt5_run.ps1"
$score = "D:\EA_LAB\scripts\score_backtest.py"
$parse = "C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts\parse_mt5_report.py"
$rep  = "D:\EA_LAB\_mt5_auto\reports"
$auto = "D:\EA_LAB\_mt5_auto"
$from = "2023.01.01"; $to = "2026.06.01"

# EA list: Expert name, Symbol, Period, code label
$eas = @(
  @{ E="(GPM) Almost 1 Direction v1.9.3"; S="EURUSD"; P="H1"; C="GPM_1dir" },
  @{ E="BaronGrid";                        S="EURUSD"; P="H1"; C="BaronGrid" },
  @{ E="Boss - 6 Pivot Range Trading";     S="EURUSD"; P="H1"; C="Boss6Pivot" },
  @{ E="EA Among Us";                      S="EURUSD"; P="H1"; C="EAAmongUs" },
  @{ E="EA Black Dragon MT5 V13";          S="XAUUSD"; P="H1"; C="BlackDragon" },
  @{ E="EA TREND";                         S="EURUSD"; P="H1"; C="EA_TREND_v1" },
  @{ E="EasyMoney_V1";                     S="EURUSD"; P="H1"; C="EasyMoney" },
  @{ E="Gold_SMC_Continuous_MT5";          S="XAUUSD"; P="H1"; C="GSMC_orig" },
  @{ E="Gold_SMC_FiboRecovery_MT5";        S="XAUUSD"; P="H1"; C="GSMC_Fibo" },
  @{ E="Immortal Gold";                    S="XAUUSD"; P="H1"; C="ImmortalGold" },
  @{ E="JanusGrid_EA_v2_5";               S="EURUSD"; P="H1"; C="JanusGrid" },
  @{ E="Knight Sword EA";                  S="EURUSD"; P="H1"; C="KnightSword" },
  @{ E="KNTPTT Grid Scalp Pro real no bug"; S="EURUSD"; P="H1"; C="KNTPTT_Grid" },
  @{ E="KNTPTT LongTerm DCA EA";           S="EURUSD"; P="H4"; C="KNTPTT_DCA" },
  @{ E="KNTPTT_KnightSword_v2";           S="EURUSD"; P="H1"; C="KNTPTT_KS2" },
  @{ E="LowCortisolGrid";                  S="EURUSD"; P="H1"; C="LowCortisol" },
  @{ E="LQ Scalper";                       S="EURUSD"; P="M15"; C="LQ_Scalper" },
  @{ E="Perfect EA(M4) AutoHedging(EX2)"; S="EURUSD"; P="H1"; C="PerfectEA" },
  @{ E="PORT 1 $([char]0x2014) EA_CelestialWoodfire";   S="EURUSD"; P="H1"; C="Port1_CW" },
  @{ E="PORT 6 $([char]0x2014) EA_GoldenEmber";         S="XAUUSD"; P="H1"; C="Port6_GE" },
  @{ E="Sentinel XAU_1.2_fix";            S="XAUUSD"; P="H1"; C="Sentinel12" },
  @{ E="SNOWBALL GENIUS HYBRID";           S="EURUSD"; P="H1"; C="Snowball" },
  @{ E="The Gold Reaper MT5_4.3_fix_@FundedMillionAiress"; S="XAUUSD"; P="H1"; C="GoldReaper" },
  @{ E="UnifiedRegressionEA";             S="EURUSD"; P="H1"; C="UnifiedReg" },
  @{ E="V2_15_SEMI_ORI_FINAL";            S="EURUSD"; P="H1"; C="V2_15_SEMI" },
  @{ E="XAU_Scalper_AI_v10";              S="XAUUSD"; P="H1"; C="XAU_AI_v10" },
  @{ E="ZyFer_Noname";                    S="EURUSD"; P="H1"; C="ZyFer" }
)

$results = @()
$n = $eas.Count
$i = 0

foreach ($ea in $eas) {
  $i++
  $rname = "SMOKE_$($ea.C)"
  $htm   = "$rep\$rname.htm"
  Write-Output "[$i/$n] $($ea.E) | $($ea.S) $($ea.P) -> $rname"

  try {
    & $run -Expert $ea.E -Symbol $ea.S -Period $ea.P -Model 1 `
           -FromDate $from -ToDate $to -ReportName $rname -ErrorAction Stop
  } catch {
    Write-Output "  ERROR launch: $_"
    $results += [PSCustomObject]@{ Code=$ea.C; EA=$ea.E; Symbol=$ea.S; PF="ERR"; DD="ERR"; Trades="ERR"; Verdict="ERROR" }
    continue
  }

  if (-not (Test-Path $htm)) {
    Write-Output "  SKIP: no report"
    $results += [PSCustomObject]@{ Code=$ea.C; EA=$ea.E; Symbol=$ea.S; PF="NOHTM"; DD="-"; Trades="-"; Verdict="NOHTM" }
    continue
  }

  $json = "$auto\${rname}_parsed.json"
  python $parse $htm | Set-Content $json -Encoding UTF8

  $out = python $score $json --strategy trend 2>&1
  Write-Output "  $($out | Select-String 'PF=|VERDICT')"

  # quick parse score output
  $pf = ($out | Select-String 'PF=').ToString() -replace '.*PF=(\S+).*','$1'
  $dd = ($out | Select-String 'PF=').ToString() -replace '.*DD%=(\S+).*','$1'
  $tr = ($out | Select-String 'PF=').ToString() -replace '.*trades=(\S+).*','$1'
  $vd = if ($out | Select-String 'PASS') { "PASS" } elseif ($out | Select-String 'WATCH') { "WATCH" } elseif ($out | Select-String 'REJECT') { "REJECT" } else { "?" }

  $results += [PSCustomObject]@{ Code=$ea.C; EA=$ea.E; Symbol=$ea.S; PF=$pf; DD=$dd; Trades=$tr; Verdict=$vd }
}

Write-Output "`n===== SMOKE TEST SUMMARY ====="
$results | Format-Table -AutoSize

# Save to file
$results | Export-Csv "$auto\smoke_all_results.csv" -NoTypeInformation -Encoding UTF8
Write-Output "Saved: $auto\smoke_all_results.csv"
