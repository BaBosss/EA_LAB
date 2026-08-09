ตรวจแบบ read-only ที่ `HEAD f16fbf3a5669fa2118d89883e93871b3e8bde5fb` แล้ว ไม่มีการสร้าง/แก้/ย้าย/ลบไฟล์และไม่ได้แตะ git history

ไฟล์เป้าหมายไม่ dirty แต่ `AGENT_TASKBOARD.md` มี working-tree changes จาก session อื่น ผมจึงอ้างเฉพาะ `HEAD` ตามคำสั่ง

เป้าหมายของ design ในประโยคเดียว: เชื่อม owner เดิมให้เป็นระบบอัตโนมัติและสร้าง Control Center โดยไม่คัดลอกความจริงที่มีเจ้าของแล้ว (`_triage/EA_LAB_FACTORY_OS_DESIGN.md:40-47`)

ทางเลือกที่เล็กกว่าและปลอดภัยกว่า: เริ่มจาก snapshot adapter + fail-closed reconciliation + scheduler checkpoint เท่านั้น ใช้ taskboard/event log/evidence manifest เดิมโดยตรง เลื่อน Work Receipts, Idea Tank, Hypothesis Wizard, magic allocator และ Factory UI เต็มรูปออกไปจนกว่าสามแกนแรกผ่าน shadow mode

## Findings

> **[P0]** — `_triage/factory_os/schemas.json:19` — *Appendix ไม่ได้เป็น validator ที่ใช้งานได้จริง*
>
> **What is wrong:** schema ทั้งหมดอยู่ใต้ `$defs` แต่ root ไม่มี `type`, `properties`, `$ref`, `oneOf` หรือ `unevaluatedProperties:false` ดังนั้นการ validate instance กับไฟล์นี้ตรง ๆ ยอมรับ JSON แทบทุกชนิด การบังคับหลายข้อยังอยู่แค่ใน `description`; เช่น transition, immutability, permission และ `ALL CLEAR`
>
> **Failure scenario:** validator โหลด `schemas.json` เป็น root → `{}`, `{"all_clear":true}` หรือ Candidate ที่ขาดทุก field ผ่าน root schema → slice รายงาน “schema-valid” ทั้งที่ไม่มี contract ใดทำงาน
>
> **Suggested fix:** แยก schema ต่อ artifact หรือเพิ่ม root discriminator/`oneOf` ที่ `$ref` ไปยัง `$defs`; ระบุคำสั่ง validator ที่ต้อง validate exact `$defs/<Entity>` และเพิ่ม negative fixtures ของทุก entity

> **[P0]** — `_triage/EA_LAB_FACTORY_OS_DESIGN.md:92` — *คำอ้าง “สิบเอ็ด fact ยังไม่มี owner” ไม่จริง และทำให้ §20.7 แตกแขนง*
>
> **What is wrong:** governance บังคับ “links, never copies” (`PROJECT_STATE.md:32-45`) และ §20.7 จำกัด event/structured timeline ไว้ที่ occurrence metadata, hashes และ references (`_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md:881-889`) แต่ schema ใหม่เก็บ mutable status, PF/DD/trades, acceptance, owner และ evidence ซ้ำ หลักฐานก่อน crash finding ข้อ 1 จึง **CONFIRMED**
>
> **Failure scenario:** Order ถูก REVIEWED ใน taskboard แต่ Receipt ยัง `IN_PROGRESS`; Coverage แก้ PF จากผลใหม่แต่ `MASTER_BACKLOG` ยังมีค่าเดิม; Run manifest เขียน `COMPLETED` แต่ event chain จบที่ `RUN_STARTED` → Control Center ต้องเลือกเจ้าของเอง ทั้งที่ design สัญญาว่าจะไม่เกิดเหตุนี้
>
> **Suggested fix:** ทำ owner-by-owner migration table ที่เจ้าของเดิมอนุมัติ หากยังไม่ demote owner เดิม artifact ใหม่ต้องเก็บเพียง stable ID + owner ref ที่ pin commit/blob/hash ห้ามเก็บ mutable copy

