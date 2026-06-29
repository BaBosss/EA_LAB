# DEPLOY CHECKLIST — จันทร์ 2026-06-29

> เป้าหมายวันนี้: ทำพอร์ต demo ให้ครบ **9 EA** ด้วย 3 จังหวะใน MT5 GUI (~15 นาที).
> ทุกอย่าง bundle staged + verified แล้ว. **ไม่ต้องรัน automation** — งานนี้คือ GUI ล้วน.
> ทำเสร็จ → ติ๊ก [x] + อัปเดต `PROJECT_STATE.md` section 4 (สถานะ 🟡 → 🟢) + commit git.

## ก่อนเริ่ม (pre-flight)
- [ ] MT5 ที่จะ deploy = **DEMO account 10,000 cent** (เลขเดียวกับที่ deploy 2026-06-22) — เช็คมุมขวาบน
- [ ] เปิด **AutoTrading** (ปุ่มเขียวบน toolbar) = ON
- [ ] Options → Expert Advisors → ☑ Allow Algo Trading, ☑ Allow DLL (ถ้า EA ต้องการ)
- [ ] เปิด tab **Toolbox → Experts** ไว้ดู log ตอน attach (ดูว่า EA init ผ่าน + magic ถูก)

---

## จังหวะ 1 — RELOAD EA #6 เป็น v3 (XAUUSD H1, Bars55)
> นี่คือ **upgrade ของเดิม** ไม่ใช่ EA ใหม่. EA_BREAKOUT_XAU ตัวที่รันอยู่ → เปลี่ยน .set เป็น v3.

- [ ] ไปที่ชาร์ต **XAUUSD H1** ที่ EA_BREAKOUT_XAU (magic 991001) รันอยู่
- [ ] กด **F7** (เปิด properties ของ EA ตัวนั้น) → tab Inputs → ปุ่ม **Load**
- [ ] เลือกไฟล์: `D:\EA_LAB\_vps_deploy\BRK_XAU_live_v3.set`
- [ ] ตรวจค่าหลังโหลด: `_01_BreakoutBars=55` · `_02_TpAtrMult=8.0` · `_04_EmaPeriod=150` · `_06_Magic=991001`
- [ ] กด **OK** → ดู Experts log ว่า re-init ผ่าน, magic ยัง 991001
- [ ] ✅ เสร็จ: EA #6 = Bars55 plateau-center (v3)

⚠️ recompile/re-attach EA จะ reset state — ถ้ามี position เปิดอยู่ของ 991001 ให้รู้ว่าจะถูก
จัดการตาม logic ใหม่ (ปกติ breakout EA ไม่มี pyramid ค้าง = ปลอดภัย).

---

