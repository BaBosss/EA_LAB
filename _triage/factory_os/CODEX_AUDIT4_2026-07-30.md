# Codex blind audit #4 — 2026-07-30 — the design↔schema binding (BACKLOG-D31)

**Verbatim reply, unedited.** Codex did not write this file itself: the brief
(`CODEX_AUDIT4_BRIEF.md`) said STRICTLY READ-ONLY in one line and told it to write a report in
another. That contradiction is the brief's defect, not the auditor's — it read the stronger
constraint and returned the report in chat. Fix the brief before dispatching audit 5.

Subject commits: `8cbb44e6` · `072c303a`. Response committed in `1ad7b17d`.

---

ผล Audit #4: **GO เฉพาะการเขียน Orders สำหรับ S2a และ S3a** ตามขอบเขต preparatory เท่านั้น แต่ **Factory OS design โดยรวมยัง NO-GO สำหรับ implementation orders ถัดไป**

ไม่ได้สร้าง `CODEX_AUDIT4_2026-07-30.md` เพราะ brief บรรทัด 3 กำหนด STRICTLY READ-ONLY จึงส่งรายงานในแชตแทน

## Q1 — Binding จริงหรือผ่านโดย construction?

**Verdict: binding เป็น synchronization check ที่ใช้งานได้ แต่ 7/7 ไม่ใช่ semantic proof; controls สองตัวผ่านโดย construction และ deleted-block control เป็น tautology**

เมื่อ baseline ปัจจุบันสะอาด ทั้งเจ็ด mutation เปลี่ยนข้อมูลที่ generator พิมพ์โดยตรง จึงแทบรับประกันว่าจะเกิด diff:

| Case | สิ่งที่พิสูจน์จริง | Non-tautological test ที่ต้องมี |
|---|---|---|
| #5 candidate ID | field/required เปลี่ยนแล้วตารางเปลี่ยน | validate payload ที่มี `candidate_id` แล้วต้อง reject |
| #8 deposit | ลบ field แล้วตารางเปลี่ยน | ExecutionKey ไม่มี deposit ต้อง reject |
| #10 global role | เปลี่ยนข้อความ row แล้วตารางเปลี่ยน | `optimize_guard` ต้องยอมให้ parameter เดียวกันมี role ต่างกันตาม hypothesis |
| #11 flat lane | เพิ่ม field แล้วตารางเปลี่ยน | MAIN/BWD คนละ lane ต้องถูก coverage validator ปฏิเสธ |
| #12 parity 2c | ลบ row แล้วตารางเปลี่ยน | parity harness ต้อง refuse หาก required case set ขาด `2c` |
| #15 finding ID leak | เพิ่ม field แล้วตารางเปลี่ยน | SafeProjection ที่มี raw `finding_id` ต้อง reject—AJV fixture ปัจจุบันทำข้อนี้แล้ว |
| #20 CSV owner | เปลี่ยน owner string แล้วตารางเปลี่ยน | round-trip typed registry ผ่าน CSV ต้องถูกปฏิเสธหรือพิสูจน์ว่า lossless |

ทุกกรณีอาจ fail เพราะสาเหตุอื่น เช่น schema structure เปลี่ยนจน mutator หา path ไม่เจอ, committed design stale หรือ renderer เปลี่ยนรูปแบบ witness ไม่ใช่เพราะ defect กลับมาโดยตรง ([binding tests:126](/D:/EA_LAB/_triage/factory_os/run_contract_binding_tests.py:126), [binding tests:136](/D:/EA_LAB/_triage/factory_os/run_contract_binding_tests.py:136)).

Controls:

- `no-op` รับประกัน GREEN เพราะ mutation ไม่ทำอะไร
- `rationale-only` รับประกัน GREEN เพราะ generator จงใจไม่ render definition-level description ([binding tests:86](/D:/EA_LAB/_triage/factory_os/run_contract_binding_tests.py:86))
- deleted-block control รับประกัน RED จาก `caught = 'ExecutionKey' not in keys`; มันไม่ได้เรียก coverage validation ใน `main()` ตามข้อความที่อ้าง ([binding tests:170](/D:/EA_LAB/_triage/factory_os/run_contract_binding_tests.py:170))

## Q2 — Escape hatches

**Verdict: มีหลายทางที่ design กับ contract จริงแยกจากกันโดยทุก cage ยังเขียว**

1. **Normative prose นอก generated block**

   ผมเปลี่ยน §6.4 ในหน่วยความจำจาก “ทุก A/B ต้องอยู่ lane เดียว” เป็น “อาจข้าม lane” ([design:1215](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:1215)) ผลคือ `generated_diff=False`—generator และ binding ไม่เห็นการเปลี่ยนนี้เลย

