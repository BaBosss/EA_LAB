# EA_LAB Automation Guide — Smart Pipeline v2
Updated: 2026-09-01

วิธีทำงานแบบประหยัด token/context + optimize ฉลาดขึ้น

> **Current router:** `docs/research/EA_CONVEYOR_BELT_PIPELINE.md` owns the end-to-end stage order. This guide is operator convenience only; it creates no selection, HOLDOUT, Candidate, risk, deployment or LIVE authority.

### 2026-09-01 fast path

`Steps 1-5 fixed/causal evidence -> Step 6 semantic/range contract -> Step 7 Fast Genetic WIDE/COARSE on MAIN when useful -> Step 8 bounded complete neighbours/lock center -> Step 9 BWD+sensitivity -> Step 10 HOLDOUT late`

- Use `scripts/mt5_optimize.ps1` under a preregistered `-HypothesisRevision`; `scripts/lib/optimize_next_step.ps1` stays contract-driven and generic ranking remains quarantined.
- Genetic output maps regions; Top-1 PF is never an automatic winner. Final center needs local-neighbour evidence.
- Do not mine BWD or HOLDOUT for retuning. Stop when no stable region/direct consumer remains, participation collapses, or the child is economically non-improving.
- Reuse `scripts/execution_reliability/` plus the report/scrutiny fast paths under `docs/research/`.


---

## ภาพรวม — Funnel 4 ชั้น

```
[Universe of EAs]
      │  ① symbol_fitness.py  → เลือก symbol ที่เหมาะกับ strategy type
      ▼
[Screen]  ← ea-screener sub-agent : smoke ทุก combo → ตารางสรุป (PASS smoke gate)
      │
      ▼
[Validate] ← ea-validator sub-agent : coarse→fine optimize → plateau-center → IS/OOS/MC
      │                                                         → verdict เดียว
      ▼
[Portfolio] ← main context : correlation, drop/keep, weight, deploy
```

ชั้น Screen + Validate = **fan-out** → ใช้ sub-agent (context สะอาด)
ชั้น Portfolio + ตัดสินใจ = **main** (คุยโต้ตอบกับ user)

---

## ① Symbol Fitness — เลือก symbol ก่อน optimize

แทนที่จะเดา symbol สุ่ม:

```powershell
# KNOWLEDGE mode — เดาจากคุณสมบัติ (ใช้เลือก batch แรกไป smoke)
python scripts\symbol_fitness.py --strategy trend --top 8

# EMPIRICAL mode — จัดอันดับจาก smoke PF จริงที่มีแล้ว (เชื่อตัวนี้มากกว่า)
python scripts\symbol_fitness.py --strategy trend --from-reports _mt5_auto\reports --ea smoke_MACD
```

Strategy types: `trend` / `mean_reversion` / `grid` / `breakout` / `scalp`

**บทเรียน 2026-06-18:** knowledge เดา GBPJPY/XAUUSD ดีสุดสำหรับ trend แต่ empirical
เผย MACD จริงชอบ CADJPY/AUDCHF (med-vol JPY/CHF cross) — **เชื่อ empirical เสมอ
ถ้ามีข้อมูล** knowledge เป็นแค่ prior สำหรับ batch แรก

---

## ② Coarse → Fine Optimize (ทำให้ค่าดีกว่าเดิม)

ปัญหาเดิม: step หยาบ + เลือก median ของ survivors → ได้ค่าขอบ plateau

วิธีใหม่ — 2 รอบ:
1. **Coarse**: range กว้าง step ใหญ่ → หาโซน plateau
   ```powershell
   # ตัวอย่าง: RSI 5..50 step 5 ใน base .set (||5||5||50||Y)
   .\scripts\mt5_optimize.ps1 -Expert "..." -Symbol XX -SetFile coarse.set -ReportName OPT_coarse `
     -HypothesisRevision <rev> ...
   # then read the launcher's own "next:" line for the collected XML -- see section 3
   ```
2. **Fine**: บีบ range ±2 step รอบ plateau centre ที่ contract ระบุ, step เล็ก
   ```powershell
   # RSI 16..22 step 1
   .\scripts\mt5_optimize.ps1 ... -SetFile fine.set -ReportName OPT_fine -HypothesisRevision <rev>
   ```

---

## ③ Selection is contract-driven (QUARANTINE NOTICE)

**The legacy generic ranker is quarantined and must not be run.** The archived BacktestScore v1
selection path refuses by default (exit 3, `REFUSED (LEGACY / NON_FACTORY)`); its
`--allow-legacy-selection` escape hatch produces NON-AUTHORITATIVE output that must never be used
to pick a configuration. Do not pass that flag to get past the refusal.

What replaces it: **nothing generic.** Selection is bound to a pre-registered candidate/hypothesis
contract. Submit the optimize pass with `-HypothesisRevision <rev>`; `mt5_optimize.ps1` then prints
the single authoritative next-step line for the XML it collected. Contract source of truth =
`_triage\factory_os\registry.py` + `_triage\factory_os\candidate.py`.

If no contract is bound, the launcher prints **`SELECTION BLOCKED`**. That is the answer, not an
obstacle to work around: there is no fallback ranking formula, and inventing one here is the exact
failure this quarantine exists to prevent. Register the contract first, or stop.

<sub>Historical note, kept because it is the reason the old formula looked attractive: the archived
ranker reported a `robust pick`, a `center pick` and a `profit-max` pick, and the plateau-centre pick
did transfer to OOS better than the score-max spike on the EAs of that era. The plateau-centre IDEA
survives; the unverified scoring formula that produced it does not, and the plateau definition now
belongs to the contract rather than to a generic script.</sub>

---

## Sub-agents

| Agent | เมื่อไหร่ | รับ | ส่งกลับ |
|---|---|---|---|
| `ea-screener` | มี EA×symbol เป็นชุด | list combos | ตารางสรุป + ตัวผ่าน smoke |
| `ea-validator` | 1 EA ผ่าน screen แล้ว | EA+symbol+type | verdict เดียว + .set path |

เรียกผ่าน Agent tool: `subagent_type: "ea-screener"` หรือ `"ea-validator"`

**ประหยัดอะไร:** main context ไม่เห็น noise ของการ parse หลายสิบไฟล์ /
การ optimize หลาย pass — เห็นแค่ผลสรุป งานตัดสินใจ portfolio ยังอยู่ main

**ไม่คุ้มเมื่อ:** งาน sequential สั้นๆ ตัวเดียว (cold start แพงกว่า) — ทำใน main เลย

---

## Pending findings (จาก symbol_fitness empirical 2026-06-18)

EAs ที่ smoke ดีกว่าตัวที่ lock แล้ว — ควร validate IS/OOS:
- **MACD CADJPY** PF=2.24 DD=11.2% T=1055 (ดีกว่า USDCAD 1.76 ที่เป็น candidate #4)
- **MACD AUDCHF** PF=1.99 DD=8.2% T=538
- **MACD EURCHF/USDCHF** PF=1.66/1.62 (med)
