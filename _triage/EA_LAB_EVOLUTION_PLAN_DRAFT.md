# EA_LAB Evolution Plan — Memory-Controlled Investment Operating System

> **สถานะ: FINAL DESIGN RECONCILED AFTER SECOND REVIEW — PENDING CANONICALIZATION / IMPLEMENTATION ORDERS — DO NOT IMPLEMENT FROM THIS FILE**
> **วันที่ร่าง:** 2026-07-11  
> **ผู้ริเริ่ม:** user · **ผู้สังเคราะห์ร่าง:** Codex  
> **เอกสารนี้ไม่มีอำนาจเปลี่ยน** `VISION.md`, `ROADMAP.md`, `PROJECT_STATE.md`, `AGENTS.md`, verdict, deployment, taskboard หรือ source code  
> **ห้ามเปิด order / ย้ายไฟล์ / สร้างระบบ / migrate ข้อมูลจากร่างนี้** จนกว่า Claude/user จะเขียนและอนุมัติ implementation orders ตาม `AGENTS.md`

> [!IMPORTANT]
> **Normative rule:** ใช้เฉพาะ **§20 AUTHORITATIVE FINAL IMPLEMENTATION BRIEF** เป็นแหล่งแตก implementation orders
> ส่วน §1–18 คือข้อเสนอเดิมที่ `SUPERSEDED` และ §19 คือ review history — ทั้งหมดเป็น non-executable appendix
> ห้าม agent resolve ความขัดแย้งระหว่าง section เอง; ถ้า §1–19 ขัดกับ §20 ให้ §20 ชนะเสมอ

**Consensus lock (ต้องครบทุกช่องก่อนเริ่ม):**

- [x] User เห็นชอบทิศทางร่าง
- [x] Fable review พร้อมข้อทักท้วง — `ACCEPT-WITH-CHANGES`, rubric 14/16, commit `4ff2051`
- [x] Claude/Fable lead สังเคราะห์ข้อเห็นตรง/ต่างใน §19
- [x] User อนุมัติ final design + ค่าแนะนำทั้งหมด — 2026-07-12
- [x] Codex outsider review รอบสองถูก reconcile เข้า authoritative §20 — 2026-07-12
- [ ] Claude/user เขียน implementation orders ตามสิทธิ์ใน `AGENTS.md`

ความเงียบหรือการไม่มีข้อค้าน **ไม่ถือเป็น approval**

---

# APPENDIX A — DESIGN AND REVIEW HISTORY (NON-EXECUTABLE)

> §1–18 เก็บข้อเสนอเดิมเพื่อ audit trail เท่านั้น; §19 เก็บ Fable review เท่านั้น
> ห้ามใช้ appendix นี้เป็น order source หรือ source of truth

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

## 7. [SUPERSEDED] Memory-control MVP — เริ่มแค่ 3 ชิ้น

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

## 10. [SUPERSEDED] Monitoring architecture

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

## 11. [SUPERSEDED SNAPSHOT] Strategy and portfolio direction

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

## 12. [SUPERSEDED] Agent workflow and benchmark

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

## 13. [SUPERSEDED] Phased roadmap and gates

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

## 18. [SUPERSEDED] Final recommendation of this draft

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

---

# 20. AUTHORITATIVE FINAL IMPLEMENTATION BRIEF (2026-07-12)

## 20.1 Approval record

User อนุมัติ **final design ตาม Fable changes ใน §19** และตอบ “ใช้คำแนะนำทั้งหมด” ต่อ defaults ที่ Codex
สังเคราะห์ให้หลัง review จากนั้น Codex ทำ outsider review รอบสองและ user สั่งให้แก้ตามข้อแนะนำทั้งหมด
section นี้จึงเป็น **order source เพียงชุดเดียว**; §1–19 เป็น design/review history และไม่มีอำนาจเชิงปฏิบัติ

การอนุมัตินี้อนุมัติ **ทิศทางและค่า default** เท่านั้น เอกสารนี้ยังไม่ใช่ order และไม่มีสิทธิ์สั่ง agent ให้แก้
canonical docs, source, monitoring, deployment หรือเงินจริง การเริ่มงานต้องรอ Claude/user แตก implementation
orders ตาม `AGENTS.md`

**Fable final review (2026-07-12, รอบปิด quota):** PASS-WITH-FIXES — fixes ถูก apply ในไฟล์นี้แล้วก่อน commit:
(1) ยก locked MVP-2 constraints จาก §19 ขึ้น §20.4 (ไม่งั้นถูก orphan เพราะ §20.9 ห้ามอ้าง appendix)
(2) เพิ่ม B0 reality clause — metric ประวัติศาสตร์ที่ไม่เคยบันทึก = `NOT_RECORDED` และ pin ว่า MVP-2 gate ใช้
B1 absolute triggers (§20.3 ตารางกับ §20.4 เดิมพูดไม่ตรงกัน) (3) แก้ path `portfolio/DEPLOYMENTS.csv`
(4) order ทุกใบต้องอ้าง §20 พร้อม commit SHA

