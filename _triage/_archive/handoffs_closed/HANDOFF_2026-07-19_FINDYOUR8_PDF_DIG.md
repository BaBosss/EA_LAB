# HANDOFF 2026-07-19 — FINDYOUR8 / QuantCorner FB+web deep dive (idea mining)

**Session type:** research/idea-mining (NO EA built, NO verdict issued). Standalone from the CR/ORDER tracks.
**Owner model:** Opus-seat. **Status:** CLOSED — all work committed.

## สิ่งที่ทำ (ครบ)
User ให้ 2 เพจ FB (ว่าด้วยการเทรด/FINDYOUR8 + QuantCorner) ให้ขุดหาไอเดียต่อยอด EA.

1. **FB login แก้ถาวร** — Claude-in-Chrome extension ใช้ session user ที่ login FB ไว้ (ไม่แตะรหัส =
   ไม่ใช่ prohibited credential action). วิธี: user เปิด Chrome login FB + connect extension →
   `list_connected_browsers` → `select_browser` → navigate/get_page_text/find/javascript_tool.
2. **โหลดหนังสือฟรี 20 PDF / 887 MB** จาก Google Drive ของ Wongsakon (folder public
   `1bLKSJNyJzq6FlAIiZlYxvXYqN77YPWVS`, ระบุ "ห้ามใช้เชิงพาณิชย์" = ศึกษาได้) → `_triage/findyour8_pdfs/`
   (**gitignored** — blob ใหญ่ ไม่ commit; catalog .md track). toolchain: gdown ใน venv scratchpad,
   PYTHONUTF8=1 (Thai filenames), โหลด folder-by-folder หรือ by-file-id (gdown --folder abort ทั้ง tree
   ถ้า nested 404; gdown 6.1.0 ไม่มี --fuzzy/--remaining-ok).
3. **แกะ 9 ระบบเทรด** (Canva image-slides → pymupdf render PNG → fan-out 9 subagent) →
   **`_triage/FINDYOUR8_STRATEGY_PDF_CATALOG.md`** (catalog เต็ม + red flags + lead triage).
4. **quant-corner.com re-assessment** — 61 บทความ (สาย SET-equity/ML), ไม่มี EA lever ใหม่เกิน 07-18.
5. **QuantCorner FB** — community hub + event "AI BATTLE IN FINANCE" (Claude Code vs Codex vs Cowork,
   22 ส.ค. = stack เดียวกับ EA_LAB). ⚠️ FB page feed paginate ไม่ได้ใน automation (server-side stall,
   scrollHeight คงที่ 2406, ได้แค่โพสต์ปักหมุด) — โพสต์เก่าเข้าไม่ถึง; ถ้าต้องเจาะ ให้ user ส่ง permalink.

## ของเด็ดที่ได้ (actionable-new)
**🏆 Adaptive Grid MC block-bootstrap zone** — lever ใหม่จริง spec ครบ buildable:
- zone = MC 10,000 path × 60d, 24d block-bootstrap → P10/P90 = grid bounds
- spacing = 0.3×ATR(RMA30); **flat lot + capped band + hard −20% kill (SAFE ไม่ martingale)**
- = "MC+bootstrap+ATR grid zone" ที่ QuantCorner 07-18 จดว่า "ยังไม่แตะ" — ตอนนี้ build ได้
- **แนะนำ probe แรก:** BTC/ETH CFD (crypto lane, TrendRider precedent ORDER-125); offline Python MC ใน
  `_mt5_auto` → P10/P90+0.3ATR → `.set` → grid EA. ⚠️ MT5 FX/CFD คืน swap ที่เด็คเลี่ยง (BTC-long −14.67%/yr)

Levers รอง: Lower-BB(EMA30−1σ)-as-VolStop (ตรง SMCxSTO 991070 SL-fragility) · vol-normalized sizing
`size%=RPT%/band-dist%` · KAMA continuous adaptive-MA block · geometric constant-% grid spacing ·
inverse-ATR anti-martingale lot · fee/swap cost-model · grid→DCA Core&Satellite routing.
**ไม่คุ้ม:** MACD (momentum ตำรา), DCA blueprint (แพ้ B&H ในแบ็คเทสต์ตัวเอง).

## บันทึกลงระบบถาวรแล้ว (committed)
- `_triage/FINDYOUR8_STRATEGY_PDF_CATALOG.md` (catalog หลัก) — commit `88cc2838`+`57e99372`
- `EDGE_CATALOG.md` IDEA SEEDS **#9** (grid-zone levers)
- `.gitignore` (กัน 887MB PDF)
- memory: `quantcorner-findyour8-idea-catalog.md` (updated: FB-via-extension solved) + MEMORY.md index

## OPEN สำหรับ session ถัดไป (ถ้า user เคาะ)
- [ ] เปิด ORDER scaffold **Adaptive Grid MC-zone** probe (crypto lane) — ยังไม่เปิด, รอ user
- [ ] (optional) เจาะโพสต์เก่า QuantCorner FB — ต้อง user ส่ง permalink (feed automation เข้าไม่ถึง)
- [ ] 11 PDF ทฤษฎี (Vanguard/Risk-Parity/Mudley/portfolio) = background, ยังไม่ extract (yield ต่ำ)