> **[P1]** — `_triage/factory_os/schemas.json:384` — *`ALL CLEAR` invariant บังคับไม่ได้*
>
> **What is wrong:** `sources[].required` ไม่บังคับ `fresh`; ไม่มี conditional ที่ผูก `mandatory`, `read_ok`, `fresh` กับ `all_clear`; reconciliation ไม่มีตัวนับ `actionable/running/waiting/review/...` หรือ coverage equation ที่ design กำหนดไว้ (`_triage/EA_LAB_FACTORY_OS_DESIGN.md:154-160`) `all_clear` เป็น boolean ที่ writer กรอกเอง หลักฐานก่อน crash finding ข้อ 2 จึง **CONFIRMED**
>
> **Failure scenario:** source `{mandatory:true,read_ok:false,age_hours:null}` พร้อม `all_clear:true` → entity-level schema ยังผ่าน หรือ source ที่หายถูกตัดออกจาก array → `discovered=0`, `categorized=0` → equation ผ่านแบบเท็จ
>
> **Suggested fix:** คำนวณ `all_clear` ใน validator ห้ามรับจาก input; มี registry ของ mandatory sources แยกจากสิ่งที่ discover ได้; encode category totals และ coverage totals; test missing/unreadable/stale/empty เป็นคนละ fixture

> **[P1]** — `scripts/make_status.ps1:4` — *Compatibility output ยังมีเส้นทาง “อ่านไม่ได้ = ไม่พบอะไร”*
>
> **What is wrong:** `make_status.ps1` ใช้ `$ErrorActionPreference="SilentlyContinue"` แล้วอ่าน taskboard และ git โดยตรง (`:12-16`) ไม่ได้อ่าน snapshot; ถ้าอ่าน taskboard ไม่ได้ `$orders` กลายเป็นว่างและยังเขียน STATUS ต่อ ขณะที่ design สัญญาว่า STATUS/digest/Telegram จะมาจาก snapshot เดียว (`_triage/EA_LAB_FACTORY_OS_DESIGN.md:139-142,601`)
>
> **Failure scenario:** taskboard ถูก lock/อ่านไม่ได้ → STATUS แสดง Work queue ว่างโดยไม่มี `UNKNOWN`; Factory page อาจแสดง stale last-known-good; Telegram อาจยังเงียบ → สาม consumer ให้ภาพคนละแบบ
>
> **Suggested fix:** ให้ compatibility generators รับ validated snapshot เท่านั้นและ fail closed เมื่อ snapshot stale/build failed; เก็บ `read_ok=false` แยกจาก zero rows ทุก output

> **[P1]** — `_triage/factory_os/schemas.json:219` — *Candidate hash self-referential และไม่ได้ทำให้ manifest immutable*
>
> **What is wrong:** `candidate_id` เป็น required member ของ object (`:220-223`) แต่ถูกนิยามว่าเป็น hash ของ object ทั้งก้อน จึงต้องแก้สมการ `id = hash(manifest containing id)` ซึ่งไม่มีวิธีสร้างตามปกติ นอกจากนี้ schema ตรวจเพียง pattern ไม่ได้ recompute hash และไฟล์ยังแก้ทับแล้ว schema-valid ได้ หลักฐานก่อน crash findingข้อ 3 จึง **CONFIRMED**
>
> **Failure scenario:** generator hash payload ก่อนใส่ ID แต่ validator hash object หลังใส่ ID → mismatch เสมอ; ทีมจึงปิด hash check หรือ hash คนละ payload → Candidate ถูกแก้โดยไม่เปลี่ยน ID
>
> **Suggested fix:** นิยาม canonical hash payload ที่ตัด `candidate_id` ออก แล้ว validator recompute ทุกครั้ง; ใช้ full digest ใน manifest และ prefix เฉพาะ display ID

> **[P1]** — `_triage/factory_os/schemas.json:220` — *Candidate hash ไม่ครอบ behavior และ evidence lineage ที่ design ต้องใช้*
>
> **What is wrong:** Candidate ไม่มี `module_set`, `experimental`, source/allowlist/generator hash หรือ `effective_config_hash`; profile เป็น mutable string ID (`:228-235`) และมี lane/fingerprint เพียงค่าเดียว ทั้งที่ `evidence_ids` อาจมีหลาย window/run
>
> **Failure scenario:** `instrument_profiles.yaml` แก้ค่าใต้ profile ID เดิม หรือ experimental module ผลิต evidence แล้วถูกอ้างใน Candidate → Candidate ID เดิมยังดู valid; MAIN และ BWD มาจากคนละ lane แต่ manifest เก็บ lane ล่าสุดเพียงค่าเดียว
>
> **Suggested fix:** hash resolved immutable profile content/version, module set/stability, source+generator+allowlist hashes และ effective config; evidence ต้องเป็นรายการ `{run_id,lane,data_fingerprint,window,model}` ไม่ใช่ fingerprint เดียว

