# ZABgoldpending - host-direct A_OWNER semantic result - 2026-09-26

Status: `A_OWNER_VALID_FIRST_ENTRY_CAPTURED / FIXED_LOT_BRANCH_OBSERVED / GLOBAL_PRECEDENCE_UNRESOLVED / B_C_NOT_RUN`.

This result closes only the owner-manual **A_OWNER** step of the accepted money-mode semantic contract. It does not use or report PF, net, DD, ending balance, win rate, exits or later-path performance.

## Frozen identity

- Family: `ZABgoldpending`
- exact EX5 SHA256: `f75e6d11f298765521d0bbcb7ce37c0e2fdacec3136315dd48047ee2249c9c90`
- A_OWNER set SHA256: `4de80df7352a0857bb8e760799582807fbf208271a1762aa34e82c1c166067b9`
- carrier: `XAUUSD / M5`
- model: Model1 / 1 Minute OHLC
- semantic window: `2023-01-01..2023-03-31`
- deposit/leverage: `10000 USD / 1:100`
- A_OWNER money inputs: `Risk_Percent=1.0`, `Fixed_Lot_Size=0.1`
- private account/auth identity was revalidated immediately before Start and remains external to Git.

## Execution history

A first owner-manual Start was rejected as evidence because Strategy Tester actually launched `XAU_Scalper_AI_v10`, not `ZABgoldpending`. That false start is preserved as negative mechanical evidence and contributes no ZAB semantic conclusion.

The tester was stopped, the exact ZAB profile was rebuilt and revalidated, and a second owner-manual Start launched `ZABgoldpending (XAUUSD,M5)` under the frozen A_OWNER surface.

## Admissible A_OWNER evidence

No init/dependency error was observed in the accepted ZAB segment.

The first money-mode decision line was:

`2023.01.03 08:00:00 - Using Fixed Lot Size: 0.1`

The first pending entry request was:

`2023.01.03 08:00:00 - BUY STOP 0.10 XAUUSD`

The first executed entry was:

`2023.01.03 08:16:40 - BUY 0.10 XAUUSD`

Therefore the A_OWNER runtime **selected the fixed-lot branch** and requested/executed 0.10 lot while `Risk_Percent=1.0` and `Fixed_Lot_Size=0.1` were both present.

## Interpretation boundary

This is sufficient to state:

`A_OWNER_FIXED_LOT_BRANCH_OBSERVED`.

It is **not** sufficient under the original preregistered A/B/C decision rule to state global `FIXED mode active` or fully resolve parameter precedence. That rule requires same-signal comparison against both:

- `B_FIXED_ONLY`: Risk_Percent=1.0, Fixed_Lot_Size=0.2
- `C_RISK_ONLY`: Risk_Percent=2.0, Fixed_Lot_Size=0.1

Neither B nor C was run. Same-signal timestamp/side comparability is therefore not established.

Current semantic disposition:

`GLOBAL_PRECEDENCE_UNRESOLVED__A_OWNER_VALID`.

## Evidence

External evidence remains outside Git:

- A_OWNER semantic result: `D:\EA_LAB_CONTROL\evidence\zabgoldpending-hostdirect-20260924\ZAB_A_OWNER_SEMANTIC_RESULT_20260926T180255.json`, SHA256 `17ceb9dfd96d541697571262b3a6e20979a0978ea2dd9d98e91a88f2c3091c08`
- accepted agent-log copy: `D:\EA_LAB_CONTROL\evidence\zabgoldpending-hostdirect-20260924\ZAB_A_OWNER_AGENT_LOG_20260926T180255.log`, SHA256 `6346f7fcc5687376873cbf87a5170cae77818e5bd031c1be8d8b627a3b8816fc`
- false-start receipt: `D:\EA_LAB_CONTROL\evidence\zabgoldpending-hostdirect-20260924\ZAB_A_OWNER_FALSE_START_20260926T004635.json`, SHA256 `a36ceb9aad16a13aafa0fbcb6ea282c6fe27e44474d2cae093181b88e03af490`
- exact normal-MT5 profile receipt: `D:\EA_LAB_CONTROL\evidence\zabgoldpending-hostdirect-20260924\ZAB_NORMAL_MT5_EXACT_PROFILE_20260926T004742.json`, SHA256 `386f31f7e6e9f28ceab81d3b6ff61b3ead4c098e5e54542a5c468b71536713f3`
- normal-MT5 prestart receipt: `D:\EA_LAB_CONTROL\evidence\zabgoldpending-hostdirect-20260924\ZAB_NORMAL_MT5_PRESTART_20260926T002421.json`, SHA256 `d40f58c26a807425218ced81fefd52fe498511ff59c3230e853d33da9771e032`

The exact-head review bundle additionally contains a privacy-safe admissible-line extract and a redacted prestart identity derivative. Private account/auth values are not copied into Git or the review bundle.

## Authority ceiling / next consumer

- B_FIXED_ONLY: **NOT RUN / NOT AUTHORIZED BY THIS RESULT**
- C_RISK_ONLY: **NOT RUN / NOT AUTHORIZED BY THIS RESULT**
- performance: **NOT READ / NOT RUN AS EVIDENCE**
- optimization: **NOT AUTHORIZED**
- HOLDOUT: **UNSPENT**
- Candidate/Grade/KINT: **NOT AUTHORIZED**
- deployment/LIVE: **NOT AUTHORIZED**

Next consumer: Control Tower may request an **explicit owner continuation** for the already-preregistered B_FIXED_ONLY and C_RISK_ONLY same-signal comparison. Until that explicit continuation exists, stop here.
