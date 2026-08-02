"""
control_center.py - ORDER-1131 (slice S11). The Control Center page model, in SHADOW MODE.

WHAT THIS IS
  A PURE projection: (snapshot read, work rows, findings, now) -> four pages, TODAY / WORK /
  LIVE / SYSTEM. It reads nothing and writes nothing. The reading is done by
  snapshot_validator.load_verified() and the writing is done by nobody, because design 10's
  prohibition for this slice is "no dispatch, claim, or closure from the UI" and the cheapest
  way to keep that true is for the UI layer to contain no verb that could.

WHY THE ORDER IS THE PRODUCT
  design 7.1 fixes the TODAY order and says so: (1) snapshot health (2) start-now
  (3) needs-you (4) stuck (5) review/audit (6) ready (7) waiting (8) just-done, with every row
  rendering WHY IT IS WHERE IT IS. So band placement here is not a heuristic and not a sort
  key: it is a table of numbered rules, first match wins, and each row carries the id of the
  rule that placed it. A row no rule matches REFUSES the build. That is the difference between
  a layout and a claim.

THE ONE RULE EVERYTHING ELSE HANGS OFF
  "Cannot read it" must never render as "nothing wrong". design 7.1's very first row is
  `ALL CLEAR`, which makes it the single most dangerous cell in the product: a snapshot this
  shell cannot parse must render `UNKNOWN` and say which of the two it is (the DOCUMENT was
  refused, or the INSTRUMENT could not run), and it must suppress every number on every page.
  Three of the six defects the S10 audit rounds found were an unreadable input rendering as a
  satisfied rule, and two of those were inside code written to close that shape.
  (memory: unreadable-input-must-refuse-not-skip, guard-disarmed-by-prose-reported-as-note)

AND THE ONE THAT COST AN AUDIT ROUND ELSEWHERE
  `reconciliation_clear: true` is NOT fleet health. snapshot_validator says so at length: it
  covers the order/coverage reconciliation and mandatory-source freshness, and Codex audit 6
  built a document with a dead sensor, a blind risk sensor, missing kill controls and missing
  attestation that verified `true`, correctly. So TODAY's headline is computed from the verdict
  AND the LIVE exception bands, and renders `ATTENTION` whenever LIVE has an exception - the
  headline can only say `ALL CLEAR` when there is nothing to be un-clear about.

TESTS  tools\\python312\\python.exe _triage/factory_os/run_s11_tests.py
"""
import collections
import sys

# The reader states, spelled EXACTLY as scripts\lib\snapshot_reader.ps1 spells them, because
# the two are one vocabulary in two languages and a second spelling is a second meaning.
SnapshotRead = collections.namedtuple('SnapshotRead', 'state code reason document')

READ_OK = 'OK'
READ_REFUSED = 'REFUSED'
READ_UNAVAILABLE = 'UNAVAILABLE'


class ShellRefusal(Exception):
    """An input this shell cannot place. Never rendered as an empty page."""


def _refuse(msg):
    raise ShellRefusal(msg)


# ---------------------------------------------------------------------------------------
# TODAY - the eight bands, in the order design 7.1 fixes. The ids are stable English; the
# labels are the Thai the design writes them in.
# ---------------------------------------------------------------------------------------
TODAY_BANDS = (
    ('SNAPSHOT_HEALTH', 'สถานะ snapshot'),
    ('START_NOW', 'ควรเริ่มตอนนี้'),
    ('NEEDS_YOU', 'ต้องการคุณ'),
    ('STUCK', 'ติดขัด / session อาจหลุด'),
    ('REVIEW_AUDIT', 'รอ Review / Audit / Handoff'),
    ('READY', 'พร้อมทำ'),
    ('WAITING', 'กำลังรอ'),
    ('JUST_DONE', 'เพิ่งเสร็จ'),
)

# design 7.1: "real-money incident -> user decision -> started-but-stuck -> blocking other
# work -> due monitor/judge/reopt/audit -> ready -> ideas". This is the WITHIN-band sort and
# the input vocabulary for a row's urgency. An unlisted value refuses.
PRIORITY_LADDER = (
    'REAL_MONEY_INCIDENT',
    'USER_DECISION',
    'STARTED_BUT_STUCK',
    'BLOCKING_OTHER_WORK',
    'DUE',
    'READY',
    'IDEA',
)

# design 7.1's full WORK lifecycle. `DONE` is deliberately NOT here: it is normalised to
# DONE_PENDING_REVIEW on the way in, because "DONE is not closed - it stays visible as
# DONE_PENDING_REVIEW until reviewed". `AGING` and `NEGLECTED` are deliberately NOT here
# either, and an input carrying one is refused rather than mapped: "a state that means 'old
# work may be ignored' is how work gets ignored", and silently accepting it would reinstate it
# under another name.
WORK_STATES = (
    'CAPTURED', 'READY', 'IN_PROGRESS', 'WAITING', 'BLOCKED', 'HANDOFF',
    'DONE_PENDING_REVIEW', 'AUDIT_REQUIRED', 'AUDIT_IN_PROGRESS', 'REWORK',
    'REVIEWED', 'CANCELLED_BY_USER', 'STATE_CONFLICT',
)
STATE_ALIASES = {'DONE': 'DONE_PENDING_REVIEW'}

