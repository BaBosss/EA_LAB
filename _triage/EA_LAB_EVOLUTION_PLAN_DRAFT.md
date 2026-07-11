# EA_LAB Evolution Plan — Memory-Controlled Investment Operating System

> **สถานะ: DRAFT FOR FABLE / CLAUDE / USER REVIEW — DO NOT IMPLEMENT**  
> **วันที่ร่าง:** 2026-07-11  
> **ผู้ริเริ่ม:** user · **ผู้สังเคราะห์ร่าง:** Codex  
> **เอกสารนี้ไม่มีอำนาจเปลี่ยน** `VISION.md`, `ROADMAP.md`, `PROJECT_STATE.md`, `AGENTS.md`, verdict, deployment, taskboard หรือ source code  
> **ห้ามเปิด order / ย้ายไฟล์ / สร้างระบบ / migrate ข้อมูลจากร่างนี้** จนกว่า user + Fable/Claude จะเห็นพ้องและบันทึก approval ใน canonical decision owner

**Consensus lock (ต้องครบทุกช่องก่อนเริ่ม):**

- [ ] User เห็นชอบทิศทางร่าง
- [ ] Fable review พร้อมข้อทักท้วง
- [ ] Claude lead สังเคราะห์ข้อเห็นตรง/ต่างและตรวจ owner boundaries
- [ ] User อนุมัติ final design อีกครั้ง
- [ ] Claude/user เขียน implementation orders ตามสิทธิ์ใน `AGENTS.md`

ความเงียบหรือการไม่มีข้อค้าน **ไม่ถือเป็น approval**

---

## 1. คำขอการตัดสินจาก Fable

ขอให้ Fable review เอกสารนี้ในฐานะ **architecture proposal** โดยตอบ 4 คำถามหลัก:

1. ทิศทาง “memory-control MVP ก่อน Wiki เต็มระบบ” ถูกหรือไม่
2. ownership ของ fact/evidence/experiment/context ควรแบ่งอย่างไรโดยไม่สร้าง source of truth ชุดที่สอง
3. acceptance gates และ rollback เพียงพอหรือยัง
4. ส่วน strategy/monitoring/agent workflow ใดควรเพิ่ม ตัด หรือเลื่อนเฟส

ผล review ที่ต้องการ: `ACCEPT` / `ACCEPT-WITH-CHANGES` / `REWORK` พร้อมรายการข้อแก้ **โดยยังไม่เริ่ม implementation**

---

## 2. Executive thesis

EA_LAB ควรพัฒนาจาก “คลัง EA + taskboard ขนาดใหญ่” ไปเป็น **Memory-Controlled Investment Operating System** ที่ทำ 5 เรื่องได้พร้อมกัน:

1. ส่งข้อมูลขั้นต่ำที่ถูกต้องและสดให้ agent ต่อหนึ่งงาน
2. เก็บหลักฐานและการทดลองแบบตรวจย้อนกลับได้
3. ป้องกัน summary/context เก่ากลายเป็นความจริงชุดใหม่
4. แยก deterministic safety ออกจาก AI explanation/judgment
5. เปลี่ยนไอเดียเป็น portfolio decision ด้วย pipeline เดียวที่วัดผลได้

ปัญหาหลักในวันนี้ไม่ใช่ “AI จำไม่ได้” อย่างเดียว แต่คือ agent ต้องอ่านเอกสารยาวมากซึ่งปนกันระหว่าง:

- กฎถาวร
- สถานะสด
- ประวัติที่ปิดแล้ว
- ผลดิบ
- verdict
- handoff เก่า
- input ภายนอก

เมื่อ context โตขึ้น agent จึงอาจหยิบ fact เก่า, พลาดข้อห้าม, สรุปจาก summary แทน raw evidence หรือเข้าใจ authority ผิด แม้ข้อมูลที่ถูกต้องจะมีอยู่บนดิสก์แล้วก็ตาม

หลักฐานเชิงขนาด ณ วันที่ร่าง: mandatory bootstrap set รวมประมาณ 6,700+ บรรทัด; `AGENT_TASKBOARD.md`
เพียงไฟล์เดียวประมาณ 5,600+ บรรทัด/มากกว่า 500 KB จึงไม่ใช่ working context ที่เหมาะกับทุกงาน แม้มันยังมีค่าเป็น history/audit trail

