ตรวจที่ `HEAD 2bf3bb42` แบบ read-only แล้ว ไฟล์เป้าหมายทั้งสามไม่ dirty; working-tree changes อื่นไม่กระทบผลนี้

## Q1 — P0 ทั้งสองข้อ

### P0-A Ownership — NOT CLOSED

สองในสามส่วนแก้จริง:

- `WorkReceipt` ไม่ required taskboard-owned fields แล้ว และเมื่อมี `order_ref` จะห้ามเก็บ `title/owner/status/acceptance` ([schemas.json:469](/D:/EA_LAB/_triage/factory_os/schemas.json:469), [schemas.json:497](/D:/EA_LAB/_triage/factory_os/schemas.json:497))
- `SystemFinding` required `detector_ref` ที่ pin owner แล้ว ([schemas.json:518](/D:/EA_LAB/_triage/factory_os/schemas.json:518))

แต่ Coverage ยังไม่ปิด:

- `MASTER_BACKLOG.md` ยังประกาศ ownership ของ coverage matrix ([MASTER_BACKLOG.md:3](/D:/EA_LAB/MASTER_BACKLOG.md:3))
- `CoverageCell` required mutable `state` และประกาศ `factory/coverage.jsonl` เป็น owner ทันที ขณะที่ `backlog_ref` เป็น optional และไม่มี `ownership_transfer_ref` หรือ `shadow_only` gate ([schemas.json:213](/D:/EA_LAB/_triage/factory_os/schemas.json:213))
- Design ยอมรับว่าต้องรอ S2 sign-off ([design:397](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:397)) แต่ schema ยังสร้าง fork ได้ก่อน sign-off

การ defer ไป S2 เป็นการเลื่อนอย่างซื่อสัตย์ แต่ยังไม่ใช่การปิด P0

Minimum fix: ก่อน sign-off ทุก CoverageCell ต้องเป็น `SHADOW_IMPORT` และ required `backlog_ref`; หลัง sign-offต้องมี immutable `ownership_transfer_ref` แล้วจึงอนุญาต canonical state

### P0-B Snapshot shape — NOT CLOSED

การแยก `ControlRoomSnapshotV5` เป็น whole document และวาง `SnapshotMeta` ไว้ใต้ `meta` แก้ความผิดพลาดเรื่อง flat root ถูกทาง ([schemas.json:561](/D:/EA_LAB/_triage/factory_os/schemas.json:561)) แต่ยังไม่ตรง additive contract จริง:

- snapshot ที่ HEAD มี `meta.stale_bar_hours`, `decision_bar_trades`, `counting_method` ([control_room_snapshot.json:2](/D:/EA_LAB/portfolio/control_room_snapshot.json:2))
- `SnapshotMeta` ปิดด้วย `unevaluatedProperties:false` แต่ไม่ได้ประกาศสาม field เหล่านั้น ([schemas.json:582](/D:/EA_LAB/_triage/factory_os/schemas.json:582))
- source rows จริงใช้ `path/sha256/mtime/age_hours`; schema v5 ปิด item และยอมเฉพาะ `name/mandatory/read_ok/fresh/age_hours` ([control_room_snapshot.json:9](/D:/EA_LAB/portfolio/control_room_snapshot.json:9), [schemas.json:595](/D:/EA_LAB/_triage/factory_os/schemas.json:595))
- Whole-document schema required เพียง `entity/meta/system_health/summary`; stable keys อีกหกรายการเป็น optional และ known payloads เช่น `system_health`/`summary` แทบไม่ถูก constrain ([schemas.json:566](/D:/EA_LAB/_triage/factory_os/schemas.json:566))

`additionalProperties:true` ที่ root ใช้รองรับ future top-level domains ได้ แต่ไม่ควรใช้แทน schema ของ known domains ปัจจุบัน ตัวอย่าง snapshot ที่มี valid meta แต่ `system_health:[{}]`, `summary:{}` และไม่มี deployments จะผ่าน

Minimum fix: define stable v4 fieldsทั้งหมดใน v5, preserve existing meta/source fieldsตาม additive rule, require stable top-level domains และ validate known domain shapes; เปิดเฉพาะ future extension namespace

