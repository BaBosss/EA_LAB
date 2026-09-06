# Owner Handoff: วิธีคุม EA_LAB จากมือถือหลัง System Convergence

> Source milestone: `89e0c3d5b79003f5591b2edb8b94dc14a0adee5d`. ก่อนเริ่มงานให้ resolve pushed origin/master ใหม่เสมอ; SHA นี้ระบุ source integration ส่วนเอกสาร closeout อยู่ใน commit ถัดมา

## ของที่พร้อมใช้

- จุดเริ่มงานจาก exact Git ref: context packet ผูก source commit, Git blobs และ task contract; order ยาวไม่ถูกตัดเงียบ และ missing task ใช้เป็น assignment ไม่ได้
- Long Job/resume แยก “รันจบ” ออกจาก “หลักฐานผ่าน/review/รับเข้า canonical” พร้อมผูก hash ของ job, state, result และ logs กับ attempt เดียว ป้องกันเอาหลักฐานคนละรอบมาประกบ
- Truncation evidence แยก `CHECK_PASS / TRUNCATED / CHECK_ERROR / UNKNOWN`; legacy `false` อย่างเดียวรับงานใหม่ไม่ได้
- Template applicability เทียบ dependency bytes แทนตัดสินจาก commit SHA ต่างอย่างเดียว และ parameter contract ตรง vocabulary จริง
- ชุดแก้ Profile/Universe selector ทำให้ schema/registry/preset/reader ใช้ lane และ precedence ตรงกัน, unknown fail closed และไม่ใส่ mapping/universe จริง ชุดนี้ผ่าน scoped manual-IDE selector review ต่าง model family แล้ว; source integration คือ `89e0c3d5b79003f5591b2edb8b94dc14a0adee5d`
- Schema gate เดิมเปิด AJV ซ้ำตามกลุ่ม path ที่แบ่งเพื่อจำกัดความยาว command ลดจาก `14.305s` เหลือ `6.252s` โดยยังตรวจ **143 cases เดิมครบและผลเหมือนเดิม** ไม่มีการถอด suite ระหว่างปิด commit hook พบ `run_*` เดิม 6 รายการยังไม่ถูกจัดชั้น; root แก้ด้วย registry rows ตรงรายการ ไม่ลด test coverage/guards; เจ้าของอนุมัติปรับเพดานเวลาสำหรับทุก per-path commit จาก 90 เป็น 110 วินาที หลัง tests ผ่านครบแต่ใช้ 98.6 วินาที ส่วน full-tier คง 195 วินาที
- Second Brain handoff และ offline news selector บังคับ citation, contradiction, abstention, available-at, revision, coverage และ clock contract; unresolved semantics ยังหยุด execution
- Monitor แยก generated time จาก source time; วันที่จากชื่อไฟล์อย่างเดียวเป็น `DATE_ONLY`, อนาคตเป็น `FUTURE`, missing/stale/invalid ไม่กลายเป็นเขียว
- Codex launcher ตรวจ executable/help/version จริงและมี smoke proof เฉพาะ read-only route บน clean exact base

## ขอบเขตที่ยังไม่ผ่าน

งานนี้ยังไม่พิสูจน์ EA end-to-end: ไม่มี MT5/backtest/optimization, ไม่เปลี่ยน MQL/strategy/risk/default, ไม่ attach/deploy และไม่เพิ่ม DEMO/LIVE authority. Profile/Universe patch แก้ contract/selector แต่ยังไม่เลือกสมาชิก universe, symbol mapping, lot หรือ config สำหรับเทรดจริง

Gemini manual-IDE selector **ผ่านเฉพาะ scoped static review ที่บันทึกไว้แล้ว** ไม่ควรเขียนว่า “Gemini ยังไม่เคย qualified” อีก แต่ persistent/unattended provider route, billing/authority path และ provider M2 ทั้งก้อนยังไม่ครบ. Codex read-only smoke ไม่พิสูจน์ write route, reviewer competence หรือ server attestation

News replay ที่ผ่านยังเป็น synthetic/offline selector proof; historical dataset, source provenance, broker/DST clock และ EA replay จริงยังไม่ qualified. Second Brain ยัง research-only. Monitor เป็น snapshot reader ไม่ใช่ scheduler/producer หรือ phone alert. PWA ยัง parked และไม่ได้ deploy/sync/แจ้งเตือนอัตโนมัติ

## วงจรทำงานจากมือถือ