2. **`x-enforced-by` ระบุชื่อ validator แต่ไม่ได้พิสูจน์ว่า validator มีหรือทำงาน**

   สร้าง snapshot ที่ประกาศ mandatory source แต่ `sources=[]` และ `all_clear=true`; AJV รายงาน `valid` เพราะสมการอยู่ใน description/`x-enforced-by` ไม่ใช่ JSON Schema ([schemas:598](/D:/EA_LAB/_triage/factory_os/schemas.json:598), [schemas:631](/D:/EA_LAB/_triage/factory_os/schemas.json:631), [schemas:677](/D:/EA_LAB/_triage/factory_os/schemas.json:677)).

3. **Schema constraint ที่ renderer ไม่รองรับหายจาก generated contract**

   ลบกฎห้าม WorkReceipt ที่มี `order_ref` copy `title`; ผล `generated_diff=False` เพราะ conditional renderer ข้าม `if` ที่มีเพียง `required` และไม่มี `properties` ([generator:158](/D:/EA_LAB/_triage/factory_os/gen_design_contracts.py:158), [schemas:534](/D:/EA_LAB/_triage/factory_os/schemas.json:534)). ตาราง generated แสดง WAITING/CANCELLED/HANDOFF แต่ไม่แสดง ownership conditional นี้ ([design:932](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:932)).

4. **`_why` สามารถถือข้อความ normative โดยไม่มีใครเห็น**

   เปลี่ยน `_why` เป็น “parity may ignore init failures”; ผล `generated_diff=False` ส่วน `note` เท่านั้นที่ render ([generator:268](/D:/EA_LAB/_triage/factory_os/gen_design_contracts.py:268), [schemas:46](/D:/EA_LAB/_triage/factory_os/schemas.json:46)).

5. **Malformed generated markers บางรูปแบบผ่าน**

   เพิ่ม stray `BEGIN` หรือ `END` marker นอก blocks: generator ยังเห็น 27 blocks, ไม่มี missing/duplicate และจะคืน OK เพราะ regex มองเฉพาะคู่ marker ที่สมบูรณ์ ([generator:47](/D:/EA_LAB/_triage/factory_os/gen_design_contracts.py:47), [generator:332](/D:/EA_LAB/_triage/factory_os/gen_design_contracts.py:332)).

## Q3 — Conversion loss

**Verdict: sentence เรื่อง seven-point parity ถูกคืนแล้ว แต่ยังมี normative Run facts ที่หายจาก design**

สิ่งที่หายและยังไม่กลับ:

- `RunTransition.record` เคยระบุว่าเป็น **per-state record**; ปัจจุบัน generated table แสดงเป็น optional โดยไม่มี conditional requirement ([design:667](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:667), [schemas:352](/D:/EA_LAB/_triage/factory_os/schemas.json:352)).
- Lease เคยระบุว่าต้องมี `lease_id`, `owner`, `expires_at`; generated design เหลือเพียง `object|null` ([schemas:311](/D:/EA_LAB/_triage/factory_os/schemas.json:311), [design:684](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:684)).
- `process_observed` เคยระบุ `pid`, `observed_at`, `process_fingerprint`; generated designไม่แสดง nested fields ([schemas:322](/D:/EA_LAB/_triage/factory_os/schemas.json:322), [design:686](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:686)).

สาเหตุคือ `walk_fields()` recurse เฉพาะ `type == "object"` แต่สามกรณีใช้ `type: ["object","null"]` ([generator:138](/D:/EA_LAB/_triage/factory_os/gen_design_contracts.py:138)). `ParameterBinding.safe_range.start/step/stop` ถูกละทิ้งด้วยสาเหตุเดียวกัน แม้ไม่ใช่ข้อความที่ถูกลบใน commit 8cbb44e6.

ข้อกำหนด seven-point parity ที่เคยหายถูกคืนใน 072c303a แล้ว ([design:1395](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:1395)). จากบรรทัดที่ถูกลบทั้งหมด ไม่พบ normative loss อื่นนอกเหนือจากกลุ่มข้างต้น

## Q4 — Cage honesty

**Verdict: fail-closed สำหรับ dependency/file/JSON failure ทั่วไป แต่ไม่ fail-closed สำหรับ malformed marker และ semantic omissions**

ผลรันจริง:

- `gen_design_contracts.py --check`: exit 0, **0.369s**
- binding tests: exit 0, **0.071s**
- schema fixtures: exit 0, **5.184s**, 17/17
- fast cages: exit 0, **11/11 suites**, internal **13.1s**, wall **13.455s**

