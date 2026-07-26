# ⛔ DO NOT ATTACH — this folder is not a deploy bundle

**Added 2026-07-26** after an audit found it sitting unlabelled in the attach surface
(`_triage/AUDIT_BUNDLE_EVIDENCE_G2.md`, section 6).

It contains two `.set` (`O142_BTC_MAIN.set`, `O142_ETH_MAIN.set`) and **no README and no `.ex5`** —
nothing told an operator what it was or whether to attach it, while every neighbouring folder in
`_vps_deploy/` is an attach-ready bundle. That is the whole defect: it reads as ready by position.

**The EA's actual standing** (`EA_SCORECARD_AND_REGISTRY.md`, `EA_MASTER_INDEX.csv`):

> `(EXP)_AdaptGridMC (992007)` — **DEAD-STRUCTURAL (static-zone design) — PARKED pending
> walk-forward redesign.** The headline MAIN PF 523 (BTC) / 1182 (ETH, M4) is a **realized-path
> artifact, proven not suspected** — a static one-time P10/P90 zone computed from pre-2023 data.
> The 2026H1 holdout confirmed **zero BTC trades**: the zone is dead.

`DEPLOYMENTS.csv` has **no row for 992007** — it was never attached, which is correct.

**The evidence windows here are clean** — this is not a contamination case. The EA is dead on
structural grounds, which is the one death that does not need an optimize pass to earn.

**Keep the `.set` files** as the record of what was tested. If the walk-forward redesign ever
happens it starts from a new bundle, not this folder.
