# EA_LAB EA Report Schema

Status: CANONICAL MANDATORY EA/VARIANT REPORT CONTENT
Authority: reporting schema only; a report does not grant strategy, deployment, runtime, risk, HOLDOUT, or promotion authority.

## Principle

A PF/DD-only report is insufficient. A useful EA report must make the strategy mechanics, configuration identity, exposure, evidence windows, optimization contract and known unknowns inspectable.

Every field must be sourced from exact code/config/evidence or shown as `UNKNOWN / UNAVAILABLE / NOT RUN`. Do not guess missing mechanics or values.

## 1. Identity
- Family;
- Variant;
- Parent;
- Hypothesis;
- exact source/ref/build identity;
- Symbol;
- TF;
- MAIN/BWD/HOLDOUT windows used;
- tester model / data-quality identity;
- configuration/set fingerprint or exact path/hash when available.

## 2. Mechanics
- entry logic in plain language;
- BUY logic;
- SELL logic;
- asymmetry between sides;
- market/pending mechanism;
- indicators and relevant timeframes;
- signal/filter state that is materially active.

Signal logic must be visually/conceptually separated from money/risk logic.## 3. Grid / position structure
- spacing rule and unit;
- max levels;
- reference-to-farthest grid span;
- inter-leg span when materially different;
- max simultaneous positions/orders;
- pending-order behavior and cancellation/reset rules;
- basket/group semantics.

## 4. Lot / exposure
- first/base lot;
- exact lot formula;
- `L1...Ln` calculated lot table, including side asymmetry;
- broker normalization/min/step assumptions or `UNKNOWN` if not durably pinned;
- max aggregate lots;
- max relative exposure versus base lot;
- progression/degression parameters;
- hard per-order/aggregate caps that can bind.

For GRID/MULTI-POSITION strategies the following are mandatory and may not be hidden behind PF/DD:
`Max concurrent positions`, `Max total lots`, `Max grid span in ATR (or native normalized unit)`, and the `L1...Ln` lot ladder.

## 5. Exit / risk
- SL mechanism;
- TP mechanism;
- basket/VWAP exit;
- partial/trailing logic if active;
- hard DD cage;
- margin cage;
- max-lot/max-level cages;
- persisted-halt/safety semantics where relevant;
- observed hard-kill events.

A working kill cage is not proof of strategy safety; a cage firing is itself evidence about the tested configuration.## 6. Optimization
- exact optimized parameters;
- exact ranges and steps/lattice;
- total combinations/cells;
- preregistration ref;
- why each parameter was optimized;
- what remained frozen;
- stage (`COARSE`, `REGION_SELECT`, `REFINE`, `SENSITIVITY`);
- why the selected region/center was chosen;
- plateau/neighbor evidence;
- boundary pressure and any bounded expansion.

The optimizer output is a search map, not an automatic winner declaration.

## 7. Performance
Report at least:
- MAIN;
- BWD;
- yearly split;
- regime split when available;
- trades/baskets/episodes as appropriate;
- PF;
- net;
- DD with the exact field definition;
- hard-kill events;
- exposure metrics.

If a cell is empty or mechanically invalid, label it `EMPTY` or `MECHANICAL_FAIL`; do not convert it into a strategy loss.

## 8. Robustness
- plateau / neighbor stability;
- flat-lot or engine-edge control when relevant;
- sensitivity;
- required Model-1/Model-4 state;
- Monte Carlo state;
- broker/execution portability evidence;
- HOLDOUT state (`UNSPENT`, `RUN`, or exact accepted vocabulary).

`NOT RUN` is a valid and required state when a prior gate stopped the funnel.## 9. Assessment
- working Verdict;
- `QUALITY_GRADE`;
- `EVIDENCE_CONFIDENCE`;
- `BUILD_POTENTIAL`;
- Known Unknowns;
- Lesson;
- Next Hypothesis / next consumer.

Recovered Factory vNext architecture keeps four axes separate:
- `VERDICT = INVALID | FAIL | PARK | PASS`;
- `QUALITY_GRADE = A | B | C | D`;
- `EVIDENCE_CONFIDENCE = A | B | C | D`;
- `BUILD_POTENTIAL = HIGH | MEDIUM | LOW | EXHAUSTED`.

The **axis architecture is recovered**, but numeric/threshold mappings remain provisional unless another canonical policy explicitly ratifies them. Legacy star displays do **not** automatically map to `QUALITY_GRADE`. When an exact mapping is absent, report `QUALITY_GRADE = UNRATIFIED` rather than invent one.

Current verdict vocabulary in existing governance remains authoritative for existing workflows until explicitly migrated; this schema does not close `KINT-001` or rewrite verdict policy.

## 10. Traceability and diagrams

Every measured statement must point to the exact evidence identity. Every interpretation must be distinguishable from measurement.

When a diagram is a direct consumer aid, use the canonical Diagram Design layer. For individual EAs prefer:
`Market Context -> Entry Trigger -> Filters -> Position Sizing/Risk -> Execution -> Add/Scale-In -> Hedge/Recovery -> Exit -> Safety/Kill -> Tunable Parameters -> Evidence Gates`.

Unknown semantics remain visibly unknown. Diagrams are `VISUAL_ONLY_NO_AUTHORITY`.
## Appendix A — Grade semantics owner decision packet

**Recovered exactly from canonical Factory vNext design:**
- four independent axes: `VERDICT`, `QUALITY_GRADE`, `EVIDENCE_CONFIDENCE`, `BUILD_POTENTIAL`;
- axis vocabularies: `INVALID|FAIL|PARK|PASS`, `A|B|C|D`, `A|B|C|D`, `HIGH|MEDIUM|LOW|EXHAUSTED`;
- grade/status architecture is settled, while numeric thresholds/defaults are provisional;
- critical-floor/cap logic is preferred over simple averaging;
- missing evidence lowers confidence rather than automatically becoming negative strategy evidence.

**Still missing/unratified:**
- an authoritative numeric/qualitative mapping from evidence categories to A/B/C/D;
- an authoritative mapping from historical star displays (`★...`) to `QUALITY_GRADE`;
- final `KINT-001` sample-adequacy migration and related production verdict-policy reconciliation.

**Minimal proposal if the owner later chooses to ratify:** retain the recovered four axes and vocabularies, ratify category/critical-floor rules separately, and never map legacy stars automatically. Until that decision, use `QUALITY_GRADE = UNRATIFIED` where no exact accepted mapping exists.

This unresolved packet does not block R&D protocol, Hermes H1, broad smoke, or evidence collection; it blocks only unsupported authoritative grade assignment.