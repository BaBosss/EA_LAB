# วิธีอ่านและใช้ EA_LAB Second Brain

> Second Brain เป็นคลังความรู้วิจัยแบบ `RESEARCH_ONLY` ไม่ใช่สถานะโครงการ ไม่ใช่ verdict ของ EA และไม่อนุญาตให้แก้ EA, backtest, deploy หรือ trade โดยอัตโนมัติ

## เริ่มอ่านอย่างไร

1. เปิด Monitor แล้วเลือก `Knowledge` หรือเปิดไฟล์ `READ_SECOND_BRAIN.html` ที่สร้างจาก Git pin ที่ผ่านการตรวจแล้ว
2. ตรวจ `Library health` ก่อน: pin, เวลา build, จำนวน source/card/draft และปัญหา hash/link ต้องแสดงจริง ค่าไม่ทราบไม่ใช่ศูนย์
3. ค้นด้วยชื่อ กลไก หัวข้อ หรือ `source_id` เช่น `Order Flow`, `Demon Beam`, `BWD`, `risk` และคำไทย
4. แยก `SOURCE_CLAIM` (สิ่งที่ต้นทางรองรับ) จาก `EA_LAB_INFERENCE` (การตีความ/ถ่ายโอนที่ยังต้องทดสอบ)
5. ตรวจ `90_negative_knowledge` และผลทดลองเดิมก่อนเสนอการทดลองซ้ำ

`Canonical` คือเอกสารใน Git pin นั้น ส่วน `Draft` คือ `DRAFT_NOT_IMPORTED`: แพ็กเก็ตเตรียม intake ที่ตรวจ hash แล้ว แต่ยังไม่ถูก review/import/register การแสดง draft ไม่ได้ยอมรับเนื้อหา

## เมื่อ EA มีปัญหา

กรอก context packet เท่าที่รู้: EA, variant, build, config, symbol, timeframe, window และ data source ช่องที่ไม่รู้ให้เว้นว่าง ระบบจะเก็บเป็น `null` ไม่เดา จากนั้นค้นอาการ/กลไกและ export packet ซึ่งมี pin, hash, source refs, excerpts, negative-memory match หรือ `NO_MATCH` และ caveat ที่ยังไม่จบ

packet เป็นหลักฐานสำหรับตั้งคำถาม ไม่ใช่คำสั่งแก้ EA ขั้นต่อไปต้องเป็นสัญญา one-change ที่ได้รับอนุมัติ ใช้ tests/review เดิม และส่ง evidence ที่ยอมรับแล้วกลับเข้า knowledge ผ่าน intake ปกติ

## โฟลเดอร์สี่ชนิด

- `knowledge/` — ความรู้ canonical ใน Git
- `D:\EA_LAB_CONTROL\evidence\...` — หลักฐานดิบภายนอกแบบ immutable; ไม่ย้ายหรือทำสำเนาเข้า reader
- prepared intake — ข้อมูลแปลงแล้วที่รอ review เช่น packet Jobbobo; ยังเป็น draft และ source identity แยกจาก canonical
- generated reader/cache — `build/sb_reader_*`; หลัง review controller อาจติดตั้งเพิ่มที่ `D:\EA_LAB_CONTROL\readers\second-brain\versions\<pin>`

## Intake ที่ถูกต้อง

`รับต้นทาง → source/hash/evidence depth → แยก claim/inference → deduplicate → review → append/register/index → retrieval → exact EA problem packet → one-change contract → existing tests/review → evidence กลับเข้า knowledge`

ห้ามใช้ observation time แทน `available_at`; ถ้าไม่ทราบให้คง `null` ห้ามอนุมาน Model 4 จาก prose และห้ามปลุกงานวิจัย EA ที่ปิดแล้ว

## เลือกเครื่องมือ

- DOM สำหรับข้อความที่มองเห็น; vision เมื่อ figure จำเป็นต่อ claim
- local tools สำหรับ hash, exact-Git search/export/tests
- GPT สำหรับ synthesis และ GPT Scrutiny แยกจาก author
- MT5/Hermes เฉพาะ contract execution ที่อนุญาต
- JEV, paid search และ vector database ไม่จำเป็นสำหรับ V1

## แก้ปัญหา

- pin/manifest/hash mismatch, duplicate ID, path escape หรือ symlink: หยุด ห้าม empty-success
- Knowledge view เสีย: view อื่นต้องยังใช้ได้ ตรวจ `knowledge_index.json` และ console
- offline ว่าง: ใช้ `READ_SECOND_BRAIN.html` ที่สร้างคู่กับ pin เดียวกัน; ไฟล์ไม่ fetch และไม่ต้อง login
- `EA` ต้องไม่ match `Seafood`: อังกฤษใช้ token boundary; ไทยใช้ substring
