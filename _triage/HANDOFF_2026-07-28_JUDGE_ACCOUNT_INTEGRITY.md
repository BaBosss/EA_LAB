# HANDOFF — 2026-07-28 `S-2026-07-28-DECISIONS` (2nd re-open) — the judge account may be judging EAs that were never running

> ⚠️ canonical entry = `PROJECT_STATE.md` · this file owns: **the account-463666728 integrity finding, the
> analysis needed to act on it, and the paste-ready prompt for the next session.** Not a queue — routing at the end.
>
> 🔴 **Read this before anything else on 2026-07-29.** It was found by accident while closing ORDER-511, and it
> is larger than every order it came out of. **The user's weekly quota was at ~5% when this was written**, so the
> expensive analysis is done HERE and the next session only has to execute.

---

## 1. The finding in one paragraph

Account **463666728** holds **~13 EAs whose demo record is the evidence for the October judge**. Three separate
measurements taken today say that record cannot be trusted as it stands:

1. **One leg is running a configuration nobody validated.** `Boss_17_Wave5` on `USDJPYm,H1` reads **all five**
   inputs where its bundle `.set` differs from the compiled defaults *at the default value* — the `.set` was
   never loaded onto that chart. It has been accumulating judge evidence since **2026-07-18**.
2. **Two magics are trading on this account that do not exist in `DEPLOYMENTS.csv`** — `990001` and `990020`.
3. **Ten magics that `DEPLOYMENTS.csv` calls `ACTIVE` produced zero deals** across `2026-07-16 → 2026-07-27`.

None of this is real money. All of it is the input to a real-money promotion decision in October.

---

## 2. What is PROVEN (measured, reproducible)

### 2a. Wave5 USDJPY runs on compiled defaults — the `.set` was never loaded

Read off the Inputs tab by the user (screenshots 2026-07-28 13:29), all five differing inputs:

| input | bundle `.set` | **on the chart** |
|---|---|---|
| `_0_Magic` | 990303 | **990001** |
| `_9_MaxLevels` | 1 | **5** |
| `_23_TrailStart` | 2000 | **300** |
| `_23_TrailStep` | 800 | **100** |
| `_17_Wave3MinMult` | 1.618 | **0.618** |

`_vps_deploy/WAVE5_USDJPY/WAVE5_USDJPY_H1_demo_v1.set:9` pins `_0_Magic=990303` correctly ⇒ **the bundle is not
wrong; the chart never loaded it.** Same class as memory `attach-verify-gate-and-binary`.

**What actually changed behaviour — and what did NOT:**
- 🚫 **`_9_MaxLevels` 1→5 is INERT. Do not write this up as 5× exposure.** `core/Stack.mqh:274` —
  `if(StackMode == STACK_SINGLE) return false;  // 90: never add` — and the chart shows StackMode = **90 Single**.
  Everywhere else `_9_MaxLevels` is only read as `if(_9_MaxLevels <= 0) return;`, so 1 and 5 behave identically.
  <sub>This one was flagged as the alarming finding by the Opus seat and the check it demanded before claiming it
  showed it was false. Kept here so nobody re-raises it.</sub>
- ✅ **`_17_Wave3MinMult` 1.618 → 0.618** — the wave-3 confirmation threshold is **much looser**, so entries fire
  on weaker structures. Entry selectivity is not the validated one.
- ✅ **`_23_TrailStart` 2000 → 300 and `_23_TrailStep` 800 → 100** — trailing starts ~7× earlier and follows ~8×
  tighter ⇒ winners are cut short. Exit behaviour is not the validated one.

⇒ **entry and exit are both wrong at the same time.** The 10 days of demo record for this leg are not evidence
about the config that passed the funnel.

### 2b. Two unregistered magics are trading on the judge account

From `portfolio/live_deals/EA_LAB_deals_463666728_20260728.csv`, window `2026.07.16 15:48 → 2026.07.27 19:00`:

