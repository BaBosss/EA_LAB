# ORDER-113 — KELTNER (#62) rescue verdict (2026-07-16B, Opus)

**EA:** `EA_KELTNER` (compiled lab EA, batch 2026-06-27) — Keltner channel breakout (EMA±KeltMult×ATR) filtered by TrendEMA200, ATR-trail. Momentum/breakout class.
**Prior verdict:** "DEAD 2026-06-27" — 4 sym (XAU/GBPJPY/USDJPY/GBPUSD) × **H4 only × default params** → XAU 1.04, others 0.68-0.70. "momentum-chasing / entering after move."
**Rescue mandate (ORDER-084 กอง ข #5):** default-only 1-TF = under-swept → sweep channel-def lever + TF บนบ้านถูก.

## ORDER-113 = sweep core lever (channel EMAPeriod/KeltMult) × TF × both-window Model-4
บ้าน = USDJPY (บ้านที่ ICHIMOKU เพิ่ง revive, momentum→JPY-trender). Isolate channel lever: hold TrendEMA200/AdxOff/SL2.0/Trail2.0. 16 runs → `_mt5_auto/KELT_CH_BOTHWIN.csv`

| preset (EMA/mult) | H1 MAIN/BWD | H4 MAIN/BWD |
|---|---|---|
| tight 10/1.5 | 1.10 / 1.05 | 0.76 / 1.22 |
| def 20/2.0 | 1.05 / 1.10 | 0.71 / 1.48 |
| mid 34/2.5 | 1.00 / 1.08 | 0.72 / 1.48 |
| wide 50/3.0 | 1.02 / 1.14 | 0.74 / 1.33 |

## VERDICT: ❌ REJECT (confirmed — properly swept this time, NOT a revive)
1. **H4 = window-inversion เต็มรูปแบบ** — BWD(2020-22) แรงทุก preset (1.22-1.48) แต่ **MAIN(2023-26) พังหมด (0.71-0.76, net -1000~-1300, DD 15%).** edge ตายในช่วง 3.5 ปีล่าสุด = **deploy ไม่ได้** (แพ้ทั้ง recent window). VERDICT GATE #3: "lever ดีที่ window นึงมัก invert อีก window" = ตรงเป๊ะ = ไม่ผ่าน both-window.
2. **H1 = marginal churn** — both-window บวกบางๆ (1.00-1.14) แต่**ไม่มี cell ไหนแตะ 1.2** + เทรด 450-530t = edge ต่อไม้บางมาก → spread/commission จริงน่าจะกิน <1 (tester ไม่มี spread stress). ไม่ใช่ candidate.
3. **ไม่มี cell ใด both-window ≥1.2** (ต่างจาก ICHIMOKU ที่ med-H4 = 1.48/1.39 ผ่านจริง).
4. **Build-on = ไม่มีทางเปิด:** H4 BWD-only edge → regime-gate ก็ช่วยไม่ได้ (breakout = momentum filter ในตัวแล้ว, regime gate redundant per `regime-gate-grids-not-breakouts`) · pending-limit ก็ผิดทาง (breakout ต้อง chase ไม่ใช่ fade) · H1 churn ปรับ param แล้วยังไม่ถึงบาร์.

**สรุป:** original DEAD = **ถูก** แต่ครั้งนี้ swept จริง (channel-EMA/mult × TF × both-window ≥3 lever) → REJECT valid. บทเรียน: rescue-ladder ให้ผลต่างกันตามตัว — **ICHIMOKU revived · KELTNER confirmed-dead** ภายใต้ treatment เดียวกัน = กระบวนการทำงาน (ไม่ใช่ rubber-stamp revive ทุกตัว). XAU breakout ceiling ~1.13-1.19 ยังจริง; KELTNER USDJPY = H4 regime-dead + H1 churn.
