# PLAN — "5 EA WAR SQUAD" (โพสต์ FB + battle card HTML) → แผนเทสตาม VERDICT GATE

> intake 2026-07-27 · source = โพสต์แชร์ไอเดีย 5 EA + `CLAUDE_EA_BATTLE_CARD.html` (Google Drive,
> owner arkira941) · claim "$1,000→$4,000 ใน 2 เดือน" = ไม่มีหลักฐาน (ไม่มี statement/myfxbook) —
> **ห้าม anchor กับ claim นี้** ใช้เป็นแหล่งไอเดียอย่างเดียว
> สถานะ: PLAN เท่านั้น ยังไม่มี verdict ใดๆ — ทุก transition ใช้บาร์จาก CLAUDE.md VERDICT GATE

## หลักการแตกไอเดีย (course-file rule: แกะ CONCEPT ออกจาก vehicle)

5 EA นี้จริงๆ มี **entry-concept ใหม่ 2 ตัว + sizing-lever 2 ตัว + ศพเก่า 1 ตัว**:

| # | ชื่อโพสต์ | แก่นจริง | ชนกับ prior ใน repo | ประเภท |
|---|---|---|---|---|
| EA1 | Apex Scanner | **cross-sectional momentum rotation** (ADX×EMAgap/ATR เลือก Top-3 symbol) | entry ข้างใต้ = EMA21/89 cross = dead concept (MASTER_BACKLOG) → ของใหม่คือ **ชั้น selection** ไม่ใช่ entry | entry/portfolio concept — ใหม่จริง |
| EA2 | Compound Beast | **win-streak lot ×1.6, reset on loss** (anti-martingale) | = STRATEGY_200 #47 "technique ดี graft เข้า trend EA" · entry EMA9/21+RSI XAU M15 = dead family | sizing lever — ห้ามเทสเป็น EA เดี่ยว |
| EA3 | Session Vampire | London/NY **ORB 30min** XAU, SL=0.6×range TP=2×range | ตระกูล session-breakout ตายซ้ำ: LNBREAK DEAD (+re-exam ORDER-008B) · AsianRange DEAD · NRBreakout XAU H1 ตาย | ศพเก่า — ให้โควตา probe เดียวแบบมีเงื่อนไข |
| EA4 | Triple Sniper | **MTF alignment H4 EMA50 + H1 EMA21/89 + M15 EMA9/21** + partial 50%@1R + BE | death-taxonomy ระบุ "MTF confluence barely used — could lift" · #81 Triple-TF = "น่าลอง" score 6 · H4-direction-gate เคยพิสูจน์ลด DD (อะไหล่ ST03) | entry concept — เปิดจริง, EV สูงสุดในชุด |
| EA5 | Profit Assassin | trend-grid 5 ชั้น + basket-TP 2% + **inter-cycle lot ×1.5** | trend-grid มีแล้ว = Boss_16 Kangaroo (validated candidate) / Boss_11 · ของใหม่ = cycle-compound lot law | sizing lever — graft บน Boss_16 |

**Structural check (gate ข้อ 1) ผ่านทุกตัว** — ไม่มี uncapped ruin: EA2 reset-on-loss + risk cap 5% ·
EA5 มี float-cut −5% + CB 20% (capped, มี exit) · EA3/EA4 มี SL จริง → ทุกตัวเข้า PARAMETRIC track.
แต่ **คำโฆษณาที่ต้องหักทิ้ง:** "downside จำกัด upside ไม่จำกัด" (EA2) กับ "แทบไม่ขาดทุนหลัง BE" (EA4)
= ไม่จริงเชิงคณิต — streak-compounding เพิ่ม risk หลังชนะ (give-back ก้อนใหญ่) และ BE stop กิน winner
ที่ย่อ — ต้องวัด ไม่ใช่เชื่อ.

## Lane priority (เรียงตาม EV ต่อชั่วโมงเครื่อง)

### Lane A — EA4 Triple-TF Sniper (ทำก่อน)
- build `(EXP)_TripleTF_rev01` บน Boss V2 (entry module ใหม่ + ใช้ MM/SL กลางของแม่พิมพ์;
  แก้ `ea_template/core/` เมื่อไหร่ → รัน `tpl_regression.ps1`)
- **hypothesis ที่เทสจริง = ชั้น MTF gate** (EMA-cross เปล่าตายแล้ว): รัน A/B M15-cross เปล่า vs
  +H1 gate vs +H1+H4 gate — ถ้า gate ไม่ยก PF = concept ตายเร็ว ประหยัดเวลา
- home: XAU + GBPUSD (momentum→trender ตาม RIGHT HOME) · TF entry M15 (+M30 เป็นแกนที่สอง)
- exit เป็น lever แยก (บทเรียน ORDER-125): fixed ATR vs partial50%@1R+BE vs trail — ห้าม hardcode
  partial+BE ตามโพสต์แล้วสรุปทั้ง concept จากมัน