| magic | deals | note |
|---|---|---|
| **990001** | 2 | the unpinned Wave5 USDJPY above — **not a `DEPLOYMENTS.csv` row** |
| **990020** | 2 | `XAUUSDm`, comment **`ST_ATR10x3`** ⇒ SuperTrend family; `EA_SUPERTREND - XAUUSDm,H4` is in the Navigator list. **Not a `DEPLOYMENTS.csv` row.** One deal closed **−57.08** on an SL |
| 990120 | 15 | registered |
| 990302 | 8 · 990301 | 4 · registered |
| 991003 | 2 · 991070 | 2 · 999094 | 1 · registered |
| 0 | 2 | no EA (manual/broker) |

### 2c. Ten `ACTIVE` magics produced nothing in 11 days

`991005` (EA_BREAKOUT_XAU US30m) · `990066` `990067` `990068` `990069` (IchiADX ×4) · `990303` (Wave5 USDJPY —
explained: it trades as 990001) · `990984` (PairSpread_StatArb) · **`992017` (PivotBreakout_XAU)** · `990103`
(RSI_MR GridLog) · `990016` (Boss_16 Kangaroo).

---

## 3. What is NOT proven — do not let the next session skip this

- 🔴 **Zero deals is NOT evidence an EA is broken.** This lab ratified a bar *this morning* precisely because four
  EAs legitimately trade at 0.2–0.3 closed trades/week (ORDER-235). Eleven days at that rate produces **zero
  trades in the normal case**. Any claim that a zero-deal EA is silent needs a *second*, independent signal.
- The `_06_AllowLive` discriminator is a **hypothesis, not a measurement**: `EA_BREAKOUT_XAU`, `EA_SUPERTREND` and
  friends ship `_06_AllowLive = false` compiled and `true` in the bundle `.set`, so a chart that never loaded its
  `.set` **cannot trade at all and looks exactly like a quiet EA**. Nobody has read that input off a chart yet.
- **`990016` Boss_16 Kangaroo has no deals, no GlobalVariable, and was not visible in the Navigator list** — it may
  simply not be attached, despite `DEPLOYMENTS.csv` saying `ACTIVE` since 2026-07-26. Its bundle `.set` *does* pin
  the magic (`990016`; the `_scaled_demo` variant pins **`990018`**, which is in no inventory row), so the
  ORDER-129 default-magic guard is **not** the explanation. Unresolved.
- **The Navigator list was scrolled/truncated in every screenshot**, so no chart count is final.
- `EA_BREAKOUT_XAU - XAUUSDm,H1` appears attached here, but inventory places EA_BREAKOUT_XAU on this account only
  on `USDJPYm` (991003) and `US30m` (991005); the XAU instances belong to **159503454**. Unexplained.

---

## 4. The analysis the next session does NOT have to redo

For every deploy bundle: the inputs where the shipped `.set` differs from the EA's compiled defaults. **These are
the only inputs whose value can tell you whether a `.set` was loaded.** Read any one of them off the Inputs tab.

| bundle (EA) | read this / expect | if it reads the right-hand value, the `.set` was **not** loaded |
|---|---|---|
| `WAVE5_XAU` · `WAVE5_XAG` (Boss_17_Wave5) | `_23_TrailStart` = **2000** | 300 |
| `MACDDIV_XAU` (MacdDiv_Naked) | `_01_LookbackBars` = **60** · `_01_SwingRadius` = **3** | 80 · 2 |
| `ICHIADX_XAU` · `ICHIADX_USDJPY_BASKET` | `TenkanPeriod` = **20** · `KijunPeriod` = **60** | 9 · 26 |
| `EA_BREAKOUT_USDJPY` (991003) · `EA_BREAKOUT_US30` (991005) | **`_06_AllowLive` = `true`** · `_06_Magic` | **false** ⇒ cannot trade at all |
| `EA_SUPERTREND_XAU` | **`_06_AllowLive` = `true`** | **false** ⇒ cannot trade at all |
| `PAIRSPREAD_STATARB` (990984) | `_01_EntryZ` = **2.5** · `_05_LotA` = **0.05** | 2.0 · 0.10 |
| `RSI_MR_EURUSD` (990103) | `_01_RsiOversold` = **25.0** · `_02_SlMaxPips` = **600** | 30.0 · 200 |
| `MACROGATE_DEMOLEG` (990120) | `ExitMode` = **22** · `SLMode` = **33** | EXIT_ATR_TP · SL_ATR |
| `MACROGATE` | `InpStaleMaxHours` = **200** | 48 |
| `BOSS16_KANGAROO_XAU` (990016) | `ExitMode` = **22** · `_0_Magic` = **990016** | EXIT_ATR_TP · 990001 |

