# CRYPTO TRENDRIDER — attach bundle (ORDER-125, staged 2026-07-18, WAITING user attach)

Trend-rider + pyramid + snowball บน crypto CFD (MT5). 2 leg อิสระ corr 0.03 = additive เต็ม.
สเปค + หลักฐานเต็ม: `_triage/ORDER125_CRYPTO_TRENDRIDER_SPEC.md`

## ⚠️ ก่อน attach — เงื่อนไขบัญชี
- **symbol ต้องมี BTCUSD + ETHUSD** ใน Market Watch (ThinkMarkets มี · Exness demo 146237 มี) — เช็ค suffix (บาง broker เป็น BTCUSDm)
- account = **HEDGING** · crypto เทรด **24/7 → ต้องรันบน VPS ตลอด** (ห้ามรันเครื่องที่ปิด)
- leverage พอสมควร (margin level ตอนเทส >2000% ที่ 100:1)

## 2 leg — attach ตามตาราง
| leg | ชาร์ต | EA (.ex5) | Set | Magic |
|---|---|---|---|---|
| ST-BTC | **BTCUSD H4** | EA_SUPERTREND | `ST_BTC_deploy.set` | **990025** |
| DON-ETH | **ETHUSD H4** | EA_DONCHIAN | `DON_ETH_deploy.set` | **990030** |

เช็คหลังโหลด set: ST → RiskPct=1.0 · ATRperiod=14 · Multiplier=2.5 · Magic=990025 ·
DON → RiskPct=0.35 · DonchPeriod=35 · MaxPyramid=3 · Magic=990030

> ⚠️ ST-BTC ใช้ Magic **990025** (ไม่ใช่ 990020 — 990020 ถูก SuperTrend XAU ใช้ไปแล้วบนบัญชีเดียวกัน กัน /ea-monitor แยก P&L ไม่ออก)

## หลักฐาน backtest (Model-4 real ticks 99%)
- ST-BTC: PF 1.88 (flat) / 2.22 (snowball 1%, DD 5.6%) · both-window + holdout ผ่าน
- DON-ETH pyr3: PF 1.99 (flat) / 2.52 (snowball 0.35%, DD 14.3%)

## 🔴 GATE ก่อน promote → เงินจริง (สำคัญ)
- **swap: backtest คิด 0 แต่ live BTC long −14.67%/ปี · ETH −9.86%/ปี** (mode5 interest)
- ปล่อย demo ≥1 เดือน → วัด swap-adjusted PF · **ต้อง >1.3 ถึงขยับเงินจริง**
- Codex audit RiskLot ผ่านแล้ว (แก้ 3 defect) · regression ตรง

## หลัง attach เสร็จ
บอก Claude วันที่ attach → ลง `portfolio/DEPLOYMENTS.csv` (เปลี่ยน PENDING_ATTACH → ACTIVE + start_date + judge_date +3 เดือน)