> **[P1]** — `_triage/factory_os/schemas.json:162` — *Run/Attempt model ไม่ crash-safe และเก็บ attempts ไม่ครบ*
>
> **What is wrong:** manifest มี `attempt` เดียวกับ state เดียว (`:167-195`) ขัดกับคำอ้างว่าเก็บทุก attempt (`_triage/EA_LAB_FACTORY_OS_DESIGN.md:264`) ไม่มี attempt array/append event, PID/heartbeat/lease expiry/failure class หรือ event-registration ID หลักฐานก่อน crash findingข้อ 4 จึง **CONFIRMED**
>
> **Failure scenario:**  
> `LEASED` แล้วเครื่องดับ → lease ค้างถาวร;  
> launch process แล้วดับก่อนเขียน `RUNNING` → resume launch ซ้ำทั้งที่ MT5 เดิมอาจยังทำงาน;  
> report เขียนแล้วแต่ exit code/state ยังไม่ persist → freshness guard ต้องใช้ exit code 0/3 (`scripts/lib/report_freshness.ps1:65-88`) แต่ reconstruct ไม่ได้;  
> event append สำเร็จแล้วดับก่อน `EVIDENCE_REGISTERED` → retry สร้าง occurrence ซ้ำ
>
> **Suggested fix:** append-only attempt journal พร้อม atomic transition record; lease owner/expiry/PID; persist start time ก่อน launchและ exit codeทันทีเมื่อได้; reconcile process/report/event store ก่อน retry

> **[P1]** — `_triage/factory_os/schemas.json:167` — *Idempotency key ไม่ครอบ configuration จริง*
>
> **What is wrong:** required fieldsไม่บังคับ `set_hash`, `ini_hash`, `ex5_hash`, `effective_config_hash`, leverage หรือ data fingerprint และไม่มี deposit/currency/execution modeเลย แม้ `mt5_run.ps1` ยืนยันว่า leverage/cache เปลี่ยนผลได้ (`scripts/mt5_run.ps1:31-47`)
>
> **Failure scenario:** run A deposit 10,000/leverage 1:100 กับ run B deposit 100,000/leverage 1:200 ใช้ required fieldsเท่ากัน → schedulerคิดว่า identicalและคืน cached evidenceผิด หรือ runที่ tester errorไม่มี `failure_class` แต่ใส่ `rerun_of` แล้ว re-run ได้
>
> **Suggested fix:** กำหนด canonical execution key ครบทุก simulator inputและ binary/data identity; บังคับ hash fields; เพิ่ม classified terminal/tester error ที่เป็น route เดียวซึ่งอนุญาต retry

> **[P1]** — `_triage/factory_os/schemas.json:39` — *EXPERIMENTAL evidence ผ่านเข้าสู่ Candidate ได้*
>
> **What is wrong:** `experimental` ไม่ required และ JSON Schema `default` ไม่ได้เติมค่าให้อัตโนมัติ; Candidate ไม่มี fieldนี้หรือ module stability และ evidence refs ไม่มี constraint ผูกกับ stable module แม้ design สั่ง REFUSE (`_triage/EA_LAB_FACTORY_OS_DESIGN.md:244-251`)
>
> **Failure scenario:** Hypothesis ละ `experimental` → consumerตี missing เป็น false; HEDGE_LOCK evidence ถูก registerเหมือน reportทั่วไป → Candidate schemaผ่าน → Deployment attestationรับ `candidate_id`
>
> **Suggested fix:** ทำ module registry/versionพร้อม stability; `experimental` required; Candidate validator resolveทุก evidence→run→module set และ failหากตัวใดไม่ `CERTIFIABLE`

