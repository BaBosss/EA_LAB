from __future__ import annotations
import argparse, calendar, csv, hashlib, json
from datetime import datetime, timedelta, timezone
from pathlib import Path

SCHEMA="P4B_TESTER_OHLC_NORMALIZED_V2"
UTC_END=datetime(2025,12,31,23,59,59,tzinfo=timezone.utc)
SERVER_END=datetime(2025,12,31,23,59,59)
UTC_WARMUP_LATEST_START=datetime(2019,4,24,0,0,0,tzinfo=timezone.utc)

def nth_sunday(year:int, month:int, n:int)->datetime:
    weeks=calendar.monthcalendar(year,month)
    sundays=[w[calendar.SUNDAY] for w in weeks if w[calendar.SUNDAY]]
    return datetime(year,month,sundays[n-1])

def is_dst_transition_server_date(dt:datetime)->bool:
    return dt.date() in (nth_sunday(dt.year,3,2).date(), nth_sunday(dt.year,11,1).date())

def server_offset_hours(dt:datetime)->int:
    start=nth_sunday(dt.year,3,2).date(); end=nth_sunday(dt.year,11,1).date()
    return 3 if start < dt.date() < end else 2

def server_to_utc(text:str)->datetime:
    raw=datetime.strptime(text,"%Y.%m.%d %H:%M:%S")
    if is_dst_transition_server_date(raw): raise ValueError("AMBIGUOUS_DST_TRANSITION")
    return (raw-timedelta(hours=server_offset_hours(raw))).replace(tzinfo=timezone.utc)

def sha256(path:Path)->str:
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()

def normalize(src:Path,dst:Path,symbol:str,tf:str)->dict:
    rows=[]; quarantine=[]; raw_count=0
    with src.open(newline='',encoding='ascii') as f:
        reader=csv.DictReader(f); required=['time_server','open','high','low','close','tick_volume','spread','real_volume']
        if reader.fieldnames != required: raise ValueError(f"unexpected header: {reader.fieldnames}")
        for row in reader:
            raw_count+=1; raw_dt=datetime.strptime(row['time_server'],"%Y.%m.%d %H:%M:%S")
            if raw_dt > SERVER_END: raise ValueError(f"HOLDOUT server-date crossing row: {row['time_server']}")
            if is_dst_transition_server_date(raw_dt):
                q=dict(row); q['reason']='UNKNOWN_DST_TRANSITION'; quarantine.append(q); continue
            utc=server_to_utc(row['time_server'])
            if utc > UTC_END: raise ValueError(f"HOLDOUT crossing row: {row['time_server']} -> {utc.isoformat()}")
            row['open_time_utc']=utc.strftime('%Y-%m-%dT%H:%M:%SZ'); rows.append(row)
    if not rows: raise ValueError('no normalized rows')
    times=[r['open_time_utc'] for r in rows]
    if times != sorted(times) or len(times)!=len(set(times)): raise ValueError('normalized UTC timestamps not strictly increasing/unique')
    first=datetime.strptime(times[0],'%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
    if first > UTC_WARMUP_LATEST_START: raise ValueError(f"insufficient causal warmup: first={first.isoformat()}")
    fields=['open_time_utc','time_server','open','high','low','close','tick_volume','spread','real_volume']
    with dst.open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=fields,lineterminator='\n'); w.writeheader(); w.writerows(rows)
    qpath=dst.with_name(dst.stem+'_quarantine.csv'); qfields=['time_server','open','high','low','close','tick_volume','spread','real_volume','reason']
    with qpath.open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=qfields,lineterminator='\n'); w.writeheader(); w.writerows(quarantine)
    return {'schema':SCHEMA,'symbol':symbol,'tf':tf,'raw_rows':raw_count,'rows':len(rows),'quarantined_rows':len(quarantine),'quarantine_file':qpath.name,'quarantine_sha256':sha256(qpath),'missing_bar_policy':'DST transition server dates are quarantined as UNKNOWN_DST_TRANSITION; never imputed','first_utc':times[0],'last_utc':times[-1],'raw_sha256':sha256(src),'normalized_sha256':sha256(dst)}

def main()->int:
    ap=argparse.ArgumentParser(); ap.add_argument('--src',type=Path,required=True); ap.add_argument('--dst',type=Path,required=True); ap.add_argument('--symbol',required=True); ap.add_argument('--tf',required=True); ap.add_argument('--meta',type=Path,required=True)
    a=ap.parse_args(); meta=normalize(a.src,a.dst,a.symbol,a.tf); a.meta.write_text(json.dumps(meta,sort_keys=True,indent=2)+'\n',encoding='utf-8'); return 0
if __name__=='__main__': raise SystemExit(main())