- windows: MAIN 2023.07–2026.07 M1 · ผ่าน smoke แล้วค่อย BWD 2020–2022
- bar: smoke naked PF≥1.2 (WATCH 1.0–1.2 → BUILD-ON ladder ≥3 lever × ≥2 TF ก่อนคิดปิด)

### Lane B — EA1 momentum rotation (ของใหม่เชิงโครงสร้าง)
- **stage B1 (ถูกก่อน):** ยังไม่ต้องเขียน multi-symbol EA — รัน per-symbol backtest entry เดียวกัน
  (EMA21/89 + ADX>22, ATR SL1.5/TP3.0) บน 8–10 symbol แล้วให้ script stitch แบบ rotation
  (ทุก H1 ranking ด้วย momentum score จาก data เดียวกัน) เทียบ: rotation Top-3 vs equal-weight vs
  best-single-symbol — **ถ้า rotation ไม่ชนะ equal-weight = ชั้น selection ไม่มีค่า จบ lane ตรงนั้น**
- stage B2 (ต่อเมื่อ B1 ชนะ): ค่อย build multi-symbol EA จริงบน MT5 (tester รองรับ multi-symbol
  แต่แพง/ช้า — จ่ายเมื่อ concept พิสูจน์แล้วเท่านั้น)
- อย่างน้อยได้ EDGE_CATALOG entry: "cross-sectional momentum score เป็น symbol-selector" ไม่ว่าผลไหน

### Lane C — sizing levers (EA2 ×1.6 streak + EA5 ×1.5 cycle) — graft ไม่ใช่ EA ใหม่
- host = candidate ที่มี edge จริงแล้ว: MacdDiv XAU H4 (M4 confirmed) และ/หรือ Boss_16 Kangaroo
- A/B ต่อ lever: flat-lot (control) vs streak-×1.6-reset vs (บน Boss_16) cycle-×1.5-cap
- ตัดสินด้วย: PF ต้อง~เท่าเดิม (sizing ไม่สร้าง edge) · เทียบ geometric growth vs eqDD/MC ruin ≤2%
  · **cap บังคับ**: streak สูงสุด 5 ไม้ตามโพสต์ / cycle-lot cap ที่ risk% ต่อ trade ≤ เพดานเดิมของ host
- grid ของ Boss_16 = ห้าม Model-2 เป็นหลักฐาน · every-tick + trend-stress ตามกฎเดิม
- ผลลง EDGE_CATALOG เป็น lever entry (ใช้ได้/ไม่ได้ + เงื่อนไข)

### Lane D — EA3 ORB (ท้ายสุด, conditional)
- เดินได้ต่อเมื่อ Lane A/B มีข้อสรุปแล้ว และหลังเช็ค ORDER-008B ว่า probe เดิม cover อะไรไปแล้ว
- สิ่งเดียวที่ยังไม่เคยเทส: **ORB-30min บน XAUUSD M5/M15 + SL ในรูป fraction ของ range (0.6×)**
  (LNBREAK เดิม = FX + ATR-SL คนละกลไก) → ให้โควตา **probe เดียว 54-cell** (session×window×SL/TP
  fraction) บน XAU — ไม่ผ่าน naked PF≥1.2 ที่ cell ไหนเลย = ปิด cell แล้วพอ ไม่ลาก ladder ยาว
  (ตระกูลนี้จ่ายค่าเล่าเรียนมาพอแล้ว)
- claim "60–70% ของวัน breakout ORB" = frequency ไม่ใช่ edge (breakout บ่อยแต่ SL 0.6×range โดน
  whipsaw ได้บ่อยกว่า) — วัดจริงอย่างเดียว

## สิ่งที่ไม่ทำ (กันหลงทาง)
- ไม่ build 5 EA ตามโพสต์ตรงๆ — 4/5 ตัวใช้ entry ตระกูล EMA-cross ที่ตายแล้ว ของจริงที่เทสคือ
  "ชั้นที่พันอยู่บน entry" (MTF gate / rotation / sizing law)
- ไม่จัด "squad $1,000 แบ่ง 5 ก้อน" — ทุกตัว trend-follow XAU-หนัก corr กันเองสูง คำว่า
  diversified ของโพสต์ยังไม่มีหลักฐาน · portfolio ว่ากันหลังมีผู้รอด corr<0.8 ตาม funnel ปกติ
- ไม่ข้าม funnel: ผู้รอด smoke → optimize ladder → both-window → (ตาม gate) → demo ≥3 เดือน
  ก่อนคุยเรื่องเงินจริงเสมอ

## Definition of done ของแผนนี้
Lane A+B มี verdict ระดับ cell (พร้อม Row-X checklist ครบ) · Lane C ได้ lever entry ใน EDGE_CATALOG ·
Lane D ปิดหรือ surprise · ไอเดียที่น่าสนใจแต่ไม่ผ่าน = PARKED-VERIFY(user) 3 บรรทัด ห้ามตายเงียบ