> **[P1]** — `_triage/factory_os/schemas.json:47` — *Parameter role ถูกวางผิดระดับและ locked value ไม่มี owner*
>
> **What is wrong:** `role=LOCKED/TUNABLE/...` อยู่บน global Parameter Definition แต่ความเป็น locked เป็นต่อ-hypothesis binding เดียวกันอาจ lockedใน H01และ tunableใน H02 ได้ อีกทั้ง Hypothesis schemaไม่มี parameter bindingsหรือ locked values แต่ generatorตัวอย่างต้องสร้าง locked constants (`_triage/EA_LAB_FACTORY_OS_DESIGN.md:390-396`)
>
> **Failure scenario:** ตั้ง `_04_TpUsd` เป็น `LOCKED` เพื่อ H01 → optimize guardปฏิเสธมันทุก Boss/hypothesis; หรือไม่ตั้ง global lock → parent Boss/`.ini` ยัง sweepได้และ evidenceถูกผูก Candidateผิด
>
> **Suggested fix:** Parameter Definition เก็บ semanticsถาวร; สร้าง immutable `ParameterBinding` ต่อ hypothesis revision มี role/value/source; generatorและ guardต้องอ่าน binding resolverเดียวกัน

> **[P1]** — `_triage/EA_LAB_FACTORY_OS_DESIGN.md:490` — *Lane provenance modelเปิดช่อง cross-install aggregation*
>
> **What is wrong:** CoverageCell เก็บ MAIN/BWD metricsหลายค่ากับ `lane`/`data_fingerprint` เพียงหนึ่งค่า (`schemas.json:132-145`) ทั้งที่ fingerprintมี windowอยู่ใน hash จึงโดยนิยาม MAIN กับ BWD ไม่สามารถมี fingerprintเดียวกัน Candidateก็มีปัญหาเดียวกัน Heatmapไม่มีข้อห้าม compareต่าง lane (`design:585-586`)
>
> **Failure scenario:** MAIN lane 5c, BWD lane 1 → writerเติม PFทั้งคู่แล้ว lane=1ตาม runล่าสุด → heatmapแสดง pairเหมือน same-lane; rescue ladderหรือ Candidateใช้ค่าคู่นี้โดยไม่เห็น provenanceจริง
>
> **Suggested fix:** metricทุกค่าต้องเป็น referenceไปยัง Run/Evidence ของตัวเอง; validatorบังคับ same-laneสำหรับ comparison group; UI partition/labelตาม laneและห้าม rank/averageข้าม partition

> **[P1]** — `_triage/EA_LAB_FACTORY_OS_DESIGN.md:435` — *Trade-list identity ยังไม่พอเป็น parity contract*
>
> **What is wrong:** identical tradesไม่ตรวจ `OnInit` success, config log, GlobalVariables, pending orders, rejected order attempts, timer/event side effects, resource use หรือ safety alerts
>
> **Failure scenario:** wrapperกับ parentไม่เปิดไม้เลยทั้งคู่ แต่ wrapper fail `OnInit`จาก wrong constหรือเขียน wrong persistent risk key → trade listว่างเหมือนกันและ parityผ่าน ทั้งที่ deploy behaviorต่างกัน
>
> **Suggested fix:** parityต้องตรวจ init result, `[CFG]` fingerprint, complete order-request/result trace, pending orders, terminal/GV side effects, errors และ final state; ต้องมี must-trade caseและ deliberate refusal case ไม่ใช่ trade-listอย่างเดียว

> **[P1]** — `_triage/factory_os/schemas.json:264` — *Deployment immutabilityและ human-only transitionยังเป็นเพียงคำสัญญา*
>
> **What is wrong:** ไม่มี Deployment schema/state-transition validator มีเพียง mutable `DeploymentAttestation`; `candidate_id`, stateและ core revisionแก้ทับได้ ไม่มี append revisionหรือ human authorization ref ขัดกับ lifecycleที่ designประกาศ (`design:293-301`)
>
> **Failure scenario:** automationอัปเดต candidate linkหรือ `attest_state` หลัง core rebuild → dashboardแสดง deploymentเป็น revisionใหม่โดยที่ userไม่เคย move champion
>
> **Suggested fix:** Deployment stateยังอยู่ใน `DEPLOYMENTS.csv`; ทุก candidate reassignmentเป็น append-only attestation eventพร้อม user/Claude owner ref; validatorห้ามเปลี่ยน identity/statusโดย actorอื่น

