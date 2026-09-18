# ZL-EA-067 Wick Displacement — Identity-Only Reallocation Contract — 2026-09-18

Status: `PROSPECTIVE / IDENTITY_ONLY / B22_RESERVED / IMPLEMENTATION_NOT_STARTED / REVIEW_GATED / NO_MT5`.

Contract base: `bc2e4afe09ca3309b091a032c020140ea1c5a858`.

Can do: `Codex Primary` bounded identity-only author using the preserved ZL lineage; deterministic generation/compile/test tooling; Control Tower acceptance/integration only after all gates pass. Suggested: `Codex Primary` for one mechanical regeneration/revalidation lane. Required final review: a separate read-only acceptance-grade GPT Scrutiny job/lane/contract against the exact clean frozen head and isolated evidence; the author job cannot self-approve.

## Collision and reservation

The frozen ZL-EA-067 WickDisplacement canary at local head `14b3181af77c52cb66b4cd30db132239d826f1ef`, and its earlier accepted technical evidence, use `B20 / LAB_ENTRY_20 / Boss_20_WickDisplacement`. The later canonical DF02 owner contract reserves `B20 / LAB_ENTRY_20 / Boss_20_GoldTimeBomb`. Therefore the old ZL identity collides with DF02 and cannot integrate under B20.

Reachable-ref and canonical searches found no existing reservation for `FamilyID=B22` or `LAB_ENTRY_22`. This contract reserves exactly:

- `FamilyID=B22`;
- `LAB_ENTRY_22`;
- `Boss_22_WickDisplacement`;
- identity-bound inputs `_22_WickBodyRatio` / `P12200` and `_22_DisplacementBodyFraction` / `P12201`.

`B20 / LAB_ENTRY_20` remains assigned to DF02. `B21 / LAB_ENTRY_21` is separately reserved for DF03 by its prospective contract. All old ZL B20 heads remain historical technical evidence and are explicitly non-integratable under B20; their evidence must not be relabelled as if it had been produced under B22.

## Frozen semantics

This is identity reallocation only. Preserve the exact `EA_LAB INDEPENDENT CHILD V0` semantics:

- rejection candle at closed-bar shift 2 and confirmation/displacement candle at shift 1;
- BUY: valid non-doji rejection, dominant lower wick at least ratio times body, bullish confirmation with body/range at least the frozen fraction, and strict close above the rejection high;
- SELL: exact mirrored upper-wick/bearish/close-below logic;
- default values `WickBodyRatio=2.0` and `DisplacementBodyFraction=0.65`;
- invalid threshold/OHLC/doji/weak-wick/weak-displacement/no-breakout behavior returns `NONE`;
- entry-only `STACK_SINGLE / CONF_DISTANCE` scaffold ownership, with no native order, pending, position, recovery, hedge, exit, money-management, or risk-cage ownership;
- `EA_LAB INDEPENDENT DERIVATION / NO ORIGINAL ZIPLOR FIDELITY CLAIM` provenance.

No condition, comparison, bar timing, input type/default, direction, chassis setting, risk/default, or source-fidelity statement may change. No Home/TF/settings are allocated here.

## Bounded implementation scope

The future writer may mechanically regenerate only identity-bound surfaces required to move the preserved ZL implementation from 20 to 22: wrapper ownership, `Boss_22_WickDisplacement`, the two input names/PIDs and their generated InputSurface/LockedConstants fingerprints, the conditional LabCore entry selection, the existing `Entry_WickDisplacement` bindings, parameter registry/linkage outputs, the focused Wick fixture, and the source-bound V0 note. The old B20 artifacts remain historical evidence; do not edit them into B22 evidence.

The prospective exact path allowlist is:

```text
_triage/factory_os/wrapper_owners.csv
docs/PARAM_LINKAGE.md
docs/PARAM_REGISTRY.csv
docs/research/ZL_EA_067_WICK_DISPLACEMENT_V0.md
ea_template/Boss_22_WickDisplacement.mq5
ea_template/core/InputSurface_gen.mqh
ea_template/core/Inputs.mqh
ea_template/core/LabCore.mqh
ea_template/core/LockedConstants_gen.mqh
ea_template/core/entries/Entry_WickDisplacement.mqh
ea_template/tests/WickDisplacement_Test.mq5
```

If current canonical generators prove a different derived owner path mandatory, stop and return the exact path to the Control Tower; do not widen this identity-only contract in place.

Any non-identity source delta, new strategy rule, new shared-module ownership, default change, or broader execution/risk edit is outside this contract and must stop for a new Control Tower contract.

## Exact validation and review boundary

Before mutation, re-run current-canonical collision checks for B20/B21/B22, build tokens, wrapper names, PIDs, input names, and wrapper-owner rows. Then require all of the following on one clean frozen head:

1. an explicit normalized diff proving the only strategy-surface changes from the frozen ZL bytes are the declared `20 -> 22` identity tokens, wrapper name, input names, PIDs, and mechanically derived fingerprints/registrations;
2. exact equality of Wick/displacement decision logic, closed-bar shifts, default values, signal outputs, scaffold Stack/Confirm settings, and all non-identity prose/provenance claims;
3. wrapper-owner, input-surface, locked-constant, parameter-surface/linkage, scaffold/new-entry, registration, and adversarial collision cages PASS;
4. `Boss_22_WickDisplacement` and the focused Wick test compile with `0 errors / 0 warnings` unless current canonical compilation introduces a separately explained environment blocker;
5. the existing nine-case Wick runtime fixture rerun only because identity binding changed, with identical signal outcomes; impacted adjacent regression rerun only where the identity-bound wrapper or generated surfaces require it, on one named installation and without cross-install comparison;
6. applicable `tpl_regression.ps1`, normal hooks, exact changed-path audit, clean-head verification, and `git diff --check` PASS;
7. acceptance-grade exact-head GPT Scrutiny of the core source under `EA_MILESTONE_SCRUTINY_CHECKLIST.md`, after every identity-equality, fixture, compile, regression, and adversarial gate above passes; only `SCRUTINY_PASS` permits Control Tower acceptance/integration.

Gemini qualification V2 timed out with no response or grade and is `NO_CONCLUSION`; it is neither competence failure nor qualification PASS. That remains historical provider evidence. Under current policy Gemini/Qwen are optional/support only, provider qualification cannot block core review, and independence is established procedurally through the separate read-only exact-head scrutiny job and evidence isolation.

No optimization, BWD retune, HOLDOUT, Candidate/Grade/KINT, performance claim, Home/TF/settings freeze, deployment, runtime attachment, DEMO/LIVE, trading, risk/default change, or Strategy Catalog record follows. Only after reviewed B22 source integration may a separate fixed-config Model1 MAIN+BWD screen contract be considered.
