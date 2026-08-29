# EA_LAB Per-EA Workflow Diagram Standard

Status: CANONICAL VISUAL DOCUMENTATION STANDARD
Authority: visual documentation only; diagrams are `VISUAL_ONLY_NO_AUTHORITY` and never override code, config, evidence, governance, risk policy, or owner approval.

## Purpose

Every EA/variant should become understandable visually enough that a new Control Tower can recover the mechanism without reconstructing it from chat history.

The diagram set is part of research continuity, not decoration.
It exists to preserve what the EA actually does and to make mechanism-level reuse visible.

Canonical renderer/design layer:
`docs/skills_mirror/skills/diagram-design/`

Baseline semantic order:
`Market Context -> Entry Trigger -> Filters -> Position Sizing/Risk -> Execution -> Add/Scale-In -> Hedge/Recovery -> Exit -> Safety/Kill -> Tunable Parameters -> Evidence Gates`

Unknown mechanics stay `UNKNOWN / UNRESOLVED`. Never infer missing semantics from parameter names alone.

## Diagram levels

### D0 — Concept sketch

When:
- intake / preregistration;
- source semantics are incomplete;
- early research only.

Required:
- market/context assumption;
- core direction/entry concept;
- exit concept;
- major risk mechanism;
- explicit unknowns.

Format:
one compact flowchart/process diagram.

D0 is optional when a short paragraph is genuinely clearer.

### D1 — Research workflow

When:
- first meaningful fixed-config evidence exists;
- the EA has a pulse or is entering mechanism/rescue work;
- a child variant will be built from a parent.

Required nodes where applicable:
1. Market Context / Home assumption;
2. Direction / signal generation;
3. Entry trigger;
4. Filters;
5. Order execution;
6. Position sizing;
7. Add/scale logic;
8. grid/recovery/hedge logic;
9. exit/basket close;
10. safety/kill/cooldown.

Also show:
- which module is changed in this variant;
- which modules are frozen from parent;
- reusable mechanism candidates.

One logical variant change must be visually distinguishable.

### D2 — Candidate engineering diagram set

Required before Candidate/DEMO admission.

D2-A — Strategy Logic Workflow
Shows the decision path from context to entry to management to exit.

D2-B — State Machine
Required when behavior depends on persistent state, basket phase, recovery phase, cooldown, hedge mode, pending-order lifecycle, or other state transitions.

Example state vocabulary only:
`IDLE -> WAIT_SIGNAL -> ENTERED -> MANAGE -> ADD/RECOVER -> EXIT -> COOLDOWN`.
Use the EA's actual state semantics; do not force generic names.

D2-C — Risk / Position Engine
Required for:
- grid;
- recovery;
- martingale/progression;
- multi-position basket;
- dynamic lot sizing;
- hedge;
- account/equity cages;
- otherwise non-trivial exposure mechanics.

Must show where applicable:
- base lot;
- progression geometry;
- max depth;
- aggregate exposure;
- basket TP/SL;
- margin/equity cage;
- max lot/max level;
- persisted halt / restart behavior;
- hard kill.

D2-D — Module Dependency / Variant Delta
Required when the EA is composed from reusable modules or a child variant changes one module while freezing others.

Purpose:
make causal attribution and future reuse obvious.

## D3 — Runtime / LIVE operational diagram

Required only when an authorized runtime/deployment consumer exists.

Adds operational boundaries such as:
- terminal/account/symbol/TF binding;
- runtime config identity;
- monitoring path;
- external guards;
- persisted state;
- owner/runtime hard-stop boundaries.

D3 is not required for ordinary research-only variants.
It must never be generated as implied deployment authority.

## Per-EA durable artifact identity

Each diagram artifact should state:
- EA Family;
- Variant ID;
- Parent;
- source/ref/build identity;
- config/set identity when relevant;
- diagram level/type;
- generated-from evidence/spec refs;
- known unknowns;
- `VISUAL_ONLY_NO_AUTHORITY`.

A diagram tied only to an EA name without version/ref is insufficient for Candidate/DEMO use.

## Update triggers

Do not redraw every diagram after every numeric backtest.
Update the workflow diagram only when one of these changes materially:
- entry semantics;
- direction semantics;
- filter semantics;
- exit semantics;
- sizing/exposure semantics;
- add/grid/recovery/hedge mechanics;
- safety/kill semantics;
- state transitions;
- module composition;
- runtime binding for D3.

If only evidence metrics change and mechanics are identical:
keep the same diagram identity and update report/evidence references instead.

## Research mechanism preservation

A weak or PARKED standalone EA can contain a valuable mechanism.
The D1/D2 diagrams should make separable components visible:
- Direction;
- Entry;
- Filter;
- Exit;
- Position Engine;
- Recovery/Hedge;
- Risk/Safety.

Examples of legitimate future children:
- strong direction + pullback entry;
- strong direction + breakout trigger;
- strong direction + directional grid;
- strong direction used as a filter on another chassis;
- strong entry mechanism with a different exit;
- robust risk engine reused with another signal.

Diagram documentation must not imply that component reuse is already validated.
It shows a hypothesis boundary and evidence lineage.

## Visual complexity rule

Use the Diagram Design skill conventions.
Target density should remain readable.
If a diagram exceeds the useful complexity budget, split it.

Preferred split:
- Overview workflow;
- State machine;
- Risk/position engine;
- module detail.

Do not create one giant spaghetti diagram merely to claim completeness.

## Relationship to Research Report Ladder

R0:
D0 optional.

R1 Discovery:
D0 or D1 when a concept pulse is being interpreted.

R2 Mechanism/Build-On:
D1 required for a meaningful mechanism claim or child design.

R3 Optimization:
reuse D1 unless mechanics changed; optimization surfaces belong in the report, not the workflow diagram.

R4 Robustness:
D1 current and source-bound; D2 preparation should begin for serious finalists.

R5 Candidate/DEMO:
D2-A mandatory.
D2-B mandatory when stateful.
D2-C mandatory for non-trivial position/risk engines.
D2-D mandatory for modular/child variants when causal lineage matters.

R6 DEMO/LIVE:
D2 remains current; D3 required when runtime topology/binding is decision-relevant.

## Acceptance checklist

Before calling an EA diagram complete for its current level:
- exact EA/Variant/Parent identified;
- source/ref identified;
- signal logic separated from money/risk logic;
- BUY/SELL asymmetry visible when real;
- statefulness visible when real;
- grid/recovery/hedge path visible when active;
- exits visible;
- safety/kill path visible;
- unknowns visibly UNKNOWN;
- changed-vs-frozen module visible for child variants;
- no diagram-created semantics;
- `VISUAL_ONLY_NO_AUTHORITY` present;
- diagram remains readable without the chat that created it.