งบ 15s เหลือประมาณ 1.5–1.9s. Binding เพิ่มเพียง 0.4s จึงยังไม่ถึงจุดที่สมเหตุผลจะใช้ `--no-verify` แต่ tier ใช้งบแล้วราว 87–90%; การเกินงบเป็นเพียง warning ไม่ทำให้ hook fail ([fast cages:193](/D:/EA_LAB/scripts/_test/run_fast_cages.ps1:193)).

พฤติกรรม fail-closed:

- Python หาย: wrapper exit 1 ([wrapper:39](/D:/EA_LAB/scripts/_test/run_contract_binding_tests.ps1:39))
- child script หาย: exit 1 ([wrapper:55](/D:/EA_LAB/scripts/_test/run_contract_binding_tests.ps1:55))
- design/schema หาย หรือ schema JSON parse ไม่ได้: Python exception ทำ child exit nonzero และ wrapper fail
- design ไม่มี generated blocks หรือขาด block สมบูรณ์: fail
- stray/unpaired marker: **ผ่าน** ตาม failing case ใน Q2

## Q5 — S2a/S3a

**S2a: GO**

เขียน Order สำหรับ Coverage ownership proposal + migration table ได้ เพราะเป็นการสร้างหลักฐานและข้อเสนอ ไม่ใช่การโอน canonical ownership จริง การโอนยังต้องรอ owner sign-off ตาม [design:648](/D:/EA_LAB/_triage/EA_LAB_FACTORY_OS_DESIGN.md:648).

**S3a: GO**

เขียน Order สำหรับ pin validator/runtime และ regression fixtures ได้ โดย acceptance ต้องครอบคลุมอย่างน้อย:

- mandatory source หาย/unreadable ⇒ ไม่ `ALL CLEAR`
- supplied `all_clear` ไม่ถูกเชื่อ
- discovered/category และ coverage equations ไม่สมดุล ⇒ reject
- validator อ่าน persisted whole-document shape ไม่ใช่ meta object แยก

S3a ยังไม่ใช่การประกาศว่า S3/S4 เสร็จ; input → computed reconciliation → persisted output boundary ยังคงต้องถูกกำหนดในงานนี้

## Q6 — สิ่งที่ยังค้าง

**Blocks writing downstream implementation Orders**

1. เปลี่ยน binding fixtures จาก “schema mutation ทำให้เอกสารเปลี่ยน” เป็น independent behavioral oracles
2. กำหนด all-clear input/output boundary
3. Coverage ownership sign-off ก่อน canonical transfer

**Blocks buildingแต่ไม่ block S2a/S3a**

1. สร้างและทดสอบ validators ทุกตัวที่ถูกอ้างใน `x-enforced-by`
2. เพิ่ม transition-specific requirements ของ Run model
3. นิยาม canonical candidate serialization
4. exact legacy-magic import allowlist
5. governance/permission approvals ที่ S10/S14 ต้องใช้

**แก้ใน slice ที่แตะได้**

- render nullable nested objects
- render หรือ refuse unsupported JSON Schema keywords
- ตรวจ unmatched markers
- เรียก coverage validator จริงใน deleted-block control
- อัปเดตคำอธิบาย fast tier ที่ยังบอกว่า “four fast cages” ทั้งที่รัน 11

**Overall: GO เฉพาะ S2a/S3a; ห้ามตีความว่า S2, S4, S10 หรือ S14 ถูกปลดบล็อก**

::code-comment{title="[P1] Deleted-block control is tautological" body="The control never invokes the generator's coverage-validation path. It declares the block caught merely because the same block key it deleted is absent. Factor coverage validation into a callable function and assert that function returns failure for the mutated document." file="D:/EA_LAB/_triage/factory_os/run_contract_binding_tests.py" start=170 end=184 priority=1}

::code-comment{title="[P1] Nullable nested contracts disappear" body="walk_fields only descends when type equals the scalar string object. Nullable objects such as safe_range, lease, and process_observed therefore lose all nested required fields from the generated design." file="D:/EA_LAB/_triage/factory_os/gen_design_contracts.py" start=138 end=143 priority=1}

::code-comment{title="[P1] Conditional contract silently omitted" body="render_conditionals ignores conditions expressed through required without properties and does not render else branches or then.not/anyOf. The WorkReceipt order_ref anti-copy rule can therefore be removed without changing the generated document." file="D:/EA_LAB/_triage/factory_os/gen_design_contracts.py" start=158 end=180 priority=1}

::code-comment{title="[P2] Unmatched generated markers pass" body="The regex recognizes only complete matching marker pairs. Extra unmatched BEGIN or END markers are invisible to duplicate, coverage, and staleness checks, so a malformed design can still report OK." file="D:/EA_LAB/_triage/factory_os/gen_design_contracts.py" start=47 end=51 priority=2}