# design 7.1: a claim with no heartbeat/process/evidence for >30 min shows the stuck label.
# The number lives HERE, once, and is the design's own - not a new risk threshold.
STALE_CLAIM_MINUTES = 30

# design 7.1: "only lower-priority ready work is capped at 5-7 with an explicit hidden count
# and expand-all. No hard cap on tasks or ideas." So the cap applies to these bands and to no
# other, and it is a DISPLAY cap that must publish what it hid (design 7.4).
CAPPED_BANDS = ('READY', 'JUST_DONE')
BAND_DISPLAY_CAP = 7


def _assert_read_contract(read):
    """
    ROUND-1 FIX. `read.document or {}` turned the contradiction OK-with-no-document into
    ATTENTION with zero reasons and numbers NOT suppressed - a headline manufactured out of
    nothing at all. snapshot_reader.ps1's contract is that Document is populated if and ONLY if
    State is OK ("deliberately, so a caller cannot accidentally read numbers off a document the
    checker rejected"), so a caller that breaks it gets a refusal, not a page.
    """
    if read.state == READ_OK and not isinstance(read.document, dict):
        _refuse('the reader reported OK and handed back no document (%s). OK means the bytes '
                'were verified, so an absent document is a broken caller - and rendering one '
                'would invent a headline from nothing.' % type(read.document).__name__)


def _stuck(row):
    age = row.get('heartbeat_age_min')
    return (row.get('state') == 'IN_PROGRESS' and age is not None
            and age > STALE_CLAIM_MINUTES)


# The placement table. ORDERED, first match wins, and the id travels with the row as its
# `why`. Adding a band or a state means adding a rule here, which is a reviewable act.
BAND_RULES = (
    ('B01', lambda r: r.get('priority') == 'REAL_MONEY_INCIDENT', 'START_NOW',
     'เหตุการณ์เงินจริง — อยู่บนสุดของบันไดความสำคัญ'),
    ('B02', lambda r: r.get('state') == 'STATE_CONFLICT', 'NEEDS_YOU',
     'สองแหล่งขัดกัน — คนต้องชี้ขาด'),
    ('B03', lambda r: r.get('priority') == 'USER_DECISION', 'NEEDS_YOU',
     'รอผู้ใช้ตัดสิน'),
    ('B04', _stuck, 'STUCK',
     'เคลมไว้แต่ไม่มี heartbeat/process/evidence เกิน %d นาที' % STALE_CLAIM_MINUTES),
    ('B05', lambda r: r.get('priority') == 'STARTED_BUT_STUCK', 'STUCK',
     'เริ่มแล้วแต่ค้าง'),
    ('B06', lambda r: r.get('state') == 'BLOCKED', 'STUCK',
     'ถูกบล็อก'),
    ('B07', lambda r: r.get('priority') == 'BLOCKING_OTHER_WORK', 'START_NOW',
     'บล็อกงานอื่นอยู่'),
    ('B08', lambda r: r.get('state') in ('DONE_PENDING_REVIEW', 'AUDIT_REQUIRED',
                                         'AUDIT_IN_PROGRESS', 'HANDOFF', 'REWORK'),
     'REVIEW_AUDIT', 'รอ review / audit / handoff — ยังไม่ปิด'),
    ('B09', lambda r: r.get('priority') == 'DUE', 'START_NOW',
     'ถึงกำหนด monitor / judge / reopt / audit'),
    ('B10', lambda r: r.get('state') == 'WAITING', 'WAITING',
     'รออยู่'),
    ('B11', lambda r: r.get('state') == 'IN_PROGRESS', 'START_NOW',
     'กำลังทำอยู่และยังมี heartbeat'),
    ('B12', lambda r: r.get('state') in ('READY', 'CAPTURED'), 'READY',
     'พร้อมทำ'),
    ('B13', lambda r: r.get('state') in ('REVIEWED', 'CANCELLED_BY_USER'), 'JUST_DONE',
     'เพิ่งปิด'),
)

DECISION_PARTS = ('question', 'options', 'recommendation', 'consequence_of_not_deciding')


def normalise_row(row):
    """One row in, one row out - or a refusal naming the row. Never a dropped row."""
    if not isinstance(row, dict):
        _refuse('a work row is %s, not an object' % type(row).__name__)
    out = dict(row)
    rid = out.get('id')
    if not rid:
        _refuse('a work row has no id, so it cannot be rendered or referred to')
    state = STATE_ALIASES.get(out.get('state'), out.get('state'))
    if state not in WORK_STATES:
        _refuse('row %s carries state %r, which is not one of design 7.1\'s %d states. '
                'Refusing rather than bucketing it: `AGING`/`NEGLECTED` were removed on purpose '
                'and a state this shell quietly accepts is that state coming back.'
                % (rid, out.get('state'), len(WORK_STATES)))
    out['state'] = state
    prio = out.get('priority', 'READY')
    if prio not in PRIORITY_LADDER:
        _refuse('row %s carries priority %r, which is not on design 7.1\'s ladder' % (rid, prio))
    out['priority'] = prio
    return out


