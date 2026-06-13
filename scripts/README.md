# scripts

EA_LAB ใช้ script คำนวณที่ติดตั้งมาพร้อม skill pipeline แล้ว
(ไม่ต้องเขียนซ้ำที่นี่ — เรียกผ่าน Claude หรือสั่งเองได้)

## script ที่มีให้ใช้ (stdlib Python 3 ไม่ต้องลงอะไรเพิ่ม)

| งาน | script | input → output |
|---|---|---|
| parse report MT5 | `C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts\parse_mt5_report.py` | HTML/optimizer XML/CSV → JSON |
| Monte Carlo / OOS | `C:\Users\patip\.claude\skills\robustness-validator\scripts\monte_carlo.py` | deals CSV → MC stats |
| correlation พอร์ต | `C:\Users\patip\.claude\skills\portfolio-selector\scripts\portfolio_analysis.py` | monthly returns CSV → corr + DD overlap |

## ตัวอย่าง
```
python "C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts\parse_mt5_report.py" ^
   "ea_projects\EA_GoldenEmber_Pivot\reports\inbox\report.html" ^
   -o "ea_projects\EA_GoldenEmber_Pivot\reports\parsed\run0004.json"
```

วิธีง่ายสุด: วาง report ใน `reports/inbox/` แล้วบอก Claude ว่า "parse report ตัวนี้"
— Claude จะเรียก script + ตีความผลผ่าน skill ให้เอง

(หมายเหตุ: README เดิมเขียนว่า "no parser exists yet" — ตอนนี้มีแล้ว ตั้งแต่ 2026-06-12)