## Q2 — สิ่งใหม่และ crash walk

### New defects

1. **Design กับ schema ขัดกันอีกแล้วหลัง self-review:** design ยังบอก `attempts[]`, lease มี `pid`, และใช้ `launched_at` ([design:401](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:401)); schema ใช้ one-transition-per-line, PID อยู่ใน `process_observed`, และแยก `launch_intent_at` ([schemas.json:265](/D:/EA_LAB/_triage/factory_os/schemas.json:265), [schemas.json:299](/D:/EA_LAB/_triage/factory_os/schemas.json:299)). Binding checkerยังผ่าน

2. **RunTransition มี identity ซ้ำสองชุด:** outer object มี `attempt/transition/at` แล้ว `record` อ้าง `RunAttempt` ซึ่งมีสาม fieldเดียวกันอีกครั้ง ทั้งสองชุดสามารถขัดกันได้ ([schemas.json:268](/D:/EA_LAB/_triage/factory_os/schemas.json:268), [schemas.json:305](/D:/EA_LAB/_triage/factory_os/schemas.json:305))

3. **ไม่มี transition-specific requirements:** `execution_key`, `record`, lease, launch intent, process observation, exit code, freshness proof และ event ref เป็น optional ทั้งหมด ([schemas.json:305](/D:/EA_LAB/_triage/factory_os/schemas.json:305))

4. **Magic legacy set ยังไม่ closed จริง:** schema บังคับเพียง boolean `imported_in_cutover` แต่ไม่ได้บังคับ `true`, exact three magics หรือ exact account pairs ([schemas.json:405](/D:/EA_LAB/_triage/factory_os/schemas.json:405)). Checkerกลับรายงานว่าเป็น “closed imported set” หลังตรวจเพียงว่ามี `legacy_accounts` ([check_schema_structure.py:90](/D:/EA_LAB/_triage/factory_os/check_schema_structure.py:90))

### Crash-transition table

สมมติ transition ถูก append สำเร็จก่อนเครื่องดับ:

| Last transition | Resume รู้ได้ | Resume ยังรู้ไม่ได้ |
|---|---|---|
| `QUEUED` | มีงานที่ยังไม่เริ่ม | Schema ไม่บังคับ `execution_key` บนบรรทัดนี้ จึงอาจสร้างงานเดิมกลับมาไม่ได้ |
| `LEASED` | ถ้า record ครบ จะรู้ lease owner/expiry | Schema ไม่บังคับ record หรือ lease; ต้อง reconcile lease file แยก |
| `LAUNCH_INTENT` | รู้ว่ามีเจตนา spawn และต้องไม่ launch ซ้ำทันที | แยกไม่ได้ระหว่าง “ดับก่อน spawn” กับ “spawn แล้ว process จบก่อน PROCESS_OBSERVED” เมื่อไม่เหลือ process/report |
| `PROCESS_OBSERVED` | รู้ว่าเคยเห็น PID ณ เวลาหนึ่ง | PID อาจจบหรือถูก reuse; `process_fingerprint` optional และยังไม่รู้ exit code |
| `RUNNING` | รู้ว่า process เคยเข้าสู่ running; ตรวจ OS/report ต่อได้ | หาก process จบก่อน persist exit code จะแยก success/failureไม่ได้จาก journal เพียงอย่างเดียว |
| `COMPLETED` | ควรถือว่าไม่ rerun | Schema ไม่บังคับ exit code หรือ fresh-report proof จึงพิสูจน์ไม่ได้ว่า completion valid |
| `FAILED` | รู้ว่าถูกจัดเป็น failure | `failure_class` ไม่ required จึงตัดสินไม่ได้ว่า retry ได้เฉพาะ tester/terminal error หรือไม่ |
| `EVIDENCE_REGISTERED` | ควรถือว่า event ถูก register | `event_id`/`event_log_ref` ไม่ required จึงพิสูจน์ registration จาก journal ไม่ได้ |

State pairs ที่ยัง indistinguishable:

- `LAUNCH_INTENT` ก่อน spawn ↔ spawn แล้ว exit ก่อน observation
- `PROCESS_OBSERVED/RUNNING` แล้ว process หาย: clean exit ↔ crash/failure หากไม่มี fresh report/exit code
- `COMPLETED` ก่อน append evidence ↔ evidence append สำเร็จแต่ดับก่อน marker หากไม่มี event reference

Fix: ใช้ one `RunTransition` schema โดยไม่ซ้ำ `RunAttempt` identity และทำ conditional `oneOf` ต่อ transition พร้อม required payload ของแต่ละ state

## Q3 — Binding checker

### สิ่งที่จับได้จริง

- Root/discriminator/branch consistency ([check_schema_structure.py:12](/D:/EA_LAB/_triage/factory_os/check_schema_structure.py:12))
- การมี `unevaluatedProperties:false` ตามรายการที่ hardcode ([check_schema_structure.py:29](/D:/EA_LAB/_triage/factory_os/check_schema_structure.py:29))
- selected field-presence spot checks เช่น `detector_ref`, `public_id`, `material_revision` ([check_schema_structure.py:70](/D:/EA_LAB/_triage/factory_os/check_schema_structure.py:70))
- storage path จาก `x-owner-file` ปรากฏเป็น substring ที่ใดสักแห่งใน design ([check_schema_structure.py:122](/D:/EA_LAB/_triage/factory_os/check_schema_structure.py:122))
- exact banned phrases สี่ข้อความ ([check_schema_structure.py:133](/D:/EA_LAB/_triage/factory_os/check_schema_structure.py:133))

### สิ่งที่พลาดแน่นอน

- ความหมายของ fields, required conditions และ state transitions
- ข้อความที่ขัดกันสองส่วนแต่มี storage path ถูกต้อง
- path ที่ถูกกล่าวถึงใน history/คำเตือน แต่ active contract ยังผิด
- synonyms/case/punctuation ของ false claim
- actual JSON Schema validation และ real fixtures
- owner sign-off, exact legacy allowlist, hash semantics และ privacy values
- design contractเก่าที่บอก `pid/launched_at/attempts[]`—ตัวอย่างสดที่ HEAD ซึ่ง checkerผ่านอยู่ตอนนี้

Hardcoded banned strings เป็น regression reminders ที่มีประโยชน์ แต่ไม่ใช่ durable binding mechanism; false claim ใหม่หนึ่งประโยคไม่อยู่ใน list ก็ผ่านทันที

### เทียบ 7 REGRESSED findings เดิม

| Finding | จับ semantic defect ได้หรือไม่ | เหตุผล |
|---|---|---|
| #5 Candidate ID สองนิยาม | **No** | ตรวจแค่ว่ามี candidate path/digest fields ไม่เปรียบเทียบนิยาม hash |
| #8 ExecutionKey fields หายจาก design | **No** | ไม่ parse field listใน design |
| #10 Role อยู่ global registry | **No** | การกล่าวถึง `parameter_bindings.jsonl` ที่ใดก็ได้ทำให้ผ่าน แม้ active contract ยังวาง role ผิด |
| #11 Flat lane/fingerprint | **No** | ไม่เปรียบเทียบ Coverage fields กับ `MetricRef` |
| #12 Pilot ใช้ parity ห้ากรณี | **No** | ไม่มี machine assertionต่อ §8.4/§8.6 |
| #15 SafeProjection ปล่อย raw finding ID | **No** | path presenceไม่ตรวจ privacy surface fields |
| #20 JSONL vs CSV/YAML | **Yes, เฉพาะรูปเดิม** | exact JSONL owner pathที่ไม่ปรากฏจะ fail แต่เพียงเพิ่มข้อความ JSONL ใน historyก็ทำให้ผ่านได้ แม้ active tableยังเป็น CSV |

ใน revision เก่า checkerนี้จะ fail หลาย missing paths โดยบังเอิญ แต่ไม่ได้แปลว่ามันพบ semantic cause

### Binding ที่เพียงพอจริง