def _decision_block(row):
    """
    design 7.1: a user-decision row must carry the question, the options, Claude's
    recommendation and the consequence of not deciding - "otherwise it renders
    `รอ Claude เตรียม decision brief` rather than dumping a vague question on the user".
    """
    decision = row.get('decision') or {}
    missing = [p for p in DECISION_PARTS if not decision.get(p)]
    if missing:
        return {'ready': False, 'missing': missing,
                'label': 'รอ Claude เตรียม decision brief',
                'why': 'ยังขาด: ' + ', '.join(missing)}
    return {'ready': True, 'missing': [],
            'label': 'พร้อมให้ตัดสิน',
            'parts': dict((p, decision[p]) for p in DECISION_PARTS)}


def _rework_block(row):
    """
    design 7.1: "Rework escalates: first defect same model -> second, stronger model -> after
    three cycles, `REWORK LOOP - review spec/approach` with a compact summary of repeated
    defects."
    """
    cycles = row.get('rework_cycles') or 0
    if cycles <= 0:
        return None
    if cycles == 1:
        return {'cycles': 1, 'route': 'SAME_MODEL', 'label': 'แก้รอบแรก — โมเดลเดิม'}
    if cycles == 2:
        return {'cycles': 2, 'route': 'STRONGER_MODEL', 'label': 'แก้รอบสอง — ยกไปโมเดลที่แรงกว่า'}
    return {'cycles': cycles, 'route': 'REWORK_LOOP',
            'label': 'REWORK LOOP — review spec/approach',
            'repeated_defects': list(row.get('repeated_defects') or [])}


def _waiting_block(row):
    """
    design 7.1: "`WAITING` requires `waiting_for` AND a wake condition, else
    `พักงานแบบไร้กำหนด — ต้องจัดการ`."
    """
    if row.get('state') != 'WAITING':
        return None
    if row.get('waiting_for') and row.get('wake_condition'):
        return {'ok': True, 'waiting_for': row['waiting_for'],
                'wake_condition': row['wake_condition']}
    missing = [k for k in ('waiting_for', 'wake_condition') if not row.get(k)]
    return {'ok': False, 'missing': missing, 'label': 'พักงานแบบไร้กำหนด — ต้องจัดการ'}


def _stage_block(row):
    """
    design 7.1: "Audit is a stage of the same row (`BUILD 1/2 -> AUDIT 2/2`), never a separate
    task that can be lost." So a row declares its stage and the shell renders it inside the
    row; there is no code path that turns a stage into a second row.
    """
    stage = row.get('stage')
    if not stage:
        return None
    if stage not in ('BUILD', 'AUDIT'):
        _refuse('row %s carries stage %r; the only stages design 7.1 names are BUILD and AUDIT'
                % (row.get('id'), stage))
    return {'stage': stage, 'label': 'BUILD 1/2' if stage == 'BUILD' else 'AUDIT 2/2'}


def place(row):
    """-> (band_id, rule_id, why). Refuses a row no rule matches."""
    for rule_id, pred, band, why in BAND_RULES:
        if pred(row):
            return band, rule_id, why
    _refuse('row %s (state=%s priority=%s) matched no placement rule. A row with nowhere to go '
            'is not rendered at the bottom of the page; it stops the build, because a shell '
            'that silently hides a row it does not understand is the failure mode this table '
            'exists to prevent.' % (row.get('id'), row.get('state'), row.get('priority')))


def build_today(read, rows, live):
    """
    The eight bands, always all eight, always in order. When the snapshot cannot be read the
    health row says so and every other band renders UNKNOWN with no numbers.
    """
    bands = collections.OrderedDict((bid, {'id': bid, 'label': label, 'rows': [],
                                           'hidden_count': 0, 'expand_all': False,
                                           'capped': bid in CAPPED_BANDS})
                                    for bid, label in TODAY_BANDS)
    health = _health_row(read, live)
    bands['SNAPSHOT_HEALTH']['rows'].append(health)

    if health['headline'] == 'UNKNOWN':
        # NOT an empty page and NOT a zero. design 7.1's first row is ALL CLEAR, so the only
        # safe rendering of "the shell could not read its input" is a stated UNKNOWN on every
        # band that would otherwise have carried a count.
        for bid in bands:
            if bid == 'SNAPSHOT_HEALTH':
                continue
            bands[bid]['unknown'] = True
            bands[bid]['why'] = health['why']
        return {'bands': list(bands.values()), 'health': health, 'unknown': True}

    placed = []
    for raw in rows:
        row = normalise_row(raw)
        band, rule_id, why = place(row)
        rendered = {
            'id': row['id'],
            'title': row.get('title', ''),
            'state': row['state'],
            'priority': row['priority'],
            'band': band,
            'why': '[%s] %s' % (rule_id, why),
            'rule': rule_id,
        }
        for name, block in (('decision', _decision_block(row) if row['priority'] == 'USER_DECISION' else None),
                            ('rework', _rework_block(row)),
                            ('waiting', _waiting_block(row)),
                            ('stage', _stage_block(row))):
            if block is not None:
                rendered[name] = block
        placed.append(rendered)

    order = dict((p, i) for i, p in enumerate(PRIORITY_LADDER))
    for row in sorted(placed, key=lambda r: (order[r['priority']], str(r['id']))):
        bands[row['band']]['rows'].append(row)

    for bid in CAPPED_BANDS:
        band = bands[bid]
        if len(band['rows']) > BAND_DISPLAY_CAP:
            band['hidden_count'] = len(band['rows']) - BAND_DISPLAY_CAP
            band['rows'] = band['rows'][:BAND_DISPLAY_CAP]
            band['expand_all'] = True
    return {'bands': list(bands.values()), 'health': health, 'unknown': False}


