อ่านและทำ re-audit ที่ `HEAD 42f9f70a` แบบ strictly read-only แล้ว ไฟล์เป้าหมายทั้งสี่ไม่ dirty แม้ repo ส่วนอื่นมี working-tree changes

## 22 findings เดิม

| # | สถานะ | หลักฐานสั้น |
|---:|---|---|
| 1 | **CLOSED** | Root มี `entity` + `oneOf`; แต่ละ entity มี `const` และ `unevaluatedProperties:false` จริง ([schemas.json:26](/D:/EA_LAB/_triage/factory_os/schemas.json:26), [schemas.json:41](/D:/EA_LAB/_triage/factory_os/schemas.json:41)) |
| 2 | **RESTATED** | §1.3 แก้ ownership แต่ §1.5/§4 กลับมาใช้ owners และ mutable fields เดิม ([design:104](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:104), [design:176](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:176)) |
| 3 | **MOVED-honest** | `ALL CLEAR` ย้ายไป `snapshot_validator`/S3; schema และ checker ยังไม่ได้คำนวณจริง ([schemas.json:510](/D:/EA_LAB/_triage/factory_os/schemas.json:510), [design:778](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:778)) |
| 4 | **MOVED-honest** | `make_status.ps1` ยังใช้ `SilentlyContinue` และอ่าน taskboard โดยตรง ([make_status.ps1:4](/D:/EA_LAB/scripts/make_status.ps1:4), [make_status.ps1:12](/D:/EA_LAB/scripts/make_status.ps1:12)) |
| 5 | **REGRESSED** | Schema แยก payload ถูก แต่ main design ยังบอกว่า ID คือ hash ของ manifest ทั้งก้อน ([schemas.json:325](/D:/EA_LAB/_triage/factory_os/schemas.json:325), [design:375](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:375)) |
| 6 | **RESTATED** | Candidate ยังไม่มี immutable evidence references/generator hash ที่ครบ ([schemas.json:328](/D:/EA_LAB/_triage/factory_os/schemas.json:328)) |
| 7 | **RESTATED** | “append-only JSONL” แต่ schema เป็น object ที่มี mutable `attempts[]` ([schemas.json:291](/D:/EA_LAB/_triage/factory_os/schemas.json:291)) |
| 8 | **REGRESSED** | `ExecutionKey` ใน schema ดีขึ้น แต่ Job manifest ใน design ยังขาด deposit/currency/effective-config ([schemas.json:243](/D:/EA_LAB/_triage/factory_os/schemas.json:243), [design:365](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:365)) |
| 9 | **RESTATED** | `experimental` required แต่ไม่มี machine condition ว่า Candidate promotion ต้องเป็น false; stability เป็นค่าที่ artifact อ้างเอง ([schemas.json:104](/D:/EA_LAB/_triage/factory_os/schemas.json:104), [schemas.json:333](/D:/EA_LAB/_triage/factory_os/schemas.json:333)) |
| 10 | **REGRESSED** | เพิ่ม `ParameterBinding` ถูก แต่ §4.2 ยังวาง `role` กลับบน global registry ([schemas.json:116](/D:/EA_LAB/_triage/factory_os/schemas.json:116), [design:335](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:335)) |
| 11 | **REGRESSED** | `MetricRef` แยก provenance ถูก แต่ Coverage contract หลักยังมี lane/fingerprint เดียว ([schemas.json:195](/D:/EA_LAB/_triage/factory_os/schemas.json:195), [design:356](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:356)) |
| 12 | **REGRESSED** | §5.5 มี seven-point parity แต่ pilot acceptance ยังใช้ห้ากรณีแบบ trade-list-centric ([design:451](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:451), [design:689](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:689)) |
| 13 | **CLOSED** | Deployment เปลี่ยนเป็น append-only event และ non-OBSERVED ต้องมี authorization ([schemas.json:398](/D:/EA_LAB/_triage/factory_os/schemas.json:398)) |
| 14 | **MOVED-honest** | เลือก global แล้ว แต่ S10 ถูก block จนกว่าผู้ใช้แก้ invariant ([PROJECT_STATE.md:182](/D:/EA_LAB/PROJECT_STATE.md:182), [design:785](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:785)) |
| 15 | **REGRESSED** | มี SafeProjection แล้ว แต่ raw `finding_id` ยังอาจบรรจุ account/magic/strategy identifier ([schemas.json:598](/D:/EA_LAB/_triage/factory_os/schemas.json:598)) |
| 16 | **MOVED-honest** | Delivery ledger และ FLAPPING policy ถูกเลื่อนไป S12 อย่างเปิดเผย ([design:787](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:787)) |
| 17 | **RESTATED** | ลำดับดีขึ้น แต่ S4 ยังไม่มี schema ที่ตรง snapshot จริง ([design:774](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:774)) |
| 18 | **MOVED-evasive** | ตาราง rollback เดิมยังบอก delete/drop/repoint; มีเพียงหมายเหตุด้านล่างว่าไม่ถูก ([design:728](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:728), [design:746](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:746)) |
| 19 | **MOVED-honest** | ~10,000 combinations ถูกยอมรับว่า unresolved ([design:832](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:832)) |
| 20 | **REGRESSED** | Schema ใช้ JSONL แต่ design หลายจุดยังใช้ CSV/YAML ([design:327](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:327), [design:356](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:356)) |
| 21 | **CLOSED** | WAITING บังคับทั้ง `waiting_for` และ `wake_condition` แล้ว ([schemas.json:454](/D:/EA_LAB/_triage/factory_os/schemas.json:454)) |
| 22 | **MOVED-honest** | S14 ถูก gate จนกว่าผู้ใช้แก้ permission table ([design:789](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:789), [AGENTS.md:79](/D:/EA_LAB/AGENTS.md:79)) |