🔴 **Where this test has NO power — say so rather than reporting a pass:** `PIVOTBREAKOUT_XAU` (**992017, the
strongest candidate in the fleet**) · `S2_TSMOM_XAU` · `SMCSTO_EURUSD` · `SS1_LONDONORB_XAU` ·
`W2_S1_TRENDRIDER_XAU` · `ST03_GBPUSD` · `CB_EUR` · `CB_GBP` all show **zero** differing inputs, so a loaded
`.set` and an unloaded one are **indistinguishable** by this method (memory
`discriminating-test-must-be-able-to-discriminate`). Either the `.set` genuinely equals the defaults, or the
comparison failed to locate that EA's source — **both need a different check, and neither may be written up as
verified.**

---

## 5. Recommended order of work (why this order)

1. **Read the `.set`-vs-default tells above, for the whole 463666728 chart list.** Cheapest, and it is the only
   thing that converts "10 EAs produced nothing" from a worry into a fact or a non-issue. `_06_AllowLive` first —
   it is the one input whose wrong value means *cannot trade*, and three EAs on this account depend on it.
2. **Identify `990020` and `990001`** and either give them inventory rows or correct the charts. `990020` is
   trading and losing money-shaped numbers on the judge account with no row anywhere.
3. **Only then** decide the Wave5 USDJPY fix — it needs a user decision (§6) and it is not the biggest item.
4. **ORDER-510** (pre-132 binaries) stays where it is. Both affected accounts are demo; the standing prohibition
   on copying `Boss_*.ex5` to the VPS holds and nothing degrades while it waits.

---

## 6. The one decision that is the user's

Fixing Wave5 USDJPY means loading the correct `.set`, which changes `_0_Magic` `990001 → 990303`, and **an EA that
changes magic forgets every position it owns.** There is an open `USDJPYm` position (**ticket 2292452147**, buy
0.01 @ 163.787, ~−0.56).

| option | consequence |
|---|---|
| **(a) close the position by hand, then load the `.set`** ← recommended | cleanest; the position is demo and ~−0.56 |
| (b) load the `.set` now | the position is orphaned — no EA manages it — and must be closed by hand anyway |
| (c) wait for it to close itself | unbounded wait, and it blocks ORDER-510 |

⚠️ **This must happen BEFORE the ORDER-510 binary upgrade, not after.** `core/LabCore.mqh:235-239` refuses
`OnInit` when `_0_Magic == 990001` on any non-tester account, so upgrading first makes this chart stop starting.

**Also the user's call:** `990303` has 10 days of record on the wrong config. Restart its judge clock, or keep it
with a written caveat? Do not decide this for them.

---

## 7. Paste-ready prompt for the next session