def _health_row(read, live):
    """
    Row (1). Three headlines and no fourth: ALL CLEAR / ATTENTION / UNKNOWN.

    UNKNOWN is reached from BOTH reader failures, and the two are distinguished in the text
    because their fixes differ - REFUSED is a statement about the document, UNAVAILABLE is a
    statement about the instrument (scripts\\lib\\snapshot_reader.ps1 owns that distinction and
    this row keeps it rather than collapsing it).
    """
    if read.state == READ_REFUSED:
        return {'headline': 'UNKNOWN', 'about': 'DOCUMENT', 'code': read.code,
                'why': 'snapshot มีอยู่แต่ถูกปฏิเสธ (%s) — ไม่แสดงตัวเลขใดๆ: %s'
                       % (read.code, read.reason),
                'numbers_suppressed': True}
    if read.state == READ_UNAVAILABLE:
        return {'headline': 'UNKNOWN', 'about': 'INSTRUMENT', 'code': read.code,
                'why': 'อ่าน snapshot ไม่ได้ (%s) — เป็นเรื่องของเครื่องมือ ไม่ใช่คำตัดสินเรื่องฟลีต: %s'
                       % (read.code, read.reason),
                'numbers_suppressed': True}
    if read.state != READ_OK:
        _refuse('unknown reader state %r - the three states are %s/%s/%s and a fourth would be '
                'a fourth meaning' % (read.state, READ_OK, READ_REFUSED, READ_UNAVAILABLE))
    _assert_read_contract(read)
    doc = read.document
    verdict = doc.get('verdict') or {}
    reasons = list(verdict.get('reasons') or [])
    exceptions = live['exception_count'] if live else 0
    clear = bool(verdict.get('reconciliation_clear')) and not reasons and exceptions == 0
    if clear:
        return {'headline': 'ALL CLEAR', 'about': 'FLEET', 'code': 'OK',
                'why': 'reconciliation ผ่าน และไม่มี exception ค้างในหน้า LIVE',
                'numbers_suppressed': False, 'reasons': [], 'live_exceptions': 0}
    return {
        'headline': 'ATTENTION', 'about': 'FLEET', 'code': 'OK',
        'numbers_suppressed': False,
        'reasons': [{'code': r.get('code'), 'detail': r.get('detail')} for r in reasons],
        'live_exceptions': exceptions,
        'why': ('reconciliation_clear=%s · เหตุผล %d ข้อ · LIVE exception %d รายการ — '
                'หมายเหตุ: reconciliation_clear ไม่ใช่คำตัดสินสุขภาพฟลีต '
                '(ครอบคลุมแค่ order/coverage reconciliation + ความสดของ mandatory source)'
                % (verdict.get('reconciliation_clear'), len(reasons), exceptions)),
    }


# ---------------------------------------------------------------------------------------
# WORK - the same rows, by lifecycle, plus the reconciliation the snapshot owns.
# ---------------------------------------------------------------------------------------

def build_work(read, rows):
    """
    Two halves that must not be confused:
      by_state   the rows this shell was handed.
      counts     what the SNAPSHOT says exists.
    When the second is non-zero and the first is empty, the page renders UNKNOWN. It does NOT
    render an empty queue - "the taskboard could not be read so STATUS showed an empty work
    queue" is one of the failure scenarios the Codex blind audit wrote down, and today it is
    the LIVE state of this repo: factory/work_receipts.jsonl carries no receipts yet (that
    import is S14), while the snapshot's reconciliation counts hundreds of orders.
    """
    by_state = collections.OrderedDict((s, []) for s in WORK_STATES)
    for raw in rows:
        row = normalise_row(raw)
        by_state[row['state']].append({'id': row['id'], 'title': row.get('title', ''),
                                       'state': row['state'], 'priority': row['priority']})
    page = {'by_state': by_state, 'states': list(WORK_STATES)}
    if read.state != READ_OK:
        page['counts'] = None
        page['unknown'] = True
        page['why'] = 'อ่าน snapshot ไม่ได้ (%s) — ไม่แสดงตัวเลข' % read.code
        return page
    rec = ((read.document or {}).get('meta') or {}).get('reconciliation') or {}
    page['counts'] = {
        'discovered': rec.get('discovered'),
        'categorized': rec.get('categorized'),
        'categories': dict(rec.get('categories') or {}),
        'unclassified': rec.get('unclassified'),
        'duplicates': rec.get('duplicates'),
        'conflicts': rec.get('conflicts'),
    }
    discovered = rec.get('discovered') or 0
    if not any(by_state.values()) and discovered > 0:
        page['unknown'] = True
        page['why'] = ('มี %d order ตาม reconciliation ของ snapshot แต่ไม่มี row ระดับรายการให้เรนเดอร์เลย — '
                       'เจ้าของข้อมูลระดับ row ยังไม่มี (S14 Work Receipts) ⇒ UNKNOWN ไม่ใช่ "คิวว่าง"'
                       % discovered)
    else:
        page['unknown'] = False
        page['why'] = ''
    unclassified = rec.get('unclassified') or 0
    duplicates = rec.get('duplicates') or 0
    page['unclassified_band'] = {
        'unclassified': unclassified, 'duplicates': duplicates,
        'shown': unclassified > 0 or duplicates > 0,
        'why': 'reconciliation จัดประเภทไม่ได้ %d · ซ้ำ %d — แสดงเป็นแถบของตัวเอง ไม่ถูกกลืนหาย'
               % (unclassified, duplicates),
    }
    return page


