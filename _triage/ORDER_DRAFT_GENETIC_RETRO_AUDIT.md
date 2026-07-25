# ORDER DRAFT — genetic retro-audit (user pastes into AGENT_TASKBOARD with next free number)

**Lane:** qwen/ZCode (mechanical grep+map — no judgment calls)
**Context:** Genetic policy ratified 2026-07-25 (skill `backtest-optimize-rigor` Step 2). Before that,
66 `.ini` files ran `Optimization=2` (fast genetic) with `OptimizationCriterion=0` (balance max)
and a silent `Leverage=N` no-op (runs executed at server default 1:2000). Question: did any of
those results reach a verdict WITHOUT the fine-grid + sensitivity-fan funnel behind it?

**Task (mechanical, numeric acceptance):**
1. List all 66 genetic `.ini` in `_mt5_auto/ini/` (`Optimization=2`) + their report names.
2. For each, check whether follow-up evidence exists: a fine/complete `.ini` or labeled grid sweep
   covering the same Expert+Symbol within 14 days after, AND any sensitivity-fan runs.
3. Grep `EA_SCORECARD_AND_REGISTRY.md`, `PROJECT_STATE.md`, `docs/memory_control/B1_DATASET.csv`
   for verdicts citing those report names / Expert+Symbol pairs.
4. Output ONE table: `ini | Expert | Symbol | fine-stage-found (Y/N) | fan-found (Y/N) |
   verdict-citing-it (verbatim + file:line) | flag`.
   `flag = DEBT` when a verdict cites a genetic run with fine-stage-found = N.

**Acceptance:** all 66 rows present · every DEBT row has a file:line citation · no verdict text
edited (report only — the lead judges what to re-verify).

**ห้าม:** อย่ารัน backtest/optimize ใหม่ · อย่าแก้ scorecard/verdict ใด ๆ · อย่าแตะไฟล์นอกรายงานผลของตัวเอง ·
commit path-limited เฉพาะไฟล์รายงาน (เครื่องนี้มีหลาย session แชร์ working tree)

**Known-good example (already checked by hand, use as calibration):** `OPT_MDX_GBP_coarse/_fine/_fine2`
= proper coarse→fine funnel, NOT debt.
