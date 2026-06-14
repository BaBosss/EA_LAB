# RESUME HERE — อัพเดท 2026-06-14 (session 2)

อ่านไฟล์นี้ก่อนเสมอเมื่อเปิด session ใหม่

---

## สถานะ EA candidates

| EA | Pair | ผล |
|---|---|---|
| GSMC (Gold SMC RiskCap) | XAUUSD | ✅ PORTFOLIO_CANDIDATE #1 |
| EX197 Multi Group Scalping | GBPJPY | ❌ CONDITIONAL REJECT — OOS RF 1.30 < 1.50, grid/hedge risk |
| MooDeng Bot | USDCHF | ❌ REJECT — OOS PF 0.94 ขาดทุน, DD 80% |
| MooDeng Bot | EURUSD | ❌ REJECT — OOS PF 0.16 ขาดทุน, DD 71.8% |
| MooDeng Bot | EURGBP | ❌ REJECT — OOS PF 0.10 ขาดทุน, DD 78.1% |

## ถัดไปทันที

1. **MooDeng family → REJECT ทั้งหมด** (USDCHF/EURUSD/EURGBP) — ข้ามไปแล้ว

2. **ขั้นตอนถัดไป (ไม่ optimize แล้ว):**
   - GSMC demo setup — configure lot sizing, เปิด demo account, monitor
   - GitHub: `gh repo create EA-Lab --private` + push (รันเอง)
   - EA Template Phase 3 — MQL5 template with dropdown modes
   - หา EA candidate #2 (ดูรายการด้านล่าง)

3. **EA ต่อไปที่ควรลอง** (มี ex5 ใน MT5 Experts):
   - `LondonBO.ex5` — London Breakout
   - `HalfTrend_MTF_EA.ex5` — trend following
   - `Multi-Timeframe Trend Following.ex5`
   - `EA TREND V2.ex5`
   - `Sentinel KMZ_2.5_fix MT5.ex5`
   - `PivotProbabilityPro.ex5`
   - **Eurusd All TF.xml** (WEAK 74.7, PF 4.16 DD 6% 889 trades) — ไม่รู้ว่า EA ไหน อยู่ใน `D:\Forex\30_OPTIMIZATION\OLD_Report\`

3. **GitHub private repo** ยังไม่เสร็จ — รันเอง:
   ```
   gh repo create EA-Lab --private --description "MT5 EA platform"
   cd D:\EA_LAB && git remote add origin https://github.com/<username>/EA-Lab.git && git push -u origin master
   ```

## .set files ที่สร้างแล้ว

```
_mt5_auto/MooDengv1_robust.set       USDCHF locked params
_mt5_auto/MooDeng_EURUSD_robust.set  EURUSD locked params
_mt5_auto/MooDeng_EURGBP_robust.set  EURGBP locked params
```

## Gate / Pipeline

- **Robust gate:** PF≥1.20, DD≤20%, RF≥1.50, Trades≥100
- **Loop:** `optimize_loop.ps1` → `select_robust_pass.py` → IS+OOS mt5_run → score
- **Plateau:** GOOD≥20 / WEAK 5-19 / THIN 1-4 / NONE=stop
- Grid/hedge EA: ใช้ report DD × 2-3 สำหรับ sizing (MC ประเมินต่ำกว่าจริง)

## คำสั่งหลัก

```powershell
# optimize loop
& D:\EA_LAB\scripts\optimize_loop.ps1 -Expert "EA_NAME" -Symbol XXXX -BaseSet "path\to.set" -Code CODE -OptFrom 2023.01.01 -OptTo 2026.06.01 -OosFrom 2020.01.01 -OosTo 2023.01.01

# single test
& D:\EA_LAB\scripts\mt5_run.ps1 -Expert "EA_NAME" -Symbol XXXX -Model 1 -FromDate 2024.01.01 -ToDate 2026.06.01 -SetFile "path\to.set" -ReportName "label"

# ดูผล
python D:\EA_LAB\scripts\_show_rows.py "keyword"
```