# ---------------------------------------------------------------------------------------
# LIVE - exception-first, never account-table-first.
# ---------------------------------------------------------------------------------------
LIVE_BANDS = (
    ('RISK', 'ความเสี่ยง / DD / margin'),
    ('SENSOR', 'sensor / VPS ไม่สด'),
    ('DRIFT', 'magic ไม่รู้จัก / deployment drift'),
    ('GOVERNANCE', 'ขาด kill-switch / attestation / governance'),
    ('DUE', 'ถึงกำหนด judge / reopt'),
    ('NORMAL', 'สรุปปกติ'),
    ('POSITIONS', 'โพซิชัน (ย่อไว้)'),
)
EXCEPTION_BANDS = ('RISK', 'SENSOR', 'DRIFT', 'GOVERNANCE', 'DUE')

# The sensor states this page treats as an exception. A closed set: an UNRECOGNISED state is
# refused, not assumed healthy.
SENSOR_HEALTHY = ('FRESH',)
SENSOR_KNOWN = ('FRESH', 'STALE', 'BLIND', 'MISSING', 'NO_SENSOR', 'UNKNOWN')


def build_live(read):
    bands = collections.OrderedDict((bid, {'id': bid, 'label': label, 'rows': []})
                                    for bid, label in LIVE_BANDS)
    if read.state != READ_OK:
        return {'bands': list(bands.values()), 'unknown': True, 'exception_count': 0,
                'why': 'อ่าน snapshot ไม่ได้ (%s) — หน้านี้ไม่แสดงตัวเลข' % read.code}
    doc = read.document or {}

    # Sensor freshness, and the CONFLICT rule: design 7.1 says the dashboard creates no
    # competing threshold and that "disagreement between detectors renders CONFLICT". The two
    # detectors that both speak about an account are system_health and floating_risk.
    # ROUND-1 BLOCKER FIX. This iterated system_health and joined floating_risk onto it, so an
    # account only the RISK detector knew about produced no row, added nothing to
    # exception_count, and therefore let TODAY render ALL CLEAR over a blind sensor with open
    # lots. The walk is now over the UNION, and a detector that is SILENT about an account is
    # itself the finding - symmetric in both directions, so neither detector is privileged.
    seen = {}
    order = []
    for source in ('system_health', 'floating_risk'):
        for row in doc.get(source, []) or []:
            acct = row.get('account')
            if acct not in seen:
                seen[acct] = {}
                order.append(acct)
            seen[acct][source] = row
    for acct in order:
        pair = seen[acct]
        states = {}
        for source in ('system_health', 'floating_risk'):
            row = pair.get(source)
            if row is None:
                continue
            state = row.get('state')
            if state not in SENSOR_KNOWN:
                _refuse('%s[%s] reports state %r, which this page does not know. '
                        'Refusing rather than treating it as healthy.' % (source, acct, state))
            states[source] = state
        missing = [s for s in ('system_health', 'floating_risk') if s not in states]
        if missing:
            bands['SENSOR']['rows'].append({
                'account': acct, 'state': 'UNKNOWN',
                'why': 'ตัวตรวจ %s ไม่รู้จักบัญชีนี้เลย — บัญชีที่ตัวตรวจตัวเดียวเห็น ยังไม่ถูกเฝ้าครบ '
                       '(สถานะที่อีกตัวรายงาน: %s)'
                       % (' + '.join(missing),
                          ', '.join('%s=%s' % kv for kv in sorted(states.items())) or 'ไม่มีเลย')})
            continue
        healthy = set(states[s] in SENSOR_HEALTHY for s in states)
        if len(healthy) > 1:
            bands['SENSOR']['rows'].append({
                'account': acct, 'state': 'CONFLICT',
                'why': 'system_health=%s แต่ floating_risk=%s — ตัวตรวจสองตัวไม่ตรงกัน '
                       'จึงเรนเดอร์ CONFLICT ไม่ใช่เลือกข้าง'
                       % (states['system_health'], states['floating_risk'])})
            continue
        if states['system_health'] not in SENSOR_HEALTHY:
            bands['SENSOR']['rows'].append({
                'account': acct, 'state': states['system_health'],
                'why': 'sensor ไม่สด (%s) อายุ %s ชม.'
                       % (states['system_health'], pair['system_health'].get('age_hours'))})

    # A detector-supplied risk band, passed through. This page computes no drawdown.
    for row in doc.get('floating_risk', []) or []:
        band = row.get('dd_band')
        if band in ('WATCH', 'BREACH'):
            bands['RISK']['rows'].append({
                'account': row.get('account'), 'state': band,
                'why': 'ตัวตรวจความเสี่ยงรายงาน %s — หน้านี้ส่งต่อ ไม่ได้คำนวณเอง' % band})

    for row in doc.get('unknown_magics', []) or []:
        if row.get('age_class') == 'ACTIVE':
            bands['DRIFT']['rows'].append({
                'account': row.get('account'), 'magic': row.get('magic'),
                'state': 'UNKNOWN_MAGIC_ACTIVE',
                'why': 'magic ที่ inventory ไม่รู้จัก และยังเทรดอยู่'})

    gaps = (doc.get('deployments') or {}).get('gaps') or {}
    for name, label in (('missing_kill', 'ไม่มี kill rule'),
                        ('missing_judge', 'ไม่มี judge date'),
                        ('unverified', 'ยังไม่ verify')):
        items = gaps.get(name) or []
        if items:
            bands['GOVERNANCE']['rows'].append({
                'gap': name, 'count': len(items), 'state': 'GAP',
                'why': '%s — %d แถว' % (label, len(items))})

    for row in doc.get('judge_readiness', []) or []:
        days = row.get('days_to_judge')
        if isinstance(days, (int, float)) and days <= 0:
            bands['DUE']['rows'].append({
                'account': row.get('account'), 'ea': row.get('ea'),
                'state': 'JUDGE_DUE',
                'why': 'ถึงวัน judge แล้ว (%s)' % row.get('judge_date')})

    summary = doc.get('summary') or {}
    bands['NORMAL']['rows'].append({
        'state': 'SUMMARY',
        'accounts_total': summary.get('accounts_total'),
        'deployments_active': summary.get('deployments_active'),
        'why': 'สรุปรวม — อยู่ใต้ exception เสมอ ไม่ใช่หัวตาราง'})

    positions = 0
    for row in doc.get('floating_risk', []) or []:
        positions += sum((m.get('pos_count') or 0) for m in (row.get('magics') or []))
    bands['POSITIONS']['rows'].append({
        'state': 'COLLAPSED', 'count': positions, 'collapsed': True,
        'why': 'โพซิชันถูกย่อโดยค่าเริ่มต้น (design 7.1: positions collapsed)'})

    count = sum(len(bands[b]['rows']) for b in EXCEPTION_BANDS)
    return {'bands': list(bands.values()), 'unknown': False, 'exception_count': count,
            'why': ''}


