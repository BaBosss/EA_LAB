---
card_type: MECHANISM_CARD
mechanism_id: MECH-GRID-001
status: RESEARCH_ONLY
transfer_status: UNTESTED_IN_EA_LAB
authority: RESEARCH_ONLY
---

# Bounded Volatility-Aware Grid

## Thesis

Harvest repeated price oscillation inside a bounded operating zone while preventing position escalation from becoming the core return mechanism.

## Inputs / components

The FINDYOUR8-derived catalog describes statistical/volatility-derived bands, ATR-scaled spacing, flat lots, capped position counts/bands, inverse-ATR sizing, and hard risk limits. It separately documents more dangerous recovery/martingale overlays; those are not treated as equivalent to this bounded flat-lot mechanism.

## Expected operating envelope

Oscillatory/range behavior inside a defensible zone. The mechanism becomes fragile when price escapes the modeled range and does not revert.

## Failure modes

- sustained directional break beyond the grid band;
- repeated re-anchoring that ratchets exposure into a decline;
- under-modeled swap/funding/spread costs;
- statistical band estimates failing under regime/OOD change;
- silently adding geometric lot escalation and changing the mechanism into martingale recovery.

## Evidence links

- Supporting: `SRC-EALAB-FINDYOUR8-CATALOG`
- Contradicting/gaps: no direct EA_LAB MT5 proof in this seed
- EA_LAB evidence: none asserted here

## Transfer note

Any EA_LAB experiment must preserve the non-escalating contract explicitly; a martingale/recovery variant is a different strategy semantics and may require separate owner authority.