อีกช่องว่างคือ tool-private memory: memory ภายใน Claude/Codex ใช้เป็น cache ได้ แต่ห้ามถือเป็น authoritative
เพราะ agent/model อื่นมองไม่เห็นเท่ากันและอาจ stale โดยไม่มี repo cage ตรวจ

**ข้อเสนอหลัก:** อย่าแก้ด้วยการสร้าง Wiki ที่ copy ทุกอย่าง ให้สร้าง “memory compiler” ซึ่งอ่าน fact จาก owner เดิมแล้วประกอบเป็น **bounded Context Packet** ที่มี provenance, hash, freshness และ invalidation

---

## 3. สิ่งที่มีอยู่แล้วและต้องรักษา

แผนนี้ไม่ใช่การรื้อระบบใหม่ ของเดิมที่แข็งและต้องคงไว้:

- `VISION.md` เป็น owner ของภาพใหญ่/ปรัชญา
- `ROADMAP.md` เป็น owner ของ end-state/phase gates
- `PROJECT_STATE.md` เป็น canonical entry และ decision/status owner ตามขอบเขตเดิม
- `AGENTS.md` เป็น owner ของ roles, permissions และ collaboration protocol
- `AGENT_TASKBOARD.md` เป็น order queue + evidence/result record
- `EA_SCORECARD_AND_REGISTRY.md` เป็น owner ของ score/verdict ตามขอบเขตเดิม
- `portfolio/DEPLOYMENTS.csv` เป็น structured deployment inventory
- raw reports/CSV/source/set/git commits เป็นหลักฐานจริง
- single-writer verdict, blind second opinion, cheapest-verifiable tier และ cages
- monthly compaction / system metrics / quarterly verdict audit ใน `docs/PORTABLE_AI_OS.md`

**กฎสถาปัตยกรรม:** proposal ใดที่ทำให้ fact เดียวมี owner มากกว่าหนึ่งที่ = ไม่ผ่าน

---

## 4. Anti-goals — สิ่งที่แผนนี้จงใจไม่ทำ

- ไม่สร้าง Chatbot ที่ “จำทุกอย่าง” โดยไม่มี provenance
- ไม่เอาเอกสารทั้งหมดเข้า vector database แล้วให้ retrieval ตัดสินว่าอะไรคือคำสั่ง
- ไม่ย้าย canonical docs ทั้งก้อนในรอบเดียว
- ไม่ลบหรือ rewrite taskboard/history เก่า
- ไม่ให้ Context Packet เป็นหลักฐานหรือ verdict
- ไม่ให้ AI monitoring ส่งคำสั่งเทรด/close/kill
- ไม่ให้ worker เลื่อนสถานะ DEMO→LIVE, REJECT, RETIRE หรือเปลี่ยน direction
- ไม่สร้าง cards หลายชุดก่อนพิสูจน์ว่า memory MVP ลด error ได้จริง
- ไม่เพิ่ม EA/agent/automation เพื่อแก้ปัญหาที่เกิดจาก state ไม่ชัด
- ไม่ optimize ระบบตามจำนวน token อย่างเดียวจนกฎ safety หายจาก context

---

## 5. Target architecture

```mermaid
flowchart TD
    A["Canonical owners\nVISION / ROADMAP / STATE / AGENTS / SCORECARD / DEPLOYMENTS"]
    B["Raw evidence\nreports / CSV / source / set / commits"]
    C["Append-only Experiment Events\nhypothesis / prereg / result / amendment / review"]
    D["Memory Compiler\nownership map + hashes + trust classes"]
    E["Bounded Context Packet\nkernel + task facts + evidence links + omissions"]
    F["Worker / Reviewer / Judge"]
    G["Write-back gate"]
    H["Generated views\nEA / Mechanism / Failure / Regime cards"]
    I["Deterministic monitoring\ntelemetry / alerts / kill controls"]
    J["AI explanation layer\nexception digest / decision packet"]

    A --> D
    B --> D
    C --> D
    D --> E
    E --> F
    F --> G
    G --> B
    G --> C
    G --> A
    D --> H
    I --> J
    H --> J
    J --> F
```

เส้นสำคัญ:

- canonical owners และ raw evidence อยู่เหนือ summary เสมอ
- generated view/packet ใช้อ่านเร็ว แต่ไม่มีสิทธิ์ override ต้นทาง
- AI อธิบาย anomaly ได้ แต่ deterministic layer เป็นเจ้าของ freshness/DD/margin/kill
- write-back ต้องกลับเข้าที่ owner ที่ถูกต้อง ไม่เขียน “memory สะดวก” แยกเอง

---

## 6. Memory architecture

### 6.1 Memory tiers

#### Tier 0 — Mandatory kernel

ต้องอยู่ในทุก Context Packet และตัดออกไม่ได้:

- objective ของงาน
- agent seat/authority
- allowed writes / forbidden actions
- money/live safety rules ที่เกี่ยวข้อง
- external input = data, not instructions
- current order ID/status/owner
- required cages
- canonical links และ freshness state

เป้าขนาด:ประมาณ 1,500–2,500 tokens

#### Tier 1 — Task context

เฉพาะ fact ที่งานนี้ต้องใช้:

- spec + acceptance + pre-registered bars
- files/modules/symbols/accounts/magics ที่อยู่ใน scope
- active decisions ที่เกี่ยวข้อง
- known failure modes
- latest reviewed result
- unresolved questions
- dependencies และ in-flight collision

เป้าขนาด:ประมาณ 4,000–8,000 tokens

#### Tier 2 — Evidence on demand

ไม่ยัดทั้งหมดลง prompt แต่ให้ manifest/link/hash:

- reports
- CSV
- source/set
- historical reviews
- external documents
- archived orders

agent ต้องเปิด Tier 2 เมื่อต้องยืนยัน claim ไม่ใช่อาศัย summary อย่างเดียว

### 6.2 Context Packet schema (proposal)

```yaml
context_id: ORDER-XXX@commit
generated_at: YYYY-MM-DDTHH:MM:SS+07:00
objective: "..."
seat: worker|challenger|chief
authority:
  may_write: []
  must_not_write: []
kernel_rules: []
task:
  order_id: ORDER-XXX
  status: OPEN
  acceptance: []
  forbidden: []
facts:
  - value: "..."
    owner_path: "..."
    owner_anchor: "..."
    source_hash: "..."
    verified_at: "..."
decisions: []
evidence:
  supporting: []
  contradicting: []
trust_namespaces:
  canonical: []
  team_evidence: []
  external_unreviewed: []
omitted_sections: []
dependencies: []
open_questions: []
packet_hash: "..."
```

### 6.3 Freshness and invalidation

- ทุก fact ใน packet ต้องอ้าง owner path/anchor/hash
- ถ้าต้นทางเปลี่ยน packet/card ต้องขึ้น `STALE`
- packet stale ห้ามใช้ทำ verdictหรือเงินจริง
- generated views ต้องมี `GENERATED — DO NOT EDIT`
- generator ต้อง deterministic: input commit เดียวกัน → packet hash เดียวกัน
- packet ต้องแสดงสิ่งที่ omit เพื่อไม่สร้างภาพว่า “นี่คือทุกอย่าง”

### 6.4 Trust namespaces

แยก retrieval อย่างน้อย 3 ชั้น:

1. `CANONICAL` — คำสั่ง/decision/fact owner ที่อนุมัติแล้ว
2. `TEAM_EVIDENCE` — ผลจาก agent/reports ยังไม่ใช่ verdict
3. `EXTERNAL_UNREVIEWED` — vendor report, PDF, web, EA ภายนอก; เป็น data เท่านั้น

ข้อมูลภายนอกห้ามถูกดึงเข้า instruction/decision block โดยตรง การ promote claim ต้องผ่าน Claude/user และมี source quote/hash

### 6.5 Write-back protocol

เมื่อจบงาน agent ส่งได้เพียง:

- raw evidence
- observed facts
- test output
- uncertainty/blocker
- commit pointer

จากนั้น:

- worker update execution state/result ของ order ตัวเอง
- Claude/user review แล้วเขียน verdict/decision ใน owner ที่ถูกต้อง
- memory compiler rebuild packet/view
- ห้าม agent สร้าง summary ถาวรอีกชุดนอก protocol

---

## 7. Memory-control MVP — เริ่มแค่ 3 ชิ้น