## Findings ที่ยังไม่ปิด

### P0 — Ownership fork ยังอยู่

Why not closed: `WorkReceipt` ที่มี `order_ref` ยัง required `title`, `owner`, `status` ซึ่งเป็น facts ของ taskboard; `SystemFinding` เก็บ state โดยไม่มี snapshot `OwnerRef`; `CoverageCell.state` กลายเป็น owner ใหม่ก่อน owner transfer ได้รับ sign-off ([schemas.json:426](/D:/EA_LAB/_triage/factory_os/schemas.json:426), [schemas.json:466](/D:/EA_LAB/_triage/factory_os/schemas.json:466), [schemas.json:212](/D:/EA_LAB/_triage/factory_os/schemas.json:212)).

Failure scenario: Order เป็น REVIEWED แต่ Receipt ยัง IN_PROGRESS; snapshot detector RESOLVED แต่ SystemFinding OPEN; backlog และ coverage.jsonl แสดงคนละ state

Fix: S2 ต้องสร้าง owner-by-owner signed migration tableจริง จากนั้น:

- Receipt ที่มี Order ต้องเก็บเพียง `order_ref` และ receipt-only metadata
- SystemFinding ต้องมี pinned detector/snapshot reference
- Coverage transfer ต้องได้รับอนุมัติก่อน และ `MASTER_BACKLOG` ต้องกลายเป็น generated-only ใน cutover เดียวกัน

### P0 — Schema root ที่แก้แล้ว validate “คนละรูป” กับ snapshot จริง

`SnapshotMeta` ถูกประกาศว่า schema ของ `portfolio/control_room_snapshot.json` แต่ schema ต้องการ `{entity,schema,version,...}` แบบ flat ขณะที่ snapshot จริงเป็น `{meta:{schema,version,...}, system_health,...}` ([schemas.json:507](/D:/EA_LAB/_triage/factory_os/schemas.json:507), [control_room_snapshot.json:1](/D:/EA_LAB/portfolio/control_room_snapshot.json:1), [control_room_snapshot.ps1:372](/D:/EA_LAB/scripts/control_room_snapshot.ps1:372)).

Failure scenario: S3 มี negative fixtures ผ่านครบทุก “entity”; S4 สร้าง snapshot รูปเดิม; validator ไม่เคย validate canonical artifact จริง แต่ pipeline รายงาน schema-clean

Fix: เพิ่ม schema ของ full `ControlRoomSnapshotV5` ที่ตรง persisted document จริง โดยใช้ `SnapshotMeta` เป็น schema ของ `meta` property ไม่ใช่ root entity แยก

### P1 — `ALL CLEAR` และ compatibility outputs ยังเป็น future code

`all_clear` ถูก required ใน persisted object แต่คำอธิบายบอกให้ rejectค่าที่ writer ส่งมา จึงต้องมี input/output boundary ที่ยังไม่ได้กำหนด ตัว checker ปัจจุบันตรวจเพียงโครงสร้าง dictionary ไม่ได้เรียก JSON Schema validator หรือคำนวณ reconciliation ([schemas.json:512](/D:/EA_LAB/_triage/factory_os/schemas.json:512), [check_schema_structure.py:41](/D:/EA_LAB/_triage/factory_os/check_schema_structure.py:41)).

Failure scenario: counts ไม่สมดุลแต่ `all_clear:true`; structural checker ยังพิมพ์ `STRUCTURE OK`

Fix: แยก builder-input กับ persisted-output contract; validator คำนวณค่าเองและมี negative fixtures missing/unreadable/stale/count mismatch ทุกกรณี จากนั้น S4 จึงเปลี่ยน `make_status` ให้รับเฉพาะ validated snapshot

### P1 — Candidate identity ยังมีสองนิยามและ lineage ไม่ครบ

