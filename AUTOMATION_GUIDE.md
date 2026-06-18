# EA_LAB Automation Guide — Smart Pipeline v2
อัพเดท: 2026-06-18

วิธีทำงานแบบประหยัด token/context + optimize ฉลาดขึ้น

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
   .\scripts\mt5_optimize.ps1 -Expert "..." -Symbol XX -SetFile coarse.set -ReportName OPT_coarse ...
   python scripts\select_robust_pass.py _mt5_auto\optimizations\OPT_coarse.xml
   # อ่าน center_params
   ```
2. **Fine**: บีบ range ±2 step รอบ center_params, step เล็ก
   ```powershell
   # RSI 16..22 step 1
   .\scripts\mt5_optimize.ps1 ... -SetFile fine.set -ReportName OPT_fine
   python scripts\select_robust_pass.py _mt5_auto\optimizations\OPT_fine.xml
   # center_params = ค่าที่ lock
   ```

---

## ③ Plateau-Center Selection (กัน overfit)

`select_robust_pass.py` ตอนนี้ออก **3 ค่า**:
- `robust pick` — score สูงสุด (อาจอยู่ขอบ plateau)
- `center pick` ⭐ — param ที่เพื่อนบ้านรอดเยอะสุด = ใจกลาง plateau → **ใช้ตัวนี้**
- `profit-max` — กำไรสูงสุด (overfit-prone, อย่าใช้)

`center_neighbours` = จำนวนเพื่อนบ้านที่รอด gate (ยิ่งเยอะยิ่ง robust)

**บทเรียน:** NuiIndy robust=RSI18/ADX20 แต่ center=RSI24/ADX12 (16 เพื่อนบ้าน) —
center มักtransferไป OOS ดีกว่าเพราะไม่ใช่ spike

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