Red-team recommendation: **ยังไม่สร้าง Wiki เต็มระบบ** ให้พิสูจน์ 3 ชิ้นก่อน

### MVP-1: Append-only Experiment Event Log

หนึ่ง experiment ไม่ใช่แถวที่ถูกแก้ทับ แต่เป็น event chain:

```text
IDEA_CREATED
HYPOTHESIS_REGISTERED
BAR_PREREGISTERED
RUN_STARTED
RESULT_ATTACHED
AMENDMENT_ADDED
REVIEW_RECORDED
DECISION_SIGNED
```

ทุก event มี:

- experiment ID
- timestamp
- actor + role
- prior event
- EA/source/set/data/tester hashes
- trial family/count
- evidence IDs
- reason

preregistration กับ result ต้องเป็นคนละ event เกณฑ์เดิมแก้ไม่ได้; เปลี่ยนได้ด้วย amendment event เท่านั้น

### MVP-2: Context Packet Generator

ช่วงแรกทำ read-only:

- อ่าน owner เดิม
- สร้าง packet สำหรับ order เดียว
- lint source/hash/freshness
- ไม่แก้ canonical docs
- ไม่อนุญาตให้ packet แทน 4 mandatory docs

### MVP-3: Active Work View + Archive Index

เป้าหมายคือลดการอ่าน taskboard หลายพันบรรทัด โดยไม่ทำลาย history:

- active view แสดงเฉพาะ OPEN / CLAIMED / DONE-awaiting-review / BLOCKED
- CLOSED/REVIEWED ยังอยู่ history เดิมหรือ archive read-only
- link/anchor เก่าต้องไม่ตาย
- active view เป็น generated view ห้ามแก้มือ
- protocol เปลี่ยนได้หลัง Claude/user อนุมัติเท่านั้น

---

## 8. Generated Knowledge Base — ทำหลัง MVP ผ่าน

### 8.1 EA Card

generated จาก owners เท่านั้น:

- identity/build/set/deployment
- entry/exit/risk mechanism
- flat-lot edge
- levers swept/held
- symbol/TF/window/trial count
- home/failure regime
- latest verdict + owner link
- live evidence + freshness

### 8.2 Mechanism Card

authored hypothesis/lesson ที่มี owner ชัด:

- mechanism
- causal hypothesis
- successful/failed uses
- portability limits
- known artifacts
- unanswered questions

Mechanism Card ไม่สามารถประกาศ EA verdict

### 8.3 Failure Card

ตัวอย่างหมวด:

- Model-2 optimism
- recovery sizing hides PF<1 entry
- same-regime OOS
- point/pip scale mismatch
- history gap
- stale report/binary
- floating-DD blindness
- concentration/top-winner artifact

แต่ละ failure มี receipt/evidence + deterministic test ที่ใช้จับได้

### 8.4 Regime Card

- regime definition
- observable features
- strategies at home/hostile
- confidence/freshness
- historical failures
- shadow-mode evidence

เริ่มด้วย ADX + ATR percentile ที่อธิบายได้ ยังไม่เริ่ม HMM/ML ก่อน simple model พิสูจน์คุณค่า

---

## 9. Alpha / Experiment pipeline

```mermaid
flowchart LR
    A["Idea"] --> B["Mechanism hypothesis"]
    B --> C["Flat-lot probe"]
    C --> D["Lever surface"]
    D --> E["Independent OOS"]
    E --> F["Cost / tail / MC"]
    F --> G["Portfolio fit"]
    G --> H["Demo forward"]
    H --> I["Small live"]
    I --> J["Scale / probation / retire"]
```

ทุก transition ต้องมี:

- checklist แบบ machine-testable เท่าที่ทำได้
- evidence IDs
- trial count
- actor/authority
- pre-registered bar
- supporting + contradicting evidence
- explicit next question

worker เลื่อนได้เฉพาะ execution states; DEMO/LIVE/REJECT/RETIRE ต้อง Claude/user signature

---

## 10. Monitoring architecture

### 10.1 Deterministic safety layer

เป็นเจ้าของ:

- snapshot/feed freshness
- balance/equity/floating P&L
- margin/free margin/stop-out distance
- positions/lots/ladder depth/pending/oldest trade
- cross-account XAU/USD exposure
- NewsGuard state/offset/event count
- hard warning/halt/kill thresholds

