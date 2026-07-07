# ORDER-036 — MT4 MASS-SMOKE BOARD (แยกไฟล์เพราะ 27 batches — กัน AGENT_TASKBOARD บวม)

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **สถานะ batch 036-01..036-27 เท่านั้น** ·
> กติกาเต็ม + verdict = `AGENT_TASKBOARD.md` ORDER-036 (ยังเป็น order แม่ ชี้มาที่นี่) + `AGENTS.md`
> **batch เสร็จ + Claude review แล้ว → ย้ายแถวผลดิบไป `_archive/ORDER-036_ARCHIVE.md`** (ไฟล์นี้เก็บแค่
> ตารางสถานะ + batch ที่ยังไม่จบ — ไม่งั้นไฟล์ระเบิด)

## วิธีสั่ง (user)
- สั่งทีละก้อน: **"ทำ 036 batch 04"** หรือยาวๆ: **"ทำ 036 batch 04-08"** (agent ไล่ทีละ batch, commit ต่อ batch)
- ใครทำได้: **Codex · oc-dev** (ต้องคุม driver + MT4) · 👉 แนะ: ตัวที่ว่าง — งาน mechanical มี spec ตายตัว

## Spec ต่อ batch (เหมือนกันทุก batch — อย่าตีความใหม่)
1. worklist ของ batch = `_triage/mass_smoke_mt4_batches.csv` filter คอลัมน์ `batch` (01..27, 50 ตัว/batch, ท้าย 18)
2. ต่อ EA: copy .ex4 → `D:\Meta4\MQL4\Experts\_smoke\` → **M2 quick 2026.04-2026.07** บน basket
   **XAUUSD, EURUSD, USDJPY, AUDNZD** H1 (⚠️ match suffix broker Meta4 จริง เช่น XAUUSDm — ไม่มี = ข้าม+note)
3. **0 trades ทุก symbol = skip+note** · เทรด ≥1 → **M1 2026.03-2026.07** ทุก symbol ที่ M2 เทรด ≥10 ไม้
   (MT4 ไม่มี tick <2026-03 — memory) · ใช้ `mt4_run.ps1` + `parse_mt4_report.py`
4. ผลลง `_mt5_auto/mass_smoke_mt4.csv` (append; คอลัมน์เดียวกับ mt5 version + คอลัมน์ batch)
5. **Tier gate (กฎ user PF>1):** Tier A = PF>1 AND trades≥20 AND eqDD<40% · Tier B = PF>1 แต่ eqDD≥40%
   (grid-trap) · Reject = PF≤1 หรือ trades<20
6. guard: timeout 180s/run · skip hang · try/catch ต่อ EA · log ทุก 10 ตัว
7. จบ batch: อัปเดตตารางข้างล่าง (สถานะ + นับ A/B/reject/skip) · commit `[tag] ORDER-036 batch NN done`
8. **ห้าม:** verdict · แก้ source · รันเกิน batch ที่สั่ง

## ⚠️ บทเรียนบังคับใช้ (จาก ORDER-037: top-3 MT5 ตายครบ, 2026-07-06)
Tier A ห้ามเชื่อจากเลข — **ด่านแรกหลัง smoke = backward-OOS 2020-2022** (ถูกกว่า M4 + ฆ่า regime-harvester
ได้เด็ดขาด: pun fix lot eqDD 83% ปี 22 · GapinFX balDD 112% ปี 22 ทั้งที่ 2021 PF 22.56) → รอดค่อย
source read (ถ้ามี .mq4) + Model-4. เลขสวย 2023-26 = mean-reversion regime ไม่ใช่ edge จนพิสูจน์ปีเทรนด์
· ชื่อไฟล์มี "_fix"/"_nodll"/"crack" = DQ ทันที (cracked commercial, hard-gate)

## ตารางสถานะ (agent อัปเดตแถวตัวเองตอนจบ batch)

| Batch | EAs | สถานะ | Tier A | Tier B | Reject | Skip/0-trade | หมายเหตุ |
|---|---|---|---|---|---|---|---|
| 036-01 | 50 | REVIEWED(Claude 07-06) | 24 | 2 | 10 | 164 | Tier A 24 → **ORDER-040 BWD-OOS ก่อนเชื่อ** (กติกาใหม่) · ⚠️ CSV comma-bug 2 แถว (แก้ใน 040) · exact-history: EURUSD, USDJPY เท่านั้น (XAU/AUDNZD ไม่มี) |
| 036-02 | 50 | REVIEWED(Claude 07-06 ค่ำ — Codex ผ่านตรวจเข้ม 4b: CSV 200 แถว ✓ · report 8/8 มีจริง ✓ · spot-check PF ตรง ✓) | 5 | 0 | 4 | 191 | Tier A triage ด้านล่างตาราง · ❌ CITY-GOLD "_fix" = **DQ ทันที (cracked, precedent North East Way)** |
| 036-03 | 50 | REVIEWED(Claude 07-06 ค่ำ — ตรวจชุดเดียวกับ 02) | 3 | 0 | 3 | 194 | Tier A triage ด้านล่างตาราง |
| 036-04 | 50 | REVIEWED(Claude 07-06 — รันเองบนเลน MT4b ด้วย driver ใหม่) | 0 | 0 | 2 | 198 | **โซนตาย: 0 survivor ทั้ง batch** — กอง "FREE EA" bundle = indicator conversion เกือบทั้งหมด · precheck ทำงานจริง: จับ `missing-indicator:` พร้อมชื่อไฟล์ (เช่น BrainTrend2Sig.ex4) + ข้าม symbol ที่เหลือ = ไม่เผา timeout · timeout-kill พิสูจน์แล้ว (LRCChannelD โดน kill ที่ 180s แทนที่จะค้างเป็นชั่วโมงแบบเดิม) · stage-2 BWD-OOS = n/a (ไม่มี Tier A) |
| 036-05 | 50 | REVIEWED(Claude 07-07 — เลน 1) | 10 | 0 | 1 | 189 | ⚠️ **Tier A ทั้งหมด = 1 ตระกูลต้องสงสัย** — ดู triage ล่างตาราง (BWD-OOS กำลังรัน) |
| 036-06 | 50 | REVIEWED(Claude 07-07 — เลน MT4b) | 0 | 0 | 0 | 200 | **โซนตาย 100%** — indicator-name pack อีกกอง (SHISIGNALARROW/SyncMA/StealthXXX ฯลฯ) |
| 036-07 | 50 | REVIEWED(Claude 07-07 — เลน MT4b) | 0 | 0 | 1 | 199 | โซนตาย — 291-TOIS.jrEURJPYGBPCHF (อีก "\*.jr\*" family) ไม่ผ่านแม้แต่ Tier A ระดับ smoke |
| 036-08 | 50 | REVIEWED(Claude 07-07 — เลน 1) | 0 | 0 | 0 | 200 | โซนตาย 100% — indicator pack ต่อเนื่อง (WSS*, X*, ZUP ฯลฯ) |
| 036-09 | 50 | REVIEWED(Claude 07-07 — เลน MT4b) | 0 | 0 | 0 | 200 | โซนตาย 100% — 0 เทรดทั้งกอง (แม้แต่ Reject ก็ไม่มี) |
| 036-10 | 50 | REVIEWED(Claude 07-07 — เลน 1) | 5 | 0 | 5 | 190 | **0/3 survivor หลัง auto-flag lot-escalation** — ดู triage ล่างตาราง |
| 036-11 | 50 | REVIEWED(Claude 07-07 — เลน MT4b) | 3 | 0 | 6 | 191 | **0/3 survivor — ตัดสินจาก smoke เดิมได้เลย ไม่ต้องเสีย BWD** ดู triage ล่างตาราง |
| 036-12 | 50 | REVIEWED(Claude 07-07 — เลน 1) | 20 | 0 | 8 | 172 | **0/11 survivor — ทุกตัวตายจาก lot-check ฟรี ไม่ต้องรัน BWD เลย** ดู triage ล่างตาราง |
| 036-13 | 50 | REVIEWED(Claude 07-07 — เลน MT4b) | 7 | 3 | 10 | 180 | **0/6 survivor — ทุกตัวตายจาก lot-check ฟรี (33x-38,750x)** ดู triage ล่างตาราง |
| 036-14 | 50 | REVIEWED(Claude 07-07 — เลน 1) | 7 | 0 | 5 | 188 | **0/5 survivor — lot-check ฆ่าทั้งหมด (656x-32,321x)** batch ที่ 5 ติดกัน (11-15) ไม่ต้องรัน BWD |
| 036-15 | 50 | REVIEWED(Claude 07-07 — เลน MT4b) | 8 | 1 | 11 | 180 | **0/5 survivor — lot-check ฆ่าทั้งหมด (1518x-10244x, ชื่อ "Ilan" = grid/martingale ชื่อดังในวงการ)** batch ที่ 4 ติดกันไม่ต้องรัน BWD |
| 036-16 | 50 | REVIEWED(Claude 07-07 — เลน MT4b) | 7 | 0 | 7 | 186 | **0/5 survivor — lot-check ฆ่าทั้งหมด (1104x-4663x) + 2 ตัว worthless (net~$0-3)** batch ที่ 6 ติดกัน (11-16) ไม่ต้องรัน BWD |
| 036-17 | 50 | REVIEWED(Claude 07-07 — เลน 1) | 2 | 1 | 6 | 191 | **0/2 survivor — lot-check ฆ่าทั้งหมด (2691x, 717x)** batch ที่ 7 ติดกัน (11-17) ไม่ต้องรัน BWD |
| 036-18 | 50 | REVIEWED(Claude 07-07 — เลน MT4b) | 7 | 3 | 11 | 179 | **0/5 survivor — lot-check ฆ่าทั้งหมด (222x-6048x)** batch ที่ 8 ติดกัน (11-18) ไม่ต้องรัน BWD |
| 036-19 | 50 | REVIEWED(Claude 07-07 — เลน 1) | 6 | 0 | 4 | 190 | **0/4 survivor — lot-check ฆ่าทั้งหมด (720x-3055x)** batch ที่ 9 ติดกัน (11-19) ไม่ต้องรัน BWD |
| 036-20 | 50 | REVIEWED(Claude 07-07 — เลน 1) | 4 | 0 | 1 | 195 | **1 candidate เข้าคิว BWD-OOS: TradePad_Current_Timeframe(EURUSD,PF1.43,net$238.5,560trd,DD0.69%,lot 1x clean)** — reject: "Take Profit"(ชื่อหลอก จริงๆ lot 43x-69x=grid ซ่อนอยู่), TradePad USDJPY-side worthless(net$36) |
| 036-21 | 50 | REVIEWED(Claude 07-07 — เลน MT4b) | 9 | 0 | 2 | 39 | **2 candidates เข้าคิว BWD-OOS: UnNomGuaiV1.132(EURUSD,PF2.06,net$819,329trd), walid Ema(EURUSD+USDJPY,PF1.14-1.19,net~$1192 รวม,consistent 2 symbol)** — reject: TSR-2018 v5.0_Fix(lot 128x=grid), VisualMartiEA(ชื่อ=martingale), FX Sniper/Two_MA_Cross(worthless net<$40), Turbo-profit v3.0(อ่อน PF1.23 net$195 เดี่ยว symbol) |
| 036-22 | 50 | REVIEWED(Claude 07-07 — ครบทั้ง 50 รวม 22R re-smoke: 7 ตัว zombie-abort = 0 candidate เพิ่ม) | 10 | 0 | 8 | 182 | **1 candidate เข้าคิว BWD: Yetti3+NewsSherry (EU PF1.51/+700/2911trd · JP PF4.35/+94 · lot ×5 ทั้งคู่)** — reject: Scalping XTendFX (lot ×32/×256 = martingale ladder จริง แม้ PF 3-5.9), Perceptrader/Signalspro007 ×3 = "_fix" DQ (cracked), PumLot worthless (net $45) · ดู triage ล่างตาราง | 
| 036-23 | 50 | REVIEWED(Claude 07-07 บ่าย — b9ulqxtba รันจบจริง exit 0, ไม่ต้อง relaunch: ABORT ท้าย log ตกแค่ M1 USDJPY ของ "EA HOPE V1.20_fix" ที่ DQ อยู่แล้วจากชื่อ ไม่กระทบ Tier A) | 5 | 0 | 2 | 193 | **1 candidate เข้าคิว BWD-OOS: 143 E4.7.4 v1(EURUSD,PF3.0,net$2016,522trd,DD9.03%,lot×3 clean via mt4_lotcheck.ps1)** — ✅ **append เข้า targets resurrect sweep แล้ว (แถวท้ายสุด, ทันก่อน Import-Csv)** · DQ ทันทีจากชื่อ "_fix": Gold Buster MT4-2.3-fix-1428+ (EU+JP), Zeus Gold Hedge V1.2_fix_1420 (EU+JP) |
| 036-24 | 50 | REVIEWED(Claude 07-07 บ่าย — เลน MT4b, biakpwz4g) | 24 | 0 | 12 | 164 | **1 candidate เข้าคิว BWD-OOS: Z61(EURUSD PF2.1/net$1734/1201trd/DD6.04% + USDJPY PF2.45/net$978/1037trd/DD4.03%,lot×1/×5.6 clean — ⚠️ entries ดิบ 12,527/13,284 สูงกว่า total_trades มาก = ต้องดู trade-list ละเอียดตอน BWD ว่า basket/hedge เปิดหลายไม้/trade หรือไม่)** — reject: EABOT2.3(×281/×69) EABOT2.5(×176/×43) Gold Stuff EA V7.0(×61/×34, **ยืนยัน precedent decision 2026-06-23 เดิม — EA ตัวเดียวกันที่เคย DQ ไปแล้ว**) Z26(×21/×27) Z27(×46/×78) Z30(×210/×14) Z46(×210/×162) Z47(×183/×108) Z52(×162/×243) Z57(×365/×61) = 9 ตัวตาย lot-check · Bistion_v12 (EU PF18.02/70trd vs JP PF0.51/-169 = thin-sample/regime-lucky cross-symbol) · SkyFX EA_fix = DQ ชื่อ |
| 036-25 | 50 | REVIEWED(Claude 07-07 บ่าย — เลน MT4b, b0f8qg3ag) | 14 | 1 | 8 | 177 | **0/10 survivor — ปิดสะอาดไม่ต้องรัน BWD-OOS เลย** — Bonnitta EA MT4 DOWNLOADMQ4.COM(lot×128/×26+ชื่อเว็บโหลดเถื่อน) EA FREEDOM PRO-FULL LICENSE(lot×9/×7 borderline+ชื่อ"FULL LICENSE"=license-crack signal เดียวกับ Bonnitta) EA-HOKKYDJONG(lot×110/×110) Yetti Pro. by @SoftechFX_Robot(lot×642.5/×110, **แฝดกับ Yetti Pro_fix ที่ DQ ชื่อ — เลขเกือบเหมือนกันเป๊ะ 662/1379/4221.9 vs 668/1379/4218.62 = ตัวเดียวกัน ก็อปมาแปะชื่อคนละอัน**) = 4 ตัวตาย lot-check/ชื่อ · **SL=2GRIDE NEW ชื่อมี"GRID"แต่ lot ×1 สะอาด — ตายด้วย cross-symbol แทน (EU PF1.86/+277 vs JP PF0.48/-539 = regime-dependent เหมือน cci ma ea เดิม)** · Nong Tom(Tier B DD66% EU vs DD19% JP ไม่นิ่ง) · FX SCALPER X New Fix + Yetti Pro_fix = DQ ชื่อ "_fix" · Forex Tramp 4.0.0 pb(lot×9.5 borderline+thin 27trd)→PARKED-marginal · Robot FX Saturn Scalping(lot×1 สะอาดแต่ USDJPY net$3.75)→PARKED-worthless |
| 036-26 | 50 | REVIEWED(Claude 07-07 บ่าย — เลน MT4b, brs4v2juk) | 2 | 0 | 2 | 196 | **0/1 survivor — Tier A มีแค่ "Grid Custom" (EU+JP) ชื่อบอกตรงๆ + lot-check ยืนยัน ×10 ทั้งคู่ (พอดีเส้น auto-reject)** ไม่ต้องรัน BWD |
| 036-27 | 18 | REVIEWED(Claude 07-07 บ่าย — เลน MT4b, bmfx9byrg — **batch สุดท้ายของ 27 ก้อน, mass-smoke sweep จบครบแล้ว**) | 12 | 0 | 3 | 57 | **🎉 4 candidates เข้าคิว BWD-OOS (มากสุดในหนึ่ง batch): Dark Mimas(EU+JP,PF5/3.52,lot×3/×6,net$296/246,DD0.61/2.56 sะอาด) Dark Venus(EU+JP,PF2.94/3.46,lot×5/×4,net$296/211,DD2.47/1.32) RSI from pips_EA(EU เดียว,PF2.61,149trd,net$279,lot×3) Yetti3_Mod2_newsWorking(EU+JP,PF3.41/4.32,lot×3/×3,net$2147/124,⚠️entries 1365 vs m1_trades 3340 = high-freq เหมือน Z61)** — reject: Yetti Pro(USDJPY, **precedent-match กับ Yetti Pro batch-25 ที่ตายไปแล้ว ×642.5 — fingerprint แทบเหมือนเป๊ะ 662trd/PF2.42/net4187 vs 662trd/PF2.41/net4221.9 = ตัวเดียวกัน ไม่ต้องรันซ้ำ**) New Sure Fire HedgingV.1.7(lot×64/×64=hedge จริงตามชื่อ) YettiAUTOTRADE_EN_Fix(DQ ชื่อ_fix) | **⚠️ BWD-OOS 4 candidate นี้ FAILED บนเลน MT4b (NO_REPORT ทั้ง 7 แถว) — เจอบั๊กโครงสร้างใหม่: เลน MT4b (D:\Meta4b) ไม่มีข้อมูลย้อนหลัง 2020-2022 โหลดไว้ (portable copy ตั้งไว้สำหรับ smoke 4 เดือนล่าสุดเท่านั้น) — เทสจบทันทีไม่มี report ทั้งที่ launch สำเร็จ. แก้ script `bwdoos_mt4_sweep_b27.ps1` ให้ชี้เลน 1 (D:\Meta4) แล้ว — คิวรันใหม่ต่อจากเลน 1 ว่าง. กฎถาวรใหม่: BWD-OOS/backward ทุกชนิดต้องรันบนเลน 1 เท่านั้น** |

## 🚨 Lot-check AUDIT (Claude, 2026-07-07 บ่าย — บั๊กใหญ่สุดของ order นี้: quick-grep เดิมกวาดคอลัมน์ผิด)

**การค้นพบ:** ระหว่างอ่าน BWD report ของ UnNomGuai quick-grep `class=mspt>(\d+\.\d\d)` ให้ "max lot
18,532.33" ซึ่งจริงๆ คือ **balance ปลายทาง** — regex นี้ match ทุก cell เลขทศนิยม 2 ตำแหน่ง =
**คอลัมน์ Size + Profit + Balance ปนกัน** (≈3.6 ค่า/แถว) → ค่า "max lot" ที่ใช้ auto-reject
batch 10-19 เกือบทั้งหมดปนเปื้อน. Re-audit ทุก Tier A (batch 10-21, 85 แถว) ด้วย parser ที่อ่าน
**คอลัมน์ Size ของแถว entry (buy/sell) เท่านั้น** → `scripts/mt4_lotcheck.ps1` (เครื่องมือถาวรใหม่) ·
ผลดิบ `_mt5_auto/lotcheck_audit_b10_21.csv`

**ผลกระทบ (สรุป):**
- ❌→❌ **reject ที่ยืนตามเดิม (ratio จริงยัง ≥10x):** AF-Global(×114 บน BWD 3ปี), Budak Ubat(×30),
  CrawlingGrid(×17), Fibo(×15), EA-Martin(×34), FoldXEA(×625), Fxs(×13), GoldenProfit(×69),
  GridMaster_fixed(×11), HedgeMadness(×256), Ilan ทั้งคู่(×103-166), Lenhune(×37), Mm2019(×65),
  rbt(×27), Scalping Strategy System(×15), Take Profit(×69), TSR-2018(×128+ชื่อ_Fix DQ),
  CommunityPower(×40 ยืนยันจาก trade list เดิมด้วย) + ทุกตัวที่ตายด้วย BWD DD 96-99% (SEMIS.jr,
  DanceT, Flexy, Happy Fast Money — ไม่เกี่ยว lot-check)
- ✅ **REJECT ผิด → คืนสถานะ candidate (ratio จริง <10x, lot แบนหรือ ladder ตื้น):**

| EA (batch) | ratio จริง (เดิมอ้าง) | smoke PF/net | สถานะใหม่ |
|---|---|---|---|
| **2020v2** (05) | **×5.4** (เดิม ×640 — เลข 63.92 คือ profit ไม่ใช่ lot) | BWD ผ่านแล้ว: PF 2.26/314trd/DD 6.27% | ✅ **คืน candidate — ผ่าน BWD อยู่แล้ว** → spread-stress คิวแรก |
| **Automated Forex Grail** (10) | **×1 แบน** (เดิม ×99) | BWD ผ่านแล้ว: PF 1.53/1063trd/DD 33% | ✅ **คืน candidate — ผ่าน BWD อยู่แล้ว** → spread-stress คิวแรก |
| Envelope 2 (12) | ×1 (เดิม ×392) | 1.5-1.61 / +677+880 สองคู่ | → คิว BWD |
| FZ2 (13) | ×6 (เดิม ×2207-3901) | 2.57-3.41 / +640 สองคู่ | → คิว BWD |
| Phoenix_EA_v5_6_03 (17) | ×1 (เดิม ×717) | 2.93 / +1977 | → คิว BWD |
| MACrossoverMaster (16) | ×1 (เดิม ×1631) | 1.43 / +2537 EU | → คิว BWD |
| swb grid (19) | ×2.2 (เดิม ×3026) | 2.38-2.96 / +1200 สองคู่ | → คิว BWD (ชื่อ grid แต่ ladder ตื้นจริง) |
| SUPERTRENDSURFER (19) | ×6 (เดิม ×3055) | 1.54 / +3820 EU | → คิว BWD |
| Oracle EA (17) | ×1 (เดิม ×2691) | 1.69 / +663 | → คิว BWD |
| EA SCALP RENKO (12) | ×1 (เดิม ×293) | 1.3-1.48 / +520 สองคู่ | → คิว BWD |
| ema_crossmod (12) | ×1 (เดิม ×49.5) | 1.78 / +4542 EU (JP 0.26 = regime-flag) | → คิว BWD |
| Expert (12) | ×1 แบน 4 lot (เดิม ×24) | 1.11-1.26 / +1120+1595 | → คิว BWD (edge อ่อน) |
| EAForexTH_Scalper_S3 (12) | ×1.1 (เดิม ×191) | PF 12-64 absurd-flag | → คิว BWD (BWD จะฆ่าเองถ้า artifact) |
| GBPJPY1H90PCWR (13) | ×1 แบน 1 lot (เดิม ×977) | PF 8.15 / +71k absurd-flag | → คิว BWD |
| killer_sell (15) | ×2.8 (เดิม ×1551) | 1.69 / +218 | → คิว BWD |
| GridMACDMEURUSD (14) | ×1 (เดิม ×657) | 1.12 / +462 JP | → คิว BWD (อ่อน) |
| MA_MA_2-35_EA (15) | ×1 (เดิม ×1518) | 1.17 / +215 | → คิว BWD (อ่อน) |
| EAForexTH_MultiHedge (12) | ×1 EU (เดิม ×1514) | 2.54 / +158 | → คิว BWD |
| VisualMartiEA (21) | ×5 (เดิม reject จากชื่อ) | 2.74 / +206 | → คิว BWD (ชื่อ Marti แต่ ladder จริง ×5) |
| firebird v63f (13) | ×1 (เดิม ×33) | 1.15 / +143 | → คิว BWD (อ่อนสุด) |
| Moving Average (16) | parser อ่าน entry ไม่ได้ (NO_ENTRIES — เดิม ×1434 ก็เชื่อไม่ได้) | 1.66 / +737 | → คิว BWD + inspect report |

- 🅿️ ตัวที่ reject ผิดแต่ **net ใกล้ศูนย์** ไม่คุ้มไล่: gods gift(+57), STARTUP(+38-54), Simple2020/Inverse(+25) → PARKED-worthless ตามเดิม
- verdict ที่ยืนด้วยเหตุ**อิสระ**จาก lot-check ไม่แตะ: cross-symbol (Blessing 3, cci ma ea), worthless,
  Tier B DD gate, ชื่อ _fix DQ · **Happy thaipop (b02-03, PARKED)** — re-check ได้ ×16.3 จริง → ยกระดับเป็น ❌ REJECT ได้เลย (escalation จริง + DD 73%)

**คิวรัน:** `_mt5_auto\ab_sets\bwdoos_mt4_sweep_resurrect.ps1` (26 BWD runs + 3 spread-stress
2020v2/Grail นำหน้า) → **launch บนเลน 1 ทันทีที่ `lane1_chain_070707.ps1` จบ** · ผลลง
`_mt5_auto/BWDOOS_MT4_RESURRECT.csv`

**🔧 แก้ spec ถาวร:** stage-2 ข้อ 2 ห้ามใช้ mspt-grep อีก — ใช้ `scripts/mt4_lotcheck.ps1`
(อ่านคอลัมน์ Size ของแถว entry เท่านั้น) กับทุก lot-check ต่อจากนี้

## 🏁 Resurrect sweep VERDICTS (Claude, 2026-07-07 เย็น — `_mt5_auto/BWDOOS_MT4_RESURRECT.csv` + lot-check 3 ปีด้วย mt4_lotcheck.ps1)

**Spread-stress 30pts (2020-22):**

| EA | baseline → SPR30 | Verdict |
|---|---|---|
| **UnNomGuaiV1.132** | PF 1.89→**1.83** · net 8527→7867 · DD 18.7→**19.0%** · lot ×2.3 เท่าเดิม | ✅ **ผ่าน spread-stress แทบไม่สะเทือน — finalist ตัวจริง** → Model-0 every-tick กำลังรัน (ด่านสุดท้าย) |
| 2020v2 | PF 2.26→1.23 · DD 6.27%→**65.43%** 💀 + lot-check 3ปี ×14.5 (≥10x) | ❌ **REJECT ถาวร (ฆ่าสองเด้ง)** — edge = spread-dependent + ladder ลึกจริงเมื่อเจอ stress |
| Automated Forex Grail | PF 1.53→**0.62** · net **-9,920** · DD **99.2%** 💀 | ❌ **REJECT ถาวร** — พังยกพอร์ตแค่เจอ spread 3 pips |

**BWD 2020-22 ของกองคืนชีพ + lot-check บน report 3 ปี (ladder ลึกกว่าที่ 4 เดือนเห็นเสมอ):**

| EA | BWD: PF/net/DD | lot 3ปี | Verdict |
|---|---|---|---|
| **Yetti3+NewsSherry** (b22) | 1.25 / +1,953 / 26.3% (12,005 trd) | ×5 | ⏳ **ผ่าน BWD → spread-stress กำลังรัน** (PF บาง + 12k ไม้ = spread ชี้ขาด) |
| **EAForexTH_MultiHedge_1.0** | 1.61 / +1,120 / 20.3% | ×1 แบน | ⏳ **ผ่าน BWD → spread-stress กำลังรัน** |
| **Oracle EA** | 1.90 / +9,988 / 36.1% | ×5.3 (54 entries จาก 1,276 trades — กลไก pending/partial ต้องอ่านถ้ารอด) | ⏳ **ผ่าน BWD → spread-stress กำลังรัน** |
| EAForexTH_Scalper_S3_1.0 | **10.71** / +19,155 / 13.0% (13,190 entries) | ×2 | ⏳ **absurd-PF สองระบอบ = สงสัย tick-model artifact หนัก** → spread-stress กำลังรัน (รอดแล้วต้อง Model-0 ซ้ำ) |
| Expert | 1.11 / +12,904 / 31.6% | ×2 (4→8) | ⏳ ผ่าน BWD เส้นยาแดง (PF 1.11) → spread-stress กำลังรัน (คาดตาย) |
| FZ2 | 3.05 / +9,855 / DD 4.77% (เลขสวยมาก!) | **×18.6** ≥10x | ❌ **AUTO-REJECT** — ladder ลึกจริงบน 3 ปี (4 เดือนเห็นแค่ ×6) · DD 4.77% = recovery ที่"ยังรอด" ไม่ใช่ความเสี่ยงจริง (structural gate 2026-06-23) |
| swb grid | 2.10 / +14,265 / **DD 51.8%** | **×25.9** ≥10x | ❌ **AUTO-REJECT** — grid-trap ยืนยันสองสัญญาณ |
| SUPERTRENDSURFER | 0.96 / -4,711 / DD 87.2% | ×104 | ❌ REJECT ถาวร |
| Envelope 2 | 0.98 / -367 / DD 43.9% | ×2 | ❌ REJECT — regime EA |
| MACrossoverMaster | 0.97 / -2,230 / DD 39.1% | ×1 | ❌ REJECT — regime EA |
| ema_crossmod | 0.56 / -9,705 / DD 98.6% | ×1.5 | ❌ REJECT ถาวร |
| EA SCALP RENKO v2.3 | 0.96 / -9,938 / DD 99.4% | ×1 | ❌ REJECT ถาวร |
| MA_MA_2-35_EA | 0.80 / -3,529 / DD 39.5% | ×1 | ❌ REJECT |
| firebird v63f | 0.87 / -2,339 / DD 29.2% | ×1 | ❌ REJECT |
| Moving Average | 0.81 / -3,057 / DD 41.9% | — | ❌ REJECT |
| 143 E4.7.4 v1 (b23) | 0.85 / -7,810 / **DD 94.4%** | ×9.8 | ❌ **REJECT ถาวร** — PF 3.0 ปี 2023-26 = regime ล้วน (ซ้ำรอย ORDER-037) |
| Phoenix / GBPJPY1H90PCWR / killer_sell / GridMACDM | 0 trades ใน window (USDJPY ทั้งหมด) | — | 🅿️ PARKED-no-data |
| TradePad · VisualMartiEA | TIMEOUT 902s (TradePad โดน 2 ครั้ง) | ×1 / ×5 (4 เดือน) | ⏳ retry 1800s อยู่ใน finalist round |

**Batch-22R re-smoke (7 ตัว zombie-abort):** 0 candidate — LamBow (EU PF 0.3 พัง / JP net $6.75 =
cross-symbol + worthless), KZM Reject, ที่เหลือ 0-trade/skip · AA_Supply Demand = m2-error parse
(duplicate key TP_PIP/TP_pip — จดไว้ ไม่เร่งด่วน)

**Finalist round กำลังรัน (เลน 1, `lane1_finalist_070707.ps1` → `BWDOOS_MT4_FINALIST.csv`):**
UnNomGuai Model-0 · SPR30 ×5 (Yetti3/MultiHedge/Oracle/Scalper_S3/Expert) · retry 1800s ×2
(TradePad/VisualMarti) · **คิวถัดไปหลังจบ: Z61 (b24) BWD EU+JP**

**บทเรียนใหม่:** lot-check ต้องทำซ้ำบน **report ยาวสุดที่มี** — ladder 4 เดือนตื้นกว่า 3 ปีเสมอ
(FZ2 ×6→×18.6 · swb ×2.2→×25.9 · 2020v2 ×5.4→×14.5): ปีเทรนด์บังคับให้ grid โชว์ความลึกจริง

## Triage batch 22 (Claude, 2026-07-07 บ่าย — lot-check ด้วย mt4_lotcheck.ps1 ตัวใหม่)

| EA | สถานะ | เหตุผล |
|---|---|---|
| Perceptrader AI v2.23 1420+_fix · Signalspro007_V12.1_fix · Signalspro007_V5_fix | ❌ DQ | ชื่อ "_fix" = cracked commercial (hard-gate) |
| Scalping XTendFX (EU/JP) | ❌ AUTO-REJECT | lot จริง ×32 / ×256 (0.01→2.56 = martingale doubling) — PF 3.01/5.9 คือ recovery mechanics |
| PumLot V.1.1 exp | 🅿️ PARKED-worthless | PF 1.08, net $44.75 |
| **Yetti3+NewsSherry** | ✅ **คิว BWD** | EU PF 1.51/+700 (2,911 ไม้ = heavy scalper — spread-sensitive ต้องดูด่านหน้า) · JP PF 4.35/+94 · lot ×5 ทั้งคู่ · เพิ่มเข้า targets ของ resurrect sweep แล้ว (2 แถวท้าย) |

## Triage batch 20-21 → BWD-OOS results (Claude, 2026-07-07 บ่าย — `_mt5_auto/BWDOOS_MT4_B2021.csv`)

| EA | BWD 2020-22: PF/trades/net/DD | lot (Size-col จริง) | Verdict |
|---|---|---|---|
| **UnNomGuaiV1.132** | **1.89 / 3,640 / +8,527 / DD 18.74%** | base 0.03 max 0.07 (×2.3) · เปิดพร้อมกันสูงสุด 9 ไม้ | ⏳ **CONDITIONAL — ตัวแรกที่ผ่าน BWD-OOS ตั้งแต่ ClevrFX (batch-01)** — mechanism อ่านจาก params: **grid ตะกร้า** (spaceOrders 1/9/14/99 ชั้น, ladder 0.01→0.03→0.05→0.07, ปิดยกตะกร้าที่กำไร $8, SL=0 ทุกไม้, maximaloss=0) — bounded จริงใน 3 ปี backward + 4 เดือน forward แต่ config เปิดถึง 99 ไม้ = tail-risk เชิงทฤษฎี · avg +$2.3/trade = **spread-sensitive สูง → spread-stress 30pts กำลังรัน (ด่านตัดสิน)** |
| walid Ema (EURUSD) | 0.96 / 956 / -1,486 / DD 35.8% | ×1 แบน | ❌ **REJECT ถาวร** — PF<1 สองระบอบ = เลข 2023-26 เป็น regime ล้วน |
| walid Ema (USDJPY) | 0 trades ใน window | — | ตกตาม EURUSD (EA เดียวกันพิสูจน์แล้วว่าไม่มี edge backward) |
| TradePad_Current_Timeframe | **หลุดจาก sweep รอบเช้า** (โดน interrupt ~12:04 ก่อนถึงคิว — ไม่มีแม้แต่แถว NO_REPORT) | ×1 แบน 0.03 | ⏳ รันใหม่แล้วเป็น step แรกของ `lane1_chain_070707.ps1` |

## Triage + BWD-OOS batch 02-03 (Claude, 2026-07-06 — ย้ายลงมาจากกลางตาราง)

- ❌ **CITY-GOLD HUNTER PROx2_fix = DQ** — "_fix" cracked (hard-gate) + PF 259.99 = absurd artifact สองเด้ง
- **BWD-OOS 2020-22 (สูตร ORDER-040 · script `_mt5_auto\ab_sets\bwdoos_mt4_sweep_b0203.ps1` · ผลดิบ `_mt5_auto\BWDOOS_MT4_B0203.csv`):**

| EA | Sym | 2020-22: PF / trades / net / DD | VERDICT (Claude) |
|---|---|---|---|
| DanceT | EURUSD | 0.09 / 486 / -10,293 / **DD 102.8%** 💀 | ❌ **REJECT ถาวร** — ล้างพอร์ตจริง (1.53 ใน 2023-26 = regime ล้วน) |
| Flexy The Dragon v2.8 | EURUSD | 0.46 / 1448 / -8,748 / **DD 89.2%** | ❌ **REJECT ถาวร** |
| 12431_Happy Fast Money | EURUSD | 0.24 / 485 / -9,890 / **DD 99.1%** | ❌ **REJECT ถาวร** — ยืนยัน tight-TP suspect |
| Happy thaipop | EURUSD | 1.25 / 430 / +2,470 / **DD 73.2%** | 🅿️ **PARKED-resize-first** (PF>1 สองระบอบแต่ edge บาง + DD ทะลุ — กฎ cap-breach ห้าม reject ตรง · priority ต่ำ · unpark ต้องเช็ค trade list ก่อน) |
| CommunityPower 2.58.3 | EURUSD | 1.91 / 1212 / +40,573 / DD 74.1% | ❌ **REJECT-as-configured** — trade list: **martingale ×1.5 ไร้ cap ลึก ~16 ชั้น (0.10→48.6 lots) + SL 0.00000 ทุกไม้** → PF 1.9 สองระบอบ = recovery mechanics ไม่ใช่ edge · DD 74% ปี 20-22 = tail เกิดจริง · precedent GoldStuffV7 · ต่างจาก ClevrFX (internal cut-loss ทำงานจริง) · config capped = EA ใหม่ validate จากศูนย์ได้อนาคต แต่ priority ต่ำ (Boss V2 มี grid มี cage แล้ว) |
| 1 MINUTE SCALPER | USDJPY | 0 trades ใน window | 🅿️ PARKED-no-data (อาจ time-gated — ไม่คุ้มไล่ต่อ) |

**Pattern ยืนยันรอบที่ 3: ฆ่า 5/6 · conditional = 0** (batch-01 เหลือ ClevrFX ตัวเดียวจริงจาก 222 EA)
→ **BWD-OOS 2020-22 + อ่าน trade list (SL + ลำดับ lot) = สอง gate ถูกสุด/เด็ดขาดสุด — ด่านบังคับก่อน
Model-4/spread-stress เสมอ** (spread-stress ทำเฉพาะตัวที่รอดสองด่านแรก)

## Triage batch 05 (Claude, 2026-07-07 — BWD-OOS 2020-22 กำลังรัน, script `bwdoos_mt4_sweep_b05.ps1` → `_mt5_auto/BWDOOS_MT4_B05.csv`)

**⚠️ Pattern ต้องสงสัยก่อนเห็นผล BWD (ประวัติศาสตร์ซ้ำจาก batch-01 "Miracle MT4"):** Tier A ของ batch นี้
มี 5 EA จริง — **4 ใน 5 เป็นตระกูล "SEMIS.jr" ที่ตั้งชื่อตามคู่เงิน (AUDCAD/CHFJPY/GBPJPY/USDJPY)
แต่ broker นี้มีแค่ history EURUSD/USDJPY** → ทั้ง 4 ตัวถูกเทสบน**คู่เงินเดียวกัน**(ไม่ใช่คู่ที่ชื่อบอก)
และให้ **trade count + PF แทบเหมือนกันทุกตัว** (3465/3161, 3518/3184, 3173/2899, 3300/3067 ไม้ ·
PF 2.6-2.83 ทั้งหมด) = สัญญาณเดียวกับ Miracle MT4 (batch-01) ที่งานเดิมเคยตั้งข้อสงสัยว่าเป็น engine
เดียวกันแปะป้ายคนละชื่อ หรือ EA ไม่สนใจ symbol ของ chart เลย (hardcode เหมือน pun fix lot) —
**ห้ามเชื่อ PF จนกว่า BWD-OOS + (ถ้ามี source) เช็คว่า trade คู่เงินตามชื่อจริงไหม**

| EA | ที่ทดสอบ (M1 full 4mo) | trades | PF | net | eqDD |
|---|---|---|---|---|---|
| 2020v2 | EURUSD | 24 | 3.57 | +42 | 0.39% |
| 2020v2 | USDJPY | 42 | 1.68 | +53 | 1.87% |
| 212-SEMIS.jrAUDCAD | EURUSD | 3465 | 2.64 | +9,830 | 17.23% |
| 212-SEMIS.jrAUDCAD | USDJPY | 3161 | 2.82 | +6,886 | 16.57% |
| 213-SEMIS.jrCHFJPY | EURUSD | 3518 | 2.77 | +7,080 | 12.78% |
| 213-SEMIS.jrCHFJPY | USDJPY | 3184 | 2.83 | +4,803 | 12.44% |
| 214-SEMIS.jrGBPJPY | EURUSD | 3173 | 2.68 | +1,677 | 3.03% |
| 214-SEMIS.jrGBPJPY | USDJPY | 2899 | 2.58 | +1,344 | 5.11% |
| 215-SEMIS.jrUSDJPY | EURUSD | 3300 | 2.80 | +6,435 | 11.91% |
| 215-SEMIS.jrUSDJPY | USDJPY | 3067 | 2.78 | +4,985 | 16.51% |

**Verdict (Claude, 2026-07-07 — BWD-OOS `_mt5_auto/BWDOOS_MT4_B05.csv`):**

| EA | 2020-22 PF / trades / net / DD | Verdict |
|---|---|---|
| 2020v2 | 2.26 / 314 / +601 / DD 6.27% (รายงาน) | ~~❌ REJECT~~ → ✅ **กลับ verdict 2026-07-07 (§Lot-check AUDIT): เลข "63.92" คือคอลัมน์ profit ไม่ใช่ lot — Size จริง base 0.1 max 0.54 = ×5.4 เท่านั้น** → คืน candidate, ผ่าน BWD อยู่แล้ว, spread-stress อยู่คิวแรกของ resurrect sweep |
| 212-SEMIS.jrAUDCAD | 0.65 / 4190 / -9,907 / **DD 99.26%** 💀 | ❌ REJECT ถาวร |
| 213-SEMIS.jrCHFJPY | 0.56 / 3962 / -9,593 / **DD 96.53%** 💀 | ❌ REJECT ถาวร |
| 214-SEMIS.jrGBPJPY | 0.05 / 676 / -9,910 / **DD 99.11%** 💀 | ❌ REJECT ถาวร |
| 215-SEMIS.jrUSDJPY | 0.16 / 678 / -9,775 / **DD 97.86%** 💀 | ❌ REJECT ถาวร |

**สงสัยถูกต้องทั้งหมด (SEMIS.jr):** ตายยกกอง (DD 96-99%) ยืนยัน artifact/engine เดียวกันตามคาด

**🔬 mechanism-check 2020v2 (Claude, 2026-07-07 — ทำตามบทเรียน CommunityPower: อ่าน trade list
ก่อนเชื่อเลขสวย เสมอ):** report บอก "DD 6.27%" ($638) แต่ trade list เผย **lot escalation ถึง
63.92 lots จาก base 0.10 (ผ่านขั้น 0.14→0.20→0.27→...→22→31.8→**63.92**)** — นี่คือ exposure
ระดับล้างพอร์ตถ้า sequence ไม่กลับตัวทันเวลา (base 0.10 lot → 63.92 lots = คูณ ~640 เท่า) ·
**"DD 6.27%" ที่ tester รายงานไม่สะท้อนความเสี่ยงจริง** เพราะวัดที่จุดปิด ไม่ใช่ตอน exposure พีค —
เข้าเกณฑ์ structural gate เดียวกับ CommunityPower/GoldStuffV7 (decision 2026-06-23: กลไก
uncapped martingale/grid = ปฏิเสธเชิงโครงสร้าง ไม่ใช่เรื่อง sizing) · **VERDICT แก้เป็น ❌ REJECT**
— resize ไม่ช่วยเพราะ risk อยู่ที่ตัวคูณ ไม่ใช่ lot ตั้งต้น
**ผล batch 05 สุดท้าย: 0/5 survivor** (ตกทุกตัวหลัง mechanism-check ครบ — บทเรียนซ้ำเป็นครั้งที่ 3:
เลข PF/DD สวยจาก tester โกหกได้เสมอถ้าไม่อ่าน trade list ประกอบ)
**⚠️ CORRECTION 2026-07-07 (§Lot-check AUDIT):** mechanism-check ของ 2020v2 ข้างบน**อ่านคอลัมน์ผิด** —
ลำดับ "0.14→...→63.92" คือค่า **profit** ไม่ใช่ lot (Size จริง ×5.4) → 2020v2 คืนสถานะ candidate ·
SEMIS.jr 4 ตัวตายด้วย BWD DD 96-99% เอง verdict ไม่เปลี่ยน → **batch 05 แก้เป็น 1 pending (2020v2)**

## Triage batch 10 (Claude, 2026-07-07 — auto-flag rule จับผลได้ทันทีคืนแรกที่ใช้จริง 2/2)

BWD-OOS (`_mt5_auto/BWDOOS_MT4_B10.csv`) + full-file lot-escalation check ตาม spec ที่ harden ไว้:

| EA | BWD 2020-22: PF/trades/DD | max lot ÷ base | Verdict |
|---|---|---|---|
| AF-Global Expert Unlimited | 1.57 / 14,591 / DD 48.76% | **0.01 → 94.86 = ×9,486** | ❌ **AUTO-REJECT** (≥10x) — grid/martingale ลึกมาก, DD จริงยืนยันตรงกับ escalation |
| Automated Forex Grail | 1.53 / 1,063 / DD 33.02% | ~~1 → 99.04 = ×99~~ **Size จริง ×1 แบน (99.04 คือ profit cell)** | ~~❌ AUTO-REJECT~~ → ✅ **กลับ verdict 2026-07-07 (§Lot-check AUDIT)** — ผ่าน BWD อยู่แล้ว (PF 1.53 สองระบอบ, DD 33% < gate 40%) → spread-stress คิวแรกของ resurrect sweep |
| BB SWING | USDJPY 0 เทรดใน window 2020-22 | n/a | 🅿️ PARKED-no-data (ตัดสินไม่ได้) |

**ผล batch 10 สุดท้าย: 0/3 survivor** — auto-flag rule (เพิ่งเขียนคืนนี้หลัง 2020v2) ทำงานตามที่ออกแบบ
ทันที: ทั้งสองตัวมี DD ที่ BWD รายงานสูงอยู่แล้ว (33-49%) ซึ่ง**สอดคล้อง**กับ escalation จริง
(ต่างจาก 2020v2 ที่ DD รายงานต่ำหลอกไว้) — แปลว่า BWD-OOS window ยาวพอที่จะเริ่มเผย DD จริงได้เอง
บางส่วน แต่ lot-check ยังจำเป็นเพื่อยืนยันสาเหตุและปิดไม่ให้เถียงว่า "แค่โชคร้าย"

## Triage batch 11 (Claude, 2026-07-07 — ตัดสินได้จากตาราง smoke เดิม ไม่ต้องรัน BWD-OOS เพิ่ม)

| EA | EURUSD | USDJPY | Verdict |
|---|---|---|---|
| Blessing 3 v3.9.6.09 | PF 0.75 / -524 / **DD 31.52%** (Reject) | PF **67.82** / 25 เทรด / DD 0.72% (Tier A) | ❌ **REJECT** — **EA ตัวเดียวกันพังใน EURUSD แต่ "ชนะสวย" ใน USDJPY ด้วยตัวอย่างแค่ 25 เทรด** = thin-sample artifact + regime-lucky ไม่ใช่ edge (PF 67.82 คือค่าที่เป็นไปไม่ได้ในทางสถิติสำหรับกลไกทั่วไป — สัญญาณเดียวกับ Elephant/IR Whale ที่เจอมาก่อน) |
| cci ma ea | PF 1.14 / +2,061 / DD 23.78% (Tier A, edge บาง) | PF 0.70 / **-5,285** / **DD 59.83%** (Reject, พังหนัก) | ❌ **REJECT** — EA เดียวกันระเบิดคนละคู่เงิน = regime-dependent ไม่ใช่ edge จริง (pattern เดียวกับ GBPAUD/EURCAD ที่ parked ไปแล้ว) |
| Daily breakout16 | — | PF 1.01 / net **+$2.28** เท่านั้น / DD 0.58% | 🅿️ **PARKED-worthless** — เหนือ PF 1 จริงแต่ net ใกล้ศูนย์เกินกว่าจะมีความหมายทางเศรษฐศาสตร์ ไม่คุ้มเสียแรง BWD |

**หลักการใหม่ที่ยืนยันจากรอบนี้:** ก่อนเสีย compute กับ BWD-OOS ให้เทียบผลข้าม symbol ของ EA
เดียวกันในตาราง smoke ก่อนเสมอ — ถ้าคู่เงินหนึ่งพังหนักอีกคู่ "ชนะสวยเกินจริง" = ปิดเคสได้ทันที
ไม่ต้องรอ BWD (ประหยัดเวลา 3-4 นาที/ตัวคืนนี้ ~10 นาที)

## Triage batch 12 (Claude, 2026-07-07 — บทเรียนใหญ่สุดของคืนนี้: lot-check ฟรีจาก M1 smoke report เดิม ฆ่าได้ทั้ง batch โดยไม่ต้องรัน BWD-OOS สักตัวเดียว)

**การค้นพบ:** 20 แถว Tier A = 11 EA จริง ลองรัน `class=mspt` grep บน M1 report ที่มีอยู่แล้ว (จาก
สมูกตอน 4 เดือนแรก — **ฟรี ไม่ต้องรอผลอะไร**) ก่อนคิดจะรัน BWD-OOS:

| EA | max lot ÷ base | Verdict |
|---|---|---|
| EAForexTH_Fibo v1.0_EU_M1 | 0.01→13.23 = **×1,323** | ❌ AUTO-REJECT |
| EA - Budak Ubat v1.51 | 0.01→67.8 = **×6,780** | ❌ AUTO-REJECT |
| EAForexTH_MultiHedge_1.0 | 0.01→15.14 = **×1,514** | ❌ AUTO-REJECT (ชื่อ "Hedge" ก็เป็นเช่นนั้นจริง) |
| EA-Martin | 0.01→87.89 = **×8,789** | ❌ AUTO-REJECT (ชื่อ "Martin"=Martingale ตรงเป๊ะ) |
| EA SCALP RENKO v2.3 | 0.1→29.3 = **×293** | ❌ AUTO-REJECT |
| EAForexTH_Scalper_S3_1.0 | 0.22→42.02 = **×191** | ❌ AUTO-REJECT (PF 64.66 ก็ absurd อยู่แล้วด้วย) |
| Envelope 2 | 0.2→78.44 = **×392** | ❌ AUTO-REJECT |
| EAForexTH_CrawlingGrid_2.2 | 0.01→83.81 = **×8,381** | ❌ AUTO-REJECT (ชื่อ "Grid" ก็เป็นเช่นนั้นจริง) |
| ema_crossmod | 2→99 = **×49.5** | ❌ AUTO-REJECT |
| Expert | 4→96 = **×24** | ❌ AUTO-REJECT (PF อ่อนอยู่แล้วด้วย 1.11-1.26) |
| EMA_Cross | (ไม่เช็ค) | 🅿️ PARKED-worthless — PF 1.02 เท่านั้น ไม่มีความหมายทางเศรษฐศาสตร์ |
| EA_Easy2Gain_Gemini_3ex | (ไม่เช็ค) | 🅿️ PARKED-thin — 43 เทรดเดียว 1 symbol ข้อมูลไม่พอ |

**ผล batch 12 สุดท้าย: 0/11 survivor — ตายสนิททั้งกอง โดยไม่เสีย BWD-OOS แม้แต่รันเดียว**
(ประหยัด compute ~10 รัน เทียบกับ batch 10 ที่ต้องรอ BWD ก่อนถึงจะรู้)

**🔧 แก้ spec ถาวร (สำคัญที่สุดของคืนนี้):** สลับลำดับ — **lot-check จาก M1 smoke report เดิม (ฟรี,
มีอยู่แล้ว) ต้องทำ "ก่อน" ส่ง BWD-OOS เสมอ ไม่ใช่หลัง** เดิม spec ให้ BWD-OOS ก่อนแล้วค่อย
lot-check EA ที่ผ่าน — กลับด้านสิ้นเปลือง ดู stage-2 spec ที่แก้ด้านล่าง

## Triage batch 18+19 (Claude, 2026-07-07)

**Batch 18:**

| EA | max lot ÷ base | Verdict |
|---|---|---|
| rbt (EURUSD/USDJPY) | ×6,048 / ×747 | ❌ AUTO-REJECT |
| Scalping Strategy System V2.0 (EURUSD/USDJPY) | ×3,945 / ×2,022 | ❌ AUTO-REJECT |
| Simple2020 / Simple_Inverse2020 | ×222 (ตัวเลขเหมือนกันเป๊ะทั้งคู่ — engine เดียวกันสลับทิศ) | ❌ AUTO-REJECT ทั้งคู่ |
| Simple ZigZag EA+martingale | (ไม่เช็ค) | 🅿️ PARKED — ชื่อ "martingale" ตรงตัว + thin 27 เทรด |
| RANGER M5 / Rebate Maker EA / SmartForex_V6 (Tier B) | (ไม่เช็ค) | ❌ REJECT — DD 47-67% อยู่แล้วจาก smoke gate (Rebate Maker = 40,793 เทรดใน 4 เดือน = HFT ผิดปกติ) |

**Batch 19:**

| EA | max lot ÷ base | Verdict |
|---|---|---|
| rbt/STARTUP FOREX ROBOT (EURUSD/USDJPY) | ×1,249 / ×720 | ❌ AUTO-REJECT |
| SUPERTRENDSURFER | ×3,055 | ❌ AUTO-REJECT |
| swb grid (EURUSD/USDJPY) | ×3,026 / ×1,523 | ❌ AUTO-REJECT (ชื่อ "grid" ก็เป็นเช่นนั้นจริง) |
| SuperWinForexThai | (ไม่เช็ค) | 🅿️ PARKED-worthless — net $7.88/20 เทรด |

**ผล batch 18+19: 0/5 + 0/4 survivor — batch ที่ 8 และ 9 ติดกัน (11-19) ปิดจบไม่ต้องรัน BWD-OOS**

## Triage batch 17 (Claude, 2026-07-07)

| EA | max lot ÷ base | Verdict |
|---|---|---|
| Oracle EA | ×2,691 | ❌ AUTO-REJECT |
| Phoenix_EA_v5_6_03 | ×717 | ❌ AUTO-REJECT |
| No Sleep EA (Tier B) | (ไม่เช็ค) | ❌ REJECT — DD 43.42% อยู่แล้วจาก smoke gate + ชื่อ "No Sleep" บอกกลไกตรงตัว (เทรดตลอดไม่พัก = ไม่มีการป้องกัน) |

**ผล batch 17 สุดท้าย: 0/2 survivor — batch ที่ 7 ติดกัน (11-17) ปิดจบไม่ต้องรัน BWD-OOS**

## Triage batch 16 (Claude, 2026-07-07)

| EA | max lot ÷ base | Verdict |
|---|---|---|
| MACD Sample | (ไม่เช็ค) | 🅿️ PARKED-worthless — net $23.55/70 เทรด ใกล้ศูนย์ |
| MARTINGALE VI HYBRID1 | (ไม่เช็ค) | 🅿️ PARKED-worthless — net $3.4/455 เทรด = ศูนย์เศรษฐศาสตร์ (ชื่อ Martingale ก็ตรงอยู่แล้ว) |
| MACrossoverMaster (EURUSD/USDJPY) | ×1,631 / ×1,104 | ❌ AUTO-REJECT |
| Mm2019 (EURUSD/USDJPY) | ×3,408 / ×4,663 | ❌ AUTO-REJECT |
| Moving Average | ×1,434 | ❌ AUTO-REJECT |

**ผล batch 16 สุดท้าย: 0/5 survivor — batch ที่ 6 ติดกัน (11,12,13,14,15,16) ปิดจบไม่ต้องรัน BWD-OOS**

## Triage batch 14 (Claude, 2026-07-07)

| EA | max lot ÷ base | Verdict |
|---|---|---|
| GoldenProfit_AUTO | ×19,149 | ❌ AUTO-REJECT |
| HedgeMadnessSELL (EURUSD/USDJPY) | ×25,600 / ×32,321 | ❌ AUTO-REJECT (ชื่อ "Hedge...Madness" ก็เป็นเช่นนั้นจริง) |
| GridMACDMEURUSD | ×657 | ❌ AUTO-REJECT |
| GridMaster_fixed (EURUSD/USDJPY) | ×4,333 / ×4,880 | ❌ AUTO-REJECT (ชื่อ "Grid" ก็เป็นเช่นนั้นจริง) |
| Hendra Robot | (ไม่เช็ค) | 🅿️ PARKED-thin — 10 เทรด M2 เท่านั้น 1 symbol |

**ผล batch 14 สุดท้าย: 0/5 survivor — batch ที่ 5 ติดกัน (11,12,13,14,15) ปิดจบไม่ต้องรัน BWD-OOS**

## Triage batch 15 (Claude, 2026-07-07)

| EA | max lot ÷ base | Verdict |
|---|---|---|
| Ilan__Z-Mod (EURUSD/USDJPY) | ×4,200 / ×6,576 | ❌ AUTO-REJECT — ชื่อ "Ilan" = grid/martingale ชื่อดังในวงการ retail EA |
| Ilan_test (EURUSD/USDJPY) | ×3,408 / ×4,663 | ❌ AUTO-REJECT (ตระกูลเดียวกับ Ilan__Z-Mod) |
| Lenhune Forward For free V2 (EURUSD/USDJPY) | ×10,244 / ×2,315 | ❌ AUTO-REJECT |
| MA_MA_2-35_EA | ×1,518 | ❌ AUTO-REJECT |
| killer_sell | ×1,551 | ❌ AUTO-REJECT |

**ผล batch 15 สุดท้าย: 0/5 survivor — batch ที่ 4 ติดกัน (11,12,13,15) ปิดจบไม่ต้องรัน BWD-OOS**
**หมายเหตุ tooling:** เจอ bug เล็ก `parse_mt4_report.py` — `UnicodeEncodeError` (cp1252) เมื่อ report
มีตัวอักษรพิเศษ (เช่น GOLD999J ใน batch 14) → parse fail 1-2 EA/batch เป็นบางครั้ง ไม่กระทบ batch
โดยรวม (แค่ EA นั้นไม่มี m1_pf ใน CSV) — ควรแก้ `encoding='utf-8'` ตอน print/write ในอนาคต (ไม่เร่งด่วน)

## Triage batch 13 (Claude, 2026-07-07 — batch ที่ 3 ติดกัน (11,12,13) ที่ปิดจบได้โดยไม่ต้องรัน BWD-OOS)

| EA | max lot ÷ base | Verdict |
|---|---|---|
| FoldXEA (EURUSD) | 0.01→387.5 = **×38,750** | ❌ AUTO-REJECT (แถมเป็น Tier B อยู่แล้วจาก DD 40.19%) |
| FoldXEA (USDJPY) | 0.01→190.29 = **×19,029** | ❌ AUTO-REJECT |
| Fxs (EURUSD) | 0.1→420 = **×4,200** | ❌ AUTO-REJECT |
| Fxs (USDJPY) | 0.1→471.23 = **×4,712** | ❌ AUTO-REJECT (Tier B, DD 43.97%) |
| FZ2 (EURUSD/USDJPY) | 0.02→78/44 = **×3,901 / ×2,207** | ❌ AUTO-REJECT ทั้งคู่ |
| GBPJPY1H90PCWR | 1→977.41 = **×977** | ❌ AUTO-REJECT (net $71,152 จาก 187 เทรดก็ absurd อยู่แล้วโดยตัวมันเอง) |
| gods gift ea v 4c | 0.1→10.3 = **×103** | ❌ AUTO-REJECT |
| firebird v63f | 0.1→3.3 = **×33** | ❌ AUTO-REJECT (ตัวที่ดูเบาที่สุด PF1.15 ก็ยังเกิน 10x) |

**ผล batch 13 สุดท้าย: 0/6 survivor — ไม่ต้องรัน BWD-OOS แม้แต่ตัวเดียว (batch ที่ 3 ติดกัน)**
สังเกต: FoldXEA/Fxs เป็นตัวอย่างที่ระบบ Tier A/Tier B (จาก DD gate เดิม) **จับสัญญาณเดียวกันได้แล้ว
ตั้งแต่ตอน smoke** (symbol หนึ่ง DD ต่ำ Tier A, อีก symbol DD พุ่ง 40-44% Tier B) — lot-check แค่ยืนยัน
สาเหตุ ไม่ใช่ผู้ค้นพบคนแรก คราวนี้

## 🛡️ Indicator precheck (เพิ่ม 2026-07-06 ดึก — แก้อาการค้างที่ user เจอ: EA เรียก indicator ที่ไม่มี → journal spam "cannot open file ...\indicators\..." ค้างเป็นชั่วโมง)

แก้ 2 ชั้นใน script กลาง (ทุก batch ต่อจากนี้ได้ผลอัตโนมัติ — อย่า workaround เอง):
1. **`mt4_run.ps1`:** timeout → **kill process ทิ้งเสมอ** (เดิมปล่อยค้าง — gotcha ที่จดใน memory ตั้งแต่ 06-30 เพิ่งแก้จริง)
2. **`mass_smoke_mt4.ps1`:**
   - precheck static: path/ชื่อเป็น indicator (`\indicators\`, "indicator", "no repaint arrow") → note `precheck-indicator-file` ข้ามทันที ฟรี
   - precheck dynamic: รันแรกไม่มี report → สแกน tester+terminal journal → เจอ `cannot open file ...\MQL4\indicators\X` → note `missing-indicator: <รายชื่อ>` + **ข้าม symbol ที่เหลือของ EA นั้นทั้งหมด** (ไม่เผา timeout ×4) · เจอ invalid ex4 → `not-an-ea-or-invalid`
   - EA ที่ note = `missing-indicator` ไม่ใช่ REJECT — เป็น **INCOMPLETE-package** (อนาคตถ้าอยากฟื้นตัวไหน หา indicator ในโฟลเดอร์ต้นทางมาลง `MQL4\indicators` แล้วรันใหม่ได้)

## 🆕 Stage-2 spec ต่อ batch (เพิ่ม 2026-07-06 ค่ำ — ให้ agent ทำเองได้ถึงหลักฐานดิบครบ ไม่ต้องรอ Claude คั่นกลาง)

หลังจบ smoke ของ batch ใดๆ ให้ agent ทำต่อทันทีในคำสั่งเดียวกัน (ยังห้าม verdict เหมือนเดิม) —
**ลำดับสลับแล้ว (2026-07-07 ดึก, บทเรียน batch 12: lot-check ฟรีต้องทำก่อน BWD เสมอ ไม่ใช่หลัง):**
1. **กรอง DQ ชื่อไฟล์:** `_fix|_nodll|crack` → mark DQ ใน CSV (คอลัมน์ note) ไม่ต้องรันต่อ
2. **Lot-escalation check ฟรี (ทำก่อน BWD เสมอ)** — ทุก Tier A ที่เหลือ มี M1 report จากสมูก 4 เดือน
   อยู่แล้วในมือ (ไม่ต้องรันอะไรเพิ่ม): **ใช้ `scripts/mt4_lotcheck.ps1` เท่านั้น** (อ่านคอลัมน์ Size
   ของแถว entry buy/sell เท่านั้น) · **auto-flag: max÷base ≥10x → REJECT ทันที ไม่ต้องรอ Claude
   ไม่ต้องรอ BWD** · ⚠️ **ห้ามใช้ quick-grep `class=mspt>(\d+\.\d\d)` เด็ดขาด (บั๊ก 2026-07-07:
   regex นั้น match คอลัมน์ Profit/Balance ปนมาด้วย → เป่าค่า max 100-1000 เท่า สร้าง false
   AUTO-REJECT ~15 ตัวใน batch 10-19 — ดู §Lot-check AUDIT)** — ชื่อ "Grid/Hedge/Martin/Martingale"
   ในชื่อ EA = สัญญาณให้สงสัย แต่ตัดสินจาก Size จริงเท่านั้น (VisualMartiEA ชื่อ Marti แต่ ladder จริง ×5)
3. **BWD-OOS 2020-22 เฉพาะตัวที่ผ่าน lot-check** (max÷base <10x): ใช้ pattern
   `bwdoos_mt4_sweep_b0203.ps1` (copy → แก้ targets จาก CSV ของ batch ตัวเอง) →
   append ผลลง `_mt5_auto/BWDOOS_MT4_B<NN>.csv`
4. **Trade-list SL check** เฉพาะตัวที่ผ่านทั้ง lot-check + BWD: SL เป็น 0.00000 ทุกไม้ไหม (ไม่ auto-fail
   แต่จดไว้ — no-SL ที่ lot ไม่ escalate ยังมีความเสี่ยง tail แบบ pun fix lot ต้องดู regime เพิ่ม)
5. **Cross-symbol sanity check ฟรีอีกชั้น** (ทำคู่ข้อ 2 ได้เลย): ถ้า EA เดียวกันมีทั้ง symbol ที่ตกหนัก
   (PF<0.8) และ symbol ที่ "ชนะสวยเกินจริง" (PF>10 ที่ trades<50) = REJECT ทันที (regime-lucky/thin-sample,
   บทเรียน batch-11: Blessing 3, cci ma ea) — ไม่ต้องรอ BWD เช่นกัน
6. append ทั้งหมดใต้แถว batch ในไฟล์นี้ · commit เดียว `[tag] ORDER-036 batch NN + stage2 done`
**Claude เหลือแค่:** อ่านตาราง → verdict — ลำดับใหม่นี้ทำให้หลาย batch (เช่น 11, 12) ปิดจบได้โดย
**ไม่ต้องรัน BWD-OOS เลยสักครั้ง** ประหยัด compute มหาศาลเทียบกับลำดับเดิม

## Archive protocol
batch ที่ Claude review แล้ว: (1) แถวตารางข้างบนเปลี่ยนเป็น `ARCHIVED` (2) ผลดิบ/รายละเอียดย้ายไป
`_archive/ORDER-036_ARCHIVE.md` (3) survivor Tier A/B เข้า scorecard §MT5 MASS-SMOKE ตาม funnel ปกติ
