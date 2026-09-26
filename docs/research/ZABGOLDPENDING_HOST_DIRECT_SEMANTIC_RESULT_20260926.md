# ZABgoldpending â€” host-direct A_OWNER semantic result â€” 2026-09-26

Status: A_OWNER_VALID_FIRST_ENTRY_CAPTURED / FIXED_LOT_BRANCH_OBSERVED / GLOBAL_PRECEDENCE_UNRESOLVED / B_C_NOT_RUN.

This result closes only the owner-manual **A_OWNER** step of the accepted money-mode semantic contract. It does not use or report PF, net, DD, ending balance, win rate, exits or later-path performance.

## Frozen identity

- Family: ZABgoldpending
- exact EX5 SHA256: 75e6d11f298765521d0bbcb7ce37c0e2fdacec3136315dd48047ee2249c9c90
- A_OWNER set SHA256: 4de80df7352a0857bb8e760799582807fbf208271a1762aa34e82c1c166067b9
- carrier: XAUUSD / M5
- model: Model1 / 1 Minute OHLC
- semantic window: 2023-01-01..2023-03-31
- deposit/leverage: 10000 USD / 1:100
- A_OWNER money inputs: Risk_Percent=1.0, Fixed_Lot_Size=0.1
- private account/auth identity was revalidated immediately before Start and remains external to Git.

## Execution history

A first owner-manual Start was rejected as evidence because Strategy Tester actually launched XAU_Scalper_AI_v10, not ZABgoldpending. That false start is preserved as negative mechanical evidence and contributes no ZAB semantic conclusion.

The tester was stopped, the exact ZAB profile was rebuilt and revalidated, and a second owner-manual Start launched ZABgoldpending (XAUUSD,M5) under the frozen A_OWNER surface.

## Admissible A_OWNER evidence

No init/dependency error was observed in the accepted ZAB segment.

The first money-mode decision line was:

2023.01.03 08:00:00 â€” Using Fixed Lot Size: 0.1

The first pending entry request was:

2023.01.03 08:00:00 â€” BUY STOP 0.10 XAUUSD

The first executed entry was:

2023.01.03 08:16:40 â€” BUY 0.10 XAUUSD

Therefore the A_OWNER runtime **selected the fixed-lot branch** and requested/executed 0.10 lot while Risk_Percent=1.0 and Fixed_Lot_Size=0.1 were both present.

## Interpretation boundary

This is sufficient to state:

A_OWNER_FIXED_LOT_BRANCH_OBSERVED.

It is **not** sufficient under the original preregistered A/B/C decision rule to state global FIXED mode active or fully resolve parameter precedence. That rule requires same-signal comparison against both:

- B_FIXED_ONLY: Risk_Percent=1.0, Fixed_Lot_Size=0.2
- C_RISK_ONLY: Risk_Percent=2.0, Fixed_Lot_Size=0.1

Neither B nor C was run. Same-signal timestamp/side comparability is therefore not established.

Current semantic disposition:

GLOBAL_PRECEDENCE_UNRESOLVED__A_OWNER_VALID.

## Evidence

External evidence remains outside Git:

- A_OWNER semantic result: $resultEv, SHA256 $(System.Collections.Specialized.OrderedDictionary.semantic_result)
- accepted agent-log copy: $(@{schema=zab_a_owner_semantic_result/1; observed_utc=2026-09-26T11:02:57.9263040+00:00; source_log=D:\EA_LAB_CONTROL\evidence\zabgoldpending-hostdirect-20260924\ZAB_A_OWNER_AGENT_LOG_20260926T180255.log; source_log_sha256=6346f7fcc5687376873cbf87a5170cae77818e5bd031c1be8d8b627a3b8816fc; segment_start_index=107022; segment_finish_index=207678; expert=ZABgoldpending; symbol=XAUUSD; timeframe=M5; first_fixed_lot_line=CS	0	17:59:14.441	ZABgoldpending (XAUUSD,M5)	2023.01.03 08:00:00   📏 Using Fixed Lot Size: 0.1; first_risk_line=CS	0	17:59:08.185	Tester	  Risk_Percent=1.0; first_pending_order=; first_market_order=; first_deal=; init_or_dependency_errors=System.Object[]; semantic_question=Risk_Percent=1.0 versus Fixed_Lot_Size=0.1 precedence; semantic_conclusion=FIXED_LOT_SIZE_PRECEDENCE_OBSERVED_FOR_A_OWNER; performance_not_read=True; B_C_authorized=False}.source_log), SHA256 $(System.Collections.Specialized.OrderedDictionary.agent_log)
- false-start receipt: $falseEv, SHA256 $(System.Collections.Specialized.OrderedDictionary.false_start)
- exact normal-MT5 profile receipt: $profileEv, SHA256 $(System.Collections.Specialized.OrderedDictionary.exact_profile)
- normal-MT5 prestart receipt: $prestartEv, SHA256 $(System.Collections.Specialized.OrderedDictionary.normal_prestart)

## Authority ceiling / next consumer

- B_FIXED_ONLY: **NOT RUN / NOT AUTHORIZED BY THIS RESULT**
- C_RISK_ONLY: **NOT RUN / NOT AUTHORIZED BY THIS RESULT**
- performance: **NOT READ / NOT RUN AS EVIDENCE**
- optimization: **NOT AUTHORIZED**
- HOLDOUT: **UNSPENT**
- Candidate/Grade/KINT: **NOT AUTHORIZED**
- deployment/LIVE: **NOT AUTHORIZED**

Next consumer: Control Tower may request an **explicit owner continuation** for the already-preregistered B_FIXED_ONLY and C_RISK_ONLY same-signal comparison. Until that explicit continuation exists, stop here.