> **[P1]** — `_triage/EA_LAB_FACTORY_OS_DESIGN.md:367` — *Magic allocatorขัดกับ invariantปัจจุบัน*
>
> **What is wrong:** designกำหนด global uniqueness แต่ governanceปัจจุบันกำหนด uniquenessที่ `account|magic` (`PROJECT_STATE.md:62`) และมี reuseข้ามบัญชีโดยตั้งใจ (`portfolio/DEPLOYMENTS.csv:22`) Allocation schemaยังคัดลอก account/statusจาก deployment owner
>
> **Failure scenario:** import fleetปัจจุบัน → allocatorพบ 991001สองบัญชีแล้วปฏิเสธข้อมูลที่ governanceถือว่าถูก หรือ renumberเพื่อผ่าน allocator → attributionเดิมแตก
>
> **Suggested fix:** userต้อง ratifyการเปลี่ยน scopeก่อน; ถ้าไม่เปลี่ยน ใช้ `(account,magic)` เป็น allocation key และให้ allocatorเป็น reservation logอ้าง Deployment ไม่เก็บ deployment statusซ้ำ

> **[P1]** — `_triage/EA_LAB_FACTORY_OS_DESIGN.md:567` — *“Safe projection by construction” ยังไม่มี construction*
>
> **What is wrong:** ไม่มี safe-projection schemaหรือ explicit allowlist ขณะที่ snapshotจริงมี account IDs, balance/equity/floating P/L และ exact open lots (`scripts/control_room_snapshot.ps1:335-339`) Designยังบอก Telegramกับ Dashboardอ่าน snapshotเดียวกัน (`design:601`)
>
> **Failure scenario:** online/Telegram adapter serialize snapshotโดยตรง → account, exact lotและเงินหลุด แม้ UIตั้งใจซ่อน
>
> **Suggested fix:** สร้าง separate derived DTO แบบ allowlist-only; validatorใส่ forbidden-key recursive scanและ synthetic secret/account fixtures; Telegramห้ามเข้าถึง full snapshot

> **[P1]** — `_triage/EA_LAB_FACTORY_OS_DESIGN.md:592` — *Alert dedupeไม่มี delivery stateที่พิสูจน์ exactly-once*
>
> **What is wrong:** dedupeด้วย `finding_id + state` ไม่ครอบ severity/payload/channel ไม่มี delivery ledger; OPEN→HEALTHY_1_OF_2→OPENทำให้แจ้งซ้ำ และ FLAPPINGที่ stateไม่เปลี่ยนอาจเงียบตลอดไป สอง botอาจ route eventเดียวกันพร้อมกัน
>
> **Failure scenario:** detectorสลับ healthyหนึ่งครั้งทุก cycle → stateเปลี่ยนทุกครั้งและ spam; หรือ severityเพิ่มจาก warning→real-money criticalแต่ stateยัง OPEN → ถูก dedupeทิ้ง
>
> **Suggested fix:** event ID immutable + per-channel delivery receipt; dedupe keyรวม material revision/severity; intermediate healthไม่ส่ง recovery; FLAPPINGมี bounded reminder/escalation policy

> **[P1]** — `_triage/EA_LAB_FACTORY_OS_DESIGN.md:711` — *Slice dependency orderใช้ไม่ได้*
>
> **What is wrong:** S7 wrapper generatorต้องอ่าน Hypothesis registryแต่ registryถูกสร้างใน S8 (`:724-725`); S10 preset compilerมาหลัง parityที่ต้องใช้ effective full config; S11 identityพึ่ง Candidate semanticsที่ยังเสีย S2เรียก “snapshot schema v4” ทั้งที่ HEADเป็น v4แล้ว (`scripts/control_room_snapshot.ps1:375-383`) จึงเกิด version collision
>
> **Failure scenario:** implement S7ก่อน S8 → ต้องสร้าง hidden ad-hoc registryหรือ hard-code pilot; implement S2เป็น “v4” → consumerเดิมเห็นเลข versionเดิมแต่ schemaคนละความหมาย
>
> **Suggested fix:** schema/ownership foundation → registries/bindings → preset resolver → wrapper/parity → scheduler → Candidate/Deployment; versionถัดไปต้องเป็น v5หรือ negotiationแบบ explicit

