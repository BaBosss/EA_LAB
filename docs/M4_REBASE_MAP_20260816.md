# M4 — EA mold / rebase cohort map

- Base SHA: `33d4c7a20695ee9771d95da8d7a14433d8113fdd`
- Scope: six owner-dispositioned REBASE targets only
- Direct consumer: future M2/M3 re-test wave
- Deployment/attachment: none
- Shared-state files: untouched

## Finding

There is no single behavior defect shared by all six targets.

The common M2/M3 reproducibility issue is configuration/provenance: two Boss_14 presets carried copied AUDJPY header metadata, and the two Wave5 deployment presets were sparse override files rather than full pinned surfaces. The four mold-backed targets already use newer template behavior. The two standalone targets do not have exact equivalents in the current mold; porting either would be a mechanism and execution/risk change, not a rebase.

## Exact rebase map

| magic | current identity | target baseline | exact delta | shared mechanism |
|---|---|---|---|---|
| 990103 | `ea_projects/(Boss)_RSI_MR_GridLog/(Boss)_RSI_MR_GridLog_rev01.mq5` + `_vps_deploy/RSI_MR_EURUSD/RSIMR_EURUSD_H1_demo_v1.set` | Owner-approved EURUSDm H1 demo baseline: RSI 25/75, re-arm 50, EMA20 filter, SL ATR 25 capped 600 pips, ATR spacing 9, LOG lot, max 8 positions, max total lot 1.0, magic 990103 | Not implemented. Current mold `LAB_ENTRY_13` is BB+RSI mean reversion, not this dual-side RSI/ATR grid. A faithful port needs a new entry/spec decision and would alter entry, stack, exit, execution, and risk integration. **Behavior-affecting; not provenance-only.** | Standalone `STANDALONE_RISK_BUNDLE.mqh` versus `LabCore + Entry + Execution + RiskControl` |
| 990204 | `ea_template/Boss_14_GridLog.mq5` + `ea_template/sets/Boss14_GridLog_AUDCAD_DEMO.set` | Boss_14 GridLog, AUDCADm, magic 990204; existing full pinned target values | Corrected copied AUDJPY header metadata only. Values unchanged. **Provenance/config-only.** | Already current Boss_14 mold / `LAB_ENTRY_14` |
| 990206 | `ea_template/Boss_14_GridLog.mq5` + `ea_template/sets/Boss14_GridLog_EURUSD_DEMO.set` | Boss_14 GridLog SELL, EURUSDm, magic 990206; existing full pinned target values | Corrected copied AUDJPY header metadata only. Values unchanged. **Provenance/config-only.** | Already current Boss_14 mold / `LAB_ENTRY_14` |
| 990301 | `ea_template/Boss_17_Wave5.mq5` + `_vps_deploy/WAVE5_XAU/WAVE5_XAU_H1_demo_v1.set` | Boss_17 Wave5, XAUUSDm H1, magic 990301: structural SL/TP, entry fib 23.6, wave-3 min 0.618, single level, trail 2000/800 | Added `ea_template/sets/Boss17_Wave5_XAU_990301_M2M3_full.set`, pinning the complete current 159-key surface. Effective values match defaults plus the existing target overrides; no mold source change. **Config/provenance-only.** | Already current Boss_17 mold / `LAB_ENTRY_17` |
| 990302 | `ea_template/Boss_17_Wave5.mq5` + `_vps_deploy/WAVE5_XAG/WAVE5_XAG_H1_demo_v1.set` | Boss_17 Wave5, XAGUSDm H1, magic 990302: same target behavior as 990301 on XAG | Added `ea_template/sets/Boss17_Wave5_XAG_990302_M2M3_full.set`, pinning the complete current 159-key surface. Effective values match defaults plus the existing target overrides; no mold source change. **Config/provenance-only.** | Already current Boss_17 mold / `LAB_ENTRY_17` |
| 999094 | `ea_projects/(EXP)_MacdDiv_Naked/MacdDiv_Naked.mq5` + `_vps_deploy/MACDDIV_XAU/MacdDiv_XAU_H4_demo_v1.set` | MACD divergence naked XAUUSDm H4 baseline: lookback 60, swing radius 3, min separation 2, MACD 12/44/13, ATR 18, 0.15 ATR buffer, 0.01 lot, 2R TP, magic 999094 | Not implemented. Current mold has no MACD-divergence entry. Adding one would define a new `LAB_ENTRY`, new input surface, and shared execution/risk integration. **Behavior-affecting and R3-related; not provenance-only.** | Standalone `CTrade` path versus current mold execution/risk chassis |

## M2/M3 readiness

- Ready for mold-based M2/M3 retest with the committed presets: **990204, 990206, 990301, 990302**.
- Not ready as mold-rebased targets: **990103, 999094**. Their existing standalone baselines remain identifiable, but no unapproved port was made.

## Boundaries observed

- No retirement, removal, reclassification, deployment, attachment, trading, LIVE action, QI-2+, or shared-state edit.
- No `ea_template/core` source change.
- No risk default was changed.
- The full Wave5 presets are additive retest artifacts; they do not replace deployment bundles.
