# Experiment Knowledge Boundary

This directory is **pointer-only**. It must not become a second experiment registry.

QI-1 already freezes the experiment contract/result model and derives the Experiment Registry and Negative Experiment Memory from existing durable objects. See `docs/research/QI1_FOUNDATION_DESIGN_FREEZE.md`.

Allowed here:

- links from research hypotheses to existing experiment IDs;
- explanatory notes about how research maps to an experiment type;
- navigation to existing event/evidence records.

Forbidden here:

- independently writable experiment contracts or results;
- a new verdict source;
- duplicated lifecycle state;
- any file that silently grants execution authority.
