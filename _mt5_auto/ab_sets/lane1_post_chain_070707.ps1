# Lane-1 post-chain 2026-07-07 — launch AFTER lane1_chain_070707 (batch 22) finishes:
#   step 1: resurrect BWD sweep (has its own preflight kill-zombie; includes
#           carry-over TradePad BWD + UnNomGuai SPR30 at the head)
#   step 2: re-smoke batch-22 EA 1-7 (falsely ABORTed by the zombie terminal;
#           batch label stays "22" so rows merge into the same batch, dupes of
#           the aborted rows are expected -> dedup at review)
$ErrorActionPreference = "Continue"
$log = "D:\EA_LAB\_mt5_auto\lane1_post_chain_070707.log"
"[$(Get-Date -Format s)] post-chain start" | Tee-Object $log -Append

"[$(Get-Date -Format s)] step 1: resurrect BWD sweep" | Tee-Object $log -Append
powershell -File D:\EA_LAB\_mt5_auto\ab_sets\bwdoos_mt4_sweep_resurrect.ps1 | Tee-Object $log -Append

"[$(Get-Date -Format s)] step 2: re-smoke batch-22R (7 EAs)" | Tee-Object $log -Append
powershell -File D:\EA_LAB\scripts\mass_smoke_mt4.ps1 -Batch 22 -WorklistCsv D:\EA_LAB\_triage\mass_smoke_mt4_batch22R.csv | Tee-Object $log -Append

"[$(Get-Date -Format s)] post-chain DONE" | Tee-Object $log -Append