AI ล่มแล้ว safety layer ต้องยังทำงาน

### 10.2 AI explanation layer

ทำได้เพียง:

- exception digest
- explain likely mechanism/regime
- compare live vs expected behavior
- assemble decision packet
- open review ticket

ห้าม:

- trade
- close
- modify lot
- promote/retire
- suppress deterministic alert

### 10.3 Shadow mode

ก่อนใช้ AI/regime recommendation จริง ให้รัน shadow 4–8 สัปดาห์และวัด:

- false alerts
- missed alerts
- stale data incidents
- acknowledgement time
- recommendation stability
- whether hypothetical block reduces loss without deleting edge

---

## 11. Strategy and portfolio direction

ทิศเสนอเพื่อ review ไม่ใช่ verdict ใหม่:

### Demo experiment priority

1. Boss_16 Kangaroo 21/30 — capped/flat-lot/hard-SL; demo forward เป็น clean holdout
2. JUMSTOCH multi-symbol — EURUSD H1 + AUDUSD H1 + GBPUSD H4; execution-rich test bed
3. SuperTrend XAU H4 — trend sleeve เพื่อลดการพึ่ง grid/reversion
4. Boss_14 new symbol legs — ต้องปิด OOS/sample/correlation ก่อนเพิ่ม
5. CB/Nui/BRK symbol expansion — เฉพาะตัวที่ flat-lot entry PF>1

### Portfolio sleeves

- trend/breakout
- capped mean-reversion
- experimental/premium quarantine
- risk reserve

risk budget ต้องอิง loss contribution/floating risk ไม่ใช่จำนวน EA หรือ lot เท่ากัน

### Ideas to test first

- JUMSTOCH pending-limit vs market: PF + fill rate + EV/signal + missed opportunity
- regime shadow router: allow/block logging ไม่เปลี่ยนเงินจริง
- live tracking-error bands: cadence/slippage/holding/depth/expectancy

### Do not expand

- no-edge entry families เช่น RSI-MR/ST03
- no-SL/locked systems เข้าพอร์ตหลัก
- strategy ที่ชนะจาก symbol/TF sample บางโดยไม่หัก trial selection

---

## 12. Agent workflow and benchmark

### 12.1 Roles remain unchanged

- user: owner/financial authority
- Claude/Fable/Opus seat: chief/judge/direction
- Codex: peer engineer/independent challenger when asked
- ZCode/Qwen/worker agents: bounded evidence production
- deterministic scripts: verification and safety

memory system เปลี่ยน “สิ่งที่แต่ละ seat ได้อ่าน” แต่ห้ามเปลี่ยน authority

### 12.2 Agent benchmark

ใช้ frozen blind cases ไม่ใช้ production tasks ที่ความยากต่างกัน

วัด:

- correctness
- false-green rate
- evidence traceability
- first-pass cage rate
- rework/escalation
- time/token/cost
- scope violations

มี holdout cases ที่ไม่ใช้ปรับ routing ป้องกัน Goodhart

---

## 13. Phased roadmap and gates

### Phase 0 — Consensus only

**งาน:** Fable/Claude/user review เอกสารนี้  
**ห้าม:** implementation ทุกชนิด  
**Gate:** owner ตอบคำถาม §16 และอนุมัติ architecture decision อย่างชัดเจน

### Phase 1 — Ownership map + baseline measurement

เสนอภายหลัง approval:

- map ทุก fact type → owner เดียว
- วัด taskboard/doc size, onboarding time, context tokens, misunderstanding rework
- สร้าง golden questions 20–30 ข้อจาก current truth
- ไม่ย้ายข้อมูล

**Gate:** ownership conflict = 0 และ baseline reproducible

### Phase 2 — Read-only memory MVP

- append-only experiment event prototype
- context packet generator แบบ read-only
- active work generated view
- stale/hash/trust lint
- packet ยังไม่แทน mandatory docs

**Gate:** historical ordersอย่างน้อย 10 รายการ reconstruct facts/authority/evidence ได้ตรงต้นทาง 100%

### Phase 3 — Shadow pilot

ทดลองกับ campaign เดียวและ 3 งานต่างชนิด:

- code task
- batch task
- judgment/review task

เทียบ full-context workflow vs packet-assisted workflow