Main design ยังนิยาม hash ของ “canonical manifest” ขณะที่ schema นิยาม hash เฉพาะ payload; canonical JSON serialization ไม่ถูกกำหนด; `generator_version` ไม่ใช่ hash; `evidence` เป็น MetricRef ที่คัด PF/trades/DD แทน immutable EvidenceRef และไม่มี report hash ([design:224](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:224), [schemas.json:325](/D:/EA_LAB/_triage/factory_os/schemas.json:325)).

Failure scenario: serializer สองตัวเรียง key/number ต่างกันได้ digest ต่างกัน หรือรายงานถูกเปลี่ยนแต่ MetricRef เดิมยังสร้าง Candidate เดิมได้

Fix: กำหนด canonicalization แบบเดียว, ตรวจ `candidate_id == digest[:12]`, hash generator artifact, และใช้ content-addressed EvidenceRef ต่อ run/window

### P1 — Run journal ยังไม่ crash-safe ตามรูป storage

`factory/runs/<run_id>.jsonl` ขัดกับ `RunJournal` ที่บรรจุ `attempts[]`; การ append transition จึงต้อง rewrite object หรือเขียน snapshots ซ้ำ นอกจากนี้ lease บังคับ PID ตั้งแต่ LEASED ก่อน process มีจริง และ `launched_at` “ก่อน launch” แยก crash-before-launch ออกจาก crash-after-launch ไม่ได้ ([schemas.json:264](/D:/EA_LAB/_triage/factory_os/schemas.json:264), [schemas.json:291](/D:/EA_LAB/_triage/factory_os/schemas.json:291)).

Failure scenario: persist `launched_at` แล้วเครื่องดับก่อนสร้าง process; resume เข้าใจว่ามี process หรือ double-launch

Fix: JSONL หนึ่ง transition ต่อบรรทัด, atomic launch-intent, PID/process fingerprint หลัง spawn, monotonic transition validator และ reconciliation กับ process/report/event store

### P1 — Registry, provenance และ parity contracts ยังขัดกันเอง

Schema ใหม่วาง ParameterBinding/per-metric provenanceถูก แต่ main design ยังใช้ global roles, flat Coverage row และ pilot checklistเก่า S13 อ้าง §8.6 จึงสามารถผ่านด้วยห้ากรณีที่ไม่ตรวจ seven-point parity ([design:335](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:335), [design:704](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:704), [design:788](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:788)).

Fix: แก้ contract หลักและ pilot checklist ไม่ใช่เพิ่ม correction note; acceptance ต้องระบุ seven points + must-trade + deliberate-refusal โดยตรง

### P1 — Global magic transition “พอป้องกันได้” แต่ยังไม่พร้อม build

ความขัดกันระหว่าง running invariant `account|magic` กับ future global scope เป็น transitional inconsistency ที่ defensible เพราะ S10 ถูก block ชัดเจน และสาม collision ถูกยืนยันจริง ([PROJECT_STATE.md:62](/D:/EA_LAB/PROJECT_STATE.md:62), [DEPLOYMENTS.csv:2](/D:/EA_LAB/portfolio/DEPLOYMENTS.csv:2)).

แต่ schema ยังอนุญาตสร้าง `LEGACY_ACCOUNT_SCOPED` exception ใหม่ได้ไม่จำกัด และไม่บังคับ `legacy_accounts`/`legacy_exception` ให้สัมพันธ์กัน ([schemas.json:377](/D:/EA_LAB/_triage/factory_os/schemas.json:377)).

Fix: แก้ Decision log ก่อน S10 และ encode exact imported exception set; หลัง cutoverห้าม mint legacy exception ใหม่

### P1 — SafeProjection ยังรั่ว identifier

แม้บัญชีถูก mask แต่ `findings[].finding_id` เป็น string ดิบ ขณะที่ SystemFinding stable key สามารถมี account, magic หรือ strategy name ได้ ([schemas.json:475](/D:/EA_LAB/_triage/factory_os/schemas.json:475), [schemas.json:598](/D:/EA_LAB/_triage/factory_os/schemas.json:598)).

Failure scenario: `FND-sensor-159503454` หลุดไป Telegram/online page

Fix: ใช้ opaque public finding ID หรือ projection-local token และเพิ่ม recursive value-pattern fixtures ไม่ใช่ตรวจเฉพาะชื่อ key

### P1 — Alert ledger ยังขาด และ contract หลักยังใช้ dedupe เก่า

§7.3 ยังบอก dedupe ด้วย `finding id + state`; `material_revision` ใน schema เป็น optional และไม่มี per-channel delivery receipt ([design:629](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:629), [schemas.json:478](/D:/EA_LAB/_triage/factory_os/schemas.json:478)).

Fix: delivery event ID + channel receipt + required material revision/severity + recovery/flapping transition table ก่อน S12

### P1 — Slice แรกที่ยัง build ไม่ได้โดยไม่ประดิษฐ์ behavior คือ S4

