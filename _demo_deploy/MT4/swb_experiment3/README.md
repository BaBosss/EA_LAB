# MT4 demo experiment #3 — swb grid 4.1.0.3_h flat-lot @ AUDCAD (user อนุมัติ 2026-07-10)

> **ที่มา:** survivor จาก ORDER-036 mass smoke (1,318 EA) → ฟื้นใน ORDER-046/047 ด้วย
> `lot_multiplier=0` (ปิด geometric ladder) + ย้าย symbol → **AUDCAD H1** ·
> หลักฐาน: `EA_SCORECARD_AND_REGISTRY.md` §ORDER-036 survivors + `AGENT_TASKBOARD.md` ORDER-047 verdict

---

## Bundle (โฟลเดอร์นี้ = ครบชุด attach)

| ไฟล์ | หน้าที่ |
|---|---|
| `swb grid 4.1.0.3_h.ex4` | EA compiled (กลไกดำ no source) — **copy ตรงจาก validated binary, MD5 ตรง lock เดิมใน `_demo_deploy\README_DEPLOY.md`** |
| `swb_AUDCAD_demo.set` | locked set — `lot_multiplier=false` + `lot_multiplier_2=1` (= flat-lot config ที่ validate) + `magic=990` (ตัวเดียวที่แก้จาก default ได้ เพราะ magic=1 เดิมชน UnNomGuai — ไม่ใช่ validated param) · **input อื่นทั้งหมด = compiled defaults** (chain ORDER-046/047 รันด้วย `swb_flat.set` ซึ่ง override แค่ 2 ค่า lot นี้ — ค่า default เต็มชุดที่พิสูจน์แล้วดูได้ใน `_mt4_auto\reports\O47P3_swb_AUDCAD_M0.htm` บรรทัด Parameters เช่น start_lot=0.1, range=25, level=10, increament=0.1, BB20/Stoch5,3,3/RSI12) |
| `MD5SUMS.txt` | binary lock ทั้งสองไฟล์ |

## Attach (user บนบัญชี demo MT4 **69424711**)

1. ก็อป `.ex4` → `MQL4\Experts\` ของ terminal 69424711 → refresh Navigator
2. Chart **AUDCAD H1** → ลาก EA ลง → Common tab ✅ Allow live trading → Inputs tab: **Load `swb_AUDCAD_demo.set`** → OK
3. AutoTrading เขียว · Save Profile · เช็ค magic ไม่ชนตัวอื่นในบัญชี (990 — distinct จาก UnNomGuai 1/2 · RSI-orig 5888 ✓)
4. **จดวันที่ attach → แจ้ง Claude = demo-clock เริ่ม**

## ค่าอ้างอิงที่พิสูจน์แล้ว (ใช้เทียบตอน monitor/judge)

| ด่าน | ผล |
|---|---|
| BWD 2020-22 M1 | PF 2.40 / DD 8.6% |
| SPR30 (spread 30pts) | PF 2.23 / DD 9.0% |
| **Model-0 (every tick, ref หลัก)** | **PF 1.80 / net +5,083 / DD 20.44% / 1,253 trades (~35 ไม้/เดือน) / win 76%** |
| Ladder จริง | linear add (increament=0.1, ×3-4 บนตะกร้าปกติ, พีค 0.8 lot ใน backtest) — **ไม่ใช่ martingale geometric** |

## 🔴 Kill-switch (เช็คทุกสัปดาห์)

- **Kill: equity DD แตะ 30%** (Model-0 อ้างอิง 20.4% — เกิน buffer นี้ = พฤติกรรมนอก backtest, detach ทันที)
- **Kill: ladder ทะลุ 1.0 lot/ไม้** @ AUDCAD (backtest ไม่เคยเกิน 0.8)
- เตือน (จับตาเข้ม): DD แตะ 25% หรือ net ลบต่อเนื่อง 6 สัปดาห์

## ⚠️ กติกาเหล็ก

- **ห้ามแก้ input ใดๆ นอกจาก set นี้** — validate ที่ค่านี้ แก้ = โมฆะ
- **no hard SL ทุกไม้** (use_sl_and_tp=false) → terminal/VPS **ต้องออนไลน์ตลอด** (หลุด = ไม้เปลือย)
- **AUDCAD-only** — swb เป็น symbol-specific: EURUSD (M0 DD 42%) / XAUUSD (SPR30 0.35) = REJECT แล้ว ห้ามย้ายคู่
- ห้าม attach เพิ่มบัญชีอื่น/เพิ่ม lot ก่อน judge

## 📊 Judge & สถานะเชิงปรัชญา

- **Judge: วันที่ attach + 3 เดือน** · ≥30 trades · PF live ≥1.4 + DD ไม่แตะเตือน + พฤติกรรมตรง backtest → ค่อยคุยขั้น live (lot เล็ก)
- **สถานะ = bench tier 5-6** ตามหลัก best-available-tier (`VISION.md`): ไม่ใช่ขยะ แต่ยังไม่ใช่ core —
  นั่งม้านั่งจนกว่าจะพิสูจน์ตัวหรือมีตัวดีกว่ามาแทน
- **ถ้าไปต่อขั้น live = เข้ากรง premium-track 3 ชั้นของ `VISION.md`**: (1) บัญชี cent แยก equity เด็ดขาด
  ห้ามปนพอร์ต edge (2) นับว่า "รอด" เมื่อถอนคืนเงินฝากครบแล้วเท่านั้น (3) พอร์ตแตะเกณฑ์ตาย =
  ปล่อยตาย **ห้ามเติมเงิน ห้ามกู้**

## Binary lock (MD5)

```
35BFB25E93966DE1A9521A4A59313379  swb grid 4.1.0.3_h.ex4
E1080AA2D218911CE9234D746BF6F6BA  swb_AUDCAD_demo.set
```
