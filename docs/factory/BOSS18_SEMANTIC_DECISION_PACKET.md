# Boss18 JumStoch semantic decision packet

Status: PARKED / OWNER-SEMANTIC / FAIL-CLOSED
Authority: decision support only; this document does not choose `_18_DirMode` and grants no H01, optimizer, tester-result, candidate, runtime, DEMO/LIVE, risk/default, or deployment authority.

## Canonical semantic boundary

`ea_template/core/entries/Entry_JumStoch.mqh` states that `_18_DirMode` is intentionally A/B-switched and that the lab has not settled which reading is correct.

- `_18_DirMode=1` — **FAITHFUL / momentum-join**. BUY when `Close[1] > LWMA` and Stochastic is below `_18_UpLevel`; SELL when `Close[1] < LWMA` and Stochastic is above `_18_LoLevel`. The source comments describe this as the standalone's actual call-site mapping and cite a historical EURUSD-H1 PF1.18 baseline. That historical number is context only and is not prospective H01 evidence.
- `_18_DirMode=2` — **REVERSION**. Exact BUY/SELL mirror: BUY below LWMA with Stochastic above `_18_LoLevel`; SELL above LWMA with Stochastic below `_18_UpLevel`.
- Source commentary says the natural home differs by mode: momentum -> trender, reversion -> ranger. It also records that both were intended for A/B evaluation rather than silently selecting one.

`docs/PARAM_REGISTRY.csv` independently records `_18_DirMode` as an active build-18 input, default `1`, and describes the same unresolved 1=momentum-join / 2=reversion semantic split. The tracked default is therefore a serialization/default fact, not owner authorization to select the semantic hypothesis.

## Mechanical facts that do not require an owner choice

- Boss18 source: `ea_template/Boss_18_JumStoch.mq5`.
- Entry implementation: `ea_template/core/entries/Entry_JumStoch.mqh`.
- Physical regression baseline: `ea_template/sets/regression/Boss_18_JumStoch_defaults.set`.
- Baseline SHA256: `67973adaf57211858f8bb615c4a73864adc03fd31e6ad0d16f6a044a8882a1c1`.
- Physical baseline keys: 159.
- `_18_Direction` remains fixed-direction-per-instance; this is separate from `_18_DirMode` signal interpretation.
- No Boss18 Hypothesis or ParameterBinding row is created by Lane H2.
- HOLDOUT remains unspent.

## Exact owner decision needed

Choose one semantic contract for a future prospective Boss18 H01:

1. **FAITHFUL momentum-join** — authorize `_18_DirMode=1` as the causal interpretation to preregister; or
2. **REVERSION** — authorize `_18_DirMode=2` as the causal interpretation to preregister.

A third valid owner action is to keep Boss18 PARKED. Until one of the two semantics is explicitly authorized, Factory registration and fixed-config evidence generation remain blocked fail-closed.
