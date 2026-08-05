# EA Template V2 — แนวทางพัฒนาสำหรับ Claude

เอกสารนี้เป็นแนวทางพัฒนาแม่พิมพ์ EA ต่อจากสถานะปัจจุบันของ `ea_template` โดยมีเป้าหมายให้ Claude ใช้แตกงานเป็น order ที่เล็ก ตรวจได้ และไม่ทำให้แม่พิมพ์ drift

## เป้าหมาย

ทำให้ `core/` + `Boss_*.mq5` เป็นสายหลักที่:

1. ใช้ผลิตและคัดกรอง EA ใหม่ได้เร็ว
2. ใช้ผิด configuration ได้ยาก
3. ตรวจสอบผลหลัง compile, restart, broker rejection และ partial execution ได้
4. แยก strategy edge ออกจาก chassis/risk behavior อย่างชัดเจน
5. มีเอกสารและ deployment path ที่ตรงกับโค้ดจริง

## Source of truth

- Current chassis: `ea_template/core/`
- Current entry wrappers: `ea_template/Boss_*.mq5`
- Legacy V1: `ea_template/EA_LabTemplate.mq5` + `ea_template/modules/`
- Current test harness: `ea_template/tests/`
- Full chassis cage: `scripts/tpl_regression.ps1`
- Deployment: `ea_template/deploy.ps1`

กฎสำคัญ: เพิ่ม feature ใหม่ใน `core/` เท่านั้น เว้นแต่ order ระบุชัดว่าเป็น V1 compatibility work. ห้ามแก้ `modules/` เพื่อให้ behavior ใหม่เกิดขึ้น

## ลำดับการพัฒนา

### Phase 1 — ทำเอกสารและ deployment ให้ตรงความจริง

งาน:

- ปรับ `README.md` ให้ V2 เป็น current path และประกาศ V1 freeze
- อธิบาย Boss 11–18, entry owner, stack owner และ exit owner ของแต่ละ build
- อธิบาย tester/demo/live status ของแต่ละ Boss โดยอ้างสถานะจาก `PROJECT_STATE.md` และ scorecard
- แก้ข้อความท้าย `deploy.ps1` ให้ค้นพบและแสดง Boss wrappers ทั้งหมดแบบ dynamic
- เพิ่มวิธีตั้ง unique magic และคำเตือนเรื่อง `.set` ที่เก่าหรือใช้กับคนละ build
- เพิ่ม troubleshooting สำหรับ no-trade, halt persistence, pending order และ restart

Acceptance criteria:

- คนใหม่อ่าน README แล้วรู้ว่าไฟล์ใดเป็น current และไฟล์ใดเป็น legacy
- ทุก Expert name ในเอกสารตรงกับไฟล์ที่ deploy ได้จริง
- ไม่มีข้อความว่า tester-only หากสถานะจริงของ build นั้นเปลี่ยนแล้ว
- ไม่เปลี่ยน input name ที่มี `.set` ใช้งานอยู่โดยไม่มี migration note

### Phase 2 — Configuration validation กลาง

สร้าง module/function เดียวสำหรับตรวจ configuration ใน `OnInit` ก่อนเริ่ม trading เช่น `Config_Validate()` หรือชื่อที่สื่อความหมายเทียบเท่า

ต้องตรวจอย่างน้อย:

- Stack 93 กับ pending mode
- exit owner ซ้ำกันระหว่าง per-leg TP, basket exit และ entry-owned exit
- Recovery/Hedge/partial-close ที่ถูก mode ปัจจุบันปิดใช้งาน
- grid/DCA ที่ไม่มี hard cap หรือมี cap เป็นศูนย์โดยไม่ตั้งใจ
- SL mode ที่คำนวณ SL ไม่ได้หรือได้ SL=0 ใน build ที่ต้องมี protective stop
- lot progression ที่เกิน max lot, max levels หรือ deposit-load cap
- input ที่ไม่มีผลใน Boss เฉพาะทาง เช่น entry ที่มี engine/exit owner ของตัวเอง

กติกา severity:

- ผิดจน safety promise เป็นเท็จ → `INIT_FAILED`
- ตั้งได้แต่ runtime จะ ignore → `WARN` พร้อมชื่อ input และทางแก้
- เป็น legal combination → เงียบหรือ log สรุปครั้งเดียว

Acceptance criteria:

- validation อยู่จุดเดียว ไม่กระจายเป็น if ซ้ำในหลาย module
- ทุก WARN ระบุว่า input ใดถูก ignore และเหตุใด
- มี test cases สำหรับ valid, warning และ fatal configuration
- regression baseline เดิมต้องไม่เปลี่ยนโดยไม่มีเหตุผลที่บันทึกไว้

### Phase 3 — Execution/restart/reconciliation cage

ขยาย tests จาก unit smoke ไปสู่ scenario tests สำหรับ state ที่ broker อาจเปลี่ยนระหว่าง EA ไม่ทำงาน

กรณีขั้นต่ำ:

