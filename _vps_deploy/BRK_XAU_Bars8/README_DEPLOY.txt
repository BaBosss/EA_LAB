========================================================================
BRK_XAU Bars8 — XAUUSD H1 — additive variant leg (magic 991002 in the
original 2026-06 demo plan; see the magic note below)
========================================================================
README created 2026-07-26 by audit — this bundle previously had NO README
at all, only the .ex5 and the .set. Read the correction before using it.

!!! THE .set HEADER'S HEADLINE NUMBERS ARE WRONG, NOT MERELY STALE !!!
    Audit AUDIT_BUNDLE_EVIDENCE_G1.md sec.1.
    `BRKXAUH4_Bars8_demo_v1.set` carries a headline of IS 2.61 / OOS 3.92.
    Those two figures belong to two DIFFERENT cells of the sweep, and neither
    of them is the shipped configuration. The shipped config's own numbers are
    IS 1.66 / OOS 3.85.
    This is the only case in the whole ten-bundle group-1 audit where a quoted
    number is wrong rather than out of date — everything else reproduced to the
    decimal. Do not carry 2.61 forward anywhere.

MAGIC — check before attaching anything:
    The 2026-06 demo plan assigned 991002 to this variant. On the REAL cent
    account 159503454, magic 991002 is now (BRK)_TrendlineBreakout (ACTIVE since
    2026-07-09). Magics only need to be unique within an account, so this is not
    automatically a conflict — but pick the magic deliberately, do not inherit it
    from the old plan.

STATUS: not attached. Treat as an evidence-incomplete variant, not a deploy
    candidate. If it is ever revived, restate its numbers from a fresh run with a
    FULL pinned .set — the sweep this bundle came from used hand-rolled grid cells
    whose selection windows still need checking against the 2025.12.31 boundary
    (see ORDER202_HOLDOUT_CONTAMINATION_RETROSCAN.md Part 4).
