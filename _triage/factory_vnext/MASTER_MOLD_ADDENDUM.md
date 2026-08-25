# Factory vNext Master Mold / Family / Variant Addendum

Status: IMPLEMENTATION ADDENDUM — NON-AUTHORITATIVE SIDECAR.
Base: `c37118e6a90cc7886640cc3dd98a171d2b20f56f`.

This extends the frozen MVP implementation without changing current Factory policy, deployment authority, risk defaults, or trading semantics.

## Composition hierarchy

`MasterMold -> StrategyFamily -> StrategyVariant -> HomeContract -> Profile/ParameterSet -> Run`

Master Mold is the capability universe. Family selects bounded common structure. Variant is an explicit strategy composition. Components and PositionGroups are evidence identities, not comments or display labels.
Machine IDs and display numbering are separate. Example machine IDs may be `B11` and `B11-V01`; user-facing `11` / `11-01` are projection metadata only and must never be relational join keys.

## Frozen HomeContract compatibility

HomeContract identity remains `ConceptID x LogicalSymbol x ExecutionTF`. Broker, Profile, display numbering, and deployment identity must not enter that key.

When a strategy is managed as a Variant, `VariantID` is the ConceptID supplied to HomeContract. Family/Master ancestry is carried as architecture evidence; there is no alternate HomeContract identity algorithm.

Legacy pilot artifacts keep their existing ConceptID until explicitly migrated. No silent re-keying is allowed.

## Component and PositionGroup rules

Every enabled component has stable `ComponentID`, explicit `ComponentRole`, and explicit `PositionGroupID`. Independent reversal is a separate component/group; it is not inferred to be a hedge.

Recovery scope is explicit and group-local. A recovery component may not silently recover another PositionGroup. A hedge component must name its parent PositionGroup explicitly.
## Parameter authority and projections

Parameter authority is one logical scoped system, not one flat row format. Parameter-global facts, hypothesis/variant bindings, and display metadata remain distinct scopes joined by stable machine identity.

Variant activation controls whether a parameter can appear in an optimization surface. Inactive parameters must not be emitted merely because the Master Mold supports the capability.

Range Generator consumes only explicit Variant/Hypothesis bindings plus parameter-global semantics and allowed domain. Risk-scale, safety, and identity/ops parameters remain snapshot-only in the pilot.

## Pilot boundary

This addendum is schema-ready only for reversal/recovery/hedge composition. It does not implement new trading behavior. The SuperTrendFlip BTCUSD/H4 pilot remains offline-only and NON-AUTHORITATIVE.

Any current-Factory migration, new strategy/risk semantics, runtime attachment, DEMO→LIVE/LIVE, or risk/default change remains outside this addendum.