# ---------------------------------------------------------------------------------------
# SYSTEM - findings with a lifecycle.
# ---------------------------------------------------------------------------------------
FINDING_CLASSES = ('RUNTIME', 'GOVERNANCE', 'DEPLOYMENT_DRIFT', 'AUDIT')
AUTO_RESOLVING_CLASSES = ('RUNTIME',)
HEALTHY_CHECKS_TO_RESOLVE = 2
FLAPPING_RECURRENCES_24H = 3


def fold_finding(finding):
    """
    design 7.1 + 7.3, as one function so the two cannot drift:
      - a RUNTIME finding auto-resolves only after TWO consecutive healthy checks;
      - a governance/audit/drift finding never auto-resolves - it needs explicit review;
      - 3 recurrences in 24h collapse into one `FLAPPING - root cause required`;
      - `OPEN -> HEALTHY_1_OF_2 -> OPEN` emits NO recovery message. An intermediate healthy
        check is not a recovery, and calling it one produces exactly the flapping spam the
        two-check rule exists to stop.
    """
    cls = finding.get('class')
    if cls not in FINDING_CLASSES:
        _refuse('finding %s has class %r, which is not one of %s'
                % (finding.get('id'), cls, ', '.join(FINDING_CLASSES)))
    healthy = finding.get('healthy_streak') or 0
    occurrences = finding.get('occurrences_24h') or 0
    previous = finding.get('previous_state') or 'OPEN'

    if occurrences >= FLAPPING_RECURRENCES_24H:
        return {'id': finding.get('id'), 'class': cls, 'state': 'FLAPPING',
                'label': 'FLAPPING — root cause required',
                'collapsed_from': occurrences, 'recovery_emitted': False,
                'why': 'เกิดซ้ำ %d ครั้งใน 24 ชม. — ยุบเป็น incident เดียว และต้องหา root cause'
                       % occurrences}
    if healthy >= HEALTHY_CHECKS_TO_RESOLVE and cls in AUTO_RESOLVING_CLASSES:
        return {'id': finding.get('id'), 'class': cls, 'state': 'RESOLVED',
                'recovery_emitted': previous in ('OPEN', 'FLAPPING', 'HEALTHY_1_OF_2'),
                'why': 'ตรวจแล้วสุขภาพดีติดกัน %d ครั้ง — RUNTIME เท่านั้นที่ปิดเองได้' % healthy}
    if healthy >= HEALTHY_CHECKS_TO_RESOLVE:
        return {'id': finding.get('id'), 'class': cls, 'state': 'OPEN',
                'needs_explicit_review': True, 'recovery_emitted': False,
                'why': 'สุขภาพดี %d ครั้งแล้วก็จริง แต่ finding ชนิด %s ปิดเองไม่ได้ '
                       'ต้องมีคนรีวิว' % (healthy, cls)}
    if healthy == 1:
        return {'id': finding.get('id'), 'class': cls, 'state': 'HEALTHY_1_OF_2',
                'recovery_emitted': False,
                'why': 'สุขภาพดี 1 ใน %d ครั้ง — ยังไม่ใช่การฟื้นตัว จึงไม่ส่งข้อความ recovery'
                       % HEALTHY_CHECKS_TO_RESOLVE}
    return {'id': finding.get('id'), 'class': cls, 'state': 'OPEN',
            'needs_explicit_review': cls not in AUTO_RESOLVING_CLASSES,
            'recovery_emitted': False,
            'why': 'ยังเปิดอยู่'}


