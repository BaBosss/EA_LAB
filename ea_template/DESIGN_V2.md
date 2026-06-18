# EA_LabTemplate V2 — Design Blueprint
> เขียน 2026-06-18 · สถานะ: DESIGN (ยังไม่ลงมือ) · คุยแผนก่อน build

V2 = รื้อ usability ของ chassis เดิม 3 เรื่องหลัก:
1. **เลขกำกับทุก dropdown** (enum value = โค้ด) → ไล่ optimize/report ง่าย
2. **1 EA = 1 entry** (compile-time variant) + entry เป็นชื่อ EA
3. **แยก StackMode** ออกจาก OnTick (เลิกบังคับ grid กับทุก entry)

โครงเดิม (V1) อยู่ที่ `EA_LabTemplate.mq5` + `modules/` — V2 ไม่ทับ ของเดิม build ได้ตลอด

---

## 1) ระบบเลขกำกับ (Numbering Scheme)

**หลักการ:** หลักสิบ = หมวด · หลักหน่วย = ตัวเลือก · **enum value = โค้ดจริง**
(MT5 โชว์เลขดิบใน optimization XML/report → เลข=โค้ด อ่านออกทันที ไม่ต้องเปิดตารางแปล)

| หมวด | Dropdown | โค้ด → ความหมาย | Default |
|---|---|---|---|
| **1x Entry** | (compile-time, เป็นชื่อ EA) | `11` GridTrendMA · `12` Breakout · `13` MeanReversion | per-build |
| **2x Exit/TP** | InpExitMode | `21` FixTP(pip) · `22` TP_ATR · `23` Trail · `24` RunTrend | 22 |
| **3x SL** | InpSLMode | `30` None · `31` FixPip · `32` Money · `33` ATR · `34` Donchian · `35` SR | 33 |
| **4x FirstLot** | InpFirstLotMode | `41` Fixed · `42` Risk% | 41 |
| **5x Progression** | InpLotProgression | `50` None · `51` Linear · `52` Multiplier · `53` Plus · `54` Log | 50 |
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
| Recovery/Hedge/Basket | stub ปิด | 8x (future) |

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
| **Recovery (เติมไม้)** | ⚔️ | `8x` + `_8_*`, cap โดย `RC_*` | ⛔ stub | `80` None |
| **Hedge (ล็อกสวน)** | ⚔️ | `InpHedgeMode` (0 off) | ⛔ stub | off (defer) |

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

### 8x Recovery (⚔️ offensive — เปิดได้แต่ cap แข็ง)
```
80 None      ← default ทุก plan ที่ไม่ใช่ grid
81 Light     ← เติม 1-2 ไม้ lot คงที่ เมื่อ adverse >= _8_TriggerATR, cap RC_MaxRecSteps
82 Adaptive  ← (ยังไม่ build — gated)
83 Aggressive← (ยังไม่ build — gated, martingale-like, ห้าม live จนกว่าผ่าน MC ruin<5%)
```
params: `_8_TriggerATR` (เริ่มแก้เมื่อขาดทุน X×ATR) · `_8_StepATR` (ระยะเติม) · lot โตตาม `5x` progression
**กฎเหล็ก:** recovery ทุกระดับถูก clamp โดย cage → `RC_MaxRecSteps` + `RC_RecMultMax` + `RC_KillDDPct`
ต่อให้ตั้ง 83 ก็ระเบิดไม่ได้เกิน KillDD

### Hedge — เลื่อน
ซับซ้อน (margin 2 ทาง, lock/unlock timing) + เสี่ยง ไม่จำเป็นกับ portfolio ปัจจุบัน
คง `HEDGE_OFF` ไว้ → ออกแบบเฟสหลังถ้าจำเป็นจริง

---

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
- [x] **V1:** เก็บถาวร (`EA_LabTemplate.mq5` + `modules/` คงไว้คู่ `core/`)

### ผลที่ตามมาจากการเคาะ
- ชื่อ build ใน wrapper: `#property description "Boss V2 — 11 Grid Trend MA"` ฯลฯ
- deploy.ps1 robocopy 3 .ex5 เข้า `…\MQL5\Experts\EALabTpl\` (ทับเฉพาะ Boss_* ไม่แตะ EA_LabTemplate.ex5 เดิม)
- Stack default: 11→91, 12→90, 13→**92** (ตั้งใน Inputs.mqh ผ่าน #if LAB_ENTRY)
- V1 ไม่ deprecate — `core/` เป็นชุดใหม่แยก ไม่ทับ `modules/` เดิม
