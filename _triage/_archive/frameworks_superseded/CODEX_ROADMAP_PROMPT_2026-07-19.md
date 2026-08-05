# Codex prompt — forward development roadmap for EA_LAB (2026-07-19)

Dispatch: `/codex:rescue --background` (task mode). Result → `_triage/CODEX_ROADMAP_2026-07-19.md` (read the file, not exit code).

---

<task>
You are a strategy advisor for a solo-operated algorithmic-trading research lab at D:\EA_LAB. This is NOT a bug hunt — a full system audit was already done and its findings are being remediated. Your job is forward-looking: given the current state of the repository, recommend where development effort should go over the next 3–6 months to maximize expected value, and rank it.

Recent context (verify against the repo, do not take on trust):
- The MQL5 EA template (ea_template/core/) just went through a safety overhaul: hard-kill broker-state reconciliation, transactional exits, persist-key scoping, magic-collision guard, spread/lot fixes (commits 629012a0, 8269a310, 0dcf60e2, 1a0dd7ff — ORDER-129/129b/132/132b).
- The research pipeline is considered "mature" by the operator — cheap parameter/sweep improvement levers are largely exhausted.
- Live/demo deployment truth is in portfolio/DEPLOYMENTS.csv; the promotion-integrity backlog is in MASTER_BACKLOG.md (§CODEX-AUDIT P1/P2).
- The operator's stated doctrine right now is FIX-THEN-SCALE: stabilize operations and evidence integrity before adding capability.

Read enough of the repo to form your own independent view: PROJECT_STATE.md, VISION.md, ROADMAP.md, MASTER_BACKLOG.md, EA_SCORECARD_AND_REGISTRY.md, portfolio/DEPLOYMENTS.csv, ea_template/DESIGN_V2.md, and the recent git log.

Answer:
1. Given everything, what are the highest-EV development directions for the next 3–6 months? Rank them.
2. For each: is it "safety/ops debt still open", "new capability", or "strategy R&D"? What is the cheapest evidence that would confirm it's worth doing, and what is the failure mode if it's skipped?
3. What should the operator explicitly NOT build right now, and why (opportunity cost)?
4. Is the FIX-THEN-SCALE doctrine still the right stance given what you see in the repo, or has the balance shifted? Argue your position from evidence.
5. One thing the operator is probably underweighting or blind to.
</task>

<grounding_rules>
Anchor every recommendation to something concrete in the repo (file, backlog item, deployment row, doc claim) — cite the path. If a recommendation rests on an assumption you could not verify in the repo, label it ASSUMPTION. Do not invent backlog items that already exist under a different name — check MASTER_BACKLOG.md and the taskboard first. Distinguish "the docs say X is planned" from "X is actually done in the code".
</grounding_rules>

<research_mode>
Form your own ranking before reading the operator's stated priorities, then reconcile: where you agree with FIX-THEN-SCALE, say so; where you'd deviate, argue why. Do not simply restate the operator's plan back — the value here is an independent second opinion, not confirmation.
</research_mode>

<structured_output_contract>
Write the full analysis to _triage/CODEX_ROADMAP_2026-07-19.md:
1. STATE READ — 8–10 lines: your own summary of where this lab actually is right now (proves independent understanding).
2. RANKED DIRECTIONS — most-EV first. Each: title | category (ops-debt / new-capability / strategy-R&D) | why now | cheapest confirming evidence | failure mode if skipped | rough effort (S/M/L).
3. DO-NOT-BUILD — list with one-line opportunity-cost rationale each.
4. DOCTRINE CHECK — is FIX-THEN-SCALE still right? Evidence-based position.
5. BLIND SPOT — the one underweighted risk or opportunity, and how to test whether it's real.
Keep the chat reply to a 5-line summary pointing at the file.
</structured_output_contract>

<default_follow_through_policy>
Read-only: modify nothing except the report file. Do not run compilers, backtests, or trading platforms. Proceed without asking questions; record unresolved ambiguities in the report.
</default_follow_through_policy>
