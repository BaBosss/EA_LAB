# EA_LAB — Existing Control Tower Intake
Date: 2026-09-12. Role: continue the ONE existing CT; this is not a new CT boot directive.
Status: PLANNING COMPLETE / SAVED_LOCAL / NOT_CANONICAL / INDEPENDENT_REVIEW_PENDING.
Owner directions: preserve EA backtesting as primary work; develop Control Center in isolated modules; integrate only completed gated modules; final push by CT, not the side worker.
Read `EA_LAB_CONTROL_CENTER_MODULAR_PLAN_V1.md` and `CONTROL_CENTER_MODULE_MANIFEST_V1.json`.
Verified planning base: `5c155cb0700db611afcac7f176753dc75c891e0e`; expected origin `https://github.com/BaBosss/EA_LAB.git`.
Target device: BaBoss / `bbb88aa0-1598-43f6-b56c-a7db22af086a`; do not select a different first-online device.
External intake directory: `D:\EA_LAB_CONTROL\handoffs\control-center-modular-plan-20260912-01\`.
Before intake: fetch current pushed master, verify hostname/origin, read START_HERE/PROJECT_STATE/AGENTS/taskboard at that ref, and query Lane Registry. Preserve dirty D:\EA_LAB; do not reset/clean/stash it.
This worker saved a plan, module contracts and pinned source snapshots; no platform implementation, model training, MT5 run, live collector, deployment, runtime change, commit or push was performed.
Planning-source capture found COMPUTERNAME absent in the tool process; `hostname` and `[Environment]::MachineName` independently confirmed BaBoss/BABOSS. The file-backed capture uses MachineName and explicit device/origin binding. No global environment change.
## Intake sequence
1. Check package checksums; compare current canonical changes only in impacted owners. Do not repeat a whole-project audit.
2. Review the proposed plan independently. Owner intent is captured; detailed risk/control semantics are NOT ratified by this roadmap.
3. In an isolated docs worktree, place the plan at `docs/architecture/EA_LAB_CONTROL_CENTER_MODULAR_PLAN_V1.md`, manifest at `docs/architecture/control_center/CONTROL_CENTER_MODULE_MANIFEST_V1.json`, and this handoff at `docs/handoffs/CONTROL_CENTER_MODULE_PLAN_HANDOFF_20260912.md`.
4. Add a short source link and the owner's backtest-first/modular/CT-push directions to the permitted PROJECT_STATE section. Add only actually READY contracts to AGENT_TASKBOARD and its declared active part. The design manifest is not a new live queue.
5. Preserve AGENTS, CLAUDE, risk defaults and existing core/runtime controls. START_HERE needs no rewrite; use its portfolio/control router, adding a link only if necessary.
6. Run applicable documentation/contract/negative/impacted tests and normal hooks; freeze exact HEAD for independent review. No self-review, bypass, PASS-shopping or cap change.
7. CT integrates/synchronizes and performs an eligible FF push only after gates; verify remote SHA. Repository acceptance does not activate anything.
8. Resume/dispatch the highest-priority genuinely READY mainline EA experiment. The Control Center is not its prerequisite. Where no experiment is ready, name and resolve only its exact minimum dependency; never rerun closed work for activity.
9. First side-track slice is CC00 -> CC01/CC02 -> bounded CC05, with at most one platform author while mainline is ready and no MT5 resource. Existing Report V3 is reused, not rewritten.
10. Later CC06 research-job UI wraps qualified existing runners, first through a fake adapter. Hermes V2-A/no-MT5 and unopened V2-B remain explicit; no new runner dependency is imposed on mainline.
## Hard boundaries and preserved blockers
NewsGuard absent-GV behavior and MacroGate stale fail-open/reduce-lot behavior are current source facts, not defects this task may change. UI freshness/UNKNOWN must not silently change trading policy. NEW ENTRY, ADD, PENDING, CLOSE, HEDGE and FLATTEN need distinct applicability and approval.
Monitor/Report remain read-only; global monitoring remains DEGRADED until its actual evidence gates pass. Do not infer a live market/running-EA state from a plan, inventory or lane record.
B14 closed fixed control; B13/B15 exhausted packaging; B16 closed branches; Schema V2 harness block; B17/ZL different-family review; provider M2 billing/qualification; HOLDOUT/Candidate/KINT; MacroGate activation and QI-2+ keep their owners and restrictions.
No AI confidence-to-lot rule, automatic online retrain/model swap, paid fallback, secret copying, runtime attach/detach, scheduler/tunnel change or public hosting is authorized.
Return: exact docs/module refs, hashes, tests/review, CT canonical SHA, current mainline action, side-track scope, blocked/parked work and next single action. Do not claim whole-platform PASS.
