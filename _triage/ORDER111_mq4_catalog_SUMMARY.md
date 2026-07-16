# ORDER-111 batch 2 — .mq4 source catalog (2026-07-16B, overnight run)

**Input:** 5,187 .mq4 files @ D:\Forex · **dedup (content-hash) → 2,048 unique families** (~2.5× dup).
**Deterministic parser:** `scripts/mq4_source_catalog.ps1` (PowerShell — python312 embed broken).
**Catalog:** `_triage/ORDER111_mq4_source_catalog.csv` (family_name, copies, path, size_kb,
mechanism_keywords, uses_iCustom, has_mart_block, rough_family, already_known).

## Distribution (2,048 families)
| rough_family | count | note |
|---|---|---|
| other | 924 | iCustom-dep (217) หรือ price-action/unclassified |
| **breakout** | **421** | momentum edge-class |
| **trend** | **384** | momentum edge-class |
| reversion | 160 | |
| oscillator | 151 | |
| grid-mart | 8 | **real-grid tokens เท่านั้น** |

**⚠️ boilerplate ที่จับได้ (skill trap):** "martingale" = label ใน fxDreema template **95% ของไฟล์**
(แม้ไม่ได้ใช้) → exclude ออกจาก rough_family, เก็บเป็นคอลัมน์แยก `has_mart_block` (37% y). ถ้าไม่ทำ
= grid-mart จะโป่ง 95% (เหมือน doji-boilerplate ×14 ใน fxDreema concept pass).

## Buildable momentum shortlist = 532 families
(trend/breakout · self-contained no-iCustom · ยังไม่รู้จัก · มี indicator call จริง)
top-by-copies (popular = battle-tested-ish, ส่วนใหญ่ classic public MT4 EAs):
awesome(iMA) · 10_points(iMACD) · **firebird** family ×หลาย rev(iMA) · envelope(iMA) ·
robotpowerm5(iSAR|iATR|iMomentum) · **tsd/TheStrategyLab** family(iMACD|iForce|iWPR) ·
universalMAcross(iMA) · moving_average(iMA) · ronz_auto_sl_ts_tp(iMA).

## Next (judgment — รอคุย user)
- cross-ref สถานะแล็บ (signal-landscape: VALIDATED/DEAD/**NEVER-TOUCHED**) → NEVER-TOUCHED ที่เข้า
  momentum thesis = คิว build (user มีความรู้ classic EA เหล่านี้จากประสบการณ์ — คุยก่อน build)
- หลาย family = classic public EA (firebird/tsd) → มี forward-track ในโลกจริง, user น่าจะรู้จัก
- **result = จุดเริ่มคุย ไม่ใช่ verdict** (per corpus-intake skill)