- ทำ machine-readable contract manifest หนึ่งชุดที่ระบุ owner, storage, canonical/derived, fields, identity/hash payload, transitions, permission, privacy surface และ ownership gate
- Generate normative Markdown tables จาก manifest/schema; proseเขียนเฉพาะ rationale ห้ามพิมพ์ field/state contract ซ้ำเอง
- Generate JSON Schema หรือ semantic assertions จาก source เดียวกัน
- ใช้ real Draft-2020-12 validator กับ valid/invalid fixtures รวมทั้ง actual snapshot fixture
- ทุก defectจากสาม auditต้องกลายเป็น negative regression fixture ไม่ใช่ banned sentence

## Q4 — S2–S4

### Verdict: NO-GO สำหรับแตก S2–S4 เป็น implementation orders เต็มรูปตอนนี้

ทำได้เพียง preparatory orders:

- **S2a ทำ ownership proposal/migration table ได้** แต่ canonical transfer ทำไม่ได้จน owner ของ `MASTER_BACKLOG` อนุมัติ
- **S3a เลือก/pin real validator และสร้าง regression fixtures ได้** แต่ all-clear validator จบไม่ได้จน input/output boundary ถูกกำหนด
- **S4 ยัง blocked** เพราะ full snapshot schema ไม่ preserve actual additive meta/source shape และ known domains ยังเปิดเกินไป

### Minimum blocking set

Decisions:

1. Owner ของ `MASTER_BACKLOG` อนุมัติหรือปฏิเสธ Coverage ownership transfer และกำหนด cutover commit/ref ([design:397](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:397))
2. เลือกและ pin Draft-2020-12 validator/runtime สำหรับ S3

Defects:

1. เพิ่ม machine-enforced shadow/transfer gate ให้ CoverageCell
2. แก้ `ControlRoomSnapshotV5` ให้รักษา actual v4 fieldsและ validate known domains
3. นิยาม builder-input → computed reconciliation → persisted-output boundary ของ `all_clear`
4. เปลี่ยน checkerจาก prose substring testเป็น generated contract + semantic fixtures

S5 onward ปล่อยเป็น design แล้ว revisit หลัง S2–S4 ได้; Run/Candidate/Magic defectsไม่ต้อง block monitoring foundation แต่ CoverageCell schema แม้อยู่ใน S5 ต้องถูกดึงมาแก้ ownership gateใน S2

### รายการ “still owed” ยังไม่ครบ

นอกจากสี่ข้อที่ผู้เขียนระบุ ยังขาด:

- `make_status.ps1` ยังอ่าน taskboardใต้ `SilentlyContinue` และแปลง read failureเป็น empty queue ([make_status.ps1:4](/D:/EA_LAB/scripts/make_status.ps1:4), [make_status.ps1:12](/D:/EA_LAB/scripts/make_status.ps1:12))
- Coverage ownership sign-off และ schema gate
- Snapshot additive compatibility/known-domain validation
- Run transition conditional contract และการลบ duplicate outer/inner fields
- Exact legacy-magic import allowlist
- Candidate evidence ยังเป็น mutable metricsแทน content-addressed EvidenceRef และ `generator_version` ยังไม่ใช่ hash ([schemas.json:353](/D:/EA_LAB/_triage/factory_os/schemas.json:353))
- Experimental promotion refusal ยังอยู่ใน description ไม่ใช่ machine condition ([schemas.json:361](/D:/EA_LAB/_triage/factory_os/schemas.json:361))
- Semantic design↔schema binding mechanism

§11 ยังมีเก้า decisions สำหรับ later slices และไม่ได้หายไป เพียงไม่ควร block preparatory S2a/S3a ([design:875](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:875))

ถ้าบังคับให้ผู้เขียนเปลี่ยนวิธีทำงานได้หนึ่งอย่าง: **หยุดแก้ normative contract ซ้ำด้วยมือ—ให้ generate design tables จาก machine-readable contract เดียว และห้ามเรียก finding ว่า fixed จน negative fixture ของ defectนั้น fail ก่อนและ pass หลัง**