- MT5 restart ขณะมี position เปิด
- restart ขณะมี pending ladder
- close-all สำเร็จบาง ticket และล้มเหลวบาง ticket
- partial close สำเร็จบาง leg และ retry ใน tick ถัดไป
- pending fill ระหว่าง restart แล้ว EA ต้อง adopt ได้ ไม่สร้างซ้ำ
- persisted HALT/KILL/PENDING state ถูก restore ถูก account, symbol และ magic
- Global Variable write/delete ล้มเหลวแล้วระบบไม่ประกาศว่าสำเร็จเกินจริง
- netting และ hedging account behavior ถูกระบุและทดสอบแยกกัน

Acceptance criteria:

- ทุก safety exit มี broker-state reconciliation หลังส่งคำสั่ง
- ไม่มี path ที่ประกาศ flat หรือ halted ทั้งที่ยังมี exposure ของตัวเอง
- test log แยกได้ว่า failure มาจาก client validation หรือ broker retcode
- ทดสอบด้วยทั้ง DryRun และ real tester execution ตามความเหมาะสม

### Phase 4 — Deployment manifest และ release gate

ปรับ `deploy.ps1` หรือเพิ่ม script เสริมให้สร้าง manifest ของ build ทุกครั้งที่ compile สำเร็จ

Manifest ควรมี:

- wrapper name และ entry tag
- source commit/hash
- compile errors/warnings
- build version
- allowed status: tester, demo, หรือ live
- required unique magic
- known ignored inputs
- required `.set` หรือ safety profile

กติกา:

- compile warning ใด ๆ ไม่ผ่าน release gate
- compile fail ห้าม mirror binary ไป lane อื่น
- binary ที่ไม่มี source/hash ตรงกันห้ามใช้เป็น candidate
- `Boss_15`, `Boss_17`, `Boss_18` ต้องติดสถานะ deploy approval ตาม scorecard ไม่ใช่ดูจาก compile ผ่านอย่างเดียว

Acceptance criteria:

- deploy output ครบ Boss wrappers ที่ค้นพบจริง
- manifest บอกได้ว่า binary ใดมาจาก source รอบใด
- stale `.ex5` ไม่สามารถถูกเข้าใจว่าเป็น compile รอบใหม่

### Phase 5 — ลดความซับซ้อนของ input surface

หลัง Phase 1–4 ผ่านแล้ว ค่อยลด input ที่ผู้ใช้เห็นในแต่ละ Boss โดยไม่ทำลาย compatibility ของ `.set`

แนวทาง:

- shared inputs อยู่ใน `Inputs.mqh`
- entry-specific inputs เปิดเฉพาะเมื่อ build นั้นใช้
- mode ที่เป็น engine-owned ไม่ควรแสดงเป็นปุ่มที่ผู้ใช้เปลี่ยนแล้วไม่มีผล
- ใช้ compatibility alias หรือ migration tool หากต้องเปลี่ยนชื่อ input
- ห้ามเพิ่ม dropdown ใหม่เพียงเพื่อรองรับ strategy หนึ่งตัว ถ้ายังไม่มี second adapter หรือ use case จริง

Acceptance criteria:

- ทุก input ที่แสดงใน Navigator มีผลต่อ behavior หรือมีเหตุผล compatibility ที่ระบุไว้
- จำนวน legal combinations ลดลงหรือถูก validate ชัดขึ้น
- `.set` สำคัญเดิมยัง load ได้ หรือมี migration result ที่ตรวจสอบได้

## สิ่งที่ยังไม่ควรทำ

- อย่าเพิ่ม indicator/entry ใหม่ก่อน safety และ documentation phases ผ่าน
- อย่าเพิ่ม martingale, recovery หรือ hedge mode ใหม่โดยไม่มี cap, kill path และ scenario tests
- อย่า port logic เข้า chassis เพียงเพราะ backtest ช่วงเดียวดูดี
- อย่าเปลี่ยน default หรือ enum value เพื่อความสะอาดโดยไม่ทำ regression และ `.set` migration
- อย่าตัดสินว่า EA ดีหรือแย่จาก template regression baseline; baseline มีไว้ตรวจ neutrality ของ chassis
- อย่าแก้ `VISION.md`, `PROJECT_STATE.md` verdict/decision log หรือทิศทางโครงการจากเอกสารนี้เอง

## Definition of done ต่อ order

ทุก order ที่แก้แม่พิมพ์ต้องมี:

1. scope ไฟล์ชัด
2. behavior ก่อน/หลังชัด
3. test หรือ regression ที่พิสูจน์ได้
4. ผลตัวเลขดิบและ log ที่เกี่ยวข้อง
5. ระบุผลกระทบต่อ `.set`, persistence และ deployment
6. `tpl_regression.ps1` เป็น CLEAN หากแตะ `core/`
7. compile ต้องเป็น 0 errors / 0 warnings
8. commit tag `[claude]` หรือ tag ของผู้ทำตามกติกาโครงการ
9. หลัง commit ต้องรัน `scripts/make_status.ps1`

## ลำดับ order ที่แนะนำ

1. README/V2-current-path cleanup
2. deploy output + dynamic release manifest
3. centralized configuration validator
4. validator tests and legal-combination table
5. restart/pending/partial-close scenario cage
6. persistence failure-injection tests
7. per-Boss input surface cleanup
8. only then consider new chassis capability

หลักตัดสินใจ: ทำให้แม่พิมพ์ “ใช้ผิดยากและพิสูจน์ได้” ก่อนทำให้ “ทำอะไรได้มากขึ้น”
