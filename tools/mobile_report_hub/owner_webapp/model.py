"""Read-only presentation of existing EA_LAB evidence."""
from __future__ import annotations
import csv, datetime as dt, hashlib, io, json, math, os, pathlib, re, subprocess
from html.parser import HTMLParser
UTC = dt.timezone.utc
LOADED_SOURCE_SHA256 = hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()
class Refused(ValueError):
    pass
def utcnow():
    return dt.datetime.now(UTC).isoformat(timespec='seconds')
def digest(raw):
    return hashlib.sha256(raw).hexdigest()
def clean(value, limit=1400):
    text = ''.join(c for c in str(value or '') if c.isprintable() or c=='\n')
    text = re.sub(r'(?i)\b[A-Z]:[\\/][^\s<>\"\']+', '[local path]', text)
    text = re.sub(r'(?i)file://[^\s<>\"\']+', '[local path]', text)
    text = re.sub(r'\b\d{8,12}\b', '[private ID]', text)
    return text[:limit]
def number(value):
    if isinstance(value, bool): return None
    try: n = float(value)
    except (ValueError, TypeError): return None
    return n if math.isfinite(n) else None
def stamp(value):
    if not isinstance(value,str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})',value): return None
    try:
        if value[-1]!='Z' and (int(value[-5:-3])>23 or int(value[-2:])>59): return None
        t = dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
        return t if t.tzinfo else None
    except (TypeError, ValueError): return None
def age_state(value, hours=26):
    t = stamp(value)
    if t is None: return 'UNKNOWN'
    age = (dt.datetime.now(UTC)-t).total_seconds()
    return 'FUTURE' if age < 0 else 'STALE' if age > hours*3600 else 'CURRENT'