## จังหวะ 2 — DEPLOY ST03 REPLICA (EA_RUNNER_ST03, GBPUSD H1, magic 990010)
> framework runner ที่ replica ST_EA03. **คนละ magic จาก ST_EA03 live (#3=9397)** → coexist ได้.

- [ ] เปิดชาร์ตใหม่ **GBPUSD H1** (File → New Chart → GBPUSD → ลาก timeframe H1)
- [ ] Navigator → Expert Advisors → หา **`EA_RUNNER_ST03`** → ลากลงชาร์ต GBPUSD H1
- [ ] ใน dialog → tab Inputs → **Load** → `D:\EA_LAB\_vps_deploy\ST03_GBPUSD\ST03_GBPUSD_live_v1.set`
- [ ] ตรวจค่า: `InpMagic=990010` · `InpAllowLiveOrders=true` (ถ้า false = EA จะไม่ส่งออเดอร์จริง!)
- [ ] กด **OK** → ดู Experts log: init ผ่าน, "AllowLiveOrders=true", magic 990010
- [ ] ✅ เสร็จ: หน้ายิ้ม 🙂 มุมขวาบนชาร์ต = EA ทำงาน

> ⚠️ **baseline OOS 3.93 = PROVISIONAL.** executor-sibling (ST03B pyramid) overfit → ก่อนใช้ 3.93 เป็น
> เกณฑ์ judge ให้ **re-run OOS ด้วย locked .set ยืนยันก่อน** (งานนี้อยู่ใน `EA_CORE_ST03_LOOP_PLAN.md`).
> deploy ลง **DEMO** ได้เลย — demo 3 เดือนมีไว้จับ overfit แบบนี้พอดี.

⚠️ ถ้า EA_RUNNER_ST03 ไม่อยู่ใน Navigator = ยังไม่ได้ compile/copy .ex5 ไป Experts folder.
แก้: compile จาก `D:\EA_Project\CURRENT_BUILD\...EA_RUNNER_ST03.mq5` แล้ว copy .ex5 เข้า
`<MT5 DataDir>\MQL5\Experts\` → refresh Navigator. (ใช้ skill `vps-deploy-ops` ช่วยได้.)

---

## จังหวะ 3 — DEPLOY BARS8 ADDITIVE (EA_BREAKOUT_XAU, XAUUSD H1, magic 991002)
> variant ของ #6 (Bars8 แทน Bars55), corr 0.21 = additive. **ชาร์ตเดียวกับ #6 ได้** เพราะคนละ magic.

- [ ] ไปที่ชาร์ต **XAUUSD H1** (จะใช้ชาร์ตเดิมของ #6 หรือเปิดใหม่ก็ได้)
- [ ] Navigator → ลาก **`EA_BREAKOUT_XAU`** ลงชาร์ต **อีกหนึ่งตัว** (จะมี 2 instance บน XAUUSD H1)
- [ ] tab Inputs → **Load** → `D:\EA_LAB\_vps_deploy\BRK_XAU_Bars8\BRKXAUH4_Bars8_demo_v1.set`
- [ ] ตรวจค่า: `_01_BreakoutBars=8` · `_06_Magic=991002` (**ต้องไม่ใช่ 991001** ไม่งั้นชนกับ #6)
- [ ] กด **OK** → Experts log: init ผ่าน, magic 991002
- [ ] ✅ เสร็จ: XAUUSD H1 มี 2 EA (991001 Bars55 + 991002 Bars8) coexist

⚠️ MT5 อนุญาต EA หลายตัวบนชาร์ตเดียวได้ (แต่ละ instance แยกกัน). ยืนยันว่ามี **2 หน้ายิ้ม** หรือเช็ค
Experts log เห็น init ทั้ง 991001 + 991002.

---

## หลัง deploy (verify + บันทึก)
- [ ] เปิด tab **Trade** — ดูว่าไม่มี error "AutoTrading disabled / invalid lots / no money"
- [ ] เช็ค magic ไม่ชนกัน: MG_v1(GUI default) · 1524 · 9397 · 9398 · GoldReaper(GUI default) · 990005 · 990010 · 991001 · 991002
      — **MG_v1 + GoldReaper magic ไม่อยู่ใน .set (อ่าน/ดูจาก GUI)**; ถ้าทั้งคู่ = 0 แต่คนละ symbol ยัง attribute ได้ด้วย (magic,symbol)
- [ ] ปล่อยรัน 1–2 วัน แล้ว export `live_deals.csv` (ดู PROJECT_STATE section 6) เช็คว่า EA ใหม่เริ่มมี deal
- [ ] อัปเดต `DEMO_DEPLOYMENT_PLAN.md` + `PROJECT_STATE.md`: #6 🟡→🟢, #9 🟡→🟢, #10 🟡→🟢
- [ ] `git add -A && git commit` — "deploy(demo): ST03 replica + Bars8 + reload #6 v3 → 9 EA live 2026-06-29"

## ถ้าพลาด / EA ไม่เทรด (silent-stop checklist)
1. AutoTrading ปุ่มเขียว ON? · 2. `AllowLiveOrders/InpDryRun` ถูกต้อง? · 3. magic ชนไหม? ·
4. lot ต่ำกว่า min ของ broker? (cent account → เช็ค min lot) · 5. symbol ตรง (XAUUSD vs GOLD)? ·
6. session/time filter ปิดอยู่ไหม? · 7. Experts log มี error อะไร? → ใช้ skill `vps-deploy-ops`
   section "silent-stop danger checklist".
