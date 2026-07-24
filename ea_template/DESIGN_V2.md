# EA_LabTemplate V2 — Design Blueprint
> เขียน 2026-06-18 · สถานะ: DESIGN (ยังไม่ลงมือ) · คุยแผนก่อน build

> **⚠️ UPDATE (post-hoc, this doc's V1 status is now stale): V1 (`EA_LabTemplate.mq5` +
> `modules/`) is now DEPRECATED, not merely "kept archived" as §"ผลที่ตามมาจากการเคาะ" below
> still says.** Finding: 0 rows in the deployments inventory, 0 backtest reports, 0 `.set`
> files reference it, `modules/` unmodified since 2026-06-18 (this doc's own write date).
> V1 still carries the silent lot-mode fallback (`MM_FirstLot`) and the round-up-to-minlot
> normalizer (`Exec_NormalizeLot`) that V2 fixed (MM-SAFETY-001, 2026-07-24). Do not build new
> work on V1; do not deploy it. See `docs/EA_CORE_AND_TEMPLATE_GUIDE.md` §3.1 for the current
> V1 vs V2 statement. This is a documentation-only correction — nothing below was re-derived
> or changed beyond this note and the two below it.

V2 = รื้อ usability ของ chassis เดิม 3 เรื่องหลัก:
1. **เลขกำกับทุก dropdown** (enum value = โค้ด) → ไล่ optimize/report ง่าย
2. **1 EA = 1 entry** (compile-time variant) + entry เป็นชื่อ EA
3. **แยก StackMode** ออกจาก OnTick (เลิกบังคับ grid กับทุก entry)

โครงเดิม (V1) อยู่ที่ `EA_LabTemplate.mq5` + `modules/` — V2 ไม่ทับ ของเดิม build ได้ตลอด
(**V1 ตอนนี้ DEPRECATED แล้ว — ดู banner ด้านบน**)

---

## 1) ระบบเลขกำกับ (Numbering Scheme)

**หลักการ:** หลักสิบ = หมวด · หลักหน่วย = ตัวเลือก · **enum value = โค้ดจริง**
(MT5 โชว์เลขดิบใน optimization XML/report → เลข=โค้ด อ่านออกทันที ไม่ต้องเปิดตารางแปล)

| หมวด | Dropdown | โค้ด → ความหมาย | Default |
|---|---|---|---|
| **1x Entry** | (compile-time, เป็นชื่อ EA) | `11` GridTrendMA · `12` Breakout · `13` MeanReversion · `14` GridLog (Zeus port) | per-build |
| **2x Exit/TP** | InpExitMode | `21` FixTP(pip) · `22` TP_ATR · `23` Trail · `24` RunTrend | 22 |
| **3x SL** | InpSLMode | `30` None · `31` FixPip · `32` Money · `33` ATR · `34` Donchian · `35` SR | 33 |
| **4x FirstLot** | InpFirstLotMode | `41` Fixed · `42` Risk%(ต้องมี SL) · `43` Balance-scaled (2026-07-23, ไม่ต้องมี SL — `lot = _43_LotPerAnchor × balance/_43_BalanceAnchor`) | 41 |
| **5x Progression** | InpLotProgression | `50` None · `51` Linear · `52` Multiplier · `53` Plus · `54` Log · `55` LogPower (Zeus `factor^ln(N)`) | 50 |
| **6x Direction** | InpTradeDir | `60` Both · `61` LongOnly · `62` ShortOnly | 60 |
| **7x Filter** | InpTrendFilter | `70` None · `71` ATR_Expand · `72` MA_Slope | 70 |
| **8x Recovery** | InpRecoveryMode | `80` None · `81` Light · `82` Adaptive · `83` Aggressive | 80 |
| **9x Stack** | InpStackMode | `90` Single · `91` GridTrend · `92` GridAgainst(DCA) | per-build |

ตัวอย่าง enum:
```mql5
enum ENUM_EXIT_MODE
{
   EXIT_FIXED_TP  = 21,  // 21 Fixed TP (pip)
   EXIT_ATR_TP    = 22,  // 22 ATR TP (ATR x mult)
   EXIT_TRAIL     = 23,  // 23 Trailing stop
   EXIT_RUN_TREND = 24   // 24 Run trend (close on MA reverse)
};
```

### Input naming = ผูกกับโค้ด
param แต่ละตัวขึ้นต้นด้วยโค้ดหมวดที่มันสังกัด → optimize เลือก mode ไหน ไล่ param หมวดนั้นได้เลย

| Prefix | ใช้กับ | ตัวอย่าง |
|---|---|---|
| `Inp11_` | Entry Grid params | `Inp11_FastMA`, `Inp11_SlowMA`, `Inp11_GridStepATR` |
| `Inp12_` | Entry Breakout params | `Inp12_Bars`, `Inp12_ConfirmBars`, `Inp12_HourFrom/To` |
| `Inp13_` | Entry MR params | `Inp13_BB_Period`, `Inp13_RSI_OB`, `Inp13_RequireBB` |
| `Inp21_` `Inp22_` `Inp23_` | Exit params | `Inp21_TP_Pip`, `Inp22_TP_ATRmult`, `Inp23_TrailStart` |
| `Inp31_` `Inp33_` `Inp34_` | SL params | `Inp31_SL_Pip`, `Inp33_SL_ATRmult`, `Inp34_DonchianBars` |
| `Inp41_` `Inp42_` | FirstLot params | `Inp41_FixedLot`, `Inp42_RiskPct` |
| `Inp51_`.. | Progression params | `Inp51_ProgFactor`, `Inp52_ProgMult`, `Inp53_PlusLot` |
| `Inp9x_` | Stack params | `Inp9_GridStepATR`, `Inp9_MaxLevels` |
| `Inp0_` | Shared | `Inp0_ATR_Period`, `Inp0_Magic`, `Inp0_Slippage` |
| `InpRC_` | Risk cage | `InpRC_MaxLot`, `InpRC_KillDDPct` |

> NOTE: เปลี่ยนชื่อ input = .set เดิมใช้ไม่ได้ (key ไม่ตรง) → V2 มี .set ชุดใหม่ ของเดิมแยกเก็บ

---

## 2) 1 EA = 1 Entry (Compile-time variant)

โค้ด shared ชุดเดียว → build ออกเป็น 3 .ex5 แต่ละตัวมี entry เดียว ไม่มี dropdown EntryStyle

### โครงไฟล์ใหม่
```
ea_template/
  core/
    LabCore.mqh         ← OnInit/OnTick/OnDeinit + dispatch (ย้ายจาก .mq5 body เดิม)
    Inputs.mqh          ← enums + inputs (มี #if LAB_ENTRY ครอบ group entry)
    Indicators.mqh  Execution.mqh  RiskControl.mqh
    MoneyManagement.mqh  ExitManager.mqh
    Stack.mqh           ← ใหม่: ตรรกะ stacking ที่แกะจาก OnTick
    entries/  (IEntry + 3 entry modules เดิม)
  Lab_11_GridTrendMA.mq5      → #define LAB_ENTRY 11  +  #include "core/LabCore.mqh"
  Lab_12_Breakout.mq5         → #define LAB_ENTRY 12  +  #include "core/LabCore.mqh"
  Lab_13_MeanReversion.mq5    → #define LAB_ENTRY 13  +  #include "core/LabCore.mqh"
```

### ไฟล์ wrapper (ตัวอย่าง)
```mql5
// Lab_12_Breakout.mq5
#property description "Lab V2 — 12 Breakout (Donchian)"
#define LAB_ENTRY 12
#include "core/LabCore.mqh"
```

### Inputs.mqh เปิด group ตาม build
```mql5
#if LAB_ENTRY==11
input group "=== 11 Entry: Grid Trend MA ==="
input int Inp11_FastMA = 20;
input int Inp11_SlowMA = 50;
// ...
#endif

#if LAB_ENTRY==12
input group "=== 12 Entry: Breakout ==="
input int Inp12_Bars = 20;
// ...
#endif
```
→ Navigator/Inputs โชว์เฉพาะ param ของ entry นั้น · optimize ไม่ลองค่ามั่ว · report แยกต่อกลยุทธ์

### ชื่อ EA = entry strategy
| Build | ชื่อไฟล์ .ex5 | ชื่อใน report/Navigator |
|---|---|---|
| Grid | `Lab_11_GridTrendMA` | Lab_11_GridTrendMA |
| Breakout | `Lab_12_Breakout` | Lab_12_Breakout |
| MeanRev | `Lab_13_MeanReversion` | Lab_13_MeanReversion |

deploy ในโฟลเดอร์ `Experts\LabV2\` → expert name = `LabV2\Lab_12_Breakout`

---

## 3) StackMode — แยก stacking ออกจาก OnTick

**ปัญหา V1:** OnTick บังคับ grid stacking (นับ CountDir, เพิ่มไม้เมื่อราคาวิ่ง GridStep) กับ *ทุก* entry
แต่ Breakout/MR ควรเปิดไม้เดียว → ตอนนี้ผูกตายตัว ไม่ใช่ตัวเลือก

**แก้:** ย้าย logic ไป `Stack.mqh` เป็น dropdown แกนใหม่

```mql5
// Stack_Decide: คืน true ถ้าควรเปิดไม้ใหม่ที่ level นี้
bool Stack_Decide(const int dir, const int have, double &outLevel)
{
   if(have >= Inp9_MaxLevels) return false;
   switch(InpStackMode)
   {
      case STACK_SINGLE:       return (have == 0);              // 90 ไม้เดียว
      case STACK_GRID_TREND:   return Stack_TrendExtend(dir, have); // 91 stack ตามเทรนด์ (logic เดิม)
      case STACK_GRID_AGAINST: return Stack_AverageDown(dir, have); // 92 DCA สวนราคา
   }
   return false;
}
```

Default per-build (ตั้งใน Inputs.mqh ด้วย #if):
| Entry | Default StackMode | เหตุผล |
|---|---|---|
| 11 Grid | `91` GridTrend | กลยุทธ์ grid โดยเนื้อแท้ |
| 12 Breakout | `90` Single | breakout = เข้าครั้งเดียว |
| 13 MR | `90` Single | (หรือ 92 ถ้าจะ DCA bounce — optimize ดู) |

> ยังเป็น dropdown ปรับได้ → อยากลอง Breakout+grid ก็เปลี่ยนเป็น 91 ได้ แต่ default สมเหตุผล

---

## 3b) Stack Confirmation (ระยะ + PA/signal trigger)

นอกจาก StackMode (90/91/92) ที่เลือก *รูปแบบ* การเติมไม้ — เพิ่ม `_9_StackConfirm`
เลือก *เงื่อนไขยืนยัน* ก่อนเติมแต่ละไม้ (V1 บังคับเป็นแบบ `1` ตายตัว → V2 เลือกได้)

| `_9_StackConfirm` | เงื่อนไขเติมไม้ | ความเสี่ยง |
|---|---|---|
| `0` Distance | ถึงระยะ GridStep ก็เติม (blind) | สูงสุด |
| `1` Dist+SignalValid | ระยะ + signal ยัง valid (**= V1 เดิม**) | กลาง |
| `2` Dist+Retrigger | ระยะ + signal เกิดใหม่ (MA re-cross / fresh) | ต่ำ |
| `3` Dist+PriceAction | ระยะ + **แท่งปิด** ทะลุ level (ไม่ใช่ wick แตะ) | ต่ำสุด |

MVP PA confirm = "bar CLOSE beyond step level" (กัน wick หลอก) → เพิ่ม engulfing/pin bar เฟสหลัง
ผล: grid เปลี่ยนจาก "ถัวบอด" → "พีระมิดมีเงื่อนไข" เติมเฉพาะตอน PA ยืนยันไปต่อ
default ต่อ stack: 91→`1` · 92(DCA)→`3` (DCA สวนต้องยืนยันแน่นกว่า) · 90 single ไม่ใช้

param: `_9_StackConfirm` (enum) — logic อยู่ใน `Stack.mqh` คู่กับ `Stack_Decide()`

---

## 3c) STACK_PYRAMID (93) — pending ladder (ScaleExecutor_v2 port, MERGE-03 2026-07-06)

กลไก: leg0 = market entry ปกติผ่าน LabCore · legs 1..N = **pending order พักที่ broker**
(`_9_PendingMode`: 3=STOP pyramid ตามเทรนด์ · 2=LIMIT scale-in สวนเทรนด์) ระยะห่าง =
`Stack_StepPrice()` เดิม (ATR-based + MinPips floor — ไม่มีสูตรใหม่) · lot ต่อ leg = `MM_NextLot`
จาก lot จริงของ leg0 · จำนวน pendings = min(`_9_PendingLegs`, `RiskControl_MaxLevels()`-1) ·
วาง**ครั้งเดียวต่อ basket** (flag reset เมื่อ flat) · restart กลาง basket → ไม่วางซ้ำ (เช็ค
filled/pending จาก broker ก่อนเสมอ)

**Intentional differences จาก CORE\ScaleExecutor_v2 (อย่า "แก้กลับ"):**
- **ไม่มี per-leg TP / OCO** — basket TP/SL ใน ExitManager เป็น exit owner เดียว (pendings มีแค่
  per-leg SL) · เหตุผล: split exit ownership = risk #1 จาก MERGE-02 synthesis, precedent =
  `_2_SuppressLegTP` เกิดจาก conflict class เดียวกันตอน port GridLog
- โหมด 93 ปิด Recovery / Hedge / partial-close / market-add (Stack_DecideAdd คืน false) —
  one mode, one owner
- `Exec_CloseAll()` cancel pendings ค้างเสมอ (ทุก exit path: basket TP, money SL, hard kill) —
  no-op สำหรับโหมดเดิมเพราะไม่เคยมี pendings
- ไม่ใช้ OnTradeTransaction — reconcile จาก `OrdersTotal()/PositionsTotal()` scan สดต่อ tick

ไฟล์ที่แตะ: `Inputs.mqh` (enum 93 + `_9_PendingMode`/`_9_PendingLegs` default 0) ·
`Execution.mqh` (pending infra: place/count/cancel) · `Stack.mqh` (`Stack_ManagePyramid`) ·
`LabCore.mqh` (wire + WARN เมื่อ 93 แต่ PendingMode ว่าง) · `ExitManager.mqh` (guard partial-close)

### Legal exit-owner combos (ORDER-124 chore 3 — OnInit assert อ้างตารางนี้)

| StackMode | Recovery (8x) | Hedge | partial-close (_2_PartialPct*) | exit owner | หมายเหตุ |
|---|---|---|---|---|---|
| 90 single / 91 / 92 | ✅ ได้ | ✅ ได้ | ✅ ได้ | ExitManager (basket TP/SL/trail) | Recovery/Hedge = add/lock path ไม่ใช่ close owner ที่สอง — close ทุกทางรวมที่ ExitManager + cage |
| **93 PYRAMID** | ❌ IGNORED | ❌ IGNORED | ❌ IGNORED | ExitManager basket TP/SL เท่านั้น (pendings มีแค่ per-leg SL) | runtime skip ใน LabCore.OnTick + `Exit_ManagePartialClose`; .set ที่เปิดไว้ = declared-but-ignored → OnInit **hard-WARN** (ไม่ fail — ไม่มี close path ชนจริง) · ⚠️ ช่องจริงที่ยังชน (Codex 445a1b7 SEV-2): ExitMode 21/22 + `_2_SuppressLegTP=false` → **leg0 มี broker TP จริง** = close path ที่สอง → WARN แนะ `_2_SuppressLegTP=true` (ไม่ fail เพราะ probe set 93 ที่ pin cage ไว้รัน combo นี้เอง) |
| entry 16 (Kangaroo) | n/a (short-circuit) | n/a | n/a | Kangaroo.mqh ทั้ง pipeline | `Kangaroo_OnTick()` return ก่อน ExitManager ทั้งหมด = dormant โดยโครงสร้าง — assert **ห้าม trip** เคสนี้ (Codex catch) · `_2_MaxHoldBars>0` มี WARN เฉพาะของมันอยู่แล้ว (ORDER-125) |

กติกา: combo ใหม่ใดๆ ที่เพิ่ม close path ที่สอง (รันพร้อม ExitManager ได้จริง) = ต้องเพิ่มแถวที่นี่ +
assert ใน OnInit ก่อน merge — "one mode, one exit owner" (MERGE-02 synthesis).

---

## 4) Module Map (อ้างอิงเร็ว)

| Module | หน้าที่ | ปรับผ่าน |
|---|---|---|
| Inputs | enums + param ทั้งหมด (มี #if ครอบ entry) | แก้ที่นี่เวลาเพิ่ม mode |
| Indicators | handle MA/ATR/RSI/BB | auto |
| entries/ | คืนสัญญาณ buy/sell/none | 1x (compile) + Inp1x_ |
| Stack | ควรเปิดไม้ใหม่ไหม/level ไหน | 9x + Inp9_ |
| MoneyManagement | FirstLot × Progression = กี่ lot | 4x + 5x |
| ExitManager | TP/SL/trail/basket | 2x + 3x |
| RiskControl | กรง: clamp lot, margin, hard-kill DD | InpRC_ |
| Recovery | เติมไม้แก้เมื่อตะกร้าแดง (81/82/83) — cap โดย cage | 8x + _8_ |
| Hedge | ล็อกสวนเมื่อ DD ลอยทะลุ trigger (HEDGE_LOCK) | HedgeMode + _H_ |
| Basket | stub ปิด (group exit จริงอยู่ใน ExitManager) | (future) |

ลำดับต่อ tick (LabCore.OnTick):
```
1. RiskControl.CheckDD  → เกินเพดาน close+halt
2. ExitManager.ManageBasket → จัดการไม้เดิม
3. Entry_Dispatch → สัญญาณ (ไม่มี = จบ)
4. RiskControl.AllowNewOrder
5. Stack_Decide → ควรเปิด/level
6. MoneyManagement.NextLot → lot
7. Execution.Open
```

---

## แผนลงมือ (เสนอลำดับ)

1. **สร้าง core/ ใหม่** — copy modules เดิมเข้า core/, ทำ Inputs.mqh เลขกำกับ + #if guards
2. **แกะ Stack.mqh** จาก OnTick V1 → 3 stack modes
3. **ทำ LabCore.mqh** (body OnTick/OnInit ใหม่ใช้ Stack)
4. **3 wrapper .mq5** + deploy.ps1 build ทั้ง 3
5. **compile 0/0** ทีละตัว
6. **smoke 1 ตัว** (เช่น Lab_12 Breakout XAUUSD) ยืนยัน pipeline ยังวิ่ง
7. อัปเดต .set ชุดใหม่ (ชื่อ key เปลี่ยน)

ของเดิม V1 คงไว้จน V2 ผ่าน smoke แล้วค่อย deprecate
(**V2 ผ่านสถานะนั้นแล้ว — V1 DEPRECATED จริงแล้ว ณ วันที่มี banner นี้, ดูหมายเหตุต้นไฟล์**)

---

## 7) ATR / Volatility Engine (sizing + stops)

### แยก ATR 2 บริบท (เพิ่มจาก V1 ที่มี ATR ตัวเดียว)
| ATR | ใช้ | param | TF default |
|---|---|---|---|
| **Signal ATR** | entry / grid step | `_0_ATR_Period` `_0_ATR_TF` | current |
| **Risk ATR** | SL / TP / sizing | `_3_RiskATR_Period` `_3_RiskATR_TF` | current |

เหตุผล: SL/MM บน TF สูงกว่า = stop ขนาด swing จริง ไม่โดน noise เขี่ย
Rule: Risk-ATR TF = สูงกว่า entry 1-2 ขั้น (เช่น entry M15 → risk H1/H4)
default = current ทั้งคู่ → พฤติกรรมเหมือน V1 จนกว่าจะเปลี่ยน

### Volatility engines (เรียงตามคุ้มค่า)
**⭐ 1. ATR Position Sizing (constant risk)** — ตัวเด่นสุดของ MM
```
lot = (Balance × risk%) / (k×ATR_points × moneyPerPointPerLot)
```
แก้สเกลสินค้า + vol regime พร้อมกัน → เสี่ยงคงที่ทุกไม้
มีแล้ว: `42` Risk% + `33` SL_ATR ทำงานคู่กัน (RiskATR ป้อน SL distance)

**2. Adaptive ATR stop (regime-scaled)** — เพิ่มเป็นออปชั่น `33` sub-mode
```
SL = k × ATR × clamp( ATR / SMA(ATR,N) , 0.7, 1.5 )
```
param: `_33_AdaptiveON` (bool) `_33_AdaptiveN` (SMA period)

**3. Chandelier / structural trail** — มีใกล้เคียง: `34` Donchian SL + `23` Trail
```
SL_long = HighestHigh(n) − k×ATR   (ไล่ขึ้น ไม่ถอย)
```

### SD vs ATR (สรุป)
ATR↔SD correlate ~80% · **ATR สำหรับ stop** (รวม gap robust) · **SD สำหรับ entry MR**
(`13` MR ใช้ BB = SD-based อยู่แล้ว) → แยกหน้าที่ ไม่ต้องเลือกอันเดียว

เพิ่ม **`36` SD-stop** เป็นออปชั่น (default ยัง `33` ATR):
```
SL = entry ∓ _36_SD_Mult × StdDev(close, _36_SD_Period)   (1SD/2SD)
```

### สรุป param ATR/vol ที่จะเพิ่มใน Inputs
```
_0_ATR_Period  _0_ATR_TF            (signal ATR)
_3_RiskATR_Period  _3_RiskATR_TF    (risk ATR — SL/TP/MM)
_33_SL_ATRmult  _33_AdaptiveON  _33_AdaptiveN
_36_SD_Mult  _36_SD_Period          (SL mode 36)
```

---

## 5) Loss-Management Layer (Recovery / Hedge / Basket / Protection)

4 ตัวนี้แยก **2 ขั้ว** — defensive (กันตาย) vs offensive (เติมไม้แก้)
ประวัติพอร์ตเรา: EA ที่ระเบิดล้วนเป็น offensive (martingale) → ออกแบบให้ offensive ถูก cage คุมเสมอ

### บทบาท + โค้ด
| ตัว | ขั้ว | โค้ด/ตัวคุม | สถานะโค้ด | Default |
|---|---|---|---|---|
| **Protection (cage)** | 🛡️ | `0x` profile + `RC_*` | ✅ ทำงานจริง | เปิดเสมอ |
| **Basket (group exit)** | 🛡️ | `_2_BasketTP` / `_32_BasketSL` (money) | ✅ อยู่ใน ExitManager | ตาม plan |
| **Recovery (เติมไม้)** | ⚔️ | `8x` + `_8_*`, cap โดย `RC_*` | ✅ ทำงานจริง (2026-07-03) | `80` None |
| **Hedge (ล็อกสวน)** | ⚔️ | `HedgeMode` + `_H_*` | ✅ HEDGE_LOCK (2026-07-03) | `0` off |

### 0x Protection profile (cage — เปิดเสมอ)
cage คำนวณตลอด profile แค่ตั้งค่า default ของ `RC_*`
```
00 Off      ← ห้ามใช้ (ไม่มีเบรก)
01 Tight    ← KillDD 15% · MaxDepositLoad 20% · MaxRecSteps 2
02 Normal   ← KillDD 25% · MaxDepositLoad 30% · MaxRecSteps 3   (default)
03 Loose    ← KillDD 40% · MaxDepositLoad 50% · MaxRecSteps 5   (grid เท่านั้น)
```
params: `RC_MaxLot` `RC_MaxDepositLoad` `RC_KillDDPct` `RC_MaxRecSteps` `RC_RecMultMax`

### Basket group exit (🛡️ ป้องกัน — แนะนำเปิดกับ grid/recovery)
อยู่ใน ExitManager แล้ว แค่ตั้งค่า:
```
_2_BasketTP_Money   = ปิดทั้งตะกร้าเมื่อกำไรรวม >= X (0=off)
_32_BasketSL_Money  = ปิดทั้งตะกร้าเมื่อขาดทุนรวม <= -X (0=off)  ← STOP ตะกร้าที่แท้จริง
```
> grid/recovery **ต้อง** มี `_32_BasketSL_Money` เสมอ = เพดานขาดทุนตะกร้า (กันทบไม่จบ)

> ⚠️ **2026-07-23 — เลขเงินแบบ absolute ข้างบนไม่ portable ข้าม cent/USD account** (`25` = $25 บน USD
> แต่ = $0.25 บน cent = ต่างกัน 100 เท่าโดยเงียบ). ใช้ฝาแฝดแบบ % of balance แทน (default 0 = ปิด,
> ของเดิมไม่เปลี่ยน): `_2_BasketTP_BalPct` · `_32_SL_BalPct` · `_57_DynCloseBalPct` · `_8_DDRefBalPct`
> — precedence = BalPct > ATRmult > Money. ratio ไม่มีหน่วย → ความหมายเท่ากันทุก account type +
> scale ตามพอร์ตเอง. รายละเอียด + ตาราง pip ต่อ instrument = `ea_template/INSTRUMENT_SCALE_REFERENCE.md`

### 8x Recovery (⚔️ offensive — build แล้ว 2026-07-03, เปิดได้แต่ cap แข็ง)
```
80 None      ← default ทุก plan ที่ไม่ใช่ grid (early-return — พฤติกรรม = stub เดิมเป๊ะ)
81 Light     ← เติมไม้ lot = first-lot คงที่ เมื่อ adverse >= _8_TriggerATR×ATR, 1 ไม้/bar
82 Adaptive  ← lot = firstLot × (1 + basketLoss$/_8_DDRefMoney), clamp ที่ RC_RecMultMax
83 Aggressive← lot = firstLot × min(_8_RecMult,RC_RecMultMax)^step (step ตาม _8_StepATR band)
               — martingale-like, ห้าม live จนกว่าผ่าน MC ruin<5%
```
เงื่อนไขยิงทุกโหมด: ตะกร้าทิศเดียว + ติดลบเท่านั้น (mixed/กำไร = ไม่ยิง) · ผ่าน `Exec_Open`
(dry-run + broker lot normalize) · แชร์ position-count cap เดียวกับ Stack (`RiskControl_MaxLevels()`)
params: `_8_TriggerATR` (default 1.5) · `_8_StepATR` (1.0) · `_8_RecMult` (1.3, เฉพาะ 83) ·
`_8_DDRefMoney` (100, เฉพาะ 82)
**กฎเหล็ก:** recovery ทุกระดับถูก clamp โดย cage → `RC_MaxRecSteps` + `RC_RecMultMax` + `RC_KillDDPct`
ต่อให้ตั้ง 83 ก็ระเบิดไม่ได้เกิน KillDD

### Hedge (⚔️ build แล้ว 2026-07-03 — HEDGE_LOCK)
```
0 HEDGE_OFF  ← default (early-return — พฤติกรรม = stub เดิมเป๊ะ)
1 HEDGE_LOCK ← DD% ลอยของตะกร้า >= _H_TriggerDDPct → เปิดไม้สวน 1 ไม้
               ขนาด _H_Ratio × |net lots| (ไม่นับ hedge เก่า) → ปิดคืนเมื่อ DD <= _H_ReleaseDDPct
```
params: `_H_TriggerDDPct` (8.0) · `_H_ReleaseDDPct` (3.0) · `_H_Ratio` (1.0) · `_H_MaxLot` (0=ใช้ RC_MaxLot)
hedge leg ติด magic เดิม + comment tag `" H"` → ไม่ถูกนับเป็น exposure ทิศทาง / ไม่ trigger Recovery
**ข้อจำกัดที่ต้องรู้ก่อนใช้จริง:** (1) ใช้ได้เฉพาะ **hedging account** — บน netting account order สวน
จะกลายเป็นลด position แทน (2) การระบุ hedge leg พึ่ง position comment ซึ่งบาง broker ตัด/เขียนทับ
บน live ได้ — ใน tester ปลอดภัย, ก่อน live จริงต้อง verify comment survival บน demo ก่อน
(3) ยังไม่เคยผ่าน backtest/MC ใดๆ — เปิดใช้ = ต้องเข้า pipeline validate ปกติเหมือน mechanism ใหม่ทุกตัว

---

## 5.5) Entry 14 — GridLog (Zeus mechanism port, 2026-07-03)

port กลไกจาก `(Boss)_ZeusInspired_GridLog_rev01.mq5` (standalone PARKED — กลไกรอด backward-OOS
แต่ EA เดิม size ปลอดภัยแล้ว PF ไม่ถึง gate) เข้าแม่พิมพ์เพื่อใช้ sweep กลไก×symbol.
**Parity verified 2026-07-03:** AUDJPY H1 2025.01–2026.07 M1 vs standalone — PF 2.04 vs 1.91 ·
58 vs 54 trades · net +$2,913 vs +$2,780 · eqDD 9.34% vs 14.73% (ต่ำกว่าฝั่งดี). ใช้ 5 attempts,
set อ้างอิง: `sets\Boss14_GridLog_AUDJPY_20x.set`.

**กลไก:** arm resting-stop level (`max(ATR(1)×_14_DistAtrMult, _14_MinDistPips)`) ที่ bar เปิดเมื่อ flat
→ trigger เช็คทุก tick (fill ตรง level เหมือน pending stop) → grid DCA ผ่าน Stack 92 → LOG-power lot
→ basket $TP + partial close 2 จังหวะ → per-leg ATR SL (capped)

**Input ใหม่ที่เพิ่มเข้า core (ทุกตัว default = OFF/พฤติกรรมเดิม):**
- `_0_BarOpenOnly` — ทั้ง pipeline ประเมินครั้งเดียวต่อ bar (Zeus-style); intrabar เหลือแค่ resting-stop fill
- `_33_SL_MaxPips` — เพดาน SL (Zeus: min(4×ATR, 150 pips))
- `PROG_LOG_POWER` (55) + `_55_LogPowerFactor/_55_UseLnNotLog10` — lot = base×factor^ln(N)
- `_4_DdAdaptiveOn/_4_DdTier*` — DD-adaptive first lot
- `_2_PartialPct1/2 + Frac1/2` — partial close ที่ % ของ basket target · `_2_SuppressLegTP` — leg ไม่มี TP รายไม้
- `_9_StepMinPips` — floor ระยะ grid · `_9_StepATRShift` — ATR shift ของ step (1 = แท่งปิด)
- `RC_MaxLevelsOverride` — แยก grid depth ออกจาก RC_MaxRecSteps ของ cage (KillDD ยังคุมตามเดิม)

**บทเรียน parity ที่จ่ายแล้ว (อย่าเจอซ้ำ):** (1) Zeus ประเมินทุกอย่างครั้งเดียวต่อ bar — chassis รันทุก tick
ทำ partial ยิงซ้ำจน basket แตกเป็นเทรดย่อย (2) resting stop ต้อง latch level ตอน arm ไม่ใช่คำนวณ dist
ใหม่ทุก bar และ trigger ต้องเช็คทุก tick (3) เพดาน SL 150 pips bind จริงช่วง ATR สูง (4) per-leg TP
ต้อง suppress เมื่อใช้ basket TP

## 6) Safety default ต่อ Strategy Plan
ผูกชั้น loss-mgmt เข้ากับ 5 plans ใน OPTIMIZE_GUIDE:

| Plan | Protection | Basket SL | Recovery | หมายเหตุ |
|---|---|---|---|---|
| A Scalp | 01 Tight | off | 80 None | SL ต่อไม้พอ |
| B Swing | 02 Normal | off | 80 None | SL กว้างต่อไม้ |
| C Trend | 02 Normal | off | 80 None | trail/run คุมเอง |
| D Breakout | 01 Tight | off | 80 None | SL ต่อไม้ |
| E Grid ⚠️ | 03 Loose | **บังคับ** `_32_BasketSL` | 80 (หรือ 81 ระวัง) | + MC ruin<5% ก่อน live |

> ปรัชญา: ยิ่งกลยุทธ์เติมไม้เยอะ (grid/recovery) ยิ่งต้องพึ่ง **basket SL + cage** เป็นเพดาน
> ไม่ใช่พึ่ง SL ต่อไม้ (เพราะ grid ไม่มี SL ต่อไม้)

---

## จุดตัดสินใจ — เคาะแล้ว (2026-06-18)
- [x] **ชื่อ EA:** `Boss_11_GridTrend` / `Boss_12_Breakout` / `Boss_13_MeanRev` (prefix Boss_ + เลขหมวด + ชื่อสั้น)
- [x] **Deploy:** ทับโฟลเดอร์ `EALabTpl` เดิม → expert name = `EALabTpl\Boss_11_GridTrend` ฯลฯ
- [x] **MR (13) default stack:** `92` DCA (ถัวสวน bounce)
- [x] **V1:** เก็บถาวร (`EA_LabTemplate.mq5` + `modules/` คงไว้คู่ `core/`) — **DEPRECATED แล้ว, ดูหมายเหตุต้นไฟล์**

### ผลที่ตามมาจากการเคาะ
- ชื่อ build ใน wrapper: `#property description "Boss V2 — 11 Grid Trend MA"` ฯลฯ
- deploy.ps1 robocopy 3 .ex5 เข้า `…\MQL5\Experts\EALabTpl\` (ทับเฉพาะ Boss_* ไม่แตะ EA_LabTemplate.ex5 เดิม)
- Stack default: 11→91, 12→90, 13→**92** (ตั้งใน Inputs.mqh ผ่าน #if LAB_ENTRY)
- V1 ไม่ deprecate ตอนนั้น — `core/` เป็นชุดใหม่แยก ไม่ทับ `modules/` เดิม (**ตอนนี้ deprecate แล้ว, ดูหมายเหตุต้นไฟล์**)