## 20.2 Final workstream sequence

1. **B0 historical baseline + ownership map**
2. **MVP-0 execution harness** — inventory runner เดิมก่อน; blocking, lane-aware, fail-visible, resume evidence
3. **MVP-3 canonical active taskboard + immutable archive + generated read-only index/view**
4. **MVP-1-lite append-only experiment events + durable evidence manifest** — JSONL รายเดือนใน git
5. **หยุด review หลัง implementation order ที่ 4** แม้ workstream ใดยังไม่จบ; ห้ามบีบหลายงานให้เป็น order ใหญ่
6. เก็บ **B1 post-change observation cohort 20 orders** หลัง MVP-3 และ MVP-1-lite ผ่าน acceptance
7. **MVP-2 Context Packet generator เฉพาะเมื่อ B1 เข้า trigger**
8. Generated cards/Wiki/AI monitoring/agent benchmark ทำภายหลังตาม canonical owner/backlog และ phase gates เท่านั้น

## 20.3 Locked operating defaults

| Decision | Approved default |
|---|---|
| Capacity ช่วงเริ่ม | **70% system improvement / 30% EA research เป็นเวลา 2 สัปดาห์ วัดจาก planned lead-attention hours**; agent runtime และ compute time รายงานแยก |
| Research continuity | ไม่หยุดโรงงานทั้งหมด; ทำเฉพาะ campaign ที่กำลังเดินและ EV สูง · ห้ามเปิด mass intake ใหม่ช่วง pilot |
| Backfill | งานใหม่ทุกงาน + historical canary 3 เคสเท่านั้น; ของเก่า backfill เมื่อถูกหยิบใช้อีกครั้ง |
| Historical canaries | ST03 · Boss_16 · ORDER-095/Boss_14 |
| Context Packet measurement | เปรียบเทียบ **B0 historical 20 orders** กับ **B1 post-change 20 orders** ก่อนตัดสินสร้าง MVP-2 |
| User interface | **HTML/mobile = executive view · Markdown/Git = evidence + audit trail** |
| AI monitoring authority | เริ่ม **shadow / alert-only**; canonical risk/deployment config owns thresholds และ deterministic layer เป็น runtime enforcer เท่านั้น |
| Implementation time-box | ไม่เกิน **4 orders** แล้วหยุด review รอบแรก |
| Critical error tolerance | factual/authority error ที่กระทบ money/live = **0** |
| Rollback | component ใดทำ canonical write path, evidence หรือ safety แย่ลงให้ rollback component นั้นทันทีตาม §20.8; money/live critical incident หนึ่งครั้ง = หยุด pilot |

### B0/B1 measurement contract

- **B0 historical baseline:** 20 orders ที่ปิดก่อนเปลี่ยน component ใด; เก็บ onboarding time, context incident,
  context-related rework, wrong order/file/scope และ lead-attention hours โดยไม่ย้ายข้อมูลเดิม
- **B0 reality clause:** metric ที่ไม่เคยถูกบันทึกตอนงานประวัติศาสตร์วิ่ง (เช่น onboarding time, lead-attention
  hours) ให้ mark `NOT_RECORDED` — ห้าม reconstruct จากความจำ; การเทียบ B0↔B1 ใช้เฉพาะ metric ที่มีจริงทั้งสองฝั่ง
  (rework/wrong-scope นับจาก git + taskboard history ได้); **MVP-2 gate ตัดสินจาก B1 absolute triggers ใน §20.4
  เท่านั้น** — B0 มีหน้าที่วัดว่า MVP-0/3/1 ทำให้ดีขึ้นจริงไหม ไม่ใช่เงื่อนไขเปิด MVP-2
- **B1 observation cohort:** 20 orders ถัดจาก MVP-3 และ MVP-1-lite ผ่าน acceptance; ใช้นิยามและ denominator เดียวกับ B0
- `context-related rework %` = จำนวน order ใน cohort ที่ต้องทำซ้ำเพราะบริบท/authority ผิด ÷ order ทั้งหมดใน cohort
- `critical` = factual/authority error ที่อาจเปลี่ยนเงินจริง, live action, risk control, verdict หรือสิทธิ์ผู้ตัดสิน
- monthly trigger วัดเมื่อครบทั้ง B1 และอย่างน้อย 30 วัน; เก็บ actual lead-attention hours ห้าม extrapolate จากช่วงสั้น