1. ใช้ ChatGPT Project Control Tower เพียงแชตเดียว ถือ objective, queue, contract และการสรุป
2. เริ่มทุก session จาก pushed `origin/master` ที่ `<freshly resolved origin/master SHA>`; อ่าน `START_HERE.md` → `PROJECT_STATE.md` → `AGENTS.md` → `AGENT_TASKBOARD.md`/task part → `docs/workflows/EA_LAB_SYSTEM_CONVERGENCE.md`
3. ถ้าต้องทำบนเครื่อง ให้ Control Tower ออก contract เดียว ระบุ exact SHA/worktree, allowed paths, exclusions, acceptance, checks, evidence และ reviewer แล้วส่งให้ local Codex อย่างชัดเจน
4. Local Codex ใช้ `D:\EA_LAB_CONTROL\worktrees\codex-system-convergence-20260906` หรือ isolated worktree ที่ contract ระบุ ใช้ deterministic tools/Long Jobs ก่อน และคืน job ID, exit/postcondition, hashes และ review ห้าม reset/clean/stash หรือเขียนทับ `D:\EA_LAB` ซึ่ง dirty และต้อง preserve
5. Integrator รับเฉพาะ declared files ตรวจ candidate tree, cages และ review ตามความเสี่ยง แล้ว sync state/taskboard, fast-forward push และตรวจ remote SHA
6. Control Tower รายงานเจ้าของเพียง:
   - **Progress:** เสร็จอะไร ที่ SHA/tree ไหน หลักฐานไหน
   - **Decision:** ข้อสรุปที่รับได้ หรือ `NONE`
   - **Approval:** เฉพาะเรื่องที่ต้องให้เจ้าของอนุมัติตาม AGENTS.md หรือ `NONE`
   - **Blocker:** blocker class, คน/ขั้นตอนถัดไป และคำถามเจ้าของเฉพาะที่จำเป็น

ChatGPT บนมือถืออ่าน pushed GitHub ได้เมื่อมี connector/access พร้อม แต่ไม่เห็น dirty/staged/local outputs, terminal, process, MT5, Lane Registry หรือ monitor ล่าสุด จน local Codex ส่งหลักฐานผูก path/hash/SHA กลับมาหรือข้อมูลถูก review และ push แล้ว ไม่มี automatic dispatch เข้า IDE และไม่มี push alert ที่พิสูจน์แล้ว

## Dependency ถัดไปตามลำดับ

1. ปิด provider transition: bounded validator + real route ที่พิสูจน์ตาม scope โดยไม่ขยายเป็น unattended authority เอง
2. ทำ **หนึ่ง non-trading populated template config** ให้ผ่าน schema → registry/profile/universe selector → generated output แบบ end-to-end โดยไม่ต่อ MT5/lot/order
3. ปิด Second Brain semantics ที่เจ้าของต้องเลือก แล้วสร้าง pinned consumer contract ก่อน execution ใด ๆ
4. Qualify historical news dataset/provenance + broker/DST clock และ replay แบบ available-at/revision จริง
5. รวม producer/freshness/delivery contract ให้เสร็จ แล้วค่อยรับ existing PWA กลับมาทดสอบและ deploy ตาม contract ใหม่

## Prompt เปิด Control Tower ใหม่

```text
คุณคือ ChatGPT Project Control Tower เพียงหนึ่งตัวของ EA_LAB
Canonical pushed SHA: <freshly resolved origin/master SHA>
Profile/Universe integrated source: 89e0c3d5b79003f5591b2edb8b94dc14a0adee5d
Local convergence worktree: D:\EA_LAB_CONTROL\worktrees\codex-system-convergence-20260906
Preserve dirty primary checkout D:\EA_LAB; ห้าม reset/clean/stash/เขียนทับ และห้ามใช้เป็น canonical

ตรวจ origin/master ให้ตรง <freshly resolved origin/master SHA> แล้วอ่าน exact ref: START_HERE.md, PROJECT_STATE.md, AGENTS.md, AGENT_TASKBOARD.md + taskboards/active/* ที่เกี่ยวข้อง, docs/workflows/EA_LAB_SYSTEM_CONVERGENCE.md

Objective ของเจ้าของ: [เติมที่นี่]

ตรวจ attempt/accepted evidence เดิมก่อน ห้าม rerun เพื่อ rediscover ถ้าต้องใช้ local Codex ให้ออก explicit scoped contract ระบุ SHA/worktree/paths/exclusions/acceptance/checks/evidence/reviewer/hard stops ใช้ deterministic tooling/Long Jobs ก่อน และอย่าอ้างว่าเห็นหรือรัน local แล้วจนมีหลักฐานกลับมา

ห้ามขยาย offline fixture เป็น EA end-to-end claim ห้ามเปลี่ยน risk/default, runtime/deploy, DEMO/LIVE, trading, QI-2+, governance หรือ irreversible direction โดยไม่มี authority ตาม AGENTS.md รายงานเป็น Progress / Decision / Blocker พร้อม exact SHA/tree/evidence
```

PWA ยังพักไว้ตามลำดับที่เจ้าของเลือก; ก่อนเปิดใช้งานต้องพิสูจน์ producer/freshness/delivery ที่หน้ามือถือนั้นใช้ ไม่ถือว่าผ่านเพราะมีหน้าเว็บแล้ว