**Gate proposal:**

- critical factual/authority error = 0
- stale packet detected = 100% ใน synthetic tests
- provenance coverage = 100%
- context tokens ลดอย่างน้อย 50%
- context-related rework ไม่สูงกว่าเดิม

### Phase 4 — Controlled adoption

- new orders ใช้ packet โดย default แต่ fallback docs ยังอยู่
- write-back gate
- archive index
- monthly compaction ใช้ registry/packet dependency

**Gate:** 20 consecutive orders ไม่มี critical memory error และ rollback ไม่ถูก trigger

### Phase 5 — Generated cards + monitoring assistant

- EA/Mechanism/Failure/Regime views
- exception digest
- decision packet
- shadow regime recommendations

**Gate:** false/missed alert อยู่ในเกณฑ์ที่ owner อนุมัติ และ deterministic safety ไม่พึ่ง AI

### Phase 6 — Portfolio operating system

- tracking-error bands
- strategy sleeves/risk contribution
- revalidation/retirement queue
- multi-account portfolio view
- blind quarterly verdict audit linked to evidence registry

---

## 14. Migration and rollback

### Migration rule

1. additive/read-only ก่อน
2. pilot campaign เดียว
3. old/new run ขนาน
4. reconcile decisions 10–20 รายการ
5. migrate เฉพาะ active work
6. old history read-only
7. no link break

### Rollback triggers

- packet แสดง fact ผิดหรือ authority ผิดหนึ่งครั้งใน money/live task
- stale packet ไม่ถูกจับ
- raw evidence link หาย
- generated view ถูกแก้มือหรือ override owner
- task rework จาก context เพิ่มเกิน baseline
- retrieval นำ external unreviewed text เข้า instruction block

rollback = ปิด generated layer แล้วกลับ mandatory-doc workflow เดิมโดย canonical docs ไม่เปลี่ยน

---

## 15. Success metrics

### Memory quality

- critical factual error
- authority/scope error
- stale packet rate
- provenance coverage
- dead evidence links
- duplicate-owner findings

### Productivity

- median context tokens/order
- onboarding/read time
- first-pass cage rate
- context-related rework
- blocked-for-missing-context rate
- cost/order by tier

### Research quality

- experiments with preregistered bars
- experiments with trial counts/data hashes
- unused holdout coverage
- results with supporting + contradicting evidence
- post-selection corrections for large sweeps

### Operations

- telemetry freshness uptime
- missed/false alert rate
- alert acknowledgement time
- unenumerated magic count
- live-vs-backtest drift incidents
- time to reconstruct why an EA was promoted/retired

---

## 16. Decisions Fable/user must settle before implementation

1. Experiment Registry จะเป็น owner ของ fact ใด และ taskboard ยัง owns อะไร
2. Event format ใช้ CSV/JSONL/YAML/SQLite แบบใด
3. generated Context Packet commit เข้า git หรือสร้างชั่วคราว
4. packet แทน mandatory docs ได้หรือไม่; ถ้าได้ หลัง gate ใด
5. active taskboard/archive ทำอย่างไรโดย anchor/link เก่าไม่ตาย
6. cards ใด generated และ cards ใด authored
7. evidence ID/hash/content-addressing policy
8. external research promotion workflow
9. transition ใด worker ทำเองได้
10. target context reduction และ tolerated error rate
11. monitoring false/missed alert threshold
12. pilot campaign แรกควรเป็น campaign ใด
13. ใคร owns schema migration และ rollback authority
14. proposal นี้ควร merge เข้า `ROADMAP.md` หรืออยู่เป็น architecture doc แยกหลังอนุมัติ

---

## 17. Suggested Fable review rubric

ให้คะแนน 0–2 ต่อข้อ:

| Dimension | 0 | 1 | 2 |
|---|---|---|---|
| One-fact-one-owner | มี owner ซ้ำ | ยังคลุมเครือ | owner ชัดทุก fact |
| Evidence integrity | summary แทน evidence | link บางส่วน | append-only + hash + provenance |
| Context safety | ตัดกฎได้ | kernel บางส่วน | mandatory kernel + omissions + stale fail |
| Authority | AI เลื่อน verdict ได้ | บาง transition unclear | seat/signature ชัด |
| External trust | index รวม | มี label | namespace + promotion gate |
| Migration | big-bang | pilot แต่ rollbackไม่ชัด | additive + shadow + rollback |
| Measurability | subjective | metrics แต่ไม่มี baseline | baseline + numeric gates |
| Simplicity | Wiki ใหญ่ทันที | MVP มากกว่า 3 ชิ้น | 3-piece MVP ก่อน |