## 20.4 MVP-2 evidence triggers

สร้าง Context Packet machinery ต่อเมื่อ B1 พบอย่างน้อยหนึ่งข้อ:

- noncritical context/authority misunderstanding ≥2 ครั้ง
- context-related rework >10%
- lead ใช้เวลาแก้ความเข้าใจผิดจาก context >2 ชั่วโมง/เดือน
- wrong order/file/scope ≥2 ครั้ง
- onboarding agent ใหม่ยังใช้เวลา >10 นาทีเพื่อระบุ current task/authority/ข้อห้าม

critical incident ที่แตะ money/live **ไม่ใช่ trigger ให้รอสร้าง MVP-2** แต่เป็น stop/rollback trigger ตั้งแต่ครั้งแรก

ถ้าไม่เข้า trigger ให้ใช้ order brief + active view + experiment events ต่อไป และ **ไม่สร้าง MVP-2 เพียงเพราะ
architecture ออกแบบไว้แล้ว**

**Locked MVP-2 constraints (ยกจาก §19 ให้มีผลใน §20 — ถ้าสร้าง MVP-2 ต้องถือตามนี้ ห้ามอ้างว่า appendix หมดอายุ):**

- packet **ไม่ commit เข้า git** — generate ชั่วคราวเสมอ; commit เฉพาะ generator + ownership map; บันทึกเฉพาะ `packet_hash` ใน result block
- packet **ห้ามแทน mandatory docs ในงาน money/verdict ตลอดไป**; งาน worker mechanical ที่ bounded อนุญาตได้หลัง Phase-3 gate เท่านั้น
- packet ที่ `STALE` ห้ามใช้ทำ verdict หรือเงินจริง; generator ต้อง deterministic (input commit เดียวกัน → packet hash เดียวกัน) และแสดงสิ่งที่ omit
- pilot campaign แรกของ MVP-2 = **ORDER-095 (Boss_14 expansion)** วัด A/B full-context vs packet

## 20.5 Decisions delegated to Claude/Codex under orders

ไม่ต้องย้อนถาม user สำหรับรายละเอียด reversible/mechanical ต่อไปนี้ ตราบใดที่ไม่เปลี่ยน owner/authority/เงินจริง:

- JSONL field naming, `schema_version`, event ID และ monthly rotation ภายใต้ append contract ใน §20.7
- evidence ID implementation; `path + git SHA + file hash` ใช้ได้เมื่อ artifact อยู่ใน git และกู้คืนได้เท่านั้น
- PowerShell/Python runner design หลัง inventory runner เดิม; ห้ามสร้าง runner ซ้ำโดยไม่บันทึกเหตุผล
- archive index/file naming
- test fixtures, generated banners และ lint implementation
- zombie/stale-lane detection แบบ path/lane scoped และ report-only; ห้าม terminate process หรือเลี่ยง no-kill rules

## 20.6 Decisions deferred until evidence exists

ยังไม่เคาะใน Phase 1:

- exact DD/margin/monitoring thresholds
- false/missed alert tolerance
- automatic `BLOCK_NEW` หรือ emergency close
- Regime Card canonical owner
- RAG/vector database
- premium-track risk budget
- full agent benchmark

หัวข้อ monitoring/benchmark/strategy/phase gates ที่มี owner อยู่ใน `MASTER_BACKLOG.md`, `ROADMAP.md`,
`EDGE_CATALOG.md`, scorecard, deployment inventory หรือ taskboard ให้ reference owner เดิม ห้าม re-specify
ค่า threshold, strategy snapshot, verdict หรือ roadmap ใน architecture plan; generated cards ต้อง derive จาก owner เดิม

## 20.7 Artifact ownership and write contracts

| Artifact/fact | Canonical owner and write path | Generated/reference rule |
|---|---|---|
| Active order text, acceptance, execution state, raw result narrative | `AGENT_TASKBOARD.md`; agent แก้ได้เฉพาะ order block ของตัวเองตาม `AGENTS.md` | ห้าม generated view รับ write-back |
| Reviewed order history | immutable archive เก็บ REVIEWED block แบบ verbatim พร้อม stable ORDER ID/anchor | index และ active view เป็น generated/read-only |
| Structured experiment timeline | monthly JSONL เก็บ occurrence metadata + hashes + references เท่านั้น | ใช้ `RESULT_LINKED`, `REVIEW_LINKED`, `DECISION_LINKED`; ห้ามคัดลอก result/verdict text |
| Verdict/decision/deployment | scorecard, `PROJECT_STATE.md` decision owner และ `portfolio/DEPLOYMENTS.csv` ตามกติกาเดิม | Event Log เก็บเพียง owner path/hash/reference |
| Decisive evidence | artifact ที่ tracked หรือ durable evidence store/backup พร้อม manifest และ existence check | ignored/transient report ห้ามถือว่าถาวรเพียงเพราะมี path/hash |
| Safety thresholds | canonical risk/deployment config | deterministic layer enforce; AI อธิบาย/alert เท่านั้น |

