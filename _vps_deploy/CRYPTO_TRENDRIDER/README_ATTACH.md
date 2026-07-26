# CRYPTO TRENDRIDER — attach bundle (ORDER-125, staged 2026-07-18)

> ## 🔴 SILENT-STOP RISK — ตรวจก่อนอย่างอื่น (เพิ่ม 2026-07-26)
> **ทั้งสอง `.set` ในโฟลเดอร์นี้ตั้ง `_06_AllowLive=false`** (`ST_BTC_deploy.set:13`,
> `DON_ETH_deploy.set:15`) — ค่านี้แปลว่า EA จะ**ไม่ส่งคำสั่งอะไรเลยบนชาร์ตจริง/เดโม** (เขียว
> ปกติ ไม่มี error ไม่มีไม้) ขณะที่ `DEPLOYMENTS.csv` บันทึกทั้งสองขาเป็น **ACTIVE ตั้งแต่
> 2026-07-23** (990025 BTCUSDm · 990030 ETHUSDm บนเดโม 415573666)
>
> **และ checklist "เช็คหลังโหลด set" ข้างล่างนี้ไม่มี `AllowLive` อยู่ในรายการ** — ทำตามครบทุกข้อ
> ก็ยังผ่านทั้งที่ EA ไม่ทำงาน. นี่คือกับดักเดียวกับที่ bundle MacdDiv เรียกว่า
> *"the #1 silent-stop trap: green EA, zero trades"*
>
> **ที่ตรวจได้จากในเครื่อง (2026-07-26):** deals ของ 415573666 ถึงวันที่ 07-26 **ไม่มีไม้ของ
> 990025 หรือ 990030 เลยสักไม้** และไม่มี `ETHUSDm` โผล่เป็น symbol ด้วยซ้ำ — ขณะที่ magic อื่นบน
> บัญชีเดียวกัน (990110/990201-207/992001/992003) มีไม้ลงตามปกติ **⇒ ตัว exporter ทำงานอยู่**
> **แต่ยังสรุปไม่ได้:** เพิ่งผ่านมา 3 วัน และนี่คือ trend-follow บน H4 — ไม่มีไม้ 3 วันเป็นเรื่อง
> ปกติสมบูรณ์ ⇒ **ต้องให้คนเปิดดูของจริง** ตัวเลขในเครื่องแยกสองสมมติฐานนี้ไม่ออก
>
> ### 👉 งานมือ: เปิดหน้า Inputs ของทั้งสองชาร์ตแล้วดูค่า `_06_AllowLive`
> - **ถ้าเป็น `true`** (แก้ด้วยมือตอน attach) = ทุกอย่างปกติ ปัญหาอยู่ที่ `.set` ในกล่องล้าสมัยเฉยๆ
> - **ถ้าเป็น `false`** = ทั้งสองขา**ไม่ได้เทรดมาตั้งแต่ 07-23** และ judge 2026-10-23 กำลังนับถอย
>   หลังบนเวลาที่ไม่มีข้อมูลเกิดขึ้นเลย → ต้องแก้ input + เลื่อน judge ตามวันที่เริ่มจริง
>
> **ผมไม่แก้ `.set` ให้เป็น `true` เอง** — การติดอาวุธให้ EA ส่งคำสั่งเป็นการตัดสินใจของเจ้าของ
> ไม่ใช่ของแล็บ แม้จะเป็นเดโมก็ตาม
>
> เรื่องรอง (แก้แล้วในบรรทัดหัวข้อ): README เขียนว่า "WAITING user attach" ทั้งที่ registry บอกว่า
> attach ไปแล้ว 07-23 · และหลักฐาน "Model-4 real ticks 99%" ข้างล่าง — เลข snowball 2.22/2.52
> ที่อธิบาย config ที่ ship จริง มาจาก run **Model-1** (audit `AUDIT_BUNDLE_EVIDENCE_G2.md` §4)

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

เช็คหลังโหลด set: **`_06_AllowLive=true` ← ข้อแรกเสมอ ไม่มีข้อนี้ = EA ไม่ทำงาน (ดูธงบนสุด)** ·
ST → RiskPct=1.0 · ATRperiod=14 · Multiplier=2.5 · Magic=990025 ·
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