```
อ่าน PROJECT_STATE.md, docs/SESSION_LEDGER.md แล้วจองบล็อกของตัวเอง commit ก่อนแตะไฟล์
อ่าน _triage/HANDOFF_2026-07-28_JUDGE_ACCOUNT_INTEGRITY.md ให้ครบก่อนเริ่ม — งานวิเคราะห์ทำไว้ให้แล้ว
ห้ามรื้อทำใหม่ ให้เอาไปใช้

quota ของผมเหลือน้อย ทำทีละอย่าง อย่าแตกงาน อย่าเปิดใบใหม่เกิน 2 ใบ

งาน = ตรวจว่า EA บนบัญชี 463666728 (บัญชีที่ ~13 EA รอ judge ต.ค.) ตัวไหน "ไม่ได้โหลด .set"
ใช้ตาราง §4 ของ handoff = รายการ input ที่ .set ต่างจาก default พร้อมค่าที่ควรอ่านได้

ลำดับ:
1. เริ่มที่ _06_AllowLive ของ EA_BREAKOUT_XAU (USDJPYm,H4 + US30m,H4) และ EA_SUPERTREND (XAUUSDm,H4)
   ถ้าอ่านได้ false = EA เทรดไม่ได้เลย ซึ่งอธิบายได้ทันทีว่าทำไม 991005 ไม่มี deal สักไม้ใน 11 วัน
   บอกผมมาว่าให้เปิดชาร์ตไหน ผมจะอ่านค่าให้ทีละตัว
2. แล้วไล่ EA ที่เหลือตามตาราง §4
3. ที่ §4 บอกว่า "ไม่มี power" (992017 PivotBreakout, TsMom, SMCSTO, LondonORB, TrendRider, ST03, CB_*)
   ห้ามเขียนว่า verified เด็ดขาด — ต้องหาวิธีตรวจอย่างอื่นหรือประกาศว่ายังไม่รู้
4. ระบุให้ได้ว่า magic 990020 (comment ST_ATR10x3, XAUUSDm) กับ 990001 คือ EA ตัวไหน
   ทั้งคู่เทรดอยู่จริงบนบัญชี judge แต่ไม่มีแถวใน DEPLOYMENTS.csv

ห้าม:
- สรุปว่า EA ที่ deal = 0 คือ EA ที่พัง เพราะบาร์ ORDER-235 ที่ user เพิ่ง ratify วันนี้ยอมรับว่า
  EA thin เทรด 0.2-0.3 ไม้/สัปดาห์ ⇒ 11 วันได้ 0 ไม้เป็นเรื่องปกติ ต้องมีสัญญาณที่สองเสมอ
- เขียนว่า _9_MaxLevels 1->5 คือ exposure 5 เท่า (Stack.mqh:274 พิสูจน์แล้วว่าเป็นแกนตายที่ StackMode=90)
- แก้ค่าบนชาร์ต / โหลด .set / ปิดไม้ใดๆ โดยไม่ถาม user ก่อน (มีไม้เปิดค้าง ticket 2292452147)
- ก๊อป rebuild หรือเขียนทับ Boss_*.ex5 บน VPS (ORDER-510 ยังเปิดอยู่)
- แตะแถว ORDER-511 ถ้าเลน S-2026-07-28-MAGIC511 ยัง ACTIVE อยู่

จบงาน: append แถว docs/memory_control/B1_DATASET.csv ใน commit เดียวกับที่ mark REVIEWED
```

---

## ปลายทางของทุกรายการ

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| Wave5 USDJPY runs on compiled defaults; the `.set` was never loaded | ORDER-511 (OPEN, lane MAGIC511 owns the row) |
| `_9_MaxLevels` 1→5 is inert under StackMode=90 — not an exposure finding | ORDER-511 (correction, must not be re-raised) |
| Entry threshold and trail are both off the validated config for 10 days | ORDER-511 — needs the user's judge-clock decision |
| Magic `990020` (`ST_ATR10x3`, XAUUSDm) trading with no inventory row | **needs a new order** |
| Magic `990001` trading with no inventory row | ORDER-511 |
| Ten `ACTIVE` magics with zero deals over 11 days — worry, not yet a fact | **needs a new order** (the §4 sweep) |
| `.set`-vs-default tell table for every bundle | this file §4 — do not recompute |
| Bundles where the test has no power, incl. **992017 PivotBreakout** | this file §4 — must not be reported as verified |
| `990016` Boss_16: no deals, no GV, not in Navigator, `.set` pins correctly | unresolved — carry into the sweep |
| `BOSS16_KANGAROO_XAU` `_scaled_demo.set` pins **990018**, in no inventory row | carry into the sweep |
| `EA_BREAKOUT_XAU - XAUUSDm,H1` attached here but inventory says 159503454 | carry into the sweep |
| Open position ticket 2292452147 blocks the Wave5 re-pin | ORDER-511 §6 — user decision |
| Wave5 re-pin must precede the ORDER-510 upgrade or the chart stops starting | ORDER-510 · ORDER-511 |
| Pre-132 binaries on the VPS; prohibition on copying `Boss_*.ex5` still stands | ORDER-510 (OPEN) |
| Floating coverage 6/6 verified, ORDER-400 closed | DONE |
