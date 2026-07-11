# ORDER-091C PREP — .Final EA funnel-queue triage (lead, 2026-07-11)

**บทบาทเอกสาร:** เตรียมคิว funnel ให้ session หน้า (Opus นำ) เริ่มได้เลยโดยไม่ต้องแกะซ้ำ. ไม่ใช่ verdict —
เป็นการจัด tier ตามโครง (concept + flags จาก catalog) + ธงเตือนที่ parser จับได้.

**ข้อจำกัดที่ต้องรู้ก่อนใช้:** .Final EA 175 rows ส่วนใหญ่ **ไม่ใช่ fxDreema-format** (hand-built/AI-gen) →
parser ยืนยัน SL เชิงโครงไม่ได้ (135 rows = `SL_UNKNOWN;SL_HEURISTIC`). การจัด tier นี้จึง **ต้องมี user
ยืนยันว่าตัวไหนคือของที่เคย hand-validate จริง** (folder ชื่อ ".Final EA" แต่ปนของ 3 แบบ: keeper จริง +
indicator-sample noise + AI-experiment). prior สูงสุด = ของ user validate — แต่ต้องแยกออกจาก noise ก่อน

---

## 🔴 ปมหลักที่ต้องให้ user ช่วยแยกก่อน funnel
Tier A ตาม concept มี **indicator เดี่ยวชื่อโดด ๆ ซ้ำเป็นคู่** เพียบ: Accelerator·Alligator·Awesome·
Awesome_Oscillator·Bears·Bulls·ColorLine·Envelopes·Force_Index·Gator_2·Ichimoku·Keltner Channel·
MACD·Parabolic·ParabolicSAR — **แทบแน่ว่าเป็น MetaTrader stock "Examples" EA / fxDreema learner export
ไม่ใช่ของ user validate** (ชื่อ = ชื่อ indicator ล้วน + ซ้ำ 2 copy). → **คำถาม user ข้อเดียวที่ปลดล็อกทั้งกอง:
"ใน .Final EA ตัวไหนคือของที่พี่คัด/เทสมือเองจริง ๆ vs ตัวอย่าง indicator ที่ติดมา?"**

---

## Tier A — edge-concept ที่น่า funnel จริง (หลังตัด indicator-sample noise)
ตัวที่ชื่อ "ตั้งใจตั้ง" ไม่ใช่ชื่อ indicator:
- **Winning Pro 2.5 (Update)** — trend_follow (ชื่อบ่งบอก strategy จริง → funnel ก่อน)
- **TMA Bands nk** — trend_follow (TMA = triangular MA band, mean-revert-ish)
- **กลุ่ม AI LLM Trading (ของ user gen เอง — Wave 3 AI_GEN แต่ copy อยู่ที่นี่ด้วย):** Scalper(AI-1) ·
  Combine Signal(AI-10) · Trend Follow(AI-7) · Swing Trade(AI-8, reversion) — **user บอกไอเดียดี** →
  concept-mine + smoke · ระวัง: AI-5 = Martingale (อยู่ Tier B)

## Tier B — grid/martingale + NO_CAP (11 ตัว) — diagnosis→lever ก่อน ห้าม DD-dismiss (คำ user)
| name | concept | flag | หมายเหตุ funnel |
|---|---|---|---|
| (Boss) Hedging Balance | session_time | NO_SL;ESC | เจอชื่อใน copy OneDrive แล้ว (plan note) — cross-ref verdict เดิมก่อน |
| (Boss) PSAR follow trend rev 1.23 lot plus | trend_follow | NO_SL;ESC;NO_CAP | PSAR trend + lot-add — flat-lot test คือกุญแจ |
| (GPM) Almost 1 Direction v1.9.3 | session_time | NO_SL;ESC;NO_CAP | 1-direction grid |
| (Niyombot) Price Action Close All Lot.d H1 | candle+dash | NO_SL;ESC;NO_CAP | PA + close-all basket |
| (Niyombot) Vote Close All Lot.D H1 V6 | dashboard | NO_SL;ESC;NO_CAP | vote-based basket |
| EX177 - Grid Trading System and Hedging Lots 2.2 | grid_basket | NO_SL;ESC;NO_CAP | classic grid+hedge |
| (NuiIndy) Dynamic RSI+ADX Style (4) | session_time | NO_SL;ESC;NO_CAP | ⚠️ **NuiIndy = live CORE อยู่แล้ว (magic 1524)** — นี่คือ variant, cross-ref ก่อน อย่า re-funnel ของเดิม |
| (NuiIndy) Perfect Tri Arbitrage Any Symbols | correlation_pair | NO_SL;ESC;NO_CAP | triangular arb — กลไกใหม่ที่ landscape ยังไม่มี, น่าสนใจแต่ NO_CAP = ระวัง |
| AI - LLM - ALL TEMPLATE (ea1) | grid_basket | SL_UNK;ESC;NO_CAP | AI template |
| AI 5 LLM Trading Martingale (ea1) ×2 | grid_basket | NO_SL;ESC;NO_CAP | AI-gen martingale — flat-lot test |

**หลัก Tier B (VERDICT GATE ข้อ 5):** martingale ≠ auto-reject → เช็ค 4 ข้อ (SL? capped steps? entry-edge
flat-lot PF>1? ดื้อ/มีเงื่อนไข?) ก่อนทิ้ง · แต่ NO_CAP = ธงแดง cap-key EA-SCORE เพดาน 3 จนกว่าจะพิสูจน์ cap จริง

## Tier C — crack/phone-home (5 ตัว) — behavioral-only หรือข้าม
`0 Test Get OpenAI API` · `1 Openai API Start` · `2 Openai API Trade SL TP` · `4 Full Stack AI Block - Sample`
(ทั้ง 4 = WEBREQUEST เรียก OpenAI API = phone-home, อาจเป็น experiment ของ user เอง) · `DLLSampleTester`
(DLL_IMPORT) → **EA-SCORE เพดาน 2 (crack-key)** · funnel เต็มไม่คุ้ม · ถ้า user อยากได้ไอเดีย = อ่านโครงอย่างเดียว

---

## คิว funnel ที่เสนอ (Opus รอบหน้า, 1-2/batch ตาม pacing)
1. **ถาม user แยก keeper vs noise ก่อน** (ปมหลักด้านบน) — ประหยัดสุด, ปลดล็อกทั้งกอง
2. batch 1 = Winning Pro 2.5 + TMA Bands nk (Tier A ชื่อ strategy จริง, funnel เต็ม MC+OOS ที่ user ไม่เคยทำ)
3. batch 2 = NuiIndy Tri-Arbitrage (กลไกใหม่ landscape ยังว่าง) + PSAR-follow (flat-lot test)
4. AI LLM series = concept-mine รวมกับ Wave 3 AI_GEN (user บอกไอเดียดี — extract idea แม้ไม่ผ่าน)
5. cross-ref ทุกตัวกับ scorecard ก่อนรัน — NuiIndy/Boss-Hedging อาจมี verdict แล้ว ห้ามรันซ้ำ