def build_system(read, findings):
    rows = [fold_finding(f) for f in findings]
    page = {'rows': rows,
            'open': len([r for r in rows if r['state'] == 'OPEN']),
            'flapping': len([r for r in rows if r['state'] == 'FLAPPING'])}
    if read.state != READ_OK:
        page['snapshot'] = {'state': read.state, 'code': read.code, 'reason': read.reason}
        page['unknown'] = True
    else:
        page['snapshot'] = {'state': 'OK', 'code': 'OK', 'reason': ''}
        page['unknown'] = False
    return page


# ---------------------------------------------------------------------------------------
# The one public entry point.
# ---------------------------------------------------------------------------------------

def project(read, rows=(), findings=()):
    """
    -> {'today':..., 'work':..., 'live':..., 'system':..., 'mode':'SHADOW'}

    PURE. It opens no file, writes no file, and calls nothing that could. The caller obtains
    `read` from snapshot_validator.load_verified() (or from the PowerShell reader, which is the
    same three states) and hands it in.
    """
    if not isinstance(read, SnapshotRead):
        _refuse('project() takes a SnapshotRead, not %s - the reader states are the contract'
                % type(read).__name__)
    _assert_read_contract(read)
    live = build_live(read)
    return {
        'mode': 'SHADOW',
        'today': build_today(read, rows, live),
        'work': build_work(read, rows),
        'live': live,
        'system': build_system(read, findings),
    }


# The CLOSED declaration of what this module offers. design 10 forbids dispatch, claim and
# closure from the UI for this slice; the cage asserts this tuple is the module's whole public
# surface AND that no name in it is a write verb, so adding one is not something that can
# happen quietly.
PUBLIC_API = (
    'SnapshotRead', 'ShellRefusal',
    'project', 'build_today', 'build_work', 'build_live', 'build_system',
    'normalise_row', 'place', 'fold_finding', 'render_html',
    # `main` is the CLI that renders the local page. It is the ONE name here that writes
    # anything, and what it writes is build/control_center.html - a rendering, never a
    # dispatch, a claim or a closure. It is declared rather than excused: the cage asserts this
    # tuple IS the module's public surface, so a second writer cannot arrive quietly.
    'main',
)

# Verbs a shadow-mode shell must not contain. The cage crosses this with PUBLIC_API and with
# the module's actual callables.
FORBIDDEN_VERBS = ('dispatch', 'claim', 'close', 'closure', 'assign', 'cancel', 'append',
                   'write', 'update', 'delete', 'send', 'commit', 'run', 'start', 'stop')


# ---------------------------------------------------------------------------------------
# The shell itself. One self-contained page, four tabs, dark-first, mobile-first. It renders
# the model above and adds NOTHING - every string it prints came from the model, so a claim
# on the page is a claim in the model, which is the thing the suite can drive.
# ---------------------------------------------------------------------------------------
_CSS = """
:root{color-scheme:dark}
body{margin:0;background:#0f1115;color:#e6e6e6;font:15px/1.5 -apple-system,Segoe UI,Roboto,
 "Noto Sans Thai",sans-serif}
header{padding:14px 16px;border-bottom:1px solid #262a33}
h1{font-size:17px;margin:0 0 4px}
.mode{display:inline-block;font-size:11px;letter-spacing:.08em;padding:2px 8px;border-radius:10px;
 background:#3a2f00;color:#ffd479;border:1px solid #6b5600}
nav{display:flex;gap:6px;padding:10px 12px;overflow-x:auto;border-bottom:1px solid #262a33}
nav button{background:#1a1d24;color:#cfd3dc;border:1px solid #2c313b;border-radius:8px;
 padding:7px 14px;font-size:14px}
nav button[aria-selected=true]{background:#243049;color:#fff;border-color:#3d5a8a}
section{display:none;padding:12px 14px 40px}section.on{display:block}
.band{border:1px solid #262a33;border-radius:10px;margin:10px 0;overflow:hidden}
.band>h2{margin:0;padding:9px 12px;font-size:14px;background:#161a21;border-bottom:1px solid #262a33}
.row{padding:9px 12px;border-bottom:1px solid #1c2028}
.row:last-child{border-bottom:0}
.why{color:#9aa3b2;font-size:12.5px;margin-top:3px}
.k{font-family:Consolas,monospace;font-size:12px;color:#8fb6ff}
.h-ALLCLEAR{color:#8ce39a}.h-ATTENTION{color:#ffd479}.h-UNKNOWN{color:#ff9aa2}
.pill{display:inline-block;font-size:11px;padding:1px 7px;border-radius:9px;border:1px solid #2c313b;
 color:#cfd3dc;margin-right:6px}
.hidden-note{padding:8px 12px;color:#9aa3b2;font-size:12.5px;background:#12151b}
"""

_JS = """
document.querySelectorAll('nav button').forEach(function(b){
  b.onclick=function(){
    document.querySelectorAll('nav button').forEach(function(x){x.setAttribute('aria-selected','false')});
    document.querySelectorAll('section').forEach(function(s){s.className=''});
    b.setAttribute('aria-selected','true');
    document.getElementById(b.dataset.tab).className='on';
  };
});
"""


