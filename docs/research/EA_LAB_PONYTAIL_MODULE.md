# EA_LAB Ponytail Controlled Adoption Module

## Decision

Adopt Ponytail's "write only what the task needs" discipline as a bounded EA_LAB worker-policy sidecar, not as a new authority layer and not as a global Ultra-mode default.

Direct consumer: EA_LAB Control Tower when it creates bounded implementation/review contracts.

Downstream skip: stop repeating ad-hoc YAGNI, reuse, stdlib/native, and over-engineering instructions in every worker prompt; consume one deterministic module decision instead.

## Why it fits EA_LAB

EA_LAB already has higher-level controls Ponytail does not provide: canonical Git authority, Lane Registry ownership, Harness validation, task contracts, one-writer/review freeze, tests/cages, independent high-risk review, and owner hard stops.

The useful missing layer is implementation restraint: before adding a helper, abstraction, dependency, configuration surface, or subsystem, the worker should prove the approved task cannot be satisfied by existing code or a simpler native mechanism.

Therefore Ponytail complements Control Tower/Harness/Lane Registry; it does not replace them.

## Upstream evidence used

Design pin: `DietrichGebert/ponytail@2ed6c52c9d7e5e56942508591085fd45dea277d3`.

The Codex plugin manifest at that commit reports version `4.9.0`. Upstream describes a ladder of understanding the touched flow, avoiding unnecessary work, reusing existing code, preferring stdlib/native/already-installed dependencies, then implementing the minimum that works.

Upstream also excludes validation, error handling, security, and accessibility from code-reduction pressure.

EA_LAB extends that preservation set with observability/diagnostics, deterministic fail-closed behavior, tests/cages, evidence/auditability, and owner hard-stop guards.

The upstream benchmark is motivation only. EA_LAB does not target its LOC, token, cost, or time percentages and does not grade work by line-count reduction.

## EA_LAB adaptation

| Surface | Effective policy |
|---|---|
| clear tooling/docs/tests/scripts | `full` by `auto` |
| explicitly requested `lite` on clear low-risk surface | `lite` |
| EA/MQL, core, execution, position, accounting, money, risk | `review` only |
| runtime/deployment/trading/LIVE | `review` only |
| mixed protected + low-risk paths | `review` only |
| unknown/unsafe/unclassified | fail closed to `review` |
| `ultra` | refused in v1 |
| `off` | no Ponytail overlay |

## Safety boundary

This module never grants task, deployment, trading, LIVE, risk/default, attestation, integration, or push authority. Every policy result carries `authority_granted=false`.

`full` and `lite` are allowed only on a clear low-risk surface. A protected work type, protected path, mixed scope, traversal/unsafe path, or unclassified scope is downgraded to `review`. `ultra` is refused in v1.

The preservation contract is stronger than upstream minimalism for EA_LAB: validation, error handling, security, applicable accessibility, observability/diagnostics, deterministic fail-closed behavior, tests/cages/negative tests, evidence/auditability, and owner hard-stop guards are never code-reduction targets.

The module does not install Ponytail, activate lifecycle hooks, mutate global agent settings, touch MT4/MT5/VPS/runtime state, or alter current EA_LAB governance.

## Acceptance

Focused deterministic acceptance requires:

- a genuine RED before the policy implementation exists;
- low-risk `auto` -> `full`;
- protected work/path -> `review`;
- mixed/unknown/traversal -> fail closed to `review`;
- explicit `review` and `off` remain usable;
- `ultra` refuses in v1;
- malformed/missing-mode contract returns structured refusal;
- output always states `authority_granted=false`;
- preservation set and `minimum_necessary_complexity` target remain explicit;
- upstream repository/commit/version are exact and pinned.

## Integration model

Normal use is:

`approved task contract -> Lane Registry/Harness -> Ponytail policy decision -> worker overlay -> existing tests/evidence -> optional over-engineering review -> existing EA_LAB acceptance/review`

Ponytail is therefore an implementation-restraint sidecar. It does not become a source of truth for Git, lane ownership, review authority, task acceptance, or owner approvals.

The module build began from `165c999d4b91421bbd78d844d5388c3cc6c5bef6`. Before closeout, the isolated lane was fast-forward reconciled to the then-current `origin/master` because canonical moved on non-overlapping neighboring lanes. Focused acceptance must be rerun after that reconciliation.

This lane stops at a local frozen commit. Canonical merge/push is intentionally deferred to a later exact-head review/integration step.