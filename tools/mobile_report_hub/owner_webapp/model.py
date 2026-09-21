"""Read-only presentation of existing EA_LAB evidence."""
from __future__ import annotations
import csv, datetime as dt, hashlib, io, json, math, os, pathlib, re, subprocess
UTC = dt.timezone.utc
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
    try:
        t = dt.datetime.fromisoformat(str(value).replace('Z', '+00:00'))
        return t if t.tzinfo else None
    except (TypeError, ValueError): return None
def age_state(value, hours=26):
    t = stamp(value)
    if t is None: return 'UNKNOWN'
    age = (dt.datetime.now(UTC)-t).total_seconds()
    return 'FUTURE' if age < -300 else 'STALE' if age > hours*3600 else 'CURRENT'
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
        deployments=csv_rows(self.blob('portfolio/DEPLOYMENTS.csv')); grouped={}; conflicts=set(); source_count=0
        for path in files:
            try:
                match=re.fullmatch(r'EA_LAB_snapshot_(\d+)(?:_\d{8})?\.csv',path.name)
                if not match: continue
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
            except (OSError,ValueError,KeyError,UnicodeError) as e: self.issue('account_snapshot',e)
        result=[]
        for (login,currency),points in grouped.items():
            kept=[p for t,p in sorted(points.items()) if ((login,currency),t) not in conflicts]
            if not kept: continue
            latest=kept[-1]; meta=metadata.get(login,{})
            result.append({'id':'acct-'+digest(login.encode())[:12],'label':'***'+login[-3:],'currency':currency,'environment':clean(meta.get('environment','UNKNOWN'),40),'points':[{k:v for k,v in p.items() if k!='eas'} for p in kept],'latest':latest,'sample_count':len(kept),'clock':'BROKER_SERVER_TIME_TZ_UNQUALIFIED','freshness':'UNKNOWN','identity':'ACCOUNT_SNAPSHOT_NOT_STRATEGY_ATTESTATION'})
        return {'rows':sorted(result,key=lambda r:r['label']),'files_read':source_count,'conflicting_samples':len(conflicts),'basis':'Observed samples only; line joins samples, not continuous equity. No FX conversion or deposit-adjusted return.'}
    def work(self):
        root=pathlib.Path(self.c['registry']); lease_root=pathlib.Path(self.c['leases']); jobs_root=pathlib.Path(self.c['jobs']); result=[]; totals={}
        for p in sorted(root.glob('*.json')):
            try:
                x=read_json(p,root); lane=x['lane_id']; state=x['state']; updated=x.get('updated_at')
                if not re.fullmatch(r'[A-Za-z0-9_.-]{1,128}',lane): raise Refused('LANE_ID')
                totals[state]=totals.get(state,0)+1
                if state=='DONE': continue
                lease=lease_root/(lane+'.json'); job={}; terminal=None; jobid=None
                if lease.is_file():
                    l=read_json(lease,lease_root); jobid=l.get('job_id')
                    if not isinstance(jobid,str) or not re.fullmatch(r'[A-Za-z0-9_.-]{1,160}',jobid): raise Refused('JOB_ID')
                    jroot=jobs_root/jobid
                    if (jroot/'state.json').is_file(): job=read_json(jroot/'state.json',jobs_root)
                    if (jroot/'result.json').is_file(): terminal=read_json(jroot/'result.json',jobs_root)
                js=job.get('state','NOT_OBSERVED'); end=None
                if isinstance(terminal,dict): js=terminal.get('state',js); end=terminal.get('ended_utc')
                cls='TERMINAL_RECONCILE' if js in ['COMPLETE','FAILED','TIMED_OUT','CANCELLED'] else 'BLOCKED_REVIEW' if state in ['REVIEW','FROZEN'] else 'WAITING_OWNER' if state=='BLOCKED' and str(x.get('blocker_class','')).startswith('E_') else state
                result.append({'id':lane,'title':lane.removeprefix('ct-').replace('-',' '),'state':state,'display_state':cls,'owner':clean(x.get('owner_chat'),100),'worker':clean(x.get('worker'),140),'updated_at':updated,'freshness':age_state(updated,24),'job_id':jobid,'job_state':js,'ended_at':end,'process_state':'NOT_PROBED','progress':'UNKNOWN','blocker':clean(x.get('blocker_class'),180),'head':x.get('head_sha'),'reviewed_head':x.get('reviewed_head'),'reviewer':clean(x.get('reviewer'),140),'dependencies':[clean(d,128) for d in x.get('dependencies',[]) if isinstance(d,str)]})
            except (OSError,ValueError,KeyError,TypeError) as e: self.issue('lane_observation',e)
        result.sort(key=lambda r:(r['freshness']=='CURRENT',r['updated_at'] or ''),reverse=True)
        return {'rows':result,'totals':totals,'observed_at':utcnow(),'basis':'Registry declarations + existing lease/result bytes; no PID-only liveness or ChatGPT-window inference.'}
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
        account_data=self.section('account_history',self.accounts,{'rows':[],'files_read':0,'basis':'UNAVAILABLE'})
        work_data=self.section('work',self.work,{'rows':[],'totals':{},'basis':'UNAVAILABLE'})
        knowledge=self.section('knowledge',self.knowledge,{'documents':[],'health':{},'binding':'UNAVAILABLE'})
        news=self.section('news',self.news,{'events':[],'guard_effective':'UNKNOWN','freshness':'UNAVAILABLE'})
        macro=self.section('macro',self.macro,{'state':'UNAVAILABLE','barometers':[],'freshness':'UNAVAILABLE'})
        templates=self.section('templates',self.templates,[])
        safe=index.get('safe_projection',{}); findings=[]
        for x in safe.get('findings',[]): findings.append({k:clean(x.get(k),80) for k in ['public_id','severity','state']})
        monitoring=index.get('monitoring',{}); import shutil
        disks=[]
        for drive in ['C:/','D:/']:
            if pathlib.Path(drive).exists():
                v=shutil.disk_usage(drive); disks.append({'drive':drive[:2],'free_gb':round(v.free/1073741824,1),'total_gb':round(v.total/1073741824,1)})
        return {'schema':'ea-lab-owner-view/1','app':{'version':'1.0.0','read_only':True,'source_acceptance':'LOCAL_TOOLING_CANDIDATE_REVIEW_PENDING'},'observed_at':utcnow(),'canonical_sha':self.sha,'canonical_basis':'Local origin/master tracking ref; independent remote observation is not repeated on each browser poll','published':published,'published_binding':'MATCH' if published.get('canonical_sha')==self.sha else 'CANONICAL_DRIFT','published_hash':digest(raw),'global_state':global_match.group(1) if global_match else 'UNKNOWN','accounts':account_data,'work':work_data,'knowledge':knowledge,'news':news,'macro':macro,'templates':templates,'research':eas,'alerts':findings,'monitoring':monitoring,'disks':disks,'errors':self.errors,'refresh':{'browser_poll_seconds':30,'meaning':'Reread existing local evidence; does not collect broker quotes, run jobs, or update news upstream.'},'limits':['Broker sample clocks are not UTC-qualified; freshness is UNKNOWN.','No per-EA realized-return / profit-factor / win-rate is inferred.','Blocked Budget Mode and Forward Alpha are not activated.','Only chats represented by existing lane/job records are observable.']}