**ขั้นต่ำเสนอ:** ไม่มี dimension ใดได้ 0 และรวม ≥13/16 ก่อนเปิด implementation planning

---

## 18. Final recommendation of this draft

ทิศทางมีศักยภาพแก้ปัญหา agent memory/context drift ได้จริง แต่ความสำเร็จขึ้นกับการไม่สร้าง “ความจริงชุดที่สอง”

ลำดับที่ปลอดภัยที่สุดคือ:

1. ownership map
2. append-only experiment events
3. bounded Context Packet พร้อม hash/freshness/trust
4. active generated view
5. shadow pilot + golden questions
6. cards/wiki/AI monitoring หลัง MVP พิสูจน์ตัวเอง

จนกว่า consensus gate จะผ่าน เอกสารนี้เป็นเพียงข้อเสนอสำหรับการถกเถียงและ **ไม่อนุญาตให้ agent ใดนำไปสร้าง order หรือเริ่มงาน**

---

# 19. FABLE REVIEW — `ACCEPT-WITH-CHANGES` (2026-07-11, Fable-seat, user สั่ง review โดยตรง)

## 19.1 คำตอบ 4 คำถามหลัก (§1)

**Q1 — "memory-control MVP ก่อน Wiki เต็มระบบ" ถูกไหม? → ถูก แต่ลำดับ MVP ผิด.**
หลักฐานจากวันนี้เอง: ปัญหาที่ **วัดได้จริง** คือ taskboard 539KB/4,532 บรรทัด (lead อ่านทั้งไฟล์ไม่ได้แล้ว, agent ทุกตัวเผา
token อ่านมัน) และ agent stall 8 ครั้ง — ไม่ใช่ "fact เก่าถูกหยิบผิด" (เกิดน้อยกว่ามาก เพราะ order brief ที่ lead เขียน
ทำหน้าที่ packet อยู่แล้วโดยพฤตินัย). **ลำดับใหม่: MVP-3 (active view + archive index) → MVP-1-lite → MVP-2
เลื่อนไปหลังมี baseline พิสูจน์ว่า brief-caused error มีจริง** — MVP-2 คือชิ้นที่แพงสุด (hash/freshness/lint machinery)
และเป็นชิ้นเดียวที่เสี่ยงกลายเป็น "ความจริงชุดที่สอง" ตามที่ §18 เตือนเอง. อย่าสร้างจนกว่า Phase-1 measurement บังคับ.

**Q2 — ownership แบ่งยังไงไม่ให้เกิด truth ชุดที่สอง? → ตอบได้เลย ไม่ต้องรอ:**
- **Experiment Event Log (MVP-1) = owner ของ fact ชนิดใหม่** (event chain: prereg→run→result→amendment→review) —
  ไม่ชนใครเพราะวันนี้ fact ชนิดนี้กระจายอยู่ใน order text แบบไม่มี owner (บทเรียน ST03: bar โผล่มากับ result commit)
- taskboard ยัง owns: order text + acceptance + raw result narrative · scorecard owns verdict · DEPLOYMENTS.csv owns
  deployment · **packet/view owns ศูนย์** (generated เสมอ ถูก checker ตรวจแบบเดียวกับ dashboard-map↔CSV ที่ ORDER-093
  พิสูจน์แล้วว่า pattern นี้ทำงานจริง)

**Q3 — gates/rollback พอไหม? → พอ + เพิ่ม 1 gate:** MVP-2 เริ่มได้ต่อเมื่อ Phase-1 baseline โชว์ context-caused
error ≥ threshold ที่ user ตั้ง (ไม่ใช่เริ่มเพราะ "ออกแบบไว้แล้ว") · rollback triggers ครบดี · เพิ่ม metric
**"lead-attention hours"** ใน §15 — ทรัพยากรที่ขาดจริงของโรงงานคือเวลา judge ไม่ใช่ token

