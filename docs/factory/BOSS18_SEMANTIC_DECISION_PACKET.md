# Boss18 JumStoch `_18_DirMode` semantic decision packet

Status: `OWNER_DECISION_RECORDED_MODE1 / PARKED_PENDING_PREREG / FAIL-CLOSED`
Authority: decision support only. This packet does not choose Boss18 strategy semantics and grants no H01, tester, optimization, HOLDOUT, Candidate, runtime, DEMO/LIVE, risk/default, Grade/KINT, or deployment authority.
Canonical analysis base: `e838ac0c9aa779bb9b4d6a66a31f2182943e2dd5`.

## Decision in one paragraph

`_18_DirMode` is a consequential seed-signal interpretation switch, not a harmless tuning knob. Mode 1 is the faithful momentum-join mapping of the source JUMSTOCH Trend block and is also the current code/regression default. Mode 2 is the exact BUY/SELL mirror implementing the Lane-A reversion brief. The Boss18 build originally kept both readings unresolved (`build & A/B both`), so neither the default nor historical results could select the identity. On 2026-09-02 the owner selected Mode 1 specifically to preserve source/provenance/semantic lineage, with Mode 2 retained only as an alternate hypothesis. The prior `DEAD-OPTIMIZED / NOT-DEPLOY` chassis-seed verdict remains binding context and is not erased by this semantic decision.

## FACT — exact mechanics

Source owner: `ea_template/core/entries/Entry_JumStoch.mqh`.

The entry evaluates only the last closed bar (`shift 1`), reading Close, LWMA and Stochastic. `_18_Direction` independently fixes each instance to BUY (`1`) or SELL (`2`); `_18_DirMode` changes which market condition is interpreted as that fixed direction.

### Mode 1 — FAITHFUL / momentum-join

- BUY seed: `Close[1] > LWMA` and `Stoch < _18_UpLevel`.
- SELL seed: `Close[1] < LWMA` and `Stoch > _18_LoLevel`.
- Economic interpretation: price is already on the trend side of LWMA while Stochastic has not reached the opposite extreme; join the prevailing direction.
- This matches the validated call-site mapping in the standalone `(EXP)_JUMSTOCH_MT5` Trend block.

### Mode 2 — REVERSION / exact mirror

- BUY seed: `Close[1] < LWMA` and `Stoch > _18_LoLevel`.
- SELL seed: `Close[1] > LWMA` and `Stoch < _18_UpLevel`.
- Economic interpretation: use the same LWMA/Stochastic states with BUY and SELL meaning mirrored versus Mode 1.
- This implements the Lane-A brief as written, not the validated standalone Trend-block direction mapping.

`_18_DirMode` changes only the seed-signal interpretation. Boss18 still uses the Boss V2 chassis for grid/DCA, sizing, protection and exits; choosing a mode does not by itself authorize changing those mechanics.

## FACT — provenance chronology

| Time / commit | Tracked evidence | Meaning |
|---|---|---|
| 2026-07-18 14:38 +07 / `1402de1f` | Boss18 source introduced with `_18_DirMode=1` default and comments `1=FAITHFUL ... 2=REVERSION ... A/B this`; build note records owner direction `build & A/B both`. | Mode 1 default predates Boss18 A/B results, but the same pre-result artifact explicitly says semantic selection was unresolved. |
| 2026-07-18 15:08 +07 / `58ea7904` | Four base-gate sets committed: faithful BUY/SELL and reversion BUY/SELL. | Both modes were prospective alternatives before the Lane-A result; Mode 2 was not invented after seeing performance. |
| 2026-07-18 15:28 +07 / `f30d2f72` | Lane-A verdict recorded both mappings as losing/moot for the chassis-seed experiment. | Historical result exists, but it did not select a canonical DirMode and is not valid evidence for a new retrospective H01 identity. |
| 2026-07-23 / `738c4903` | `Boss_18_JumStoch_defaults.set` first tracked as a regression baseline with `_18_DirMode=1`. | This baseline pin is later than the Lane-A result; it is a regression/current-default artifact, not an exact pre-result semantic identity pin for Factory H01. |
| current | `Inputs.mqh` default = `1`; regression set SHA256 `67973adaf57211858f8bb615c4a73864adc03fd31e6ad0d16f6a044a8882a1c1`, `_18_DirMode=1`; `PARAM_REGISTRY.csv` says the lab has not settled which reading is correct. | Current canonical serialization favors Mode 1 but preserves the unresolved owner-semantic boundary. |

Current project owners therefore remain correct: B18 is `FAIL-CLOSED / NOT REGISTERED`; activation and physical coverage are complete, but no tracked exact pre-result configuration pin authorizes retrospective Hypothesis/ParameterBinding registration.

## FACT — source-lineage evidence