JSONL ต้องเขียนผ่าน append utility ตัวเดียวที่มี file lock, atomic append, schema validation, unique event ID,
idempotency และ append-only correction/amendment ห้ามหลาย agent เขียนไฟล์รายเดือนโดยตรง

## 20.8 Bounded implementation workstream contracts

รายการนี้เป็น **design contract ไม่ใช่ implementation order**; Claude/user ต้องแตก order ตาม `AGENTS.md`

### Contract A — B0 + ownership map

- **Output:** fact→owner map, incident taxonomy และ B0 report จาก historical orders 20 งานที่คำนวณซ้ำได้
- **Out of scope:** migrate data หรือเปลี่ยน authority
- **Acceptance:** owner conflict = 0; sample trace กลับ canonical ได้; metrics คำนวณซ้ำได้หรือ mark `NOT_RECORDED` ตาม B0 reality clause (§20.3) — ห้ามใส่ตัวเลขที่ reconstruct จากความจำ
- **Rollback:** ลบ generated report/map; canonical docs ต้องไม่เปลี่ยน

### Contract B — MVP-0 harness

- **Output:** inventory runner เดิม แล้วทำ blocking wrapper/adapter ที่ lane-aware, fail-visible และมี resume manifest
- **Out of scope:** global process kill, `-Force` หรือเปลี่ยน tester safety
- **Acceptance:** success/failure fixture, non-zero exit, stop-on-failure, lane-lock test และ interrupted-run resume ผ่าน
- **Rollback:** กลับไปใช้ direct runner เดิมและเก็บ manifest เป็นหลักฐาน

### Contract C — MVP-3 active/archive

- **Output:** คง `AGENT_TASKBOARD.md` เป็น writable queue; archive REVIEWED blocks; สร้าง read-only index/view
- **Out of scope:** เปลี่ยน worker authority หรือลบ history
- **Acceptance:** claim/result path ยังทำงาน; block count/ORDER ID ตรง; anchors/links ผ่าน; archive round-trip ได้
- **Rollback:** restore pre-migration copy และปิด generator

### Contract D — MVP-1-lite events

- **Output:** locked JSONL append utility, linked-event schema และ durable evidence manifest
- **Out of scope:** verdict owner ใหม่, bulk backfill หรือ Context Packet generator
- **Acceptance:** concurrent/idempotent/schema/corrupt-line tests ผ่าน; canary trace และ evidence existence = 100%
- **Rollback:** ปิด append utility; rebuild จาก canonical refs; correction ใช้ amendment/tombstone event

การครบสี่ order คือ **review gate** ไม่ใช่คำสั่งให้สี่ workstream จบภายในสี่ order

## 20.9 Next review checklist

review รอบถัดไปควรตรวจเฉพาะ:

1. implementation orders อ้างเฉพาะ §20 และไม่ดึงข้อกำหนดจาก appendix หรือไม่
2. owner/write path ตรง §20.7 และไม่มี source of truth ซ้ำหรือไม่
3. harness reuse runner เดิมและไม่ละเมิด no-kill/lane rules หรือไม่
4. B0/B1 ใช้นิยามเดียวกันและเก็บหลักฐานที่กู้คืนได้หรือไม่
5. แต่ละ order เป็นงานจบในตัว มี acceptance/rollback และหยุด review หลัง order ที่ 4 หรือไม่

**Current gate:** final design approved แล้ว แต่ implementation ยัง `LOCKED` จนกว่าช่องสุดท้ายของ Consensus lock
ถูกติ๊กด้วย implementation orders ที่ Claude/user อนุมัติตามสิทธิ์

**Canonicalization anchor:** ไฟล์นี้อยู่ใน `_triage/` — implementation order ทุกใบต้องอ้าง
`_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md §20 @ <commit SHA>` (ไม่ใช่ "ตาม draft ล่าสุด") และตอนแตก order
ชุดแรกให้เพิ่ม pointer หนึ่งบรรทัดใน `PROJECT_STATE.md` Decision log ชี้มาที่ SHA เดียวกัน — แก้ §20 หลังจากนั้น
= ต้องเปิด review ใหม่ ห้าม edit เงียบ
