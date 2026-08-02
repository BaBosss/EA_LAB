//+------------------------------------------------------------------+
//| B14_H02_r1_allowlist.mqh - GENERATED FILE, DO NOT EDIT BY HAND.
//| generator : _triage/factory_os/gen_wrapper.py
//| revision  : B14-H02-r1
//| regenerate: tools\python312\python.exe _triage/factory_os/gen_wrapper.py --write
//|
//| ORDER-1021 (design 5.3). One token per capability module this revision's
//| PINNED CONFIG can reach. The set is derived by capability.enabled_tokens()
//| from the same selectors the architecture digest reads, so it cannot disagree
//| with the module_set on this revision's Hypothesis row.
//|
//| MQL5 has no `#if EXPR==n` and no `#elif` (Inputs.mqh:11 says so), so this file
//| emits TOKEN #defines only. Any design that assumes expression conditionals is
//| wrong on this platform.
//+------------------------------------------------------------------+
#ifndef BOSS_ALLOWLIST_B14_H02_R1_MQH
#define BOSS_ALLOWLIST_B14_H02_R1_MQH

#define LAB_CAP_CORE
#define LAB_CAP_ENTRY_GRIDLOG
#define LAB_CAP_EXEC
#define LAB_CAP_EXIT
#define LAB_CAP_HEDGE
#define LAB_CAP_INDICATORS
#define LAB_CAP_LOTPROG
#define LAB_CAP_MM
#define LAB_CAP_RISK
#define LAB_CAP_STACK

#endif // BOSS_ALLOWLIST_B14_H02_R1_MQH
