# B16 XAUUSD/H4 Exit-Concentration V1 — Control Gate Block

Status: `BLOCKED / D EXECUTION-INCOMPLETE (CONTROL_MISMATCH) / RESEARCH_ONLY`
Hypothesis: `HYP-B16-XAU-H4-EXITCONC-01`
Preregistration commit: `adada829b642f8f1691f0ca37fb88c338c8087d4`
New MT5 runs: `NONE`; Optimization: `NONE`; HOLDOUT: `UNSPENT`.

## What ran

The preregistered analyzer executed once after the preregistration was pushed canonical. It performed the matched-output control gate first and stopped before parsing any eligible exit-off child window because the XAUUSD/H4 MAIN `DEEP_SPACING_EQUAL` proxy did not reproduce the accepted parent headline.

Accepted parent MAIN: PF `4.08`, net `+707.78`, trades `79`, EqDD `6.27%`, report SHA256 `aee6819ba12f929caade4cf1b70915978a3259ec2b7136a1009e077057bb0e7e`.
Observed proxy MAIN: PF `4.40`, net `+700.92`, trades `80`, EqDD `7.31%`, report SHA256 `1da440acecc1cb0f309c3c4720df94fea76b83bf32e4056b2a9e1c9ed3025128`.

This is a real control mismatch, not a strategy result. Under the preregistered rule, no SingleTP-off or BasketTP-off concentration classification is admissible from V1.