The standalone MT5 port `ea_projects/(EXP)_JUMSTOCH_MT5/(EXP)_JUMSTOCH_MT5.mq5` documents a line-by-line source reading of `JUMSTOCH_FIXEDLOT.mq4`: the Trend call sites open BUY for the above-LWMA / below-upper-Stoch condition and SELL for the below-LWMA / above-lower-Stoch condition. That is precisely Mode 1. This establishes which mode is faithful to the source Trend block. It does **not** establish that the owner intended the new Boss18 chassis-seed family to adopt that interpretation, because the Boss18 creation contract explicitly kept both readings for A/B.

## INFERENCE — what preserves which identity

- **Preserve original JUMSTOCH Trend-block semantics:** Mode 1 is the stronger provenance-preserving choice.
- **Preserve current Boss18 code/regression default:** Mode 1 also changes fewer canonical assumptions because both current input and regression baseline serialize `1`.
- **Preserve the alternate Lane-A reversion brief:** Mode 2 is faithful to that brief, but it is a different causal interpretation from the validated source Trend mapping.
- None of these facts converts a default or old result into owner approval of consequential strategy semantics.

## Hindsight / retrospective-selection check

Selecting Mode 1 or Mode 2 because one historical cell, optimizer output, MAIN/BWD result, or later regression run looked better would be retrospective strategy selection and is forbidden. The recommendation below deliberately ignores PF/net/DD as selection evidence.

The chronology is protective in two ways: (1) both modes existed in tracked prospective sets before the Lane-A verdict, so Mode 2 is a genuine prior hypothesis rather than a post-result invention; and (2) the later regression Mode-1 set cannot be promoted backward into a pre-result H01 pin. Historical performance may explain project history, but it does not decide the semantic contract.

## FACT - standing terminal Boss18 chassis-seed verdict

The semantic choice is **not** a clean-sheet edge search. Canonical history already records this exact Boss18 JumStoch seed on the Boss V2 DCA chassis as `DEAD-OPTIMIZED (port/cell level) / NOT-DEPLOY` in `_triage/_archive/verdicts/ORDER_LANEA_JUMSTOCH_VERDICT.md`, echoed by `EA_SCORECARD_AND_REGISTRY.md` and `TASKBOARD_DIGEST.md`.

That historical ladder tested both DirModes and concluded the chassis-seed architecture had no demonstrated edge in that campaign. The result must not be used to choose Mode 1 versus Mode 2, but it **must** remain visible when deciding whether any new Factory evidence is worth generating. A fresh prospective B18 H01, if authorized, is therefore a standardized current-Factory registration/evidence exercise only; it does not erase, reverse, or bypass the standing `DEAD-OPTIMIZED / NOT-DEPLOY` verdict and cannot by itself create Candidate/DEMO/LIVE authority.

## OWNER DECISION - 2026-09-02

**OWNER SELECTED: OPTION A - Mode 1 / FAITHFUL momentum-join.** The stated basis is preservation of original JUMSTOCH Trend semantics and current Boss18 source identity from source/provenance/semantic lineage, not retrospective performance. Mode 2 is retained only as an alternate reversion hypothesis and is not the current intended Boss18 identity. Historical Lane-A A/B results are explicitly non-validating for the new prospective B18 hypothesis.

The owner also authorized a fresh prospective fixed-config Factory registration/evidence path after reviewed preregistration. That path does not reopen the historical optimization ladder, does not search Mode 2, and does not supersede `DEAD-OPTIMIZED / NOT-DEPLOY`.

### OPTION A - SELECTED / Mode 1 / FAITHFUL momentum-join

Consequence: future B18 prospective registration preserves the validated source Trend-block direction mapping and current canonical default. The new H01 must freeze `_18_DirMode=1` before any fresh result is generated. Old Lane-A performance is context only, not H01 selection or validation evidence.

### OPTION B - NOT SELECTED / alternate REVERSION hypothesis only

Mode 2 remains a separately authorizable future hypothesis. It must not be substituted, searched, or selected inside the Mode-1 H01.

### OPTION C - NOT SELECTED / PARK remains fail-closed fallback

If the reviewed preregistration cannot preserve the frozen Mode-1 mechanics and authority ceiling, B18 remains PARKED rather than broadening scope.

## Decision rationale and bounded consequence

Mode 1 has the strongest non-performance provenance: it reproduces the validated standalone Trend-block call-site mapping, was the initial code default before Boss18 A/B evidence, and remains the current canonical default. The owner decision establishes current Boss18 semantic identity only. It does not change the standing strategy verdict or grant optimization, HOLDOUT, Candidate, DEMO/LIVE, risk/default, Grade/KINT, deployment, or trading authority.

## Next prospective action after reviewed canonical sync

Create a new prospective B18 hypothesis/ParameterBinding contract that freezes `_18_DirMode=1`, exact current source/build/set identity, all other baseline mechanics, evidence windows and authority ceiling before any MT5 run. Any fresh run is registration/current-baseline evidence only and must carry the standing `DEAD-OPTIMIZED / NOT-DEPLOY` context forward. Do not use July Lane-A results, later regression metrics, or any retrospective winner to select or validate the new hypothesis. Do not reopen Mode2 search, optimization, HOLDOUT, or promotion paths.