> **[P1]** — `_triage/EA_LAB_FACTORY_OS_DESIGN.md:691` — *Migrationและ rollback หลายข้อไม่ได้คืน prior state*
>
> **What is wrong:** M1กำหนด state `UNVERIFIED_IMPORT` (`:694`) แต่ Coverage enumไม่มีค่านี้ (`schemas.json:131`); M2 rollbackโดยลบ receiptsจะทำ commitmentsใหม่หายหลัง cutover; M4 repointหน้าเก่าไม่ทำให้หน้าเก่ารู้ ownersใหม่; ไม่มี rollbackของ event/notification deliveryหรือ artifact store
>
> **Failure scenario:** import M1ครั้งแรกไม่ผ่าน validator; หลังใช้งาน receiptsหนึ่งสัปดาห์แล้ว rollback → commitmentsที่ไม่เคยอยู่ handoffเดิมหาย; repoint old page → Factory stateใหม่มองไม่เห็นแต่ดูเหมือนระบบกลับปกติ
>
> **Suggested fix:** แยก shadow importออกจาก canonical state; dual-readพร้อม reconciliationจนผ่าน cutover gate; rollbackต้องมี reverse projection/exportและ data-retention plan ไม่ใช่แค่ลบ directory/repoint URL

> **[P1]** — `_triage/EA_LAB_FACTORY_OS_DESIGN.md:476` — *ข้อกำหนด ~10,000 ต่อ roundยังไม่ได้ reconcileจริง*
>
> **What is wrong:** policy ratifiedบอก fine complete grid ≤1,000ต่อ zone (`PROJECT_STATE.md:164`) แต่ designเพียงประกาศว่า ~10,000คือ budgetรวม zones โดยไม่กำหนดจำนวน zone, minimum total searchหรือ stop rule
>
> **Failure scenario:** genetic coarse → fine gridเดียว 125 combos → ผ่าน ≤1,000-per-zone แต่ไม่ถึง locked ~10,000-round requirement; orchestratorประกาศ compliantได้ทั้งสองทาง
>
> **Suggested fix:** ownerของ requirementต้องนิยาม round budgetเชิง executable: target/minimum, zone construction, adaptive early-stopและข้อยกเว้น แล้ว validatorนับจริง

## Other findings outside the design’s own attack list

> **[P1]** — `_triage/factory_os/schemas.json:118` — *JSON Schemaไม่ตรงกับ CSV/YAML storage contract*
>
> **What is wrong:** Hypothesis/Coverage ownerเป็น CSVแต่ schemaใช้ typed arrays/booleans/numbers; CSV parserให้ stringทั้งหมด และไม่มี serialization ruleสำหรับ `module_set`, `supported_profiles` หรือ null
>
> **Failure scenario:** writer serialize arrayเป็น `"A,B"` แต่ readerแยก commaเป็น columns หรือ validatorรับ JSON objectที่ไม่สามารถ round-tripกลับ CSV byte-equivalent
>
> **Suggested fix:** ใช้ JSON/JSONLเป็น canonical ownerหรือกำหนด CSV encoding/null/list grammarพร้อม round-trip fixtures

> **[P1]** — `_triage/factory_os/schemas.json:309` — *WAITING contractใน schemaอ่อนกว่าที่ designประกาศ*
>
> **What is wrong:** designบอก WAITINGต้องมี `waiting_for` และ wake condition (`design:556`) แต่ schemaใช้ `anyOf` จึงต้องมีเพียงอย่างใดอย่างหนึ่ง
>
> **Failure scenario:** Receiptมี `waiting_for=user`, ไม่มี wake condition → schemaผ่านและกลายเป็นงานพักไม่มีกำหนดที่ designตั้งใจป้องกัน
>
> **Suggested fix:** ใช้ `required:["waiting_for","wake_condition"]` หรือเขียนข้อยกเว้น explicit

> **[P1]** — `AGENTS.md:79` — *Designมอบ write authorityใหม่โดยไม่มี governance migration*
>
> **What is wrong:** WorkReceiptระบุ “any agent” เป็น writer (`schemas.json:281-307`) แต่ current permissionsให้ agentเขียนเฉพาะ order blockของตัวเองและ new report/CSV/setตาม order (`AGENTS.md:81-85`); JSON receipt/status ownerใหม่ไม่ได้รับอนุญาตชัดเจน
>
> **Failure scenario:** Codex/agentทำตาม schemaแล้ว commit receipt → ละเมิด current single-writer rules หรือ implementationแก้ AGENTSเองทั้งที่ห้าม
>
> **Suggested fix:** เพิ่ม governance-change prerequisiteที่ Claude/user ratifyและแก้ permission tableก่อนเปิด writer