S2 ทำ ownership proposal/sign-off ได้ และ S3 ทำ entity validator ได้ แต่ S4 ต้องตัดสินเองว่า snapshot v5 เป็น full document รูปเดิมหรือ `{entity:"SnapshotMeta"}` envelope รวมถึงจุดที่ `all_clear` ถูกคำนวณและจุดที่ input ถูก reject ซึ่ง design ยังตอบไม่ได้ ([design:779](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:779)).

หลังจากนั้น S5 ยังติด storage format/Core Universe และ S10 ติด magic/artifact-store decisions

### P1 — Rollback ยังเป็นคำเตือน ไม่ใช่แผน executable

ตาราง canonical ยังบอก `drop file`, `delete receipts`, `repoint old page`; correction noteยอมรับว่าทำไม่ได้แต่ไม่ได้แทนที่ตารางด้วยขั้นตอน reverse projection, cutover gate หรือ event-delivery rollback ([design:728](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:728), [design:746](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:746)).

Fix: เปลี่ยนตารางจริง พร้อม rollback acceptance test และเพิ่ม slice สำหรับ artifact restore/event replay drill

### P1 — รายการ “สี่ owed + สาม unresolved” ไม่ครบ

สี่ owed ถูกบันทึกที่ [PROJECT_STATE.md:100](/D:/EA_LAB/PROJECT_STATE.md:100) แต่ §11 มี unresolved เก้าข้อ ไม่ใช่สาม: token-guard rollout, old-set policy, artifact store/backup, Core Universe membership และ CSV-vs-JSONL ยังไม่ได้ปิด นอกเหนือจาก trial ladder, participation floor และ ~10k budget ([design:810](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:810), [design:818](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:818), [design:843](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:843)).

### P1 — Storage contract ยังมีสองแหล่งความจริง

Schema rev2 ใช้ JSONL แต่ §1.5, §4, generated wrapper comment และ pilot acceptance ยังระบุ CSV/YAML รวมถึง causal claim/falsifier ที่ schemaห้าม copy ([design:176](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:176), [design:327](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:327), [design:705](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:705)).

Fix: ratifyหนึ่ง format แล้วแก้ ownership map, schema, examples, generators และ acceptance checklistพร้อมกัน

### P2 — Factual/internal regressions

- ยังเขียน Boss wrapper 13 lines ทั้งที่ auditวัด 12 ([design:855](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:855))
- Summary กลับมาเรียก “eleven unowned facts” ([design:862](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:862))
- Summary บอก unresolved six แต่ §11 มีเก้า ([design:868](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:868))
- committed snapshot fixture ยัง v3 แต่ generator HEAD สร้าง v4 ([control_room_snapshot.json:2](/D:/EA_LAB/portfolio/control_room_snapshot.json:2), [control_room_snapshot.ps1:375](/D:/EA_LAB/scripts/control_room_snapshot.ps1:375))

## Schema-root judgment

Composition ของ root discriminator ถูกต้องตาม Draft 2020-12: `$ref` มี sibling keywords ได้ และแต่ละ referenced entity ประกาศ `entity` ของตัวเอง จึงไม่ชนกับ `unevaluatedProperties:false` ([JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12)).

พฤติกรรมที่คาดจาก compliant validator:

- unknown `entity` → reject
- entity ที่ขาด required field → reject
- extra property → reject

แต่ใน workspace ไม่มี `ajv`, `jsonschema`, Docker หรือ validator Draft 2020-12 ที่ติดตั้งอยู่ และ brief ห้ามติดตั้ง package จึงทดสอบ engine จริงไม่ได้ ตัว `check_schema_structure.py` ผ่าน แต่เป็นเพียง schema linter ไม่ใช่ validator cage

## ทางเลือกที่เล็กกว่า

เส้นทางปลอดภัยที่สุดยังเป็น ownership contract → full-snapshot schema/real validator → fail-closed snapshot/compatibility เท่านั้น แล้วหยุด re-audit อีกครั้งก่อน registries, scheduler, Candidate และ UI เต็มชุด

## NO-GO

**NO-GO สำหรับแตก design ปัจจุบันเป็น implementation orders S2–S15** เนื่องจาก P0 ownership ยังไม่ปิด และ schema contract ยัง validate คนละรูปกับ canonical snapshot จริง

คำถามใหญ่ที่สุดที่ design ตอบไม่ได้:

> Snapshot v5 ที่ persist จริงต้องคงรูป `{meta, system_health, deployments, ...}` เดิม หรือเปลี่ยนเป็น `{entity:"SnapshotMeta", ...}`? จนกว่าจะเลือกและทำ schema ให้ตรง artifact จริง S3/S4 สามารถรายงาน “validated” ทั้งที่ไม่ได้ validate Control Room snapshot เลย