def _esc(value):
    return (str(value).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;'))


def _row_html(row):
    head = []
    for key in ('id', 'state', 'account', 'magic', 'ea', 'gap', 'count'):
        if row.get(key) not in (None, ''):
            head.append('<span class="pill">%s %s</span>' % (_esc(key), _esc(row[key])))
    title = _esc(row.get('title', '') or row.get('label', ''))
    extra = []
    for key in ('decision', 'rework', 'waiting', 'stage'):
        if row.get(key):
            extra.append('<div class="why"><span class="k">%s</span> %s</div>'
                         % (_esc(key), _esc(row[key].get('label', row[key]))))
    return ('<div class="row">%s %s<div class="why">%s</div>%s</div>'
            % (''.join(head), title, _esc(row.get('why', '')), ''.join(extra)))


def _band_html(band):
    body = ''.join(_row_html(r) for r in band['rows'])
    if band.get('unknown'):
        body = '<div class="row h-UNKNOWN">UNKNOWN<div class="why">%s</div></div>' % _esc(band.get('why', ''))
    if not body:
        body = '<div class="row why">— ไม่มีรายการ —</div>'
    note = ''
    if band.get('hidden_count'):
        note = ('<div class="hidden-note">ซ่อนอยู่อีก %d รายการ (แถบนี้ cap ที่ %d) — '
                'expand-all พร้อมใช้</div>' % (band['hidden_count'], BAND_DISPLAY_CAP))
    return '<div class="band"><h2>%s</h2>%s%s</div>' % (_esc(band['label']), body, note)


def render_html(pages):
    """The local, full-detail shell. NOT the online surface - that is safe_projection.py."""
    health = pages['today']['health']
    today = ''.join(_band_html(b) for b in pages['today']['bands'])
    work = pages['work']
    work_html = ['<div class="band"><h2>lifecycle</h2>']
    if work.get('unknown'):
        work_html.append('<div class="row h-UNKNOWN">UNKNOWN<div class="why">%s</div></div>'
                         % _esc(work.get('why', '')))
    for state, rows in work['by_state'].items():
        work_html.append('<div class="row"><span class="pill">%s</span> %d<div class="why">%s</div></div>'
                         % (_esc(state), len(rows), _esc(', '.join(str(r['id']) for r in rows))))
    work_html.append('</div>')
    if work.get('counts'):
        work_html.append('<div class="band"><h2>reconciliation (snapshot เป็นเจ้าของตัวเลขนี้)</h2>'
                         '<div class="row">discovered %s / categorized %s<div class="why">%s</div></div></div>'
                         % (_esc(work['counts']['discovered']), _esc(work['counts']['categorized']),
                            _esc(work['unclassified_band']['why'])))
    live = ''.join(_band_html(b) for b in pages['live']['bands'])
    system = ''.join(_row_html(r) for r in pages['system']['rows']) or '<div class="row why">— ไม่มี finding —</div>'
    return """<!doctype html><html lang="th"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>EA LAB Control Center</title><style>%s</style></head><body>
<header><h1>EA LAB Control Center</h1>
<span class="mode">SHADOW MODE — อ่านอย่างเดียว</span>
<div class="why h-%s">%s — %s</div></header>
<nav>
<button data-tab="today" aria-selected="true">TODAY</button>
<button data-tab="work" aria-selected="false">WORK</button>
<button data-tab="live" aria-selected="false">LIVE</button>
<button data-tab="system" aria-selected="false">SYSTEM</button>
</nav>
<section id="today" class="on">%s</section>
<section id="work">%s</section>
<section id="live">%s</section>
<section id="system"><div class="band"><h2>findings</h2>%s</div></section>
<script>%s</script></body></html>
""" % (_CSS, _esc(health['headline']).replace(' ', ''), _esc(health['headline']),
       _esc(health['why']), today, ''.join(work_html), live, system, _JS)


def main(argv):
    """One end-to-end run: read the REAL snapshot through the one reader, render the shell."""
    import io
    import json
    import os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import safe_projection
    import snapshot_validator as sv

    repo_root = '.'
    if '--repo-root' in argv:
        repo_root = argv[argv.index('--repo-root') + 1]
    out = os.path.join(repo_root, 'build', 'control_center.html')
    path = os.path.join(repo_root, safe_projection.SNAPSHOT_REL)
    try:
        doc = sv.load_verified(path)
        read = SnapshotRead(READ_OK, 'OK', '', doc)
    except sv.MalformedDocument as exc:
        read = SnapshotRead(READ_REFUSED, 'MALFORMED', str(exc), None)
    except sv.VerdictMismatch as exc:
        read = SnapshotRead(READ_REFUSED, 'VERDICT', str(exc), None)
    except Exception as exc:                                  # noqa: BLE001 - reported, not swallowed
        read = SnapshotRead(READ_UNAVAILABLE, 'TOOL', '%s: %s' % (type(exc).__name__, exc), None)

    receipts = []
    rpath = os.path.join(repo_root, 'factory', 'work_receipts.jsonl')
    if os.path.exists(rpath):
        with io.open(rpath, 'r', encoding='utf-8-sig') as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                obj = json.loads(line)
                if obj.get('entity') == 'WorkReceipt':
                    receipts.append(obj)

    pages = project(read, receipts, [])
    d = os.path.dirname(out)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    with io.open(out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(render_html(pages))
    print('control_center: %s · headline=%s · LIVE exceptions=%d · WORK unknown=%s'
          % (out, pages['today']['health']['headline'], pages['live']['exception_count'],
             pages['work'].get('unknown')))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