## Factual accuracy check

- Boss wrapperเป็น thinจริง แต่มี **12 lines ไม่ใช่ 13**: `ea_template/Boss_14_GridLog.mq5:1-12`
- MQL5 conditional compilationรองรับ `#ifdef/#ifndef/#else/#endif`; ข้อจำกัดที่ `Inputs.mqh:11` ถูกต้องและตรงกับ [official MQL5 Reference](https://www.mql5.com/en/docs/basis/preprosessor/conditional_compilation)
- Registry counts **ถูกต้อง**: 184 rows; `OptimizeStage=UNKNOWN` 177; `SafeRange=UNKNOWN` 181 จาก `docs/PARAM_REGISTRY.csv:10`
- Input countถูกเขียนคลุมเครือ/ผิด:
  - real `input/sinput` = **184**
  - `input group` = **25**
  - รวม source lines = **209**
  - conditional guard openers = **26 ไม่ใช่ 28**
- ความต่าง “static 128–153 vs MT5 113–135” อธิบายได้ครบ ไม่ใช่ discovery gap:
  - real visible inputsต่อ Boss = `113,117,119,116,119,135,121,121`
  - static totalที่ designอ้างนับ group headersเพิ่ม `15` หรือ `18` → `128–153`
  - Boss 14 reportที่ HEADอ้าง 116 inputs (`_triage/HANDOFF_2026-07-28_BATCHQUEUE.md:74`) ตรงกับ static countเมื่อไม่นับ groups
- Unit-convention contradiction **ยืนยันจริง**: `Stack_PipSize()` ใช้ 10× pointบน 3/5 digits (`ea_template/core/Stack.mqh:23-28`) แต่ fixed SL/TPคูณ `_Point`ตรง (`ea_template/core/ExitManager.mqh:140-141,214-215`)
- Snapshot claim “currently schema v3” ล้าสมัยที่ HEAD: actualคือ v4 (`scripts/control_room_snapshot.ps1:375-383`)

## Second sources of truth

การประเมิน 11 “new facts” ทีละข้อ:

1. **Hypothesis/revision — ไม่ได้ unowned:** causal claim, falsifier, acceptanceและ execution contextอยู่ใน taskboard/preregistrationแล้ว; registryใหม่คัดลอก
2. **Test Universe — genuinely unowned:** versioned mandatory symbol×TF setยังไม่มี canonical artifact
3. **Coverage state — ไม่ได้ unowned:** `MASTER_BACKLOG.md:3,27-39` ประกาศ ownerชัด
4. **Instrument Profile — ownedบางส่วน:** baseline/profile semanticsและค่าตั้งต้นอยู่ `ea_template/OPTIMIZATION_PROCEDURE_V2.md:117-160`; broker/lane mappingละเอียดเป็นส่วนใหม่
5. **Run/Attempt — split:** scheduler recovery checkpointเป็น factใหม่ แต่ occurrence/hash/trial timelineมี event logเป็น ownerแล้ว
6. **Evidence bundle index — ไม่ได้ unowned:** existing `evidence-manifest.jsonl` + event utilityเป็น registryอยู่แล้ว; blob store locationอาจเป็น factใหม่
7. **Candidate — new identityบางส่วน:** immutable bundle IDเป็นใหม่ แต่ locked set, scorecard standing, evidenceและattestationมี ownersเดิม
8. **Magic allocation — ไม่ได้ unownedทั้งหมด:** assigned magicอยู่ DEPLOYMENTS; uniquenessตรวจโดย checker; session rangesอยู่ SESSION_LEDGER
9. **Work Receipt — ใหม่เฉพาะ chat commitmentที่ยังไม่เป็น Order:** title/status/owner/acceptanceของ formal workซ้ำ taskboard
10. **System Finding — ใหม่เฉพาะ stable lifecycle/identity:** detector stateและoperational occurrenceมี snapshot/taskboardอยู่แล้ว
11. **Idea Tank — ไม่ได้ unowned:** `INTAKE_QUEUE.md:1-4` ประกาศตัวเองเป็นที่เดียวสำหรับ strategy intake

Mutable second-owner locationsที่ designสร้างหรือเสนอ:

- `factory/hypotheses.csv` ↔ taskboard/preregistration/archive
- `factory/coverage.csv` ↔ `MASTER_BACKLOG.md` + taskboard raw results
- `factory/runs/*.json` ↔ experiment event log
- `factory/evidence/index.csv` ↔ existing evidence manifest/event log
- `factory/candidates/*.json` ↔ locked `.set`, scorecard, attestation
- `factory/instrument_profiles.yaml` ↔ `OPTIMIZATION_PROCEDURE_V2.md`
- `factory/magic_allocations.csv` ↔ `DEPLOYMENTS.csv` + session ledger/checker
- `ops/receipts/*.json` ↔ taskboard order state/owner/acceptance/evidence
- `ops/findings.csv` ↔ detector snapshot/taskboardสำหรับ governance findings
- `ops/ideas.csv` ↔ `INTAKE_QUEUE.md`
- Deployment attestation candidate/core state ↔ existing `ATTESTATION_MAP.csv`/`DEPLOYMENTS.csv` เว้นแต่เพิ่มเป็น columnsใน ownerเดิมเพียงที่เดียว

## Go / no-go

**NO-GO สำหรับแตกเป็น implementation ordersตาม S1–S13 as-is**

สิ่งที่ต้องแก้ก่อน:

1. ทำ ownership diffและตัด mutable copiesออก
2. ทำ schemaให้ validate instanceจริง
3. แก้ Candidate hash payload
4. เปลี่ยน Run/Attemptเป็น append-only crash-recovery model
5. ทำ experimental/certifiableและlane provenanceให้ machine-enforceable
6. นิยาม safe projection
7. reorder slicesและเขียน rollbackที่รักษาข้อมูล
8. ใช้ snapshot versionใหม่ ไม่ชน v4ที่มีแล้ว

S1 monitoring-integrityที่แยกจาก Factory OSอาจเดินต่อได้ตาม orderเดิม แต่ไม่ควรถือว่าเป็นการเริ่ม implement designฉบับนี้

## Over-engineering

สำหรับ single operator ผมจะตัดหรือเลื่อน:

- Work Receiptsสำหรับงานที่มี Orderแล้ว—ใช้ taskboard IDโดยตรง
- Legacy handoff bulk import—สร้าง read-only indexจากไฟล์เดิมพอ
- Idea Tankใหม่—ปรับ `INTAKE_QUEUE.md` ให้มี stable ID/URL dedupe
- Hypothesis WizardและParameter Linkage Graph UI—เริ่มจาก validated CSV/CLI report
- Reserved magic ranges “อ่าน familyจากเลข”—ใช้ opaque allocationและ account-scoped uniqueness
- สอง Telegram botsบน event systemเดียว—เริ่ม botเดียวและ severity routing
- Champion–Challenger UIเต็ม—เก็บ immutable Candidate refsและรายงาน diffแบบไฟล์ก่อน
- General-purpose System Finding lifecycle—เริ่มเฉพาะ monitoring faultsที่มี detectorจริง

แกนที่ควรเก็บ: fail-closed snapshot, same-lane evidence provenance, full preset compiler, parity cage, scheduler recoveryและimmutable candidate payload

## What I could not verify

- ไม่ได้ compile wrapperหรือรัน MT5 parity เพราะขัดกับ strictly read-only; การพิสูจน์ `input→const`จริงต้อง buildใน temporary external worktree/laneและตรวจ init/config/order/GV trace
- ตัวเลข MT5 Inputs-page 113–135 ไม่มี consolidated artifactหนึ่งชิ้นที่ HEAD แต่ static walkอธิบายช่วงนี้ครบและ Boss 14มีหลักฐาน 116ตรงกัน
- Sourceต้นฉบับของ locked Grill requirement “~10,000 per round” ไม่ได้อยู่ในรายการ governance canonicalที่ตรวจได้; ผมถือว่ามัน lockedตามคำสั่งผู้ใช้
- Telegram/online safe projectionยังไม่ implement จึงตรวจได้เพียงว่า designไม่มี schema/allowlist ไม่สามารถพิสูจน์ runtime leakจริง
- Artifact-store location/backup/restoreยัง unresolvedตาม designเอง จึงตรวจ durabilityจริงไม่ได้
- Working-tree taskboardที่ dirtyอาจมีสถานะใหม่กว่า HEAD แต่ไม่กระทบข้อบกพร่องเชิงสถาปัตยกรรมข้างต้น