# Archived root docs — 2026-07-18 cleanup

Dead/closed root-level .md files moved out of the repo root to reduce clutter.
None are referenced by any living canonical doc anymore (the one live pointer,
`PROJECT_STATE.md` §2 → `QWEN_RUN_LOG.md`, was updated to the new path). None are
in any hook/`check_state`/archive-checker protected set.

| File | Why archived |
|---|---|
| `QWEN_RUN_LOG.md` | qwen batch run log, work reviewed+closed 2026-07-02 (GR opt null, goldgrid all-fail) |
| `QWEN_RUN_LOG_updated.md` | stale duplicate of the above |
| `QWEN_RUN_PLAN.md` | qwen batch plan, executed and closed 2026-06 |
| `ORDER-036_MT4_MASS_SMOKE.md` | ORDER-036 1,318-EA MT4 sweep, CLOSED 2026-07-07 (see memory `order-036-closed-unnomguai-finding`) |
| `BASKET_PLAN_GSMC_MG.md` | superseded basket plan (2026-06-28), not on any active track |

Recover any of these with `git mv _archive_docs/<file> <file>` if a track reopens.
