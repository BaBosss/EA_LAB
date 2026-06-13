# EA_LAB

EA_LAB is a separate testing and optimization workspace for EA experiments, presets, reports, results, and candidate tracking.

EA_LAB is separate from EA_CORE_V1.

This scaffold is template-only. The Excel files contain template schemas only: sheet names and practical column headers.

This scaffold does not create formulas, macros, VBA, external connections, PowerQuery, parser logic, strategy logic, live trading logic, broker integration, Telegram automation, dashboard automation, or EA_CORE_V1 source changes.

## Intended Use

- Strategy presets
- Preset parameters
- Manual and future automated MT5 reports
- Backtest and optimization results
- Candidate selection
- Future portfolio tracking

## Identifier Formats

- RunID format: RUN_<EA_CODE><0001>
- OptBatchID format: OPT_<EA_CODE><0001>
- PassID format: _P000001
- CandidateID format: CAND_<EA_CODE>_
- RecommendationID format: REC_<EA_CODE><0001>

## Workflow Note

Manual/auto MT5 reports are not parsed yet.

Reports may be manually placed into reports\inbox.

Parsing and automation are future phases only.

No parser exists yet.

No automation exists yet.

---

## UPDATE 2026-06-12 — เริ่มใช้งานจริงแล้ว

- **เปิด [INDEX.md](INDEX.md) ก่อนเสมอ** = ทะเบียน EA ทุกตัว + สถานะ
- **parser มีแล้ว** (เลิกใช้ข้อความ "no parser exists yet" ด้านบน) — อยู่ใน skill
  pipeline ดู [scripts/README.md](scripts/README.md)
- **EA ตัวแรกที่ทำจริง:** [ea_projects/EA_GoldenEmber_Pivot](ea_projects/EA_GoldenEmber_Pivot/00_README.md)
- **idea bank:** `D:\Forex\50_KNOWLEDGE\IDEA_BANK\` (ไม่ย้ายมา ใช้ร่วมกัน)
- **skill pipeline:** `C:\Users\patip\.claude\skills\` = สมองที่ให้คะแนน/ตัดสิน;
  EA_LAB = แฟ้มหลักฐานของ EA แต่ละตัว
