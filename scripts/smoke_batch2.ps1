<#
smoke_batch2.ps1 — Sequential smoke test of EAs in subfolders (MQL5 EA\, Quantum\)
Each test: 2023.01.01-2026.06.01, Model=1 (OHLC fast), default params.
#>
$ErrorActionPreference = "Continue"
$run  = "D:\EA_LAB\scripts\mt5_run.ps1"
$score = "D:\EA_LAB\scripts\score_backtest.py"
$parse = "C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts\parse_mt5_report.py"
$rep  = "D:\EA_LAB\_mt5_auto\reports"
$auto = "D:\EA_LAB\_mt5_auto"
$from = "2023.01.01"; $to = "2026.06.01"

# EA list: subfolder\name, Symbol, Period, code label
$eas = @(
  # PORT 1 and PORT 6 — correct names found in MQL5 EA\ subfolder
  @{ E="MQL5 EA\rev_010_EA_CelestialWoodfire_141049900"; S="EURUSD"; P="H1"; C="B2_CW_rev010" },
  @{ E="MQL5 EA\rev_012_EA_GoldenEmber_117030969";       S="XAUUSD"; P="H1"; C="B2_GE_rev012" },
  @{ E="MQL5 EA\rev_001_EA_GoldenEmber_117030969_V2";    S="XAUUSD"; P="H1"; C="B2_GE_V2" },

  # Boss grid variants
  @{ E="MQL5 EA\Boss - GridTrendFollower_MTF_ATR_EA";    S="EURUSD"; P="H1"; C="B2_Boss_GTF_ATR" },
  @{ E="MQL5 EA\(Boss) Grid RSI";                        S="EURUSD"; P="H1"; C="B2_Boss_GridRSI" },
  @{ E="MQL5 EA\(Boss) Grid Trend Follower";             S="EURUSD"; P="H1"; C="B2_Boss_GTF" },
  @{ E="MQL5 EA\(Boss) Multi-Timeframe Smart Grid";      S="EURUSD"; P="H1"; C="B2_Boss_MTF_Grid" },
  @{ E="MQL5 EA\Boss - 2 Adaptive Smart Grid";           S="EURUSD"; P="H1"; C="B2_Boss2_ASG" },
  @{ E="MQL5 EA\Boss - Adaptive Grid";                   S="EURUSD"; P="H1"; C="B2_Boss_AG" },
  @{ E="MQL5 EA\Boss - Grid Follower";                   S="EURUSD"; P="H1"; C="B2_Boss_GF" },
  @{ E="MQL5 EA\Boss - Grid Advance";                    S="EURUSD"; P="H1"; C="B2_Boss_GA" },

  # rev_00x series (portfolio EAs)
  @{ E="MQL5 EA\rev_001_Bi-directional_Stop_Grid_Breakout_EA"; S="EURUSD"; P="H1"; C="B2_BiDir_SGB" },
  @{ E="MQL5 EA\rev_001_Smart_Money_EA";                 S="EURUSD"; P="H1"; C="B2_SmartMoney" },
  @{ E="MQL5 EA\rev_001_AstroMaster_4Ports_FULL";        S="EURUSD"; P="H1"; C="B2_AstroMaster" },
  @{ E="MQL5 EA\rev_001_CRT_EA";                         S="EURUSD"; P="H1"; C="B2_CRT" },
  @{ E="MQL5 EA\rev_002_CME_OI_Trader";                  S="XAUUSD"; P="H1"; C="B2_CME_OI" },
  @{ E="MQL5 EA\rev_002_GridTrendFollower_MTF_ATR_EA";   S="EURUSD"; P="H1"; C="B2_GTF_v2" },
  @{ E="MQL5 EA\rev_003_Combo_A_MTF_EA_-_Version_3.0_(High_Frequency_Fix)"; S="EURUSD"; P="H1"; C="B2_ComboA_v3" },
  @{ E="MQL5 EA\rev_006_AdaptiveGrid_v3_Final";          S="EURUSD"; P="H1"; C="B2_AdaptGrid_v3" },
  @{ E="MQL5 EA\rev_007_AW_Recover_Simplified";          S="EURUSD"; P="H1"; C="B2_AW_Recover" },
  @{ E="MQL5 EA\rev_007_Geno_Smart_Signal_V23_EA";       S="EURUSD"; P="H1"; C="B2_Geno_V23" },
  @{ E="MQL5 EA\rev_008_EA_BlazingArrow_159503454";      S="XAUUSD"; P="H1"; C="B2_BlazingArrow" },
  @{ E="MQL5 EA\rev_009_EA_AbyssalDiscipline_111098104"; S="EURUSD"; P="H1"; C="B2_AbyssalD" },
  @{ E="MQL5 EA\rev_009_EA_DragonsWrath_183977997";      S="XAUUSD"; P="H1"; C="B2_DragonsWrath" },
  @{ E="MQL5 EA\rev_009_EA_EmberStrike_141058396";       S="XAUUSD"; P="H1"; C="B2_EmberStrike" },
  @{ E="MQL5 EA\rev_009_EA_SolarEclipse_159149771";      S="EURUSD"; P="H1"; C="B2_SolarEclipse" },
  @{ E="MQL5 EA\rev_009_EA_TwinFlares_141050699";        S="EURUSD"; P="H1"; C="B2_TwinFlares" },
  @{ E="MQL5 EA\rev_010_EA_CrimsonTide_159219430";       S="EURUSD"; P="H1"; C="B2_CrimsonTide" },
  @{ E="MQL5 EA\rev_010_EA_DawnAscendant_193234160";     S="EURUSD"; P="H1"; C="B2_DawnAscendant" },
  @{ E="MQL5 EA\rev_011_EA_IroncladForest_146004104";    S="EURUSD"; P="H1"; C="B2_IroncladForest" },

  # Quantum series
  @{ E="Quantum\Quantum Queen EA MT5 v3.52 @SoftechFX_Robot"; S="EURUSD"; P="H1"; C="B2_QQ_352" },
  @{ E="Quantum\Quantum Athena Fix For MT5 @FundedMillionAiress"; S="EURUSD"; P="H1"; C="B2_Q_Athena" },
  @{ E="Quantum\Quantum Athena_1.1_fix";                 S="EURUSD"; P="H1"; C="B2_Q_Athena11" },
  @{ E="Quantum\Quantum Queen v2.6_.,fix";               S="EURUSD"; P="H1"; C="B2_QQ_26" },
  @{ E="Quantum\Quantum Queen V2.91 MT5";                S="EURUSD"; P="H1"; C="B2_QQ_291" },
  @{ E="Quantum\Quantum Speed";                          S="EURUSD"; P="H1"; C="B2_Q_Speed" },
  @{ E="Quantum\Quantum Valkyrie 4.1 Fix MT5";           S="EURUSD"; P="H1"; C="B2_Q_Valkyrie" }
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
    Write-Output "  NO REPORT (exited). Check EA name / symbol."
    $results += [PSCustomObject]@{ Code=$ea.C; EA=$ea.E; Symbol=$ea.S; PF="NOHTM"; DD="-"; Trades="-"; Verdict="NOHTM" }
    continue
  }

  $json = "$auto\${rname}_parsed.json"
  python $parse $htm | Set-Content $json -Encoding UTF8

  $out = python $score $json --strategy trend 2>&1
  Write-Output "  $($out | Select-String 'PF=|VERDICT')"

  $pf = ($out | Select-String 'PF=').ToString() -replace '.*PF=(\S+).*','$1'
  $dd = ($out | Select-String 'PF=').ToString() -replace '.*DD%=(\S+).*','$1'
  $tr = ($out | Select-String 'PF=').ToString() -replace '.*trades=(\S+).*','$1'
  $vd = if ($out | Select-String 'PASS') { "PASS" } elseif ($out | Select-String 'WATCH') { "WATCH" } elseif ($out | Select-String 'REJECT') { "REJECT" } else { "?" }

  $results += [PSCustomObject]@{ Code=$ea.C; EA=$ea.E; Symbol=$ea.S; PF=$pf; DD=$dd; Trades=$tr; Verdict=$vd }
}

Write-Output "`n===== SMOKE BATCH 2 SUMMARY ====="
$results | Format-Table -AutoSize

# Save to file
$results | Export-Csv "$auto\smoke_batch2_results.csv" -NoTypeInformation -Encoding UTF8
Write-Output "Saved: $auto\smoke_batch2_results.csv"