def projection_view(value):
    """Consume build_index.safe_projection's envelope, preserving availability.

    Its producer has no version/confidence/process/acceptance fields. Local
    generated_at is legal producer data but cannot establish UTC freshness.
    """
    state=value.get('status') if isinstance(value,dict) else 'MISSING' if value is None else 'INVALID'
    empty={'status':state if state in ('MISSING','INVALID') else 'INVALID','findings':[], 'accounts':[], 'freshness':'UNKNOWN','generated_at':None}
    if state!='AVAILABLE': return empty
    if value.get('entity')!='SafeProjection' or value.get('source_kind')!='SAFE_PROJECTION_DERIVED' or value.get('authority')!='READ_ONLY_NO_RUNTIME_AUTHORITY': return empty
    if not isinstance(value.get('build_id'),str) or not re.fullmatch('[0-9a-f]{16}',value['build_id']): return empty
    when=value.get('generated_at')
    try:
        if not isinstance(when,str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z?',when): return empty
        dt.datetime.fromisoformat(when.replace('Z','+00:00'))
    except ValueError: return empty
    if not isinstance(value.get('accounts'),list) or not isinstance(value.get('findings'),list): return empty
    for r in value['accounts']:
        if not isinstance(r,dict) or set(r)!={'account_masked','sensor_state','dd_pct_band'}: return empty
        if not isinstance(r['account_masked'],str) or not re.fullmatch(r'\*{3}[0-9]{3}',r['account_masked']): return empty
        if r['sensor_state'] not in ('FRESH','STALE','BLIND','MISSING','UNKNOWN','CONFLICT') or r['dd_pct_band'] not in ('OK','WATCH','BREACH','UNKNOWN'): return empty
    for r in value['findings']:
        if not isinstance(r,dict) or set(r)!={'public_id','severity','state'}: return empty
        if not isinstance(r['public_id'],str) or not re.fullmatch('FP-[0-9a-f]{10}',r['public_id']): return empty
        if r['severity'] not in ('INFO','WARN','CRITICAL','REAL_MONEY') or not isinstance(r['state'],str) or not re.fullmatch('[A-Z][A-Z0-9_]{0,31}',r['state']): return empty
    return {k:value[k] for k in ('status','entity','build_id','generated_at','accounts','findings')} | {'freshness':age_state(when)}

def work_presentation(row):
    """Return derived owner-facing routing without changing source observations."""
    state=str(row.get('state') or 'UNKNOWN'); blocker=str(row.get('blocker') or '')
    code=blocker.upper(); health=str(row.get('process_health') or 'UNKNOWN'); job_state=str(row.get('job_state') or 'UNKNOWN')
    if 'REPAIR_LIMIT' in code or ('REPAIR' in code and ('SPENT' in code or 'EXHAUST' in code)):
        category='REPAIR_LIMIT'; display='REPAIR_LIMIT'
    elif any(token in code for token in ('WAITING_STATE_SYNC','SERIALIZED_STATE_CONVERGENCE')) or state=='WAITING_STATE_SYNC':
        category='WAITING_STATE_SYNC'; display='WAITING_STATE_SYNC'
    elif any(token in code for token in ('WAITING_REVIEW','WAITING_INDEPENDENT','WAITING_GPT_SCRUTINY')) or state in ('WAITING_REVIEW','REVIEW','FROZEN'):
        category='WAITING_REVIEW'; display='WAITING_REVIEW'
    elif blocker:
        category='OWNER_OR_SOURCE_GATE'; display='OWNER_OR_SOURCE_GATE'
    elif state=='DONE':
        category='RECORDED_SCOPE_CLOSURE'; display='RECORDED_SCOPE_CLOSURE'
    elif health in ('STALLED','RECOVERY_REQUIRED','NO_DURABLE_JOB','UNAVAILABLE'):
        category='PROCESS_RECOVERY'
        display={'STALLED':'STALLED','RECOVERY_REQUIRED':'RECOVERY_REQUIRED','NO_DURABLE_JOB':'STALE_REGISTRY','UNAVAILABLE':'LIVENESS_UNAVAILABLE'}[health]
    elif job_state in ('COMPLETE','FAILED','TIMED_OUT','CANCELLED','POSTCONDITION_FAILED') or health in ('COMPLETE','TERMINAL_NONCOMPLETE'):
        category='RESULT_TO_RECONCILE'; display='TERMINAL_RECONCILE'
    elif health=='ACTIVE':
        category='ACTIVE_PROCESS'; display='ACTIVE_PROCESS'
    else:
        category=state if state!='UNKNOWN' else 'UNKNOWN'; display=state if state!='UNKNOWN' else 'UNKNOWN'
    descriptions={
        'REPAIR_LIMIT':('สิทธิ์ซ่อมตามสัญญาถูกใช้ครบแล้ว','ให้เจ้าของหรือ Control Tower กำหนดสัญญาหรือทางเดินถัดไป'),
        'WAITING_STATE_SYNC':('รอปรับสถานะจากหลักฐานที่ยอมรับแล้ว','ตรวจหลักฐานและบันทึกสถานะ canonical โดยผู้มีสิทธิ์'),
        'WAITING_REVIEW':('รอการตรวจอิสระ ไม่ใช่ผล PASS','ส่งหัวและหลักฐานที่ตรึงไว้ให้ผู้ตรวจตามสัญญา'),
        'OWNER_OR_SOURCE_GATE':('มี blocker ที่ระบุไว้','ตรวจ blocker และหลักฐานก่อนเปิด gate'),
        'RECORDED_SCOPE_CLOSURE':('ปิดขอบเขตงานใน Registry เท่านั้น ไม่ใช่ PASS','ดูผลตรวจและสถานะ canonical ก่อนนำไปใช้'),
        'PROCESS_RECOVERY':('สถานะ process ต้องตรวจสอบหรือกู้คืน','ตรวจหลักฐาน process และนโยบายเริ่มงานก่อนดำเนินการ'),
        'RESULT_TO_RECONCILE':('มีผลจบงาน แต่ยังไม่ใช่การยอมรับผล','ตรวจผล review และ state sync แยกกัน'),
        'ACTIVE_PROCESS':('พบ process จากหลักฐานที่ตรวจสอบแล้ว','ติดตามผลและ gate ตามสัญญาเดิม'),
        'UNKNOWN':('ข้อมูลยังไม่พอระบุ gate ปัจจุบัน','ตรวจ Registry blocker และหลักฐานที่เกี่ยวข้อง'),
    }
    reason,action=descriptions.get(category,(f'สถานะ Registry: {state}','ตรวจหลักฐานและ gate ตามสัญญา'))
    notes=[]
    if row.get('superseded_by_claim'): notes.append('superseded_by เป็นเพียงคำอ้างอิง ต้องตรวจหลักฐานของงานถัดไป')
    terminal=job_state in ('COMPLETE','FAILED','TIMED_OUT','CANCELLED','POSTCONDITION_FAILED') or health in ('COMPLETE','TERMINAL_NONCOMPLETE')
    if terminal and category in ('REPAIR_LIMIT','WAITING_STATE_SYNC','WAITING_REVIEW','OWNER_OR_SOURCE_GATE'):
        notes.append('ผลจบ job ไม่ลบ gate ที่ระบุไว้')
    if state=='DONE' and terminal and job_state!='COMPLETE':
        notes.append('DONE ปิดเฉพาะขอบเขต Registry; ผล job เดิมยังคงถูกแสดง')
    return {'display_state':display,'category':category,'reason_th':reason,'next_action_th':action,
            'reconciliation':notes,'unresolved':state!='DONE'}

def safe_bytes(path, root, limit=6_000_000):
    p=pathlib.Path(path).absolute(); root=pathlib.Path(root).absolute()
    if not p.is_relative_to(root): raise Refused('PATH_OUTSIDE_SOURCE')
    for x in [p,*p.parents]:
        if x.is_symlink() or getattr(x.stat(),'st_file_attributes',0)&0x400: raise Refused('REPARSE_SOURCE')
        if x==root: break
    before=p.stat()
    if not p.is_file() or before.st_size>limit: raise Refused('SOURCE_SIZE_OR_TYPE')
    raw=p.read_bytes(); after=p.stat()
    if (before.st_size,before.st_mtime_ns)!=(after.st_size,after.st_mtime_ns): raise Refused('SOURCE_CHANGED_DURING_READ')
    return raw
def read_json(path, root):
    return json.loads(safe_bytes(path,root).decode('utf-8-sig'))
def csv_rows(raw):
    text=raw.decode('utf-16' if raw[:2] in (bytes([255,254]),bytes([254,255])) else 'utf-8-sig')
    return list(csv.DictReader(io.StringIO(text)))

class _DashboardParser(HTMLParser):
    """Extract only account-card tables from the accepted generated dashboard."""
    def __init__(self):
        super().__init__(convert_charrefs=True); self.stack=[]; self.cards=[]; self.card=None
        self.in_head=False; self.in_table=False; self.row=None; self.cell=None
    def handle_starttag(self,tag,attrs):
        a=dict(attrs); self.stack.append((tag,a))
        if tag=='div' and 'acct-card' in a.get('class','').split():
            self.card={'head':'','rows':[]}; self.cards.append(self.card)
        if self.card and tag=='div' and 'acct-head' in a.get('class','').split(): self.in_head=True
        if self.card and tag=='table': self.in_table=True
        if self.in_table and tag=='tr':
            self.row={'class':a.get('class',''),'cells':[]}; self.card['rows'].append(self.row)
        if self.row is not None and tag in ('th','td'):
            self.cell={'tag':tag,'class':a.get('class',''),'text':''}; self.row['cells'].append(self.cell)
    def handle_endtag(self,tag):
        closing=self.stack[-1] if self.stack else (None,{})
        if tag in ('th','td'): self.cell=None
        if tag=='tr': self.row=None
        if tag=='table': self.in_table=False
        if tag=='div' and self.in_head and 'acct-head' in closing[1].get('class','').split(): self.in_head=False
        if tag=='div' and self.card and 'acct-card' in closing[1].get('class','').split(): self.card=None
        if self.stack: self.stack.pop()
    def handle_data(self,data):
        if self.card and self.in_head: self.card['head']+=data
        if self.cell is not None: self.cell['text']+=data

class Model:
    def __init__(self, config):
        self.c=config; self.repo=pathlib.Path(config['repo']); self.errors=[]
    def git(self,*args):
        p=subprocess.run(['git','-C',str(self.repo),*args],capture_output=True,timeout=12,env={**os.environ,'GIT_OPTIONAL_LOCKS':'0','GIT_TERMINAL_PROMPT':'0'})
        if p.returncode: raise Refused('GIT_READ_UNAVAILABLE')
        return p.stdout
    def blob(self,path): return self.git('show',self.sha+':'+path)
    def issue(self,source,error): self.errors.append({'source':source,'reason':type(error).__name__ if not isinstance(error,Refused) else str(error)})
    def section(self,name,fn,default):
        try: return fn()
        except (OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError) as e:
            self.issue(name,e); return default
    def accounts(self):
        root=pathlib.Path(self.c['snapshots']); files=sorted(root.glob('EA_LAB_snapshot_*.csv'))
        if len(files)>1000: raise Refused('SNAPSHOT_SET_TOO_LARGE')
        metadata={r['account']:r for r in csv_rows(self.blob('portfolio/ACCOUNTS.csv'))}
        deployments=csv_rows(self.blob('portfolio/DEPLOYMENTS.csv')); grouped={}; conflicts=set(); source_count=0; gaps=[]
        for path in files:
            login=None
            try:
                match=re.fullmatch(r'EA_LAB_snapshot_(\d+)(?:_\d{8})?\.csv',path.name)
                if not match: raise Refused('SNAPSHOT_FILENAME')
                login=match.group(1); raw=safe_bytes(path,root,1_000_000); rows=csv_rows(raw)
                acc=[r for r in rows if r.get('row_type')=='ACCOUNT']
                if len(acc)!=1 or acc[0].get('login')!=login: raise Refused('SNAPSHOT_IDENTITY')
                row=acc[0]; when=dt.datetime.strptime(row['server_time'],'%Y.%m.%d %H:%M:%S').isoformat()
                bal=number(row.get('balance')); eq=number(row.get('equity')); currency=row.get('currency','')
                if bal is None or eq is None or not re.fullmatch('[A-Z]{3,5}',currency): raise Refused('INVALID_ACCOUNT_SAMPLE')
                if login in metadata and metadata[login].get('currency') not in ('',currency): raise Refused('CURRENCY_CONFLICT')
                magic=[]
                for r in rows:
                    if r.get('row_type')!='MAGIC': continue
                    if r.get('login')!=login or r.get('server_time')!=row['server_time']: raise Refused('MAGIC_IDENTITY_TIME')
                    matches=[d for d in deployments if d.get('account')==login and d.get('magic')==r.get('magic')]
                    names=set(d.get('ea_name','') for d in matches); name=next(iter(names)) if len(names)==1 else 'Unmapped / ambiguous deployment'
                    magic.append({'id':'ea-'+digest((login+'|'+r.get('magic','')).encode())[:12],'name':clean(name,160),'symbol':clean(r.get('symbols'),80),'floating':number(r.get('float_pl')),'lots':number(r.get('open_lots')),'positions':number(r.get('open_positions')),'inventory_state':clean('|'.join(sorted(set(d.get('status','') for d in matches))),80) or 'UNMAPPED','identity':'UNVERIFIED_RUNTIME_IDENTITY'})
                key=(login,currency); point={'time':when,'balance':bal,'equity':eq,'margin':number(row.get('margin')),'source_hash':digest(raw),'eas':magic}
                book=grouped.setdefault(key,{}); previous=book.get(when)
                if previous and {k:v for k,v in previous.items() if k!='source_hash'}!={k:v for k,v in point.items() if k!='source_hash'}: conflicts.add((key,when))
                else: book[when]=point
                source_count+=1
            except (OSError,ValueError,KeyError,UnicodeError) as e:
                self.issue('account_snapshot',e)
                gaps.append({'account_id':'acct-'+digest(login.encode())[:12] if login else None, 'state':'INVALID', 'balance':None,'equity':None})
        result=[]
        for (login,currency),points in grouped.items():
            kept=[p if ((login,currency),t) not in conflicts else {'time':t,'balance':None,'equity':None,'eas':[],'state':'INVALID'} for t,p in sorted(points.items())]
            if not kept: continue
            latest=kept[-1]; meta=metadata.get(login,{})
            # An unplaceable malformed sample might be newer than the last good one.
            if any(g['account_id'] in (None,'acct-'+digest(login.encode())[:12]) for g in gaps): latest={'balance':None,'equity':None,'eas':[],'state':'INVALID'}
            result.append({'id':'acct-'+digest(login.encode())[:12],'label':'***'+login[-3:],'currency':currency,'environment':clean(meta.get('environment','UNKNOWN'),40),'points':[{k:v for k,v in p.items() if k!='eas'} for p in kept],'latest':latest,'sample_count':len(kept),'clock':'BROKER_SERVER_TIME_TZ_UNQUALIFIED','freshness':'UNKNOWN','identity':'ACCOUNT_SNAPSHOT_NOT_STRATEGY_ATTESTATION'})
        return {'status':'INVALID' if gaps or conflicts else 'AVAILABLE' if source_count else 'MISSING','rows':sorted(result,key=lambda r:r['label']),'gaps':gaps,'files_read':source_count,'conflicting_samples':len(conflicts),'basis':'Discrete observed samples only; no interpolation across missing or invalid samples. No FX conversion or deposit-adjusted return.'}
    def lane_status(self,lane_id,expected_job_id):
        script=pathlib.Path(self.c.get('lane_status',''))
        if not script.is_file() or script.is_symlink(): raise Refused('LANE_STATUS_UNAVAILABLE')
        p=subprocess.run(['powershell.exe','-NoLogo','-NoProfile','-NonInteractive','-File',str(script),'-LaneId',lane_id,'-Json'],
                         capture_output=True,timeout=10)
        if p.returncode: raise Refused('LANE_STATUS_REFUSED')
        raw=p.stdout
        text=raw.decode('utf-16' if raw[:2] in (bytes([255,254]),bytes([254,255])) else 'utf-8-sig',errors='strict')
        x=json.loads(text)
        required={'lane_id','job_id','health','observed_state','durable_state','runner_alive','child_alive','postcondition_alive','heartbeat_age_sec','retry_decision','checked_utc'}
        if not isinstance(x,dict) or not required.issubset(x): raise Refused('LANE_STATUS_SCHEMA')
        if x['lane_id']!=lane_id or x['job_id']!=expected_job_id: raise Refused('LANE_STATUS_IDENTITY')
        if not all(isinstance(x[k],bool) for k in ['runner_alive','child_alive','postcondition_alive']): raise Refused('LANE_STATUS_PROCESS_TYPES')
        health=str(x['health']); observed=str(x['observed_state']); durable=x['durable_state']
        allowed_health={'ACTIVE','STALLED','COMPLETE','RECOVERY_REQUIRED','TERMINAL_NONCOMPLETE','UNKNOWN'}
        allowed_observed={'STARTING','RUNNING','POSTCONDITION_RUNNING','CANCEL_REQUESTED','COMPLETE','FAILED','POSTCONDITION_FAILED','TIMED_OUT','CANCELLED','LOST_PROCESS','UNKNOWN'}
        if health not in allowed_health or observed not in allowed_observed: raise Refused('LANE_STATUS_ENUM')
        if durable is not None and (not isinstance(durable,str) or len(durable)>60): raise Refused('LANE_STATUS_DURABLE_STATE')
        heartbeat=x.get('heartbeat_age_sec')
        if heartbeat is not None and (number(heartbeat) is None or number(heartbeat)<0): raise Refused('LANE_STATUS_HEARTBEAT')
        if x.get('retry_decision') not in ('ALLOW_RETRY','REFUSE_RETRY'): raise Refused('LANE_STATUS_RETRY')
        if stamp(x.get('checked_utc')) is None: raise Refused('LANE_STATUS_CHECKED_TIME')
        if health=='ACTIVE' and not (x['runner_alive'] or x['child_alive'] or x['postcondition_alive']): raise Refused('LANE_STATUS_ACTIVE_WITHOUT_PROCESS')
        if health=='COMPLETE' and observed!='COMPLETE': raise Refused('LANE_STATUS_COHERENCE')
        if health=='RECOVERY_REQUIRED' and observed!='LOST_PROCESS': raise Refused('LANE_STATUS_COHERENCE')
        if health=='TERMINAL_NONCOMPLETE' and observed not in {'FAILED','POSTCONDITION_FAILED','TIMED_OUT','CANCELLED'}: raise Refused('LANE_STATUS_COHERENCE')
        return {'health':health,'observed_state':observed,'durable_state':clean(durable,60),
                'runner_alive':x['runner_alive'],'child_alive':x['child_alive'],'postcondition_alive':x['postcondition_alive'],
                'heartbeat_age_sec':number(heartbeat),'retry_decision':x['retry_decision'],
                'checked_utc':clean(x.get('checked_utc'),60),'status_source':'ACCEPTED_CHAT_STALL_LANE_STATUS'}

    def work(self):
        root=pathlib.Path(self.c['registry']); lease_root=pathlib.Path(self.c['leases']); jobs_root=pathlib.Path(self.c['jobs']); result=[]; totals={}
        for p in sorted(root.glob('*.json')):
            try:
                x=read_json(p,root); lane=x['lane_id']; state=x['state']; updated=x.get('updated_at')
                if not re.fullmatch(r'[A-Za-z0-9_.-]{1,128}',lane): raise Refused('LANE_ID')
                totals[state]=totals.get(state,0)+1
                lease=lease_root/(lane+'.json'); job={}; terminal=None; jobid=None
                if lease.is_file():
                    l=read_json(lease,lease_root)
                    if l.get('lane_id')!=lane: raise Refused('LEASE_LANE_IDENTITY')
                    jobid=l.get('job_id')
                    if not isinstance(jobid,str) or not re.fullmatch(r'[A-Za-z0-9_.-]{1,160}',jobid): raise Refused('JOB_ID')
                    jroot=jobs_root/jobid
                    if (jroot/'state.json').is_file():
                        job=read_json(jroot/'state.json',jobs_root)
                        if job.get('job_id')!=jobid: raise Refused('JOB_STATE_IDENTITY')
                    if (jroot/'result.json').is_file():
                        terminal=read_json(jroot/'result.json',jobs_root)
                        if terminal.get('job_id')!=jobid: raise Refused('JOB_RESULT_IDENTITY')
                js=job.get('state','NOT_OBSERVED'); end=None
                if isinstance(terminal,dict): js=terminal.get('state',js); end=terminal.get('ended_utc')
                process_state='NOT_PROBED'; process_health='NOT_PROBED'
                if state=='RUNNING' and not jobid:
                    process_state='NOT_OBSERVED'; process_health='NO_DURABLE_JOB'
                result.append({'id':lane,'title':lane.removeprefix('ct-').replace('-',' '),'state':state,'owner':clean(x.get('owner_chat'),100),'worker':clean(x.get('worker'),140),'updated_at':updated,'freshness':age_state(updated,24),'job_id':jobid,'job_state':js,'ended_at':end,'process_state':process_state,'process_health':process_health,'runner_alive':None,'child_alive':None,'postcondition_alive':None,'heartbeat_age_sec':None,'retry_decision':'UNKNOWN','process_checked_utc':None,'progress':'UNKNOWN','blocker':clean(x.get('blocker_class'),1400),'head':x.get('head_sha'),'reviewed_head':x.get('reviewed_head'),'reviewer':clean(x.get('reviewer'),140),'dependencies':[clean(d,128) for d in x.get('dependencies',[]) if isinstance(d,str)],'acceptance':'UNKNOWN','canonical':'NOT_ASSESSED','consumption':'UNKNOWN','superseded_by_claim':clean(x.get('superseded_by'),180) or None,'source_status':'REGISTRY_RECORD_AVAILABLE','evidence_basis':'Registry declaration + available lease/job/process observations; each remains a separate source.'})
            except (OSError,ValueError,KeyError,TypeError) as e: self.issue('lane_observation',e)
        result.sort(key=lambda r:(r['freshness']=='CURRENT',r['updated_at'] or ''),reverse=True)
        probe_states={'RUNNING','REVIEW','FROZEN','INTEGRATING','WAITING','BLOCKED'}
        candidates=[r for r in result if r['freshness']=='CURRENT' and r['job_id'] and r['state'] in probe_states][:12]
        for row in candidates:
            try:
                live=self.lane_status(row['id'],row['job_id'])
                row['process_state']=live['observed_state']; row['process_health']=live['health']
                row['runner_alive']=live['runner_alive']; row['child_alive']=live['child_alive']; row['postcondition_alive']=live['postcondition_alive']
                row['heartbeat_age_sec']=live['heartbeat_age_sec']; row['retry_decision']=live['retry_decision']; row['process_checked_utc']=live['checked_utc']
            except (OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError,UnicodeError) as e:
                row['process_state']='UNKNOWN'; row['process_health']='UNAVAILABLE'
                self.issue('lane_status:'+row['id'],e)
        for row in result: row.update(work_presentation(row))
        return {'status':'INVALID' if any(e['source']=='lane_observation' for e in self.errors) else 'AVAILABLE' if root.is_dir() else 'MISSING','rows':result,'totals':totals,'observed_at':utcnow(),'process_probed_count':len(candidates),
                'basis':'Registry declarations + existing lease/result bytes. Fresh leased lanes additionally consume accepted chat-stall lane_status process identity; heartbeat is liveness evidence, not work-progress proof.'}
    def knowledge(self):
        root=pathlib.Path(self.c['knowledge']); manifest=read_json(root/'MANIFEST_SHA256.json',root)
        entry=next((r for r in manifest['files'] if r['path']=='knowledge_index.json'),None)
        raw=safe_bytes(root/'knowledge_index.json',root)
        if not entry or digest(raw)!=entry['sha256'] or len(raw)!=entry['bytes']: raise Refused('KNOWLEDGE_MANIFEST_MISMATCH')
        x=json.loads(raw.decode('utf-8-sig'))
        if x.get('schema_version')!='ea-lab-second-brain-reader/1' or x['canonical']['sha']!=manifest['source_head']: raise Refused('KNOWLEDGE_PIN_MISMATCH')
        docs=[]
        for d in x['documents']:
            docs.append({'id':clean(d['id'],220),'title':clean(d['title'],220),'kind':clean(d['document_type'],60),'authority':clean(d['authority_class'],80),'body':clean(d.get('body'),48000),'topics':[clean(t,60) for t in d.get('topics',[])],'sources':[clean(t,160) for t in d.get('source_ids',[])],'sha256':d.get('sha256'),'source_url':d.get('source_url') if str(d.get('source_url','')).startswith('https://') else None})
        return {'documents':docs,'health':x['health'],'canonical':x['canonical'],'manifest_hash':digest(safe_bytes(root/'MANIFEST_SHA256.json',root)),'binding':'HASH_VERIFIED_PINNED_READER_NOT_CURRENT_PROJECT_STATUS'}
    def templates(self):
        paths=self.git('ls-tree','-r','--name-only',self.sha,'--','ea_template').decode().splitlines(); rows=[]
        for path in paths:
            if not re.fullmatch(r'ea_template/[^/]+\.mq5',path): continue
            raw=self.blob(path); text=raw.decode('utf-8-sig',errors='replace')
            entry=re.search(r'^#define\s+LAB_ENTRY_(\d+)\s*$',text,re.M)
            if not entry: continue
            description=re.search(r'#property\s+description\s+"([^"]+)"',text)
            rows.append({'id':'B'+entry.group(1),'name':path.split('/')[-1].replace('.mq5',''),'concept':clean(description.group(1) if description else 'Source wrapper; inspect canonical strategy contract',600),'state':'SOURCE_PRESENT','path':path,'sha256':digest(raw),'canonical_sha':self.sha,'runtime':'NOT_INFERRED','research':'Separate experiment evidence required'})
        return sorted(rows,key=lambda r:int(r['id'][1:]))
    def news(self):
        root=pathlib.Path(self.c['runtime']); p=root/'portfolio/news_week.csv'; raw=safe_bytes(p,root); rows=[]
        for x in csv_rows(raw):
            t=dt.datetime.strptime(x['BkkTime'],'%Y.%m.%d %H:%M').replace(tzinfo=dt.timezone(dt.timedelta(hours=7)))
            rows.append({'time':t.isoformat(),'currency':clean(x.get('Currency'),8),'title':clean(x.get('Title'),180),'forecast':clean(x.get('Forecast'),60),'previous':clean(x.get('Previous'),60),'impact':'NOT_SUPPLIED','guard_window':'EFFECTIVE_CONFIG_UNAVAILABLE'})
        return {'events':sorted(rows,key=lambda r:r['time']),'source_hash':digest(raw),'source':'DailyMonitor / news_week.csv','freshness':'SOURCE_GENERATION_TIME_UNAVAILABLE','guard_effective':'UNKNOWN','basis':'BkkTime is UTC+07. Calendar is not proof that the trading EA applied NewsGuard.'}
    def macro(self):
        root=pathlib.Path(self.c['runtime']); raw=safe_bytes(root/'portfolio/mris/regime_state.json',root); x=json.loads(raw.decode('utf-8-sig'))
        return {'state':clean(x.get('state'),40),'time':x.get('generated_utc'),'freshness':age_state(x.get('generated_utc')),'bias':clean(x.get('bias'),180),'barometers':[{k:(number(v) if k in ['spot','chg5d_pct','signal'] else clean(v,300)) for k,v in b.items() if k in ['symbol','spot','chg5d_pct','signal','reason']} for b in x.get('barometers',[])],'source_hash':digest(raw),'effective':'UNKNOWN','source':'MRIS existing producer; not EA effective-state evidence'}

    def control_room(self):
        root=pathlib.Path(self.c['runtime']); raw=safe_bytes(root/'portfolio/control_room_snapshot.json',root,2_000_000)
        x=json.loads(raw.decode('utf-8-sig')); meta=x.get('meta',{})
        if x.get('entity')!='ControlRoomSnapshotV5' or meta.get('schema')!='ControlRoomSnapshot' or meta.get('version')!=5:
            raise Refused('CONTROL_ROOM_SCHEMA')
        generated=meta.get('generated_at'); binding='MATCH' if meta.get('git_head')==self.sha else 'DIFFERENT_REPO_HEAD'
        floating={}
        for acc in x.get('floating_risk',[]):
            account=str(acc.get('account',''))
            for m in acc.get('magics',[]):
                floating[(account,str(m.get('magic','')))]=m
        rows=[]
        for r in x.get('judge_readiness',[]):
            account=str(r.get('account','')); magic=str(r.get('magic','')); f=floating.get((account,magic),{})
            rows.append({'account_id':'acct-'+digest(account.encode())[:12],'account_label':'***'+account[-3:] if account else 'UNKNOWN',
                'magic':clean(magic,40),'ea':clean(r.get('ea'),180),'symbol':clean(r.get('symbol'),40),'status':clean(r.get('status'),50),
                'operational_status':clean(r.get('operational_status'),50),'verification_state':clean(r.get('verification_state'),60),
                'attention':clean(r.get('attention'),50),'closed_deal_rows':r.get('closed_trades'),'readiness':clean(r.get('readiness'),60),
                'forecast':clean(r.get('forecast'),60),'judge_date':clean(r.get('judge_date'),30),'observation_start_date':clean(r.get('observation_start_date'),30),
                'observed_trades_per_week':number(r.get('observed_trades_per_week')),'expected_trades_per_week':number(r.get('expected_trades_per_week')),
                'rate_flag':clean(r.get('rate_flag'),60),'expectation_status_reason':clean(r.get('expectation_status_reason'),400),
                'floating_pl':number(f.get('floating_pl')),'open_lots':number(f.get('open_lots')),'open_positions':number(f.get('pos_count')),
                'oldest_open_hours':number(f.get('oldest_age_h'))})
        src=[{'name':clean(s.get('name'),80),'fresh':s.get('fresh') if isinstance(s.get('fresh'),bool) else None,'age_hours':number(s.get('age_hours'))} for s in meta.get('sources',[])]
        rid=x.get('runtime_identity_summary',{})
        raw_summary=x.get('summary',{})
        summary={k:v for k,v in raw_summary.items() if isinstance(v,(int,float,bool,str)) and k not in ('expectation_baskets',)}
        return {'generated_at':generated,'freshness':age_state(generated,30),'git_head':meta.get('git_head'),'binding':binding,
            'execution_context':clean(meta.get('execution_context'),80),'rows':rows,'summary':summary,'source_health':src,
            'reconciliation_clear':x.get('verdict',{}).get('reconciliation_clear') if isinstance(x.get('verdict',{}).get('reconciliation_clear'),bool) else None,
            'verdict_reasons':[{'code':clean(v.get('code'),80),'detail':clean(v.get('detail'),180)} for v in x.get('verdict',{}).get('reasons',[])],
            'runtime_identity':{'state':clean(rid.get('state'),40),'forward_test_state':clean(rid.get('forward_test_state'),80),
                'reasons':[{'code':clean(v.get('code'),80),'detail':clean(v.get('detail'),180)} for v in rid.get('reasons',[])]},
            'source_hash':digest(raw),'basis':clean(meta.get('counting_method'),300)}

    def live_performance(self):
        root=pathlib.Path(self.c['runtime']); raw=safe_bytes(root/'portfolio/LIVE_DASHBOARD.html',root,2_000_000)
        control=read_json(root/'portfolio/control_room_snapshot.json',root)
        source=next((s for s in control.get('meta',{}).get('sources',[]) if s.get('name')=='live_dashboard'),None)
        if not source or source.get('sha256')!=digest(raw): raise Refused('LIVE_DASHBOARD_BINDING_MISMATCH')
        parser=_DashboardParser(); parser.feed(raw.decode('utf-8-sig',errors='strict'))
        currencies={r.get('account',''):r.get('currency','UNKNOWN') for r in csv_rows(self.blob('portfolio/ACCOUNTS.csv'))}
        def numtext(value):
            s=str(value or '').strip().replace(',','').replace('%','')
            if s in ('','UNKNOWN','N/A','—'): return None
            if s in ('∞','Infinity','+Infinity'): return 'INFINITY'
            return number(s)
        accounts=[]
        for card in parser.cards:
            perf_header=None
            for row in card['rows']:
                headers=[c['text'].strip() for c in row['cells'] if c['tag']=='th']
                if 'Net P&L' in headers and 'PF' in headers and 'Trades' in headers:
                    perf_header=headers; break
            if not perf_header: continue
            m=re.match(r'\s*(\d{5,12})\s*·\s*(.*)',card['head'],re.S)
            if not m: raise Refused('LIVE_DASHBOARD_ACCOUNT_HEADER')
            account=m.group(1); head=clean(m.group(2),900); rows=[]
            for row in card['rows']:
                cells=row['cells']
                if not cells or cells[0]['tag']=='th': continue
                vals=[c['text'].strip() for c in cells]
                if len(vals)!=len(perf_header): raise Refused('LIVE_DASHBOARD_ROW_WIDTH')
                obj=dict(zip(perf_header,vals))
                rows.append({'flag_class':clean(row.get('class'),40),'operational':clean(obj.get('Operational'),60),
                    'verification':clean(obj.get('Verification'),60),'ea':clean(obj.get('EA'),220),'magic':clean(obj.get('Magic'),40),
                    'symbol':clean(obj.get('Symbol'),50),'trades':number(obj.get('Trades')),
                    'net_pl':numtext(obj.get('Net P&L')),'profit_factor':numtext(obj.get('PF')),
                    'max_dd_pct':numtext(obj.get('Max DD%')),'kill_dd_pct':numtext(obj.get('Kill DD%')),
                    'days_idle':numtext(obj.get('Days idle')),'detail':clean(obj.get('Detail'),500)})
            hm=re.search(r'window:\s*from\s*([^·]+)\s*·\s*net\s*([+\-0-9,.]+)\s*·\s*(\d+)\s*trades',card['head'])
            accounts.append({'account_id':'acct-'+digest(account.encode())[:12],'account_label':'***'+account[-3:],
                'currency':clean(currencies.get(account,'UNKNOWN'),10),'header':head,'window_start':clean(hm.group(1).strip(),30) if hm else 'UNKNOWN',
                'account_net_pl':numtext(hm.group(2)) if hm else None,'account_trades':int(hm.group(3)) if hm else None,'rows':rows})
        return {'accounts':accounts,'source_hash':digest(raw),'source_age_hours':number(source.get('age_hours')),
            'source_fresh':source.get('fresh') if isinstance(source.get('fresh'),bool) else None,'source_mtime':clean(source.get('mtime'),40),
            'producer_git_head':control.get('meta',{}).get('git_head'),'binding':'MATCH' if control.get('meta',{}).get('git_head')==self.sha else 'DIFFERENT_REPO_HEAD',
            'basis':'Existing scripts/live_dashboard.ps1 output. MT5 closes use entry OUT/INOUT/OUT_BY; net P/L includes profit+swap+commission; PF and DD preserve producer semantics.'}

    def news_policy(self):
        raw=self.blob('ea_projects/(Boss)_NewsGuard/GUARDCONFIG_2026-07-17.md'); text=raw.decode('utf-8-sig',errors='replace')
        def val(name):
            m=re.search(r'\|\s*`?'+re.escape(name)+r'`?\s*\|\s*`?([^|\n`]+)',text)
            return clean(m.group(1).strip(),80) if m else 'UNKNOWN'
        return {'reference_date':'2026-07-17','pre_news_min':number(val('PreNewsMin')),'post_news_min':number(val('PostNewsMin')),
            'news_file':val('NewsFile'),'use_common_files':val('UseCommonFiles'),'effective_runtime':'UNKNOWN',
            'coverage_state':'HISTORICAL_CONFIG_SNAPSHOT_REVERIFY_DEPLOYMENTS','source_hash':digest(raw),'canonical_sha':self.sha,
            'basis':'Canonical runbook reference only. It explicitly requires regeneration when DEPLOYMENTS.csv changes; attachment/effective guard state is not inferred.'}
    def snapshot(self):
        self.errors=[]; self.sha=self.git('rev-parse','refs/remotes/origin/master').decode().strip()
        if not re.fullmatch('[0-9a-f]{40}',self.sha): raise Refused('INVALID_TRACKING_REF')
        root=pathlib.Path(self.c['monitor']); raw=safe_bytes(root/'report_index.json',root); index=json.loads(raw.decode('utf-8-sig'))
        if index.get('schema_version')!=1 or not isinstance(index.get('eas'),list) or not isinstance(index.get('project'),dict): raise Refused('REPORT_SCHEMA_INVALID')
        published=index['project']; declared=self.blob('PROJECT_STATE.md').decode('utf-8-sig')
        global_match=re.search(r'Global state:\s*`([A-Z_]+)`',declared)
        eas=[]
        for ea in index['eas']:
            ev=ea.get('evidence',{}); eas.append({'id':clean(ea.get('id'),180),'name':clean(ea.get('display_name'),220),'family':clean(ea.get('family_id'),60),'status':clean(ea.get('status'),100),'strategy':clean(ea.get('strategy'),1000),'home':{k:clean(v,80) for k,v in ea.get('home',{}).items()},'evidence':ev,'native_graphs':ea.get('native_graphs',{}),'verdict':clean(ea.get('verdict'),500),'links':ea.get('links',{}),'provenance':ea.get('provenance',[])})
        account_data=self.section('account_history',self.accounts,{'status':'INVALID','rows':[],'files_read':None,'basis':'UNAVAILABLE'})
        work_data=self.section('work',self.work,{'status':'INVALID','rows':[],'totals':{},'basis':'UNAVAILABLE'})
        knowledge=self.section('knowledge',self.knowledge,{'documents':[],'health':{},'binding':'UNAVAILABLE'})
        news=self.section('news',self.news,{'events':[],'guard_effective':'UNKNOWN','freshness':'UNAVAILABLE'})
        macro=self.section('macro',self.macro,{'state':'UNAVAILABLE','barometers':[],'freshness':'UNAVAILABLE'})
        control_room=self.section('control_room',self.control_room,{'rows':[],'summary':{},'freshness':'UNAVAILABLE','binding':'UNAVAILABLE','runtime_identity':{'state':'UNKNOWN','forward_test_state':'UNKNOWN'}})
        live_performance=self.section('live_performance',self.live_performance,{'accounts':[],'source_fresh':False,'binding':'UNAVAILABLE','basis':'UNAVAILABLE'})
        news_policy=self.section('news_policy',self.news_policy,{'pre_news_min':None,'post_news_min':None,'effective_runtime':'UNKNOWN','coverage_state':'UNAVAILABLE'})
        templates=self.section('templates',self.templates,[])
        safe=projection_view(index.get('safe_projection')); findings=[]
        for x in safe.get('findings',[]): findings.append({k:clean(x.get(k),80) for k in ['public_id','severity','state']})
        monitoring=index.get('monitoring',{}); import shutil
        disks=[]
        for drive in ['C:/','D:/']:
            if pathlib.Path(drive).exists():
                v=shutil.disk_usage(drive); disks.append({'drive':drive[:2],'free_gb':round(v.free/1073741824,1),'total_gb':round(v.total/1073741824,1)})
        return {'schema':'ea-lab-owner-view/1','app':{'version':'1.2.0','read_only':True,'source_acceptance':'LOCAL_TOOLING_CANDIDATE_REVIEW_PENDING'},'observed_at':utcnow(),'canonical_sha':self.sha,'canonical_basis':'Local origin/master tracking ref; independent remote observation is not repeated on each browser poll','published':published,'published_binding':'MATCH' if published.get('canonical_sha')==self.sha else 'CANONICAL_DRIFT','published_hash':digest(raw),'global_state':global_match.group(1) if global_match else 'UNKNOWN','accounts':account_data,'work':work_data,'knowledge':knowledge,'news':news,'news_policy':news_policy,'macro':macro,'control_room':control_room,'live_performance':live_performance,'templates':templates,'research':eas,'safe_projection':safe,'alerts':findings,'monitoring':monitoring,'disks':disks,'errors':self.errors,'refresh':{'browser_poll_seconds':30,'meaning':'Reread existing local evidence; does not collect broker quotes, run jobs, or update news upstream.'},'limits':['Broker sample clocks are not UTC-qualified; freshness is UNKNOWN.','No universal EA good/bad score is inferred. Live P/L/PF/DD preserve the existing dashboard producer semantics and source binding.','Control Room readiness/floating values retain their own source binding and verification state.','Blocked Budget Mode and Forward Alpha are not activated.','Only chats represented by existing lane/job records are observable.']}