**Q4 — เพิ่ม/ตัด/เลื่อนอะไร?**
- **เพิ่ม (หายไปจากแผนทั้งที่เป็น waste ที่วัดได้ใหญ่สุดของวันนี้): execution harness** — `run_batch.ps1` ให้ agent
  เรียก 1 คำสั่ง blocking ทั้ง batch (ฆ่า stall class 8 ครั้ง/วัน เชิงโครงสร้าง) + zombie-tester cleanup · ถูกกว่า
  memory-OS ทุกชิ้นและ ROI สูงกว่า
- **ตัด/เลื่อน:** agent benchmark (§12.2) → Phase 5+ (golden questions ให้ 80% ของค่า) · Regime cards + AI
  monitoring assistant → มีใน MASTER_BACKLOG P1/P2 อยู่แล้ว **ให้ reference ไม่ใช่ re-specify** (ไม่งั้น §10
  กลายเป็น duplicate owner ของ monitoring roadmap — ขัดกฎ one-fact-one-owner ของแผนเอง)

## 19.2 ตอบ §16 ข้อที่ตัดสินได้เลย (lead call)
(2) **JSONL** append-only, 1 ไฟล์/เดือน, อยู่ใน git (diff ธรรมชาติ; SQLite=opaque, CSV=escaping-pain) ·
(3) packet **ไม่ commit** — generate ชั่วคราว, commit เฉพาะ generator+ownership map, packet_hash บันทึกใน result block ·
(4) packet **ห้ามแทน mandatory docs ในงาน money/verdict ตลอดไป**; งาน worker mechanical ที่ bounded อนุญาตหลัง Phase-3 gate ·
(5) archive ตาม design ที่ lead เสนอ user แล้ววันนี้ (ARCHIVE_TASKBOARD_2026-07A.md + INDEX 1 บรรทัด/order ในบอร์ดใหม่) ·
(9) worker เลื่อนได้เฉพาะ execution states — ตาม AGENTS.md เดิมไม่เปลี่ยน ·
(12) pilot campaign แรก = **ORDER-095 (Boss_14 expansion)** — งานซ้ำรูปแบบ, bounded, วัด A/B full-context vs packet ได้ตรงสุด ·
(14) เก็บเป็น architecture doc แยก (ROADMAP ชี้มา) — อย่า merge จนผ่าน Phase 2

## 19.3 หลักฐานสดที่ยืนยัน thesis ของแผน (จากในตัวแผนเอง)
§11 เขียน JUMSTOCH config = "EURUSD H1 + AUDUSD H1 + GBPUSD H4" — **stale แล้วภายในไม่กี่ชั่วโมง**: D1e/D1f
ทับด้วย core ใหม่ EURGBP H1 + NZDUSD H4 + GBPUSD H4 (EURUSD/AUDUSD = watch). นี่คือตัวอย่างจริงว่า
snapshot-in-prose เน่าเร็วแค่ไหน = argument ที่ดีที่สุดของ freshness/invalidation ที่แผนเสนอ. จดไว้เป็น exhibit A.

## 19.4 Rubric (ให้คะแนนตรง): one-owner 2 · evidence 2 · context-safety 2 · authority 2 · external-trust 2 ·
migration 2 · **measurability 1** (ยังไม่มี baseline จริง) · **simplicity 1** (อ้าง 3-piece แต่ MVP-2 หนักกว่าที่โชว์) = **14/16 ผ่าน**

## 19.5 สรุป verdict
**ACCEPT-WITH-CHANGES:** (1) สลับลำดับ MVP เป็น 3→1→2 และ gate MVP-2 ด้วย baseline (2) เพิ่ม execution-harness
workstream (3) §10/§12.2 reference backlog แทน re-specify (4) แก้ §11 ให้ตรง D1f + จดเป็น exhibit ของ freshness
(5) เพิ่ม lead-attention-hours metric · การตัดสินใน 19.2 = คำตอบ lead สำหรับ §16 ข้อ 2,3,4,5,9,12,14 — เหลือ
ข้อ 1(รายละเอียด),6,7,8,10,11,13 ให้ user+Claude เคาะตอน Phase 1 · **Consensus lock ช่อง "Fable review พร้อม
ข้อทักท้วง" = ✅ ติ๊กได้** · ห้าม implement จนกว่า user อนุมัติ final design ตามเดิม

