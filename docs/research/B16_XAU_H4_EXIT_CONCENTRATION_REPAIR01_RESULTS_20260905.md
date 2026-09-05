# B16 XAUUSD/H4 Exit-Concentration Repair01 — Results

Status: `PASS_READ_ONLY / HYPOTHESIS_NOT_FALSIFIED / EXIT_CONCENTRATION_REPLICATED / RESEARCH_ONLY`
Hypothesis: `HYP-B16-XAU-H4-EXITCONC-01`
Repair01 preregistration commit: `f7421ea425d9f15dfa8561045fa88b136313ba58`
MT5 rerun: `NONE`; Optimization: `NONE`; HOLDOUT: `UNSPENT`.

## Evidence boundary

V1 correctly stopped at `BLOCKED_CONTROL_MISMATCH` before child outcomes were calculated because `DEEP_SPACING_EQUAL` did not reproduce the accepted XAUUSD/H4 parent MAIN headline evidence. Repair01 then replaced only that control source with the already-accepted H03 parsed parent object, SHA256 `3639c9abcc8c299cf11ce1eb310ed9e721f43831870e213baafeb2e59f6a0fb6`, bound to parent report SHA256 `aee6819b...` MAIN and `df63addd...` BWD.

The Repair01 raw calculation completed and froze `repair01_diagnostic.json` at SHA256 `5194fa5986767d9c47a4c4220b70699e8a21ac6e31aa14457d74837c46acf7b1`. A later CSV packaging step failed because parent and child row dictionaries had different optional PF fields. That is classified `B HARNESS-TEST`; packaging was salvaged from the frozen diagnostic JSON without re-running raw analysis or changing any research semantics.

## Frozen preregistered result

| Eligible window | Max hold | Active share | Top-1 positive-cycle GP share | Zero-close years | Rule result |
|---|---:|---:|---:|---:|---|
| Parent MAIN control | 16.31 d | 3.88% | 17.22% | 0 | control |
| SingleTP off MAIN | 750.17 d | 58.02% | 74.85% | 1 | `4/4 -> CONCENTRATION_SHIFT` |
| Parent BWD control | 30.30 d | 9.34% | 9.75% | 0 | control |
| SingleTP off BWD | 1019.33 d | 72.57% | 100.00% | 1 | `4/4 -> CONCENTRATION_SHIFT` |
| BasketTP off MAIN | 1029.17 d | 70.69% | 99.71% | 1 | `4/4 -> CONCENTRATION_SHIFT` |
`BASKETTP_OFF / BWD` remains mechanically ineligible hard-cage evidence at 25.00% DD and is excluded from the three-window verdict exactly as preregistered.

All three eligible windows satisfy the preregistered `>=3 of 4` concentration rule, and in fact each is higher on all four dimensions. Overall classification is therefore `HYPOTHESIS_NOT_FALSIFIED / EXIT_CONCENTRATION_REPLICATED`.

Additional aggregate evidence remains descriptive rather than the decision rule: SingleTP-off MAIN has 43 trades / 8 reconstructed cycles and net +1952.33; SingleTP-off BWD has 4 trades / 2 cycles and net -399.24; BasketTP-off MAIN has 5 trades / 4 cycles and net +3394.29 with no gross loss, so its mathematical PF is `UNDEFINED_NO_GROSS_LOSS` despite MT5 displaying 0.00.

## Interpretation

The XAUUSD/H4 result replicates the previously observed USDJPY/H1 mechanism pattern: removing either exit can produce attractive aggregate economics in some windows while transforming participation into a few extremely long-lived and highly concentrated realized paths. The evidence therefore supports the interpretation that current Single TP / Basket TP mechanics materially control holding duration and profit-distribution concentration.

This does not establish that the current exits are optimal, nor that an exit redesign cannot improve the family. It shows that aggregate PF/net alone is not sufficient evidence for removing these exits, because the exit-off paths are materially different in concentration and temporal participation.

## Decision / next consumer

Decision: `RETAIN_CURRENT_EXITS_FROZEN / EXIT_CONCENTRATION_REPLICATED`.

Do not open an exit-parameter search from this result. Any future XAUUSD/H4 exit-redesign hypothesis must be separately preregistered and must include participation/holding/concentration guardrails in addition to aggregate PF/net/DD. No such follow-up is auto-opened by this report.

Repair01 is the single bounded research repair for this diagnostic. No Repair02 is authorized automatically.

## Authority ceiling

`RESEARCH_ONLY`. No optimization, HOLDOUT, Candidate/Model4, Grade/KINT, strategy default, DEMO/LIVE, deployment, trading, or risk/default authority. `ORDER-353` and global monitoring state are unrelated and remain unchanged.
